//
//  STLShapeShifter.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 14.01.10.
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

#import "STLShapeShifter.h"
#import "Vector3.h"
#import "STLModel.h"

enum { kRotateX, kRotateY, kRotateZ };

static void rotateVertex(NSInteger axis, STLVertex* p, float angle)
{
	float cos = cosf(angle);
	float sin = sinf(angle);
	
	float inP[3] = {(float)p->x, (float)p->y, (float)p->z};
	
	float eulerMatrix[3][3]={0};
	switch(axis)
	{
		case kRotateX:
			eulerMatrix[0][0] = 1.f;
			eulerMatrix[0][1] = 0.f;
			eulerMatrix[0][2] = 0.f;
			eulerMatrix[1][0] = 0.f;
			eulerMatrix[1][1] = cos;
			eulerMatrix[1][2] = -sin;
			eulerMatrix[2][0] = 0.f;
			eulerMatrix[2][1] = sin;
			eulerMatrix[2][2] = cos;
			break;
		case kRotateY:
			eulerMatrix[0][0] = cos;
			eulerMatrix[0][1] = 0.f;
			eulerMatrix[0][2] = sin;
			eulerMatrix[1][0] = 0.f;
			eulerMatrix[1][1] = 1.f;
			eulerMatrix[1][2] = 0.f;
			eulerMatrix[2][0] = -sin;
			eulerMatrix[2][1] = 0.f;
			eulerMatrix[2][2] = cos;
			break;
		case kRotateZ:
			eulerMatrix[0][0] = cos;
			eulerMatrix[0][1] = -sin;
			eulerMatrix[0][2] = 0.f;
			eulerMatrix[1][0] = sin;
			eulerMatrix[1][1] = cos;
			eulerMatrix[1][2] = 0.f;
			eulerMatrix[2][0] = 0.f;
			eulerMatrix[2][1] = 0.f;
			eulerMatrix[2][2] = 1.f;
			break;
	}
	float rotated[3];
	for(NSUInteger i=0;i<3;i++)
	{
		rotated[i]=0.f;
		for(NSUInteger j=0;j<3;j++)
		{
			rotated[i]+=inP[j]*eulerMatrix[i][j];
		}
	}
	p->x=(GLfloat)rotated[0];
	p->y=(GLfloat)rotated[1];
	p->z=(GLfloat)rotated[2];
}

@implementation STLShapeShifter
@synthesize sourceSTLModel, objectRotateX, objectRotateY, objectRotateZ, processedSTLModel, objectScale, dimX, dimY, dimZ, centerX, centerY, minZ, undoManager;

