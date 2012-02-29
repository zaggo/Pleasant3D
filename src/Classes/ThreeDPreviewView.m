//
//  ThreeDPreviewView.m
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

#import "ThreeDPreviewView.h"
#import <OpenGL/glu.h>
#import <P3DCore/P3DCore.h>
#import "trackball.h"

@interface ThreeDPreviewView (Private)
- (void)resetGraphics;
@end


@implementation ThreeDPreviewView
@synthesize currentLayer, threeD, othersAlpha, showArrows, currentLayerHeight, currentMachine;
@dynamic userRequestedAutorotate, autorotate, maxLayers, layerHeight, objectDimensions;

- (void)awakeFromNib
{
	// TODO: These should be handled by a Document-based object
	NSMutableDictionary *ddef = [NSMutableDictionary dictionary];
	[ddef setObject:[NSNumber numberWithFloat:.5] forKey:@"gCodeAlpha"];
	[ddef setObject:[NSNumber numberWithBool:NO] forKey:@"gCodeAutorotate"];	
	[ddef setObject:[NSNumber numberWithBool:YES] forKey:@"gCodeShowArrows"];
	[ddef setObject:[NSNumber numberWithBool:YES] forKey:@"gCode3d"];
	
	[[NSUserDefaults standardUserDefaults] registerDefaults:ddef];
	
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	
	self.threeD = [defaults boolForKey:@"gCode3d"];
	self.othersAlpha = [defaults floatForKey:@"gCodeAlpha"];
	self.showArrows = [defaults boolForKey:@"gCodeShowArrows"];
	
	[self resetGraphics];
	
	self.autorotate=[[NSUserDefaults standardUserDefaults] boolForKey:@"gCodeAutorotate"];
}

- (void)setupProjection
{
	// NSLog(@"Called: %s", _cmd);
	if(readyToDraw)
	{
		NSRect boundsInPixelUnits = [self convertRect:[self frame] toView:nil];
		glViewport(0, 0, boundsInPixelUnits.size.width, boundsInPixelUnits.size.height);
		
		glMatrixMode( GL_PROJECTION );
		glLoadIdentity();
		
		if(threeD)
			gluPerspective( 45., boundsInPixelUnits.size.width / boundsInPixelUnits.size.height, 0.1, 1000.0 );
		else
		{
			CGFloat width;
			CGFloat height;
			CGFloat midX;
			CGFloat midY;
            if(self.currentMachine.dimBuildPlattform)
            {
                width = (self.currentMachine.dimBuildPlattform.x)*1.1;
                height = (self.currentMachine.dimBuildPlattform.y)*1.1;
                midX = self.currentMachine.zeroBuildPlattform.x-self.currentMachine.dimBuildPlattform.x/2.;
                midY = self.currentMachine.zeroBuildPlattform.y-self.currentMachine.dimBuildPlattform.y/2.;
            }
            else
            {
                width = (self.objectDimensions.x)*1.1;
                height = (self.objectDimensions.y)*1.1;
                midX = self.currentMachine.zeroBuildPlattform.x-self.objectDimensions.x/2.;
                midY = self.currentMachine.zeroBuildPlattform.y-self.objectDimensions.y/2.;

//                width = (boundsInPixelUnits.size.width)*1.1;
//                height = (boundsInPixelUnits.size.height)*1.1;
//                midX = boundsInPixelUnits.size.width/2.;
//                midY = boundsInPixelUnits.size.height/2.;
            }
			CGFloat ratio = boundsInPixelUnits.size.width / boundsInPixelUnits.size.height;
			if(ratio>1.)
			{
				glOrtho(midX-height/2.*ratio, midX+height/2.*ratio, midY-height/2., midY+height/2.,  -1., 1.);
			}
			else
			{
				glOrtho(midX-width/2., midX+width/2., midY-width/2./ratio, midY+width/2./ratio,  -1., 1.);
			}
		}
		glMatrixMode( GL_MODELVIEW );
		glLoadIdentity();
	}
}

- (float)layerHeight
{
	return 1.;
}

+ (NSSet *)keyPathsForValuesAffectingCurrentLayerHeight {
    return [NSSet setWithObjects:@"currentLayer", nil];
}

- (void)setCurrentLayerHeight:(float)value
{
	currentLayerHeight = value;
	currentLayer = (NSUInteger)(value/self.layerHeight);
	[self setNeedsDisplay:YES];
}

+ (NSSet *)keyPathsForValuesAffectingCurrentLayer {
    return [NSSet setWithObjects:@"currentLayerHeight", nil];
}

