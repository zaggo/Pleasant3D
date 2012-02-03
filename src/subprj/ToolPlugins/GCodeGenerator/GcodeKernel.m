//
//  GCodeKernel.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 12.08.09.
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

#import "GCodeKernel.h"
#import "GcodeGenerator.h"

@implementation GCodeKernel

- (GCode*)generateGCode:(P3DLoops*)loops owner:(P3DToolBase*)owner
{
	NSMutableString* gcode = [[NSMutableString alloc] init];
		
	float travelSpeed = ((GcodeGenerator*)owner).travelFeedRate * 53; // TODO: Get factor from a machine settings file
	float extrudeSpeed = [[((GcodeGenerator*)owner).layerSettings.lastObject objectForKey:@"feedRate"] floatValue]* 53; // TODO: !!!
	
	[loops.layers enumerateObjectsUsingBlock:^(id layer, NSUInteger layerIndex, BOOL *stopLayers) {
		float z = (float)layerIndex*loops.extrusionHeight;
		
		*stopLayers = owner.abortRequested;
		
		[layer enumerateObjectsUsingBlock:^(id loop, NSUInteger loopIndex, BOOL *stopLoops) {
			NSInteger count = ((PSMutableIntegerArray*)loop).count;
			if(count>0)
			{
				InsetLoopCorner* corner = &(loops.loopCorners[[((PSMutableIntegerArray*)loop) integerAtIndex:0]]);
				[gcode appendFormat:@"G1 X%1.3f Y%1.3f Z%1.3f F%1.3f\n",corner->point.s[0], corner->point.s[1], z, travelSpeed];
				[gcode appendString:@"M101\n"];
				for(NSUInteger pointIndex=1;pointIndex<count;pointIndex++)
				{
					corner = &(loops.loopCorners[[((PSMutableIntegerArray*)loop) integerAtIndex:pointIndex]]);
					[gcode appendFormat:@"G1 X%1.3f Y%1.3f Z%1.3f F%1.3f\n",corner->point.s[0], corner->point.s[1], z, extrudeSpeed];
				}
				[gcode appendString:@"M103\n"];
			}
		}];
	}];
			
	return [[GCode alloc] initWithGCodeString:gcode];
}

@end
