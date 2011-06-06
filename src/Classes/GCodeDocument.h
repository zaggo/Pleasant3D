//
//  GCodeDocument.h
//  PleasantSTL
//
//  Created by Eberhard Rensch on 18.10.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <P3DCore/P3DCore.h>

@class GCodeView, Vector3, Vector2d;
@interface GCodeDocument : P3DMachinableDocument {
	NSString* gCodeString;
	
	IBOutlet GCodeView* openGLView;
	BOOL calculatingPreview;

	NSArray* gCodeLineScanners;
	
	Vector3* cornerHigh;
	Vector3* cornerLow;
	CGFloat extrusionWidth;
	CGFloat scale;
	Vector2d* scaleCornerHigh;
	Vector2d* scaleCornerLow;
	
	NSInteger maxLayers;
	float currentPreviewLayerHeight;
    
    NSTimer* changesCommitTimer;
}

@property (retain) NSString* gCodeString;
@property (retain) IBOutlet GCodeView* openGLView;
@property (assign) BOOL calculatingPreview;
@property (assign) NSInteger maxLayers;
@property (assign) float currentPreviewLayerHeight;
@property (assign) NSAttributedString* formattedGCode;

@end
