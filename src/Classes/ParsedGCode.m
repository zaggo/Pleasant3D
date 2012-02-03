//
//  GCodeParser.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 07.02.10.
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

#import "ParsedGCode.h"
#import <P3DCore/NSArray+GCode.h>

@interface NSScanner (ParseGCode)
- (void)updateLocation:(Vector3*)currentLocation;
- (BOOL)isLayerStartWithCurrentLocation:(Vector3*)currentLocation oldZ:(float*)oldZ layerStartWordExists:(BOOL)layerStartWordExist;
@end

@implementation NSScanner (ParseGCode)
- (void)updateLocation:(Vector3*)currentLocation
{
	float value;
	if([self scanString:@"X" intoString:nil])
	{
		[self scanFloat:&value];
		currentLocation.x = value;
	}
	if([self scanString:@"Y" intoString:nil])
	{
		[self scanFloat:&value];
		currentLocation.y = value;
	}
	if([self scanString:@"Z" intoString:nil])
	{
		[self scanFloat:&value];
		currentLocation.z = value;
	}
}

- (BOOL)isLayerStartWithCurrentLocation:(Vector3*)currentLocation oldZ:(float*)oldZ layerStartWordExists:(BOOL)layerStartWordExist
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
		[self updateLocation:currentLocation];
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



@implementation ParsedGCode
@synthesize cornerHigh, cornerLow, extrusionWidth, panes;

static NSArray* _extrusionColors=nil;
static CGColorRef _extrusionOffColor=nil;
+ (void)initialize
{
	// 'brown', 'red', 'orange', 'yellow', 'green', 'blue', 'purple'
	_extrusionColors = [NSArray arrayWithObjects:NSMakeCollectable(CGColorCreateGenericRGB(0.855, 0.429, 0.002, 1.000)), NSMakeCollectable(CGColorCreateGenericRGB(1.000, 0.000, 0.000, 1.000)), NSMakeCollectable(CGColorCreateGenericRGB(1.000, 0.689, 0.064, 1.000)), NSMakeCollectable(CGColorCreateGenericRGB(1.000, 1.000, 0.000, 1.000)), NSMakeCollectable(CGColorCreateGenericRGB(0.367, 0.742, 0.008, 1.000)), NSMakeCollectable(CGColorCreateGenericRGB(0.607, 0.598, 1.000, 1.000)), NSMakeCollectable(CGColorCreateGenericRGB(0.821, 0.000, 0.833, 1.000)), nil];
	_extrusionOffColor = (CGColorRef)CFMakeCollectable(CGColorCreateGenericRGB(0.902, 0.902, 0.902, .1));
}

- (id)initWithGCodeString:(NSString*)gcode;
{
	self = [super init];
	if(self)
	{
		// Create an array of linescanners
		NSMutableArray* gCodeLineScanners = [NSMutableArray array];
		NSArray* untrimmedLines = [gcode componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
		NSCharacterSet* whiteSpaceSet = [NSCharacterSet whitespaceCharacterSet];
		[untrimmedLines enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			[gCodeLineScanners addObject:[NSScanner scannerWithString:[obj stringByTrimmingCharactersInSet:whiteSpaceSet]]];
		}];
			
		extrusionWidth = 0.;
		
		BOOL isThereALayerStartWord=[gCodeLineScanners isThereAFirstWord:@"(<layer>"];
		
		panes = [NSMutableArray array];
		__block NSMutableArray* currentPane = nil;
		__block Vector3* currentLocation = [[Vector3 alloc] initVectorWithX:0. Y:0. Z:0.];
		__block float oldZ = -FLT_MAX;
		__block NSInteger extrusionNumber=0;
		__block Vector3* highCorner = [[Vector3 alloc] initVectorWithX:-FLT_MAX Y:-FLT_MAX Z:-FLT_MAX];
		__block Vector3* lowCorner = [[Vector3 alloc] initVectorWithX:FLT_MAX Y:FLT_MAX Z:FLT_MAX];
		__block float localExtrutionWidth = 0.;
		[gCodeLineScanners enumerateObjectsUsingBlock:^(id scanner, NSUInteger idx, BOOL *stop) {
			NSScanner* lineScanner = (NSScanner*)scanner;
			[lineScanner setScanLocation:0];
			if([lineScanner isLayerStartWithCurrentLocation:currentLocation oldZ:&oldZ layerStartWordExists:isThereALayerStartWord])
			{
				extrusionNumber = 0;
				currentPane = [NSMutableArray array];
				[panes addObject:currentPane];
			}
			if([lineScanner scanString:@"G1" intoString:nil])
			{
				[lineScanner updateLocation:currentLocation];
				[currentPane addObject:[[currentLocation copy] autorelease]];
				[lowCorner minimizeWith:currentLocation];
				[highCorner maximizeWith:currentLocation];
			}
			else if([lineScanner scanString:@"M101" intoString:nil])
			{
				extrusionNumber++;
				[currentPane addObject:[_extrusionColors objectAtIndex:extrusionNumber%[_extrusionColors count]]];
			}
			else if([lineScanner scanString:@"M103" intoString:nil])
			{
				[currentPane addObject:(id)_extrusionOffColor];
			}			
			else if([lineScanner scanString:@"(<extrusionWidth>" intoString:nil])
			{
				[lineScanner scanFloat:&localExtrutionWidth];
			}
		}];
		cornerLow = lowCorner;
		cornerHigh = highCorner;
		extrusionWidth = localExtrutionWidth;
	}
	return self;
}
@end
