//
//  P3DParsedGCodePrinter.m
//  P3DCore
//
//  Created by Eberhard Rensch on 16.12.13.
//  Copyright (c) 2013 Pleasant Software. All rights reserved.
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

#import "P3DParsedGCodePrinter.h"
#import "NSArray+GCode.h"
#import "GCodeStatistics.h"
#import "P3DPrinterDriverBase.h"
#import "PSLog.h"

const float __filamentDiameterBias = 0.07; // bias (mm)
const float __averageDensity = 1050; // kg.m-3
const float  __averageAccelerationEfficiencyWhenTravelling = 0.2; // ratio : theoricalSpeed * averageAccelEfficiency = realSpeed along an average path
const float  __averageAccelerationEfficiencyWhenExtruding = 0.6; // ratio : theoricalSpeed * averageAccelEfficiency = realSpeed along an average path

static inline void fillVertex(GLfloat* vertex, NSColor* color, Vector3* location) {
    vertex[0] = color.redComponent;
    vertex[1] = color.greenComponent;
    vertex[2] = color.blueComponent;
    vertex[3] = color.alphaComponent;
    vertex[4] = location.x;
    vertex[5] = location.y;
    vertex[6] = location.z;
    vertex[7] = 0.f;
}

static inline void fillVertexColor(GLfloat* vertex, NSColor* color) {
    vertex[0] = color.redComponent;
    vertex[1] = color.greenComponent;
    vertex[2] = color.blueComponent;
    vertex[3] = color.alphaComponent;
}

@interface NSScanner (ParseGCode)
- (BOOL)updateLocation:(Vector3*)currentLocation;
- (void)updateStats:(GCodeStatistics*)GCODE_stats with:(Vector3*)currentLocation;
- (BOOL)isNewLayerWithCurrentLocation:(Vector3*)currentLocation;
@end

@implementation NSScanner (ParseGCode)
- (BOOL)updateLocation:(Vector3*)currentLocation
{
    BOOL validLocation = NO;
	float value;
	if([self scanString:@"X" intoString:nil])
	{
		[self scanFloat:&value];
		currentLocation.x = value;
        validLocation = YES;
	}
	if([self scanString:@"Y" intoString:nil])
	{
		[self scanFloat:&value];
		currentLocation.y = value;
        validLocation = YES;
	}
	if([self scanString:@"Z" intoString:nil])
	{
		[self scanFloat:&value];
		currentLocation.z = value;
        validLocation = YES;
	}
    
    return validLocation;
}

