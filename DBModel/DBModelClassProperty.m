//
//  DBModelClassProperty.m
//  Common
//
//  Created by 黄磊 on 16/4/6.
//  Copyright © 2016年 Musjoy. All rights reserved.
//

#import "DBModelClassProperty.h"

@implementation DBModelClassProperty


- (NSString *)description
{
    //build the properties string for the current class property
    NSMutableArray* properties = [NSMutableArray arrayWithCapacity:8];
    
    if (self.isIndex) [properties addObject:@"Index"];
    if (self.isOptional) [properties addObject:@"Optional"];
    if (self.isMutable) [properties addObject:@"Mutable"];
    if (self.convertsOnDemand) [properties addObject:@"ConvertOnDemand"];
    if (self.isAllowedClassype) [properties addObject:@"Allowed Class type"];
    
    NSString* propertiesString = @"";
    if (properties.count>0) {
        propertiesString = [NSString stringWithFormat:@"(%@)", [properties componentsJoinedByString:@", "]];
    }
    
    //return the name, type and additional properties
    return [NSString stringWithFormat:@"@property %@%@ %@ %@",
            self.type?[NSString stringWithFormat:@"%@*",self.type]:(self.structName?self.structName:@"primitive"),
            self.protocol?[NSString stringWithFormat:@"<%@>", self.protocol]:@"",
            self.name,
            propertiesString
            ];
}


@end
