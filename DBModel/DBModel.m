//
//  DBModel.m
//  Common
//
//  Created by 黄磊 on 16/4/6.
//  Copyright © 2016年 Musjoy. All rights reserved.
//

#import "DBModel.h"
#import <DBModel/DBModelClassProperty.h>
#import <objc/runtime.h>
#ifdef MODULE_DB_MANAGER
#import <DBModel/DBTableInfo.h>
#endif

static const char * kClassPropertiesKey;
static const char * kClassPrimaryKey;

static NSDictionary *s_dicErrors = nil;

static NSArray *s_allowedClassTypes = nil;
static NSArray *s_allowedPrimitiveTypes = nil;
static NSDictionary *s_primitivesNames = nil;
static NSDictionary *s_dicTypeDBNames = nil;

static NSDateFormatter *s_dataFormatter = nil;

static Class s_DBModelClass = NULL;


@implementation DBModel


#pragma mark - initialization methods

+ (void)load
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // initialize all class static objects,
        
        @autoreleasepool {
            
            s_dicErrors = @{    @"-10001" : @"Json data is nil",
                                @"-10002" : @"Model init failed",
                                @"-10003" : @"Not a NSDictionary type",// @"初始化所需的数据不是NSDictionary类型",
                                @"-10004" : @"Not a json data"};
            
            s_allowedClassTypes = @[
                                 [NSString class], [NSNumber class], [NSDecimalNumber class], //immutable JSON classes
                                 [NSMutableString class], //mutable JSON classes
                                 [NSDate class]];
            
            s_allowedPrimitiveTypes = @[
                                      @"BOOL", @"float", @"int", @"long", @"double", @"short",
                                      //and some famous aliases
                                      @"NSInteger", @"NSUInteger",
                                      @"Block"
                                      ];
            
            s_primitivesNames = @{@"f":@"float", @"i":@"int", @"d":@"double", @"l":@"long", @"c":@"BOOL", @"s":@"short", @"q":@"long",
                                 //and some famos aliases of primitive types
                                 // BOOL is now "B" on iOS __LP64 builds
                                 @"I":@"NSInteger", @"Q":@"NSUInteger", @"B":@"BOOL",
                                 
                                 @"@?":@"Block"};
            
            s_dicTypeDBNames = @{@"int":@"INT",
                                 @"long":@"INT",
                                 @"short":@"INT",
                                 @"NSInteger":@"INT",
                                 @"NSUInteger":@"INT",
                                 @"float":@"FLOAT",
                                 @"double":@"DOUBLE",
                                 @"BOOL":@"BOOL",
                                 @"NSString":@"VARCHAR",
                                 @"NSMutableString":@"VARCHAR",
                                 @"NSNumber":@"FLOAT",
                                 @"NSDate":@"DATETIME"};
            
            // Using NSClassFromString instead of [DBModel class], as this was breaking unit tests, see below
            //http://stackoverflow.com/questions/21394919/xcode-5-unit-test-seeing-wrong-class
            s_DBModelClass = NSClassFromString(NSStringFromClass(self));
        }
    });
}

+ (NSError *)errorWithCode:(NSInteger)code
{
    NSString *errDesc = [s_dicErrors objectForKey:[NSString stringWithFormat:@"%d", (int)code]];
    if (!errDesc) {
        errDesc = @"";
    }
    NSError *err = [NSError errorWithDomain:@"DBModel"
                                       code:code
                                   userInfo:@{NSLocalizedDescriptionKey:errDesc,
                                              NSLocalizedFailureReasonErrorKey:errDesc}];
    return err;
}

#pragma mark - Public

+ (void)setDateFormat:(NSDateFormatter *)aDateFormatter
{
    s_dataFormatter = aDateFormatter;
}

+ (NSDate *)dateFromString:(NSString *)aDateStr
{
    NSDate *date = nil;
    if ([aDateStr isKindOfClass:[NSString class]]) {
        if (s_dataFormatter) {
            date = [s_dataFormatter dateFromString:aDateStr];
            if (date) {
                return date;
            }
        }
    } else if ([aDateStr isKindOfClass:[NSNumber class]]) {
        aDateStr = [(NSNumber *)aDateStr stringValue];
    } else {
        return date;
    }
    if (date == nil) {
        date = [NSDate dateWithTimeIntervalSince1970:[[aDateStr substringToIndex:10] longLongValue]];
    }
    return date;
}

