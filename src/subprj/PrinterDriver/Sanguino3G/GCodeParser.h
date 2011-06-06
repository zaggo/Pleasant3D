//
//  GCodeParser.h
//  Sanguino3G
//
//  Created by Eberhard Rensch on 10.04.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <P3DCore/P3DCore.h>

@class Sanguino3G, PacketBuilder;
@interface GCodeParser : NSObject {
	Sanguino3G* driver;
	Vector3* stepsPerMM;
	Vector3* maxFeedrate;
	
	NSCharacterSet* commandCodeSet;
	NSData* commandValueData;
	float* commandValues;
	NSData* commandFoundData;
	BOOL* commandFound;
	
	PacketBuilder* packetFactory;
	
	BOOL imperialUnits;
	BOOL absolutePositioning;
	NSInteger toolIndex;
	Vector3* currentPosition;
	Vector3* targetPosition;
	Vector3* intermedPosition;
	Vector3* deltaSteps;
	float currentFeedrate;
	float feedrate;
	
	NSMutableArray* bytecodeBuffers;
	NSData* bytecodeBufferData;
	uint8_t* bytecodeBufferPtr;
	NSInteger bytecodeWritePosition;
}

@property (assign) Sanguino3G* driver;

- (NSArray*)parse:(NSString*)gCode;

@end
