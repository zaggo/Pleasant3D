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

#import <OpenGL/glu.h>
#import "GCodePreviewGenerator.h"
#import "NSArray+GCode.h"
#import "PSLog.h"
#import "P3DParsedGCodeBase.h"
#import "P3DParsedGCodeMill.h"
#import "P3DParsedGCodePrinter.h"

enum {
    kGcode3DPrinter,
    kGcodeMill
};

enum {
    kPlatformVBO,
    kPlatformRasterVBO,
    kCurrentLayerVBO,
    kVBOCount
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

#pragma mark - GCodePreviewGenerator
@implementation GCodePreviewGenerator
{
    BOOL _thumbnail;
    CGSize _renderSize;
    
    CGFloat _othersAlpha;
    NSUInteger _currentLayer;
    
    CGFloat _cameraOffset;
    CGFloat _rotateX;
    CGFloat _rotateY;
    
    Vector3* _dimBuildPlattform;
    Vector3* _centerBuildPlatform;
    
    P3DParsedGCodeBase* _parsedGCode;
    
    GLuint _vbo[kVBOCount];
    
    float _zShift;
}


- (NSInteger)analyzeGcodeType:(NSString*)gcode {
    NSInteger type = kGcodeMill;
    
    NSError* error=nil;
    
    // If a G-Command followed by a E parameter is found -> 5D-Printing gCode
    NSRegularExpression* regex = [[NSRegularExpression alloc] initWithPattern:@"[\\n\\r]\\s*G\\d+.*?E[\\d\\.]+.*?[\\n\\r]" options:0 error:&error];
    NSTextCheckingResult* result = [regex firstMatchInString:gcode options:0 range:NSMakeRange(0, gcode.length)];
    if(result && result.range.location!=NSNotFound) {
        type = kGcode3DPrinter;
    } else {
        // If one of the bore commands or a circular command is present -> Mill gCode
        regex = [[NSRegularExpression alloc] initWithPattern:@"[\\n\\r]\\s*G(81|82|83|84|85|86|87|88|89|2|3|02|03)\\s" options:0 error:&error];
        result = [regex firstMatchInString:gcode options:0 range:NSMakeRange(0, gcode.length)];
        if(result==nil || result.range.location==NSNotFound) {
            
            // No specific Mill code found. Check for M101 or M103 commands -> legacy 3D-printing gCode
            regex = [[NSRegularExpression alloc] initWithPattern:@"[\\n\\r]\\s*M(101|103)\\s" options:0 error:&error];
            result = [regex firstMatchInString:gcode options:0 range:NSMakeRange(0, gcode.length)];
            if(result && result.range.location!=NSNotFound) {
                type = kGcode3DPrinter;
            }
        }
    }

    PSLog(@"parseGCode", PSPrioNormal, @"analyzeGCodeType: %ld", (long)type);
    return type;
}

- (id)initWithURL:(NSURL*)gCodeURL size:(CGSize)size forThumbnail:(BOOL)forThumbnail
{
	self = [super init];
	if(self) {

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
            switch([self analyzeGcodeType:gCode]) {
                case kGcode3DPrinter:
                    _parsedGCode = [[P3DParsedGCodePrinter alloc] initWithGCodeString:gCode printer:nil];
                    break;
                case kGcodeMill:
                    _parsedGCode = [[P3DParsedGCodeMill alloc] initWithGCodeString:gCode printer:nil];
                    break;
            }
        } else {
			PSErrorLog(@"Error while reading: %@: %@", gCodeURL, [error localizedDescription]);
        }
		
        _dimBuildPlattform = [_parsedGCode.cornerHigh sub:_parsedGCode.cornerLow];
        _zShift = -(_parsedGCode.cornerHigh.z-_dimBuildPlattform.z/2.f);
        _centerBuildPlatform = [[Vector3 alloc] initVectorWithX:_parsedGCode.cornerLow.x+_dimBuildPlattform.x/2.f Y:_parsedGCode.cornerLow.y+_dimBuildPlattform.y/2.f Z:_zShift];
        [_dimBuildPlattform imul:1.2f];
        
        float maxDist = 2.f*MAX(_dimBuildPlattform.x, _dimBuildPlattform.y);
        maxDist = MAX(maxDist, 2.5f*_dimBuildPlattform.z);
		_cameraOffset = -maxDist;
		
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
		kCGLPFASupersample,
		kCGLPFASampleAlpha,
        kCGLPFARemotePBuffer,
		(CGLPixelFormatAttribute)0
	} ;
    