- (void)setCurrentLayer:(NSUInteger)value
{
	currentLayer = value;
	currentLayerHeight = currentLayer*self.layerHeight;
	[self setNeedsDisplay:YES];
}

+ (NSSet *)keyPathsForValuesAffectingUserRequestedAutorotate {
    return [NSSet setWithObjects:@"autorotate", nil];
}

- (BOOL)userRequestedAutorotate
{
	return self.autorotate;
}

- (void)setUserRequestedAutorotate:(BOOL)value
{
	self.autorotate = value;
	[[NSUserDefaults standardUserDefaults] setBool:value forKey:@"P3DLoopsPreviewAutorotate"];
}

- (BOOL)autorotate
{
	return (autorotateTimer!=nil);
}

- (void)setAutorotate:(BOOL)value
{
	if(self.autorotate != value)
	{
		if(value)
		{
			[autorotateTimer invalidate];
			autorotateTimer = [NSTimer timerWithTimeInterval:1./120. target:self selector:@selector(autorotate:) userInfo:nil repeats:YES];
			[[NSRunLoop currentRunLoop] addTimer:autorotateTimer forMode:NSRunLoopCommonModes];
		}
		else
		{
			[autorotateTimer invalidate];
			autorotateTimer=nil;
		}
	}
}

- (void)resetGraphics
{
	[self setupProjection];
	[self resetPerspective:self];
}

- (void)setThreeD:(BOOL)value
{
	//NSLog(@"setThreeD: %@", value?@"YES":@"NO");
	threeD = value;
	self.autorotate=NO;
	[[NSUserDefaults standardUserDefaults] setBool:threeD forKey:@"gCode3d"];
	validPerspective=NO;
	[self resetGraphics];
}

- (void)setShowArrows:(BOOL)value
{
	//NSLog(@"setShowArrows: %@", value?@"YES":@"NO");
	showArrows = value;
	[[NSUserDefaults standardUserDefaults] setBool:showArrows forKey:@"gCodeShowArrows"];
	[self setNeedsDisplay:YES];
}

- (void)setOthersAlpha:(CGFloat)value
{
	othersAlpha = value;
	[[NSUserDefaults standardUserDefaults] setFloat:othersAlpha forKey:@"gCodeAlpha"];
	[self setNeedsDisplay:YES];
}

- (Vector3*)objectDimensions
{
    return nil;
}

- (IBAction)resetPerspective:(id)sender
{
	self.autorotate=NO;
	cameraTranslateX = 0.;
	cameraTranslateY = 0.;
    if(self.currentMachine.dimBuildPlattform)
    {
        cameraOffset = - 2*MAX( self.currentMachine.dimBuildPlattform.x, self.currentMachine.dimBuildPlattform.y);
        validPerspective=YES;
    }
    else
    {
        Vector3* dim = self.objectDimensions;
        if(dim)
        {
            cameraOffset = - 2*MAX( dim.x, dim.y);
            validPerspective=YES;
            cameraTranslateY = -dim.y/4.;
        }
    }
	worldRotation[0] = -45.f;
	worldRotation[1] = 1.f;
	worldRotation[2] = worldRotation[3] = 0.0f;
	[self setNeedsDisplay:YES];
}

- (void)scrollWheel:(NSEvent *)theEvent
{
	cameraOffset += [theEvent deltaY];
	cameraOffset = MIN(MAX(-900., cameraOffset), 1.);
	[self setNeedsDisplay:YES];
}

- (void)rightMouseDown:(NSEvent *)theEvent
{
	self.autorotate=NO;
	NSPoint event_location = [theEvent locationInWindow];
	localMousePoint = [self convertPoint:event_location fromView:nil];
}

- (void)rightMouseDragged:(NSEvent *)theEvent
{
	NSPoint event_location = [theEvent locationInWindow];
	NSPoint localPoint = [self convertPoint:event_location fromView:nil];
	
	cameraTranslateX += (localPoint.x-localMousePoint.x)/((threeD)?(-1000./cameraOffset):5.);
	cameraTranslateY += (localPoint.y-localMousePoint.y)/((threeD)?(-1000./cameraOffset):5.);
	
	[self setNeedsDisplay:YES];
	localMousePoint=localPoint;
}

