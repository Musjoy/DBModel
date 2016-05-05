//
//  DBManager.h
//  Common
//
//  Created by 黄磊 on 16/4/6.
//  Copyright © 2016年 Musjoy. All rights reserved.
//  <MODULE_DB_MANAGER>

#import <Foundation/Foundation.h>
#ifndef MODULE_DB_MANAGER
#define MODULE_DB_MANAGER
#endif
#import "DBModel.h"
#import "FMDB.h"

@interface DBManager : NSObject

+ (DBManager *)shareInstance;

#pragma mark - Public

/// 请先吊用openDefaultDB，之后才能使用下面的DB操作
- (void)openDefaultDB:(NSString *)dbName withTables:(NSArray *)arrTables;
/// 设置DBModel的时间格式
- (void)setDefalutDateFormat:(NSDateFormatter *)aDateFormatter;

- (BOOL)executeUpdates:(NSArray *)arrSql;
- (FMResultSet *)executeQuery:(NSString *)sql, ...;

#pragma mark -Model Operation

/** 插入Model到数据库 */
+ (BOOL)insertModel:(DBModel *)aModel;
/** 插入数组列表 */
+ (BOOL)insertModelList:(NSArray *)arrModels;
/** 强制插入数据库，不检查是否存在 */
+ (BOOL)forceInsertModelList:(NSArray *)arrModels;
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
