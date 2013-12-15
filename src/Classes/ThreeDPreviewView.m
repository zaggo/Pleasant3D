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

enum {
    kPlatformVBO,
    kPlatformRasterVBO,
    kVBOCount
};

@interface ThreeDPreviewView (Private)
- (void)resetGraphics;
@end


@implementation ThreeDPreviewView
{
    BOOL _platformVBONeedsRefresh;

    GLuint _vbo[kVBOCount];
    GLsizei _platformRasterVerticesCount;
}
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
	
    _platformVBONeedsRefresh=YES;

	self.threeD = [defaults boolForKey:@"gCode3d"];
	self.othersAlpha = [defaults floatForKey:@"gCodeAlpha"];
	self.showArrows = [defaults boolForKey:@"gCodeShowArrows"];
	
	[self resetGraphics];
	
	self.autorotate=[[NSUserDefaults standardUserDefaults] boolForKey:@"gCodeAutorotate"];
    [self addObserver:self forKeyPath:@"currentMachine" options:NSKeyValueObservingOptionNew context:NULL];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(currentMachineSettingsChanged:) name:P3DCurrentMachineSettingsChangedNotifiaction object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self removeObserver:self forKeyPath:@"currentMachine"];
    glDeleteBuffers(kVBOCount, _vbo);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if([keyPath isEqualToString:@"currentMachine"]) {
        _platformVBONeedsRefresh=YES;
    }
}

