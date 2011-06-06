//
//  STLPreviewGenerator.h
//  STLQuickLook
//
//  Created by Eberhard Rensch on 07.01.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>
#import "STLModel.h"
#import "Vector3.h"
//#import <QTKit/QTKit.h>

@interface STLPreviewGenerator : NSObject {
	BOOL thumbnail;
	CGSize renderSize;
	STLModel* stlModel;
	
	CGFloat cameraOffset;
	CGFloat rotateX;
	CGFloat rotateY;
	
	BOOL wireframe;
	
	Vector3* dimBuildPlattform;
	Vector3* zeroBuildPlattform;
}

@property (retain) STLModel* stlModel;
@property (assign) BOOL wireframe;
@property (assign) CGSize renderSize;

- (id)initWithSTLModel:(STLModel*)model size:(CGSize)size forThumbnail:(BOOL)forThumbnail;

- (CGImageRef)generatePreviewImage;
//- (QTMovie*)generatePreviewMovie;
@end
