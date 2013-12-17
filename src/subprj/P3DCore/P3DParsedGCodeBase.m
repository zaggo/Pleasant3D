//
//  P3DParsedGCodeBase.m
//  P3DCore
//
//  Created by Eberhard Rensch on 16.12.13.
//  Copyright (c) 2013 Pleasant Software. All rights reserved.
//

#import "P3DParsedGCodeBase.h"
#import <P3DCore/P3DCore.h>

@implementation P3DParsedGCodeBase
@dynamic vertexArray;


- (id)initWithGCodeString:(NSString*)gcode printer:(P3DPrinterDriverBase*)currentPrinter
{
    self = [super init];
    if(self) {
        _currentPrinter = currentPrinter;
    }
    
    return self;
}

- (GLfloat*)vertexArray {
    return (GLfloat*)_vertexBuffer.bytes;
}

- (void)addError:(NSString*)formatString, ...
{
    va_list args;
    va_start(args, formatString);
    NSString* errorString = [[NSString alloc] initWithFormat:formatString arguments:args];
    va_end(args);
    
    if(_parsingErrors==nil)
        _parsingErrors = [NSMutableArray array];
    [_parsingErrors addObject:errorString];
}

@end
