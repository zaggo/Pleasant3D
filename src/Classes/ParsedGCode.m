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
#import "GCodeStatistics.h"

const float __filamentDiameter = 1.75 + 0.07; // mm + bias (mm)
const float __averageDensity = 1050; // kg.m-3
const float  __averageAccelerationEfficiencyWhenTravelling = 0.2; // ratio : theoricalSpeed * averageAccelEfficiency = realSpeed along an average path
const float  __averageAccelerationEfficiencyWhenExtruding = 0.6; // ratio : theoricalSpeed * averageAccelEfficiency = realSpeed along an average path

#pragma mark - NSScanner Category

@interface NSScanner (ParseGCode)
- (void)updateLocation:(Vector3*)currentLocation;
- (void)updateStats:(GCodeStatistics*)GCODE_stats with:(Vector3*)currentLocation;
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

- (void)updateStats:(GCodeStatistics*)gCodeStatistics with:(Vector3*)currentLocation
{
    // Travelling
    Vector3* previousLocation = gCodeStatistics->currentLocation;
    [gCodeStatistics->currentLocation setToVector3:currentLocation];
    gCodeStatistics->movementLinesCount++;
	
    // == Look for a feedrate FIRST ==
    if([self scanString:@"F" intoString:nil]) {
		[self scanFloat:&(gCodeStatistics->currentFeedRate)]; // mm/min
	}
    
    // == Look for an extrusion length ==
    // E or A is the first extruder head ("ToolA")
    // B is the other extruder ("ToolB")
    float currentExtrudedLength;
    
    if([self scanString:@"E" intoString:nil] || [self scanString:@"A" intoString:nil]) {
        
        // We're using ToolA for this move
        [self scanFloat:&currentExtrudedLength];
        gCodeStatistics->extruding = (currentExtrudedLength > gCodeStatistics->currentExtrudedLengthToolA);
        if (gCodeStatistics->extruding) {
            // Real life test
            gCodeStatistics->currentExtrudedLengthToolA = currentExtrudedLength;
        }
        gCodeStatistics->usingToolB = NO;
        
	} else if([self scanString:@"B" intoString:nil]) {
        
        // We're using ToolB for this move
        [self scanFloat:&currentExtrudedLength];
        gCodeStatistics->extruding = (currentExtrudedLength > gCodeStatistics->currentExtrudedLengthToolB);
        if (gCodeStatistics->extruding) {
            // Real life test
            gCodeStatistics->currentExtrudedLengthToolB = currentExtrudedLength;
        }
        gCodeStatistics->usingToolB = YES;
    }
    
    PSLog(@"parseGCode", PSPrioLow, @" ## Previous : %@", [previousLocation description]);
    PSLog(@"parseGCode", PSPrioLow, @" ## Current : %@", [gCodeStatistics->currentLocation description]);
    
    Vector3* travelVector = [gCodeStatistics->currentLocation sub:previousLocation];
    float longestDistanceToMove = MAX(ABS(travelVector.x), ABS(travelVector.y)); // mm
    float cartesianDistance = [travelVector abs]; // mm
    
    // == Calculating time taken to move or extrude ==
    if (gCodeStatistics->extruding) {
        
        // Extrusion in progress, let's calculate the time taken
        //PSLog(@"parseGCode", PSPrioLow, @"Extruding %f  > %f", currentExtrudedLength, previousExtrudedLength);
        gCodeStatistics->totalExtrudedDistance += cartesianDistance; // mm
        gCodeStatistics->totalExtrudedTime += (longestDistanceToMove / (gCodeStatistics->currentFeedRate *  __averageAccelerationEfficiencyWhenExtruding)); // min
    } else {
        
        // We're only travelling, let's calculate the time taken
        PSLog(@"parseGCode", PSPrioLow, @"Travelling");
        gCodeStatistics->totalTravelledDistance += cartesianDistance; // mm
        gCodeStatistics->totalTravelledTime += (longestDistanceToMove / (gCodeStatistics->currentFeedRate * __averageAccelerationEfficiencyWhenTravelling)); // min
    }
    
    PSLog(@"parseGCode", PSPrioLow, @" ## tel= %f; tet= %f; ttt=%f; D=%f; fr=%f; extr=%d", gCodeStatistics->currentExtrudedLengthToolA, gCodeStatistics->totalExtrudedTime, gCodeStatistics->totalTravelledTime, longestDistanceToMove, gCodeStatistics->currentFeedRate, gCodeStatistics->extruding);

    [self setScanLocation:0];
}