- (void)updateStats:(GCodeStatistics*)gCodeStatistics with:(Vector3*)currentLocation
{
    PSLog(@"parseGCode", PSPrioLow, @" ## Previous : %@", [gCodeStatistics.currentLocation description]);
    PSLog(@"parseGCode", PSPrioLow, @" ## Current : %@", [currentLocation description]);
    
    // Travelling
    Vector3* travelVector = [currentLocation sub:gCodeStatistics.currentLocation];
    [gCodeStatistics.currentLocation setToVector3:currentLocation];
    gCodeStatistics.movementLinesCount++;
	
    // == Look for a feedrate FIRST ==
    if([self scanString:@"F" intoString:nil]) {
        float value;
		[self scanFloat:&value]; // mm/min
        gCodeStatistics.currentFeedRate = value;
	}
    
    // == Look for an extrusion length ==
    // E or A is the first extruder head ("ToolA")
    // B is the other extruder ("ToolB")
    float currentExtrudedLength;
    
    if([self scanString:@"E" intoString:nil] || [self scanString:@"A" intoString:nil]) {
        
        // We're using ToolA for this move
        [self scanFloat:&currentExtrudedLength];
        BOOL extruding = (currentExtrudedLength > gCodeStatistics.currentExtrudedLengthToolA);
        if(extruding != gCodeStatistics.extruding || (extruding && gCodeStatistics.usingToolB))
            gCodeStatistics.extrudingStateChanged=YES;
        gCodeStatistics.extruding=extruding;
        gCodeStatistics.currentExtrudedLengthToolA = currentExtrudedLength;
        gCodeStatistics.usingToolB = NO;
        
	} else if([self scanString:@"B" intoString:nil]) {
        
        // We're using ToolB for this move
        [self scanFloat:&currentExtrudedLength];
        BOOL extruding = (currentExtrudedLength > gCodeStatistics.currentExtrudedLengthToolB);
        if(extruding != gCodeStatistics.extruding || (extruding && !gCodeStatistics.usingToolB))
            gCodeStatistics.extrudingStateChanged=YES;
        gCodeStatistics.extruding=extruding;
        gCodeStatistics.currentExtrudedLengthToolB = currentExtrudedLength;
        gCodeStatistics.usingToolB = YES;
    }
    
    float longestDistanceToMove = MAX(ABS(travelVector.x), ABS(travelVector.y)); // mm
    float cartesianDistance = [travelVector abs]; // mm
    
    // == Calculating time taken to move or extrude ==
    if (gCodeStatistics.extruding) {
        
        // Extrusion in progress, let's calculate the time taken
        //PSLog(@"parseGCode", PSPrioLow, @"Extruding %f  > %f", currentExtrudedLength, previousExtrudedLength);
        gCodeStatistics.totalExtrudedDistance += cartesianDistance; // mm
        gCodeStatistics.totalExtrudedTime += (longestDistanceToMove / (gCodeStatistics.currentFeedRate *  __averageAccelerationEfficiencyWhenExtruding)); // min
    } else {
        
        // We're only travelling, let's calculate the time taken
        PSLog(@"parseGCode", PSPrioLow, @"Travelling");
        gCodeStatistics.totalTravelledDistance += cartesianDistance; // mm
        gCodeStatistics.totalTravelledTime += (longestDistanceToMove / (gCodeStatistics.currentFeedRate * __averageAccelerationEfficiencyWhenTravelling)); // min
    }
    
    PSLog(@"parseGCode", PSPrioLow, @" ## tel= %f; tet= %f; ttt=%f; D=%f; fr=%f; extr=%d", gCodeStatistics.currentExtrudedLengthToolA, gCodeStatistics.totalExtrudedTime, gCodeStatistics.totalTravelledTime, longestDistanceToMove, gCodeStatistics.currentFeedRate, gCodeStatistics.extruding);
    
    [self setScanLocation:0];
}

- (BOOL)isNewLayerWithCurrentLocation:(Vector3*)currentLocation
{
    // TODO: Some slicers actually announce new layers in the comments.
    // If present, recognizing those annotations might be a better way to determine the start of a new layer
    // The current code could be still available as fallback

    BOOL isNewLayer = NO;
    
    if([self scanString:@"G1" intoString:nil]) {
        
        float oldZ = currentLocation.z;
		if([self updateLocation:currentLocation]) {
            BOOL layerChange = ABS(currentLocation.z - oldZ) > .04 && ABS(currentLocation.z - oldZ) < 100.0;
            PSLog(@"parseGCode", PSPrioLow, @"%f", ABS(currentLocation.z - oldZ));
            
            if(layerChange) {
                
                PSLog(@"parseGCode", PSPrioLow, @"New layer created at z = %f", currentLocation.z);
                isNewLayer = YES;
            }
        }
	}
	
    // Reset scan of line
	[self setScanLocation:0];
    
	return isNewLayer;
}
@end

@interface P3DParsedGCodePrinter ()
@property (readonly) float filamentDiameter;
@end

@implementation P3DParsedGCodePrinter
@dynamic objectWeight, filamentLengthToolA, filamentLengthToolB, layerHeight;

