//
//  SerialPort.m
//  PleasantMill
//
//  Created by Eberhard Rensch on 16.03.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import "PleasantMillDevice.h"
#import "PleasantMill.h"

@interface PleasantMillDevice (Private)
- (NSInteger)motherboardVersion;
- (NSString*)sendCommandSynchron:(NSString*)cmd;
@end

@implementation PleasantMillDevice
{
    BOOL _synchronReceivedFlag;
    BOOL _synchronReceiveMode;
    NSString* _synchronReceivedResponse;
}

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

// TODO: This code needs to be rewritten (block based code)
- (NSString*)sendCommandSynchron:(NSString*)cmd
{
    _synchronReceivedResponse=nil;
	if ([cmd length]>0)
	{
        _synchronReceivedFlag = NO;
        _synchronReceiveMode = YES;
		NSString* sendString = [cmd stringByAppendingString:@"\r"];
        if([port isOpen]) {
            if(![port sendData:[sendString dataUsingEncoding:NSUTF8StringEncoding]] && !quiet)
                 PSErrorLog(@"Error writing to device "); // TODO Error Handling via serialPort:didEncounterError: delegate method
		}
        
        NSDate* timeout = [NSDate dateWithTimeIntervalSinceNow:4.f];
        while(!_synchronReceivedFlag && [timeout timeIntervalSinceNow]<0.f)
        {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.1]];
        }
        _synchronReceiveMode = NO;

        if([_synchronReceivedResponse rangeOfString:@"\n"].location!=NSNotFound)
            _synchronReceivedResponse = [_synchronReceivedResponse substringToIndex:[_synchronReceivedResponse rangeOfString:@"\n"].location];
        if(_synchronReceivedResponse==nil && !quiet)
            PSErrorLog(@"Error reading from printer");
	}
	return _synchronReceivedResponse;
}

- (void)serialPort:(ORSSerialPort *)serialPort didReceiveData:(NSData *)data
{
    if(_synchronReceiveMode)
    {
        if ([data length] > 0) {
            _synchronReceivedResponse = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
            _synchronReceivedFlag=YES;
        } else {
            // port closed
            PSErrorLog(@"Port was closed on a readData operation...not good!");
        }
    }
    else
    {
        [super serialPort:serialPort didReceiveData:data];
    }
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
