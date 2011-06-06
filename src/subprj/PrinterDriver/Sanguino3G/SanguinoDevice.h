//
//  SerialPort.h
//  Sanguino3G
//
//  Created by Eberhard Rensch on 16.03.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <P3DCore/P3DCore.h>

@class PacketResponse;
@interface SanguinoDevice : P3DSerialDevice {
	BOOL eepromChecked;
}

- (PacketResponse*)runCommandWithRawPacket:(uint8_t*)packetBytes packetLength:(NSInteger)packetLength;
- (void)changeMachineName:(NSString*)newName;
@end


enum 
{	kMasterVERSION = 0
	,	kMasterINIT = 1
	,	kMasterGET_BUFFER_SIZE = 2
	,	kMasterCLEAR_BUFFER = 3
	,	kMasterGET_POSITION = 4
	,	kMasterGET_RANGE = 5
	,	kMasterSET_RANGE = 6
	,	kMasterABORT = 7
	,	kMasterPAUSE = 8
	,	kMasterPROBE = 9
	,	kMasterTOOL_QUERY = 10
	,	kMasterIS_FINISHED = 11
	,	kMasterREAD_EEPROM = 12
	,	kMasterWRITE_EEPROM = 13
	
	,	kMasterCAPTURE_TO_FILE = 14
	,	kMasterEND_CAPTURE = 15
	,	kMasterPLAYBACK_CAPTURE =16
	
	,	kMasterRESET = 17
	
	,	kMasterNEXT_FILENAME = 18
	
	// Non-Query commands have a code >= 128
	//,	kMasterQUEUE_POINT_INC = 128  obsolete
	,	kMasterQUEUE_POINT_ABS = 129
	,	kMasterSET_POSITION = 130
	,	kMasterFIND_AXES_MINIMUM = 131
	,	kMasterFIND_AXES_MAXIMUM = 132
	,	kMasterDELAY = 133
	,	kMasterCHANGE_TOOL = 134
	,	kMasterWAIT_FOR_TOOL = 135
	,	kMasterTOOL_COMMAND = 136
	,	kMasterENABLE_AXES = 137
};

enum 
{	kSlaveVERSION = 0
	,	kSlaveINIT = 1
	,	kSlaveGET_TEMP = 2
	,	kSlaveSET_TEMP = 3
	,	kSlaveSET_MOTOR_1_PWM = 4
	,	kSlaveSET_MOTOR_2_PWM = 5
	,	kSlaveSET_MOTOR_1_RPM = 6
	,	kSlaveSET_MOTOR_2_RPM = 7
	,	kSlaveSET_MOTOR_1_DIR = 8
	,	kSlaveSET_MOTOR_2_DIR = 9
	,	kSlaveTOGGLE_MOTOR_1 = 10
	,	kSlaveTOGGLE_MOTOR_2 = 11
	,	kSlaveTOGGLE_FAN = 12
	,	kSlaveTOGGLE_VALVE = 13
	,	kSlaveSET_SERVO_1_POS = 14
	,	kSlaveSET_SERVO_2_POS = 15
	,	kSlaveFILAMENT_STATUS = 16
	,	kSlaveGET_MOTOR_1_RPM = 17
	,	kSlaveGET_MOTOR_2_RPM = 18
	,	kSlaveGET_MOTOR_1_PWM = 19
	,	kSlaveGET_MOTOR_2_PWM = 20
	,	kSlaveSELECT_TOOL = 21
	,	kSlaveIS_TOOL_READY = 22
	,	kSlaveREAD_FROM_EEPROM = 25
	,	kSlaveWRITE_TO_EEPROM = 26
	,	kSlaveGET_PLATFORM_TEMP = 30
	,	kSlaveSET_PLATFORM_TEMP = 31
};