static NSArray* _extrusionColors_A=nil;
static NSArray* _extrusionColors_B=nil;
static NSColor* _extrusionOffColor=nil;
+ (void)initialize
{
    _extrusionColors_A = [NSArray arrayWithObjects:
                        [[NSColor colorWithCalibratedRed:0.904 green:0.538 blue:0.140 alpha:1.000] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                        [[NSColor colorWithCalibratedRed:0.928 green:0.953 blue:0.157 alpha:1.000] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                        [[NSColor colorWithCalibratedRed:0.672 green:0.888 blue:0.138 alpha:1.000] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                        [[NSColor colorWithCalibratedRed:0.913 green:0.742 blue:0.147 alpha:1.000] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                        [[NSColor colorWithCalibratedRed:0.218 green:0.801 blue:0.115 alpha:1.000] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                        [[NSColor colorWithCalibratedRed:0.770 green:0.289 blue:0.121 alpha:1.000] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                        nil];
    
    
    _extrusionColors_B = [NSArray arrayWithObjects:
                          [[NSColor colorWithCalibratedRed:0.214 green:0.687 blue:0.741 alpha:1.000] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                          [[NSColor colorWithCalibratedRed:0.167 green:0.319 blue:0.741 alpha:1.000] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                          [[NSColor colorWithCalibratedRed:0.749 green:0.000 blue:0.517 alpha:1.000] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                          [[NSColor colorWithCalibratedRed:0.431 green:0.000 blue:0.713 alpha:1.000] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                          [[NSColor colorWithCalibratedRed:0.749 green:0.000 blue:0.517 alpha:1.000] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                          [[NSColor colorWithCalibratedRed:0.871 green:0.000 blue:0.148 alpha:1.000] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                          nil];
    
    // Off color
    _extrusionOffColor = [[[NSColor grayColor] colorWithAlphaComponent:kRapidMoveAlpha] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
    
}

- (id)initWithGCodeString:(NSString*)gcode printer:(P3DPrinterDriverBase*)currentPrinter
{
	self = [super initWithGCodeString:gcode printer:currentPrinter];
	if(self) {
        _gCodeStatistics = [[GCodeStatistics alloc] init];
        [self parseGCode:gcode];
	}
    
	return self;
    
}

#pragma mark - Service

/*
 This function parses GCODE (roughly) according to http://reprap.org/wiki/G-code
 */


- (void)parseGCode:(NSString*)gcode
{
    _parsingErrors = nil;

    _extrusionWidth = 0.;
    NSInteger extrusionNumber_A = 0;
    NSInteger extrusionNumber_B = 0;

    Vector3* currentLocation = [[Vector3 alloc] initVectorWithX:0. Y:0. Z:-FLT_MAX];
    Vector3* highCorner = [[Vector3 alloc] initVectorWithX:-FLT_MAX Y:-FLT_MAX Z:-FLT_MAX];
    Vector3* lowCorner = [[Vector3 alloc] initVectorWithX:FLT_MAX Y:FLT_MAX Z:FLT_MAX];
    
    NSArray* untrimmedLines = [[gcode uppercaseString] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSCharacterSet* whiteSpaceSet = [NSCharacterSet whitespaceCharacterSet];
    
    _vertexStride = sizeof(GLfloat)*8; // RGBA + XYZW (W always 0)
    NSMutableData* vertexBuffer = [NSMutableData dataWithCapacity:untrimmedLines.count*_vertexStride];
    
    NSColor* currentColor = _extrusionOffColor;
    
    NSMutableArray* paneIndex = [NSMutableArray array];
    
    NSInteger vertexCount = 0;
    
    float minLayerZ=FLT_MAX;
    float maxLayerZ=-FLT_MAX;
    
    GLfloat vertex[8];
    BOOL validVertex = NO;
    
    // Scan each line.
    NSCharacterSet* commandCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"GMT0123456789"];
    for(NSString* untrimmedLine in untrimmedLines) {
        NSScanner* lineScanner = [NSScanner scannerWithString:[untrimmedLine stringByTrimmingCharactersInSet:whiteSpaceSet]];
        //NSLog(@"Scan: %@", lineScanner.string);
        float oldZ = currentLocation.z;
        
        // Check for new Layer
        if([lineScanner isNewLayerWithCurrentLocation:currentLocation]) { // TODO: isNewLayerWithCurrentLocation changes currentLocation
            NSInteger lastVertexIndex=-1;
            
            // Set the min/max layerZ for the last pane:
            if(paneIndex.count>0) {
                lastVertexIndex = [paneIndex[paneIndex.count-1][kFirstVertexIndex] integerValue];
                
                paneIndex[paneIndex.count-1] = @{
                                             kFirstVertexIndex: @(lastVertexIndex),
                                             kMinLayerZ: @(minLayerZ),
                                             kMaxLayerZ: @(maxLayerZ)
                                            };
            }
            
            if(vertexCount>lastVertexIndex) {
                [paneIndex addObject:@{ kFirstVertexIndex: @(vertexCount) }];

                minLayerZ=FLT_MAX;
                maxLayerZ=-FLT_MAX;
                
//                extrusionNumber_A=0;
//                extrusionNumber_B=0;
                
                validVertex = NO;
                
                _gCodeStatistics.layersCount++;
                
                // If height has not been found yet
                if (_gCodeStatistics.layerHeight == 0.0) {
                    float theoreticalHeight = roundf((currentLocation.z - oldZ)*100)/100;
                    if (theoreticalHeight > 0.f && theoreticalHeight < 1.f) { // We assume that a layer is less than 1mm thick
                        _gCodeStatistics.layerHeight = theoreticalHeight;
                    }
                }
            }
        }
        
        // Look for GCode commands starting with G, M or T.
        NSString* command = nil;
        if([lineScanner scanCharactersFromSet:commandCharacterSet intoString:&command]) {
            
            if([command isEqualToString:@"M104"] /*|| [command isEqualToString:@"M109"]*/ || [command isEqualToString:@"G10"]) {
                // M104: Set Extruder Temperature
                // Set the temperature of the current extruder and return control to the host immediately
                // (i.e. before that temperature has been reached by the extruder). See also M109 that does the same but waits.
                // /!\ This is deprecated because temperatures should be set using the G10 and T commands.
                
                // M109
                // Makerware uses M109 for the heating bed ...
                
                // G10
                // Example: G10 P3 X17.8 Y-19.3 Z0.0 R140 S205
                // This sets the offset for extruder head 3 (from the P3) to the X and Y values specified.
                // The R value is the standby temperature in °C that will be used for the tool, and the S value is its operating temperature.
                
                // Makerware puts the temperature first, skip it
                if ([lineScanner scanString:@"S" intoString:nil]) {
                    [lineScanner scanInt:nil];
                }
                
                // Extract the tool index
                if ([lineScanner scanString:@"P" intoString:nil] || [lineScanner scanString:@"T" intoString:nil]) {
                    
                    NSInteger toolIndex;
                    [lineScanner scanInteger:&toolIndex];
                    
                    BOOL usingToolB = (toolIndex >= 1);
                    if(_gCodeStatistics.usingToolB != usingToolB)
                        _gCodeStatistics.dualExtrusion = YES;
                    _gCodeStatistics.usingToolB=usingToolB;
                }
                
                // Done : We don't need the temperature
                
            } else if([command isEqualToString:@"G1"]) {
                // Example: G1 X90.6 Y13.8 E22.4
                // Go in a straight line from the current (X, Y) point to the point (90.6, 13.8),
                // extruding material as the move happens from the current extruded length to a length of 22.4 mm.
                
                BOOL validLocation = [lineScanner updateLocation:currentLocation];
                
                [lineScanner updateStats:_gCodeStatistics with:currentLocation];
                
                // Coloring
                if(_gCodeStatistics.extrudingStateChanged) {
                    if(_gCodeStatistics.extruding) {
                        if (_gCodeStatistics.usingToolB)
                            currentColor = [_extrusionColors_B objectAtIndex:extrusionNumber_B%[_extrusionColors_B count]];
                        else
                            currentColor = [_extrusionColors_A objectAtIndex:extrusionNumber_A%[_extrusionColors_A count]];
                        
                    } else {
                        if (_gCodeStatistics.usingToolB)
                            extrusionNumber_B++;
                        else
                            extrusionNumber_A++;
                        currentColor = _extrusionOffColor;
                        if(validVertex)
                            fillVertexColor(vertex, currentColor); // No color blending in extrusionOff lines
                        
                    }
                    _gCodeStatistics.extrudingStateChanged=NO;
                }
                
                if(validLocation) {
                    if(validVertex) {
                        if(_currentPrinter || vertex[3]!=kRapidMoveAlpha)  {
                            // Else we're in Quicklook where no printer object is provided (and we don't want offExtrusions rendered)
                            [lowCorner minimizeWith:currentLocation];
                            [highCorner maximizeWith:currentLocation];
                            
                            minLayerZ = MIN(minLayerZ, currentLocation.z);
                            maxLayerZ = MAX(minLayerZ, currentLocation.z);
                            
                            [vertexBuffer appendBytes:vertex length:_vertexStride];
                            fillVertex(vertex, currentColor, currentLocation);
                            [vertexBuffer appendBytes:vertex length:_vertexStride];
                            vertexCount+=2;
                        } else {
                            fillVertex(vertex, currentColor, currentLocation);
                        }
                    } else {
                        fillVertex(vertex, currentColor, currentLocation);
                        validVertex = YES;
                    }
                }
            } else if([command isEqualToString:@"M101"]) { // Legacy 3D Printing code: Extruder ON
                if(!_gCodeStatistics.extruding) {
                    if (_gCodeStatistics.usingToolB)
                        currentColor = [_extrusionColors_B objectAtIndex:extrusionNumber_B%[_extrusionColors_B count]];
                    else
                        currentColor = [_extrusionColors_A objectAtIndex:extrusionNumber_A%[_extrusionColors_A count]];
                }
                _gCodeStatistics.extruding = YES;
            } else if([command isEqualToString:@"M103"]) { // Legacy 3D Printing code: Extruder OFF
                if(_gCodeStatistics.extruding) {
                    if (_gCodeStatistics.usingToolB)
                        extrusionNumber_B++;
                    else
                        extrusionNumber_A++;
                    currentColor = _extrusionOffColor;
                    if(validVertex)
                        fillVertexColor(vertex, currentColor); // No color blending in extrusionOff lines
                }
                _gCodeStatistics.extruding = NO;
            } else if([command isEqualToString:@"G92"]) {
                // G92: Set Position. Allows programming of absolute zero point, by reseting the current position
                // to the values specified.
                // Slic3r uses this to reset the extruded distance.
                
                [lineScanner updateLocation:currentLocation];
                
                // We assume that an E value appears first.
                // Generally, it's " G92 E0 ", but in case ...
                if ([lineScanner scanString:@"E" intoString:nil]) {
                    float currentExtrudedLength;
                    [lineScanner scanFloat:&currentExtrudedLength];
                    if (_gCodeStatistics.usingToolB) {
                        _gCodeStatistics.totalExtrudedLengthToolB += _gCodeStatistics.currentExtrudedLengthToolB;
                        _gCodeStatistics.currentExtrudedLengthToolB = currentExtrudedLength;
                    } else {
                        _gCodeStatistics.totalExtrudedLengthToolA += _gCodeStatistics.currentExtrudedLengthToolA;
                        _gCodeStatistics.currentExtrudedLengthToolA = currentExtrudedLength;
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
                    _gCodeStatistics.usingToolB = (toolIndex >= 1);
                    
                    /*
                     // The tool changed : we're sure we have a double extrusion print
                     if (_gCodeStatistics.usingToolB == !previouslyUsingToolB) {
                     _gCodeStatistics.dualExtrusion = YES;
                     }
                     */
                }
            } else if ([command isEqualToString:@"T0"]) {
                // T0: Switch to the first extruder.
                // Slic3r and KISSlicer use this to switch the current extruder.
                
                // BOOL previouslyUsingToolB = statistics->usingToolB;
                _gCodeStatistics.usingToolB =  NO;
                
                /*
                 // The tool changed : we're sure we have a double extrusion print
                 if (_gCodeStatistics.usingToolB == !previouslyUsingToolB) {
                 _gCodeStatistics.dualExtrusion = YES;
                 }
                 */
                
            } else if ([command isEqualToString:@"T1"]) {
                // T1: Switch to the second extruder.
                // Slic3r and KISSlicer use this to switch the current extruder.
                
                // BOOL previouslyUsingToolB = statistics->usingToolB;
                _gCodeStatistics.usingToolB =  YES;
                
                /*
                 // The tool changed : we're sure we have a double extrusion print
                 if (_gCodeStatistics.usingToolB == !previouslyUsingToolB) {
                 _gCodeStatistics.dualExtrusion = YES;
                 }
                 */
            }
        } // if ([lineScanner scanCharactersFromSet:commandCharacterSet intoString:&command])
    }
    
    if(paneIndex.count>0)
        paneIndex[paneIndex.count-1] = @{
                                     kFirstVertexIndex: paneIndex[paneIndex.count-1][kFirstVertexIndex],
                                     kMinLayerZ: @(minLayerZ),
                                     kMaxLayerZ: @(maxLayerZ)
                                     };
    _vertexIndex = paneIndex;
    _vertexBuffer = vertexBuffer;
    _vertexCount = vertexCount;
    
    _gCodeStatistics.totalExtrudedLengthToolA += _gCodeStatistics.currentExtrudedLengthToolA;
    _gCodeStatistics.totalExtrudedLengthToolB += _gCodeStatistics.currentExtrudedLengthToolB;
    
    // Correct extruded lengths for extruder primes
    _gCodeStatistics.totalExtrudedLengthToolA = _gCodeStatistics.dualExtrusion?_gCodeStatistics.totalExtrudedLengthToolA:(_gCodeStatistics.totalExtrudedLengthToolA>_gCodeStatistics.totalExtrudedLengthToolB?_gCodeStatistics.totalExtrudedLengthToolA:0);
    _gCodeStatistics.totalExtrudedLengthToolB = _gCodeStatistics.dualExtrusion?_gCodeStatistics.totalExtrudedLengthToolB:(_gCodeStatistics.totalExtrudedLengthToolB>_gCodeStatistics.totalExtrudedLengthToolA?_gCodeStatistics.totalExtrudedLengthToolB:0);
    
    // Correct height:
    highCorner.z = _gCodeStatistics.layersCount * _gCodeStatistics.layerHeight;
    
    _cornerLow = lowCorner;
    _cornerHigh = highCorner;
    _extrusionWidth = _gCodeStatistics.layerHeight;
    
    
    
    PSLog(@"parseGCode", PSPrioNormal, @" High corner: %@", _cornerHigh);
    PSLog(@"parseGCode", PSPrioNormal, @" Low corner: %@", _cornerLow);
    PSLog(@"parseGCode", PSPrioNormal, @" Total Extruded length Tool A (mm): %f", _gCodeStatistics.totalExtrudedLengthToolA);
    PSLog(@"parseGCode", PSPrioNormal, @" Total Extruded length Tool B (mm): %f", _gCodeStatistics.totalExtrudedLengthToolB);
    PSLog(@"parseGCode", PSPrioNormal, @" Using dual extrusion: %@", _gCodeStatistics.dualExtrusion ? @"Yes" : @"No");
    PSLog(@"parseGCode", PSPrioNormal, @" Grams : %f", (_gCodeStatistics.totalExtrudedLengthToolA + _gCodeStatistics.totalExtrudedLengthToolB) * (float)M_PI/4.f * powf(1.75f,2.f) * 1050.f * powf(10.f,-6.f));
    
    PSLog(@"parseGCode", PSPrioNormal, @" G1 Lines : %d",_gCodeStatistics.movementLinesCount );
    
    PSLog(@"parseGCode", PSPrioNormal, @" Layer Height : %f",_gCodeStatistics.layerHeight );
    PSLog(@"parseGCode", PSPrioNormal, @" Layer Count : %d",_gCodeStatistics.layersCount );
    PSLog(@"parseGCode", PSPrioNormal, @" Height Corrected (mm) : %f",_gCodeStatistics.layersCount*_gCodeStatistics.layerHeight );
    
    PSLog(@"parseGCode", PSPrioNormal, @" Total Extruded time (min): %f", _gCodeStatistics.totalExtrudedTime);
    PSLog(@"parseGCode", PSPrioNormal, @" Total Travelled time (min): %f", _gCodeStatistics.totalTravelledTime);
    
    PSLog(@"parseGCode", PSPrioNormal, @" Total Extruded distance (mm): %f", _gCodeStatistics.totalExtrudedDistance);
    PSLog(@"parseGCode", PSPrioNormal, @" Total Travelled distance (mm): %f", _gCodeStatistics.totalTravelledDistance);
}

- (float)filamentDiameter
{
    return _currentPrinter.filamentDiameter+__filamentDiameterBias;
}

#pragma mark - GUI Bindings

- (float)objectWeight
{
    return (_gCodeStatistics.totalExtrudedLengthToolA + _gCodeStatistics.totalExtrudedLengthToolB) * (float)M_PI * powf(self.filamentDiameter/2.f,2.f) * __averageDensity * powf(10.f,-6.f); // in g
}

- (float)filamentLengthToolA
{
    return _gCodeStatistics.totalExtrudedLengthToolA / 10.f ; // in cm
}

- (float)filamentLengthToolB
{
    return _gCodeStatistics.totalExtrudedLengthToolB / 10.f ; // in cm
}

- (NSInteger)layerHeight
{
    return (NSInteger)floorf(_gCodeStatistics.layerHeight * 100.f) * 10 ; // in µm
}

@end