- (void)mouseDown:(NSEvent *)theEvent
{
	self.autorotate=NO;

	NSPoint event_location = [theEvent locationInWindow];
	localMousePoint = [self convertPoint:event_location fromView:nil];
	zoomCamera=([theEvent modifierFlags]&NSCommandKeyMask)!=0;
	translateCamera=!zoomCamera && ((([theEvent modifierFlags]&NSAlternateKeyMask)!=0)||!threeD);
	
	if(!translateCamera && !zoomCamera)
	{
		NSRect boundsInPixelUnits = [self convertRect:[self frame] toView:nil];
		startTrackball (localMousePoint.x, localMousePoint.y, 0, 0, boundsInPixelUnits.size.width, boundsInPixelUnits.size.height);
	}

}

- (void)mouseDragged:(NSEvent *)theEvent
{
	NSPoint event_location = [theEvent locationInWindow];
	NSPoint localPoint = [self convertPoint:event_location fromView:nil];
	
	if(zoomCamera)
	{
		cameraOffset += (localPoint.x-localMousePoint.x);
		cameraOffset = MIN(MAX(-900., cameraOffset), 1.);
	}
	else if(translateCamera)
	{
		cameraTranslateX += (localPoint.x-localMousePoint.x)/((threeD)?(-1000./cameraOffset):5.);
		cameraTranslateY += (localPoint.y-localMousePoint.y)/((threeD)?(-1000./cameraOffset):5.);
	}
	else if(threeD)
	{
        rollToTrackball (localPoint.x, localPoint.y, trackBallRotation);
	}
	
	[self setNeedsDisplay:YES];
	localMousePoint=localPoint;
}

- (void)mouseUp:(NSEvent *)theEvent
{
	if(threeD)
	{
		if(!translateCamera && !zoomCamera)
		{
			if (trackBallRotation[0] != 0.0)
				addToRotationTrackball (trackBallRotation, worldRotation);
			trackBallRotation [0] = trackBallRotation [1] = trackBallRotation [2] = trackBallRotation [3] = 0.0f;
			
			[self setNeedsDisplay:YES];
		}
		else if([theEvent clickCount]>1)
			[self resetPerspective:self];
	}
}

- (void)keyDown:(NSEvent *)theEvent
{
	NSString* chars = [theEvent charactersIgnoringModifiers];
	NSUInteger modif = [theEvent modifierFlags];
	if([chars characterAtIndex:0]==NSUpArrowFunctionKey)
	{
		if(modif & NSAlternateKeyMask) // Opt
		{
			self.currentLayer = self.maxLayers;
		}
		if(currentLayer<self.maxLayers)
			self.currentLayer++;
	}
	else if([chars characterAtIndex:0]==NSDownArrowFunctionKey)
	{
		if(modif & NSAlternateKeyMask) // Opt
		{
			self.currentLayer = 0;
		}
		if(currentLayer>0)
			self.currentLayer--;
	}
}

- (BOOL)acceptsFirstResponder {
    // We want this view to be able to receive key events.
    return YES;
}

- (void)autorotate:(NSTimer*)timer
{
	GLfloat autorotation[] = {1.f, 0.f, 1.f, 0.f};
	addToRotationTrackball (autorotation, worldRotation);
	[self setNeedsDisplay:YES];
}

- (void)reshape {
	[self setupProjection];
}

- (void)prepareOpenGL
{
	const GLfloat kArrowLen = .4f;
	
	arrowDL = glGenLists(1);
	glNewList(arrowDL, GL_COMPILE);
	
	glBegin(GL_TRIANGLES);
	glVertex3f(kArrowLen, kArrowLen, 0.f);
	glVertex3f(-kArrowLen, 0.f, 0.f);
	glVertex3f(kArrowLen, -kArrowLen, 0.f);
	glEnd();
	
	glEndList();
}

- (void)renderContent
{
}