- (id)initWithCoder:(NSCoder*)decoder
{
	self = [super init];
	if(self)
	{
		objectRotateX = [decoder decodeFloatForKey:@"objectRotateX"];
		objectRotateY = [decoder decodeFloatForKey:@"objectRotateY"];
		objectRotateZ = [decoder decodeFloatForKey:@"objectRotateZ"];
		objectScale = [decoder decodeFloatForKey:@"objectScale"];
		centerX = [decoder decodeFloatForKey:@"centerX"];
		centerY = [decoder decodeFloatForKey:@"centerY"];
		minZ = [decoder decodeFloatForKey:@"minZ"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder*)encoder
{
	[encoder encodeFloat:objectRotateX forKey:@"objectRotateX"];
	[encoder encodeFloat:objectRotateY forKey:@"objectRotateY"];
	[encoder encodeFloat:objectRotateZ forKey:@"objectRotateZ"];
	[encoder encodeFloat:objectScale forKey:@"objectScale"];
	[encoder encodeFloat:centerX forKey:@"centerX"];
	[encoder encodeFloat:centerY forKey:@"centerY"];
	[encoder encodeFloat:minZ forKey:@"minZ"];
}

+ (NSSet *)keyPathsForValuesAffectingDimX {
    return [NSSet setWithObjects:@"processedSTLModel", nil];
}

+ (NSSet *)keyPathsForValuesAffectingDimY {
    return [NSSet setWithObjects:@"processedSTLModel", nil];
}

+ (NSSet *)keyPathsForValuesAffectingDimZ {
    return [NSSet setWithObjects:@"processedSTLModel", nil];
}

+ (NSSet *)keyPathsForValuesAffectingDimensionsString {
    return [NSSet setWithObjects:@"processedSTLModel", nil];
}

+ (NSSet *)keyPathsForValuesAffectingObjectScale {
    return [NSSet setWithObjects:@"processedSTLModel", nil];
}

+ (NSSet *)keyPathsForValuesAffectingObjectRotateX {
    return [NSSet setWithObjects:@"processedSTLModel", nil];
}

+ (NSSet *)keyPathsForValuesAffectingObjectRotateY {
    return [NSSet setWithObjects:@"processedSTLModel", nil];
}

+ (NSSet *)keyPathsForValuesAffectingObjectRotateZ {
    return [NSSet setWithObjects:@"processedSTLModel", nil];
}

+ (NSSet *)keyPathsForValuesAffectingCenterX {
    return [NSSet setWithObjects:@"processedSTLModel", nil];
}

+ (NSSet *)keyPathsForValuesAffectingCenterY {
    return [NSSet setWithObjects:@"processedSTLModel", nil];
}

+ (NSSet *)keyPathsForValuesAffectingMinZ {
    return [NSSet setWithObjects:@"processedSTLModel", nil];
}

- (void)processSTLModel
{
	[self willChangeValueForKey:@"processedSTLModel"];
	processedSTLModel=nil;
	
	if(sourceSTLModel)
	{
		processedSTLModel = [sourceSTLModel copy];
		
		STLBinaryHead* stl = [processedSTLModel stlHead];
		STLFacet* facet = firstFacet(stl);
		
		float angleX = (float)objectRotateX/180.f*M_PI;
		float angleY = (float)objectRotateY/180.f*M_PI;
		float angleZ = (float)objectRotateZ/180.f*M_PI;
		
		// Berechne den Mittelpunkt des ursprünglichen Objekts
		Vector3* dimension = [sourceSTLModel.cornerMaximum sub:sourceSTLModel.cornerMinimum];
		float cx = sourceSTLModel.cornerMinimum.x+dimension.x/2.f;
		float cy = sourceSTLModel.cornerMinimum.y+dimension.y/2.f;
		float cz = sourceSTLModel.cornerMinimum.z+dimension.z/2.f;
		//		float tz = dimension.z*objectScale/2.f;
		
		processedSTLModel.cornerMinimum = [[Vector3 alloc] initVectorWithX:FLT_MAX Y:FLT_MAX Z:FLT_MAX];
		processedSTLModel.cornerMaximum = [[Vector3 alloc] initVectorWithX:-FLT_MAX Y:-FLT_MAX Z:-FLT_MAX];
		for(NSUInteger i = 0; i<stl->numberOfFacets; i++)
		{			
			for(NSUInteger pIndex = 0; pIndex<3; pIndex++)
			{
				// Center the object before rotating
				facet->p[pIndex].x-=cx;
				facet->p[pIndex].y-=cy;
				facet->p[pIndex].z-=cz;
				
				// Rotate
				rotateVertex(kRotateX, &(facet->p[pIndex]), angleX);
				rotateVertex(kRotateY, &(facet->p[pIndex]), angleY);
				rotateVertex(kRotateZ, &(facet->p[pIndex]), angleZ);
				
				// Scale
				facet->p[pIndex].x*=objectScale;
				facet->p[pIndex].y*=objectScale;
				facet->p[pIndex].z*=objectScale;
				
				// Caclulate rotated Bounds
				[processedSTLModel.cornerMaximum maximizeWithX:facet->p[pIndex].x Y:facet->p[pIndex].y Z:facet->p[pIndex].z];
				[processedSTLModel.cornerMinimum minimizeWithX:facet->p[pIndex].x Y:facet->p[pIndex].y Z:facet->p[pIndex].z];
			}
			
			facet = nextFacet(facet);
		}
		
		Vector3* rotatedDimension = [processedSTLModel.cornerMaximum sub:processedSTLModel.cornerMinimum];
		// Nicht per self.dimX=..., da es sonst zu einer Rückkopplung kommt!
		// Bindings werden über Kreuzabhängigkeit mit processedSTLModel geupdated
		dimX=rotatedDimension.x;
		dimY=rotatedDimension.y;
		dimZ=rotatedDimension.z;		
		
		// Translate back in Position
		// needs to be handled in a second loop, since we need the completed rotatedSTLData.cornerMaximum/cornerMinimum
		
		facet = firstFacet(stl);
		for(UInt32 i = 0; i<stl->numberOfFacets; i++)
		{
			for(NSInteger pIndex = 0; pIndex<3; pIndex++)
			{
				facet->p[pIndex].x-=processedSTLModel.cornerMinimum.x+rotatedDimension.x/2.-centerX;
				facet->p[pIndex].y-=processedSTLModel.cornerMinimum.y+rotatedDimension.y/2.-centerY;
				facet->p[pIndex].z-=processedSTLModel.cornerMinimum.z-minZ;
				
			}
			facet = nextFacet(facet);
		}
		processedSTLModel.cornerMaximum.x-=processedSTLModel.cornerMinimum.x+rotatedDimension.x/2.-centerX;
		processedSTLModel.cornerMaximum.y-=processedSTLModel.cornerMinimum.y+rotatedDimension.y/2.-centerY;
		processedSTLModel.cornerMaximum.z-=processedSTLModel.cornerMinimum.z-minZ;
		processedSTLModel.cornerMinimum.x-=processedSTLModel.cornerMinimum.x+rotatedDimension.x/2.-centerX;
		processedSTLModel.cornerMinimum.y-=processedSTLModel.cornerMinimum.y+rotatedDimension.y/2.-centerY;
		processedSTLModel.cornerMinimum.z-=processedSTLModel.cornerMinimum.z-minZ;		
	}
	[self didChangeValueForKey:@"processedSTLModel"];
}

- (void)setSourceSTLModel:(STLModel*)value
{
	if(sourceSTLModel!=value)
	{
		sourceSTLModel=value;
		[self processSTLModel];
	}
}

- (void)resetWithSTLModel:(STLModel*)value
{
	if(sourceSTLModel!=value)
	{
		if(objectScale==0.)
		{
			objectRotateX=0.;
			objectRotateY=0.;
			objectRotateZ=0.;
			
			objectScale = 1.;
			
			Vector3* dimension = [value.cornerMaximum sub:value.cornerMinimum];
			centerX = value.cornerMinimum.x+dimension.x/2.;
			centerY = value.cornerMinimum.y+dimension.y/2.;
			minZ = value.cornerMinimum.z;
		}
		
		self.sourceSTLModel = value;
	}
}

- (void)setCenterX:(CGFloat)newXCenter
{
	if(self.centerX!=newXCenter)
	{
		[[undoManager prepareWithInvocationTarget:self] setCenterX:self.centerX];
		centerX = newXCenter;
		[self processSTLModel];
	}
}

- (void)setCenterY:(CGFloat)newYCenter
{
	if(self.centerY!=newYCenter)
	{
		[[undoManager prepareWithInvocationTarget:self] setCenterY:self.centerY];
		centerY = newYCenter;
		[self processSTLModel];
	}
}

- (void)setMinZ:(CGFloat)newZMin
{
	if(self.minZ!=newZMin)
	{
		[[undoManager prepareWithInvocationTarget:self] setMinZ:self.minZ];
		minZ = newZMin;
		[self processSTLModel];
	}
}

- (IBAction)centerObject:(id)sender
{
	[undoManager beginUndoGrouping];
	self.centerX = 0.;
	self.centerY = 0.;
	self.minZ = 0.;
	[undoManager endUndoGrouping];
}

- (void)rotateBy90OnAxis:(NSInteger)axis
{
	switch(axis)
	{
		case 0: self.objectRotateX+=90.; break;
		case 1: self.objectRotateY+=90.; break;
		case 2: self.objectRotateZ+=90.; break;
	}
}

- (IBAction)rotateBy90:(id)sender
{
	[self rotateBy90OnAxis:[sender tag]];
}

- (void)setObjectRotateX:(CGFloat)value
{
	if(objectRotateX!=value)
	{
		while(value>=360.)
			value-=360.;
		while(value<=-360.)
			value+=360.;
		[[undoManager prepareWithInvocationTarget:self] setObjectRotateX:objectRotateX];
		objectRotateX = value;
		[self processSTLModel];
	}
}

- (void)setObjectRotateY:(CGFloat)value
{
	if(objectRotateY!=value)
	{
		while(value>=360.)
			value-=360.;
		while(value<=-360.)
			value+=360.;
		[[undoManager prepareWithInvocationTarget:self] setObjectRotateY:objectRotateY];
		objectRotateY = value;
		[self processSTLModel];
	}
}

- (void)setObjectRotateZ:(CGFloat)value
{
	if(objectRotateZ!=value)
	{
		while(value>=360.)
			value-=360.;
		while(value<=-360.)
			value+=360.;
		[[undoManager prepareWithInvocationTarget:self] setObjectRotateZ:objectRotateZ];
		objectRotateZ = value;
		[self processSTLModel];
	}
}

- (void)setObjectScale:(CGFloat)value
{
	if(objectScale!=value)
	{
		[[undoManager prepareWithInvocationTarget:self] setObjectScale:objectScale];
		
		objectScale = value;
		
		[self processSTLModel];
	}
}

- (void)setDimX:(CGFloat)newXDim
{
	if(newXDim>0.)
	{
		CGFloat faktor = 1.;
		Vector3* dimension = [sourceSTLModel.cornerMaximum sub:sourceSTLModel.cornerMinimum];
		if(dimension.x>0.)
			faktor=newXDim/dimension.x;
		self.objectScale=faktor;		
	}
}

- (void)setDimY:(CGFloat)newYDim
{
	if(newYDim>0.)
	{
		Vector3* dimension = [sourceSTLModel.cornerMaximum sub:sourceSTLModel.cornerMinimum];
		CGFloat faktor = 1.;
		if(dimension.y>0.)
			faktor=newYDim/dimension.y;
		self.objectScale=faktor;		
	}
}

- (void)setDimZ:(CGFloat)newZDim
{
	if(newZDim>0.)
	{
		Vector3* dimension = [sourceSTLModel.cornerMaximum sub:sourceSTLModel.cornerMinimum];
		CGFloat faktor = 1.;
		if(dimension.z>0.)
			faktor=newZDim/dimension.z;
		self.objectScale=faktor;		
	}
}

@end