- (BOOL)isNewLayerWithCurrentLocation:(Vector3*)currentLocation
{
    BOOL isNewLayer = NO;
    
    if([self scanString:@"G1" intoString:nil]) {
        
        float oldZ = currentLocation.z;
		[self updateLocation:currentLocation];
        
        BOOL layerChange = ABS(currentLocation.z - oldZ) > .04 && ABS(currentLocation.z - oldZ) < 100.0;
        PSLog(@"parseGCode", PSPrioLow, @"%f", ABS(currentLocation.z - oldZ));
        
        if(layerChange) {
            
            PSLog(@"parseGCode", PSPrioLow, @"New layer created at z = %f", currentLocation.z);
			isNewLayer = YES;
		}
        
	}
	
    // Reset scan of line
	[self setScanLocation:0];
    
	return isNewLayer;
}

@end


@implementation ParsedGCode

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
    
    // Off color
    _extrusionOffColor = [[[NSColor grayColor] colorWithAlphaComponent:0.6] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];

}

- (float)getTotalMachiningTime
{
    return _gCodeStatistics->totalExtrudedTime + _gCodeStatistics->totalTravelledTime;
}

- (float)getObjectWeight
{
    return (_gCodeStatistics->totalExtrudedLengthToolA + _gCodeStatistics->totalExtrudedLengthToolB) * (float)M_PI/4.f * powf(__filamentDiameter,2.f) * __averageDensity * powf(10.f,-6.f); // in g
}

- (float)getFilamentLengthToolA
{
    return _gCodeStatistics->totalExtrudedLengthToolA / 10.f ; // in cm
}

- (float)getFilamentLengthToolB
{
    return _gCodeStatistics->totalExtrudedLengthToolB / 10.f ; // in cm
}

- (NSInteger)getLayerHeight
{
    return (NSInteger)floorf(_gCodeStatistics->layerHeight * 100.f) * 10 ; // in mm
}

