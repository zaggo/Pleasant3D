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

@implementation STLPreviewView
{
    BOOL _objectVBONeedsRefresh;
    BOOL _lightNeedsRefresh;
    
    GLuint _vbo;
    GLsizei _objectVerticesCount;
}

@synthesize stlModel, wireframe;

#pragma mark - View Life Cycle
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
   
	self.wireframe=[[NSUserDefaults standardUserDefaults] boolForKey:@"wireframeSTLPreview"];
	self.threeD = YES; // This view is always in 3D
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
    [super viewWillMoveToWindow:newWindow];
    if(newWindow==nil) {
        PSLog(@"OpenGL", PSPrioNormal, @"VBOs deleted");
        [self.openGLContext makeCurrentContext]; // Ensure we're in the right OpenGL context
        glDeleteBuffers(1, &_vbo);
        _vbo=0;
    }
}

#pragma mark - Service

- (Vector3*)objectDimensions
{
    return [stlModel.cornerMaximum sub:stlModel.cornerMinimum];
}

- (void)setStlModel:(STLModel*)value
{
	if(stlModel!=value) {
		stlModel = value;
		if(stlModel && !stlModel.hasNormals)
			self.wireframe=YES;
        
        _objectVBONeedsRefresh=YES;
	}
	[self setNeedsDisplay:YES];
}

- (void)setWireframe:(BOOL)value
{
	if(wireframe!=value) {
		wireframe = value;
		[[NSUserDefaults standardUserDefaults] setBool:value forKey:@"wireframeSTLPreview"];
        _lightNeedsRefresh = YES;
		[self setNeedsDisplay:YES];
	}
}


#pragma mark - GUI Binding

+ (NSSet *)keyPathsForValuesAffectingDimensionsString {
    return [NSSet setWithObjects:@"stlModel", nil];
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

#pragma mark - Render OpenGL

- (void)prepareOpenGL
{
    [super prepareOpenGL];
    glGenBuffers(1, &_vbo);
    PSLog(@"OpenGL", PSPrioNormal, @"1 VBOs generated");
}

- (void)renderContent
{
	if(stlModel)
	{
        if(_objectVBONeedsRefresh) {
            PSLog(@"OpenGL", PSPrioNormal, @"objectVBONeedsRefresh");
            _objectVerticesCount = [self setupObjectVBOWithBufferName:_vbo];
            _objectVBONeedsRefresh=NO;
        }
        
        if(_lightNeedsRefresh) {
            if(!wireframe) {
                glPolygonMode( GL_FRONT_AND_BACK, GL_FILL );
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
            }
            _lightNeedsRefresh = NO;
        }

        if(wireframe) {
            glPolygonMode( GL_FRONT_AND_BACK, GL_LINE );
            glDisable(GL_COLOR_MATERIAL);
            glDisable(GL_LIGHTING);
        } else {
            glPolygonMode( GL_FRONT_AND_BACK, GL_FILL );
            glEnable(GL_COLOR_MATERIAL);
            glEnable(GL_LIGHTING);
        }
        
        glDisableClientState(GL_COLOR_ARRAY);
        glEnableClientState(GL_NORMAL_ARRAY);
        const GLsizei objectStride = sizeof(GLfloat)*6; // UVW + XYZ

        // Draw Object
		glColor3f(1.f, 1.f, 1.f);
        glBindBuffer(GL_ARRAY_BUFFER, _vbo);
        glNormalPointer(GL_FLOAT, objectStride, 0);
        glVertexPointer(3, GL_FLOAT, objectStride, 3*sizeof(GLfloat));
        glDrawArrays(GL_TRIANGLES, 0, _objectVerticesCount);

        glBindBuffer(GL_ARRAY_BUFFER, 0);
	}
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
    PSLog(@"OpenGL", PSPrioNormal, @"setupObjectVBOWithBufferName created buffer for %d with %d vertices", bufferName, i/3);
    
    return numVertices;
}

@end
