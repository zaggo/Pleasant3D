//
//  STLPreviewGenerator.m
//  STLQuickLook
//
//  Created by Eberhard Rensch on 07.01.10.
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
#import "STLPreviewGenerator.h"
#import <OpenGL/glu.h>

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

@implementation STLPreviewGenerator
{
    float _zShift;
}
@synthesize stlModel, renderSize, wireframe;

- (id)initWithSTLModel:(STLModel*)model size:(CGSize)size forThumbnail:(BOOL)forThumbnail
{
	self = [super init];
	if(self)
	{
		thumbnail = forThumbnail;
		
		if(thumbnail)
			renderSize = CGSizeMake(512.,512.);
		else
			renderSize = CGSizeMake(size.width*kRenderUpsizeFaktor,size.height*kRenderUpsizeFaktor);
		
		stlModel = model;
		
        Vector3* cMax = stlModel.cornerMaximum;
        Vector3* cMin = stlModel.cornerMinimum;
        
        dimBuildPlattform = [cMax sub:cMin];
        
        _zShift = -(cMax.z-dimBuildPlattform.z/2.f);
        
        zeroBuildPlattform = [[Vector3 alloc] initVectorWithX:cMin.x+dimBuildPlattform.x/2.f Y:cMin.y+dimBuildPlattform.y/2.f Z:cMin.z+_zShift];
        [dimBuildPlattform imul:1.2f];
        
        float maxDist = 2.f*MAX(dimBuildPlattform.x, dimBuildPlattform.y);
        maxDist = MAX(maxDist, 2.25f*dimBuildPlattform.z);
		cameraOffset = -maxDist;
		
		rotateX = 0.;
		rotateY = -45.;
		
		self.wireframe=!stlModel.hasNormals;
	}
	return self;
}


