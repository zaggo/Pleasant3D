//
//  P3DLoopsPreviewView.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 04.08.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ThreeDPreviewView.h"

@class P3DLoops;
@interface P3DLoopsPreviewView : ThreeDPreviewView	{
	P3DLoops* loops;
	
	BOOL showNoExtrusionPaths;
}

@property (retain) P3DLoops* loops;

@property (readonly) NSString* layerInfoString;
@property (readonly) NSString* dimensionsString;

@property (assign) BOOL showNoExtrusionPaths;
@end
