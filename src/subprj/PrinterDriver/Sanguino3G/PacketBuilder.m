//
//  PacketBuilder.m
//  Sanguino3G
//
//  Created by Eberhard Rensch on 16.03.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import "PacketBuilder.h"

@interface PacketBuilder (Private)
- (void)crc_ibutton_update:(uint8_t)value;
@end

@implementation PacketBuilder
@dynamic packet, rawPacketPtr, crc;

- (id)init
{
	self = [super init];
	if(self)
	{
		data = [[NSData alloc] initWithBytesNoCopy:calloc(256, sizeof(unsigned char)) length:256 freeWhenDone:YES];
		dataPtr = (uint8_t*)data.bytes;
	}
	return self;
}

- (id)initWithCommand:(uint8_t)command
{
	self = [super init];
	if(self)
	{
		data = [[NSData alloc] initWithBytesNoCopy:calloc(256, sizeof(unsigned char)) length:256 freeWhenDone:YES];
		dataPtr = (uint8_t*)data.bytes;
		
		[self startPacketWithCommand:command];
	}
	return self;
}

- (void)startPacketWithCommand:(uint8_t)command
{
	writePos=0;
	crc = 0x0;
	dataPtr[writePos++] = kStartByte;
	dataPtr[writePos++] = 0; // just to avoid confusion (the length byte goes here)
	[self add8:command];
}

- (void)add8:(uint8_t)value
{
	dataPtr[writePos++] = value;
	[self crc_ibutton_update:value];
}

- (void)add16:(uint16_t)value
{
	uint16_t lilEndianValue = CFSwapInt16HostToLittle(value);
	[self add8:(unsigned char) (lilEndianValue & 0xff)];
	[self add8:(unsigned char) ((lilEndianValue >> 8) & 0xff)];
}

- (void)add32:(uint32_t)value;
{
	uint32_t lilEndianValue = CFSwapInt32HostToLittle(value);
	[self add8:(unsigned char) (lilEndianValue & 0xff)];
	[self add8:(unsigned char) ((lilEndianValue >> 8) & 0xff)];
	[self add8:(unsigned char) ((lilEndianValue >> 16) & 0xff)];
	[self add8:(unsigned char) ((lilEndianValue >> 24) & 0xff)];
}

- (uint8_t*)rawPacketPtr
{
	if(dataPtr[1]==0) // Avoid side effects on multiple calls
	{
		dataPtr[writePos++] = crc;
		dataPtr[1] = (uint8_t)(writePos-3); // len does not count packet header & crc
	}
	return dataPtr;
}

- (NSData*)packet
{
	uint8_t* tmp = self.rawPacketPtr;
	NSInteger len = writePos;
	NSData* packetData = [NSData dataWithBytesNoCopy:tmp length:len freeWhenDone:NO];
	
	return packetData;
}


- (void)crc_ibutton_update:(uint8_t)value
{
	crc = (crc ^ value) & 0xff; // i loathe java's promotion rules
	for (int i = 0; i < 8; i++) {
		if ((crc & 0x01) != 0) {
			crc = ((crc >> 1) ^ 0x8c) & 0xff;
		} else {
			crc = (crc >> 1) & 0xff;
		}
	}
}

- (uint8_t)crc
{
	return (uint8_t)crc;
}
@end