+ (NSString *)stringFromDate:(NSDate *)aDate
{
    if (s_dataFormatter) {
        return [s_dataFormatter stringFromDate:aDate];
    }
    return [aDate description];
}


#pragma mark - JSON

+ (id)objectFromJSONString:(NSString *)string error:(NSError *__autoreleasing *)err
{
    //check for nil input
    if (!string) {
        if (err) *err = [self.class errorWithCode:-10001];
        return nil;
    }
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    NSError* initError = nil;
    id obj = [self objectFromJSONData:data error:&initError];
    if (!obj) {
        if (err) *err = initError;
    }
    return obj;
}

+ (id)objectFromJSONData:(NSData *)data error:(NSError *__autoreleasing *)err
{
    // check for nil input
    if (!data) {
        if (err) *err = [self.class errorWithCode:-10001];
        return nil;
    }
    // read the json
    NSError* initError = nil;
    id obj = nil;
    @try {
        obj = [NSJSONSerialization JSONObjectWithData:data
                                              options:kNilOptions
                                                error:&initError];
    }
    @catch (NSException *exception) {
        if (!initError) {
            initError = [self.class errorWithCode:-10004];
        }
    }
    @finally {
        if (initError) {
            if (err) *err = [self.class errorWithCode:-10004];
            return nil;
        }
        
        return obj;
    }
    
}


- (instancetype)initWithDictionary:(NSDictionary*)dict error:(NSError *__autoreleasing *)err
{
    //check for nil input
    if (!dict) {
        if (err) *err = [self.class errorWithCode:-10001];
        return nil;
    }
    
    //invalid input, just create empty instance
    if (![dict isKindOfClass:[NSDictionary class]]) {
        if (err) *err = [self.class errorWithCode:-10003];
        return nil;
    }
    
    //create a class instance
    self = [self init];
    if (!self) {
        // super init didn't succeed
        if (err) *err = [self.class errorWithCode:-10002];
        return nil;
    }
    
    // import the data from a dictionary
    NSArray *arrProperty = [self.class __properties];
    
    for (DBModelClassProperty *p in arrProperty) {
        if (p.isJsonIgnore) {
            continue;
        }
        id aValue = [dict objectForKey:p.name];
        if (aValue == nil || [aValue isKindOfClass:[NSNull class]]) {
            continue;
        }
        if (p.type && !p.isAllowedClassype) {
            if ([p.type isSubclassOfClass:[NSDictionary class]]) {
                if ([aValue isKindOfClass:[NSDictionary class]]) {
                    [self setValue:aValue forKey:p.name];
                }
            } else if (p.isDBModel) {
                
                if (aValue && [aValue isKindOfClass:[NSDictionary class]]) {
                    NSError *aErr = nil;
                    id value = [[p.type alloc] initWithDictionary:aValue error:&aErr];
                    if (value == nil) {
                        *err = aErr;
                        return nil;
                    }
                    [self setValue:value forKey:p.name];
                } else if (aValue && [aValue isKindOfClass:[NSString class]] && [aValue length] > 0) {
                    NSError *aErr = nil;
                    id value = [[p.type alloc] initWithString:aValue error:&aErr];
                    if (value == nil) {
                        *err = aErr;
                        return nil;
                    }
                    [self setValue:value forKey:p.name];
                }
            } else if ([p.type isSubclassOfClass:[NSArray class]]) {
                id aValue = [dict objectForKey:p.name];
                if ([aValue isKindOfClass:[NSArray class]]) {
                    if (p.protocol.length > 0 && [aValue count] != 0) {
                        Class protocolClass = NSClassFromString(p.protocol);
                        if (protocolClass && [self.class __isJSONModelSubClass:protocolClass]) {
                            // 包含DBModel的数组
                            NSError *aErr = nil;
                            NSMutableArray* list = [[protocolClass class] arrayOfModelsFromDictionaries:aValue error:&aErr];
                            if (list == nil) {
                                *err = aErr;
                                return nil;
                            }
                            [self setValue:list forKey:p.name];
                        }
                    } else {
                        [self setValue:aValue forKey:p.name];
                    }
                }
            } else if ([p.type isSubclassOfClass:[NSObject class]]) {
                [self setValue:aValue forKey:p.name];
            }
            continue;
        }
        
        if ([p.type isSubclassOfClass:[NSDate class]]) {
            if (![aValue isKindOfClass:[NSDate class]]) {
                aValue = [self.class dateFromString:aValue];
            }
        } else if ([p.type isSubclassOfClass:[NSNumber class]]) {
            if ([aValue isKindOfClass:[NSString class]]) {
                if ([p.typeName hasPrefix:@"INT"]) {
                    aValue = [NSNumber numberWithInt:[aValue intValue]];
                } else if ([p.typeName isEqualToString:@"BOOL"]) {
                    aValue = [NSNumber numberWithBool:[aValue boolValue]];
                } else if ([p.typeName isEqualToString:@"FLOAT"]) {
                    aValue = [NSNumber numberWithFloat:[aValue floatValue]];
                } else if ([p.typeName isEqualToString:@"DOUBLE"]) {
                    aValue = [NSNumber numberWithDouble:[aValue doubleValue]];
                }
            }
        } else if ([p.type isSubclassOfClass:[NSString class]]) {
            if ([aValue isKindOfClass:[NSNumber class]]) {
                aValue = [aValue stringValue];
            }
        }
        if (aValue) {
            [self setValue:aValue forKey:p.name];
        }
    }
    
    // model is valid! yay!
    return self;
}

