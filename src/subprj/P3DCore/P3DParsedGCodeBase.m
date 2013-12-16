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

- (id)initWithGCodeString:(NSString*)gcode printer:(P3DPrinterDriverBase*)currentPrinter
{
    self = [super init];
    if(self) {
        _currentPrinter = currentPrinter;
    }
    
    return self;
}


@end
