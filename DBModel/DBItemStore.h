//
//  DBItemStore.h
//  Common
//
//  Created by 黄磊 on 16/8/23.
//  Copyright © 2016年 Musjoy. All rights reserved.
//

#import "DBModel.h"

#ifndef FILE_NAME_STORE_KEYS
#define FILE_NAME_STORE_KEYS @"store_key"
#endif

@interface DBItemStore : DBModel

@property (nonatomic, strong) NSNumber<Primary> *storeId;
@property (nonatomic, strong) NSString *storeClass;                     ///< 存储的类名，必须继承DBModel
@property (nonatomic, strong) NSString *relateId;                       ///< 关联Id

@property (nonatomic, strong) NSString *storeData;                      ///< 保存的json字符串

@property (nonatomic, strong) NSString *identifier;                     ///< 储存的标示符

@property (nonatomic, strong) NSNumber<DBInt> *storeOrder;              ///<  存储数据内部排序

/// 保存DBModel数组，该Model必须包含数据库
+ (void)storeItems:(NSArray *)arrItems withClass:(NSString *)aClassName identifier:(NSString *)identifier;

+ (void)storeItems:(NSArray *)arrItems withClass:(NSString *)aClassName identifier:(NSString *)identifier haveDB:(BOOL)haveDB;

+ (__kindof NSArray<DBModel> *)itemsOfClass:(NSString *)aClassName identifier:(NSString *)identifier;

+ (__kindof NSArray<DBModel> *)itemsOfClass:(NSString *)aClassName identifier:(NSString *)identifier orderBy:(NSString *)orderBy;

+ (__kindof NSArray<DBModel> *)itemsOfClass:(NSString *)aClassName identifier:(NSString *)identifier orderBy:(NSString *)orderBy haveDB:(BOOL)haveDB;;


+ (void)deleteItemWithId:(NSString *)relateId ofClass:(NSString *)aClassName identifier:(NSString *)identifier;


@end


@interface DBModel (DBItemStore)

+ (void)storeItems:(NSArray *)arrItems identifier:(NSString *)identifier;

+ (__kindof NSArray<DBModel> *)theStoreItemsWithIdentifier:(NSString *)identifier;

+ (NSArray<DBModel> *)theStoreItemsWithIdentifier:(NSString *)identifier orderBy:(NSString *)orderBy;

+ (void)setItems:(NSArray *)arrItems withKey:(NSString *)key;

+ (__kindof NSArray<DBModel> *)itemsWithKey:(NSString *)key;

@end
