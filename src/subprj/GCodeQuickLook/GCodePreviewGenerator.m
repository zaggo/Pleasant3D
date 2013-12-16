//
//  GCodePreviewGenerator.m
//  GCodeQuickLook
//
//  Created by Eberhard Rensch on 07.01.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//
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

#import "GCodePreviewGenerator.h"
#import "NSArray+GCode.h"
#import <OpenGL/glu.h>

enum {
    kGcode3DPrinterLegacy,
    kGcode3DPrinter5D,
    kGcodeMill
};

#pragma mark - Helper function to flip image data
static void swizzleBitmap(void * data, int rowBytes, int height) {
    int top, bottom;
    void *buffer;
    void *topP;
    void *bottomP;
    void *base;
	
    top = 0;
    bottom = height - 1;
    base = data;
    buffer = malloc(rowBytes);
	
    while (top < bottom) {
        topP = (void *)((top * rowBytes) + (intptr_t)base);
        bottomP = (void *)((bottom * rowBytes) + (intptr_t)base);
		
        bcopy(topP, buffer, rowBytes);
        bcopy(bottomP, topP, rowBytes);
        bcopy(buffer, bottomP, rowBytes);
		
        ++top;
        --bottom;
    }
    free(buffer);
}

const CGFloat kRenderUpsizeFaktor=3.;

@interface ExtrudingState : NSObject
@property (assign, nonatomic) NSInteger gCodeType;
@property (assign, nonatomic) BOOL extruding;
@property (assign, nonatomic) float currentExtrudedLengthToolA;
@property (assign, nonatomic) float currentExtrudedLengthToolB;
@property (assign, nonatomic) BOOL usingToolB;
@property (assign, nonatomic) BOOL extrutionBegan;
@end

@implementation ExtrudingState
@end

#pragma mark - Helper NSScanner Category
@implementation NSScanner (ParseGCode)
- (BOOL)updateLocation:(Vector3*)currentLocation extrudingState:(ExtrudingState*)state
{
    BOOL foundCoordinate=NO;
	float value;
	if([self scanString:@"X" intoString:nil]) {
		[self scanFloat:&value];
		currentLocation.x = value;
        foundCoordinate=YES;
	}
	if([self scanString:@"Y" intoString:nil]) {
		[self scanFloat:&value];
		currentLocation.y = value;
        foundCoordinate=YES;
	}
	if([self scanString:@"Z" intoString:nil]) {
		[self scanFloat:&value];
		currentLocation.z = value;
        foundCoordinate=YES;
	}
    
    if(state) { // Only valid when 3DPrining
        if([self scanString:@"E" intoString:nil] || [self scanString:@"A" intoString:nil]) {
            
            // We're using ToolA for this move
            [self scanFloat:&value];
            BOOL extruding = (value > state.currentExtrudedLengthToolA);
            state.currentExtrudedLengthToolA = value;
            if (extruding && (!state.extruding || state.usingToolB)) {
                    state.extrutionBegan = YES;
            }
            state.extruding=extruding;
            
            state.usingToolB = NO;
            
        } else if([self scanString:@"B" intoString:nil]) {
            
            // We're using ToolB for this move
            [self scanFloat:&value];
            BOOL extruding = (value > state.currentExtrudedLengthToolB);
            state.currentExtrudedLengthToolB = value;
            if (extruding && (!state.extruding || !state.usingToolB)) {
                    state.extrutionBegan = YES;
            }
            state.extruding=extruding;

            state.usingToolB = YES;
        }
    }
    
    return foundCoordinate;
}

- (BOOL)isLayerStartWithCurrentLocation:(Vector3*)currentLocation oldZ:(CGFloat*)oldZ layerStartWordExists:(BOOL)layerStartWordExist
{
	BOOL isLayerStart = NO;
	
	if(layerStartWordExist)
	{
		if([self scanString:@"(<layer>" intoString:nil])
			isLayerStart = YES;
	}
	else if([self scanString:@"G1" intoString:nil] || 
			[self scanString:@"G2" intoString:nil] ||
			[self scanString:@"G3" intoString:nil])
	{
		[self updateLocation:currentLocation extrudingState:nil];
		if(currentLocation.z-*oldZ >.1)
		{
			*oldZ=currentLocation.z;
			isLayerStart = YES;
		}
	}
	[self setScanLocation:0];
	return isLayerStart;
}

