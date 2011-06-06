//
//  GCodeParser.m
//  Sanguino3G
//
//  Created by Eberhard Rensch on 10.04.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import "GCodeParser.h"
#import "Sanguino3G.h"
#import "SanguinoDevice.h"
#import "PacketBuilder.h"

static NSString* kCommandCodes = @"DFGHIJKLMPQRSTXYZ";
enum {
	kIndexD,
	kIndexF,
	kIndexG,
	kIndexH,
	kIndexI,
	kIndexJ,
	kIndexK,
	kIndexL,
	kIndexM,
	kIndexP,
	kIndexQ,
	kIndexR,
	kIndexS,
	kIndexT,
	kIndexX,
	kIndexY,
	kIndexZ
	};

const float kMMtoInches = 25.4;
const NSInteger kBytecodeBufferLen = 4096;

@interface GCodeParser (Private)
- (void)parseCodeLine:(NSScanner*)codeline;
- (void)appendPacket:(uint8_t*)rawPacket;
- (void)clear;
- (void)execute;
- (void)executeM;
- (void)executeG;
- (void)commitTargetPosition;
- (void)queueIntermedPosition;
@end

@implementation GCodeParser
@synthesize driver;

- (id) init
{
	self = [super init];
	if (self != nil) {
		commandCodeSet = [NSCharacterSet characterSetWithCharactersInString:kCommandCodes];
		commandValueData = [NSData dataWithBytesNoCopy:calloc(sizeof(float),kCommandCodes.length) length:kCommandCodes.length freeWhenDone:YES];
		commandValues = (float*)commandValueData.bytes;
		commandFoundData = [NSData dataWithBytesNoCopy:calloc(sizeof(BOOL),kCommandCodes.length) length:kCommandCodes.length freeWhenDone:YES];
		commandFound = (BOOL*)commandFoundData.bytes;
		
		packetFactory = [[PacketBuilder alloc] init];
		toolIndex = -1;
		
		currentPosition = [[Vector3 alloc] init];
		targetPosition = [[Vector3 alloc] init];
		intermedPosition = [[Vector3 alloc] init];
		deltaSteps = [[Vector3 alloc] init];

		bytecodeBuffers = [[NSMutableArray alloc] init];
		bytecodeBufferData = [NSData dataWithBytesNoCopy:calloc(sizeof(uint8_t),kBytecodeBufferLen) length:kBytecodeBufferLen freeWhenDone:YES];
		bytecodeBufferPtr = (uint8_t*)bytecodeBufferData.bytes;
		bytecodeWritePosition = 0;
	}
	return self;
}

- (void)setDriver:(Sanguino3G*)value
{
	driver = value;
	stepsPerMM = [[Vector3 alloc] initVectorWithX:[[[driver.driverOptions objectForKey:@"xAxis"] objectForKey:@"scale"] floatValue] 
												Y:[[[driver.driverOptions objectForKey:@"yAxis"] objectForKey:@"scale"] floatValue]
												Z:[[[driver.driverOptions objectForKey:@"zAxis"] objectForKey:@"scale"] floatValue]];
	maxFeedrate = [[Vector3 alloc] initVectorWithX:[[[driver.driverOptions objectForKey:@"xAxis"] objectForKey:@"maxFeedrate"] floatValue] 
												 Y:[[[driver.driverOptions objectForKey:@"yAxis"] objectForKey:@"maxFeedrate"] floatValue]
												 Z:[[[driver.driverOptions objectForKey:@"zAxis"] objectForKey:@"maxFeedrate"] floatValue]];
}

- (NSArray*)parse:(NSString*)gCode;
{
	[bytecodeBuffers removeAllObjects];
	bytecodeWritePosition = 0;
	
	// Create an array of linescanners
	NSMutableArray* gCodeLineScanners = [NSMutableArray array];
	NSArray* untrimmedLines = [gCode componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	NSCharacterSet* whiteSpaceSet = [NSCharacterSet whitespaceCharacterSet];
	[untrimmedLines enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		[gCodeLineScanners addObject:[NSScanner scannerWithString:[obj stringByTrimmingCharactersInSet:whiteSpaceSet]]];
	}];
	
	[gCodeLineScanners enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		[self parseCodeLine:obj];
	}];
	
	return bytecodeBuffers;
}

