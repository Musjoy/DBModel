//
//  DBManager.m
//  Common
//
//  Created by 黄磊 on 16/4/6.
//  Copyright © 2016年 Musjoy. All rights reserved.
//

#import "DBManager.h"
#import HEADER_SERVER_URL
#ifdef HEADER_ANALYSE
#import HEADER_ANALYSE
#endif
#ifdef MODULE_FILE_SOURCE
#import "FileSource.h"
#endif
#ifdef MODULE_DB_ITEM_STORE
#import "DBItemStore.h"
#endif

static DBManager *s_dbManager = nil;

@interface DBManager ()

@property (nonatomic, strong) NSArray *arrTables;
@property (nonatomic, strong) FMDatabase  *db;
@property (nonatomic, strong) NSDateFormatter *curDateFormatter;

@end

@implementation DBManager

+ (DBManager *)sharedInstance
{
    if (s_dbManager == nil)
    {
        s_dbManager = [[DBManager alloc] init];
    }
    return s_dbManager;
}

+ (void)configure
{
#ifdef DEFAULT_DB_NAME
    NSArray *arrTables = @[];
    NSString *theDBName = DEFAULT_DB_NAME;
#ifdef DEFAULT_DB_TABLE_LIST
    arrTables = DEFAULT_DB_TABLE_LIST;
#endif

#else
    NSString *theDBName = nil;
    NSArray *arrTables = @[];
    NSDictionary *aDic = getFileData(FILE_NAME_DB_CONFIG);
    if (aDic) {
        theDBName = aDic[@"theDBName"];
        arrTables = aDic[@"theTableList"];
    }
#endif
    if (theDBName.length > 0) {
        if (arrTables == nil || ![arrTables isKindOfClass:[NSArray class]]) {
            arrTables = @[];
        }
#ifdef DB_MANAGER_USE_LIB
        [[self sharedInstance] openLibDB:theDBName withTables:arrTables];
#else
        [[self sharedInstance] openDefaultDB:theDBName withTables:arrTables];
#endif
    }
}

- (id)init
{
    self = [super init];
    if (self) {
    }
    return self;
}

- (void)openDefaultDB:(NSString *)dbName withTables:(NSArray *)arrTables
{
    if (_db) {
        [_db close];
        _db = nil;
    }
    
#if (defined(DEBUG) || defined(DB_NEED_HOST_PREFIX)) && defined(kServerBaseHost)
    NSString *theBaseHost = [[kServerBaseHost componentsSeparatedByString:@"://"] lastObject];
    NSString *fileName    = [theBaseHost stringByAppendingFormat:@"-%@.sqlite", dbName];
#else
    NSString *fileName = [dbName stringByAppendingString:@".sqlite"];
#endif
    
#if (!defined(DEBUG) && defined(DB_HIDE_DB_FILE))
    NSString *docsPath = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)[0];
#else
    NSString *docsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
#endif
    NSString *dbPath   = [docsPath stringByAppendingPathComponent:fileName];
    BOOL needUpdate = ![[NSFileManager defaultManager] fileExistsAtPath:dbPath];
    _db = [FMDatabase databaseWithPath:dbPath];
    if (_curDateFormatter && _db) {
        [_db setDateFormat:_curDateFormatter];
    }
#ifdef MODULE_DB_ITEM_STORE
    arrTables = [arrTables arrayByAddingObject:@"DBItemStore"];
#endif
    self.arrTables = arrTables;
    [_db open];
    [self createTablesWithDBName:dbName forceUpdate:needUpdate];
}

- (void)openLibDB:(NSString *)dbName withTables:(NSArray *)arrTables
{
    if (_db) {
        [_db close];
        _db = nil;
    }
    
    NSString *fileName = [dbName stringByAppendingString:@".sqlite"];
    NSString *docsPath = [[NSBundle mainBundle] resourcePath];
    NSString *dbPath   = [docsPath stringByAppendingPathComponent:fileName];
    _db = [FMDatabase databaseWithPath:dbPath];
    if (_curDateFormatter && _db) {
        [_db setDateFormat:_curDateFormatter];
    }
#ifdef MODULE_DB_ITEM_STORE
    arrTables = [arrTables arrayByAddingObject:@"DBItemStore"];
#endif
    self.arrTables = arrTables;
    [_db open];
}

