//
//  GCodeStatistics.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 06.12.13.
//  Copyright (c) 2013 Pleasant Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Vector3.h"

@interface GCodeStatistics : NSObject

@property (assign, nonatomic) BOOL dualExtrusion;

// Tool-specific stats
/* TOOL A */
@property (assign, nonatomic) float currentExtrudedLengthToolA;
@property (assign, nonatomic) float totalExtrudedLengthToolA;


/* TOOL B */
@property (assign, nonatomic) float currentExtrudedLengthToolB;
@property (assign, nonatomic) float totalExtrudedLengthToolB;
@property (assign, nonatomic) BOOL usingToolB;

// Common stats
@property (assign, nonatomic) float totalExtrudedTime;
@property (assign, nonatomic) float totalExtrudedDistance;

@property (assign, nonatomic) float totalTravelledTime;
@property (assign, nonatomic) float totalTravelledDistance;

@property (assign, nonatomic) float currentFeedRate;

@property (assign, nonatomic) NSInteger movementLinesCount;
@property (assign, nonatomic) NSInteger layersCount;
@property (assign, nonatomic) float layerHeight;

@property (assign, nonatomic) BOOL extruding;
@property (assign, nonatomic) BOOL extrudingStateChanged;

@property (strong, readonly, nonatomic) Vector3* currentLocation;

@end
