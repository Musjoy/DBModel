//
//  DBItemStore.m
//  Common
//
//  Created by 黄磊 on 16/8/23.
//  Copyright © 2016年 Musjoy. All rights reserved.
//

#import "DBItemStore.h"
#import "DBManager.h"
#ifdef MODULE_FILE_SOURCE
#import "FileSource.h"
#endif

static NSDictionary *s_storeKeys = nil;
static NSCache *s_cacheData = nil;
static DBItemStore *s_itemStore = nil;

#pragma mark - Category

@implementation DBModel (DBItemStore)

+ (__kindof NSArray<DBModel> *)theStoreItemsWithIdentifier:(NSString *)identifier
{
    return [self theStoreItemsWithIdentifier:identifier orderBy:@"storeOrder"];
}

+ (__kindof NSArray<DBModel> *)theStoreItemsWithIdentifier:(NSString *)identifier orderBy:(NSString *)orderBy
{
    NSString *className = NSStringFromClass([self class]);
    return [DBItemStore itemsOfClass:className identifier:identifier orderBy:orderBy];
}

+ (void)storeItems:(NSArray *)arrItems identifier:(NSString *)identifier
{
    NSString *className = NSStringFromClass([self class]);
    return [DBItemStore storeItems:arrItems withClass:className identifier:identifier];
}

@end

#pragma mark - DBItemStore

@implementation DBItemStore

+ (NSDictionary *)storeKeys
{
    if (s_storeKeys == nil) {
        id data = getFileData(FILE_NAME_STORE_KEYS);
        NSArray *arr = data;
        if (arr.count > 0) {
            NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
            for (NSString *aKey in arr) {
                [dic setObject:[NSNumber numberWithBool:YES] forKey:aKey];
            }
            s_storeKeys = dic;
        } else {
            s_storeKeys = @{@"*":@YES};
        }
        [self addStoreKeyObserve];
    }
    return s_storeKeys;
}


+ (BOOL)isPrimaryKeyAutoIncrement:(NSString *)property
{
    return YES;
}


#pragma mark - Update Store Key

