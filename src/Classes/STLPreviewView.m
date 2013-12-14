//
//  OpenGLPreviewView.m
//  MacSkeinforge
//
//  Created by Eberhard Rensch on 30.07.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
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

#import "STLPreviewView.h"
#import <P3DCore/P3DCore.h>
#import <OpenGL/glu.h>

enum {
    kPlatformVBO,
    kPlatformRasterVBO,
    kObjectVBO,
    kVBOCount
};

@implementation STLPreviewView
{
    BOOL _platformVBONeedsRefresh;
    BOOL _objectVBONeedsRefresh;
    BOOL _lightNeedsRefresh;
    
    GLuint _vbo[kVBOCount];
    GLsizei _platformRasterVerticesCount;
    GLsizei _objectVerticesCount;
}

@synthesize stlModel, wireframe;

+ (void)initialize
{
	NSMutableDictionary *ddef = [NSMutableDictionary dictionary];
	[ddef setObject:[NSNumber numberWithBool:NO] forKey:@"wireframeSTLPreview"];	
	[[NSUserDefaults standardUserDefaults] registerDefaults:ddef];
}

- (void)awakeFromNib
{
	[super awakeFromNib];
    _lightNeedsRefresh = YES;
    _platformVBONeedsRefresh=YES;
   
	self.wireframe=[[NSUserDefaults standardUserDefaults] boolForKey:@"wireframeSTLPreview"];
	self.threeD = YES; // This view is always in 3D
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(currentMachineSettingsChanged:) name:P3DCurrentMachineSettingsChangedNotifiaction object:nil];
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glDeleteBuffers(kVBOCount, _vbo);
}

+ (NSSet *)keyPathsForValuesAffectingDimensionsString {
    return [NSSet setWithObjects:@"stlModel", nil];
}

- (Vector3*)objectDimensions
{
    return [stlModel.cornerMaximum sub:stlModel.cornerMinimum];
}

