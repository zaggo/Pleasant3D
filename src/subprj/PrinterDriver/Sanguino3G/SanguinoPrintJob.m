//
//  SanguinoPrintJob.m
//  Sanguino3G
//
//  Created by Eberhard Rensch on 11.04.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import "SanguinoPrintJob.h"
#import "SanguinoDevice.h"
#import "PacketResponse.h"

@implementation SanguinoPrintJob

- (id)initWithBytecodeBuffers:(NSArray*)buffers;

{
	self = [super init];
	if (self != nil) {
		bytecodeBuffers = buffers;
	}
	return self;
}

- (void)implProcessJob
{
	float totalLength = 0.f;
	for(NSData* bytecodeBuffer in bytecodeBuffers)
	{
		totalLength+=(float)bytecodeBuffer.length;
	}
	
	float sentLength = 0.f;
	float percent = 0.f;
	
	SanguinoDevice* device = (SanguinoDevice*)(self.driver.currentDevice);
	for(NSData* bytecodeBuffer in bytecodeBuffers)
	{
		NSInteger readPos = 0;
		uint8_t* bytecodePtr = (uint8_t*)bytecodeBuffer.bytes;
		
		while(readPos<bytecodeBuffer.length && !self.jobAbort) // self.jobAbort might be set from user...
		{
			NSInteger packetLength = (NSInteger)bytecodePtr[readPos+1]+3; // + Packetheader (2) + CRC (1)
			BOOL packetSent = NO;
			while(!packetSent && !self.jobAbort)
			{
				if(device.deviceIsValid)
				{
					PacketResponse* response = [device runCommandWithRawPacket:bytecodePtr+readPos packetLength:packetLength];
					switch(response.responseCode)
					{
						case kPacketResponseOK:
							packetSent = YES;
							break;
						case kPacketResponseBUFFER_OVERFLOW:
							usleep(25);
							break;
						default:
							// TODO: Error handling
							PSErrorLog(@"Error during sending print job");
							self.jobAbort = YES;
							break;
					}
				}
				else
				{
					// TODO: Error handling
					self.jobAbort = YES;
					break;
				}
			}
			readPos+=packetLength;
			
			sentLength+=(float)packetLength;
			percent = sentLength/totalLength;
			if((NSInteger)(self.progress*100.f)<(NSInteger)(percent*100.f))
				dispatch_async(dispatch_get_main_queue(), ^{
					self.progress = percent;
					NSLog(@"Sent Job: %f%%",(percent*100.f));
				});
		}
		
		if(self.jobAbort)
			break;
	}
}

@end
