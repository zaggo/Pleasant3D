//
//  ThreeDPreviewView.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 11.02.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Vector3, P3DMachineDriverBase;
@interface ThreeDPreviewView : NSOpenGLView {
	NSUInteger currentLayer;
	float currentLayerHeight;
	
	CGFloat cameraOffset;
	CGFloat cameraTranslateX;
	CGFloat cameraTranslateY;
	GLfloat trackBallRotation[4];
	GLfloat worldRotation[4];

	BOOL zoomCamera;
	BOOL translateCamera;
	
	NSTimer* autorotateTimer;
	
	NSPoint localMousePoint;

	BOOL threeD;
	BOOL showArrows;
	CGFloat othersAlpha;
	
	GLuint arrowDL;
	BOOL readyToDraw;	
    
    P3DMachineDriverBase* currentMachine;
}

@property (assign) NSUInteger currentLayer;
@property (assign) BOOL showArrows;
@property (assign) BOOL threeD;
@property (assign) CGFloat othersAlpha;
@property (assign) BOOL autorotate;
@property (assign) BOOL userRequestedAutorotate;
@property (readonly) NSInteger maxLayers;
@property (assign) float currentLayerHeight;
@property (readonly) float layerHeight;
@property (assign) P3DMachineDriverBase* currentMachine;

- (IBAction)resetPerspective:(id)sender;

- (void)renderContent;
@end