@end

#pragma mark - GCodePreviewGenerator
@implementation GCodePreviewGenerator
{
    NSInteger _gCodeType;

    BOOL _thumbnail;
    CGSize _renderSize;
    
    NSArray* _gCodePanes;
    Vector3* _cornerMinimum;
    Vector3* _cornerMaximum;
    CGFloat _extrusionWidth;
    
    CGFloat _othersAlpha;
    NSUInteger _currentLayer;
    
    CGFloat _cameraOffset;
    CGFloat _rotateX;
    CGFloat _rotateY;
    
    Vector3* _dimBuildPlattform;
    Vector3* _centerBuildPlatform;
    
    NSArray* _extrusionColors;
    NSColor* _extrusionOffColor;
}

- (NSArray*)parseLines:(NSArray*)gCodeLineScanners
{
	BOOL isThereALayerStartWord=[gCodeLineScanners isThereAFirstWord:@"(<layer>"];
		
	NSMutableArray* panes = [NSMutableArray array];
	NSMutableArray* currentPane = nil;
	Vector3* currentLocation = [[Vector3 alloc] initVectorWithX:0. Y:0. Z:0.];
	CGFloat oldZ = -FLT_MAX;
	NSInteger extrusionNumber=0;
    Vector3* highCorner = [[Vector3 alloc] initVectorWithX:-FLT_MAX Y:-FLT_MAX Z:-FLT_MAX];
	Vector3* lowCorner = [[Vector3 alloc] initVectorWithX:FLT_MAX Y:FLT_MAX Z:FLT_MAX];
    ExtrudingState* state = nil;
    if(_gCodeType!=kGcodeMill) {
        state = [[ExtrudingState alloc] init];
        state.gCodeType = _gCodeType;
    }
    
    for(NSScanner* lineScanner in gCodeLineScanners) {
		[lineScanner setScanLocation:0];
		if([lineScanner isLayerStartWithCurrentLocation:currentLocation oldZ:&oldZ layerStartWordExists:isThereALayerStartWord])
		{
			extrusionNumber = 0;
			currentPane = [[NSMutableArray alloc] init];
			[panes addObject:currentPane];
		}
		if([lineScanner scanString:@"G1" intoString:nil])
		{
            BOOL validLocation = [lineScanner updateLocation:currentLocation extrudingState:state];
            
            if(state.extrutionBegan) {
                extrusionNumber++;
                [currentPane addObject:[_extrusionColors objectAtIndex:extrusionNumber%[_extrusionColors count]]];
                state.extrutionBegan=NO;
            }
            
			if(validLocation && (state==nil || state.extruding )) {
                [currentPane addObject:[currentLocation copy]]; // Add the centered point
                [lowCorner minimizeWith:currentLocation];
                [highCorner maximizeWith:currentLocation];
            }
		}
		else if([lineScanner scanString:@"M101" intoString:nil])
		{
			extrusionNumber++;
			[currentPane addObject:[_extrusionColors objectAtIndex:extrusionNumber%[_extrusionColors count]]];
            state.extruding=YES;
		}
		else if([lineScanner scanString:@"M103" intoString:nil])
		{
			[currentPane addObject:_extrusionOffColor];
            state.extruding=NO;
		}
	}
    
	_cornerMinimum = lowCorner;
	_cornerMaximum = highCorner;
	
	return panes;
}

- (void)analyzeGcodeType:(NSString*)gcode {
    _gCodeType = kGcodeMill;
    
    NSError* error=nil;
    
    // If a G-Command followed by a E parameter is found -> 5D-Printing gCode
    NSRegularExpression* regex = [[NSRegularExpression alloc] initWithPattern:@"[\\n\\r]\\s*G\\d+.*?E[\\d\\.]+.*?[\\n\\r]" options:0 error:&error];
    NSTextCheckingResult* result = [regex firstMatchInString:gcode options:0 range:NSMakeRange(0, gcode.length)];
    if(result && result.range.location!=NSNotFound) {
        _gCodeType = kGcode3DPrinter5D;
    } else {
        // If one of the bore commands or a circular command is present -> Mill gCode
        regex = [[NSRegularExpression alloc] initWithPattern:@"[\\n\\r]\\s*G(81|82|83|84|85|86|87|88|89|2|3|02|03)\\s" options:0 error:&error];
        result = [regex firstMatchInString:gcode options:0 range:NSMakeRange(0, gcode.length)];
        if(result==nil || result.range.location==NSNotFound) {
            
            // No specific Mill code found. Check for M101 or M103 commands -> legacy 3D-printing gCode
            regex = [[NSRegularExpression alloc] initWithPattern:@"[\\n\\r]\\s*M(101|103)\\s" options:0 error:&error];
            result = [regex firstMatchInString:gcode options:0 range:NSMakeRange(0, gcode.length)];
            if(result && result.range.location!=NSNotFound) {
                _gCodeType = kGcode3DPrinterLegacy;
            }
        }
    }

    NSLog(@"analyzeGCodeType: %ld", (long)_gCodeType);
}

