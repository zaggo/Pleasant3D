//
//  ThreeDPreviewView.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 11.02.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify it under
//  the terms of the GNU General Public License as published by the Free Software 
//  Foundation; either version 3 of the License, or (at your option) any later 
//  version.
// 
//  This program is distributed in the hope that it will be useful, but WITHOUT ANY 
//  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A 
//  PARTICULAR PURPOSE. See the GNU General Public License for more details.
// 
//  You should have received a copy of the GNU General Public License along with 
//  this program; if not, see <http://www.gnu.org/licenses>.
// 
//  Additional permission under GNU GPL version 3 section 7
// 
//  If you modify this Program, or any covered work, by linking or combining it 
//  with the P3DCore.framework (or a modified version of that framework), 
//  containing parts covered by the terms of Pleasant Software's software license, 
//  the licensors of this Program grant you additional permission to convey the 
//  resulting work.
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

    BOOL validPerspective;
    
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
@property (readonly) Vector3* objectDimensions;

- (IBAction)resetPerspective:(id)sender;

- (void)renderContent;
@end
