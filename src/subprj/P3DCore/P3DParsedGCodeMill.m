//
//  P3DParsedGCodeMill.m
//  P3DCore
//
//  Created by Eberhard Rensch on 17.12.13.
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

/*
 *This Gcode parser is based on the PleasantMill firmware
 * 
 * "Pleasant Mill" Firmware
 * Copyright (c) 2011 Eberhard Rensch, Pleasant Software, Offenburg
 * All rights reserved.
 * http://pleasantsoftware.com/developer/3d/pleasant-mill/
 *
 *  Based on the RepRap GCode interpreter.
 *  see http://www.reprap.org
 *
 *  IMPORTANT
 *	Before changing this interpreter,read this page:
 *	http://objects.reprap.org/wiki/Mendel_User_Manual:_RepRapGCodes
 *
 */

#import "P3DParsedGCodeMill.h"

enum
{
	GCODE_G,
	GCODE_M,
	GCODE_P,
	GCODE_X,
	GCODE_Y,
	GCODE_Z,
	GCODE_I,
	GCODE_N,
	GCODE_CHECKSUM,
	GCODE_F,
	GCODE_S,
	GCODE_Q,
	GCODE_R,
	GCODE_E,
	GCODE_T,
	GCODE_J,
	GCODE_A,
	GCODE_B,
	GCODE_L,
	GCODE_COUNT
};

enum {
    kCoordX,
    kCoordY,
    kCoordZ,
    kCoordA,
    kCoordB,
    kCoordF,
    kCoordCount
};

#define kMaxGCommands 5

#pragma mark - Static Helper Functions

static inline void fillVertex(GLfloat* vertex, NSColor* color, Vector3* location, Vector3* localZeroOffset) {
    vertex[0] = color.redComponent;
    vertex[1] = color.greenComponent;
    vertex[2] = color.blueComponent;
    vertex[3] = color.alphaComponent;
    vertex[4] = location.x+localZeroOffset.x;
    vertex[5] = location.y+localZeroOffset.y;
    vertex[6] = location.z+localZeroOffset.z;
    vertex[7] = 0.f;
}

static inline void fillVertexLocation(GLfloat* vertex, Vector3* location, Vector3* localZeroOffset) {
    vertex[4] = location.x+localZeroOffset.x;
    vertex[5] = location.y+localZeroOffset.y;
    vertex[6] = location.z+localZeroOffset.z;
}

#pragma mark - Vector6 Helper Class
@interface Vector6 : Vector3
@property (assign) float a;
@property (assign) float b;
@property (assign) float f;

@end

@implementation Vector6
- (id)initVectorWithX:(float)x Y:(float)y Z:(float)z A:(float)a B:(float)b F:(float)f
{
    self = [super initVectorWithX:x Y:y Z:z];
    if (self) {
        _a=a;
        _b=b;
        _f=f;
    }
    return self;
}
- (Vector6*)copyWithZone:(NSZone *)zone
{
	return [[Vector6 alloc] initVectorWithX:self.x Y:self.y Z:self.z A:_a B:_b F:_f];
}

- (Vector3*)cartesianVector
{
    return super.self;
}
@end

#pragma mark - P3DParsedGCodeMill

@implementation P3DParsedGCodeMill
{
    BOOL _seen[GCODE_COUNT]; // More than 16 GCodes, a bitfield won't do
    
    NSInteger _GIndex;
    NSInteger _G[kMaxGCommands];
    NSInteger _M;
    NSInteger _T;
    float _P;
    float _X;
    float _Y;
    float _Z;
    float _A;
    float _B;
    float _I;
    float _J;
    float _F;
    float _S;
    float _R;
    float _Q;
    NSInteger _L;
    NSInteger _Checksum;
    NSInteger _N;
    NSInteger _LastLineNrProcessed;
    
    /* keep track of the last G code - this is the command mode to use
     * if there is no command in the current string
     */
    NSInteger _last_gcode_g;

    NSCharacterSet* _controlCharacterSet;
    NSCharacterSet* _commandCodeSet;
    
    NSMutableData* _workVertexBuffer;
    NSInteger _workVertexCount;
    NSMutableArray* _workTimeIndex;
    NSTimeInterval _workTime;
    NSTimeInterval _lastIndexedTime;
    
    float _minZ;
    float _maxZ;
    
    // Modelling the Mill
    Vector6* _machinePosition;
    Vector6* _localZeroOffset;
    
    BOOL _machineAbsolutePositioningMode;
    BOOL _machineMetricUnits;
    BOOL _machineRetractMode;
    float _machineRectractingHeight;
    float _machineClearanceIncrement;
    float _machineStickyQ;
    float _machineStickyP;
    NSInteger _machineCurrentTool;
}