- (CGImageRef)newPreviewImage
{	
	CGImageRef cgImage=NULL;
    CGLError glError = kCGLNoError;

    CGLContextObj contextObj=NULL;
	CGLPixelFormatObj pixelFormatObj=NULL;
	GLint numPixelFormats=0;

    GLuint vbo[3];

	CGLPixelFormatAttribute attribs[] =
	{
		kCGLPFAColorSize, (CGLPixelFormatAttribute)32,
		kCGLPFADepthSize, (CGLPixelFormatAttribute)32,
        kCGLPFANoRecovery,
		kCGLPFASupersample,
		kCGLPFASampleAlpha,
        kCGLPFARemotePBuffer,
		(CGLPixelFormatAttribute)0
	};
    
	glError = CGLChoosePixelFormat (attribs, &pixelFormatObj, &numPixelFormats);
    
    if (pixelFormatObj && glError == kCGLNoError)
    {
        glError = CGLCreateContext (pixelFormatObj, NULL, &contextObj);
        CGLDestroyPixelFormat (pixelFormatObj);
        
        if (contextObj && glError == kCGLNoError)
        {
            glError = CGLSetCurrentContext (contextObj);
            
            if (glError == kCGLNoError)
            {
                glGenBuffers(3, vbo);
                
                long bytewidth = (GLsizei)renderSize.width * 4; // Assume 4 bytes/pixel for now
                bytewidth = (bytewidth + 3) & ~3; // Align to 4 bytes
                
                /* Build bitmap context */
                void *bitmapContextData = NULL;
                bitmapContextData = malloc((GLsizei)renderSize.height * bytewidth);
                if (bitmapContextData) {
                    
                    CGColorSpaceRef cSpace = CGColorSpaceCreateWithName (kCGColorSpaceGenericRGB);
                    CGContextRef bitmap;
                    bitmap = CGBitmapContextCreate(bitmapContextData, (GLsizei)renderSize.width, (GLsizei)renderSize.height, 8, bytewidth, cSpace, kCGImageAlphaPremultipliedFirst /* RGBA */);
                    CFRelease(cSpace);
                    
                    
                    // FBO
                    GLuint fb;
                    GLuint fboRenderBuffers[2];
                    glGenFramebuffers(1, &fb);
                    glBindFramebuffer(GL_FRAMEBUFFER, fb);
                    glGenRenderbuffers(2, fboRenderBuffers);
                    glBindRenderbuffer(GL_RENDERBUFFER, fboRenderBuffers[0]);
                    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT, renderSize.width, renderSize.height);
                    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, fboRenderBuffers[0]);
                    glBindRenderbuffer(GL_RENDERBUFFER, fboRenderBuffers[1]);
                    glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA, renderSize.width, renderSize.height);
                    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, fboRenderBuffers[1]);
                    
                    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
                    if(GL_FRAMEBUFFER_COMPLETE == status)
                    {
                        glViewport(0, 0, renderSize.width, renderSize.height);
                        
                        glMatrixMode( GL_PROJECTION );
                        glLoadIdentity();
                        gluPerspective( 32., renderSize.width / renderSize.height, 1., MAX(1000., - 2.* cameraOffset) );
                        
                        // Clear the framebuffer.
                        glMatrixMode(GL_MODELVIEW);
                        glLoadIdentity();						// Reset The View
                        
                        glClearColor( 0., 0., 0., 1. );
                        glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
                        
                        if(stlModel)
                        {
                            glEnable (GL_LINE_SMOOTH);
                            glEnable (GL_BLEND);
                            glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
                            
                            glPolygonMode( GL_FRONT_AND_BACK, GL_FILL );
                            
                            glTranslatef(-zeroBuildPlattform.x, -zeroBuildPlattform.y, cameraOffset);
                            glRotatef(rotateX, 0.f, 1.f, 0.f);
                            glRotatef(rotateY, 1.f, 0.f, 0.f);
                            
                            glEnableClientState(GL_COLOR_ARRAY);
                            glEnableClientState(GL_VERTEX_ARRAY);
                            
                            //                    if(thumbnail)
                            //                        [self setupPlatformVBOWithBufferName:vbo[0] colorR:.252f G:.212f B:.122f A:1.f];
                            //                    else
                            [self setupPlatformVBOWithBufferName:vbo[0] colorR:1.f G:.749f B:0.f A:.1f];
                            
                            GLsizei platformRasterVerticesCount = [self setupPlatformRasterVBOWithBufferName:vbo[1]];
                            GLsizei objectVerticesCount = [self setupObjectVBOWithBufferName:vbo[2]];
                            
                            const GLsizei stride = sizeof(GLfloat)*8; // RGBA + XYZW
                            
                            // Draw Platform
                            glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
                            glColorPointer(/*rgba*/4, GL_FLOAT, stride, 0);
                            glVertexPointer(/*xyz*/3, GL_FLOAT, stride, 4*sizeof(GLfloat));
                            glDrawArrays(GL_QUADS, 0, 4);
                            
                            glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
                            glColorPointer(/*rgba*/4, GL_FLOAT, stride, 0);
                            glVertexPointer(/*xyz*/3, GL_FLOAT, stride, 4*sizeof(GLfloat));
                            glDrawArrays(GL_LINES, 0, platformRasterVerticesCount);
                            
                            
                            if(wireframe) {
                                glPolygonMode( GL_FRONT_AND_BACK, GL_LINE );
                                glDisable(GL_COLOR_MATERIAL);
                                glDisable(GL_LIGHTING);
                            } else {
                                const GLfloat mat_specular[] = { .8, .8, .8, 1.0 };
                                const GLfloat mat_shininess[] = { 15.0 };
                                const GLfloat mat_ambient[] = { 0.2, 0.2, 0.2, 1.0 };
                                const GLfloat mat_diffuse[] = { 0.3, 0.3, 0.3, 1.0 };
                                
                                const GLfloat light_ambient[] = { 0.5, 0.5, 0.5, 0.0 };
                                const GLfloat light_diffuse[] = { 0.2, 0.2, 0.2, 0.0 };
                                
                                const GLfloat light0_position[] = { -1., 1., .5, 0. };
                                const GLfloat light0_specular[] = { 0.309, 0.377, 1.000, 1.000 };
                                
                                const GLfloat light1_position[] = { 1., .75, .75, 0. };
                                const GLfloat light1_specular[] = { 1.000, 0.638, 0.438, 1.000 };
                                
                                const  GLfloat light2_position[] = { 0., -1, -.75, 0. };
                                const GLfloat light2_specular[] = { 0.574, 1.000, 0.434, 1.000 };
                                
                                glMaterialfv(GL_FRONT, GL_SPECULAR,  mat_specular);
                                glMaterialfv(GL_FRONT, GL_SHININESS, mat_shininess);
                                glMaterialfv(GL_FRONT, GL_AMBIENT,   mat_ambient);
                                glMaterialfv(GL_FRONT, GL_DIFFUSE,   mat_diffuse);
                                
                                glLightfv(GL_LIGHT0, GL_AMBIENT,  light_ambient);
                                glLightfv(GL_LIGHT0, GL_DIFFUSE,  light_diffuse);
                                glLightfv(GL_LIGHT0, GL_POSITION, light0_position);
                                glLightfv(GL_LIGHT0, GL_SPECULAR, light0_specular);
                                
                                glLightfv(GL_LIGHT1, GL_POSITION, light1_position);
                                glLightfv(GL_LIGHT1, GL_SPECULAR, light1_specular);
                                
                                glLightfv(GL_LIGHT2, GL_POSITION, light2_position);
                                glLightfv(GL_LIGHT2, GL_SPECULAR, light2_specular);
                                
                                glEnable(GL_LIGHT0);
                                glEnable(GL_LIGHT1);
                                glEnable(GL_LIGHT2);
                                glEnable(GL_COLOR_MATERIAL);
                                glEnable(GL_LIGHTING);
                                glEnable(GL_DEPTH_TEST);
                            }
                            
                            glDisableClientState(GL_COLOR_ARRAY);
                            glEnableClientState(GL_NORMAL_ARRAY);
                            const GLsizei objectStride = sizeof(GLfloat)*6; // UVW + XYZ
                            
                            // Draw Object
                            glTranslatef(0.f, 0.f, _zShift);
                            glColor3f(1.f, 1.f, 1.f);
                            glBindBuffer(GL_ARRAY_BUFFER, vbo[2]);
                            glNormalPointer(GL_FLOAT, objectStride, 0);
                            glVertexPointer(3, GL_FLOAT, objectStride, 3*sizeof(GLfloat));
                            glDrawArrays(GL_TRIANGLES, 0, objectVerticesCount);
                            
                            glBindBuffer(GL_ARRAY_BUFFER, 0);
                            glFlush();
                        }
                        
                        
                        /* Read framebuffer into our bitmap */
                        glPixelStorei(GL_PACK_ALIGNMENT, (GLint)4); /* Force 4-byte alignment */
                        glPixelStorei(GL_PACK_ROW_LENGTH, (GLint)0);
                        glPixelStorei(GL_PACK_SKIP_ROWS, (GLint)0);
                        glPixelStorei(GL_PACK_SKIP_PIXELS, (GLint)0);
                        
                        /* Fetch the data in XRGB format, matching the bitmap context. */
                        glReadPixels((GLint)0, (GLint)0, (GLsizei)renderSize.width, (GLsizei)renderSize.width, GL_BGRA,
                                     GL_UNSIGNED_INT_8_8_8_8, // for Intel! http://lists.apple.com/archives/quartz-dev/2006/May/msg00100.html
                                     bitmapContextData);
                        
                        swizzleBitmap(bitmapContextData, bytewidth, (GLsizei)renderSize.height);
                        
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
                
                glDeleteBuffers(3, vbo);
            }
            
            CGLSetCurrentContext(NULL);
            CGLClearDrawable (contextObj);
            CGLDestroyContext (contextObj);
        }
    }
    else
    {
        NSLog(@"##### Unable to create pixel buffer");
    }

    if (cgImage == NULL)
    {
        NSLog(@"##### Unable to create preview image: %s (%d)", CGLErrorString(glError), glError);
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
    varray[i++] = (GLfloat)(zeroBuildPlattform.x-dimBuildPlattform.x/2.f);
    varray[i++] = (GLfloat)(zeroBuildPlattform.y-dimBuildPlattform.y/2.f);
    varray[i++] = (GLfloat)zeroBuildPlattform.z;
    varray[i++] = 0.f;
    varray[i++] = r;
    varray[i++] = g;
    varray[i++] = b;
    varray[i++] = a;
    varray[i++] = (GLfloat)(zeroBuildPlattform.x-dimBuildPlattform.x/2.f);
    varray[i++] = (GLfloat)(zeroBuildPlattform.y+dimBuildPlattform.y/2.f);
    varray[i++] = (GLfloat)zeroBuildPlattform.z;
    varray[i++] = 0.f;
    varray[i++] = r;
    varray[i++] = g;
    varray[i++] = b;
    varray[i++] = a;
    varray[i++] = (GLfloat)(zeroBuildPlattform.x+dimBuildPlattform.x/2.f);
    varray[i++] = (GLfloat)(zeroBuildPlattform.y+dimBuildPlattform.y/2.f);
    varray[i++] = (GLfloat)zeroBuildPlattform.z;
    varray[i++] = 0.f;
    varray[i++] = r;
    varray[i++] = g;
    varray[i++] = b;
    varray[i++] = a;
    varray[i++] = (GLfloat)(zeroBuildPlattform.x+dimBuildPlattform.x/2.f);
    varray[i++] = (GLfloat)(zeroBuildPlattform.y-dimBuildPlattform.y/2.f);
    varray[i++] = (GLfloat)zeroBuildPlattform.z;
    varray[i++] = 0.f;
    
    glBindBuffer(GL_ARRAY_BUFFER, bufferName);
    glBufferData(GL_ARRAY_BUFFER, bufferSize, varray, GL_STATIC_DRAW);
    free(varray);
}

