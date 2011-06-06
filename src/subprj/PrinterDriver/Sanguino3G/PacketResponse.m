//
//  PacketResponse.m
//  Sanguino3G
//
//  Created by Eberhard Rensch on 16.03.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import "PacketResponse.h"
#import "PacketBuilder.h"
#import <P3DCore/P3DCore.h>

enum { kPacketStateSTART, kPacketStateLEN, kPacketStatePAYLOAD, kPacketStateCRC, kPacketStateLAST };

@implementation PacketResponse
@synthesize payload, quiet;
@dynamic isOk, responseCode;

- (id) initQuiet:(BOOL)q
{
	self = [super init];
	if (self != nil) {
		quiet=q;
		packetState = kPacketStateSTART;
	}
	return self;
}


- (void)crc_ibutton_update:(uint8_t)value
{
	crc = crc ^ value;
	for (uint8_t i = 0; i < 8; i++)
	{
		if (crc & 0x01)
			crc = (crc >> 1) ^ 0x8C;
		else
			crc >>= 1;
	}
}

- (void)reset
{
	packetState = kPacketStateSTART;
	payload=nil;
}

- (BOOL)processBytes:(uint8_t*)bytes length:(NSInteger)length
{
	BOOL complete = NO;
	for(NSInteger i = 0; i<length && !complete; i++)
	{
		uint8_t byte = bytes[i];
		
		switch (packetState)
		{
			case kPacketStateSTART:
				if (byte == kStartByte)
					packetState = kPacketStateLEN;
				break;
			
			case kPacketStateLEN:
				payloadLength = byte;
				payload = [[NSMutableData alloc] initWithCapacity:payloadLength];
				packetState = kPacketStatePAYLOAD;
				break;
			
			case kPacketStatePAYLOAD:
				[payload appendBytes:&byte length:1];
				[self crc_ibutton_update:byte];
				if ([payload length] >= payloadLength)
					packetState = kPacketStateCRC;
				break;
			
			case kPacketStateCRC:
				if(!quiet)
				{
					if (crc != byte)
						PSErrorLog(@"CRC mismatch on reply");
//					else
//						NSLog(@"Packet successfully received: %@", [payload description]);
				}
				complete=YES;
				break;
		}
	}
	return complete;
}

- (uint8_t)get8
{
	uint8_t byte = 0x0;
	
	if ([payload length]>0)
	{
		byte = ((uint8_t*)[payload bytes])[0];
		[payload replaceBytesInRange:NSMakeRange(0,1) withBytes:NULL length:0];
	}
	else if(!quiet)
		PSErrorLog(@"Error: payload not big enough.");
	return byte;
}

- (uint16_t)get16
{
	uint16_t word = 0x0;
	
	if ([payload length]>1)
	{
		word = CFSwapInt16LittleToHost(*((uint16_t*)[payload bytes]));
		[payload replaceBytesInRange:NSMakeRange(0,2) withBytes:NULL length:0];
	}
	else if(!quiet)
		PSErrorLog(@"Error: payload not big enough.");
	return word;
}

- (uint32_t)get32
{
	uint32_t longword = 0x0;
	
	if ([payload length]>3)
	{
		longword = CFSwapInt32LittleToHost(*((uint32_t*)[payload bytes]));
		[payload replaceBytesInRange:NSMakeRange(0,4) withBytes:NULL length:0];
	}
	else if(!quiet)
		PSErrorLog(@"Error: payload not big enough.");
	return longword;
}

- (uint8_t)responseCode
{
	if([payload bytes])
		return ((uint8_t*)[payload bytes])[0];
	return kPacketResponseUNKNOWN;
}

- (BOOL)isOk
{
	return (self.responseCode == kPacketResponseOK);
}
@end