- (void)closeDefaultDB
{
    if (_db) {
        [_db close];
        _db = nil;
    }
}

- (void)setDefalutDateFormat:(NSDateFormatter *)aDateFormatter
{
    if (aDateFormatter) {
        _curDateFormatter = aDateFormatter;
        [DBModel setDateFormat:_curDateFormatter];
        if (_db) {
            [_db setDateFormat:_curDateFormatter];
        }
    }
}

// 创建所有的表
- (void)createTablesWithDBName:(NSString *)dbName forceUpdate:(BOOL)forceUpdate
{
    // 加入版本判断，避免频繁更新数据库
    NSString *key = [kDBLastCheckVersion stringByAppendingString:dbName];
    NSString *curVersion = kClientVersion;
    if (!forceUpdate) {
#if !defined(DEBUG) || !defined(FUNCTION_CHECK_DB_UPDATE_EVERY_TIME)
        /// 发布版本每次需要判断版本，开发版本，当定义FUNCTION_CHECK_DB_UPDATE_EVERY_TIME，不用判断版本，每次更新数据库
        NSString *lastVersion = [[NSUserDefaults standardUserDefaults] stringForKey:key];
        if (lastVersion && [lastVersion isEqualToString:curVersion]) {
            return;
        }
#endif
    }
    
    BOOL isSucceed = [self updateAllDB];
    if (isSucceed) {
        [[NSUserDefaults standardUserDefaults] setObject:curVersion forKey:key];
    }
}
    

- (BOOL)updateAllDB
{
    if (!_db) {
        return NO;
    }
    BOOL result = YES;
    for (NSString *table in self.arrTables) {
        Class tableClass = NSClassFromString(table);
        if (tableClass) {
            NSString *tableName = [tableClass tableName];
            FMResultSet *tableResult = [_db getTableSchema:tableName];
            NSArray *arrSqls = [tableClass createOrUpdateTableSqlsWith:tableResult];
            if (arrSqls.count == 0) {
                // 空的创建语句不能执行
                continue;
            }
            BOOL isSucceed = [self executeUpdates:arrSqls];
            if (!isSucceed) {
                result = NO;
                NSString *strErr = [NSString stringWithFormat:@"数据库[%@]更新失败", tableName];
                triggerEventStr(STAT_Error, strErr);
            }
        }
    }
    return result;
}

#pragma mark - Public

- (BOOL)executeUpdates:(NSArray *)arrSql
{
    if (arrSql.count == 1) {
        return [_db executeUpdate:arrSql[0]];
    }
    
    BOOL isSucceed = YES;
    [_db beginTransaction];
    for (NSString *aSql in arrSql) {
        isSucceed = [_db executeUpdate:aSql];
        if (!isSucceed) {
            break;
        }
    }
    if (isSucceed) {
        return [_db commit];
    } else {
        [_db rollback];
    }
    return isSucceed;
}

- (FMResultSet *)executeQuery:(NSString *)sql, ...
{
    return [_db executeQuery:sql];
}


#pragma mark -Model Operation

+ (BOOL)insertModel:(DBModel *)aModel
{
    // 检查是否存在改数据
    BOOL isExist = [self isExistModel:aModel];
    if (isExist) {
        // 调用update
        return [self updateModel:aModel];
    }
    NSString *strSql = [aModel insertSql];
    
    BOOL isSucceed = [[DBManager sharedInstance] executeUpdates:@[strSql]];
    if (!isSucceed) {
        LogError(@"Sql Execute Faild :\n%@", strSql);
    }
    return isSucceed;
}

+ (BOOL)updateModel:(DBModel *)aModel
{
    NSString *strSql = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE (%@='%@')", [aModel.class tableName], [aModel.class primaryKey], [aModel primaryValue]];
    FMResultSet *result = [[DBManager sharedInstance] executeQuery:strSql];
    if (result.next) {
        NSString *strSql1 = [aModel updateSqlFormFMResult:result];
        if (strSql1.length > 0) {
            BOOL isSucceed = [[DBManager sharedInstance] executeUpdates:@[strSql1]];
            if (!isSucceed) {
                LogError(@"Sql Execute Faild :\n%@", strSql1);
            }
            return isSucceed;
        }
        // 没有需要更新的
        return YES;
    }
    
    return NO;
}

