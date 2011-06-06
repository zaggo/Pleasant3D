//
//  PacketBuilder.h
//  Sanguino3G
//
//  Created by Eberhard Rensch on 16.03.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define kStartByte 0xd5

@interface PacketBuilder : NSObject {
	NSInteger writePos;
	NSData* data;
	uint8_t* dataPtr;
	
	uint16_t crc;
}

@property (readonly) NSData* packet;
@property (readonly) uint8_t* rawPacketPtr;
@property (readonly) uint8_t crc;

- (id)initWithCommand:(uint8_t)command;

- (void)startPacketWithCommand:(uint8_t)command;

- (void)add8:(uint8_t)value;
- (void)add16:(uint16_t)value;
- (void)add32:(uint32_t)value;

@end
