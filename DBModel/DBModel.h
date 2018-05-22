//
//  DBModel.h
//  Common
//
//  Created by 黄磊 on 16/4/6.
//  Copyright © 2016年 Musjoy. All rights reserved.
//  Json数据库模型<MODULE_DB_MODEL>

#import <Foundation/Foundation.h>
#ifdef MODULE_DB_MANAGER
#import <FMDB/FMDB.h>


/** 主键 */
@protocol Primary <NSObject>

@end

/** Int类型 */
@protocol DBInt <NSObject>

@end

/** Bool类型 */
@protocol DBBool <NSObject>

@end

/** float类型 */
@protocol DBFloat <NSObject>

@end

/** double类型 */
@protocol DBDouble <NSObject>

@end

/** json解析中忽略该字段 */
@protocol JsonIgnore <NSObject>

@end

/** 数据库存储忽略该字段 */
@protocol DBIgnore <NSObject>

@end

#endif

/** DBModel */
@protocol DBModel <NSObject>

@end

@interface DBModel : NSObject

#pragma mark - Public

#pragma mark - Data Format

+ (void)setDateFormat:(NSDateFormatter *)aDateFormatter;

+ (NSDate *)dateFromString:(NSString *)aDateStr;

+ (NSString *)stringFromDate:(NSDate *)aDate;


#pragma mark - JSON

+ (id)objectFromJSONString:(NSString *)string error:(NSError **)err;

+ (id)objectFromJSONData:(NSData *)data error:(NSError **)err;

- (instancetype)initWithDictionary:(NSDictionary*)dict error:(NSError**)err;

- (instancetype)initWithData:(NSData *)data error:(NSError **)err;

- (instancetype)initWithString:(NSString *)string usingEncoding:(NSStringEncoding)encoding error:(NSError **)err;

- (instancetype)initWithString:(NSString *)string error:(NSError **)err;


+ (NSMutableArray*)arrayOfModelsFromDictionaries:(NSArray*)array error:(NSError**)err;

- (NSDictionary *)toDictionary;

- (NSString *)toJSONString;


#pragma mark - SQL

#ifdef MODULE_DB_MANAGER

/** 创建table */
+ (NSString *)createTableSql;
/** 用已存在的table结构创建或更新table */
+ (NSArray *)createOrUpdateTableSqlsWith:(FMResultSet *)tableResult;
/** 返回该类的TableName */
+ (NSString *)tableName;
/** 该属性的长度 */
+ (int)lengthFor:(NSString *)property;
/** 返回该字段的默认值, 无则返回nil, 字符串默认值需自己加单引号 */
+ (NSString *)defaultValueFor:(NSString *)property;
/** 对应主键是否自增 */
+ (BOOL)isPrimaryKeyAutoIncrement:(NSString *)property;
/** 返回NSNumber的数据类型，可重写该方法定义数据类型 */
+ (NSString *)typeNameForNumber:(NSString *)property;

/** 该Model的主键 */
+ (NSString *)primaryKey;
/** 改Model得主键键值 */
- (NSString *)primaryValue;


/** 从FMResultSet中获取对应Model */
+ (instancetype)modelWithFMResult:(FMResultSet *)result;

- (NSString *)insertSql;

- (NSString *)updateSqlFormFMResult:(FMResultSet *)result;

#endif

@end


#pragma mark - Category

@interface NSString (DBModel)

/** 将json字符串解析成object */
- (id)objectFromJSONString;

@end


