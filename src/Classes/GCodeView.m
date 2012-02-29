//
//  GCodeView.m
//  MacSkeinforge
//
//  Created by Eberhard Rensch on 04.08.09.
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

#import "GCodeView.h"
#import <OpenGL/glu.h>
#import <P3DCore/P3DCore.h>
#import "ParsedGCode.h"

static GLuint makeMask(NSInteger n)
{
	return (2L<<n-1) - 1;
}

@implementation GCodeView
@synthesize parsedGCode, currentLayerMaxZ, currentLayerMinZ;

+ (NSSet *)keyPathsForValuesAffectingCurrentZ {
    return [NSSet setWithObjects:@"currentLayerMaxZ", @"currentLayerMinZ", nil];
}

- (NSString*)currentZ
{
	NSString* currentZ = @"- mm";
	if(currentLayerMinZ<FLT_MAX && currentLayerMaxZ>-FLT_MAX)
	{
		NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
		[numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
		[numberFormatter setFormat:@"0.0mm;0.0mm;-0.0mm"];

		if(fabsf(currentLayerMaxZ-currentLayerMinZ)<0.1)
		{
			currentZ = [numberFormatter stringFromNumber:[NSNumber numberWithFloat:currentLayerMaxZ]];
		}
		else
		{
			currentZ = [NSString stringWithFormat:@"%@ - %@",[numberFormatter stringFromNumber:[NSNumber numberWithFloat:currentLayerMinZ]], [numberFormatter stringFromNumber:[NSNumber numberWithFloat:currentLayerMaxZ]]];
		}
	}
	return currentZ;
}

+ (NSSet *)keyPathsForValuesAffectingMaxLayers {
    return [NSSet setWithObjects:@"parsedGCode", nil];
}

+ (NSSet *)keyPathsForValuesAffectingDimensionsString {
    return [NSSet setWithObjects:@"parsedGCode", nil];
}

+ (NSSet *)keyPathsForValuesAffectingLayerInfoString {
    return [NSSet setWithObjects:@"parsedGCode", @"currentLayer", nil];
}

- (NSInteger)maxLayers
{
	return parsedGCode.panes.count-1;
}

- (Vector3*)objectDimensions
{
    return [parsedGCode.cornerHigh sub:parsedGCode.cornerLow];
}

- (NSString*)dimensionsString
{
	Vector3* dimension = [parsedGCode.cornerHigh sub:parsedGCode.cornerLow];
	
	NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
	[numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
	[numberFormatter setFormat:@"0.0mm;0.0mm;-0.0mm"];
	
	NSString* dimString = [NSString stringWithFormat:@"%@ (X) x %@ (Y) x %@ (Z)", [numberFormatter stringFromNumber:[NSNumber numberWithFloat:dimension.x]], [numberFormatter stringFromNumber:[NSNumber numberWithFloat:dimension.y]], [numberFormatter stringFromNumber:[NSNumber numberWithFloat:dimension.z]]];
	return dimString;
}

- (NSString*)layerInfoString
{
	NSString* infoString = NSLocalizedString(@"Layer - of -: - mm",nil);
	if(parsedGCode)
	{
		infoString = [NSString stringWithFormat: NSLocalizedString(@"Layer %d of %d: %@",nil), currentLayer+1, parsedGCode.panes.count,[self currentZ]];
	}
	return infoString;
}

- (void)setParsedGCode:(ParsedGCode*)value
{
	parsedGCode = value;
	[self setNeedsDisplay:YES];
}

- (void)awakeFromNib
{
	[super awakeFromNib];
	self.currentLayerMinZ = FLT_MAX;
	self.currentLayerMaxZ = -FLT_MAX;
}

+ (NSSet *)keyPathsForValuesAffectingCorrectedCurrentLayer {
    return [NSSet setWithObjects:@"currentLayer", nil];
}

- (NSInteger)correctedCurrentLayer
{
	return self.currentLayer+1;
}

+ (NSSet *)keyPathsForValuesAffectingDimX {
    return [NSSet setWithObjects:@"parsedGCode", nil];
}

- (CGFloat)dimX
{
	Vector3* dimension = [parsedGCode.cornerHigh sub:parsedGCode.cornerLow];
	return dimension.x;
}

+ (NSSet *)keyPathsForValuesAffectingDimY {
    return [NSSet setWithObjects:@"parsedGCode", nil];
}

- (CGFloat)dimY
{
	Vector3* dimension = [parsedGCode.cornerHigh sub:parsedGCode.cornerLow];
	return dimension.y;
}

+ (NSSet *)keyPathsForValuesAffectingDimZ {
    return [NSSet setWithObjects:@"parsedGCode", nil];
}

- (CGFloat)dimZ
{
	Vector3* dimension = [parsedGCode.cornerHigh sub:parsedGCode.cornerLow];
	return dimension.z;
}

- (float)layerHeight
{
	if(parsedGCode.panes.count>0)
		return self.dimZ/parsedGCode.panes.count;
	return 1.;
}

- (void)renderContent 
{		
	float minLayerZ=FLT_MAX;
	float maxLayerZ=-FLT_MAX;
	if(parsedGCode)
	{
		glDisable(GL_COLOR_MATERIAL);
		glDisable(GL_LIGHTING);
		glDisable(GL_LIGHT0);

		unsigned long indx=0; // Für Selection
		
		if(threeD)
		{
			NSUInteger layer=0;
			for(NSArray* pane in parsedGCode.panes)
			{
				glLineWidth((layer==currentLayer)?1.f:2.f);

				Vector3* lastPoint = nil;
				for(id elem in pane)
				{
					if([elem isKindOfClass:[Vector3 class]])
					{
						Vector3* point = (Vector3*)elem;
						if(lastPoint)
						{							
							glBegin(GL_LINES);
							glVertex3f((GLfloat)lastPoint.x,(GLfloat)lastPoint.y, (GLfloat)lastPoint.z);
							glVertex3f((GLfloat)point.x,(GLfloat)point.y, (GLfloat)point.z);
							glEnd();
							
							if(layer==currentLayer)
							{
								minLayerZ = MIN(minLayerZ, point.z);
								maxLayerZ = MAX(minLayerZ, point.z);

								if(showArrows)
								{								
									glPushMatrix();
									glTranslatef((GLfloat)((point.x+lastPoint.x)/2.f), (GLfloat)((point.y+lastPoint.y)/2.f), (GLfloat)((point.z+lastPoint.z)/2.f));
									glRotatef((GLfloat)(180.f*atan2f((lastPoint.y-point.y),(lastPoint.x-point.x))/M_PI), 0.f, 0.f, 1.f);
									glCallList(arrowDL);
									glPopMatrix();
								}
							}
							indx++;
						}
						lastPoint = point;
					}
					else
					{
						const CGFloat* color = CGColorGetComponents((CGColorRef)elem);
						if(currentLayer > layer)
							glColor4f((GLfloat)color[0], (GLfloat)color[1], (GLfloat)color[2], (GLfloat)color[3]*powf((GLfloat)othersAlpha,3.f)); 
						else if(currentLayer < layer)
							glColor4f((GLfloat)color[0], (GLfloat)color[1], (GLfloat)color[2], ((GLfloat)color[3]*powf((GLfloat)othersAlpha,3.f))/(1.f+20.f*powf((GLfloat)othersAlpha, 3.f))); 
						else
							glColor4f((GLfloat)color[0], (GLfloat)color[1], (GLfloat)color[2], (GLfloat)color[3]);
					}
				}
				layer++;
			}
		}
		else
		{
			if(currentLayer<[parsedGCode.panes count])
			{
				glLineWidth(2.f);
				NSArray* pane = [parsedGCode.panes objectAtIndex:currentLayer];
				Vector3* lastPoint=nil;
				for(id elem in pane)
				{
					if([elem isKindOfClass:[Vector3 class]])
					{
						Vector3* point = (Vector3*)elem;
						if(lastPoint)
						{
//							if(selectionDetection)
//							{
//							   glColor3ui ((GLuint)(indx & redMask << redShift), 
//										   (GLuint)(indx & greenMask << greenShift), 
//										   (GLuint)(indx & blueMask << blueShift));
//							}
							glBegin(GL_LINES);
								glVertex3f((GLfloat)lastPoint.x, (GLfloat)lastPoint.y, 0.f);
								glVertex3f((GLfloat)point.x, (GLfloat)point.y, 0.f);
							glEnd();
							if(showArrows)
							{
								glPushMatrix();
								glTranslatef((GLfloat)(point.x+lastPoint.x)/2.f, (GLfloat)(point.y+lastPoint.y)/2.f, 0.f);
								glRotatef((GLfloat)(180.f*atan2f((lastPoint.y-point.y),(lastPoint.x-point.x))/M_PI), 0.f, 0.f, 1.f);
								glCallList(arrowDL);
								glPopMatrix();
							}
							indx++;
						}
						lastPoint = point;
						minLayerZ = MIN(minLayerZ, point.z);
						maxLayerZ = MAX(minLayerZ, point.z);
					}
					else
					{
						const CGFloat* color = CGColorGetComponents((CGColorRef)elem);
						glColor4f((GLfloat)color[0], (GLfloat)color[1], (GLfloat)color[2], (GLfloat)color[3]);
					}
				}
			}
		}
	}
	
	self.currentLayerMinZ=(CGFloat)minLayerZ;
	self.currentLayerMaxZ=(CGFloat)maxLayerZ;
}
@end
