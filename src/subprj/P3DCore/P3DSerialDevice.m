//
//  P3DSerialDevice.m
//  P3DCore
//
//  Created by Eberhard Rensch on 17.03.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify it under
//  the terms of the GNU General Public License as published by the Free Software 
//  Foundation; either version 3 of the License, or (at your option) any later 
//  version.
// 
//  This program is distributed in the hope that it will be useful, but WITHOUT ANY 
//  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A 
//  PARTICULAR PURPOSE. See the GNU General Public License for more details.
// 
//  You should have received a copy of the GNU General Public License along with 
//  this program; if not, see <http://www.gnu.org/licenses>.
// 
//  Additional permission under GNU GPL version 3 section 7
// 
//  If you modify this Program, or any covered work, by linking or combining it 
//  with the P3DCore.framework (or a modified version of that framework), 
//  containing parts covered by the terms of Pleasant Software's software license, 
//  the licensors of this Program grant you additional permission to convey the 
//  resulting work.
//
#import "P3DSerialDevice.h"
#import "AvailableDevices.h"
#import "AMSerialPortAdditions.h"

@interface P3DSerialDevice (Private)
- (BOOL)openSerialPort;
- (void)closeSerialPort;
@end


@implementation P3DSerialDevice
@synthesize port, deviceName, deviceIsValid, quiet, errorMessage, activeMachineJob;
@dynamic driverClass, baudRate, deviceIsBusy;

- (id)initWithPort:(AMSerialPort*)p
{
    self = [super init];
    if(self)
    {
        port = p;
    }
    return self;
}

- (void)finalize
{
	[port close];
	[super finalize];
}

- (BOOL)registerDeviceIfValid
{
    PSLog(@"Machining",PSPrioNormal, @"Trying %@ on %@",[port name], [self className]);
    if ([port open]) {
        //Then I suppose we connected!
        //NSLog(@"successfully connected");
        [port setSpeed:self.baudRate];
        if([self validateSerialDevice])
        {
            deviceName = [self fetchDeviceName];
            self.deviceIsValid = YES;
            
            // listen for data in a separate thread
            [port readDataInBackground];
        }
        
    }
    return deviceIsValid;
}

- (NSError*)sendStringAsynchron:(NSString*)string
{
    NSError* error=nil;
	if ([string length]>0)
	{
        if([port isOpen]) {
            if(![port writeString:string usingEncoding:NSUTF8StringEncoding error:&error] && !quiet)
                PSErrorLog(@"Error writing to device - %@.", [error description]);
        }
    }
    return error;
}

- (void)serialPortReadData:(NSDictionary *)dataDictionary
{
    NSData *data = [dataDictionary objectForKey:@"data"];
	if ([data length] > 0) {
		
		NSString *receivedText = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
		NSLog(@"Serial Port Data Received: %@",receivedText);
        
        [activeMachineJob handleDeviceResponse:receivedText];

        // continue listening
		[port readDataInBackground];
		
	} else { 
		// port closed
		NSLog(@"Port was closed on a readData operation...not good!");
	}
	
}

- (NSInteger)baudRate
{
    return B38400;
}

#pragma mark -

// These methods must be overloaded
- (NSString*)fetchDeviceName
{
	return [port name];
}

- (BOOL)validateSerialDevice
{
	return NO;
}

// Return the driver class, this device driver is part of
- (Class)driverClass
{
	return nil;
}

+ (NSSet *)keyPathsForValuesAffectingDeviceIsBusy {
    return [NSSet setWithObjects:@"activeMachineJob", nil];
}

- (BOOL)deviceIsBusy
{
    return activeMachineJob!=nil;
}
@end
