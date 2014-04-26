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
	if(received) {
        NSError* error=nil;
        NSRegularExpression* regEx = [[NSRegularExpression alloc] initWithPattern:@"com.pleasantsoftware.pleasantmill\\s+\\[(\\d+)\\.(\\d+)\\.(\\d+)\\]" options:NSRegularExpressionCaseInsensitive error:&error];
        NSTextCheckingResult* result = [regEx firstMatchInString:received options:0 range:NSMakeRange(0, received.length)];
        if(result) {
            NSInteger major=0, minor=0, bugfix=0;
            NSRange range = [result rangeAtIndex:1];
            if(range.location != NSNotFound)
                major = [[received substringWithRange:range] integerValue];
            range = [result rangeAtIndex:2];
            if(range.location != NSNotFound)
                minor = [[received substringWithRange:range] integerValue];
            range = [result rangeAtIndex:3];
            if(range.location != NSNotFound)
                bugfix = [[received substringWithRange:range] integerValue];
            PSLog(@"devices", PSPrioNormal, @"Found Pleasant Mill, Firmware: %d.%d.%d", major, minor, bugfix);
            if(major>=kFirmwareMinMajor && minor>=kFirmwareMinMinor && bugfix>=kFirmwareMinBugfix) {
                PSLog(@"devices", PSPrioNormal, @"==> Valid Machine");
                isValid=YES;
            } else {
                PSLog(@"devices", PSPrioNormal, @"Firmware too old. Minimum: %d.%d.%d", kFirmwareMinMajor, kFirmwareMinMinor, kFirmwareMinBugfix);
            }
        }
        
    }
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
        
       // NSDate* timeout = [NSDate dateWithTimeIntervalSinceNow:8.f];
        while(YES) {
            if(_synchronReceivedFlag)
                break;
//            if([timeout timeIntervalSinceNow]>0.f)
//                break;
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
    if(serialPort == port) {
        while([data length] > 0) {
            if(_synchronReceiveMode) {
                if(self.dataBuffer==nil)
                        self.dataBuffer = [NSMutableData data];
                NSRange crRange = [data rangeOfData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding] options:0 range:NSMakeRange(0, data.length)];
                if(crRange.location != NSNotFound) {
                    [self.dataBuffer appendData:[data subdataWithRange:NSMakeRange(0, crRange.location+crRange.length)]];
                        
                    _synchronReceivedResponse = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
                    PSLog("devices", PSPrioNormal, @"Port [%@] received synchron data: %@", [port name], _synchronReceivedResponse);
                    
                    self.dataBuffer = nil;
                    _synchronReceivedFlag=YES;

                    if(crRange.location+crRange.length<data.length)
                        data = [data subdataWithRange:NSMakeRange(crRange.location+crRange.length, data.length-crRange.location-crRange.length)];
                    else
                        data = nil;
                } else {
                    [self.dataBuffer appendData:data];
                    data = nil;
                }
            } else {
                [super serialPort:serialPort didReceiveData:data];
                data = nil;
            }
        }
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