- (NSString*)dimensionsString
{
	Vector3* dimension = [stlModel.cornerMaximum sub:stlModel.cornerMinimum];
	
	NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
	[numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
	[numberFormatter setFormat:@"0.0mm;0.0mm;-0.0mm"];
	
	NSString* dimString = [NSString stringWithFormat:@"%@ (X) x %@ (Y) x %@ (Z)", [numberFormatter stringFromNumber:[NSNumber numberWithFloat:dimension.x]], [numberFormatter stringFromNumber:[NSNumber numberWithFloat:dimension.y]], [numberFormatter stringFromNumber:[NSNumber numberWithFloat:dimension.z]]];
	return dimString;
}

- (void)setWireframe:(BOOL)value
{
	if(wireframe!=value)
	{
		wireframe = value;
		[[NSUserDefaults standardUserDefaults] setBool:value forKey:@"wireframeSTLPreview"];
        _lightNeedsRefresh = YES;
		[self setNeedsDisplay:YES];
	}
}

- (void)setStlModel:(STLModel*)value
{
	if(stlModel!=value)
	{
		stlModel = value;
		if(stlModel && !stlModel.hasNormals)
			self.wireframe=YES;
        
        _objectVBONeedsRefresh=YES;
	}
	[self setNeedsDisplay:YES];
}

- (void)currentMachineSettingsChanged:(NSNotification*)notification
{
    _platformVBONeedsRefresh=YES;
}

- (void)renderContent
{
	if(stlModel)
	{
        if(_vbo[0]==0) {
            glGenBuffers(kVBOCount, _vbo);
            glEnableClientState(GL_VERTEX_ARRAY);
        }
        
        if(_platformVBONeedsRefresh) {
            [self setupPlatformVBOWithBufferName:_vbo[kPlatformVBO]];
            _platformRasterVerticesCount = [self setupPlatformRasterVBOWithBufferName:_vbo[kPlatformRasterVBO]];
            _platformVBONeedsRefresh=NO;
        }
        
        if(_objectVBONeedsRefresh) {
            _objectVerticesCount = [self setupObjectVBOWithBufferName:_vbo[kObjectVBO]];
            _objectVBONeedsRefresh=NO;
        }
        
        if(_lightNeedsRefresh) {
            if(!wireframe) {
                glPolygonMode( GL_FRONT_AND_BACK, GL_FILL );
                GLfloat mat_specular[] = { .8, .8, .8, 1.0 };
                GLfloat mat_shininess[] = { 15.0 };
                GLfloat mat_ambient[] = { 0.2, 0.2, 0.2, 1.0 };
                GLfloat mat_diffuse[] = { 0.3, 0.3, 0.3, 1.0 };
                
                GLfloat light_ambient[] = { 0.5, 0.5, 0.5, 0.0 };
                GLfloat light_diffuse[] = { 0.2, 0.2, 0.2, 0.0 };

                GLfloat light0_position[] = { -1., 1., .5, 0. };
                GLfloat light0_specular[] = { 0.309, 0.377, 1.000, 1.000 };

                GLfloat light1_position[] = { 1., .75, .75, 0. };
                GLfloat light1_specular[] = { 1.000, 0.638, 0.438, 1.000 };
                
                GLfloat light2_position[] = { 0., -1, -.75, 0. };
                GLfloat light2_specular[] = { 0.574, 1.000, 0.434, 1.000 };

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
            }
            _lightNeedsRefresh = NO;
        }

        glBindBuffer(GL_ARRAY_BUFFER, 0);
        
        if(wireframe) {
            glPolygonMode( GL_FRONT_AND_BACK, GL_LINE );
        } else {
            glEnable(GL_COLOR_MATERIAL);
            glEnable(GL_LIGHTING);
        }
        

        glDisableClientState(GL_COLOR_ARRAY);
        glEnableClientState(GL_NORMAL_ARRAY);
        const GLsizei objectStride = sizeof(GLfloat)*6; // UVW + XYZ

        // Draw Object
		glColor3f(1.f, 1.f, 1.f);
        glBindBuffer(GL_ARRAY_BUFFER, _vbo[kObjectVBO]);
        glNormalPointer(GL_FLOAT, objectStride, 0);
        glVertexPointer(/*xyz*/3, GL_FLOAT, objectStride, 3*sizeof(GLfloat));
        glDrawArrays(GL_TRIANGLES, /*firstIndex*/0, /*indexCount*/_objectVerticesCount);

        
		if(wireframe) {
            glPolygonMode( GL_FRONT_AND_BACK, GL_FILL );
        } else {
			glDisable(GL_COLOR_MATERIAL);
			glDisable(GL_LIGHTING);
		}
 
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

        glBindBuffer(GL_ARRAY_BUFFER, 0);
	}
}

- (void)setupPlatformVBOWithBufferName:(GLuint)bufferName
{
    const GLsizei stride = sizeof(GLfloat)*3;
    const GLint numVertices = 4;
    const GLsizeiptr bufferSize = stride * numVertices;
    
    Vector3* zeroBuildPlattform = self.currentMachine.zeroBuildPlattform;
    Vector3* dimBuildPlattform = self.currentMachine.dimBuildPlattform;
    
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

- (GLsizei)setupPlatformRasterVBOWithBufferName:(GLuint)bufferName
{
    Vector3* zeroBuildPlattform = self.currentMachine.zeroBuildPlattform;
    Vector3* dimBuildPlattform = self.currentMachine.dimBuildPlattform;

    const GLsizei stride = sizeof(GLfloat)*8;
    const GLint numVertices = ((GLint)(dimBuildPlattform.x/10.f)+1+(GLint)(dimBuildPlattform.y/10.f)+1)*2+(dimBuildPlattform.z>0.f?(GLint)16:0);
    const GLsizeiptr bufferSize = stride * numVertices;
    
    GLfloat * varray = (GLfloat*)malloc(bufferSize);
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
    
    if(dimBuildPlattform.z>0.f) {
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