+ (BOOL)updateModelList:(NSArray *)arrModels
{
    BOOL isSucceed = YES;
    for (DBModel *aModel in arrModels) {
        BOOL result = [self updateModel:aModel];
        if (!result) {
            // 这里更新失败之后，需继续更新后面数据，处理方式需要探讨。
            LogError(@"Updata Failed!!!");
            triggerEventStr(STAT_Error, @"更新失败");
            isSucceed = NO;
        }
    }
    return isSucceed;
}

+ (BOOL)deleteModelList:(NSArray *)arrModels
{
    NSMutableString *primaryValues = [[NSMutableString alloc] init];
    NSString *strSeparate = @"";
    for (DBModel *aModel in arrModels) {
        [primaryValues appendString:strSeparate];
        [primaryValues appendFormat:@"'%@'", [aModel primaryValue]];
        strSeparate = @",";
    }
    if (primaryValues.length > 0) {
        DBModel *aModel = arrModels[0];
        NSString *strSql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ IN (%@)", [aModel.class tableName], [aModel.class primaryKey], primaryValues];
        FMResultSet *result = [[DBManager sharedInstance] executeQuery:strSql];
        return result.next;
    }
    return YES;
}

+ (BOOL)isExistModel:(DBModel *)aModel
{
    if ([aModel primaryValue] == nil) {
        return NO;
    }
    NSString *primaryKey = [aModel.class primaryKey];
    NSString *strSql = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE (%@='%@')", primaryKey, [aModel.class tableName], primaryKey, [aModel primaryValue]];
    FMResultSet *result = [[DBManager sharedInstance] executeQuery:strSql];
    return result.next;
}

+ (BOOL)insertModelList:(NSArray *)arrModels
{
    BOOL isSucceed = YES;
    for (DBModel *aModel in arrModels) {
        BOOL result = [self insertModel:aModel];
        if (!result) {
            // 这里插入失败之后，需继续更新后面数据，处理方式需要探讨。
            LogError(@"Insert Failed!!!");
            triggerEventStr(STAT_Error, @"插入失败");
            isSucceed = NO;
        }
    }
    return isSucceed;
}

+ (BOOL)forceInsertModelList:(NSArray *)arrModels
{
    if (arrModels.count == 0) {
        return YES;
    }
    NSMutableArray *arrSql = [[NSMutableArray alloc] init];
    for (DBModel *aModel in arrModels) {
        [arrSql addObject:[aModel insertSql]];
    }
    return [[DBManager sharedInstance] executeUpdates:arrSql];
}

+ (BOOL)insertModelListWhileNotExist:(NSArray *)arrModels
{
    NSMutableArray *arrNeedForceInsert = [[NSMutableArray alloc] init];
    for (DBModel *aModel in arrModels) {
        if ([aModel primaryValue]) {
            if ([self isExistModel:aModel]) {
                continue;
            }
        }
        [arrNeedForceInsert addObject:aModel];
    }
    return [self forceInsertModelList:arrNeedForceInsert];
}

#pragma mark -Model Query