- (GLsizei)setupPlatformRasterVBOWithBufferName:(GLuint)bufferName
{
    const GLsizei stride = sizeof(GLfloat)*8;
    const GLint numVertices = ((GLint)(dimBuildPlattform.x/10.f)+2+(GLint)(dimBuildPlattform.y/10.f)+2)*2;
    const GLsizeiptr bufferSize = stride * numVertices;
    
    GLfloat * varray = (GLfloat*)malloc(bufferSize);
    NSInteger i = 0;
    
    GLfloat r = 1.f;
    GLfloat g = 0.f;
    GLfloat b = 0.f;
    GLfloat a = .4f;
    
    for(float x=0.f; x<dimBuildPlattform.x; x+=10.f) {
        varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
        varray[i++] = (GLfloat)(zeroBuildPlattform.x-dimBuildPlattform.x/2.f+x);
        varray[i++] = (GLfloat)(zeroBuildPlattform.y-dimBuildPlattform.y/2.f);
        varray[i++] = (GLfloat)zeroBuildPlattform.z;
        varray[i++] = 0.f;
        varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
        varray[i++] = (GLfloat)(zeroBuildPlattform.x-dimBuildPlattform.x/2.f+x);
        varray[i++] = (GLfloat)(zeroBuildPlattform.y+dimBuildPlattform.y/2.f);
        varray[i++] = (GLfloat)zeroBuildPlattform.z;
        varray[i++] = 0.f;
    }
    varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
    varray[i++] = (GLfloat)(zeroBuildPlattform.x+dimBuildPlattform.x/2.f);
    varray[i++] = (GLfloat)(zeroBuildPlattform.y-dimBuildPlattform.y/2.f);
    varray[i++] = (GLfloat)zeroBuildPlattform.z;
    varray[i++] = 0.f;
    varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
    varray[i++] = (GLfloat)(zeroBuildPlattform.x+dimBuildPlattform.x/2.f);
    varray[i++] = (GLfloat)(zeroBuildPlattform.y+dimBuildPlattform.y/2.f);
    varray[i++] = (GLfloat)zeroBuildPlattform.z;
    varray[i++] = 0.f;
    
    
    for(float y=0.f; y<dimBuildPlattform.y; y+=10.f) {
        varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
        varray[i++] = (GLfloat)(zeroBuildPlattform.x-dimBuildPlattform.x/2.f);
        varray[i++] = (GLfloat)(zeroBuildPlattform.y-dimBuildPlattform.y/2.f+y);
        varray[i++] = (GLfloat)zeroBuildPlattform.z;
        varray[i++] = 0.f;
        varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
        varray[i++] = (GLfloat)(zeroBuildPlattform.x+dimBuildPlattform.x/2.f);
        varray[i++] = (GLfloat)(zeroBuildPlattform.y-dimBuildPlattform.y/2.f+y);
        varray[i++] = (GLfloat)zeroBuildPlattform.z;
        varray[i++] = 0.f;
    }
    varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
    varray[i++] = (GLfloat)(zeroBuildPlattform.x-dimBuildPlattform.x/2.f);
    varray[i++] = (GLfloat)(zeroBuildPlattform.y+dimBuildPlattform.y/2.f);
    varray[i++] = (GLfloat)zeroBuildPlattform.z;
    varray[i++] = 0.f;
    varray[i++] = r; varray[i++] = g; varray[i++] = b; varray[i++] = a;
    varray[i++] = (GLfloat)(zeroBuildPlattform.x+dimBuildPlattform.x/2.f);
    varray[i++] = (GLfloat)(zeroBuildPlattform.y+dimBuildPlattform.y/2.f);
    varray[i++] = (GLfloat)zeroBuildPlattform.z;
    varray[i++] = 0.f;
    
    glBindBuffer(GL_ARRAY_BUFFER, bufferName);
    glBufferData(GL_ARRAY_BUFFER, bufferSize, varray, GL_STATIC_DRAW);
    free(varray);
    
    return numVertices;
}

