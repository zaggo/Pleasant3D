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
		
		dimBuildPlattform = [[Vector3 alloc] initVectorWithX:100. Y:100. Z:0.];
		zeroBuildPlattform = [[Vector3 alloc] initVectorWithX:50. Y:50. Z:0.];

		stlModel = [model retain];
		
		cameraOffset = - 2.*MAX( dimBuildPlattform.x, dimBuildPlattform.y);
		
		CGFloat objectMaxXDim = MAX(fabsf(stlModel.cornerMaximum.x), fabsf(stlModel.cornerMinimum.x));
		CGFloat objectMaxYDim = MAX(fabsf(stlModel.cornerMaximum.y), fabsf(stlModel.cornerMinimum.y));
		CGFloat objectOffset = - 2.5*MAX( objectMaxXDim, objectMaxYDim);
		cameraOffset = MIN(objectOffset, cameraOffset);
		
		rotateX = 0.;
		rotateY = -45.;
		
		self.wireframe=!stlModel.hasNormals;
	}
	return self;
}

- (void) dealloc
{
	[stlModel release];
	[dimBuildPlattform release];
	[zeroBuildPlattform release];
	[super dealloc];
}

- (CGImageRef)newPreviewImage
{	
	CGImageRef cgImage=nil;
    
	CGLPixelFormatAttribute attribs[] = // 1
	{
//		kCGLPFAOffScreen,
		kCGLPFAColorSize, (CGLPixelFormatAttribute)32,
		kCGLPFADepthSize, (CGLPixelFormatAttribute)32,
		kCGLPFASupersample,
		kCGLPFASampleAlpha,
        kCGLPFARemotePBuffer,
		(CGLPixelFormatAttribute)0
	} ;
	CGLPixelFormatObj pixelFormatObj;
	GLint numPixelFormats;
	CGLChoosePixelFormat (attribs, &pixelFormatObj, &numPixelFormats);
	
	long bytewidth = (GLsizei)renderSize.width * 4; // Assume 4 bytes/pixel for now
	bytewidth = (bytewidth + 3) & ~3; // Align to 4 bytes
	
	/* Build bitmap context */
	void *data;
	data = malloc((GLsizei)renderSize.height * bytewidth);
	if (data == NULL) {
		return nil;
	}
	
	CGColorSpaceRef cSpace = CGColorSpaceCreateWithName (kCGColorSpaceGenericRGB);
	CGContextRef bitmap;
	bitmap = CGBitmapContextCreate(data, (GLsizei)renderSize.width, (GLsizei)renderSize.height, 8, bytewidth, cSpace, kCGImageAlphaPremultipliedFirst /* RGBA */);
	CFRelease(cSpace);

	CGLContextObj contextObj;
	CGLCreateContext (pixelFormatObj, NULL, &contextObj);
	CGLDestroyPixelFormat (pixelFormatObj);
	CGLSetCurrentContext (contextObj);
	    
    // FBO
    GLuint fb;
    GLuint fboRenderBuffers[2];
    glGenFramebuffers/*EXT*/(1, &fb);
    glBindFramebuffer/*EXT*/(GL_FRAMEBUFFER/*_EXT*/, fb);
    glGenRenderbuffers(2, fboRenderBuffers);
    glBindRenderbuffer(GL_RENDERBUFFER/*_EXT*/, fboRenderBuffers[0]);
    glRenderbufferStorage(GL_RENDERBUFFER/*_EXT*/, GL_DEPTH_COMPONENT, renderSize.width, renderSize.height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER/*_EXT*/, GL_DEPTH_ATTACHMENT/*_EXT*/, GL_RENDERBUFFER/*_EXT*/, fboRenderBuffers[0]);
    glBindRenderbuffer(GL_RENDERBUFFER/*_EXT*/, fboRenderBuffers[1]);
    glRenderbufferStorage(GL_RENDERBUFFER/*_EXT*/, GL_RGBA, renderSize.width, renderSize.height);
    glFramebufferRenderbuffer/*EXT*/(GL_FRAMEBUFFER/*_EXT*/, GL_COLOR_ATTACHMENT0/*_EXT*/, GL_RENDERBUFFER/*_EXT*/, fboRenderBuffers[1]);

    GLenum status = glCheckFramebufferStatus/*EXT*/(GL_FRAMEBUFFER/*_EXT*/);
    if(GL_FRAMEBUFFER_COMPLETE/*_EXT*/ == status)
    {
        glViewport(0, 0, renderSize.width, renderSize.height);
        
        glMatrixMode( GL_PROJECTION );
        glLoadIdentity();
        gluPerspective( 32., renderSize.width / renderSize.height, 10., MAX(1000.,- 2. *cameraOffset) );
            
        // Clear the framebuffer.
        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();						// Reset The View
        
        glClearColor( 0., 0., 0., 0. );
        glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
        
        if(stlModel)
        {	
            glEnable (GL_LINE_SMOOTH); 
            glEnable (GL_BLEND); 
            glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

            if(wireframe)
            {
                glColor3f(1., 1., 1.);
                glPolygonMode( GL_FRONT_AND_BACK, GL_LINE );
            }
            else
            {
                glPolygonMode( GL_FRONT_AND_BACK, GL_FILL );
                GLfloat mat_specular[] = { .8, .8, .8, 1.0 };
                GLfloat mat_shininess[] = { 60.0 };
                GLfloat mat_ambient[] = { 0.2, 0.2, 0.2, 1.0 };
                GLfloat mat_diffuse[] = { 0.2, 0.8, 0.2, 1.0 };
                
                GLfloat light_position[] = { 1., -1., 1., 0. };
                GLfloat light_ambient[] = { 0.5, 0.5, 0.5, 1.0 };
                GLfloat light_diffuse[] = { 0.2, 0.2, 0.2, 1.0 };
                
                glMaterialfv(GL_FRONT, GL_SPECULAR,  mat_specular);
                glMaterialfv(GL_FRONT, GL_SHININESS, mat_shininess);
                glMaterialfv(GL_FRONT, GL_AMBIENT,   mat_ambient);
                glMaterialfv(GL_FRONT, GL_DIFFUSE,   mat_diffuse);
                
                glLightfv(GL_LIGHT0, GL_AMBIENT,  light_ambient);
                glLightfv(GL_LIGHT0, GL_DIFFUSE,  light_diffuse);
                glLightfv(GL_LIGHT0, GL_POSITION, light_position);
                
                glEnable(GL_DEPTH_TEST);
                glEnable(GL_COLOR_MATERIAL);
                glEnable(GL_LIGHTING);
                glEnable(GL_LIGHT0);
            }

            glTranslatef(0.f,0.f,cameraOffset);
            glRotatef(rotateX, 0.f, 1.f, 0.f);
            glRotatef(rotateY, 1.f, 0.f, 0.f);
            
            if(thumbnail)
                glColor4f(.252f, .212f, .122f, 1.f);
            else
                glColor4f(1.f, .749f, 0.f, .1f);
            
            GLfloat platformZ = 0.;
            GLfloat platformCoords[] = {
                -zeroBuildPlattform.x, -zeroBuildPlattform.y, platformZ,
                -zeroBuildPlattform.x, dimBuildPlattform.y-zeroBuildPlattform.y, platformZ,
                dimBuildPlattform.x-zeroBuildPlattform.x, dimBuildPlattform.y-zeroBuildPlattform.y, platformZ,
                dimBuildPlattform.x-zeroBuildPlattform.x, -zeroBuildPlattform.y, platformZ
            };
            glVertexPointer(3, GL_FLOAT, 0, platformCoords);
            glDrawArrays(GL_QUADS, 0, 12);

//            glBegin(GL_QUADS);
//            glVertex3f(-zeroBuildPlattform.x, -zeroBuildPlattform.y, platformZ);
//            glVertex3f(-zeroBuildPlattform.x, dimBuildPlattform.y-zeroBuildPlattform.y, platformZ);
//            glVertex3f(dimBuildPlattform.x-zeroBuildPlattform.x, dimBuildPlattform.y-zeroBuildPlattform.y, platformZ);
//            glVertex3f(dimBuildPlattform.x-zeroBuildPlattform.x, -zeroBuildPlattform.y, platformZ);
//            glEnd();
            
            //glDepthFunc(GL_LEQUAL);
            platformZ += 0.1;
            
            
            glColor4f(1., 0., 0., .5);
            size_t rasterLinesSize = ceil(dimBuildPlattform.x/ 10.0) * 6;
            GLfloat* rasterLines = calloc(rasterLinesSize, sizeof(GLfloat));
            NSInteger i=0;
            for(CGFloat x = -zeroBuildPlattform.x; x<dimBuildPlattform.x-zeroBuildPlattform.x; x+=10.)
            {
                rasterLines[i++]=x;
                rasterLines[i++]=-zeroBuildPlattform.y;
                rasterLines[i++]=platformZ;
                rasterLines[i++]=x;
                rasterLines[i++]=dimBuildPlattform.y-zeroBuildPlattform.y;
                rasterLines[i++]=platformZ;
            }
            glVertexPointer(3, GL_FLOAT, 0, rasterLines);
            glDrawArrays(GL_LINES, 0, i);
            free(rasterLines);
            
            glBegin(GL_LINES);
//            for(CGFloat x = -zeroBuildPlattform.x; x<dimBuildPlattform.x-zeroBuildPlattform.x; x+=10.)
//            {
//                glVertex3f(x, -zeroBuildPlattform.y, platformZ);
//                glVertex3f(x, dimBuildPlattform.y-zeroBuildPlattform.y, platformZ);
//            }
            glVertex3f(dimBuildPlattform.x-zeroBuildPlattform.x, -zeroBuildPlattform.y, platformZ);
            glVertex3f(dimBuildPlattform.x-zeroBuildPlattform.x, dimBuildPlattform.y-zeroBuildPlattform.y, platformZ);
            
            for(CGFloat y =  -zeroBuildPlattform.y; y<dimBuildPlattform.y-zeroBuildPlattform.y; y+=10.)
            {
                glVertex3f(-zeroBuildPlattform.x, y, platformZ);
                glVertex3f(dimBuildPlattform.x-zeroBuildPlattform.x, y, platformZ);
            }
            glVertex3f(-zeroBuildPlattform.x, dimBuildPlattform.y-zeroBuildPlattform.y, platformZ);
            glVertex3f(dimBuildPlattform.x-zeroBuildPlattform.x, dimBuildPlattform.y-zeroBuildPlattform.y, platformZ);
            glEnd();

            glColor3f(1., 1., 1.);
            glBegin(GL_TRIANGLES);
            STLBinaryHead* stl = [stlModel stlHead];
            STLFacet* facet = firstFacet(stl);
            for(NSUInteger i = 0; i<stl->numberOfFacets; i++)
            {
                glNormal3fv((GLfloat const *)&(facet->normal));
                for(NSInteger pIndex = 0; pIndex<3; pIndex++)
                {
                    //glVertex3f((GLfloat)facet->p[pIndex].x, (GLfloat)facet->p[pIndex].y, (GLfloat)facet->p[pIndex].z);
                    glVertex3fv((GLfloat const *)&(facet->p[pIndex]));
                }
                facet = nextFacet(facet);
            }
            glEnd();
            
            if(!wireframe)
            {
                glDisable(GL_COLOR_MATERIAL);
                glDisable(GL_LIGHTING);
                glDisable(GL_LIGHT0);
            }            

            if(!wireframe)
            {
                glDisable(GL_DEPTH_TEST);
            }
            
            glDisable (GL_LINE_SMOOTH); 
            glDisable (GL_BLEND); 
        }
                
        /* Read framebuffer into our bitmap */
        glPixelStorei(GL_PACK_ALIGNMENT, (GLint)4); /* Force 4-byte alignment */
        glPixelStorei(GL_PACK_ROW_LENGTH, (GLint)0);
        glPixelStorei(GL_PACK_SKIP_ROWS, (GLint)0);
        glPixelStorei(GL_PACK_SKIP_PIXELS, (GLint)0);
        
        /* Fetch the data in XRGB format, matching the bitmap context. */
        glReadPixels((GLint)0, (GLint)0, (GLsizei)renderSize.width, (GLsizei)renderSize.width, GL_BGRA,
                     GL_UNSIGNED_INT_8_8_8_8, // for Intel! http://lists.apple.com/archives/quartz-dev/2006/May/msg00100.html
                     data);
        
        swizzleBitmap(data, bytewidth, (GLsizei)renderSize.height);
        
        /* Make an image out of our bitmap; does a cheap vm_copy of the bitmap */
        cgImage = CGBitmapContextCreateImage(bitmap);
    }
    else
        NSLog(@"FBO not complete: %d", status);
    
    glBindFramebuffer/*EXT*/(GL_FRAMEBUFFER/*_EXT*/, 0);
    glDeleteRenderbuffers/*EXT*/(2, fboRenderBuffers);
    glDeleteFramebuffers/*EXT*/(1, &fb);
   
    /* Get rid of bitmap */
    CFRelease(bitmap);
    free(data);
    
    
    CGLSetCurrentContext (NULL);
    CGLClearDrawable (contextObj);
    CGLDestroyContext (contextObj);
    
	return cgImage;
}

@end
