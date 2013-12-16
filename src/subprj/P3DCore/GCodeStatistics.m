//
//  GCodeStatistics.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 06.12.13.
//  Copyright (c) 2013 Pleasant Software. All rights reserved.
//

#import "GCodeStatistics.h"

@implementation GCodeStatistics
- (id)init
{
    self = [super init];
    if (self) {
        // Init stats
        _currentFeedRate = 4800.0; // Default feed rate (mm/min)
        _currentLocation = [[Vector3 alloc] initVectorWithX:0. Y:0. Z:0.];
    }
    return self;
}

@end