static NSArray* _toolPathColor=nil;
static NSColor* _fastMoveColor=nil;
+ (void)initialize
{
    _toolPathColor = [NSArray arrayWithObjects:
                          [[NSColor colorWithCalibratedRed:0.928 green:0.953 blue:0.157 alpha:1.000] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                          [[NSColor colorWithCalibratedRed:0.672 green:0.888 blue:0.138 alpha:1.000] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                          [[NSColor colorWithCalibratedRed:0.904 green:0.538 blue:0.140 alpha:1.000] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                          [[NSColor colorWithCalibratedRed:0.913 green:0.742 blue:0.147 alpha:1.000] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                          [[NSColor colorWithCalibratedRed:0.218 green:0.801 blue:0.115 alpha:1.000] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                          [[NSColor colorWithCalibratedRed:0.770 green:0.289 blue:0.121 alpha:1.000] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                          [[NSColor colorWithCalibratedRed:0.214 green:0.687 blue:0.741 alpha:1.000] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                          [[NSColor colorWithCalibratedRed:0.167 green:0.319 blue:0.741 alpha:1.000] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                          [[NSColor colorWithCalibratedRed:0.749 green:0.000 blue:0.517 alpha:1.000] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                          [[NSColor colorWithCalibratedRed:0.431 green:0.000 blue:0.713 alpha:1.000] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                          [[NSColor colorWithCalibratedRed:0.749 green:0.000 blue:0.517 alpha:1.000] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                          [[NSColor colorWithCalibratedRed:0.871 green:0.000 blue:0.148 alpha:1.000] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]],
                          nil];
    
    
    _fastMoveColor = [[[NSColor grayColor] colorWithAlphaComponent:0.6] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
}


- (id)initWithGCodeString:(NSString*)gcode printer:(P3DPrinterDriverBase*)currentPrinter
{
	self = [super initWithGCodeString:gcode printer:currentPrinter];
	if(self) {
        _controlCharacterSet = [NSCharacterSet controlCharacterSet];
        _commandCodeSet = [NSCharacterSet characterSetWithCharactersInString:@"GMTLSPXYZIJFRQEABN*;("];
        _last_gcode_g = -1;
        
        
        [self parseGCode:gcode];
    }
    
	return self;
    
}

#pragma mark - Service
- (void)resetMachineModel
{
    _machinePosition = [[Vector6 alloc] init];
    _machinePosition.f = ((P3DMillDriverBase*)_currentPrinter).slowFeedrate;
    _localZeroOffset = [[Vector6 alloc] init];
    
    _machineAbsolutePositioningMode=YES;
    _machineMetricUnits=YES;
    _machineRetractMode=YES;
    _machineRectractingHeight=0.f;
    _machineClearanceIncrement=2.5f;
    _machineStickyQ=0.;
    _machineStickyP=0.;
    
    _machineCurrentTool = 0;
}

- (BOOL)seenAnything
{
	for(NSInteger i=0; i<GCODE_COUNT;i++)
		if(_seen[i])
			return YES;
	return NO;
}

- (Vector6*)fetchCartesianParameters
{
	Vector6* fp = [_machinePosition copy];
	if(_machineAbsolutePositioningMode) {
		if (_seen[GCODE_X])
			fp.x = _X*(_machineMetricUnits?1.f:25.4f);
		if (_seen[GCODE_Y])
			fp.y = _Y*(_machineMetricUnits?1.f:25.4f);
		if (_seen[GCODE_Z])
			fp.z = _Z*(_machineMetricUnits?1.f:25.4f);
		if (_seen[GCODE_E])
			fp.a = _A*(_machineMetricUnits?1.f:25.4f);
		if (_seen[GCODE_A])
			fp.a = _A*(_machineMetricUnits?1.f:25.4f);
		if (_seen[GCODE_B])
			fp.a = _B*(_machineMetricUnits?1.f:25.4f);
	} else {
		if (_seen[GCODE_X])
			fp.x += _X*(_machineMetricUnits?1.f:25.4f);
		if (_seen[GCODE_Y])
			fp.y += _Y*(_machineMetricUnits?1.f:25.4f);
		if (_seen[GCODE_Z])
			fp.z += _Z*(_machineMetricUnits?1.f:25.4f);
		if (_seen[GCODE_E])
			fp.a += _A*(_machineMetricUnits?1.f:25.4f);
		if (_seen[GCODE_A])
			fp.a += _A*(_machineMetricUnits?1.f:25.4f);
		if (_seen[GCODE_B])
			fp.b += _B*(_machineMetricUnits?1.f:25.4f);
	}
    
	// Get feedrate if supplied - feedrates are always absolute???
	if ( _seen[GCODE_F] )
		fp.f = MIN(_F*(_machineMetricUnits?1.f:25.4f), ((P3DMillDriverBase*)_currentPrinter).fastXYFeedrate);

    return fp;
}

- (NSTimeInterval)calculateTimeWithStartPosition:(Vector3*)startPosition endPosition:(Vector3*)endPosition feedRate:(float)feedrate
{
    NSTimeInterval travelTime = 0.;
    if(feedrate>0.f) {
        Vector3* travel = [endPosition sub:startPosition];
        float distance = [travel abs];

        travelTime = distance*60.f/feedrate;
    
        if(startPosition.z != endPosition.z && feedrate>((P3DMillDriverBase*)_currentPrinter).fastZFeedrate && ((P3DMillDriverBase*)_currentPrinter).fastZFeedrate>0.f) {
            distance = endPosition.z-startPosition.z;
            
            NSTimeInterval zTravelTime = distance*60.f/((P3DMillDriverBase*)_currentPrinter).fastZFeedrate;
            
            travelTime = MAX(travelTime, zTravelTime);
        }
    } else {
        [self addError:@"Invalid Feedrate (0 mm/min)"];
    }
    
    return travelTime;
}

- (void)updateTimeIndex
{
    if(_workTime-_lastIndexedTime>1.) { // Log at most every second
        _lastIndexedTime = floorf(_workTime);
        [_workTimeIndex addObject:@{ kTimestamp: @(_workTime), kFirstVertexIndex: @(_workVertexCount), kMinLayerZ: @(_minZ), kMaxLayerZ: @(_maxZ) }];
        _minZ = FLT_MAX;
        _maxZ = -FLT_MAX;
    }
}


#pragma mark - Parsing
- (void)parseGCode:(NSString*)gcode
{
    NSArray* untrimmedLines = [[gcode uppercaseString] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSCharacterSet* whiteSpaceSet = [NSCharacterSet whitespaceCharacterSet];
    
    _parsingErrors = nil;
    [self resetMachineModel];
    
    _vertexStride = sizeof(GLfloat)*8; // RGBA + XYZW (W always 0)
    _workVertexBuffer = [NSMutableData dataWithCapacity:untrimmedLines.count*_vertexStride];
    _workVertexCount = 0;
    _workTimeIndex = [NSMutableArray array];
    _workTime = 0.f;
    
    _minZ = FLT_MAX;
    _maxZ = -FLT_MAX;

    [_workTimeIndex addObject:@{ kTimestamp: @(_workTime), kFirstVertexIndex: @0 }];
    _lastIndexedTime = 0.f;
    
    for(NSString* untrimmedLine in untrimmedLines) {
        NSString* trimmedLine = [untrimmedLine stringByTrimmingCharactersInSet:whiteSpaceSet];
        
        if(trimmedLine.length>0 && ![trimmedLine hasPrefix:@"/"]) { //the character / means delete block... used for comments and stuff.
            
            //get all our parameters!
            [self parseCommand:trimmedLine];
            if([self executeCommand:trimmedLine]) {
                [self addError:@"Abort parsing the gcode: %@", trimmedLine];
                break;
            }
        }
    }
    
    _vertexBuffer = _workVertexBuffer;
    _vertexCount = _workVertexCount;
    _vertexIndex = _workTimeIndex;
    _workTimeIndex=nil;
}

- (void)parseCommand:(NSString*)commandString
{
    //PSLog(@"parseGCode", PSPrioNormal, @"Parsing: %@", commandString);

    NSScanner* lineScanner = [NSScanner scannerWithString:commandString];
    [lineScanner setCharactersToBeSkipped:_controlCharacterSet];

    // Reset Commandbuffer
    _GIndex = 0;
    bzero(_seen, GCODE_COUNT*sizeof(BOOL));
    
    BOOL endOfCommand=NO;
    while(!endOfCommand) {
        [lineScanner scanUpToCharactersFromSet:_commandCodeSet intoString:nil];
        
        NSString* commandCode=nil;
        if([lineScanner scanCharactersFromSet:_commandCodeSet intoString:&commandCode]) {
            const char* commandChars = [commandCode UTF8String];
            if(commandCode.length>1) {
                switch(commandChars[0]) {
                    case ';':
                    case '(':
                        endOfCommand=YES;
                        break;
                    default:
                        [self addError:@"Skipping invalid command code (longer than 1 character): %@", commandCode];
                }
            } else {
                switch(commandChars[0]) {
                    case ';':
                    case '(':
                        endOfCommand=YES;
                        break;
                    case 'G':
                        if(_GIndex<kMaxGCommands) {
                            if([lineScanner scanInteger:&_G[_GIndex++]])
                                _seen[GCODE_G]=YES;
                        } else {
                            [self addError:@"Too many G codes per command line (more than %d): %@", kMaxGCommands, commandString];
                            endOfCommand=YES;
                        }
                        break;
                    case 'M':
                        if([lineScanner scanInteger:&_M])
                            _seen[GCODE_M]=YES;
                        break;
                    case 'T':
                        if([lineScanner scanInteger:&_T])
                            _seen[GCODE_T]=YES;
                        break;
                    case 'L':
                        if([lineScanner scanInteger:&_L])
                            _seen[GCODE_L]=YES;
                        break;
                    case 'S':
                        if([lineScanner scanFloat:&_S])
                            _seen[GCODE_S]=YES;
                        break;
                    case 'P':
                        if([lineScanner scanFloat:&_P])
                            _seen[GCODE_P]=YES;
                        break;
                    case 'X':
                        if([lineScanner scanFloat:&_X])
                            _seen[GCODE_X]=YES;
                        break;
                    case 'Y':
                        if([lineScanner scanFloat:&_Y])
                            _seen[GCODE_Y]=YES;
                        break;
                    case 'Z':
                        if([lineScanner scanFloat:&_Z])
                            _seen[GCODE_Z]=YES;
                        break;
                    case 'I':
                        if([lineScanner scanFloat:&_I])
                            _seen[GCODE_I]=YES;
                        break;
                    case 'J':
                        if([lineScanner scanFloat:&_J])
                            _seen[GCODE_J]=YES;
                        break;
                    case 'F':
                        if([lineScanner scanFloat:&_F])
                            _seen[GCODE_F]=YES;
                        break;
                    case 'R':
                        if([lineScanner scanFloat:&_R])
                            _seen[GCODE_R]=YES;
                        break;
                    case 'Q':
                        if([lineScanner scanFloat:&_Q])
                            _seen[GCODE_Q]=YES;
                        break;
                    case 'E':
                        if([lineScanner scanFloat:&_A])
                            _seen[GCODE_E]=YES;
                        break;
                    case 'A':
                        if([lineScanner scanFloat:&_A])
                            _seen[GCODE_A]=YES;
                        break;
                    case 'B':
                        if([lineScanner scanFloat:&_B])
                            _seen[GCODE_B]=YES;
                        break;
                    case 'N':
                        if([lineScanner scanInteger:&_N])
                            _seen[GCODE_N]=YES;
                        break;
                    case '*':
                        if([lineScanner scanInteger:&_Checksum])
                            _seen[GCODE_CHECKSUM]=YES;
                        break;
                    default:
                        [self addError:@"Skipping unknown command code: %@", commandCode];
                }
            }
        } else {
            endOfCommand=YES;
        }
    }
}

- (BOOL)executeCommand:(NSString*)commandString {
    BOOL axisSelected;
    
    BOOL abortProcessingGcode=NO;
    BOOL abortProcessingThisCommand = NO;
    
    // Do we have lineNr and checksums in this gcode?
	if(_seen[GCODE_CHECKSUM] || _seen[GCODE_N]) {
		// Check that if recieved a L code, we also got a C code. If not, one of them has been lost, and we have to reset queue
		if(!abortProcessingThisCommand && _seen[GCODE_CHECKSUM] != _seen[GCODE_N]) {
            if(_seen[GCODE_CHECKSUM])
                [self addError:@"Checksum without line number. Checksum: %d, line processing: %@", _Checksum, commandString];
            else
                [self addError:@"Line number without checksum. Linenumber: %d, line processing: %@", _N, commandString];
            abortProcessingThisCommand=YES;
		}
        
		// Check checksum of this string. Flush buffers and re-request line of error is found
		if(!abortProcessingThisCommand && _seen[GCODE_CHECKSUM]) { // if we recieved a line nr, we know we also recieved a Checksum, so check it
            // Calc checksum.
            const char* commandChars = [commandString UTF8String];
            uint8_t checksum = 0;
            NSInteger i = 0;
            while(commandChars[i] != '*')
                checksum = checksum^commandChars[i++];
            // Check checksum.
            if(_Checksum != (NSInteger)checksum) {
                [self addError:@"Checksum mismatch.  Remote (%ld) not equal to local (%ld), line processing: %@", _Checksum, (long)checksum, commandString];
                abortProcessingThisCommand=YES;
            }
			// Check that this lineNr is LastLineNrRecieved+1. If not, flush
			if(!abortProcessingThisCommand && !(_seen[GCODE_M] && _M == 110)) { // unless this is a reset-lineNr command
				if(_N != _LastLineNrProcessed+1) {
					[self addError:@"Linenumber (%ld) is not last + 1 (%ld), line processing: %@", _N, _LastLineNrProcessed+1, commandString];
					abortProcessingThisCommand=YES;
				}
            }
            
			//If we reach this point, communication is a succes, update our "last good line nr" and continue
			if(!abortProcessingThisCommand)
                _LastLineNrProcessed = _N;
		}
    }
    
    // Deal with emergency stop as No 1 priority
    if (_seen[GCODE_M] && _M == 112) {
        abortProcessingThisCommand=YES;
        abortProcessingGcode=YES;
    }

    if(!abortProcessingThisCommand) {
        /* if no command was seen, but parameters were, then use the last G code as
         * the current command
         */
        if(!(_seen[GCODE_G] || _seen[GCODE_M] || _seen[GCODE_T]) && ([self seenAnything] && (_last_gcode_g >= 0))) {
            /* yes - so use the previous command with the new parameters */
            _G[0] = _last_gcode_g;
            _GIndex=1;
            _seen[GCODE_G]=YES;
        }
        
        Vector6* fp;
        //did we get a gcode?
        if(_seen[GCODE_G]) {
            // Handle all GCodes in this line
            for(NSInteger gIndex=0; gIndex<_GIndex; gIndex++) {
                _last_gcode_g = _G[gIndex];	/* remember this for future instructions */
                
                // Process the buffered move commands first
                switch(_G[gIndex]) {
                    ////////////////////////
                    // Buffered commands
                    ////////////////////////
                        
                    case 0:		//Rapid move
                        fp = [self fetchCartesianParameters];
                        [self renderRapidMove:fp];
                        break;
                        
                    case 1:		// Controlled move;
                        fp = [self fetchCartesianParameters];
                        [self renderControlledMove:fp];
                        break;

                    case 2:		// G2, Clockwise arc
                    case 3: 	// G3, Counterclockwise arc
                        fp = [self fetchCartesianParameters];
                        if(_seen[GCODE_R])
                            [self addError:@"Dud G code: G%d with R param not yet implemented (%@)", _G[gIndex], commandString];
                        else if(_seen[GCODE_I] || _seen[GCODE_J])
                            [self renderArc:fp centerX:fp.x+_I centerY:fp.y+_J endX:fp.x endY:fp.y clockwise:_G[gIndex]==2];
                        else
                            [self addError:@"Dud G code: G%d without I or J params (%@)", _G[gIndex], commandString];
                        break;
							
                    case 28:	//go home.  If we send coordinates (regardless of their value) only zero those axes
                        fp = [self fetchCartesianParameters];
                        axisSelected = NO;
                        if(_seen[GCODE_Z])
                        {
                            _machinePosition.z=0.f;
                            _localZeroOffset.z=0.f;
                            axisSelected = YES;
                        }
                        if(_seen[GCODE_X])
                        {
                            _machinePosition.x=0.f;
                            _localZeroOffset.x=0.f;
                            axisSelected = YES;
                        }
                        if(_seen[GCODE_Y])
                        {
                            _machinePosition.y=0.f;
                            _localZeroOffset.y=0.f;
                            axisSelected = YES;
                        }                                
                        if(!axisSelected)
                        {
                            _machinePosition.z=0.f;
                            _machinePosition.x=0.f;
                            _machinePosition.y=0.f;
                            _localZeroOffset.z=0.f;
                            _localZeroOffset.x=0.f;
                            _localZeroOffset.y=0.f;
                        }
                        _machinePosition.f = ((P3DMillDriverBase*)_currentPrinter).slowFeedrate;     // Most sensible feedrate to leave it in
                        break;
                        
                        ////////////////////////
                        // Non-Buffered commands
                        ////////////////////////
                        
                    case 4: 	//Dwell
                        _workTime+= _P / 1000.f;
                        break;
                        
                    case 20:	//Inches for Units
                        _machineMetricUnits = NO;
                        break;
                        
                    case 21:	//mm for Units
                        _machineMetricUnits = YES;
                        break;
                        
                    case 73:	// Peck drilling cycle for milling - high-speed
                    case 81:	// Drill Cycle
                    case 82:	// Drill Cycle with dwell
                    case 83:	// Drill Cycle peck drilling
                    case 85:	// Drill Cycle, slow retract
                    case 89:	// Drill Cycle with dwell and slow reredract
                        fp = [self fetchCartesianParameters];
                        [self renderDrillCycle:_G[gIndex] fp:fp];
                        break;
                        
                    case 90: 	//Absolute Positioning
                        _machineAbsolutePositioningMode=YES;
                        break;
                        
                    case 91: 	//Incremental Positioning
                        _machineAbsolutePositioningMode=NO;
                        break;
                        
                    case 92:	//Set position as fp
                        fp = [self fetchCartesianParameters];
                        if(_seen[GCODE_X])
                            _localZeroOffset.x=-_machinePosition.x+fp.x;
                        if(_seen[GCODE_Y])
                            _localZeroOffset.y=-_machinePosition.y+fp.y;
                        if(_seen[GCODE_Z])
                            _localZeroOffset.z=-_machinePosition.z+fp.z;
                        if(_seen[GCODE_A] || _seen[GCODE_E])
                            _localZeroOffset.a=-_machinePosition.a+fp.a;
                        if(_seen[GCODE_B])
                            _localZeroOffset.b=-_machinePosition.b+fp.a;
                        break;
                        
                    case 98:	// Return to initial Z level in canned cycle
                        _machineRetractMode=YES;
                        break;
                        
                    case 99:	// Return to R level in canned cycle
                        _machineRetractMode=NO;
                        break;
                        
                    default:
                        [self addError:@"Dud G code: G%d: %@", _G[gIndex], commandString];
                }
            }
        }
        
        // Get feedrate if supplied and queue is empty
        if ( _seen[GCODE_F] )
            _machinePosition.f=MIN(_F, ((P3DMillDriverBase*)_currentPrinter).fastXYFeedrate);

        //find us an m code.
        if (_seen[GCODE_M]) {
            switch (_M)
            {
                case 0:
                    abortProcessingGcode=YES;
                    break;
		        case 1:
                    // not implemented: optional stop
                    break;
                case 2:
                    // not implemented: program end
                    break;
                    
                case 6:
                    // Tool change
                    if(_seen[GCODE_T]) {
                        _machineCurrentTool=_T;
                    } else {
                        _machineCurrentTool=0;
                        [self addError:@"Unspecified tool change: %@", commandString];
                    }

                    break;
                case 110:
                    // Starting a new print, reset the gc.LastLineNrRecieved counter
                    if (_seen[GCODE_N])
                        _LastLineNrProcessed = _N;
                    break;
                case 112:	// STOP! (priority commnand)
                    abortProcessingGcode=YES;
                    break;
                default:
                    [self addError:@"Dud M code: M%d: %@", _M, commandString];
            }
        }
    }

    if (_seen[GCODE_T]) {
        _machineCurrentTool=_T;
    }
    
    return abortProcessingGcode;
}

#pragma mark - Rendering Methods
- (void)renderRapidMove:(Vector6*)fp
{
    [self updateTimeIndex];
    
    GLfloat vertex[8];
    fillVertex(vertex, _fastMoveColor, _machinePosition.cartesianVector, _localZeroOffset.cartesianVector);
    [_workVertexBuffer appendBytes:vertex length:_vertexStride];
    fillVertexLocation(vertex, fp.cartesianVector, _localZeroOffset.cartesianVector);
    [_workVertexBuffer appendBytes:vertex length:_vertexStride];
    _workVertexCount+=2;
    
    _workTime+=[self calculateTimeWithStartPosition:_machinePosition.cartesianVector endPosition:fp.cartesianVector feedRate:((P3DMillDriverBase*)_currentPrinter).fastXYFeedrate];

    [_machinePosition.cartesianVector resetWith:fp.cartesianVector];
    
    _minZ = MIN(_minZ, _machinePosition.z);
    _maxZ = MAX(_maxZ, _machinePosition.z);
}

- (void)renderControlledMove:(Vector6*)fp
{
    [self updateTimeIndex];
    
    NSColor* toolColor = _toolPathColor[_machineCurrentTool%_toolPathColor.count];
    GLfloat vertex[8];
    fillVertex(vertex, toolColor, _machinePosition.cartesianVector, _localZeroOffset.cartesianVector);
    [_workVertexBuffer appendBytes:vertex length:_vertexStride];
    fillVertexLocation(vertex, fp.cartesianVector, _localZeroOffset.cartesianVector);
    [_workVertexBuffer appendBytes:vertex length:_vertexStride];
    _workVertexCount+=2;

    _workTime+=[self calculateTimeWithStartPosition:_machinePosition.cartesianVector endPosition:fp.cartesianVector feedRate:fp.f];
    
    [_machinePosition.cartesianVector resetWith:fp.cartesianVector];
    _machinePosition.f = fp.f;
    
    _minZ = MIN(_minZ, _machinePosition.z);
    _maxZ = MAX(_maxZ, _machinePosition.z);
}

- (void)renderArc:(Vector6*)fp centerX:(float)centerX centerY:(float)centerY endX:(float)endpointX endY:(float)endpointY clockwise:(BOOL)clockwise
{
    // angle variables.
    float angleA;
    float angleB;
    float angle;
    float radius;
    float length;
    
    // delta variables.
    float aX;
    float aY;
    float bX;
    float bY;
    
    // figure out our deltas
    aX = _machinePosition.x - centerX;
    aY = _machinePosition.y - centerY;
    bX = endpointX - centerX;
    bY = endpointY - centerY;
    
    // Clockwise
    if (clockwise) {
        angleA = atan2(bY, bX);
        angleB = atan2(aY, aX);
    }
    // Counterclockwise
    else {
        angleA = atan2(aY, aX);
        angleB = atan2(bY, bX);
    }
    
    // Make sure angleB is always greater than angleA
    // and if not add 2PI so that it is (this also takes
    // care of the special case of angleA == angleB,
    // ie we want a complete circle)
    if (angleB<=angleA)
        angleB += 2. * M_PI;
    angle = angleB - angleA;
    
    // calculate a couple useful things.
    radius = sqrt(aX * aX + aY * aY);
    length = radius * angle;
    
    // for doing the actual move.
    NSInteger steps;
    NSInteger s;
    NSInteger step;
    
    // Maximum of either 2.4 times the angle in radians
    // or the length of the curve divided by the curve section constant
    steps = (NSInteger)ceilf(MAX(angle * 2.4, length));
    
    Vector6* circlePoint = [_machinePosition copy];
    circlePoint.z = fp.z;
    circlePoint.a = fp.a;
    circlePoint.b = fp.b;
    circlePoint.f = fp.f;
    
    for (s = 1; s <= steps; s++) {
        // Forwards for CCW, backwards for CW
        if (!clockwise)
            step = s;
        else
            step = steps - s;
        
        // calculate our waypoint.
        circlePoint.x = centerX + radius * cos(angleA + angle * ((float) step / steps));
        circlePoint.y = centerY + radius * sin(angleA + angle * ((float) step / steps));
        
        // start the move
        [self renderControlledMove:circlePoint];
    }
    
    // Avoid problems with rounding errors above...
    _machinePosition.x = endpointX;
    _machinePosition.y = endpointY;
}

- (void)renderDrillCycle:(NSInteger)commandCode fp:(Vector6*)fp
{
	float dwell = 0.f;
	float delta = 0.f;
	BOOL slowRetract=NO;
	BOOL fullRetract=YES;
    
	float oldZ = _machinePosition.z;
	fp.z=oldZ;

    [self renderCrosshairAtCenter:fp.cartesianVector radius:1.5f];
    //[self renderCircleAtCenter:fp.cartesianVector radius:1.f];

	BOOL error = NO;
	switch(commandCode) {
		case 85:
            slowRetract=YES;
            // fall through
		case 81:
            // Check for error conditions
            if(		!(_seen[GCODE_X] || _seen[GCODE_Y])  // No X or Y given
               ||	(_seen[GCODE_L] && _L<=0.f)			 // Loops given but not positive
               || 	_seen[GCODE_A] || _seen[GCODE_B]	   // Movements on rotational axes
//               ||	sharedMachineModel.getCutterRadiusCompensation()!=0	// cutter radius compensation is active
               )
                error = YES;
            break;
		case 89:
            slowRetract=YES;
            // fall through
		case 82:
            if(!_seen[GCODE_P])
                _P = _machineStickyP;
            // Check for error conditions
            if(		!(_seen[GCODE_X] || _seen[GCODE_Y])  // No X or Y given
               ||	_P<0.f									   // and >= 0
               ||	(_seen[GCODE_L] && _L<=0.f)			   // Loops given but not positive
               || 	_seen[GCODE_A] || _seen[GCODE_B]	   // Movements on rotational axes
//               ||	sharedMachineModel.getCutterRadiusCompensation()!=0	// cutter radius compensation is active
               )
                error = YES;
            dwell = _P;
            _machineStickyP = _P;
            break;
		case 73:
            fullRetract=NO;
            // fall through
		case 83:
            if(!_seen[GCODE_Q])
                _Q = _machineStickyQ;
            // Check for error conditions
            if(		!(_seen[GCODE_X] || _seen[GCODE_Y])  // No X or Y given
               ||	_Q<=0.									   // and > 0
               ||	(_seen[GCODE_L] && _L<=0.f)			   // Loops given but not positive
               || 	_seen[GCODE_A] || _seen[GCODE_B]	   // Movements on rotational axes
//               ||	sharedMachineModel.getCutterRadiusCompensation()!=0	// cutter radius compensation is active
               )
                error = true;
            delta = _Q;
            _machineStickyQ = _Q;
            break;
	}
	if(error) {
		[self addError:@"Dud G code: G%d with invalid or missing parameters", commandCode];
	} else {
		NSInteger loops = 1;
		if(_seen[GCODE_L])
			loops = _L;
		if(_seen[GCODE_R])
			_machineRectractingHeight = _R;
		
		if(fp.z<_machineRectractingHeight) {
			Vector6* move = [_machinePosition copy];
			move.z = _machineRectractingHeight;
            [self renderRapidMove:move];
			fp.z = _machineRectractingHeight;
		}
		
		while(loops-->0) {
            [self renderRapidMove:fp];
			if(fp.z!=_machineRectractingHeight) {
				fp.z = _machineRectractingHeight;
                [self renderRapidMove:fp];
			}
			
			if(delta>0.f) {
				float z = fp.z;
				while(z>_Z) {
					z -= delta;
					if(z<_Z)
						z=_Z;
                    
					fp.z=z;
                    [self renderControlledMove:fp];
					
					if(z>_Z) {
						if(fullRetract)
							fp.z=_machineRectractingHeight;
						else
							fp.z=z+_machineClearanceIncrement;
                        [self renderRapidMove:fp];
						fp.z=z-.5f;
                        [self renderRapidMove:fp];
					}
				}
			} else {
				fp.z = _Z;
                [self renderControlledMove:fp];
			}
			
			if(dwell>0)
                _workTime += dwell/1000.f;
            
			if(loops==0 && _machineRetractMode)
				fp.z = oldZ;
			else
				fp.z = _machineRectractingHeight;
            
			if(slowRetract)
                [self renderControlledMove:fp];
			else
                [self renderRapidMove:fp];
            
			if(loops>0 && !_machineAbsolutePositioningMode) {
				if (_seen[GCODE_X])
					fp.x += _X;
				if (_seen[GCODE_Y])
					fp.y += _Y;
			}
		}
	}
}

- (void)renderCrosshairAtCenter:(Vector3*)center radius:(float)r
{
    GLfloat vertex[8];
    NSColor* toolColor = _fastMoveColor; //_toolPathColor[_machineCurrentTool%_toolPathColor.count];
    
    Vector3* p = [[Vector3 alloc] init];
    p.z = center.z;
    
    p.x = center.x;
    p.y = center.y - r;
    fillVertex(vertex, toolColor, p, _localZeroOffset.cartesianVector);
    [_workVertexBuffer appendBytes:vertex length:_vertexStride];
    p.x = center.x;
    p.y = center.y + r;
    fillVertex(vertex, toolColor, p, _localZeroOffset.cartesianVector);
    [_workVertexBuffer appendBytes:vertex length:_vertexStride];
    p.x = center.x - r;
    p.y = center.y;
    fillVertex(vertex, toolColor, p, _localZeroOffset.cartesianVector);
    [_workVertexBuffer appendBytes:vertex length:_vertexStride];
    p.x = center.x + r;
    p.y = center.y;
    fillVertex(vertex, toolColor, p, _localZeroOffset.cartesianVector);
    [_workVertexBuffer appendBytes:vertex length:_vertexStride];
    
    p.x = center.x - r*.5;
    p.y = center.y - r*.5;
    fillVertex(vertex, toolColor, p, _localZeroOffset.cartesianVector);
    [_workVertexBuffer appendBytes:vertex length:_vertexStride];
    p.x = center.x - r*.15;
    p.y = center.y - r*.15;
    fillVertex(vertex, toolColor, p, _localZeroOffset.cartesianVector);
    [_workVertexBuffer appendBytes:vertex length:_vertexStride];
    p.x = center.x + r*.5;
    p.y = center.y + r*.5;
    fillVertex(vertex, toolColor, p, _localZeroOffset.cartesianVector);
    [_workVertexBuffer appendBytes:vertex length:_vertexStride];
    p.x = center.x + r*.15;
    p.y = center.y + r*.15;
    fillVertex(vertex, toolColor, p, _localZeroOffset.cartesianVector);
    [_workVertexBuffer appendBytes:vertex length:_vertexStride];
    p.x = center.x - r*.5;
    p.y = center.y + r*.5;
    fillVertex(vertex, toolColor, p, _localZeroOffset.cartesianVector);
    [_workVertexBuffer appendBytes:vertex length:_vertexStride];
    p.x = center.x - r*.15;
    p.y = center.y + r*.15;
    fillVertex(vertex, toolColor, p, _localZeroOffset.cartesianVector);
    [_workVertexBuffer appendBytes:vertex length:_vertexStride];
    p.x = center.x + r*.5;
    p.y = center.y - r*.5;
    fillVertex(vertex, toolColor, p, _localZeroOffset.cartesianVector);
    [_workVertexBuffer appendBytes:vertex length:_vertexStride];
    p.x = center.x + r*.15;
    p.y = center.y - r*.15;
    fillVertex(vertex, toolColor, p, _localZeroOffset.cartesianVector);
    [_workVertexBuffer appendBytes:vertex length:_vertexStride];

    _workVertexCount+=8;
}

- (void)renderCircleAtCenter:(Vector3*)center radius:(float)r
{
    NSInteger num_segments = 10.f * sqrtf(r);
    
	float theta = 2.f * M_PI / (float)num_segments;
	float tangetial_factor = tanf(theta);//calculate the tangential factor
    
	float radial_factor = cosf(theta);//calculate the radial factor
	
	float x = r;//we start at angle = 0
    
	float y = 0;
    GLfloat vertex[8];
    NSColor* toolColor = _toolPathColor[_machineCurrentTool%_toolPathColor.count];
    
    Vector3* p = [[Vector3 alloc] init];
    p.z = center.z;
    
	for(NSInteger ii = 0; ii < num_segments; ii++)
	{
        if(ii>0) {
            [_workVertexBuffer appendBytes:vertex length:_vertexStride];
            _workVertexCount++;
        }
        p.x = x + center.x;
        p.y = y + center.y;
        fillVertex(vertex, toolColor, p, _localZeroOffset.cartesianVector);
        if(ii>0) {
            [_workVertexBuffer appendBytes:vertex length:_vertexStride];
            _workVertexCount++;
        }
        
		//calculate the tangential vector
		//remember, the radial vector is (x, y)
		//to get the tangential vector we flip those coordinates and negate one of them
        
		float tx = -y;
		float ty = x;
        
		//add the tangential vector
        
		x += tx * tangetial_factor;
		y += ty * tangetial_factor;
        
		//correct using the radial factor
        
		x *= radial_factor;
		y *= radial_factor;
	}
    if(num_segments>0) {
        [_workVertexBuffer appendBytes:vertex length:_vertexStride];
        _workVertexCount++;
        p.x = r + center.x;
        p.y = center.y;
        fillVertex(vertex, toolColor, p, _localZeroOffset.cartesianVector);
        [_workVertexBuffer appendBytes:vertex length:_vertexStride];
        _workVertexCount++;
    }
}

@end
