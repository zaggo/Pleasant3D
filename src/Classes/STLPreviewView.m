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
	self.wireframe=[[NSUserDefaults standardUserDefaults] boolForKey:@"wireframeSTLPreview"];
	self.threeD = YES; // This view is always in 3D
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
	}
	[self setNeedsDisplay:YES];
}

- (void)renderContent 
{
	if(stlModel)
	{	
		if(wireframe)
		{
			glColor3f(1., 1., 1.);
			glPolygonMode( GL_FRONT_AND_BACK, GL_LINE );
		}
		else
		{
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
            
			glEnable(GL_COLOR_MATERIAL);
			glEnable(GL_LIGHTING);
			glEnable(GL_LIGHT0);
			glEnable(GL_LIGHT1);
			glEnable(GL_LIGHT2);
		}

		glColor3f(1., 1., 1.);
		glBegin(GL_TRIANGLES);
		STLBinaryHead* stl = [stlModel stlHead];
		STLFacet* facet = firstFacet(stl);
		for(UInt32 i = 0; i<stl->numberOfFacets; i++)
		{
			glNormal3fv((GLfloat const *)&(facet->normal));
			for(NSInteger pIndex = 0; pIndex<3; pIndex++)
				glVertex3fv((GLfloat const *)&(facet->p[pIndex]));
			
			facet = nextFacet(facet);
		}
		glEnd();
		
		if(!wireframe)
		{
			glDisable(GL_COLOR_MATERIAL);
			glDisable(GL_LIGHTING);
			glDisable(GL_LIGHT0);
			glDisable(GL_LIGHT1);
			glDisable(GL_LIGHT2);
		}

        if(self.currentMachine.dimBuildPlattform)
        {
            glLineWidth(1.f);	
            glColor4f(1.f, .749f, 0.f, .1f);
            glBegin(GL_QUADS);
            glVertex3f(-self.currentMachine.zeroBuildPlattform.x, -self.currentMachine.zeroBuildPlattform.y, 0.);
            glVertex3f(-self.currentMachine.zeroBuildPlattform.x, self.currentMachine.dimBuildPlattform.y-self.currentMachine.zeroBuildPlattform.y, 0.);
            glVertex3f(self.currentMachine.dimBuildPlattform.x-self.currentMachine.zeroBuildPlattform.x, self.currentMachine.dimBuildPlattform.y-self.currentMachine.zeroBuildPlattform.y, 0.);
            glVertex3f(self.currentMachine.dimBuildPlattform.x-self.currentMachine.zeroBuildPlattform.x, -self.currentMachine.zeroBuildPlattform.y, 0.);
            glEnd();

            glColor4f(1., 0., 0., .4);
            glBegin(GL_LINES);
            for(CGFloat x = -self.currentMachine.zeroBuildPlattform.x; x<self.currentMachine.dimBuildPlattform.x-self.currentMachine.zeroBuildPlattform.x; x+=10.)
            {
                glVertex3f(x, -self.currentMachine.zeroBuildPlattform.y, 0.);
                glVertex3f(x, self.currentMachine.dimBuildPlattform.y-self.currentMachine.zeroBuildPlattform.y, 0.);
            }
            glVertex3f(self.currentMachine.dimBuildPlattform.x-self.currentMachine.zeroBuildPlattform.x, -self.currentMachine.zeroBuildPlattform.y, 0.);
            glVertex3f(self.currentMachine.dimBuildPlattform.x-self.currentMachine.zeroBuildPlattform.x, self.currentMachine.dimBuildPlattform.y-self.currentMachine.zeroBuildPlattform.y, 0.);
            
            for(CGFloat y =  -self.currentMachine.zeroBuildPlattform.y; y<self.currentMachine.dimBuildPlattform.y-self.currentMachine.zeroBuildPlattform.y; y+=10.)
            {
                glVertex3f(-self.currentMachine.zeroBuildPlattform.x, y, 0.);
                glVertex3f(self.currentMachine.dimBuildPlattform.x-self.currentMachine.zeroBuildPlattform.x, y, 0.);
            }
            glVertex3f(-self.currentMachine.zeroBuildPlattform.x, self.currentMachine.dimBuildPlattform.y-self.currentMachine.zeroBuildPlattform.y, 0.);
            glVertex3f(self.currentMachine.dimBuildPlattform.x-self.currentMachine.zeroBuildPlattform.x, self.currentMachine.dimBuildPlattform.y-self.currentMachine.zeroBuildPlattform.y, 0.);
            glEnd();
        }
	}
}
@end