- (GLsizei)setupObjectVBOWithBufferName:(GLuint)bufferName
{
    STLBinaryHead* stl = [stlModel stlHead];
    const GLsizei stride = sizeof(GLfloat)*6;
    const GLint numVertices = stl->numberOfFacets*3;
    const GLsizeiptr bufferSize = stride * numVertices;
    
    GLfloat * varray = (GLfloat*)malloc(bufferSize);
    NSInteger i = 0;
    
    STLFacet* facet = firstFacet(stl);
    for(UInt32 fI = 0; fI<stl->numberOfFacets; fI++) {
        for(NSInteger pIndex = 0; pIndex<3; pIndex++) {
            varray[i++] = (GLfloat)facet->normal.x;
            varray[i++] = (GLfloat)facet->normal.y;
            varray[i++] = (GLfloat)facet->normal.z;
            varray[i++] = (GLfloat)facet->p[pIndex].x;
            varray[i++] = (GLfloat)facet->p[pIndex].y;
            varray[i++] = (GLfloat)facet->p[pIndex].z;
        }
        facet = nextFacet(facet);
    }
    
    glBindBuffer(GL_ARRAY_BUFFER, bufferName);
    glBufferData(GL_ARRAY_BUFFER, bufferSize, varray, GL_STATIC_DRAW);
    free(varray);
    
    return numVertices;
}

@end