- (id)initWithURL:(NSURL*)gCodeURL size:(CGSize)size forThumbnail:(BOOL)forThumbnail
{
	self = [super init];
	if(self) {
		// 'brown', 'red', 'orange', 'yellow', 'green', 'blue', 'purple'
		_extrusionColors = [NSArray arrayWithObjects:
                        [[NSColor brownColor] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                        [[NSColor redColor] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                        [[NSColor orangeColor] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                        [[NSColor yellowColor] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                        [[NSColor greenColor] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                        [[NSColor blueColor] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                        [[NSColor purpleColor] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                        nil];
        _extrusionOffColor = [[[NSColor grayColor] colorWithAlphaComponent:0.6] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
        
		_thumbnail = forThumbnail;
		_othersAlpha = .75;
		_rotateX = 0.;
		_rotateY = -45.;

		if(_thumbnail)
			_renderSize = CGSizeMake(512.,512.);
		else
			_renderSize = CGSizeMake(size.width*kRenderUpsizeFaktor,size.height*kRenderUpsizeFaktor);

		NSError* error;
		NSString* gCode = [[[NSString alloc] initWithContentsOfURL:gCodeURL encoding:NSUTF8StringEncoding error:&error] uppercaseString];
		if(gCode) {
            [self analyzeGcodeType:gCode];
            
			// Create an array of linescanners
			NSMutableArray* gCodeLineScanners = [[NSMutableArray alloc] init];
			NSArray* untrimmedLines = [gCode componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
			NSCharacterSet* whiteSpaceSet = [NSCharacterSet whitespaceCharacterSet];
			[untrimmedLines enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
				[(NSMutableArray*)gCodeLineScanners addObject:[NSScanner scannerWithString:[obj stringByTrimmingCharactersInSet:whiteSpaceSet]]];
			}];
								
			_gCodePanes = [self parseLines:gCodeLineScanners];
			
			if([_gCodePanes count]>0) {
				NSInteger maxLayers = [_gCodePanes count]-1;
				_currentLayer=maxLayers*.7;
			} else {
				NSLog(@"Error while parsing: %@",gCodeURL);
				_currentLayer=0;
			}
		}
		else
			NSLog(@"Error while reading: %@: %@", gCodeURL, [error localizedDescription]);
		
        _dimBuildPlattform = [_cornerMaximum sub:_cornerMinimum];
        _centerBuildPlatform = [[Vector3 alloc] initVectorWithX:_cornerMinimum.x+_dimBuildPlattform.x/2.f Y:_cornerMinimum.y+_dimBuildPlattform.y/2.f Z:0/*_cornerMinimum.z*/];
        [_dimBuildPlattform imul:1.2f];
        
		_cameraOffset = - 2.*MAX(_dimBuildPlattform.x, _dimBuildPlattform.z);
		
	}
	return self;
}

- (CGImageRef)newPreviewImage
{	
	CGImageRef cgImage=NULL;
    CGLError glError = kCGLNoError;
    
	CGLPixelFormatObj pixelFormatObj=NULL;
    CGLContextObj contextObj=NULL;
	GLint numPixelFormats=0;

	CGLPixelFormatAttribute attribs[] =
	{
        kCGLPFAOpenGLProfile, kCGLOGLPVersion_Legacy,
        kCGLPFAMinimumPolicy,
		kCGLPFAColorSize, (CGLPixelFormatAttribute)32,
		kCGLPFADepthSize, (CGLPixelFormatAttribute)32,
//		kCGLPFASupersample,
//		kCGLPFASampleAlpha,
        kCGLPFARemotePBuffer,
		(CGLPixelFormatAttribute)0
	} ;
    
	glError = CGLChoosePixelFormat (attribs, &pixelFormatObj, &numPixelFormats);
	
    if(pixelFormatObj==NULL)
        NSLog(@"############ pixelFormatObj == NULL!! numPixelFormats=%d, err = %d", numPixelFormats, glError);
    else {
        CGLCreateContext (pixelFormatObj, NULL, &contextObj);
        CGLDestroyPixelFormat (pixelFormatObj);
        glError = CGLSetCurrentContext (contextObj);
    }
    
    if(pixelFormatObj && glError == kCGLNoError) {
        
        void *bitmapContextData=NULL;
        
        long bytewidth = (GLsizei)_renderSize.width * 4; // Assume 4 bytes/pixel for now
        bytewidth = (bytewidth + 3) & ~3; // Align to 4 bytes
        
        /* Build bitmap context */
        bitmapContextData = malloc((GLsizei)_renderSize.height * bytewidth);
        if (bitmapContextData) {
            
            CGColorSpaceRef cSpace = CGColorSpaceCreateWithName (kCGColorSpaceGenericRGB);
            CGContextRef bitmap;
            bitmap = CGBitmapContextCreate(bitmapContextData, (GLsizei)_renderSize.width, (GLsizei)_renderSize.height, 8, bytewidth, cSpace, kCGImageAlphaPremultipliedFirst /* RGBA */);
            CFRelease(cSpace);
            
            // FBO
            GLuint fb;
            GLuint fboRenderBuffers[2];
            glGenFramebuffers(1, &fb);
            glBindFramebuffer(GL_FRAMEBUFFER, fb);
            glGenRenderbuffers(2, fboRenderBuffers);
            glBindRenderbuffer(GL_RENDERBUFFER, fboRenderBuffers[0]);
            glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT, _renderSize.width, _renderSize.height);
            glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, fboRenderBuffers[0]);
            glBindRenderbuffer(GL_RENDERBUFFER, fboRenderBuffers[1]);
            glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA, _renderSize.width, _renderSize.height);
            glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, fboRenderBuffers[1]);
            
            GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
            if(GL_FRAMEBUFFER_COMPLETE == status) {
                glViewport(0, 0, _renderSize.width, _renderSize.height);
                
                glMatrixMode( GL_PROJECTION );
                glLoadIdentity();
                gluPerspective( 32., _renderSize.width / _renderSize.height, 10., MAX(1000.,- 2. *_cameraOffset) );
                
                // Clear the framebuffer.
                glMatrixMode(GL_MODELVIEW);
                glLoadIdentity();						// Reset The View
                
                glClearColor( 0., 0., 0., 0. );
                glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
                glLoadIdentity();	
                
                glEnable (GL_LINE_SMOOTH); 
                glEnable (GL_BLEND); 
                glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
                                
              //  glTranslatef(-_centerBuildPlatform.x, -(_cornerMinimum.z+_dimBuildPlattform.z/2.f), -_centerBuildPlatform.y+_cameraOffset);
                glTranslatef(-_centerBuildPlatform.x, -_centerBuildPlatform.y, _cameraOffset);

                glRotatef((GLfloat)_rotateX, 0.f, 1.f, 0.f);
                glRotatef((GLfloat)_rotateY, 1.f, 0.f, 0.f);
                
               // glTranslatef(0, 0, _cameraOffset);

                glEnableClientState(GL_COLOR_ARRAY);
                glEnableClientState(GL_VERTEX_ARRAY);
                
                GLuint vbo[3];
                glGenBuffers(3, vbo);
                if(_thumbnail)
                    [self setupPlatformVBOWithBufferName:vbo[0] colorR:.252f G:.212f B:.122f A:1.f];
                else
                    [self setupPlatformVBOWithBufferName:vbo[0] colorR:1.f G:.749f B:0.f A:.1f];
                GLsizei platformRasterVerticesCount = [self setupPlatformRasterVBOWithBufferName:vbo[1]];
                
                GLint layerVertexIndex[_gCodePanes.count+1];
                bzero(layerVertexIndex, sizeof(GLint)*(_gCodePanes.count+1));
                GLsizei objectVerticesCount = [self setupObjectVBOWithBufferName:vbo[2] layerVertexIndex:layerVertexIndex];
                
                const GLsizei stride = sizeof(GLfloat)*8; // RGBA + XYZW
                
                // Draw Platform
                glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
                glColorPointer(/*rgba*/4, GL_FLOAT, stride, 0);
                glVertexPointer(/*xyz*/3, GL_FLOAT, stride, 4*sizeof(GLfloat));
                glDrawArrays(GL_QUADS, /*firstIndex*/0, /*indexCount*/4);
                
                glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
                glColorPointer(/*rgba*/4, GL_FLOAT, stride, 0);
                glVertexPointer(/*xyz*/3, GL_FLOAT, stride, 4*sizeof(GLfloat));
                glDrawArrays(GL_LINES, 0, platformRasterVerticesCount);

                glTranslatef(0, 0., -_cornerMinimum.z);

                // Draw Object
                glBindBuffer(GL_ARRAY_BUFFER, vbo[2]);
                glColorPointer(/*rgba*/4, GL_FLOAT, stride, 0);
                glVertexPointer(/*xyz*/3, GL_FLOAT, stride, 4*sizeof(GLfloat));
               
                GLint startIndex = 0;
                GLsizei count = 0;
                if(_currentLayer>0) {
                    glLineWidth(1.f);
                    count = layerVertexIndex[_currentLayer];
                    glDrawArrays(GL_LINES, startIndex, count);
                    startIndex += count;
                }
                
                glLineWidth(2.f);
                count = layerVertexIndex[_currentLayer+1]-startIndex;
                
                glDrawArrays(GL_LINES, startIndex, count);
                startIndex += count;

                if(_currentLayer<_gCodePanes.count-1) {
                    glLineWidth(1.f);
                    count = objectVerticesCount-startIndex;
                    glDrawArrays(GL_LINES, startIndex, count);
                }
                
                // Cleanup
                glBindBuffer(GL_ARRAY_BUFFER, 0);
                glDeleteBuffers(3, vbo);

                glFlush();
                
                /* Read framebuffer into our bitmap */
                glPixelStorei(GL_PACK_ALIGNMENT, (GLint)4); /* Force 4-byte alignment */
                glPixelStorei(GL_PACK_ROW_LENGTH, (GLint)0);
                glPixelStorei(GL_PACK_SKIP_ROWS, (GLint)0);
                glPixelStorei(GL_PACK_SKIP_PIXELS, (GLint)0);
                
                /* Fetch the data in XRGB format, matching the bitmap context. */
                glReadPixels((GLint)0, (GLint)0, (GLsizei)_renderSize.width, (GLsizei)_renderSize.width, GL_BGRA,
                             GL_UNSIGNED_INT_8_8_8_8, // for Intel! http://lists.apple.com/archives/quartz-dev/2006/May/msg00100.html
                             bitmapContextData);
                
                swizzleBitmap(bitmapContextData, bytewidth, (GLsizei)_renderSize.height);
            
                /* Make an image out of our bitmap; does a cheap vm_copy of the bitmap */
                cgImage = CGBitmapContextCreateImage(bitmap);
            }
            else
                NSLog(@"FBO not complete: %d", status);
            
            glBindFramebuffer(GL_FRAMEBUFFER, 0);
            glDeleteRenderbuffers(2, fboRenderBuffers);
            glDeleteFramebuffers(1, &fb);
            
            /* Get rid of bitmap */
            CFRelease(bitmap);
            free(bitmapContextData);
        }
    }
    
    CGLSetCurrentContext (NULL);
    if(contextObj) {
        CGLClearDrawable (contextObj);
        CGLDestroyContext (contextObj);
    }
    
	return cgImage;
}

- (void)setupPlatformVBOWithBufferName:(GLuint)bufferName colorR:(GLfloat)r G:(GLfloat)g B:(GLfloat)b A:(GLfloat)a
{
    
    const GLsizei stride = sizeof(GLfloat)*8;
    const GLint numVertices = 4;
    const GLsizeiptr bufferSize = stride * numVertices;
    
    GLfloat * varray = (GLfloat*)malloc(bufferSize); // 4 Dimensional, 4 Corners, 2 Components (Coordinate + Color)
    NSInteger i = 0;
    
    varray[i++] = r;
    varray[i++] = g;
    varray[i++] = b;
    varray[i++] = a;
    varray[i++] = (GLfloat)(_centerBuildPlatform.x-_dimBuildPlattform.x/2.f);
    varray[i++] = (GLfloat)(_centerBuildPlatform.y-_dimBuildPlattform.y/2.f);
    varray[i++] = (GLfloat)_centerBuildPlatform.z;
    varray[i++] = 0.f;
    varray[i++] = r;
    varray[i++] = g;
    varray[i++] = b;
    varray[i++] = a;
    varray[i++] = (GLfloat)(_centerBuildPlatform.x-_dimBuildPlattform.x/2.f);
    varray[i++] = (GLfloat)(_centerBuildPlatform.y+_dimBuildPlattform.y/2.f);
    varray[i++] = (GLfloat)_centerBuildPlatform.z;
    varray[i++] = 0.f;
    varray[i++] = r;
    varray[i++] = g;
    varray[i++] = b;
    varray[i++] = a;
    varray[i++] = (GLfloat)(_centerBuildPlatform.x+_dimBuildPlattform.x/2.f);
    varray[i++] = (GLfloat)(_centerBuildPlatform.y+_dimBuildPlattform.y/2.f);
    varray[i++] = (GLfloat)_centerBuildPlatform.z;
    varray[i++] = 0.f;
    varray[i++] = r;
    varray[i++] = g;
    varray[i++] = b;
    varray[i++] = a;
    varray[i++] = (GLfloat)(_centerBuildPlatform.x+_dimBuildPlattform.x/2.f);
    varray[i++] = (GLfloat)(_centerBuildPlatform.y-_dimBuildPlattform.y/2.f);
    varray[i++] = (GLfloat)_centerBuildPlatform.z;
    varray[i++] = 0.f;
    
    glBindBuffer(GL_ARRAY_BUFFER, bufferName);
    glBufferData(GL_ARRAY_BUFFER, bufferSize, varray, GL_STATIC_DRAW);
    free(varray);
}

- (GLsizei)setupPlatformRasterVBOWithBufferName:(GLuint)bufferName
{
    const GLsizei stride = sizeof(GLfloat)*8;
    const GLint numVertices = ((GLint)(_dimBuildPlattform.x/10.f)+2+(GLint)(_dimBuildPlattform.y/10.f)+2)*2;
    const GLsizeiptr bufferSize = stride * numVertices;
    
    GLfloat * varray = (GLfloat*)malloc(bufferSize);
    NSInteger i = 0;
    
    GLfloat r = 1.f;
    GLfloat g = 0.f;
    GLfloat b = 0.f;
    GLfloat a = .4f;
    
    for(float x=0.f; x<_dimBuildPlattform.x; x+=10.f) {
        varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
        varray[i++] = (GLfloat)(_centerBuildPlatform.x-_dimBuildPlattform.x/2.f+x);
        varray[i++] = (GLfloat)(_centerBuildPlatform.y-_dimBuildPlattform.y/2.f);
        varray[i++] = (GLfloat)_centerBuildPlatform.z;
        varray[i++] = 0.f;
        varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
        varray[i++] = (GLfloat)(_centerBuildPlatform.x-_dimBuildPlattform.x/2.f+x);
        varray[i++] = (GLfloat)(_centerBuildPlatform.y+_dimBuildPlattform.y/2.f);
        varray[i++] = (GLfloat)_centerBuildPlatform.z;
        varray[i++] = 0.f;
    }
    varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
    varray[i++] = (GLfloat)(_centerBuildPlatform.x+_dimBuildPlattform.x/2.f);
    varray[i++] = (GLfloat)(_centerBuildPlatform.y-_dimBuildPlattform.y/2.f);
    varray[i++] = (GLfloat)_centerBuildPlatform.z;
    varray[i++] = 0.f;
    varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
    varray[i++] = (GLfloat)(_centerBuildPlatform.x+_dimBuildPlattform.x/2.f);
    varray[i++] = (GLfloat)(_centerBuildPlatform.y+_dimBuildPlattform.y/2.f);
    varray[i++] = (GLfloat)_centerBuildPlatform.z;
    varray[i++] = 0.f;
    
    
    for(float y=0.f; y<_dimBuildPlattform.y; y+=10.f) {
        varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
        varray[i++] = (GLfloat)(_centerBuildPlatform.x-_dimBuildPlattform.x/2.f);
        varray[i++] = (GLfloat)(_centerBuildPlatform.y-_dimBuildPlattform.y/2.f+y);
        varray[i++] = (GLfloat)_centerBuildPlatform.z;
        varray[i++] = 0.f;
        varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
        varray[i++] = (GLfloat)(_centerBuildPlatform.x+_dimBuildPlattform.x/2.f);
        varray[i++] = (GLfloat)(_centerBuildPlatform.y-_dimBuildPlattform.y/2.f+y);
        varray[i++] = (GLfloat)_centerBuildPlatform.z;
        varray[i++] = 0.f;
    }
    varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
    varray[i++] = (GLfloat)(_centerBuildPlatform.x-_dimBuildPlattform.x/2.f);
    varray[i++] = (GLfloat)(_centerBuildPlatform.y+_dimBuildPlattform.y/2.f);
    varray[i++] = (GLfloat)_centerBuildPlatform.z;
    varray[i++] = 0.f;
    varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
    varray[i++] = (GLfloat)(_centerBuildPlatform.x+_dimBuildPlattform.x/2.f);
    varray[i++] = (GLfloat)(_centerBuildPlatform.y+_dimBuildPlattform.y/2.f);
    varray[i++] = (GLfloat)_centerBuildPlatform.z;
    varray[i++] = 0.f;
    
    glBindBuffer(GL_ARRAY_BUFFER, bufferName);
    glBufferData(GL_ARRAY_BUFFER, bufferSize, varray, GL_STATIC_DRAW);
    free(varray);
    
    return numVertices;
}

- (GLsizei)setupObjectVBOWithBufferName:(GLuint)bufferName layerVertexIndex:(GLint*)layerVertexIndex
{
    const GLsizei stride = sizeof(GLfloat)*8;
    
    GLint numVertices = 0;
    for(NSArray* pane in _gCodePanes)
        numVertices+=(GLint)pane.count; // This results in a numVertices larger than the actually needed
    
    numVertices*=2;
    
    GLsizeiptr bufferSize = stride * numVertices;

    if(bufferSize>0) {
        GLfloat * varray = (GLfloat*)malloc(bufferSize);

        GLfloat r = 1.f;
        GLfloat g = 0.f;
        GLfloat b = 0.f;
        GLfloat a = 1.f;

        numVertices = 0;
        NSInteger i = 0;
        NSInteger layer=0;
        for(NSArray* pane in _gCodePanes) {
            layerVertexIndex[layer] = numVertices;
            
            Vector3* lastPoint = nil;
            for(id elem in pane) {
                if([elem isKindOfClass:[Vector3 class]]) {
                    Vector3* point = (Vector3*)elem;
                    if(lastPoint) {
                        varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
                        varray[i++] = (GLfloat)lastPoint.x;
                        varray[i++] = (GLfloat)lastPoint.y;
                        varray[i++] = (GLfloat)lastPoint.z;
                        varray[i++] = 0.f;
                        varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
                        varray[i++] = (GLfloat)point.x;
                        varray[i++] = (GLfloat)point.y;
                        varray[i++] = (GLfloat)point.z;
                        varray[i++] = 0.f;
                        
                        numVertices+=2;
                    }
                    lastPoint = point;
                } else {
                    NSColor *color = elem;
                    GLfloat alphaMultiplier;
                    if(_currentLayer > layer)
                        alphaMultiplier = powf((GLfloat)_othersAlpha, 3.f);
                    else if(_currentLayer < layer)
                        alphaMultiplier = powf((GLfloat)_othersAlpha, 3.f); //powf((GLfloat)othersAlpha, 3.f)/(1.f+20.f*powf((GLfloat)othersAlpha, 3.f));
                    else
                        alphaMultiplier = 1.f;
                    
                    r = (GLfloat)color.redComponent;
                    g = (GLfloat)color.greenComponent;
                    b = (GLfloat)color.blueComponent;
                    a = (GLfloat)color.alphaComponent*alphaMultiplier;
                }
            }
            layer++;
        }
        
        layerVertexIndex[layer] = numVertices;
        bufferSize = stride * numVertices;
        
        glBindBuffer(GL_ARRAY_BUFFER, bufferName);
        glBufferData(GL_ARRAY_BUFFER, bufferSize, varray, GL_STATIC_DRAW);
        free(varray);
    }
    
    return numVertices;
}

@end