- (void)clear
{
	bzero(commandFound, commandFoundData.length);

	float lastGCode = commandValues[kIndexG];
	bzero(commandValues, commandValueData.length);
	commandValues[kIndexG]=lastGCode;
}


- (void)parseCodeLine:(NSScanner*)codeline
{
	[self clear];
	
	NSString* code;
	while([codeline scanCharactersFromSet:commandCodeSet intoString:&code])
	{
		float value = 0.f;
		[codeline scanFloat:&value];
		
		NSInteger index = [kCommandCodes rangeOfString:code].location;
		if(index!=NSNotFound)
		{
			if(commandFound[index])
				[self execute];
			
			commandFound[index]=YES;
			commandValues[index]=value;
		}
	}
	
	[self execute];
}

- (void)appendPacket:(uint8_t*)rawPacket
{
	NSInteger packetLen = (NSInteger)rawPacket[1]+3; // payload + header (2) + crc (1)
	if(bytecodeWritePosition+packetLen>=kBytecodeBufferLen)
	{
		NSData* bytecodeBufferBlock = [NSData dataWithBytes:bytecodeBufferPtr length:bytecodeWritePosition];
		[bytecodeBuffers addObject:bytecodeBufferBlock];
		bytecodeWritePosition=0;
	}
	memcpy(bytecodeBufferPtr+bytecodeWritePosition, rawPacket, packetLen);
	bytecodeWritePosition+=packetLen;
}

- (void)commitTargetPosition
{
	[intermedPosition resetWith:currentPosition];
	if (targetPosition.z != intermedPosition.z)
	{
		intermedPosition.z = targetPosition.z;
		[self queueIntermedPosition];
		[currentPosition resetWith:intermedPosition];
	}
	
	if(targetPosition.x != intermedPosition.x || targetPosition.y != intermedPosition.y)
	{
		[intermedPosition resetWith:targetPosition];
		[self queueIntermedPosition];
	}
	[currentPosition resetWith:targetPosition];
}

- (float)safeFeedrate:(Vector3*)delta
{
	float safeFeedrate = currentFeedrate;
	
	if(safeFeedrate==0.f)
		safeFeedrate = MAX(MAX(maxFeedrate.x, maxFeedrate.y), maxFeedrate.z);

	if(delta.x!=0.f)
		safeFeedrate = MIN(safeFeedrate, maxFeedrate.x);
	if(delta.y!=0.f)
		safeFeedrate = MIN(safeFeedrate, maxFeedrate.y);
	if(delta.z!=0.f)
		safeFeedrate = MIN(safeFeedrate, maxFeedrate.z);
	
	return safeFeedrate;
}

- (void)queueIntermedPosition
{
	float deltaDistanceX = (intermedPosition.x-currentPosition.x);
	float deltaDistanceY = (intermedPosition.y-currentPosition.y);
	float deltaDistanceZ = (intermedPosition.z-currentPosition.z);

	deltaSteps.x = roundf(deltaDistanceX*stepsPerMM.x);
	deltaSteps.y = roundf(deltaDistanceY*stepsPerMM.y);
	deltaSteps.z = roundf(deltaDistanceZ*stepsPerMM.z);
	
	float masterSteps = MAX(MAX(deltaSteps.x, deltaSteps.y), deltaSteps.z);
	
	// okay, we need at least one step.
	if (masterSteps > 0.0)
	{	 
		// how fast are we doing it?
		float distance = sqrtf(deltaDistanceX * deltaDistanceX
								+ deltaDistanceY * deltaDistanceY 
								+ deltaDistanceZ * deltaDistanceZ);

		// distance / feedrate * 60,000,000 = move duration in microseconds
		float microsecs = distance / [self safeFeedrate:deltaSteps] * 60000000.f;

		// micros / masterSteps = time between steps for master axis.
		float step_delay = microsecs / masterSteps;

		NSInteger micros = (NSInteger)roundf(step_delay);

		// okay, send it off!
		[packetFactory startPacketWithCommand:kMasterQUEUE_POINT_ABS];
		[packetFactory add32:(NSInteger)(intermedPosition.x*stepsPerMM.x)];
		[packetFactory add32:(NSInteger)(intermedPosition.y*stepsPerMM.y)];
		[packetFactory add32:(NSInteger)(intermedPosition.y*stepsPerMM.y)];
		[packetFactory add32:micros];
		[self appendPacket:packetFactory.rawPacketPtr];
	}
}
		 