- (void)drawRect:(NSRect)aRect {
 	// NSLog(@"Called: %s", _cmd);
	if(!readyToDraw)
	{
		readyToDraw=YES;
		[self setupProjection];
	}
    if(!validPerspective)
    {
        [self resetPerspective:nil];
    }

    // Clear the framebuffer.
	glClearColor( .08f, .08f, .08f, 1.f);
	//glClearColor( 1.f, 1.f, 1.f, 1.f);
	glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
	
	
	// Reset The View
	glEnable (GL_LINE_SMOOTH); 
	glEnable (GL_BLEND); 
	glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

	glLoadIdentity();	
	if(threeD)
	{
		glTranslatef((GLfloat)cameraTranslateX, (GLfloat)cameraTranslateY, (GLfloat)cameraOffset);
		//glTranslatef((GLfloat)cameraTranslateX, (GLfloat)cameraTranslateY, 0.f);
		if (trackBallRotation[0] != 0.0f) 
			glRotatef (trackBallRotation[0], trackBallRotation[1], trackBallRotation[2], trackBallRotation[3]);
		// accumlated world rotation via trackball
		glRotatef (worldRotation[0], worldRotation[1], worldRotation[2], worldRotation[3]);
//		glTranslatef(0.f, 0.f, (GLfloat)cameraOffset);
	}
	else
	{
		glTranslatef((GLfloat)cameraTranslateX, (GLfloat)cameraTranslateY, 0.f);
		glScalef(-200.f/(GLfloat)cameraOffset, -200.f/(GLfloat)cameraOffset, 1.f);
	}

    // Build Platform
    if(self.currentMachine.dimBuildPlattform)
    {
        glLineWidth(1.f);
        //glColor4f(1.f, .749f, 0.f, .1f);
        glColor4f(1.f, 0.f, 0.f, 0.1f);
        glBegin(GL_QUADS);
        glVertex3f((GLfloat)-self.currentMachine.zeroBuildPlattform.x, (GLfloat)-self.currentMachine.zeroBuildPlattform.y, 0.f);
        glVertex3f((GLfloat)-self.currentMachine.zeroBuildPlattform.x, (GLfloat)self.currentMachine.dimBuildPlattform.y-(GLfloat)self.currentMachine.zeroBuildPlattform.y, 0.f);
        glVertex3f((GLfloat)self.currentMachine.dimBuildPlattform.x-(GLfloat)self.currentMachine.zeroBuildPlattform.x, (GLfloat)self.currentMachine.dimBuildPlattform.y-(GLfloat)self.currentMachine.zeroBuildPlattform.y, 0.f);
        glVertex3f((GLfloat)self.currentMachine.dimBuildPlattform.x-(GLfloat)self.currentMachine.zeroBuildPlattform.x, (GLfloat)-self.currentMachine.zeroBuildPlattform.y, 0.f);
        glEnd();
        
        glColor4f(1.f, 0.f, 0.f, .4f);
        glBegin(GL_LINES);
        for(float x=-self.currentMachine.zeroBuildPlattform.x; x<self.currentMachine.dimBuildPlattform.x-self.currentMachine.zeroBuildPlattform.x; x+=10.f)
        {
            glVertex3f((GLfloat)x, (GLfloat)-self.currentMachine.zeroBuildPlattform.y, 0.f);
            glVertex3f((GLfloat)x, (GLfloat)self.currentMachine.dimBuildPlattform.y-(GLfloat)self.currentMachine.zeroBuildPlattform.y, 0.f);
        }
        glVertex3f((GLfloat)self.currentMachine.dimBuildPlattform.x-(GLfloat)self.currentMachine.zeroBuildPlattform.x, (GLfloat)-self.currentMachine.zeroBuildPlattform.y, 0.f);
        glVertex3f((GLfloat)self.currentMachine.dimBuildPlattform.x-(GLfloat)self.currentMachine.zeroBuildPlattform.x, (GLfloat)self.currentMachine.dimBuildPlattform.y-(GLfloat)self.currentMachine.zeroBuildPlattform.y, 0.f);
        
        for(float y=-self.currentMachine.zeroBuildPlattform.y; y<self.currentMachine.dimBuildPlattform.y-self.currentMachine.zeroBuildPlattform.y; y+=10.f)
        {
            glVertex3f((GLfloat)-self.currentMachine.zeroBuildPlattform.x, (GLfloat)y, 0.f);
            glVertex3f((GLfloat)self.currentMachine.dimBuildPlattform.x-(GLfloat)self.currentMachine.zeroBuildPlattform.x, (GLfloat)y, 0.f);
        }
        glVertex3f((GLfloat)-self.currentMachine.zeroBuildPlattform.x, (GLfloat)self.currentMachine.dimBuildPlattform.y-(GLfloat)self.currentMachine.zeroBuildPlattform.y, 0.f);
        glVertex3f((GLfloat)self.currentMachine.dimBuildPlattform.x-(GLfloat)self.currentMachine.zeroBuildPlattform.x, (GLfloat)self.currentMachine.dimBuildPlattform.y-(GLfloat)self.currentMachine.zeroBuildPlattform.y, 0.f);
        glEnd();
    }
	// Ende Build Platfom
    
	glEnable(GL_DEPTH_TEST);
	[self renderContent];
	glDisable(GL_DEPTH_TEST);
	
	glFinish();
	[[self openGLContext] flushBuffer];
}

- (void)setCurrentMachine:(P3DMachineDriverBase*)value
{
    currentMachine=value;
    [self setNeedsDisplay:YES];
}
@end