- (instancetype)initWithData:(NSData *)data error:(NSError *__autoreleasing *)err
{
    
    //read the json
    NSError* initError = nil;
    id obj = [self.class objectFromJSONData:data error:&initError];
    
    if (!obj) {
        if (err) *err = initError;
        return nil;
    }
    
    //init with dictionary
    id objModel = [self initWithDictionary:obj error:&initError];
    if (initError && err) *err = initError;
    return objModel;
}

- (instancetype)initWithString:(NSString *)string usingEncoding:(NSStringEncoding)encoding error:(NSError *__autoreleasing *)err
{
    //check for nil input
    if (!string) {
        if (err) *err = [self.class errorWithCode:-10001];
        return nil;
    }
    
    NSError *initError = nil;
    id objModel = [self initWithData:[string dataUsingEncoding:encoding] error:&initError];
    if (initError && err) *err = initError;
    return objModel;
}

- (instancetype)initWithString:(NSString *)string error:(NSError *__autoreleasing *)err
{
    NSError *initError = nil;
    id objModel = [self initWithString:string usingEncoding:NSUTF8StringEncoding error:&initError];
    if (initError && err) *err = initError;
    return objModel;
}


+ (NSMutableArray *)arrayOfModelsFromDictionaries:(NSArray*)array error:(NSError**)err
{
    //bail early
    if (array == nil || array.count == 0) return nil;
    
    //parse dictionaries to objects
    NSMutableArray* list = [NSMutableArray arrayWithCapacity: [array count]];
    
    for (id d in array) {
        if ([d isKindOfClass:NSDictionary.class]) {
            NSError *aErr = nil;
            id obj = [[self alloc] initWithDictionary:d error:&aErr];
            if (obj == nil) {
                *err = aErr;
                return nil;
            }
            
            [list addObject: obj];
        } else if ([d isKindOfClass:NSArray.class]) {
            [list addObjectsFromArray:[self arrayOfModelsFromDictionaries:d error:err]];
        } else {
            // This is very bad
        }
        
    }
    
    return list;
}