- (id)initWithGCodeString:(NSString*)gcode;
{
    /*
     This function parses GCODE (roughly) according to http://reprap.org/wiki/G-code
     */
    
	self = [super init];
	if(self)
	{
        _gCodeStatistics = [[GCodeStatistics alloc] init];
        
        
		NSArray* untrimmedLines = [gcode componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
		NSCharacterSet* whiteSpaceSet = [NSCharacterSet whitespaceCharacterSet];
			
		_extrusionWidth = 0.;
		__block NSInteger extrusionNumber = 0;
		
		NSMutableArray* panes = [NSMutableArray array];
		__block NSMutableArray* currentPane = nil;
		__block Vector3* currentLocation = [[Vector3 alloc] initVectorWithX:0. Y:0. Z:0.];
		__block Vector3* highCorner = [[Vector3 alloc] initVectorWithX:-FLT_MAX Y:-FLT_MAX Z:-FLT_MAX];
		__block Vector3* lowCorner = [[Vector3 alloc] initVectorWithX:FLT_MAX Y:FLT_MAX Z:FLT_MAX];
		
        NSCharacterSet* commandCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"GMT0123456789"];

		// Scan each line.
		[untrimmedLines enumerateObjectsUsingBlock:^(id untrimmedLine, NSUInteger idx, BOOL *stop) {
            NSScanner* lineScanner = [NSScanner scannerWithString:[untrimmedLine stringByTrimmingCharactersInSet:whiteSpaceSet]];
            
            float oldZ = currentLocation.z;
            
            if ([lineScanner isNewLayerWithCurrentLocation:currentLocation]){
                
				currentPane = [NSMutableArray array];
				[panes addObject:currentPane];
                _gCodeStatistics->layersCount++;
                
                // If height has not been found yet
                if (_gCodeStatistics->layerHeight == 0.0){
                    
                    float theoreticalHeight = roundf((currentLocation.z - oldZ)*100)/100;
                    
                    if (theoreticalHeight > 0 && theoreticalHeight < 1){ // We assume that a layer is less than 1mm thick
                        _gCodeStatistics->layerHeight = theoreticalHeight;
                    }
		
                }
                
            }
            
            // Look for GCode commands starting with G, M or T.
            NSString* command = nil;
            if ([lineScanner scanCharactersFromSet:commandCharacterSet intoString:&command]) {
                if([command isEqualToString:@"M104"] /*|| [command isEqualToString:@"M109"]*/ || [command isEqualToString:@"G10"]) {
                    // M104: Set Extruder Temperature
                    // Set the temperature of the current extruder and return control to the host immediately
                    // (i.e. before that temperature has been reached by the extruder). See also M109 that does the same but waits.
                    // /!\ This is deprecated because temperatures should be set using the G10 and T commands.
                    
                    // M109
                    // Makerware uses M109 for the heating bed ...
                    
                    // G10
                    // Example: G10 P3 X17.8 Y-19.3 Z0.0 R140 S205
                    // This sets the offset for extrude head 3 (from the P3) to the X and Y values specified.
                    // The R value is the standby temperature in oC that will be used for the tool, and the S value is its operating temperature.

                    // Makerware puts the temperature first, skip it
                    if ([lineScanner scanString:@"S" intoString:nil]) {
                        [lineScanner scanInt:nil];
                    }
                
                    // Extract the tool index
                    if ([lineScanner scanString:@"P" intoString:nil] || [lineScanner scanString:@"T" intoString:nil]) {
                        
                        NSInteger toolIndex;
                        [lineScanner scanInteger:&toolIndex];
                        
                        BOOL previouslyUsingToolB = _gCodeStatistics->usingToolB;
                        _gCodeStatistics->usingToolB = (toolIndex >= 1);
                        
                        if (_gCodeStatistics->usingToolB == !previouslyUsingToolB)
                            _gCodeStatistics->dualExtrusion = YES;
                    }
                
                    // Done : We don't need the temperature
                
                } else if([command isEqualToString:@"G1"]) {
                    // Example: G1 X90.6 Y13.8 E22.4
                    // Go in a straight line from the current (X, Y) point to the point (90.6, 13.8),
                    // extruding material as the move happens from the current extruded length to a length of 22.4 mm.
                    
                    [lineScanner updateLocation:currentLocation];
                                     
                    [lowCorner minimizeWith:currentLocation];
                    [highCorner maximizeWith:currentLocation];
                    
                    // Update stats
                    [lineScanner updateStats:_gCodeStatistics with:currentLocation];
                    
                    // Coloring
                    if(_gCodeStatistics->extruding) {
                        if (_gCodeStatistics->dualExtrusion) {
                            if (_gCodeStatistics->usingToolB) {
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
                    
                    [currentPane addObject:[currentLocation copy]];
                
                } else if([command isEqualToString:@"G92"]) {
                    // G92: Set Position. Allows programming of absolute zero point, by reseting the current position
                    // to the values specified.
                    // Slic3r uses this to reset the extruded distance.
                    
                    // We assume that an E value appears first.
                    // Generally, it's " G92 E0 ", but in case ...
                    if ([lineScanner scanString:@"E" intoString:nil]) {
                        float currentExtrudedLength;
                        [lineScanner scanFloat:&currentExtrudedLength];
                        if (_gCodeStatistics->usingToolB) {
                            _gCodeStatistics->totalExtrudedLengthToolB += _gCodeStatistics->currentExtrudedLengthToolB;
                            _gCodeStatistics->currentExtrudedLengthToolB = currentExtrudedLength;
                        } else {
                            _gCodeStatistics->totalExtrudedLengthToolA += _gCodeStatistics->currentExtrudedLengthToolA;
                            _gCodeStatistics->currentExtrudedLengthToolA = currentExtrudedLength;
                        }
                    }
                
                } else if ([command isEqualToString:@"M135"] || [command isEqualToString:@"M108"]) {
                    // M135: tool switch.
                    // M108: Set Extruder Speed.
                    // Both are used in practice to swith the current extruder.
                    // M135 is used by Makerware, M108 is used by Replicator G.
                    if ([lineScanner scanString:@"T" intoString:nil]) {
                        NSInteger toolIndex;
                        [lineScanner scanInteger:&toolIndex];
                        
                        // BOOL previouslyUsingToolB = statistics->usingToolB;
                        _gCodeStatistics->usingToolB = (toolIndex >= 1);
                        
                        /*
                        // The tool changed : we're sure we have a double extrusion print
                        if (_gCodeStatistics->usingToolB == !previouslyUsingToolB) {
                            _gCodeStatistics->dualExtrusion = YES;
                        }
                         */
                    }
                } else if ([command isEqualToString:@"T0"]) {
                    // T0: Switch to the first extruder.
                    // Slic3r and KISSlicer use this to switch the current extruder.
                    
                    // BOOL previouslyUsingToolB = statistics->usingToolB;
                    _gCodeStatistics->usingToolB =  NO;
                    
                    /*
                    // The tool changed : we're sure we have a double extrusion print
                    if (_gCodeStatistics->usingToolB == !previouslyUsingToolB) {
                        _gCodeStatistics->dualExtrusion = YES;
                    }
                     */
                    
                } else if ([command isEqualToString:@"T1"]) {
                    // T1: Switch to the second extruder.
                    // Slic3r and KISSlicer use this to switch the current extruder.
                    
                    // BOOL previouslyUsingToolB = statistics->usingToolB;
                    _gCodeStatistics->usingToolB =  YES;
                    
                    /*
                    // The tool changed : we're sure we have a double extrusion print
                    if (_gCodeStatistics->usingToolB == !previouslyUsingToolB) {
                        _gCodeStatistics->dualExtrusion = YES;
                    }
                     */
                }
            } // if ([lineScanner scanCharactersFromSet:commandCharacterSet intoString:&command])
		}];
        
        _panes = panes;
        
        _gCodeStatistics->totalExtrudedLengthToolA += _gCodeStatistics->currentExtrudedLengthToolA;
        _gCodeStatistics->totalExtrudedLengthToolB += _gCodeStatistics->currentExtrudedLengthToolB;
        
        // Correct extruded lengths for extruder primes
        _gCodeStatistics->totalExtrudedLengthToolA = _gCodeStatistics->dualExtrusion?_gCodeStatistics->totalExtrudedLengthToolA:(_gCodeStatistics->totalExtrudedLengthToolA>_gCodeStatistics->totalExtrudedLengthToolB?_gCodeStatistics->totalExtrudedLengthToolA:0);
        _gCodeStatistics->totalExtrudedLengthToolB = _gCodeStatistics->dualExtrusion?_gCodeStatistics->totalExtrudedLengthToolB:(_gCodeStatistics->totalExtrudedLengthToolB>_gCodeStatistics->totalExtrudedLengthToolA?_gCodeStatistics->totalExtrudedLengthToolB:0);
        
        // Correct height:
        highCorner.z = _gCodeStatistics->layersCount * _gCodeStatistics->layerHeight;
        
		_cornerLow = lowCorner;
		_cornerHigh = highCorner;
		_extrusionWidth = _gCodeStatistics->layerHeight;

        
        
        PSLog(@"parseGCode", PSPrioNormal, @" High corner: %@", _cornerHigh);
        PSLog(@"parseGCode", PSPrioNormal, @" Low corner: %@", _cornerLow);
        PSLog(@"parseGCode", PSPrioNormal, @" Total Extruded length Tool A (mm): %f", _gCodeStatistics->totalExtrudedLengthToolA);
        PSLog(@"parseGCode", PSPrioNormal, @" Total Extruded length Tool B (mm): %f", _gCodeStatistics->totalExtrudedLengthToolB);
        PSLog(@"parseGCode", PSPrioNormal, @" Using dual extrusion: %@", _gCodeStatistics->dualExtrusion ? @"Yes" : @"No");
        PSLog(@"parseGCode", PSPrioNormal, @" Grams : %f", (_gCodeStatistics->totalExtrudedLengthToolA + _gCodeStatistics->totalExtrudedLengthToolB) * (float)M_PI/4.f * powf(1.75f,2.f) * 1050.f * powf(10.f,-6.f));
        
        PSLog(@"parseGCode", PSPrioNormal, @" G1 Lines : %d",_gCodeStatistics->movementLinesCount );
        
        PSLog(@"parseGCode", PSPrioNormal, @" Layer Height : %f",_gCodeStatistics->layerHeight );
        PSLog(@"parseGCode", PSPrioNormal, @" Layer Count : %d",_gCodeStatistics->layersCount );
        PSLog(@"parseGCode", PSPrioNormal, @" Height Corrected (mm) : %f",_gCodeStatistics->layersCount*_gCodeStatistics->layerHeight );
        
        PSLog(@"parseGCode", PSPrioNormal, @" Total Extruded time (min): %f", _gCodeStatistics->totalExtrudedTime);
        PSLog(@"parseGCode", PSPrioNormal, @" Total Travelled time (min): %f", _gCodeStatistics->totalTravelledTime);
        
        PSLog(@"parseGCode", PSPrioNormal, @" Total Extruded distance (mm): %f", _gCodeStatistics->totalExtrudedDistance);
        PSLog(@"parseGCode", PSPrioNormal, @" Total Travelled distance (mm): %f", _gCodeStatistics->totalTravelledDistance);
	}
    
	return self;

}
@end