- (void)execute
{
	if(commandFound[kIndexT])
	{
		NSInteger tool = (NSInteger)commandValues[kIndexT];
		if(tool != toolIndex)
		{
			[packetFactory startPacketWithCommand:kMasterCHANGE_TOOL];
			[packetFactory add8:tool];
			[self appendPacket:packetFactory.rawPacketPtr];
			toolIndex = tool;
		}
	}

	if(commandFound[kIndexM])
		[self executeM];
		
	if(commandFound[kIndexG] || commandFound[kIndexX] || commandFound[kIndexY] || commandFound[kIndexZ])
		[self executeG];
	
	[self clear];
}

- (void)executeM
{
	switch ((NSInteger)commandValues[kIndexM])
	{
		// stop codes
		case 0:
		case 1:
		case 2:
			break;
			
			// spindle on, CW
		case 3:
			[packetFactory startPacketWithCommand:kMasterTOOL_COMMAND];
			[packetFactory add8:toolIndex];
			[packetFactory add8:kSlaveTOGGLE_MOTOR_2];
			[packetFactory add8:1]; // payload length
			[packetFactory add8:0x3]; // 0000 0011 - bit 0 = enable, bit 2 = directon
			[self appendPacket:packetFactory.rawPacketPtr];
			break;
			
			// spindle on, CCW
		case 4:
			[packetFactory startPacketWithCommand:kMasterTOOL_COMMAND];
			[packetFactory add8:toolIndex];
			[packetFactory add8:kSlaveTOGGLE_MOTOR_2];
			[packetFactory add8:1]; // payload length
			[packetFactory add8:0x1]; // 0000 0001 - bit 0 = enable, bit 2 = directon
			[self appendPacket:packetFactory.rawPacketPtr];
			break;
			
			// spindle off
		case 5:
			[packetFactory startPacketWithCommand:kMasterTOOL_COMMAND];
			[packetFactory add8:toolIndex];
			[packetFactory add8:kSlaveTOGGLE_MOTOR_2];
			[packetFactory add8:1]; // payload length
			[packetFactory add8:0x0]; // 0000 0000 - bit 0 = enable, bit 2 = directon
			[self appendPacket:packetFactory.rawPacketPtr];
			break;
			
			// tool change
		case 6:
			if(commandFound[kIndexT])
			{
				NSInteger tool = (NSInteger)commandValues[kIndexT];
				[packetFactory startPacketWithCommand:kMasterWAIT_FOR_TOOL];
				[packetFactory add8:tool];
				[packetFactory add16:100]; // delay between master -> slave pings (millis)
				[packetFactory add16:120]; // timeout before continuing (seconds)
				[self appendPacket:packetFactory.rawPacketPtr];
			}
			else
			{
				// TODO: Error handling
				PSErrorLog(@"The T parameter is required for tool changes. (M6)");
			}
			break;
			
			// coolant A on (flood coolant)
		case 7:
			// TODO: Error handling
			PSErrorLog(@"coolant A on (flood coolant) currently unsupported. (M7)");
			break;
			
			// coolant B on (mist coolant)
		case 8:
			// TODO: Error handling
			PSErrorLog(@"coolant B on (mist coolant) currently unsupported. (M8)");
			break;
			
			// all coolants off
		case 9:
			// TODO: Error handling
			PSErrorLog(@"all coolants off currently unsupported. (M9)");
			break;
			
			// close clamp
		case 10:
			if(commandFound[kIndexQ])
			{
				NSInteger clampNumber = (NSInteger)commandValues[kIndexQ];
				// TODO: Error handling
				PSErrorLog(@"close clamp (#%d) currently unsupported. (M9)", clampNumber);
			}
			else
			{
				// TODO: Error handling
				PSErrorLog(@"The Q parameter is required for clamp operations. (M10)");
			}
			break;
			
			// open clamp
		case 11:
			if(commandFound[kIndexQ])
			{
				NSInteger clampNumber = (NSInteger)commandValues[kIndexQ];
				// TODO: Error handling
				PSErrorLog(@"open clamp (#%d) currently unsupported. (M9)", clampNumber);
			}
			else
			{
				// TODO: Error handling
				PSErrorLog(@"The Q parameter is required for clamp operations. (M11)");
			}
			break;
			
			// spindle CW and coolant A on
		case 13:
			[packetFactory startPacketWithCommand:kMasterTOOL_COMMAND];
			[packetFactory add8:toolIndex];
			[packetFactory add8:kSlaveTOGGLE_MOTOR_2];
			[packetFactory add8:1]; // payload length
			[packetFactory add8:0x3]; // 0000 0011 - bit 0 = enable, bit 2 = directon
			[self appendPacket:packetFactory.rawPacketPtr];
			// TODO: Error handling
			PSErrorLog(@"coolant A on (flood coolant) currently unsupported. (M13)");
			break;
			
			// spindle CW and coolant A on
		case 14:
			[packetFactory startPacketWithCommand:kMasterTOOL_COMMAND];
			[packetFactory add8:toolIndex];
			[packetFactory add8:kSlaveTOGGLE_MOTOR_2];
			[packetFactory add8:1]; // payload length
			[packetFactory add8:0x1]; // 0000 0001 - bit 0 = enable, bit 2 = directon
			[self appendPacket:packetFactory.rawPacketPtr];
			// TODO: Error handling
			PSErrorLog(@"coolant A on (flood coolant) currently unsupported. (M14)");
			break;
			
			// enable drives
		case 17:		
			[packetFactory startPacketWithCommand:kMasterENABLE_AXES];
			[packetFactory add8:0x87]; // enable x,y,z
			[self appendPacket:packetFactory.rawPacketPtr];
			break;
			
			// disable drives
		case 18:
			[packetFactory startPacketWithCommand:kMasterENABLE_AXES];
			[packetFactory add8:0x07]; // disable x,y,z
			[self appendPacket:packetFactory.rawPacketPtr];
			break;
			
			// open collet
		case 21:
			// TODO: Error handling
			PSErrorLog(@"open collet currently unsupported. (M21)");
			
			// close collet
		case 22:
			// TODO: Error handling
			PSErrorLog(@"close collet currently unsupported. (M22)");
			
			// M40-M46 = change gear ratios
		case 40:
		case 41:
		case 42:
		case 43:
		case 44:
		case 45:
		case 46:
			// TODO: Error handling
			PSErrorLog(@"change gear ratios currently unsupported. (M%d)", (NSInteger)commandValues[kIndexM]);
			break;
			
			// M48, M49: i dont understand them yet.
			
			// read spindle speed
		case 50:
			// TODO: Error handling
			PSErrorLog(@"read spindle speed currently unsupported. (M%d)", (NSInteger)commandValues[kIndexM]);
			break;
			
			// subroutine functions... will implement later
			// case 97: jump
			// case 98: jump to subroutine
			// case 99: return from sub
			
			// turn extruder on, forward
		case 101:
			[packetFactory startPacketWithCommand:kMasterTOOL_COMMAND];
			[packetFactory add8:toolIndex];
			[packetFactory add8:kSlaveTOGGLE_MOTOR_1];
			[packetFactory add8:1]; // payload length
			[packetFactory add8:0x3]; // 0000 0011 - bit 0 = enable, bit 2 = directon
			[self appendPacket:packetFactory.rawPacketPtr];
			break;
			
			// turn extruder on, reverse
		case 102:
			[packetFactory startPacketWithCommand:kMasterTOOL_COMMAND];
			[packetFactory add8:toolIndex];
			[packetFactory add8:kSlaveTOGGLE_MOTOR_1];
			[packetFactory add8:1]; // payload length
			[packetFactory add8:0x1]; // 0000 0001 - bit 0 = enable, bit 2 = directon
			[self appendPacket:packetFactory.rawPacketPtr];
			break;
			
			// turn extruder off
		case 103:
			[packetFactory startPacketWithCommand:kMasterTOOL_COMMAND];
			[packetFactory add8:toolIndex];
			[packetFactory add8:kSlaveTOGGLE_MOTOR_1];
			[packetFactory add8:1]; // payload length
			[packetFactory add8:0x0]; // 0000 0000 - bit 0 = enable, bit 2 = directon
			[self appendPacket:packetFactory.rawPacketPtr];
			break;
			
			// custom code for temperature control
		case 104:
			if(commandFound[kIndexS])
			{
				NSInteger temperature = MIN(65535, (NSInteger)roundf(commandValues[kIndexS]));
				[packetFactory startPacketWithCommand:kMasterTOOL_COMMAND];
				[packetFactory add8:toolIndex];
				[packetFactory add8:kSlaveSET_TEMP];
				[packetFactory add8:2]; // payload length
				[packetFactory add16:temperature];
				[self appendPacket:packetFactory.rawPacketPtr];
			}
			else
			{
				// TODO: Error handling
				PSErrorLog(@"The S parameter is required for extruder temperature operations. (M104)");
			}
			break;
			
			// custom code for temperature reading
		case 105:
			// TODO: Error handling
			PSErrorLog(@"temperature reading currently unsupported. (M%d)", (NSInteger)commandValues[kIndexM]);
			break;
			
			// turn fan on
		case 106:
			[packetFactory startPacketWithCommand:kMasterTOOL_COMMAND];
			[packetFactory add8:toolIndex];
			[packetFactory add8:kSlaveTOGGLE_FAN];
			[packetFactory add8:1]; // payload length
			[packetFactory add8:0x1];
			[self appendPacket:packetFactory.rawPacketPtr];
			break;
			
			// turn fan off
		case 107:
			[packetFactory startPacketWithCommand:kMasterTOOL_COMMAND];
			[packetFactory add8:toolIndex];
			[packetFactory add8:kSlaveTOGGLE_FAN];
			[packetFactory add8:1]; // payload length
			[packetFactory add8:0x0];
			[self appendPacket:packetFactory.rawPacketPtr];
			break;
			
			// set max extruder speed, RPM
		case 108:
			if(commandFound[kIndexS])
			{
				NSInteger pwm = (NSInteger)commandValues[kIndexS];
				[packetFactory startPacketWithCommand:kMasterTOOL_COMMAND];
				[packetFactory add8:toolIndex];
				[packetFactory add8:kSlaveSET_MOTOR_1_PWM];
				[packetFactory add8:1]; // payload length
				[packetFactory add8:pwm]; // payload length
				[self appendPacket:packetFactory.rawPacketPtr];
			}
			else if(commandFound[kIndexR] && commandValues[kIndexR]>0.)
			{
				// convert RPM into microseconds and then send.
				NSInteger microseconds = MIN(65535, (NSInteger)roundf(60.f * 1000000.f / commandValues[kIndexR]));
				[packetFactory startPacketWithCommand:kMasterTOOL_COMMAND];
				[packetFactory add8:toolIndex];
				[packetFactory add8:kSlaveSET_MOTOR_1_RPM];
				[packetFactory add8:4]; // payload length
				[packetFactory add32:microseconds];
				[self appendPacket:packetFactory.rawPacketPtr];
			}
			break;
			
			// set build platform temperature
		case 109:
			if(commandFound[kIndexS])
			{
				NSInteger temperature = MIN(65535, (NSInteger)roundf(commandValues[kIndexS]));
				[packetFactory startPacketWithCommand:kMasterTOOL_COMMAND];
				[packetFactory add8:toolIndex];
				[packetFactory add8:kSlaveSET_PLATFORM_TEMP];
				[packetFactory add8:2]; // payload length
				[packetFactory add16:temperature];
				[self appendPacket:packetFactory.rawPacketPtr];
			}
			else
			{
				// TODO: Error handling
				PSErrorLog(@"The S parameter is required for platform temperature operations. (M109)");
			}
			break;
			
			// set build chamber temperature
		case 110:
			// TODO: Error handling
			PSErrorLog(@"set build chamber temperature currently unsupported. (M%d)", (NSInteger)commandValues[kIndexM]);
			break;
			
			// valve open
		case 126:
			[packetFactory startPacketWithCommand:kMasterTOOL_COMMAND];
			[packetFactory add8:toolIndex];
			[packetFactory add8:kSlaveTOGGLE_VALVE];
			[packetFactory add8:1]; // payload length
			[packetFactory add8:0x1];
			[self appendPacket:packetFactory.rawPacketPtr];
			break;
			
			// valve close
		case 127:
			[packetFactory startPacketWithCommand:kMasterTOOL_COMMAND];
			[packetFactory add8:toolIndex];
			[packetFactory add8:kSlaveTOGGLE_VALVE];
			[packetFactory add8:1]; // payload length
			[packetFactory add8:0x0];
			[self appendPacket:packetFactory.rawPacketPtr];
			break;
			
			// where are we?
		case 128:
			// TODO: Error handling
			PSErrorLog(@"getPosition currently unsupported. (M%d)", (NSInteger)commandValues[kIndexM]);
			break;
			
			// how far can we go?
		case 129:
			// TODO: Error handling
			PSErrorLog(@"getRange currently unsupported. (M%d)", (NSInteger)commandValues[kIndexM]);
			break;
			
			// you must know your limits
		case 130:
			// TODO: Error handling
			PSErrorLog(@"setRange currently unsupported. (M%d)", (NSInteger)commandValues[kIndexM]);
			break;
			
			// initialize to default state.
		case 200:
			[packetFactory startPacketWithCommand:kMasterINIT];
			[self appendPacket:packetFactory.rawPacketPtr];
			break;

		default:
			// TODO: Error handling
			PSErrorLog(@"currently unsupported. (M%d)", (NSInteger)commandValues[kIndexM]);
	}
}

