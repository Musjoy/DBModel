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

+ (void)storeItems:(NSArray *)arrItems identifier:(NSString *)identifier
{
    NSString *className = NSStringFromClass([self class]);
    return [DBItemStore storeItems:arrItems withClass:className identifier:identifier];
}

+ (__kindof NSArray<DBModel> *)theStoreItemsWithIdentifier:(NSString *)identifier
{
    return [self theStoreItemsWithIdentifier:identifier orderBy:@"storeOrder"];
}

+ (__kindof NSArray<DBModel> *)theStoreItemsWithIdentifier:(NSString *)identifier orderBy:(NSString *)orderBy
{
    NSString *className = NSStringFromClass([self class]);
    return [DBItemStore itemsOfClass:className identifier:identifier orderBy:orderBy];
}

+ (void)setItems:(NSArray *)arrItems withKey:(NSString *)key
{
    NSString *className = NSStringFromClass([self class]);
    return [DBItemStore storeItems:arrItems withClass:className identifier:key haveDB:NO];
}

+ (__kindof NSArray<DBModel> *)itemsWithKey:(NSString *)key
{
    NSString *className = NSStringFromClass([self class]);
    return [DBItemStore itemsOfClass:className identifier:key orderBy:@"storeOrder" haveDB:NO];
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

+ (int)lengthFor:(NSString *)property
{
    if ([property isEqualToString:@"storeData"]) {
        return 5000;
    }
    return 0;
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

+ (void)storeItems:(NSArray *)arrItems withClass:(NSString *)aClassName identifier:(NSString *)identifier
{
    [self storeItems:arrItems withClass:aClassName identifier:identifier haveDB:YES];
}

+ (void)storeItems:(NSArray *)arrItems withClass:(NSString *)aClassName identifier:(NSString *)identifier haveDB:(BOOL)haveDB
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
        if (!haveDB) {
            store.storeData = [model toJSONString];
        }
        [arrUpdate addObject:store];
    }
    if (arrUpdate.count > 0) {
        if (haveDB) {
            [DBManager insertModelListWhileNotExist:arrItems];
        }
        [DBManager updateModelList:arrUpdate];
    }
    
    // 判断有删除，还是有新增
    if (arr.count < arrItems.count) {
        // 有新增
        NSMutableArray *arrInsert = [[NSMutableArray alloc] init];
        for (NSInteger i=len, len1=arrItems.count; i<len1; i++, index++) {
            DBModel *model = arrItems[i];
            DBItemStore *store = [[DBItemStore alloc] init];
            store.storeClass = aClassName;
            store.relateId = [model valueForKey:idName];
            store.identifier = identifier;
            store.storeOrder = (NSNumber<DBInt> *)[NSNumber numberWithInteger:index];
            if (!haveDB) {
                store.storeData = [model toJSONString];
            }
            [arrInsert addObject:store];
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

+ (NSArray *)itemsOfClass:(NSString *)aClassName identifier:(NSString *)identifier
{
    NSArray *arr = [self itemsOfClass:aClassName identifier:identifier orderBy:@"storeOrder"];
    return arr;
}

+ (NSArray *)itemsOfClass:(NSString *)aClassName identifier:(NSString *)identifier orderBy:(NSString *)orderBy
{
    return [self itemsOfClass:aClassName identifier:identifier orderBy:orderBy haveDB:YES];
}

+ (NSArray *)itemsOfClass:(NSString *)aClassName identifier:(NSString *)identifier orderBy:(NSString *)orderBy haveDB:(BOOL)haveDB
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
    if (haveDB) {
        NSString *relateIdName = [itemClass primaryKey];
        NSString *strJoin = [NSString stringWithFormat:@"store LEFT JOIN %@ item ON item.%@=store.relateId", [itemClass tableName], relateIdName];
        NSString *whereSql = [NSString stringWithFormat:@"storeClass='%@' AND identifier='%@' AND item.%@ IS NOT NULL", aClassName, identifier, relateIdName];
        arr = [DBManager findModelList:self
                                  join:strJoin
                          withWhereSql:whereSql
                               orderBy:orderBy];
    } else {
        NSString *whereSql = [NSString stringWithFormat:@"storeClass='%@' AND identifier='%@'", aClassName, identifier];
        arr = [DBManager findModelList:self
                          withWhereSql:whereSql
                               orderBy:orderBy];
    }
    
    if (arr.count > 0) {
        [[self cacheData] setObject:arr forKey:key];
    }
    return arr;
}


#pragma mark - Overwrite

+ (DBModel *)modelWithFMResult:(FMResultSet *)result
{
    if ([result columnCount] > 6) {
        NSString *storeClass = [result stringForColumn:@"storeClass"];
        Class itemClass = NSClassFromString(storeClass);
        return [itemClass modelWithFMResult:result];
    } else if ([result columnCount] == 6) {
        NSString *storeData = [result stringForColumn:@"storeData"];
        if (storeData.length > 0) {
            NSString *storeClass = [result stringForColumn:@"storeClass"];
            Class itemClass = NSClassFromString(storeClass);
            return [[itemClass alloc] initWithString:storeData error:NULL];
        }
    }
    return [super modelWithFMResult:result];
}



@end


