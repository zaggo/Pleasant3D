//
//  P3DLoops.h
//  P3DCore
//
//  Created by Eberhard Rensch on 17.01.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <P3DCore/P3DCore.h>
#import "SliceTypes.h"

@interface P3DLoops : P3DProcessedObject {
	NSData* insetLoopCornerData;
	NSArray* layers;
	float extrusionHeight;
	float extrusionWidth;
	Vector3* cornerMaximum;
	Vector3* cornerMinimum;
}

- (id)initWithLoopCornerData:(NSData*)data;

@property (readonly) InsetLoopCorner* loopCorners;
@property (readonly) NSUInteger loopCornerCount;

@property (assign) NSArray* layers;
@property (assign) float extrusionHeight;
@property (assign) float extrusionWidth;
@property (copy) Vector3* cornerMaximum;
@property (copy) Vector3* cornerMinimum;
@end
