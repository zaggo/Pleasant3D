//
//  GCodeStatistics.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 06.12.13.
//  Copyright (c) 2013 Pleasant Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <P3DCore/P3DCore.h>

@interface GCodeStatistics : NSObject
{
@public
    
    BOOL dualExtrusion;
    
    // Tool-specific stats
    /* TOOL A */
    float currentExtrudedLengthToolA;
    float totalExtrudedLengthToolA;
    
    /* TOOL B */
    float currentExtrudedLengthToolB;
    float totalExtrudedLengthToolB;
    BOOL usingToolB;
    
    // Common stats
    float totalExtrudedTime;
    float totalExtrudedDistance;
    
    float totalTravelledTime;
    float totalTravelledDistance;
    
    float currentFeedRate;
    
    NSInteger movementLinesCount;
    NSInteger layersCount;
    float layerHeight;
    
    Vector3* currentLocation;
    
    BOOL extruding;
}
@end
