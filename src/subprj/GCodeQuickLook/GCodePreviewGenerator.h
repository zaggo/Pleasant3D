//
//  GCodePreviewGenerator.h
//  GCodeQuickLook
//
//  Created by Eberhard Rensch on 07.01.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>
//#import <P3DCore/P3DCore.h>
#import "Vector3.h"

@interface GCodePreviewGenerator : NSObject {
	BOOL thumbnail;
	CGSize renderSize;

	NSArray* gCodePanes;
	Vector3* cornerMinimum;
	Vector3* cornerMaximum;
	CGFloat extrusionWidth;
	
	CGFloat othersAlpha;
	NSUInteger currentLayer;
	
	CGFloat cameraOffset;
	CGFloat rotateX;
	CGFloat rotateY;
	
	Vector3* dimBuildPlattform;
	Vector3* zeroBuildPlattform;
	
	NSArray* extrusionColors;
	CGColorRef extrusionOffColor;
}

@property (retain) NSArray* gCodePanes;
@property (assign) CGSize renderSize;

- (id)initWithURL:(NSURL*)gCodeURL size:(CGSize)size forThumbnail:(BOOL)forThumbnail;

- (CGImageRef)generatePreviewImage;
@end