	glError = CGLChoosePixelFormat (attribs, &pixelFormatObj, &numPixelFormats);
	
    if(pixelFormatObj==NULL)
        PSErrorLog(@"############ pixelFormatObj == NULL!! numPixelFormats=%d, err = %d", numPixelFormats, glError);
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
                
                glClearColor( 0., 0., 0., 1. );
                glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
                glLoadIdentity();	
                
                glEnable (GL_LINE_SMOOTH); 
                glEnable (GL_BLEND); 
                glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
                                

                glTranslatef(-_centerBuildPlatform.x, -_centerBuildPlatform.y, _cameraOffset);
                glRotatef((GLfloat)_rotateX, 0.f, 1.f, 0.f);
                glRotatef((GLfloat)_rotateY, 1.f, 0.f, 0.f);
                
                glEnableClientState(GL_VERTEX_ARRAY);
                glEnableClientState(GL_COLOR_ARRAY);
               
                glGenBuffers(kVBOCount, _vbo);

//                if(_thumbnail)
//                    [self setupPlatformVBOWithBufferName:_vbo[kPlatformVBO] colorR:.252f G:.212f B:.122f A:1.f];
//                else
                    [self setupPlatformVBOWithBufferName:_vbo[kPlatformVBO] colorR:1.f G:.749f B:0.f A:.1f];
                GLsizei platformRasterVerticesCount = [self setupPlatformRasterVBOWithBufferName:_vbo[kPlatformRasterVBO]];
                [self setupObjectVBOWithBufferName:_vbo[kCurrentLayerVBO]];
                
                if(platformRasterVerticesCount>0) {
                    glPolygonMode( GL_FRONT_AND_BACK, GL_FILL );
                    
                    // Draw Platform
                    const GLsizei platformStride = sizeof(GLfloat)*8; // RGBA + XYZW
                   
                    glLineWidth(1.f);
                    glBindBuffer(GL_ARRAY_BUFFER, _vbo[kPlatformVBO]);
                    glColorPointer(/*rgba*/4, GL_FLOAT, platformStride, 0);
                    glVertexPointer(/*xyz*/3, GL_FLOAT, platformStride, 4*sizeof(GLfloat));
                    glDrawArrays(GL_QUADS, 0, 4);
                    
                    glBindBuffer(GL_ARRAY_BUFFER, _vbo[kPlatformRasterVBO]);
                    glColorPointer(/*rgba*/4, GL_FLOAT, platformStride, 0);
                    glVertexPointer(/*xyz*/3, GL_FLOAT, platformStride, 4*sizeof(GLfloat));
                    glDrawArrays(GL_LINES, 0, platformRasterVerticesCount);
                }
                
                glTranslatef(0.f, 0.f, _zShift);
                if(_parsedGCode) {
                    GLint vboVerticesCount = _parsedGCode.vertexCount;
                    if(vboVerticesCount>0) {
                        const GLsizei stride = _parsedGCode.vertexStride;
                        glBindBuffer(GL_ARRAY_BUFFER, _vbo[kCurrentLayerVBO]);
                        glColorPointer(4, GL_FLOAT, stride, (const GLvoid*)0);
                        glVertexPointer(3, GL_FLOAT, stride, (const GLvoid*)(4*sizeof(GLfloat)));
                        glLineWidth(2.f);
                        glDrawArrays(GL_LINES, 0, (GLsizei)vboVerticesCount);
                        
                    }
                }
                glBindBuffer(GL_ARRAY_BUFFER, 0);
               
                glFlush();
                glDeleteBuffers(kVBOCount, _vbo);

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
                PSErrorLog(@"FBO not complete: %d", status);
            
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


- (void)setupObjectVBOWithBufferName:(GLuint)bufferName
{
    glBindBuffer(GL_ARRAY_BUFFER, bufferName);
    glBufferData(GL_ARRAY_BUFFER, _parsedGCode.vertexCount*_parsedGCode.vertexStride, _parsedGCode.vertexArray, GL_STATIC_DRAW);
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

@end
