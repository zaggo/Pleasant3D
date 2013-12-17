//
//  P3DMillDriverBase.m
//  P3DCore
//
//  Created by Eberhard Rensch on 14.12.13.
//  Copyright (c) 2013 Pleasant Software. All rights reserved.
//

#import "P3DMillDriverBase.h"

@implementation P3DMillDriverBase

- (id)init
{
    self = [super init];
    if (self) {
        _fastXYFeedrate = 1100.f; // mm/min
        _fastZFeedrate = 1100.f; // mm/min
        _slowFeedrate = 150.f; // mm/min
    }
    return self;
}
@end
