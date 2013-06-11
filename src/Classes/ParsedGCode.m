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


const float __filamentDiameter = 1.75 + 0.07; // mm + bias (mm)
const float __averageDensity = 1050; // kg.m-3
const float  __averageAccelerationEfficiency = 0.3; // ratio : theoricalSpeed * averageAccelEfficiency = realSpeed along an average path

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

- (void)updateStats:(struct stats*)GCODE_stats with:(Vector3*)currentLocation
{
    float newExtrudedLength = 0;
    float feedRate = 0;
    
    [self setScanLocation:0];    
    // are we G0/1, or M101/3 ?
    if([self scanString:@"G1 " intoString:nil] || [self scanString:@"G0 " intoString:nil])
	{
        // travelling
        GCODE_stats->currentLocation = currentLocation;
        GCODE_stats->movementLinesCount++;
            
    } else {
        // Nothing important, skip.
        return;
    }
    
    // Look for an extrusion length
    if([self scanUpToString:@"E" intoString:nil])
	{
        [self scanString:@"E" intoString:nil];
		[self scanFloat:&newExtrudedLength]; // mm
        [self setScanLocation:0];
	}
    if([self scanUpToString:@"A" intoString:nil])
	{
        [self scanString:@"A" intoString:nil];
		[self scanFloat:&newExtrudedLength]; // mm
        [self setScanLocation:0];
	}
    
    
    // Look for a feedrate
    if([self scanUpToString:@"F" intoString:nil])
	{
        [self scanString:@"F" intoString:nil];
		[self scanFloat:&feedRate]; // mm/min
	}
    
    //NSLog(@" ## Previous : %@", [GCODE_stats->previousLocation description]);
    //NSLog(@" ## Current : %@", [GCODE_stats->currentLocation description]);
    
    Vector3* travelVector = [GCODE_stats->currentLocation sub:GCODE_stats->previousLocation];
    float longestDistanceToMove = MAX(ABS(travelVector.x), ABS(travelVector.y)); // mm
    float cartesianDistance = [travelVector abs]; // mm

    // No FR information ?
    if (feedRate == 0){
        // Take previous feedRate
        GCODE_stats->currentFeedRate = GCODE_stats->defaultFeedRate; // mm/min
    } else {
        if ([GCODE_stats->previousLocation isEqual:GCODE_stats->currentLocation])
        {
            GCODE_stats->defaultFeedRate = GCODE_stats->currentFeedRate = feedRate; // mm/min
        }
    }
    
    // Extrusion in progress
    if (newExtrudedLength > 0){
        GCODE_stats->totalExtrudedLength = newExtrudedLength; // mm
        GCODE_stats->totalExtrudedDistance += cartesianDistance; // mm
        GCODE_stats->totalExtrudedTime += (longestDistanceToMove / (GCODE_stats->currentFeedRate *  __averageAccelerationEfficiency)); // min
    } else {
        GCODE_stats->totalTravelledDistance += cartesianDistance; // mm
        GCODE_stats->totalTravelledTime += (longestDistanceToMove / (GCODE_stats->currentFeedRate * __averageAccelerationEfficiency)); // min
    }
            
    GCODE_stats->previousLocation = [[GCODE_stats->currentLocation copy] autorelease];
    
    //NSLog(@" ## tel= %f; tet= %f; ttt=%f; nel=%f; D=%f; fr=%f; extr=%d", GCODE_stats->totalExtrudedLength, GCODE_stats->totalExtrudedTime, GCODE_stats->totalTravelledTime, newExtrudedLength, longestDistanceToMove, GCODE_stats->currentFeedRate, newExtrudedLength > 0);

    [self setScanLocation:0];
    
}