+ (void)addStoreKeyObserve
{
#ifdef MODULE_FILE_SOURCE
    if (s_itemStore == nil) {
        s_itemStore = [[DBItemStore alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:s_itemStore
                                                 selector:@selector(updateStoreKeys)
                                                     name:[kNoticPlistUpdate stringByAppendingString:FILE_NAME_STORE_KEYS]
                                                   object:nil];
    }
#endif
}

- (void)updateStoreKeys
{
    s_storeKeys = nil;
}


#pragma mark - Cache

+ (NSCache *)cacheData
{
    if (s_cacheData == nil) {
        s_cacheData = [[NSCache alloc] init];
    }
    return s_cacheData;
}

// 能否读取改数据
+ (BOOL)canReadDataWithKey:(NSString *)theKey
{
    if (theKey.length == 0) {
        return NO;
    }
    if ([[self storeKeys] objectForKey:@"*"]) {
        return YES;
    }
    
    NSArray *arr = [theKey componentsSeparatedByString:@"-"];
    NSMutableString *strKey = [arr[0] mutableCopy];
    for (NSInteger i=1, len=arr.count; i<len; i++) {
        NSString *aStr = arr[i];
        [strKey appendString:@"-"];
        NSString *aKey = [strKey stringByAppendingString:@"*"];
        if ([[self storeKeys] objectForKey:aKey]) {
            return YES;
        }
        [strKey appendString:aStr];
    }
    
    if ([[self storeKeys] objectForKey:strKey]) {
        return YES;
    }
    
    if ([[self storeKeys] objectForKey:[strKey stringByAppendingString:@"-*"]]) {
        return YES;
    }
    
    return NO;
}

#pragma mark - Public

+ (NSArray *)itemsOfClass:(NSString *)aClassName identifier:(NSString *)identifier
{
    NSArray *arr = [self itemsOfClass:aClassName identifier:identifier orderBy:@"storeOrder"];
    return arr;
}

+ (NSArray *)itemsOfClass:(NSString *)aClassName identifier:(NSString *)identifier orderBy:(NSString *)orderBy
{
    Class itemClass = NSClassFromString(aClassName);
    if (itemClass == NULL) {
        return @[];
    }
    // 首先读内存缓存
    NSString *key = [NSString stringWithFormat:@"%@-%@", aClassName, identifier];
    NSArray *arr = [[self cacheData] objectForKey:key];
    if (arr.count > 0) {
        return arr;
    }
    if (![self canReadDataWithKey:identifier]) {
        return @[];
    }
    identifier = [identifier stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
    NSString *relateIdName = [itemClass primaryKey];
    NSString *strJoin = [NSString stringWithFormat:@"store LEFT JOIN %@ item ON item.%@=store.relateId", [itemClass tableName], relateIdName];
    NSString *whereSql = [NSString stringWithFormat:@"storeClass='%@' AND identifier='%@' AND item.%@ IS NOT NULL", aClassName, identifier, relateIdName];
    arr = [DBManager findModelList:self
                              join:strJoin
                      withWhereSql:whereSql
                           orderBy:orderBy];
    if (arr.count > 0) {
        [[self cacheData] setObject:arr forKey:key];
    }
    return arr;
}

+ (void)storeItems:(NSArray *)arrItems withClass:(NSString *)aClassName identifier:(NSString *)identifier
{
    Class itemClass = NSClassFromString(aClassName);
    if (itemClass == NULL) {
        return;
    }
    NSDictionary *aDic = @{@"storeClass":aClassName,
                           @"identifier":identifier};
    NSArray *arr = [DBManager findModelList:self inCondition:aDic orderBy:@"storeOrder"];
    
    // 先找需要update的数据
    NSMutableArray *arrUpdate = [[NSMutableArray alloc] init];
    NSInteger index = 0;
    NSInteger len = MIN(arr.count, arrItems.count);
    NSString *idName = [itemClass primaryKey];
    for (NSInteger i=0; i<len; i++,index++) {
        DBItemStore *store = arr[i];
        DBModel *model = arrItems[i];
        store.relateId = [model valueForKey:idName];
        store.storeOrder = (NSNumber<DBInt> *)[NSNumber numberWithInteger:index];
        [arrUpdate addObject:store];
    }
    if (arrUpdate.count > 0) {
        [DBManager insertModelListWhileNotExist:arrItems];
        [DBManager updateModelList:arrUpdate];
    }
    
    // 判断有删除，还是有新增
    if (arr.count < arrItems.count) {
        // 有新增
        NSMutableArray *arrInsert = [[NSMutableArray alloc] init];
        for (NSInteger i=len, len1=arrItems.count; i<len1; i++, index++) {
            DBModel *model = arrItems[i];
            DBItemStore *sort = [[DBItemStore alloc] init];
            sort.storeClass = aClassName;
            sort.relateId = [model valueForKey:idName];
            sort.identifier = identifier;
            sort.storeOrder = (NSNumber<DBInt> *)[NSNumber numberWithInteger:index];
            [arrInsert addObject:sort];
        }
        [DBManager forceInsertModelList:arrInsert];
    } else if (arr.count > arrItems.count) {
        // 需要删除
        NSArray *arrDelete = [arr subarrayWithRange:NSMakeRange(len, arr.count-arrItems.count)];
        [DBManager deleteModelList:arrDelete];
    }
    NSString *key = [NSString stringWithFormat:@"%@-%@", aClassName, identifier];
    [[self cacheData] setObject:arrItems forKey:key];
}

+ (void)deleteItemWithId:(NSString *)relateId ofClass:(NSString *)aClassName identifier:(NSString *)identifier
{
    NSString *strSql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE relateId='%@' AND storeClass='%@' AND identifier='%@'", [self tableName], relateId, aClassName, identifier];
    [[DBManager sharedInstance] executeUpdates:@[strSql]];
}


#pragma mark - Overwrite

+ (DBModel *)modelWithFMResult:(FMResultSet *)result
{
//    NSString *storeClass = [result stringForColumn:@"storeClass"];
//    if (storeClass.length > 0) {
//        Class itemClass = NSClassFromString(storeClass);
//        if (itemClass && [itemClass isSubclassOfClass:[DBModel class]]) {
//            NSString *primaryKey = [itemClass primaryKey];
//            if ([result.columnNameToIndexMap objectForKey:[primaryKey lowercaseString]]) {
//                return [itemClass modelWithFMResult:result];
//            }
//        }
//    }
//
//    return [super modelWithFMResult:result];
    
    if ([result columnCount] > 5) {
        NSString *storeClass = [result stringForColumn:@"storeClass"];
        Class itemClass = NSClassFromString(storeClass);
        return [itemClass modelWithFMResult:result];
    } else {
        return [super modelWithFMResult:result];
    }
}



@end


