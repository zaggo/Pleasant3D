//
//  SerialPort.m
//  PleasantMill
//
//  Created by Eberhard Rensch on 16.03.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import "PleasantMillDevice.h"
#import "PleasantMill.h"
#import <P3DCore/AMSerialPortAdditions.h>

@interface PleasantMillDevice (Private)
- (NSInteger)motherboardVersion;
- (NSString*)sendCommandSynchron:(NSString*)cmd;
@end

@implementation PleasantMillDevice

// Return the driver class, this device driver is part of
- (Class)driverClass
{
	return [PleasantMill class];
}

- (NSInteger)baudRate
{
    return B115200;
}

- (BOOL)validateSerialDevice
{
	BOOL isValid=NO;
	NSString* received = [self sendCommandSynchron:@"M900"]; // Ask for firmware version
	if(received && [received rangeOfString:@"PleasantMill"].location != NSNotFound)
		isValid=YES;
	return isValid;
}		

- (NSString*)fetchDeviceName
{
	NSString* fetchedName=[self sendCommandSynchron:@"M901"];
    if([fetchedName hasPrefix:@"ok"])
        fetchedName = [[fetchedName substringFromIndex:3] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    else
        fetchedName = @"<Error>";

	return fetchedName;
}

- (NSString*)sendCommandSynchron:(NSString*)cmd
{
    NSString* response=nil;
	if ([cmd length]>0)
	{
        NSError* error=nil;
		NSString* sendString = [cmd stringByAppendingString:@"\r"];
        if([port isOpen]) {
            if(![port writeString:sendString usingEncoding:NSUTF8StringEncoding error:&error] && !quiet)
                PSErrorLog(@"Error writing to device - %@.", [error description]);
		}
        NSTimeInterval oldTimeout = [port readTimeout];
        [port setReadTimeout:4.];
        response = [port readUpToChar:(char)'\n' usingEncoding:NSUTF8StringEncoding error:&error];
        if(response==nil && !quiet)
            PSErrorLog(@"Error reading from printer - %@.", [error description]);
        [port setReadTimeout:oldTimeout];
	}
	return response;
}

#pragma mark -
			 
- (void)changeMachineName:(NSString*)newName
{
	NSString* response=[self sendCommandSynchron:[NSString stringWithFormat:@"M902 \"%@\"", [newName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]]];
    if([response hasPrefix:@"ok"])    
        deviceName = [newName copy];
    else
        PSErrorLog(@"Error when trying to write device name to machine: %@", response);
}	 
@end