+ (__kindof DBModel *)findModel:(Class)aModelClass inCondition:(NSDictionary *)dicCondition
{
    NSMutableString *strWhereSql = [[NSMutableString alloc] init];
    NSString *strSeparate = @"";
    
    for (NSString *key in [dicCondition allKeys]) {
        [strWhereSql appendString:strSeparate];
        id value = dicCondition[key];
        [strWhereSql appendFormat:@"%@=", key];
        if ([value isKindOfClass:[NSNumber class]]) {
            [strWhereSql appendString:[value stringValue]];
        } else {
            if ([value isKindOfClass:[NSString class]]) {
                value = [value stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
            }
            [strWhereSql appendFormat:@"'%@'", value];
        }
        strSeparate = @" AND ";
    }
    return [self findModel:aModelClass withWhereSql:strWhereSql];
}

+ (DBModel *)findModel:(Class)aModelClass withWhereSql:(NSString *)strWhereSql
{
    NSMutableString *strSql = [[NSMutableString alloc] init];
    [strSql appendFormat:@"SELECT * FROM %@ WHERE (%@) LIMIT 1", [aModelClass tableName], strWhereSql];
    FMResultSet *result = [[self sharedInstance] executeQuery:strSql];
    if (result.next) {
        return [aModelClass modelWithFMResult:result];
    }
    return nil;
}

+ (NSArray *)findModelList:(Class)aModelClass inCondition:(NSDictionary *)dicCondition
{
    return [self findModelList:aModelClass inCondition:dicCondition orderBy:nil];
}

+ (NSArray *)findModelList:(Class)aModelClass inCondition:(NSDictionary *)dicCondition orderBy:(NSString *)orderBy
{
    NSMutableString *strWhereSql = [[NSMutableString alloc] init];
    NSString *strSeparate = @"";
    
    for (NSString *key in [dicCondition allKeys]) {
        [strWhereSql appendString:strSeparate];
        id value = dicCondition[key];
        [strWhereSql appendFormat:@"%@=", key];
        if ([value isKindOfClass:[NSNumber class]]) {
            [strWhereSql appendString:[value stringValue]];
        } else {
            if ([value isKindOfClass:[NSString class]]) {
                value = [value stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
            }
            [strWhereSql appendFormat:@"'%@'", value];
        }
        strSeparate = @" AND ";
    }
    return [self findModelList:aModelClass withWhereSql:strWhereSql orderBy:orderBy];
}

+ (NSArray *)findModelList:(Class)aModelClass withWhereSql:(NSString *)strWhereSql
{
    return [self findModelList:aModelClass withWhereSql:strWhereSql orderBy:nil];
}

+ (NSArray *)findModelList:(Class)aModelClass withWhereSql:(NSString *)strWhereSql orderBy:(NSString *)orderBy
{
    NSMutableString *strSql = [[NSMutableString alloc] init];
    [strSql appendFormat:@"SELECT * FROM %@", [aModelClass tableName]];
    if (strWhereSql.length > 0) {
        [strSql appendFormat:@" WHERE (%@)",strWhereSql];
    }
    if (orderBy.length > 0) {
        if ([self isString:orderBy containString:@"ORDER BY"]) {
            [strSql appendFormat:@" %@", orderBy];
        } else {
            [strSql appendFormat:@" ORDER BY %@", orderBy];
        }
    }
    FMResultSet *result = [[self sharedInstance] executeQuery:strSql];
    NSMutableArray *arr = [[NSMutableArray alloc] init];
    while (result.next) {
        DBModel *aModel = [aModelClass modelWithFMResult:result];
        [arr addObject:aModel];
    }
    return arr;
}

+ (NSArray *)findModelList:(Class)aModelClass join:(NSString *)strJoin withWhereSql:(NSString *)strWhereSql orderBy:(NSString *)orderBy
{
    NSMutableString *strSql = [[NSMutableString alloc] init];
    [strSql appendFormat:@"SELECT * FROM %@ %@", [aModelClass tableName], strJoin];
    if (strWhereSql.length > 0) {
        [strSql appendFormat:@" WHERE (%@)",strWhereSql];
    }
    if (orderBy.length > 0) {
        if ([self isString:orderBy containString:@"ORDER BY"]) {
            [strSql appendFormat:@" %@", orderBy];
        } else {
            [strSql appendFormat:@" ORDER BY %@", orderBy];
        }
    }
    FMResultSet *result = [[self sharedInstance] executeQuery:strSql];
    NSMutableArray *arr = [[NSMutableArray alloc] init];
    while (result.next) {
        DBModel *aModel = [aModelClass modelWithFMResult:result];
        [arr addObject:aModel];
    }
    return arr;
}



+ (int)countFromModel:(Class)aModelClass inCondition:(NSDictionary *)dicCondition
{
    NSMutableString *strWhereSql = [[NSMutableString alloc] init];
    NSString *strSeparate = @"";
    
    for (NSString *key in [dicCondition allKeys]) {
        [strWhereSql appendString:strSeparate];
        id value = dicCondition[key];
        [strWhereSql appendFormat:@"%@=", key];
        if ([value isKindOfClass:[NSNumber class]]) {
            [strWhereSql appendString:[value stringValue]];
        } else {
            [strWhereSql appendFormat:@"'%@'", value];
        }
        strSeparate = @" AND ";
    }
    return [self countFromModel:aModelClass withWhereSql:strWhereSql];
}

+ (int)countFromModel:(Class)aModelClass withWhereSql:(NSString *)strWhereSql
{
    NSMutableString *strSql = [[NSMutableString alloc] init];
    [strSql appendFormat:@"SELECT count(*) FROM %@", [aModelClass tableName]];
    if (strWhereSql.length > 0) {
        [strSql appendFormat:@" WHERE (%@)", strWhereSql];
    }
    FMResultSet *result = [[self sharedInstance] executeQuery:strSql];
    if (result.next) {
        return [result intForColumnIndex:0];
    }
    return 0;
}


#pragma mark - Other DB


+ (BOOL)theDB:(FMDatabase *)db executeUpdates:(NSArray *)arrSql
{
    if (arrSql.count == 1) {
        return [db executeUpdate:arrSql[0]];
    }
    
    BOOL isSucceed = YES;
    [db beginTransaction];
    for (NSString *aSql in arrSql) {
        isSucceed = [db executeUpdate:aSql];
        if (!isSucceed) {
            break;
        }
    }
    if (isSucceed) {
        return [db commit];
    } else {
        [db rollback];
    }
    return isSucceed;
}

+ (FMResultSet *)theDB:(FMDatabase *)db executeQuery:(NSString *)sql, ...
{
    return [db executeQuery:sql];
}


#pragma mark -Model Operation

+ (BOOL)theDB:(FMDatabase *)db insertModel:(DBModel *)aModel
{
    // 检查是否存在改数据
    BOOL isExist = [self theDB:db isExistModel:aModel];
    if (isExist) {
        // 调用update
        return [self theDB:db updateModel:aModel];
    }
    NSString *strSql = [aModel insertSql];
    
    BOOL isSucceed = [self theDB:db executeUpdates:@[strSql]];
    if (!isSucceed) {
        LogError(@"Sql Execute Faild :\n%@", strSql);
    }
    return isSucceed;
}

+ (BOOL)theDB:(FMDatabase *)db updateModel:(DBModel *)aModel
{
    NSString *strSql = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE (%@='%@')", [aModel.class tableName], [aModel.class primaryKey], [aModel primaryValue]];
    FMResultSet *result = [self theDB:db executeQuery:strSql];
    if (result.next) {
        NSString *strSql1 = [aModel updateSqlFormFMResult:result];
        if (strSql1.length > 0) {
            BOOL isSucceed = [self theDB:db executeUpdates:@[strSql1]];
            if (!isSucceed) {
                LogError(@"Sql Execute Faild :\n%@", strSql1);
            }
            return isSucceed;
        }
    }
    
    return NO;
}

+ (BOOL)theDB:(FMDatabase *)db updateModelList:(NSArray *)arrModels
{
    for (DBModel *aModel in arrModels) {
        BOOL result = [self theDB:db updateModel:aModel];
        if (!result) {
            return result;
        }
    }
    return YES;
}

+ (BOOL)theDB:(FMDatabase *)db deleteModelList:(NSArray *)arrModels
{
    NSMutableString *primaryValues = [[NSMutableString alloc] init];
    NSString *strSeparate = @"";
    for (DBModel *aModel in arrModels) {
        [primaryValues appendString:strSeparate];
        [primaryValues appendFormat:@"'%@'", [aModel primaryValue]];
        strSeparate = @",";
    }
    if (primaryValues.length > 0) {
        DBModel *aModel = arrModels[0];
        NSString *strSql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ IN (%@)", [aModel.class tableName], [aModel.class primaryKey], primaryValues];
        FMResultSet *result = [self theDB:db executeQuery:strSql];
        return result.next;
    }
    return YES;
}

+ (BOOL)theDB:(FMDatabase *)db isExistModel:(DBModel *)aModel
{
    if ([aModel primaryValue] == nil) {
        return NO;
    }
    NSString *strSql = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE (%@='%@')", [aModel.class tableName], [aModel.class primaryKey], [aModel primaryValue]];
    FMResultSet *result = [self theDB:db executeQuery:strSql];
    return result.next;
}

+ (BOOL)theDB:(FMDatabase *)db insertModelList:(NSArray *)arrModels
{
    for (DBModel *aModel in arrModels) {
        BOOL result = [self theDB:db insertModel:aModel];
        if (!result) {
            return result;
        }
    }
    return YES;
}

+ (BOOL)theDB:(FMDatabase *)db forceInsertModelList:(NSArray *)arrModels
{
    if (arrModels.count == 0) {
        return YES;
    }
    NSMutableArray *arrSql = [[NSMutableArray alloc] init];
    for (DBModel *aModel in arrModels) {
        [arrSql addObject:[aModel insertSql]];
    }
    return [self theDB:db executeUpdates:arrSql];
}

#pragma mark -Model Query

+ (DBModel *)theDB:(FMDatabase *)db findModel:(Class)aModelClass withWhereSql:(NSString *)strWhereSql
{
    NSMutableString *strSql = [[NSMutableString alloc] init];
    [strSql appendFormat:@"SELECT * FROM %@ WHERE (%@) LIMIT 1", [aModelClass tableName], strWhereSql];
    FMResultSet *result = [self theDB:db executeQuery:strSql];
    if (result.next) {
        return [aModelClass modelWithFMResult:result];
    }
    return nil;
}

+ (NSArray *)theDB:(FMDatabase *)db findModelList:(Class)aModelClass withWhereSql:(NSString *)strWhereSql orderBy:(NSString *)orderBy
{
    NSMutableString *strSql = [[NSMutableString alloc] init];
    [strSql appendFormat:@"SELECT * FROM %@", [aModelClass tableName]];
    if (strWhereSql.length > 0) {
        [strSql appendFormat:@" WHERE (%@)",strWhereSql];
    }
    if (orderBy.length > 0) {
        if ([self isString:orderBy containString:@"ORDER BY"]) {
            [strSql appendFormat:@" %@", orderBy];
        } else {
            [strSql appendFormat:@" ORDER BY %@", orderBy];
        }
    }
    FMResultSet *result = [self theDB:db executeQuery:strSql];
    NSMutableArray *arr = [[NSMutableArray alloc] init];
    while (result.next) {
        DBModel *aModel = [aModelClass modelWithFMResult:result];
        [arr addObject:aModel];
    }
    return arr;
}

+ (NSArray *)theDB:(FMDatabase *)db findModelList:(Class)aModelClass join:(NSString *)strJoin withWhereSql:(NSString *)strWhereSql orderBy:(NSString *)orderBy
{
    NSMutableString *strSql = [[NSMutableString alloc] init];
    [strSql appendFormat:@"SELECT * FROM %@ %@", [aModelClass tableName], strJoin];
    if (strWhereSql.length > 0) {
        [strSql appendFormat:@" WHERE (%@)",strWhereSql];
    }
    if (orderBy.length > 0) {
        if ([self isString:orderBy containString:@"ORDER BY"]) {
            [strSql appendFormat:@" %@", orderBy];
        } else {
            [strSql appendFormat:@" ORDER BY %@", orderBy];
        }
    }
    FMResultSet *result = [self theDB:db executeQuery:strSql];
    NSMutableArray *arr = [[NSMutableArray alloc] init];
    while (result.next) {
        DBModel *aModel = [aModelClass modelWithFMResult:result];
        [arr addObject:aModel];
    }
    return arr;
}


#pragma mark - Support

+ (BOOL)isString:(NSString *)aStr containString:(NSString *)strContain
{
    if (strContain == nil) {
        return NO;
    }
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_8_0
    return [aStr containsString:strContain];
#else
    NSRange aRange = [aStr rangeOfString:strContain];
    if (aRange.length > 0) {
        return YES;
    }
    return NO;
#endif
}


#pragma mark - 数据库升级

- (void)checkDBUpdate
{
    [[self.class sharedInstance] updateAllDB];
}

@end
