//
//  DBTableInfo.h
//  Common
//
//  Created by 黄磊 on 16/4/6.
//  Copyright © 2016年 Musjoy. All rights reserved.
//

#import "DBModel.h"

@interface DBTableInfo : DBModel


@property (nonatomic, strong) NSNumber<Primary> *cid;                   /** 列ID */
@property (nonatomic, strong) NSString *name;                           /** 列名称 */
@property (nonatomic, strong) NSString *type;                           /** 列类型 */
@property (nonatomic, strong) NSNumber<DBInt> *notnull;                 /** 是否不为空 */
@property (nonatomic, strong) NSString *dflt_value;                     /** 默认值 */
@property (nonatomic, strong) NSNumber<DBInt> *pk;                      /** 是否为主键 */


@end
