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
const float  __averageAccelerationEfficiencyWhenTravelling = 0.2; // ratio : theoricalSpeed * averageAccelEfficiency = realSpeed along an average path
const float  __averageAccelerationEfficiencyWhenExtruding = 0.6; // ratio : theoricalSpeed * averageAccelEfficiency = realSpeed along an average path

@interface NSScanner (ParseGCode)
- (void)updateLocation:(Vector3*)currentLocation;
- (void)updateStats:(struct stats*)GCODE_stats with:(Vector3*)currentLocation;
- (BOOL)isNewLayerWithCurrentLocation:(Vector3*)currentLocation;
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
    // Travelling
    Vector3* previousLocation = GCODE_stats->currentLocation;
    GCODE_stats->currentLocation = [[currentLocation copy] autorelease];
    GCODE_stats->movementLinesCount++;
            
    // Look for a feedrate FIRST
    if([self scanString:@"F" intoString:nil])
	{
		[self scanFloat:&GCODE_stats->currentFeedRate]; // mm/min
    }
    
    // Look for an extrusion length
    // E or A is the first extruder head
    // B is the other extruder
    float previousExtrudedLength = GCODE_stats->usingSecondExtruder
        ? GCODE_stats->currentExtrudedLengthSecondExtruder
        : GCODE_stats->currentExtrudedLength;
    float currentExtrudedLength = previousExtrudedLength; // Default value: no change.
    if([self scanString:@"E" intoString:nil]
       || [self scanString:@"A" intoString:nil]
       || [self scanString:@"B" intoString:nil])
	{
        [self scanFloat:&currentExtrudedLength];
        if (GCODE_stats->usingSecondExtruder) {
            GCODE_stats->currentExtrudedLengthSecondExtruder = currentExtrudedLength;
        } else {
            GCODE_stats->currentExtrudedLength = currentExtrudedLength;
        }
	}
    
    //NSLog(@" ## Previous : %@", [previousLocation description]);
    //NSLog(@" ## Current : %@", [GCODE_stats->currentLocation description]);
    
    Vector3* travelVector = [GCODE_stats->currentLocation sub:previousLocation];
    float longestDistanceToMove = MAX(ABS(travelVector.x), ABS(travelVector.y)); // mm
    float cartesianDistance = [travelVector abs]; // mm
    
    // Are we extruding ?
    GCODE_stats->extruding = (currentExtrudedLength > previousExtrudedLength);
    GCODE_stats->totalExtrudedLength += (currentExtrudedLength - previousExtrudedLength); // mm

    // Extrusion in progress
    if (GCODE_stats->extruding){
        //NSLog(@"Extruding %f  > %f", currentExtrudedLength, previousExtrudedLength);
        GCODE_stats->totalExtrudedDistance += cartesianDistance; // mm
        GCODE_stats->totalExtrudedTime += (longestDistanceToMove / (GCODE_stats->currentFeedRate *  __averageAccelerationEfficiencyWhenExtruding)); // min
    } else {
        // NSLog(@"TRAVELLING");
        GCODE_stats->totalTravelledDistance += cartesianDistance; // mm
        GCODE_stats->totalTravelledTime += (longestDistanceToMove / (GCODE_stats->currentFeedRate * __averageAccelerationEfficiencyWhenTravelling)); // min
    }
    
    // NSLog(@" ## tel= %f; tet= %f; ttt=%f; nel=%f; D=%f; fr=%f; extr=%d", GCODE_stats->totalExtrudedLength, GCODE_stats->totalExtrudedTime, GCODE_stats->totalTravelledTime, newExtrudedLength, longestDistanceToMove, GCODE_stats->currentFeedRate, GCODE_stats->extruding);

    [self setScanLocation:0];
    
}

- (BOOL)isNewLayerWithCurrentLocation:(Vector3*)currentLocation
{
    BOOL isNewLayer = NO;
    
    if([self scanString:@"G1" intoString:nil])
	{
        
        float oldZ = currentLocation.z;
		[self updateLocation:currentLocation];
        
        BOOL layerChange = ABS(currentLocation.z - oldZ) > .09 && ABS(currentLocation.z - oldZ) < 100.0;
        // NSLog(@"%f", ABS(currentLocation.z - oldZ));
        
        if(layerChange) {
            
            // NSLog(@"New layer created at z = %f", currentLocation.z);
			isNewLayer = YES;
		}
        
	}
	
    // Reset scan of line
    [self setScanLocation:0];
    
	return isNewLayer;
}

