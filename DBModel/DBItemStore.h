//
//  DBItemStore.h
//  Common
//
//  Created by 黄磊 on 16/8/23.
//  Copyright © 2016年 Musjoy. All rights reserved.
//

#import <DBModel/DBModel.h>

#ifndef FILE_NAME_STORE_KEYS
#define FILE_NAME_STORE_KEYS @"store_key"
#endif

@interface DBItemStore : DBModel

@property (nonatomic, strong) NSNumber<Primary> *storeId;
@property (nonatomic, strong) NSString *storeClass;                     ///< 存储的类名，必须继承DBModel
@property (nonatomic, strong) NSString *relateId;                       ///< 关联Id

@property (nonatomic, strong) NSString *identifier;                     ///< 储存的标示符

@property (nonatomic, strong) NSNumber<DBInt> *storeOrder;              ///<  存储数据内部排序


+ (__kindof NSArray<DBModel> *)itemsOfClass:(NSString *)aClassName identifier:(NSString *)identifier orderBy:(NSString *)orderBy;

+ (__kindof NSArray<DBModel> *)itemsOfClass:(NSString *)aClassName identifier:(NSString *)identifier;

+ (void)storeItems:(NSArray *)arrItems withClass:(NSString *)aClassName identifier:(NSString *)identifier;

+ (void)deleteItemWithId:(NSString *)relateId ofClass:(NSString *)aClassName identifier:(NSString *)identifier;


@end


@interface DBModel (DBItemStore)

+ (__kindof NSArray<DBModel> *)theStoreItemsWithIdentifier:(NSString *)identifier;

+ (NSArray<DBModel> *)theStoreItemsWithIdentifier:(NSString *)identifier orderBy:(NSString *)orderBy;

+ (void)storeItems:(NSArray *)arrItems identifier:(NSString *)identifier;

@end