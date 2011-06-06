//
//  PacketResponse.h
//  Sanguino3G
//
//  Created by Eberhard Rensch on 16.03.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PacketResponse : NSObject {
	BOOL quiet;
	
	NSInteger packetState;

	NSMutableData* payload;
	uint8_t payloadLength;
	uint8_t crc;
}

@property (readonly) NSData* payload;
@property (readonly) uint8_t responseCode;
@property (readonly) BOOL isOk;
@property (assign) BOOL quiet;

- (id) initQuiet:(BOOL)q;

- (BOOL)processBytes:(uint8_t*)bytes length:(NSInteger)length;
- (void)reset;

- (uint8_t)get8;
- (uint16_t)get16;
- (uint32_t)get32;

@end

enum uint8_t {
	kPacketResponseGENERIC_ERROR, 
	kPacketResponseOK, 
	kPacketResponseBUFFER_OVERFLOW, 
	kPacketResponseCRC_MISMATCH, 
	kPacketResponseQUERY_OVERFLOW, 
	kPacketResponseUNSUPPORTED,
	kPacketResponseUNKNOWN
	};