- (BOOL)isLayerStartWithCurrentLocation:(Vector3*)currentLocation oldZ:(float*)oldZ layerStartWordExists:(BOOL)layerStartWordExist
{
	BOOL isLayerStart = NO;
	
	if(layerStartWordExist)
	{
		if([self scanString:@"(<layer>" intoString:nil])
			isLayerStart = YES;
		if([self scanString:@"(Slice" intoString:nil])
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
@synthesize cornerHigh, cornerLow, extrusionWidth, panes, statistics;

static NSArray* _extrusionColors=nil;
static NSColor* _extrusionOffColor=nil;
+ (void)initialize
{
	// 'brown', 'red', 'orange', 'yellow', 'green', 'blue', 'purple'
    _extrusionColors = [NSArray arrayWithObjects:
     [[NSColor brownColor] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
     [[NSColor redColor] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
     [[NSColor orangeColor] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
     [[NSColor yellowColor] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
     [[NSColor greenColor] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
     [[NSColor blueColor] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
     [[NSColor purpleColor] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
     nil];

    _extrusionOffColor = [[[NSColor grayColor] colorWithAlphaComponent:0.6] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];

}

- (float)getTotalMachiningTime
{
    return statistics.totalExtrudedTime + statistics.totalTravelledTime;
}
- (float)getObjectWeight
{
    return statistics.totalExtrudedLength * pi/4 * pow(__filamentDiameter,2) * __averageDensity * pow(10,-6); // in g
}
- (float)getFilamentLength
{
    return statistics.totalExtrudedLength / 10 ; // in mm
}


- (id)initWithGCodeString:(NSString*)gcode;
{
	self = [super init];
	if(self)
	{
        // Init stats
        statistics.defaultFeedRate = 4800.0; // (mm/min)
        
        statistics.currentLocation = [[Vector3 alloc] initVectorWithX:0. Y:0. Z:0.];
        statistics.previousLocation = [[Vector3 alloc] initVectorWithX:0. Y:0. Z:0.];
        statistics.totalTravelledTime = 0;
        statistics.totalTravelledDistance = 0;
        statistics.totalExtrudedTime = 0;
        statistics.totalExtrudedDistance = 0;
        
        statistics.totalExtrudedLength = 0;
        
        statistics.movementLinesCount = 0;
        statistics.extruding = NO;
        
		// Create an array of linescanners
		NSMutableArray* gCodeLineScanners = [NSMutableArray array];
		NSArray* untrimmedLines = [gcode componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
		NSCharacterSet* whiteSpaceSet = [NSCharacterSet whitespaceCharacterSet];
		[untrimmedLines enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			[gCodeLineScanners addObject:[NSScanner scannerWithString:[obj stringByTrimmingCharactersInSet:whiteSpaceSet]]];
		}];
			
		extrusionWidth = 0.;
		
		// MakerWare 1.1 uses Slice and has no <layer>
		BOOL isThereALayerStartWord=[gCodeLineScanners isThereAFirstWord:@"(<layer>"] || [gCodeLineScanners isThereAFirstWord:@"(Slice"];
		
		panes = [NSMutableArray array];
		__block NSMutableArray* currentPane = nil;
		__block Vector3* currentLocation = [[Vector3 alloc] initVectorWithX:0. Y:0. Z:0.];
		__block float oldZ = -FLT_MAX;
		__block NSInteger extrusionNumber=0;
		__block Vector3* highCorner = [[Vector3 alloc] initVectorWithX:-FLT_MAX Y:-FLT_MAX Z:-FLT_MAX];
		__block Vector3* lowCorner = [[Vector3 alloc] initVectorWithX:FLT_MAX Y:FLT_MAX Z:FLT_MAX];
		__block float localExtrutionWidth = 0.;
		__block float lastEValue = 0;
		__block float eValue = 0;
		__block BOOL extrusionOff = NO;
		__block BOOL makerWareInUse = YES;
		
		[gCodeLineScanners enumerateObjectsUsingBlock:^(id scanner, NSUInteger idx, BOOL *stop) {
            
			NSScanner* lineScanner = (NSScanner*)scanner;
			[lineScanner setScanLocation:0];
			if([lineScanner isLayerStartWithCurrentLocation:currentLocation oldZ:&oldZ layerStartWordExists:isThereALayerStartWord])
			{
				extrusionNumber = 0;
				currentPane = [NSMutableArray array];
				[panes addObject:currentPane];
			}
			BOOL hasG1E = [lineScanner scanString:@"G1 E" intoString:nil];
			BOOL hasSnort = [[lineScanner string] rangeOfString:@"(snort)"].length != 0;
			BOOL hasSquirt = [[lineScanner string] rangeOfString:@"(squirt)"].length != 0;
                        
			if(makerWareInUse && (hasG1E || hasSnort || hasSquirt))
			{
				// Track E value for MakerWare 1.0 only
				// Makerware does not insert 101 and 103s into the G-Code, so coloring fails
				// G1 E with E smaller is a 103, next G1 E setting is a 101
				if(hasG1E) {
					[lineScanner scanFloat:&eValue];
					if(eValue<lastEValue) {
						[currentPane addObject:_extrusionOffColor];
						extrusionOff = YES;
					} else if (extrusionOff) {
						extrusionNumber++;
						[currentPane addObject:[_extrusionColors objectAtIndex:extrusionNumber%[_extrusionColors count]]];
						extrusionOff = NO;
					}
					lastEValue = eValue;
				} else {
					// For MakerWare 1.1 only
					// Makerware does not insert 101 and 103s into the G-Code, so coloring fails
					// Snort and squirt are used
					if(hasSnort) {
						[currentPane addObject:_extrusionOffColor];
					} else if(hasSquirt) {
						extrusionNumber++;
						[currentPane addObject:[_extrusionColors objectAtIndex:extrusionNumber%[_extrusionColors count]]];
					}
				}
				
			}
			else if([lineScanner scanString:@"G1" intoString:nil])
			{
				[lineScanner updateLocation:currentLocation];
				[currentPane addObject:[[currentLocation copy] autorelease]];
				[lowCorner minimizeWith:currentLocation];
				[highCorner maximizeWith:currentLocation];

			}
			else if([lineScanner scanString:@"M101" intoString:nil])
			{
				makerWareInUse = NO;
				extrusionNumber++;
				[currentPane addObject:[_extrusionColors objectAtIndex:extrusionNumber%[_extrusionColors count]]];
			}
			else if([lineScanner scanString:@"M103" intoString:nil])
			{
				makerWareInUse = NO;
				[currentPane addObject:_extrusionOffColor];
			}			
			else if([lineScanner scanString:@"(<extrusionWidth>" intoString:nil])
			{
				[lineScanner scanFloat:&localExtrutionWidth];
			}
            
            // Current Location is now updated
            //NSLog(@"%@", [lineScanner string]);
            
            // Update stats
            if(!hasSnort && !hasSquirt) {
                [lineScanner updateStats:&statistics with:currentLocation];
            }
            
		}];
        
		cornerLow = lowCorner;
		cornerHigh = highCorner;
		extrusionWidth = localExtrutionWidth;

        /*
        NSLog(@" Total Extruded length (mm): %f", statistics.totalExtrudedLength);
        NSLog(@" Grams : %f", statistics.totalExtrudedLength * pi/4 * pow(1.75,2) * 1050 * pow(10,-6));
        
        NSLog(@" Lines : %d",statistics.movementLinesCount );
        
        NSLog(@" Total Extruded time (min): %f", statistics.totalExtrudedTime);
        NSLog(@" Total Travelled time (min): %f", statistics.totalTravelledTime);
        
        NSLog(@" Total Extruded distance (mm): %f", statistics.totalExtrudedDistance);
        NSLog(@" Total Travelled distance (mm): %f", statistics.totalTravelledDistance);
         */
    
	}
	return self;
}
@end
