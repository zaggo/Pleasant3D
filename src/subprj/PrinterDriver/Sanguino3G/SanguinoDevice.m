//
//  SerialPort.m
//  Sanguino3G
//
//  Created by Eberhard Rensch on 16.03.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import "SanguinoDevice.h"
#import "PacketBuilder.h"
#import "PacketResponse.h"
#import "Sanguino3G.h"

#define EEPROM_CHECK_LOW 0x5A
#define EEPROM_CHECK_HIGH 0x78

/// EEPROM map:
/// 00-01 - EEPROM data version
/// 02    - Axis inversion byte
/// 32-47 - Machine name (max. 16 chars)
#define EEPROM_CHECK_OFFSET 0
#define EEPROM_MACHINE_NAME_OFFSET 32
#define EEPROM_AXIS_INVERSION_OFFSET 2

#define EEPROM_EC_THERMISTOR_TABLE_OFFSET 0x100
#define EEPROM_EC_R0_OFFSET 0xf0
#define EEPROM_EC_T0_OFFSET 0xf4
#define EEPROM_EC_BETA_OFFSET 0xf8

#define MAX_MACHINE_NAME_LEN 16

@interface SanguinoDevice (Private)
- (PacketResponse*)runCommand:(NSData*)packet;
- (NSInteger)motherboardVersion;
- (NSData*)readFromEEPROMAtOffset:(NSInteger)offset length:(NSInteger)length;
- (void)writeToEEPROMAtOffset:(NSInteger)offset data:(NSData*)data;
- (void)checkEEPROM;
@end

@implementation SanguinoDevice

// Return the driver class, this device driver is part of
- (Class)driverClass
{
	return [Sanguino3G class];
}

- (BOOL)validateSerialDevice
{
	BOOL isValid=NO;
	NSInteger motherboardVersion = [self motherboardVersion];
	if(motherboardVersion>=106)
		isValid=YES;
	return isValid;
}		

- (NSString*)fetchDeviceName
{
	NSString* fetchedName;
	
	[self checkEEPROM];
	NSData* data = [self readFromEEPROMAtOffset:EEPROM_MACHINE_NAME_OFFSET length:MAX_MACHINE_NAME_LEN];
	fetchedName = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
	NSUInteger end = [fetchedName rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location;
	if(end!=NSNotFound)
		fetchedName = [fetchedName substringToIndex:end];
	if([fetchedName length]==0)
		fetchedName = NSLocalizedStringFromTableInBundle(@"MakerBot", nil, [NSBundle bundleForClass:[self class]], @"Localized fallback Display Name for Makerbot");
	return fetchedName;
}

- (PacketResponse*)runCommandWithRawPacket:(uint8_t*)packetBytes packetLength:(NSInteger)packetLength
{
	PacketResponse* response = nil;
//	if (packetBytes && packetLength >= 4)
//	{
//		//NSLog(@"Sending %@", [packet description]);
//		ssize_t numBytesSent = write(fileDescriptor, packetBytes, packetLength);
//		if (numBytesSent == -1)
//		{
//			PSErrorLog(@"Error writing to device - %s (%d).", strerror(errno), errno);
//		}
//		
//		//NSLog(@"Waiting for response");
//		response = [[PacketResponse alloc] initQuiet:self.quiet];
//		uint8_t buffer[256];
//		ssize_t numBytesRead=0;
//        do
//        {
//			numBytesRead = read(fileDescriptor, buffer, 255);
//            if (numBytesRead == -1)
//            {
//				PSErrorLog(@"Error reading from printer - %s (%d).", strerror(errno), errno);
//            }
//            else if (numBytesRead > 0)
//            {
//				if([response processBytes:buffer length:numBytesRead])
//                    break; // PacketResponse complete...
//            }
//			//            else
//			//                NSLog(@"Nothing read.");
//        } while (numBytesRead > 0);
//	}
	return response;
}

- (PacketResponse*)runCommand:(NSData*)packet
{
	return [self runCommandWithRawPacket:(uint8_t*)[packet bytes] packetLength:[packet length]];
}

#pragma mark EEPROM
- (void)checkEEPROM
{
	if (!eepromChecked) 
	{
		NSData* versionData = [self readFromEEPROMAtOffset:EEPROM_CHECK_OFFSET length:2];
		const uint8_t* versionBytes = [versionData bytes];
		if(versionBytes)
		{
			if ((versionBytes[0] != EEPROM_CHECK_LOW) ||
				(versionBytes[1] != EEPROM_CHECK_HIGH)) 
			{
				NSLog(@"Cleaning EEPROM");
				
				// Wipe EEPROM
//				NSMutableData *eepromWipe = [[NSMutableData alloc] initWithLength:16];
//				for (int i = 16; i < 256; i+=16)
//					[self writeToEEPROMAtOffset:i data:eepromWipe];
//
//				uint8_t* eepromWipeBytes = [eepromWipe mutableBytes];
//				eepromWipeBytes[0] = EEPROM_CHECK_LOW;
//				eepromWipeBytes[1] = EEPROM_CHECK_HIGH;
//				[self writeToEEPROMAtOffset:0 data:eepromWipe];
			}
			eepromChecked = YES;
		}
	}
}

- (void)writeToEEPROMAtOffset:(NSInteger)offset data:(NSData*)data
{
	PacketBuilder* pb = [[PacketBuilder alloc] initWithCommand:kMasterWRITE_EEPROM];
	[pb add16:offset];
	uint8_t len = [data length];
	[pb add8:len];
	const uint8_t* bytes = [data bytes];
	for(uint8_t i=0; i<len;i++)
		[pb add8:bytes[i]];

	PacketResponse* pr = [self runCommand:pb.packet];
	if([pr get8] != len)
		PSErrorLog(@"writeToEEPROM failed, written %d bytes, received %d confirmed bytes");
}

- (NSData*)readFromEEPROMAtOffset:(NSInteger)offset length:(NSInteger)length
{
	NSData* readBytes = nil;
	
	PacketBuilder* pb = [[PacketBuilder alloc] initWithCommand:kMasterREAD_EEPROM];
	[pb add16:offset];
	[pb add8:length];

	PacketResponse* pr = [self runCommand:pb.packet];
	if(pr.isOk)
	{
		int rvlen = MIN(pr.payload.length - 1, length);
		readBytes = [NSData dataWithBytes:((uint8_t*)pr.payload.bytes)+1 length:rvlen];
	}
	return readBytes;
}

#pragma mark -
			 
- (NSInteger)motherboardVersion
{
	NSInteger version = 0;
	
	PacketBuilder* pb = [[PacketBuilder alloc] initWithCommand:kMasterVERSION];
	[pb add16:(uint16_t)13]; // We dont have a host version yet. But this information isn't used in the firmware yet.
	
	PacketResponse* pr = [self runCommand:pb.packet];
	version = [pr get16];
	return version;
}

- (void)changeMachineName:(NSString*)newName
{
	deviceName = [newName copy];
	if (deviceName.length > MAX_MACHINE_NAME_LEN)
		deviceName = [deviceName substringToIndex:MAX_MACHINE_NAME_LEN];
		
	NSMutableData *paddedNameData = [[NSMutableData alloc] initWithLength:MAX_MACHINE_NAME_LEN];
	[paddedNameData replaceBytesInRange:NSMakeRange(0, deviceName.length) withBytes:[[deviceName dataUsingEncoding:NSISOLatin1StringEncoding allowLossyConversion:YES] bytes]];
	
	[self writeToEEPROMAtOffset:EEPROM_MACHINE_NAME_OFFSET data:paddedNameData];
}	 
@end