- (NSDictionary *)toDictionary
{
    // import the data from a dictionary
    NSArray *arrProperty = [self.class __properties];
    NSMutableDictionary *dicTmp = [[NSMutableDictionary alloc] init];
    for (DBModelClassProperty *p in arrProperty) {
        if (p.type && !p.isAllowedClassype) {
            id aValue = [self valueForKey:p.name];
            if (aValue == nil) {
                continue;
            }
            if ([p.type isSubclassOfClass:[NSDictionary class]]) {
                if ([aValue isKindOfClass:[NSDictionary class]]) {
                    [dicTmp setObject:aValue forKey:p.name];
                }
            }
            else if ([p.type isSubclassOfClass:[NSArray class]]) {
                if ([aValue isKindOfClass:[NSArray class]]) {
                    NSMutableArray *arrTmp = [[NSMutableArray alloc] init];
                    for (id object in aValue) {
                        if ([object isKindOfClass:[NSDictionary class]]) {
                            [arrTmp addObject:object];
                        }
                        else if ([object isKindOfClass:[DBModel class]]) {
                            [arrTmp addObject:[object toDictionary]];
                        }
                        else if ([object respondsToSelector:@selector(toDictionary)]) {
                            NSDictionary *aDic = [object toDictionary];
                            if (aDic) {
                                [arrTmp addObject:aDic];
                            }
                        }
                        else if ([object isKindOfClass:NSString.class] || [object isKindOfClass:NSNumber.class]) {
                            [arrTmp addObject:object];
                        }
                    }
                    [dicTmp setObject:arrTmp forKey:p.name];
                }
            }
            else if (p.isDBModel) {
                if (aValue) {
                    if ([aValue isKindOfClass:[DBModel class]]) {
                        NSDictionary *dicValue = [aValue toDictionary];
                        [dicTmp setObject:dicValue forKey:p.name];
                    }
                    else if ([aValue isKindOfClass:[NSDictionary class]]) {
                        [dicTmp setObject:aValue forKey:p.name];
                    }
                }
            } else if ([aValue respondsToSelector:@selector(toDictionary)]) {
                NSDictionary *aDic = [aValue toDictionary];
                if (aDic) {
                    [dicTmp setObject:aDic forKey:p.name];
                }
            }
            continue;
        }
        id value = [self valueForKey:p.name];
        if (value == nil) {
            continue;
        }
        if ([value isKindOfClass:[NSDate class]]) {
            value = [DBModel stringFromDate:value];
        }
        [dicTmp setObject:value forKey:p.name];
    }
    return dicTmp;
}

