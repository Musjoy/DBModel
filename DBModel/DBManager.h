//
//  DBManager.h
//  Common
//
//  Created by 黄磊 on 16/4/6.
//  Copyright © 2016年 Musjoy. All rights reserved.
//  数据库管理<MODULE_DB_MANAGER>

#import <Foundation/Foundation.h>
#import "DBModel.h"
#import "FMDB.h"

#ifndef FILE_NAME_DB_CONFIG
#define FILE_NAME_DB_CONFIG @"db_config"
#endif

/** 最后一次数据库检查的app版本 */
#ifndef kDBLastCheckVersion
#define kDBLastCheckVersion @"DBLastCheckVersion-"
#endif

//#define DB_NEED_HOST_PREFIX :to use kServerBaseHost as prefix of the db file name
//#define DB_HIDE_DB_FILE :to hide db file in NSLibraryDirectory (Only use for release)

@interface DBManager : NSObject

+ (DBManager *)sharedInstance;

/// 加载默认配置:
/// 1、定义了<DEFAULT_DB_NAME>，默认打开名称为<DEFAULT_DB_NAME>的数据库，默认创建<DEFAULT_DB_TABLE_LIST>中定义的表
/// 2、如果未定义<DEFAULT_DB_NAME>，寻找名字为<FILE_NAME_DB_CONFIG>的配置文件，根据字段theDBName和theTableList初始化数据
+ (void)configure;

#pragma mark - Public

/// 打开指定的数据库，如果不存在则创建
- (void)openDefaultDB:(NSString *)dbName withTables:(NSArray *)arrTables;
/// 打开项目中的DB，仅供测试使用，请勿使用
- (void)openLibDB:(NSString *)dbName withTables:(NSArray *)arrTables __attribute__((deprecated("This just for testing, use openDefaultDB:withTables:")));
/// 设置DBModel的时间格式
- (void)setDefalutDateFormat:(NSDateFormatter *)aDateFormatter;

/// 在默认数据库中执行SQL语句，请先吊用openDefaultDB，之后才能使用下面的DB操作
- (BOOL)executeUpdates:(NSArray *)arrSql;
- (FMResultSet *)executeQuery:(NSString *)sql, ...;

/// 关闭默认数据库
- (void)closeDefaultDB;

#pragma mark -Model Operation

/** 插入Model到数据库 */
+ (BOOL)insertModel:(DBModel *)aModel;
/** 插入Model到数据库，并获得插入model的主键ID */
+ (long long)insertModelGetId:(DBModel *)aModel;
/** 插入数组列表 */
+ (BOOL)insertModelList:(NSArray *)arrModels;
/** 强制插入数据库，不检查是否存在 */
+ (BOOL)forceInsertModelList:(NSArray *)arrModels;
/** 插入列表中不存在于DB中的Model */
+ (BOOL)insertModelListWhileNotExist:(NSArray *)arrModels;
/** 更新model */
+ (BOOL)updateModel:(DBModel *)aModel;
+ (BOOL)updateModelList:(NSArray *)arrModels;
/** 删除model */
+ (BOOL)deleteModelList:(NSArray *)arrModels;

/** 用dicCondition条件查询单个Model */
+ (__kindof DBModel *)findModel:(Class)aModelClass inCondition:(NSDictionary *)dicCondition;
/** 用strSql条件查询单个Model */
+ (__kindof DBModel *)findModel:(Class)aModelClass withWhereSql:(NSString *)strWhereSql;

/** 用dicCondition条件查询Model列表 */
+ (NSArray *)findModelList:(Class)aModelClass inCondition:(NSDictionary *)dicCondition;
+ (NSArray *)findModelList:(Class)aModelClass inCondition:(NSDictionary *)dicCondition orderBy:(NSString *)orderBy;
/** 用strSql条件查询Model列表 */
+ (NSArray *)findModelList:(Class)aModelClass withWhereSql:(NSString *)strWhereSql;
+ (NSArray *)findModelList:(Class)aModelClass withWhereSql:(NSString *)strWhereSql orderBy:(NSString *)orderBy;
+ (NSArray *)findModelList:(Class)aModelClass join:(NSString *)strJoin withWhereSql:(NSString *)strWhereSql orderBy:(NSString *)orderBy;

/** 取个数 */
+ (int)countFromModel:(Class)aModelClass inCondition:(NSDictionary *)dicCondition;
+ (int)countFromModel:(Class)aModelClass withWhereSql:(NSString *)strWhereSql;


#pragma mark - Other DB

+ (BOOL)theDB:(FMDatabase *)db executeUpdates:(NSArray *)arrSql;
+ (FMResultSet *)theDB:(FMDatabase *)db executeQuery:(NSString *)sql, ...;

/** 插入Model到数据库 */
+ (BOOL)theDB:(FMDatabase *)db insertModel:(DBModel *)aModel;
/** 插入数组列表 */
+ (BOOL)theDB:(FMDatabase *)db insertModelList:(NSArray *)arrModels;
/** 强制插入数据库，不检查是否存在 */
+ (BOOL)theDB:(FMDatabase *)db forceInsertModelList:(NSArray *)arrModels;
/** 更新model */
+ (BOOL)theDB:(FMDatabase *)db updateModel:(DBModel *)aModel;
+ (BOOL)theDB:(FMDatabase *)db updateModelList:(NSArray *)arrModels;
/** 删除model */
+ (BOOL)theDB:(FMDatabase *)db deleteModelList:(NSArray *)arrModels;

/** 用strSql条件查询单个Model */
+ (__kindof DBModel *)theDB:(FMDatabase *)db findModel:(Class)aModelClass withWhereSql:(NSString *)strWhereSql;
/** 用strSql条件查询Model列表 */
+ (NSArray *)theDB:(FMDatabase *)db findModelList:(Class)aModelClass withWhereSql:(NSString *)strWhereSql orderBy:(NSString *)orderBy;
+ (NSArray *)theDB:(FMDatabase *)db findModelList:(Class)aModelClass join:(NSString *)strJoin withWhereSql:(NSString *)strWhereSql orderBy:(NSString *)orderBy;


#pragma mark -

/** 数据库升级检查 */
- (void)checkDBUpdate;

@end
