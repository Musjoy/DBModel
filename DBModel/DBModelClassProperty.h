//
//  DBModelClassProperty.h
//  Common
//
//  Created by 黄磊 on 16/4/6.
//  Copyright © 2016年 Musjoy. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface DBModelClassProperty : NSObject


/** The name of the declared property (not the ivar name) */
@property (copy, nonatomic) NSString* name;

/** A property class type  */
@property (assign, nonatomic) Class type;

/** A string of class type  */
@property (assign, nonatomic) NSString *typeName;

/** Struct name if a struct */
@property (strong, nonatomic) NSString* structName;

/** The name of the protocol the property conforms to (or nil) */
@property (copy, nonatomic) NSString* protocol;

/** If YES, it can be used as primary key */
@property (assign, nonatomic) BOOL isPrimary;

/** If YES, it can be missing in the input data, and the input would be still valid */
@property (assign, nonatomic) BOOL isOptional;

/** If NO - don't call any transformers on this property's value */
@property (assign, nonatomic) BOOL isAllowedClassype;

/** If YES - don't parser this from json */
@property (assign, nonatomic) BOOL isJsonIgnore;

/** If YES - don't save it in DB */
@property (assign, nonatomic) BOOL isDBIgnore;

/** If YES - it is a sub class of DBModel */
@property (assign, nonatomic) BOOL isDBModel;

/** If YES - create a mutable object for the value of the property */
@property (assign, nonatomic) BOOL isMutable;

/** If YES - create models on demand for the array members */
@property (assign, nonatomic) BOOL convertsOnDemand;

/** If YES - the value of this property determines equality to other models */
@property (assign, nonatomic) BOOL isIndex;


@end