@end


@implementation ParsedGCode
@synthesize cornerHigh, cornerLow, extrusionWidth, panes, statistics;

static NSArray* _extrusionColors=nil;
static NSArray* _extrusionColors_A=nil;
static NSArray* _extrusionColors_B=nil;
static NSColor* _extrusionOffColor=nil;

+ (void)initialize
{
    // For single head extrusions
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

    // For dual head extrusions
    // different shades of the same color
    _extrusionColors_A = [NSArray arrayWithObjects:
                        [[NSColor brownColor] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                        [[NSColor redColor] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                        [[NSColor orangeColor] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                        [[NSColor yellowColor] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                        nil];

    _extrusionColors_B = [NSArray arrayWithObjects:
                          [[NSColor cyanColor] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                          [[NSColor magentaColor] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
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
    return statistics.totalExtrudedLength / 10.0 ; // in cm
}
- (NSInteger)getLayerHeight
{
    return floor(statistics.layerHeight * 100.0)*10 ; // in mm
}

- (id)initWithGCodeString:(NSString*)gcode;
{
	self = [super init];
	if(self)
	{
        // Init stats
        statistics.currentFeedRate = 4800.0; // Default feed rate (mm/min)
        
        statistics.currentLocation = [[Vector3 alloc] initVectorWithX:0. Y:0. Z:0.];
        statistics.totalTravelledTime = 0;
        statistics.totalTravelledDistance = 0;
        statistics.totalExtrudedTime = 0;
        statistics.totalExtrudedDistance = 0;
        
        statistics.totalExtrudedLength = 0;
        statistics.currentExtrudedLength = 0;
        
        statistics.movementLinesCount = 0;
        statistics.layersCount = 0;
        statistics.layerHeight = -1.0;
        
        statistics.extruding = NO;
        statistics.dualExtrusion = NO;
        statistics.usingSecondExtruder = NO;
        
		NSArray* untrimmedLines = [gcode componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
		NSCharacterSet* whiteSpaceSet = [NSCharacterSet whitespaceCharacterSet];
			
		extrusionWidth = 0.;
		__block NSInteger extrusionNumber = 0;
		
		panes = [NSMutableArray array];
		__block NSMutableArray* currentPane = nil;
		__block Vector3* currentLocation = [[Vector3 alloc] initVectorWithX:0. Y:0. Z:0.];
		__block Vector3* highCorner = [[Vector3 alloc] initVectorWithX:-FLT_MAX Y:-FLT_MAX Z:-FLT_MAX];
		__block Vector3* lowCorner = [[Vector3 alloc] initVectorWithX:FLT_MAX Y:FLT_MAX Z:FLT_MAX];

		// Scan each line.
		[untrimmedLines enumerateObjectsUsingBlock:^(id untrimmedLine, NSUInteger idx, BOOL *stop) {
            NSScanner* lineScanner = [NSScanner scannerWithString:[untrimmedLine stringByTrimmingCharactersInSet:whiteSpaceSet]];
            
            float oldZ = currentLocation.z;
            
            if ([lineScanner isNewLayerWithCurrentLocation:currentLocation]){
                
                currentPane = [NSMutableArray array];
                [panes addObject:currentPane];
                statistics.layersCount++;
                
                if (statistics.layerHeight == - 1.0){
                    NSLog(@"INFO : Faking layer height calculation - skipping first result");
                    statistics.layerHeight = 0;
                } else if (statistics.layerHeight == 0.0){
                    NSLog(@"INFO : Layer height : %fµ", roundf(ABS(oldZ - currentLocation.z)*100)*10);
                    statistics.layerHeight = roundf(ABS(oldZ - currentLocation.z)*100)/100 ;
                }
                
            }
            
            // Look for GCode commands starting with G, M or T.
            NSCharacterSet* commandCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"GMT0123456789"];
            NSString* command = nil;
            BOOL commandFound = [lineScanner scanCharactersFromSet:commandCharacterSet intoString:&command];

            if (!commandFound) {
                return;
            }
            
            // Statistics
            if([command isEqualToString:@"G1"])
            {   
                [lineScanner updateLocation:currentLocation];
                                 
                [lowCorner minimizeWith:currentLocation];
                [highCorner maximizeWith:currentLocation];
                
                // Update stats
                [lineScanner updateStats:&statistics with:currentLocation];
                
                // Coloring
                if(statistics.extruding)
                {
                    if (statistics.dualExtrusion) {
                        if (statistics.usingSecondExtruder) {
                            [currentPane addObject:[_extrusionColors_B objectAtIndex:extrusionNumber%[_extrusionColors_B count]]];
                        } else {
                            [currentPane addObject:[_extrusionColors_A objectAtIndex:extrusionNumber%[_extrusionColors_A count]]];
                        }
                    } else {
                        [currentPane addObject:[_extrusionColors objectAtIndex:extrusionNumber%[_extrusionColors count]]];
                    }
                    
                } else {
                    extrusionNumber++;
                    [currentPane addObject:_extrusionOffColor];
                }
                
                [currentPane addObject:[[currentLocation copy] autorelease]];
            
            } else if([command isEqualToString:@"G92"]) {
                // G92: Set Position. Allows programming of absolute zero point, by reseting the current position
                // to the values specified.
                // Slic3r uses this to reset the extruded distance.
                
                // We assume that an E value appears first.
                if ([lineScanner scanString:@"E" intoString:nil]) {
                    float currentExtrudedLength;
                    [lineScanner scanFloat:&currentExtrudedLength];
                    if (statistics.usingSecondExtruder) {
                        statistics.currentExtrudedLengthSecondExtruder = currentExtrudedLength;
                    } else {
                        statistics.currentExtrudedLength = currentExtrudedLength;
                    }
                }
            } else if ([command isEqualToString:@"M135"] || [command isEqualToString:@"M108"]) {
                // M135: tool switch.
                // M108: Set Extruder Speed.
                // Both are used in practice to swith the current extruder.
                // M135 is used by Makerware, M108 is used by Replicator G.
                if ([lineScanner scanString:@"T" intoString:nil]) {
                    int toolIndex;
                    [lineScanner scanInt:&toolIndex];
                    statistics.usingSecondExtruder = (toolIndex >= 1);
                    if (statistics.usingSecondExtruder) {
                        statistics.dualExtrusion = TRUE;
                    }
                }
            } else if ([command isEqualToString:@"T0"]) {
                // T0: Switch to the first extruder.
                // Slic3r and KISSlicer use this to switch the current extruder.
                statistics.usingSecondExtruder =  NO;
            } else if ([command isEqualToString:@"T1"]) {
                // T1: Switch to the second extruder.
                // Slic3r and KISSlicer use this to switch the current extruder.
                statistics.usingSecondExtruder =  YES;
                statistics.dualExtrusion = YES;
            }
            
		}];
        
        // Correct height:
        highCorner.z = statistics.layersCount * statistics.layerHeight;
        
		cornerLow = lowCorner;
		cornerHigh = highCorner;
		extrusionWidth = statistics.layerHeight;

        /*
        NSLog(@" High corner: %@", cornerHigh);
        NSLog(@" Low corner: %@", cornerLow);
        NSLog(@" Total Extruded length (mm): %f", statistics.totalExtrudedLength);
        NSLog(@" Using dual extrusion: %@", statistics.dualExtrusion ? @"Yes" : @"No");
        NSLog(@" Grams : %f", statistics.totalExtrudedLength * pi/4 * pow(1.75,2) * 1050 * pow(10,-6));
        
        NSLog(@" G1 Lines : %d",statistics.movementLinesCount );
        
        NSLog(@" Layer Height : %f",statistics.layerHeight );
        NSLog(@" Layer Count : %d",statistics.layersCount );
        NSLog(@" Height Corrected (mm) : %f",statistics.layersCount*statistics.layerHeight );
        
        NSLog(@" Total Extruded time (min): %f", statistics.totalExtrudedTime);
        NSLog(@" Total Travelled time (min): %f", statistics.totalTravelledTime);
        
        NSLog(@" Total Extruded distance (mm): %f", statistics.totalExtrudedDistance);
        NSLog(@" Total Travelled distance (mm): %f", statistics.totalTravelledDistance);
        //*/
    
	}
    
	return self;

}
@end