- (void)executeG
{
	[targetPosition resetWith:currentPosition];
	if(absolutePositioning)
	{
		// We want to slow down the parsing as less as possible by the imperial system!
		if(imperialUnits)
		{
			if(commandFound[kIndexX])
				targetPosition.x = commandValues[kIndexX]*kMMtoInches;
			if(commandFound[kIndexY])
				targetPosition.y = commandValues[kIndexY]*kMMtoInches;
			if(commandFound[kIndexZ])
				targetPosition.z = commandValues[kIndexZ]*kMMtoInches;
		}
		else
		{
			if(commandFound[kIndexX])
				targetPosition.x = commandValues[kIndexX];
			if(commandFound[kIndexY])
				targetPosition.y = commandValues[kIndexY];
			if(commandFound[kIndexZ])
				targetPosition.z = commandValues[kIndexZ];
		}
	}
	else
	{
		// We want to slow down the parsing as less as possible by the imperial system!
		if(imperialUnits)
		{
			if(commandFound[kIndexX])
				targetPosition.x += commandValues[kIndexX]*kMMtoInches;
			if(commandFound[kIndexY])
				targetPosition.y += commandValues[kIndexY]*kMMtoInches;
			if(commandFound[kIndexZ])
				targetPosition.z += commandValues[kIndexZ]*kMMtoInches;
		}
		else
		{
			if(commandFound[kIndexX])
				targetPosition.x += commandValues[kIndexX];
			if(commandFound[kIndexY])
				targetPosition.y += commandValues[kIndexY];
			if(commandFound[kIndexZ])
				targetPosition.z += commandValues[kIndexZ];
		}
	}

	if(commandFound[kIndexF])
	{
		feedrate = commandValues[kIndexF];
	}
	
	switch((NSInteger)commandValues[kIndexG])
	{
			// Linear Interpolation
			// these are basically the same thing.
		case 0:
			currentFeedrate = MIN(maxFeedrate.x, maxFeedrate.y);
			[self commitTargetPosition];
			break;
			
			// Rapid Positioning
		case 1:
			// set our target.
			currentFeedrate = feedrate;
			[self commitTargetPosition];
			break;
			
			// Clockwise arc
		case 2:
			// Counterclockwise arc
		case 3: 
		/*{
			// call our arc drawing function.
			if (hasCode("I") || hasCode("J")) {
				// our centerpoint
				Point3d center = new Point3d();
				center.x = current.x + iVal;
				center.y = current.y + jVal;
				
				// draw the arc itself.
				if (gCode == 2)
					drawArc(center, temp, true);
				else
					drawArc(center, temp, false);
			}
			// or we want a radius based one
			else if (hasCode("R")) {
				System.out
				.println("G02/G03 arcs with (R)adius parameter are not supported yet.");
				
				if (gCode == 2)
					drawRadius(temp, rVal, true);
				else
					drawRadius(temp, rVal, false);
			}
		}*/
			break;
			
			// dwell
		case 4:
			{
				NSInteger millis = (NSInteger)commandValues[kIndexP];
				[packetFactory startPacketWithCommand:kMasterDELAY];
				[packetFactory add32:millis];
				[self appendPacket:packetFactory.rawPacketPtr];
			}
			break;
			
			// plane selection codes
		case 17:
		case 18:
		case 19:
			// TODO: Error handling
			PSErrorLog(@"XYZ Plane moves currently unsupported. (G%d)", (NSInteger)commandValues[kIndexG]);
			break;
			
			// Inches for Units
		case 20:
		case 70:
			imperialUnits = YES;
			break;
			
			// mm for Units
		case 21:
		case 71:
			imperialUnits = NO;
			break;
			
			// go home to your limit switches
		case 28:
			// TODO: Error handling
			PSErrorLog(@"Homing currently unsupported. (G%d)", (NSInteger)commandValues[kIndexG]);
			break;
			
			// single probe
		case 31:
			// TODO: Error handling
			PSErrorLog(@"single probe currently unsupported. (G%d)", (NSInteger)commandValues[kIndexG]);
			break;
			
			// probe area
		case 32:
			// TODO: Error handling
			PSErrorLog(@"probe area currently unsupported. (G%d)", (NSInteger)commandValues[kIndexG]);
			break;
			
			// master offset
		case 53:
			// fixture offset 1
		case 54:
			// fixture offset 2
		case 55:
			// fixture offset 3
		case 56:
			// fixture offset 4
		case 57:
			// fixture offset 5
		case 58:
			// fixture offset 6
		case 59:
			// TODO: Error handling
			PSErrorLog(@"master offset currently unsupported. (G%d)", (NSInteger)commandValues[kIndexG]);
			break;
			
/*
			// Peck Motion Cycle
			// case 178: //speed peck motion
			// case 78:
			// TODO: make this
			
			// Cancel drill cycle
		case 80:
			drillTarget = new Point3d();
			drillRetract = 0.0;
			drillFeedrate = 0.0;
			drillDwell = 0;
			drillPecksize = 0.0;
			break;
			
			// Drilling canned cycles
		case 81: // Without dwell
		case 82: // With dwell
		case 83: // Peck drilling (w/ optional dwell)
		case 183: // Speed peck drilling (w/ optional dwell)
			
			// we dont want no stinkin speedpeck
			boolean speedPeck = false;
			
			// setup our parameters
			if (hasCode("X"))
				drillTarget.x = temp.x;
			if (hasCode("Y"))
				drillTarget.y = temp.y;
			if (hasCode("Z"))
				drillTarget.z = temp.z;
			if (hasCode("F"))
				drillFeedrate = getCodeValue("F");
			if (hasCode("R"))
				drillRetract = rVal;
			
			// set our vars for normal drilling
			if (gCode == 81) {
				drillDwell = 0;
				drillPecksize = 0.0;
			}
			// they want a dwell
			else if (gCode == 82) {
				if (hasCode("P"))
					drillDwell = (int) getCodeValue("P");
				drillPecksize = 0.0;
			}
			// fancy schmancy 'pecking' motion.
			else if (gCode == 83 || gCode == 183) {
				if (hasCode("P"))
					drillDwell = (int) getCodeValue("P");
				if (hasCode("Q"))
					drillPecksize = Math.abs(getCodeValue("Q"));
				
				// oooh... do it fast!
				if (gCode == 183)
					speedPeck = true;
			}
			
			drillingCycle(speedPeck);
			break;
*/			
			// Absolute Positioning
		case 90:
			absolutePositioning = YES;
			break;
			
			// Incremental Positioning
		case 91:
			absolutePositioning = NO;
			break;
			
			// Set position
		case 92:
			// We want to slow down the parsing as less as possible by the imperial system!
			if(imperialUnits)
			{
				if(commandFound[kIndexX])
					currentPosition.x = commandValues[kIndexX]*kMMtoInches;
				if(commandFound[kIndexY])
					currentPosition.y = commandValues[kIndexY]*kMMtoInches;
				if(commandFound[kIndexZ])
					currentPosition.z = commandValues[kIndexZ]*kMMtoInches;
			}
			else
			{
				if(commandFound[kIndexX])
					currentPosition.x = commandValues[kIndexX];
				if(commandFound[kIndexY])
					currentPosition.y = commandValues[kIndexY];
				if(commandFound[kIndexZ])
					currentPosition.z = commandValues[kIndexZ];
			}
			break;
			
/*			// feed rate mode
			// case 93: //inverse time feed rate
		case 94: // IPM feed rate (our default)
			// case 95: //IPR feed rate
			// TODO: make this work.
			break;
			
			// spindle speed rate
		case 97:
			driver.setSpindleRPM((int) getCodeValue("S"));
			break;
*/			

		default:
			// TODO: Error handling
			PSErrorLog(@"currently unsupported. (G%d)", (NSInteger)commandValues[kIndexG]);
	}
}
@end
