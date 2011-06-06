//
//  OpenGLPreviewView.h
//  MacSkeinforge
//
//  Created by Eberhard Rensch on 30.07.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ThreeDPreviewView.h"

@class STLModel;
@interface STLPreviewView : ThreeDPreviewView 
{
	STLModel* stlModel;
	
	BOOL wireframe;
}

@property (retain) STLModel* stlModel;
@property (assign) BOOL wireframe;
@end
