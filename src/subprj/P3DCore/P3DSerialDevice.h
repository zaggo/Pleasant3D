//
//  P3DSerialDevice.h
//  P3DCore
//
//  Created by Eberhard Rensch on 17.03.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
//#import <termios.h>
#import <P3DCore/P3DCore.h>
#import "AMSerialPort.h"

@class P3DMachineJob;
@interface P3DSerialDevice : NSObject {
	BOOL quiet;
    
    AMSerialPort* port;
    NSString* deviceName;

	BOOL deviceIsValid;
	NSString* errorMessage;
    P3DMachineJob* activeMachineJob;
}

@property (readonly) AMSerialPort* port;
@property (readonly) NSString* deviceName;
@property (readonly) Class	  driverClass;
@property (assign) BOOL deviceIsValid;
@property (readonly) BOOL deviceIsBusy;
@property (assign) BOOL quiet;
@property (assign) P3DMachineJob* activeMachineJob;
@property (copy) NSString* errorMessage;
@property (readonly) NSInteger baudRate;

- (id)initWithPort:(AMSerialPort*)port;
- (BOOL)registerDeviceIfValid;

// Overload in derivates:
- (BOOL)validateSerialDevice;
- (NSString*)fetchDeviceName;
- (NSError*)sendStringAsynchron:(NSString*)string;

@end