- (void)setupProjection
{
	if(_readyToDraw) {
		NSRect boundsInPixelUnits = [self convertRect:[self frame] toView:nil];
		glViewport(0, 0, boundsInPixelUnits.size.width, boundsInPixelUnits.size.height);
		
		glMatrixMode( GL_PROJECTION );
		glLoadIdentity();
		
		if(_threeD) {
			gluPerspective( 45., boundsInPixelUnits.size.width / boundsInPixelUnits.size.height, 0.1, 1000.0 );
        } else {
			CGFloat width;
			CGFloat height;
			CGFloat midX;
			CGFloat midY;
            if(self.currentMachine.dimBuildPlattform) {
                width = (self.currentMachine.dimBuildPlattform.x)*1.1;
                height = (self.currentMachine.dimBuildPlattform.y)*1.1;
                midX = self.currentMachine.zeroBuildPlattform.x-self.currentMachine.dimBuildPlattform.x/2.;
                midY = self.currentMachine.zeroBuildPlattform.y-self.currentMachine.dimBuildPlattform.y/2.;
            } else {
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
			if(ratio>1.) {
				glOrtho(midX-height/2.*ratio, midX+height/2.*ratio, midY-height/2., midY+height/2.,  -1., 1.);
			} else {
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
	_currentLayerHeight = value;
	_currentLayer = (NSUInteger)(value/self.layerHeight);
	[self setNeedsDisplay:YES];
}

+ (NSSet *)keyPathsForValuesAffectingCurrentLayer {
    return [NSSet setWithObjects:@"currentLayerHeight", nil];
}

- (void)setCurrentLayer:(NSUInteger)value
{
	_currentLayer = value;
	_currentLayerHeight = _currentLayer*self.layerHeight;
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

- (void)currentMachineSettingsChanged:(NSNotification*)notification
{
    _platformVBONeedsRefresh=YES;
    [self setNeedsDisplay:YES];
}

- (BOOL)autorotate
{
	return (_autorotateTimer!=nil);
}

- (void)setAutorotate:(BOOL)value
{
	if(self.autorotate != value) {
		if(value) {
			[_autorotateTimer invalidate];
			_autorotateTimer = [NSTimer timerWithTimeInterval:1./120. target:self selector:@selector(autorotate:) userInfo:nil repeats:YES];
			[[NSRunLoop currentRunLoop] addTimer:_autorotateTimer forMode:NSRunLoopCommonModes];
		} else {
			[_autorotateTimer invalidate];
			_autorotateTimer=nil;
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
	_threeD = value;
	self.autorotate=NO;
	[[NSUserDefaults standardUserDefaults] setBool:_threeD forKey:@"gCode3d"];
	_validPerspective=NO;
    _platformVBONeedsRefresh=YES;
	[self resetGraphics];
}

- (void)setShowArrows:(BOOL)value
{
	_showArrows = value;
	[[NSUserDefaults standardUserDefaults] setBool:_showArrows forKey:@"gCodeShowArrows"];
	[self setNeedsDisplay:YES];
}

- (void)setOthersAlpha:(CGFloat)value
{
	_othersAlpha = value;
	[[NSUserDefaults standardUserDefaults] setFloat:_othersAlpha forKey:@"gCodeAlpha"];
	[self setNeedsDisplay:YES];
}

- (Vector3*)objectDimensions
{
    return nil;
}

- (IBAction)resetPerspective:(id)sender
{
	self.autorotate=NO;
	_cameraTranslateX = 0.;
	_cameraTranslateY = 0.;
    if(self.currentMachine.dimBuildPlattform) {
        _cameraOffset = - 2*MAX( self.currentMachine.dimBuildPlattform.x, self.currentMachine.dimBuildPlattform.y);
        _validPerspective=YES;
    } else {
        Vector3* dim = self.objectDimensions;
        if(dim) {
            _cameraOffset = - 2*MAX( dim.x, dim.y);
            _validPerspective=YES;
            _cameraTranslateY = -dim.y/4.;
        }
    }
	_worldRotation[0] = -45.f;
	_worldRotation[1] = 1.f;
	_worldRotation[2] = _worldRotation[3] = 0.0f;
	[self setNeedsDisplay:YES];
}

- (void)scrollWheel:(NSEvent *)theEvent
{
	_cameraOffset += [theEvent deltaY];
	_cameraOffset = MIN(MAX(-900., _cameraOffset), 1.);
	[self setNeedsDisplay:YES];
}

- (void)rightMouseDown:(NSEvent *)theEvent
{
	self.autorotate=NO;
	NSPoint event_location = [theEvent locationInWindow];
	_localMousePoint = [self convertPoint:event_location fromView:nil];
}

- (void)rightMouseDragged:(NSEvent *)theEvent
{
	NSPoint event_location = [theEvent locationInWindow];
	NSPoint localPoint = [self convertPoint:event_location fromView:nil];
	
	_cameraTranslateX += (localPoint.x-_localMousePoint.x)/((_threeD)?(-1000./_cameraOffset):5.);
	_cameraTranslateY += (localPoint.y-_localMousePoint.y)/((_threeD)?(-1000./_cameraOffset):5.);
	
	[self setNeedsDisplay:YES];
	_localMousePoint=localPoint;
}

- (void)mouseDown:(NSEvent *)theEvent
{
	self.autorotate=NO;

	NSPoint event_location = [theEvent locationInWindow];
	_localMousePoint = [self convertPoint:event_location fromView:nil];
	_zoomCamera=([theEvent modifierFlags]&NSCommandKeyMask)!=0;
	_translateCamera=!_zoomCamera && ((([theEvent modifierFlags]&NSAlternateKeyMask)!=0)||!_threeD);
	
	if(!_translateCamera && !_zoomCamera) {
		NSRect boundsInPixelUnits = [self convertRect:[self frame] toView:nil];
		startTrackball (_localMousePoint.x, _localMousePoint.y, 0, 0, boundsInPixelUnits.size.width, boundsInPixelUnits.size.height);
	}

}

- (void)mouseDragged:(NSEvent *)theEvent
{
	NSPoint event_location = [theEvent locationInWindow];
	NSPoint localPoint = [self convertPoint:event_location fromView:nil];
	
	if(_zoomCamera) {
		_cameraOffset += (localPoint.x-_localMousePoint.x);
		_cameraOffset = MIN(MAX(-900., _cameraOffset), 1.);
	} else if(_translateCamera) {
		_cameraTranslateX += (localPoint.x-_localMousePoint.x)/((_threeD)?(-1000./_cameraOffset):5.);
		_cameraTranslateY += (localPoint.y-_localMousePoint.y)/((_threeD)?(-1000./_cameraOffset):5.);
	} else if(_threeD) {
        rollToTrackball (localPoint.x, localPoint.y, _trackBallRotation);
	}
	
	[self setNeedsDisplay:YES];
	_localMousePoint=localPoint;
}

- (void)mouseUp:(NSEvent *)theEvent
{
	if(_threeD) {
		if(!_translateCamera && !_zoomCamera) {
			if (_trackBallRotation[0] != 0.0)
				addToRotationTrackball (_trackBallRotation, _worldRotation);
			_trackBallRotation [0] = _trackBallRotation [1] = _trackBallRotation [2] = _trackBallRotation [3] = 0.0f;
			
			[self setNeedsDisplay:YES];
		} else if([theEvent clickCount]>1) {
			[self resetPerspective:self];
        }
	}
}

- (void)keyDown:(NSEvent *)theEvent
{
	NSString* chars = [theEvent charactersIgnoringModifiers];
	NSUInteger modif = [theEvent modifierFlags];
	if([chars characterAtIndex:0]==NSUpArrowFunctionKey) {
		if(modif & NSAlternateKeyMask) // Opt
			self.currentLayer = self.maxLayers;
		if(_currentLayer<self.maxLayers)
			self.currentLayer++;
	} else if([chars characterAtIndex:0]==NSDownArrowFunctionKey) {
		if(modif & NSAlternateKeyMask) // Opt
			self.currentLayer = 0;
		if(_currentLayer>0)
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
	addToRotationTrackball (autorotation, _worldRotation);
	[self setNeedsDisplay:YES];
}

- (void)reshape {
	[self setupProjection];
}

- (void)prepareOpenGL
{
	const GLfloat kArrowLen = .4f;
	
	_arrowDL = glGenLists(1);
	glNewList(_arrowDL, GL_COMPILE);
	
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
	if(!_readyToDraw) {
		_readyToDraw=YES;
		[self setupProjection];
	}
    if(!_validPerspective) {
        [self resetPerspective:nil];
    }

    if(_vbo[kPlatformVBO]==0) {
        glGenBuffers(kVBOCount, _vbo);
        glEnableClientState(GL_VERTEX_ARRAY);

        glEnable (GL_LINE_SMOOTH);
        glEnable (GL_BLEND);
        glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    }

    if(_platformVBONeedsRefresh) {
        [self setupPlatformVBOWithBufferName:_vbo[kPlatformVBO]];
        _platformRasterVerticesCount = [self setupPlatformRasterVBOWithBufferName:_vbo[kPlatformRasterVBO]];
        _platformVBONeedsRefresh=NO;
    }
    
    // Clear the framebuffer.
	glClearColor( .08f, .08f, .08f, 1.f);
	glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
	
	
    // Reset The View
	glLoadIdentity();	
	if(_threeD) {
		glTranslatef((GLfloat)_cameraTranslateX, (GLfloat)_cameraTranslateY, (GLfloat)_cameraOffset);
		if (_trackBallRotation[0] != 0.0f)
			glRotatef (_trackBallRotation[0], _trackBallRotation[1], _trackBallRotation[2], _trackBallRotation[3]);
		// accumlated world rotation via trackball
		glRotatef (_worldRotation[0], _worldRotation[1], _worldRotation[2], _worldRotation[3]);
	} else {
		glTranslatef((GLfloat)_cameraTranslateX, (GLfloat)_cameraTranslateY, 0.f);
		glScalef(-200.f/(GLfloat)_cameraOffset, -200.f/(GLfloat)_cameraOffset, 1.f);
	}

    if(_platformRasterVerticesCount>0) {
        glPolygonMode( GL_FRONT_AND_BACK, GL_FILL );
        glDisable(GL_COLOR_MATERIAL);
        glDisable(GL_LIGHTING);
        
        // Draw Platform
        glDisableClientState(GL_NORMAL_ARRAY);
        const GLsizei platformStride = sizeof(GLfloat)*3;
        
        glColor4f(1.f, .749f, 0.f, .1f);
        glBindBuffer(GL_ARRAY_BUFFER, _vbo[kPlatformVBO]);
        glVertexPointer(3, GL_FLOAT, platformStride, 0);
        glDrawArrays(GL_QUADS, 0, 4);
    
        glEnableClientState(GL_COLOR_ARRAY);
        const GLsizei platformRasterStride = sizeof(GLfloat)*8;
        
        glBindBuffer(GL_ARRAY_BUFFER, _vbo[kPlatformRasterVBO]);
        glColorPointer(4, GL_FLOAT, platformRasterStride, 0);
        glVertexPointer(3, GL_FLOAT, platformRasterStride, 4*sizeof(GLfloat));
        glDrawArrays(GL_LINES, 0, _platformRasterVerticesCount);
    }
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    
	glEnable(GL_DEPTH_TEST);
	[self renderContent];
	glDisable(GL_DEPTH_TEST);
	
	glFinish();
	[[self openGLContext] flushBuffer];
}

- (void)setCurrentMachine:(P3DMachineDriverBase*)value
{
    _currentMachine=value;
    [self setNeedsDisplay:YES];
}

- (void)setupPlatformVBOWithBufferName:(GLuint)bufferName
{
    Vector3* dimBuildPlattform = self.currentMachine.dimBuildPlattform;
    if(dimBuildPlattform) {
        Vector3* zeroBuildPlattform = self.currentMachine.zeroBuildPlattform;
        
        const GLsizei stride = sizeof(GLfloat)*3;
        const GLint numVertices = 4;
        const GLsizeiptr bufferSize = stride * numVertices;
        
        GLfloat * varray = (GLfloat*)malloc(bufferSize);
        NSInteger i = 0;
        
        varray[i++] = (GLfloat)-zeroBuildPlattform.x;
        varray[i++] = (GLfloat)-zeroBuildPlattform.y;
        varray[i++] = 0.f;
        varray[i++] = (GLfloat)-zeroBuildPlattform.x;
        varray[i++] = (GLfloat)dimBuildPlattform.y-(GLfloat)zeroBuildPlattform.y;
        varray[i++] = 0.f;
        varray[i++] = (GLfloat)dimBuildPlattform.x-(GLfloat)zeroBuildPlattform.x;
        varray[i++] = (GLfloat)dimBuildPlattform.y-(GLfloat)zeroBuildPlattform.y;
        varray[i++] = 0.f;
        varray[i++] = (GLfloat)dimBuildPlattform.x-(GLfloat)zeroBuildPlattform.x;
        varray[i++] = (GLfloat)-zeroBuildPlattform.y;
        varray[i++] = 0.f;
        
        glBindBuffer(GL_ARRAY_BUFFER, bufferName);
        glBufferData(GL_ARRAY_BUFFER, bufferSize, varray, GL_STATIC_DRAW);
        free(varray);
    }
}

- (GLsizei)setupPlatformRasterVBOWithBufferName:(GLuint)bufferName
{
    GLint numVertices = 0;
    Vector3* dimBuildPlattform = self.currentMachine.dimBuildPlattform;
    if(dimBuildPlattform) {
        Vector3* zeroBuildPlattform = self.currentMachine.zeroBuildPlattform;

        const GLsizei stride = sizeof(GLfloat)*8;
        numVertices = ((GLint)(dimBuildPlattform.x/10.f)+1+(GLint)(dimBuildPlattform.y/10.f)+1)*2+(dimBuildPlattform.z>0.f?(GLint)16:0);
        const GLsizeiptr bufferSize = stride * numVertices;
        
        GLfloat * varray = (GLfloat*)malloc(bufferSize);
        if(varray) {
            NSInteger i = 0;
            
            GLfloat r = 1.f;
            GLfloat g = 0.f;
            GLfloat b = 0.f;
            GLfloat a = .4f;
            
            for(float x=-zeroBuildPlattform.x; x<dimBuildPlattform.x-zeroBuildPlattform.x; x+=10.f) {
                varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
                varray[i++] = (GLfloat)x;
                varray[i++] = (GLfloat)-zeroBuildPlattform.y;
                varray[i++] = 0.f;
                varray[i++] = 0.f;
                varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
                varray[i++] = (GLfloat)x;
                varray[i++] = (GLfloat)dimBuildPlattform.y-(GLfloat)zeroBuildPlattform.y;
                varray[i++] = 0.f;
                varray[i++] = 0.f;
            }
            varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
            varray[i++] = (GLfloat)dimBuildPlattform.x-(GLfloat)zeroBuildPlattform.x;
            varray[i++] = (GLfloat)-zeroBuildPlattform.y;
            varray[i++] = 0.f;
            varray[i++] = 0.f;
            varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
            varray[i++] = (GLfloat)dimBuildPlattform.x-(GLfloat)zeroBuildPlattform.x;
            varray[i++] = (GLfloat)dimBuildPlattform.y-(GLfloat)zeroBuildPlattform.y;
            varray[i++] = 0.f;
            varray[i++] = 0.f;
            
            
            for(float y=-zeroBuildPlattform.y; y<dimBuildPlattform.y-zeroBuildPlattform.y; y+=10.f) {
                varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
                varray[i++] = (GLfloat)-zeroBuildPlattform.x;
                varray[i++] = (GLfloat)y;
                varray[i++] = 0.f;
                varray[i++] = 0.f;
                varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
                varray[i++] = (GLfloat)dimBuildPlattform.x-(GLfloat)zeroBuildPlattform.x;
                varray[i++] = (GLfloat)y;
                varray[i++] = 0.f;
                varray[i++] = 0.f;
            }
            varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
            varray[i++] = (GLfloat)-zeroBuildPlattform.x;
            varray[i++] = (GLfloat)dimBuildPlattform.y-(GLfloat)zeroBuildPlattform.y;
            varray[i++] = 0.f;
            varray[i++] = 0.f;
            varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
            varray[i++] = (GLfloat)dimBuildPlattform.x-(GLfloat)zeroBuildPlattform.x;
            varray[i++] = (GLfloat)dimBuildPlattform.y-(GLfloat)zeroBuildPlattform.y;
            varray[i++] = 0.f;
            varray[i++] = 0.f;
            
            if(dimBuildPlattform.z>0.f && self.threeD) {
                r = 1.f;
                g = 0.503f;
                b = 0.029f;
                a = .15f;
                
                // corners
                varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
                varray[i++] = (GLfloat)-zeroBuildPlattform.x;
                varray[i++] = (GLfloat)-zeroBuildPlattform.y;
                varray[i++] = 0.f;
                varray[i++] = 0.f;
                varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
                varray[i++] = (GLfloat)-zeroBuildPlattform.x;
                varray[i++] = (GLfloat)-zeroBuildPlattform.y;
                varray[i++] = dimBuildPlattform.z;
                varray[i++] = 0.f;
                varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
                varray[i++] = (GLfloat)dimBuildPlattform.x-(GLfloat)zeroBuildPlattform.x;
                varray[i++] = (GLfloat)-zeroBuildPlattform.y;
                varray[i++] = 0.f;
                varray[i++] = 0.f;
                varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
                varray[i++] = (GLfloat)dimBuildPlattform.x-(GLfloat)zeroBuildPlattform.x;
                varray[i++] = (GLfloat)-zeroBuildPlattform.y;
                varray[i++] = dimBuildPlattform.z;
                varray[i++] = 0.f;
                varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
                varray[i++] = (GLfloat)-zeroBuildPlattform.x;
                varray[i++] = (GLfloat)dimBuildPlattform.y-(GLfloat)zeroBuildPlattform.y;
                varray[i++] = 0.f;
                varray[i++] = 0.f;
                varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
                varray[i++] = (GLfloat)-zeroBuildPlattform.x;
                varray[i++] = (GLfloat)dimBuildPlattform.y-(GLfloat)zeroBuildPlattform.y;
                varray[i++] = dimBuildPlattform.z;
                varray[i++] = 0.f;
                varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
                varray[i++] = (GLfloat)dimBuildPlattform.x-(GLfloat)zeroBuildPlattform.x;
                varray[i++] = (GLfloat)dimBuildPlattform.y-(GLfloat)zeroBuildPlattform.y;
                varray[i++] = 0.f;
                varray[i++] = 0.f;
                varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
                varray[i++] = (GLfloat)dimBuildPlattform.x-(GLfloat)zeroBuildPlattform.x;
                varray[i++] = (GLfloat)dimBuildPlattform.y-(GLfloat)zeroBuildPlattform.y;
                varray[i++] = dimBuildPlattform.z;
                varray[i++] = 0.f;
                
                // Upper Frame
                varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
                varray[i++] = (GLfloat)-zeroBuildPlattform.x;
                varray[i++] = (GLfloat)-zeroBuildPlattform.y;
                varray[i++] = dimBuildPlattform.z;
                varray[i++] = 0.f;
                varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
                varray[i++] = (GLfloat)dimBuildPlattform.x-(GLfloat)zeroBuildPlattform.x;
                varray[i++] = (GLfloat)-zeroBuildPlattform.y;
                varray[i++] = dimBuildPlattform.z;
                varray[i++] = 0.f;
                varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
                varray[i++] = (GLfloat)dimBuildPlattform.x-(GLfloat)zeroBuildPlattform.x;
                varray[i++] = (GLfloat)-zeroBuildPlattform.y;
                varray[i++] = dimBuildPlattform.z;
                varray[i++] = 0.f;
                varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
                varray[i++] = (GLfloat)dimBuildPlattform.x-(GLfloat)zeroBuildPlattform.x;
                varray[i++] = (GLfloat)dimBuildPlattform.y-(GLfloat)zeroBuildPlattform.y;
                varray[i++] = dimBuildPlattform.z;
                varray[i++] = 0.f;
                varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
                varray[i++] = (GLfloat)dimBuildPlattform.x-(GLfloat)zeroBuildPlattform.x;
                varray[i++] = (GLfloat)dimBuildPlattform.y-(GLfloat)zeroBuildPlattform.y;
                varray[i++] = dimBuildPlattform.z;
                varray[i++] = 0.f;
                varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
                varray[i++] = (GLfloat)-zeroBuildPlattform.x;
                varray[i++] = (GLfloat)dimBuildPlattform.y-(GLfloat)zeroBuildPlattform.y;
                varray[i++] = dimBuildPlattform.z;
                varray[i++] = 0.f;
                varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
                varray[i++] = (GLfloat)-zeroBuildPlattform.x;
                varray[i++] = (GLfloat)dimBuildPlattform.y-(GLfloat)zeroBuildPlattform.y;
                varray[i++] = dimBuildPlattform.z;
                varray[i++] = 0.f;
                varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
                varray[i++] = (GLfloat)-zeroBuildPlattform.x;
                varray[i++] = (GLfloat)-zeroBuildPlattform.y;
                varray[i++] = dimBuildPlattform.z;
                varray[i++] = 0.f;
                
            }
            glBindBuffer(GL_ARRAY_BUFFER, bufferName);
            glBufferData(GL_ARRAY_BUFFER, bufferSize, varray, GL_STATIC_DRAW);
            free(varray);
        }
    }
    return numVertices;
}

@end
