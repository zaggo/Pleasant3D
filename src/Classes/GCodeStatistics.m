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
        currentFeedRate = 4800.0; // Default feed rate (mm/min)
        
        currentLocation = [[Vector3 alloc] initVectorWithX:0. Y:0. Z:0.];
        totalTravelledTime = 0;
        totalTravelledDistance = 0;
        totalExtrudedTime = 0;
        totalExtrudedDistance = 0;
        
        currentExtrudedLengthToolA = 0;
        currentExtrudedLengthToolB = 0;
        
        totalExtrudedLengthToolA = 0;
        totalExtrudedLengthToolB = 0;
        
        movementLinesCount = 0;
        layersCount = 0;
        layerHeight = 0;
        
        extruding = NO;
        dualExtrusion = NO;
        usingToolB = NO;
    }
    return self;
}
@end
