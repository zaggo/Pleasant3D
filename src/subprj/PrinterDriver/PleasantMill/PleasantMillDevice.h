//
//  SerialPort.h
//  PleasantMill
//
//  Created by Eberhard Rensch on 16.03.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <P3DCore/P3DCore.h>

enum {
    kFirmwareMinMajor=0,
    kFirmwareMinMinor=5,
    kFirmwareMinBugfix=0
};

enum {
    kErrorCodeMachineNotArmed = 1,
    kErrorCodeLineNumberWithoutChecksum,
    kErrorCodeChecksumWithoutLineNumber,
    kErrorCodeChecksumMismatch,
    kErrorCodeLineNumberNotLastPlusOne,
    kErrorCodeDudGcode,
    kErrorCodeBadDeviceName,
    kErrorCodeDudMcode,
    kErrorCodeInvalidParameter
};

@interface PleasantMillDevice : P3DSerialDevice {
    CGFloat machinableAreaX;
    CGFloat machinableAreaY;
    CGFloat machinableAreaZ;
}

- (void)changeMachineName:(NSString*)newName;
@end