- (NSString *)toJSONString
{
    NSData* jsonData = nil;
    NSError* jsonError = nil;
    
    @try {
        NSDictionary* dict = [self toDictionary];
        jsonData = [NSJSONSerialization dataWithJSONObject:dict options:kNilOptions error:&jsonError];
    }
    @catch (NSException *exception) {
        //this should not happen in properly design DBModel
        //usually means there was no reverse transformer for a custom property
        NSLog(@"EXCEPTION: %@", exception.description);
        return nil;
    }
    
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

#pragma mark - DB

+ (NSString *)typeNameForNumber:(NSString *)property
{
    return @"FLOAT";
}

+ (BOOL)isDBIgnoreForNumber:(NSString *)property
{
    return NO;
}

#ifdef MODULE_DB_MANAGER

+ (NSString *)createTableSql
{
    NSString *tableName = [self tableName];
    if (tableName.length == 0) {
        return nil;
    }
    NSMutableString *sqlStr = [[NSMutableString alloc] init];
    [sqlStr appendFormat:@"CREATE TABLE IF NOT EXISTS %@(", tableName];
    NSArray *arrProperty = [self __properties];
    NSString *separateStr = @"";
    for (DBModelClassProperty *p in arrProperty) {
        if (p.isDBIgnore || (p.type && !p.isAllowedClassype)) {
            continue;
        }
        [sqlStr appendString:separateStr];
        [sqlStr appendString:[self descForProperty:p]];
        separateStr = @", ";
    }
    if (separateStr.length == 0) {
        // 未找到任何字段，则不能创建table
        return nil;
    }
    [sqlStr appendString:@")"];
    return sqlStr;
}

+ (NSArray *)createOrUpdateTableSqlsWith:(FMResultSet *)tableResult
{
    if (![tableResult.parentDB tableExists:[self tableName]]) {
        // 如果没有找到以前table，就直接创建
        NSString *strSql = [self createTableSql];
        if (strSql.length > 0) {
            return @[strSql];
        }
        return @[];
    }
    
    // 对比数据库
    NSMutableDictionary *dicOld = [[NSMutableDictionary alloc] init];
    
    while (tableResult.next) {
        DBTableInfo *aTableInfo = [DBTableInfo modelWithFMResult:tableResult];
        [dicOld setObject:aTableInfo forKey:aTableInfo.name];
    }
    
    NSMutableArray *arrSqls = [[NSMutableArray alloc] init];
    NSString *strPrefix = [NSString stringWithFormat:@"ALTER TABLE %@", [self tableName]];
    NSArray *arrProperty = [self __properties];
    for (DBModelClassProperty *p in arrProperty) {
        if (p.isDBIgnore || (p.type && !p.isAllowedClassype)) {
            continue;
        }
        DBTableInfo *aTableInfo = [dicOld objectForKey:p.name];
        if (aTableInfo) {
            // TODO:这里后面可以添加字段类型比较
            continue;
        }
        NSString *strSql = [NSString stringWithFormat:@"%@ ADD COLUMN %@;", strPrefix, [self descForProperty:p]];
        [arrSqls addObject:strSql];
    }
    return arrSqls;
}

+ (NSString *)descForProperty:(DBModelClassProperty *)p
{
    NSMutableString *strDesc = [[NSMutableString alloc] init];
    [strDesc appendFormat:@"%@ ", p.name];               // 名称
    [strDesc appendString:p.typeName];                   // 类型
    if ([p.typeName hasSuffix:@"CHAR"]) {
        int length = [self lengthFor:p.name];
        if (length == 0) {
            length = 255;
        }
        [strDesc appendFormat:@"(%d)", length];          // 长度
    }
    if (p.isPrimary) {
        if ([p.type isSubclassOfClass:[NSNumber class]] && [self isPrimaryKeyAutoIncrement:p.name]) {
            [strDesc appendString:@" PRIMARY KEY AUTOINCREMENT"];
        } else {
            [strDesc appendString:@" PRIMARY KEY NOT NULL"];
        }
    }
    // 默认值设置
    NSString *defaultValue = [self defaultValueFor:p.name];
    if (defaultValue.length > 0) {
        [strDesc appendFormat:@" DEFAULT %@", defaultValue];
    }
    return strDesc;
}

+ (NSString *)tableName
{
    return NSStringFromClass([self class]);
}

+ (int)lengthFor:(NSString *)property
{
    return 0;
}

+ (NSString *)defaultValueFor:(NSString *)property
{
    return nil;
}

+ (BOOL)isPrimaryKeyAutoIncrement:(NSString *)property
{
    return NO;
}

+ (NSString *)primaryKey
{
    NSString *aPrimaryKey = objc_getAssociatedObject(self.class, &kClassPrimaryKey);
    if (aPrimaryKey == nil) {
        // if here, the class needs to inspect itself
        [self __setup];
        aPrimaryKey = objc_getAssociatedObject(self.class, &kClassPrimaryKey);
        if (aPrimaryKey == nil) {
            LogError(@" { %@ } don't have a primary key", NSStringFromClass(self.class));
        }
    }
    return aPrimaryKey;
}

- (NSString *)primaryValue
{
    NSString *key = [self.class primaryKey];
    id value = [self valueForKey:key];
    if ([value isKindOfClass:[NSString class]]) {
        return value;
    } else {
        return [value stringValue];
    }
}

+ (DBModel *)modelWithFMResult:(FMResultSet *)result
{
    NSArray *arrProperty = [self __properties];
    DBModel *model = [[self alloc] init];
    for (DBModelClassProperty *p in arrProperty) {
        if (p.isDBIgnore || (p.type && !p.isAllowedClassype)) {
            continue;
        }
        if ([p.type isSubclassOfClass:[NSDate class]]) {
            id value = [result dateForColumn:p.name];
            [model setValue:value forKey:p.name];
            continue;
        }
        // 获取对应value
        id value = [result objectForColumn:p.name];
        if (value && ![value isKindOfClass:[NSNull class]]) {
            [model setValue:value forKey:p.name];
        }
    }
    return model;
}

- (NSString *)insertSql
{
    NSMutableString *strSql = [[NSMutableString alloc] init];
    [strSql appendFormat:@"INSERT INTO %@(", [self.class tableName]];
    NSMutableString *strValue = [@"VALUES(" mutableCopy];
    NSArray *arrProperty = [self.class __properties];
    NSString *strSeparateStr = @"";
    for (DBModelClassProperty *p in arrProperty) {
        if (p.isDBIgnore || (p.type && !p.isAllowedClassype)) {
            continue;
        }
        id value = [self valueForKey:p.name];
        if (value == nil) {
            continue;
        }
        [strSql appendString:strSeparateStr];
        [strValue appendString:strSeparateStr];
        [strSql appendString:p.name];
        if ([p.typeName hasSuffix:@"CHAR"]) {
            if ([value isKindOfClass:[NSNumber class]]) {
                value = [value stringValue];
            }
            value = [value stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
            [strValue appendFormat:@"'%@'", value];
        } else if ([p.typeName isEqualToString:@"DATETIME"]) {
            [strValue appendFormat:@"'%@'", [self.class stringFromDate:value]];
        } else if ([value isKindOfClass:[NSNumber class]]) {
            [strValue appendString:[value stringValue]];
        } else {
            [strValue appendFormat:@"'%@'", value];
        }
        strSeparateStr = @", ";
    }
    [strSql appendString:@") "];
    [strValue appendString:@")"];
    [strSql appendString:strValue];
    return strSql;
}

- (NSString *)updateSqlFormFMResult:(FMResultSet *)result
{
    
    NSMutableString *strSql = [[NSMutableString alloc] init];
    [strSql appendFormat:@"UPDATE %@ SET", [self.class tableName]];
    NSArray *arrProperty = [self.class __properties];
    
    BOOL hasUpdate = NO;
    
    NSString *strSeparateStr = @"";
    for (DBModelClassProperty *p in arrProperty) {
        if (p.isDBIgnore || (p.type && !p.isAllowedClassype)) {
            continue;
        }
        id newValue = [self valueForKey:p.name];
        NSString *newValueStr = nil;
        if (newValue == nil || [newValue isKindOfClass:[NSNull class]]) {
            continue;
        }
        
        if ([p.typeName hasSuffix:@"CHAR"]) {
            NSString *oldValue = [result stringForColumn:p.name];
            if ([newValue isKindOfClass:[NSNumber class]]) {
                newValue = [newValue stringValue];
            }
            newValue = [newValue stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
            if (oldValue == nil || ![newValue isEqualToString:oldValue]) {
                newValueStr = [NSString stringWithFormat:@"'%@'", newValue];
            }
        } else if ([p.typeName isEqualToString:@"DATETIME"]) {
            newValueStr = [NSString stringWithFormat:@"'%@'", [DBModel stringFromDate:newValue]];
        } else {
            // NSNumber
            if (![newValue isKindOfClass:[NSNumber class]]) {
                LogError(@" %@ need a number but a %@", p.name, NSStringFromClass(newValue));
                continue;
            }
            if ([p.typeName hasPrefix:@"INT"]) {
                int oldValue = [result intForColumn:p.name];
                int newNumValue = [newValue intValue];
                if (newNumValue != oldValue) {
                    newValueStr = [newValue stringValue];
                }
            } else if ([p.typeName isEqualToString:@"BOOL"]) {
                BOOL oldValue = [result intForColumn:p.name];
                BOOL newNumValue = [newValue boolValue];
                if (newNumValue != oldValue) {
                    newValueStr = newNumValue?@"1":@"0";
                }
            } else {
                newValueStr = [newValue stringValue];
            }
        }
        if (newValueStr.length > 0) {
            [strSql appendString:strSeparateStr];
            [strSql appendFormat:@" %@=%@", p.name, newValueStr];
            strSeparateStr = @",";
            hasUpdate = YES;
        }
    }
    
    if (!hasUpdate) {
        return nil;
    }
    
    [strSql appendFormat:@" WHERE (%@='%@')", [self.class primaryKey], [self primaryValue]];
    return strSql;
}

#endif

#pragma mark - Private

+ (NSArray *)__properties
{
    // fetch the associated object
    NSDictionary* classProperties = objc_getAssociatedObject(self.class, &kClassPropertiesKey);
    if (classProperties) return [classProperties allValues];
    
    // if here, the class needs to inspect itself
    [self __setup];
    
    // return the property list
    classProperties = objc_getAssociatedObject(self.class, &kClassPropertiesKey);
    return [classProperties allValues];
}

+ (void)__setup
{
    // if first instance of this model, generate the property list
    if (!objc_getAssociatedObject(self.class, &kClassPropertiesKey)) {
        [self __inspectProperties];
    }
}


//inspects the class, get's a list of the class properties
+ (void)__inspectProperties
{
    
    NSMutableDictionary *propertyIndex = [NSMutableDictionary dictionary];
    
    //temp variables for the loops
    Class class = [self class];
    NSScanner* scanner = nil;
    NSString* propertyType = nil;
    
    // inspect inherited properties up to the JSONModel class
    while (class != [DBModel class]) {
        unsigned int propertyCount;
        objc_property_t *properties = class_copyPropertyList(class, &propertyCount);
        
        //loop over the class properties
        for (unsigned int i = 0; i < propertyCount; i++) {
            
            DBModelClassProperty* p = [[DBModelClassProperty alloc] init];
            
            // get property name
            objc_property_t property = properties[i];
            const char *propertyName = property_getName(property);
            p.name = @(propertyName);
            
            if ([propertyIndex objectForKey:p.name]) {
                // 如果子类中存在这个字段，这忽略父类中对应字段
                continue;
            }
            
            // get property attributes
            const char *attrs = property_getAttributes(property);
            NSString* propertyAttributes = @(attrs);
            NSArray* attributeItems = [propertyAttributes componentsSeparatedByString:@","];
            
            // ignore read-only properties
            // TODO:这里需要探讨一下是否真的需要移除只读属性
            if ([attributeItems containsObject:@"R"]) {
                continue; //to next property
            }
            
            // check for 64b BOOLs
            if ([propertyAttributes hasPrefix:@"Tc,"]) {
                // mask BOOLs as structs so they can have custom convertors
                p.structName = @"BOOL";
            }
            
            scanner = [NSScanner scannerWithString: propertyAttributes];
            
            [scanner scanUpToString:@"T" intoString: nil];
            [scanner scanString:@"T" intoString:nil];
            
            // check if the property is an instance of a class
            if ([scanner scanString:@"@\"" intoString: &propertyType]) {
                
                [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\"<"]
                                        intoString:&propertyType];
                
                if ([propertyType isEqualToString:@"@\""]) {
                    // 这里类型是id, 忽略掉
                    continue;
                }
                p.typeName = s_dicTypeDBNames[propertyType];
                p.type = NSClassFromString(propertyType);
                p.isMutable = ([propertyType rangeOfString:@"Mutable"].location != NSNotFound);
                p.isAllowedClassype = [s_allowedClassTypes containsObject:p.type];
                
                if (!p.isAllowedClassype) {
                    p.isDBModel = [self __isJSONModelSubClass:p.type];
                }
                
                if ([propertyType isEqualToString:@"NSNumber"]) {
                    p.typeName = [self typeNameForNumber:p.name];
                    p.isDBIgnore = [self isDBIgnoreForNumber:p.name];
                }
                
                
                //read through the property protocols
                while ([scanner scanString:@"<" intoString:NULL]) {
                    
                    NSString* protocolName = nil;
                    
                    [scanner scanUpToString:@">" intoString: &protocolName];
                    
                    if ([protocolName isEqualToString:@"Primary"]) {
                        if (objc_getAssociatedObject(self.class, &kClassPrimaryKey) == nil) {
                            p.isPrimary = YES;
                            if ([p.type isSubclassOfClass:[NSNumber class]]) {
                                p.typeName = @"INTEGER";
                            }
                            objc_setAssociatedObject(self.class,
                                                     &kClassPrimaryKey,
                                                     p.name,
                                                     OBJC_ASSOCIATION_RETAIN // This is atomic
                                                     );
                        }
                    } else if ([protocolName isEqualToString:@"Optional"]) {
                        p.isOptional = YES;
                    } else if ([protocolName isEqualToString:@"ConvertOnDemand"]) {
                        p.convertsOnDemand = YES;
                    } else if ([protocolName isEqualToString:@"JsonIgnore"]) {
                        p.isJsonIgnore = YES;
                    } else if ([protocolName isEqualToString:@"DBIgnore"]) {
                        p.isDBIgnore = YES;
                    } else if ([protocolName isEqualToString:@"DBInt"]) {
                        p.typeName = @"INT";
                    } else if ([protocolName isEqualToString:@"DBBool"]) {
                        p.typeName = @"BOOL";
                    } else if ([protocolName isEqualToString:@"DBFloat"]) {
                        p.typeName = @"FLOAT";
                    } else if ([protocolName isEqualToString:@"DBDouble"]) {
                        p.typeName = @"DOUBLE";
                    } else {
                        p.protocol = protocolName;
                    }
                    
                    [scanner scanString:@">" intoString:NULL];
                }
                
            }
            //check if the property is a structure
            else if ([scanner scanString:@"{" intoString: &propertyType]) {
                [scanner scanCharactersFromSet:[NSCharacterSet alphanumericCharacterSet]
                                    intoString:&propertyType];
                
                p.isAllowedClassype = NO;
                p.structName = propertyType;
                
            }
            else if ([scanner scanString:@"@," intoString: &propertyType]) {
                // 这里类型是id, 忽略掉
                continue;
            }
            //the property must be a primitive
            else {
                
                //the property contains a primitive data type
                [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@","]
                                        intoString:&propertyType];
                
                //get the full name of the primitive type
                propertyType = s_primitivesNames[propertyType];
                p.typeName = s_dicTypeDBNames[propertyType];
                
                if (![s_allowedPrimitiveTypes containsObject:propertyType]) {
                    
                    //type not allowed - programmer mistaked -> exception
                    @throw [NSException exceptionWithName:@"DBModelProperty type not allowed"
                                                   reason:[NSString stringWithFormat:@"Property type of %@.%@ is not supported by DBModel.", self.class, p.name]
                                                 userInfo:nil];
                }
                p.isDBIgnore = [self isDBIgnoreForNumber:p.name];
            }
            
    //        NSString *nsPropertyName = @(propertyName);
    //            if([[self class] propertyIsOptional:nsPropertyName]){
    //                p.isOptional = YES;
    //            }
    //            
    //            if([[self class] propertyIsIgnored:nsPropertyName]){
    //                p = nil;
    //            }
            
            //few cases where JSONModel will ignore properties automatically
            if ([propertyType isEqualToString:@"Block"]) {
                p = nil;
            }
            
            //add the property object to the temp index
            if (p) {
                [propertyIndex setObject:p forKey:p.name];
            }
        }
        
        free(properties);
        class = [class superclass];
    }
    
    
    // finally store the property index in the static property index
    objc_setAssociatedObject(self.class,
                             &kClassPropertiesKey,
                             [propertyIndex copy],
                             OBJC_ASSOCIATION_RETAIN // This is atomic
                             );
}

+ (BOOL)__isJSONModelSubClass:(Class)class
{
    // http://stackoverflow.com/questions/19883472/objc-nsobject-issubclassofclass-gives-incorrect-failure
#ifdef UNIT_TESTING
    return [@"JSONModel" isEqualToString: NSStringFromClass([class superclass])];
#else
    return [class isSubclassOfClass:s_DBModelClass];
#endif
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@", [self toDictionary]];
}

@end



#pragma mark - Category

@implementation NSString (Utils)

- (id)objectFromJSONString
{
    return [DBModel objectFromJSONString:self error:nil];
}

@end

