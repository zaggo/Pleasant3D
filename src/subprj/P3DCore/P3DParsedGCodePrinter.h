//
//  P3DParsedGCodePrinter.h
//  P3DCore
//
//  Created by Eberhard Rensch on 16.12.13.
//  Copyright (c) 2013 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "P3DParsedGCodeBase.h"

#define kFirstVertexIndex @"firstVertexIndex"
#define kMinLayerZ @"minLayerZ"
#define kMaxLayerZ @"maxLayerZ"

@class GCodeStatistics;
@interface P3DParsedGCodePrinter : P3DParsedGCodeBase

@property (readonly, strong) NSArray* paneIndex;

@property (readonly, strong) GCodeStatistics* gCodeStatistics;

@property (readonly) float extrusionWidth;

@property (readonly) float totalMachiningTime;
@property (readonly) float objectWeight;
@property (readonly) float filamentLengthToolA;
@property (readonly) float filamentLengthToolB;
@property (readonly) NSInteger layerHeight;

@end
