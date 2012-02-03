//
//  AvailableDevices.m
//  P3DCore
//
//  Created by Eberhard Rensch on 16.03.10.
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
#import "AvailableDevices.h"
#import <dispatch/dispatch.h>
#import "P3DSerialDevice.h"
#import "ConfiguredMachines.h"

#import "AMSerialPortList.h"
#import "AMSerialPortAdditions.h"

// Needed for _NSGetArgc/_NSGetArgv
// "crt_externs.h" has no C++ guards [3126393], so we have to provide them 
// ourself otherwise we get a link error.
#ifdef __cplusplus
extern "C" {
#endif
#include <crt_externs.h>
#ifdef __cplusplus
}
#endif

#define SHOW_UNDISCOVERED_DEVICES 1

@interface AvailableDevices (Private)
- (void)didAddPorts:(NSNotification *)theNotification;
@end

@implementation AvailableDevices
@synthesize discovering;
@dynamic availableDevices;

+ (AvailableDevices*)sharedInstance
{
	static AvailableDevices* _singleton = nil;
	static dispatch_once_t	justOnce=(dispatch_once_t)nil;
	dispatch_once(&justOnce, ^{
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"ExperimentalMachineDriverSupport"])
		{
            _singleton = [[AvailableDevices alloc] init];
        }
    });
	return _singleton;
}

- (id) init
{
	self = [super init];
	if (self != nil) {
		availableSerialDevices = [[NSMutableArray alloc] init];
		availableDrivers = [[NSMutableArray alloc] init];
		
		// Find all available 3D Machine Drivers
		__block NSError* error;
		NSFileManager* fm = [NSFileManager defaultManager];
		
		// Search order: ~/Library/AppSupport, /Library/AppSupport, inside app's plugins
		NSMutableArray* bundlePaths = [NSMutableArray array];
		NSMutableArray*	bundleSearchPaths = [NSMutableArray array];
		
		// Special feature for Developers: Launch argument -p<path> sets additional directory for searching
		// of printer drivers. Since the import algorithm does only load the first instance of a driver (dependant on
		// the plugins CFBundleIdentifier), this mechanism can also be used to temporary overwrite an existing driver
		int* argc = _NSGetArgc();
		char***argv=_NSGetArgv();
		for(int i=1;i<*argc;i++)
		{
			NSString* arg = [NSString stringWithCString:(*argv)[i] encoding:NSUTF8StringEncoding];
			if([arg hasPrefix:@"-m"])
			{
				NSString* pluginPath = [arg substringFromIndex:[@"-m" length]];
				NSLog(@"Additional bundleSearchPaths for MachineDriver added: %@",pluginPath);
				[bundleSearchPaths addObject:pluginPath];
			}
		}
		
		NSBundle* mainBundle = [NSBundle mainBundle];
		NSString* printerDriverSubPath = @"MachineDrivers";
		NSString* appName = [[mainBundle infoDictionary] objectForKey:@"CFBundleName"];
		if(appName)
		{
			NSArray* librarySearchPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
			for(NSString* librarySearchPath in librarySearchPaths)
			{
				NSString* appSupPath = [[librarySearchPath stringByAppendingPathComponent:appName] stringByAppendingPathComponent:printerDriverSubPath];
				[bundleSearchPaths addObject:appSupPath];
				if(![fm fileExistsAtPath:appSupPath])
					[fm createDirectoryAtPath:appSupPath withIntermediateDirectories:YES attributes:nil error:&error];
			}
			librarySearchPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSLocalDomainMask, YES);
			for(NSString* librarySearchPath in librarySearchPaths)
			{
				[bundleSearchPaths addObject:[[librarySearchPath stringByAppendingPathComponent:appName] stringByAppendingPathComponent:printerDriverSubPath]];
			}
		}
		[bundleSearchPaths addObject:[[[mainBundle bundlePath] stringByAppendingPathComponent:@"Contents"] stringByAppendingPathComponent:printerDriverSubPath]];
		
		[bundleSearchPaths enumerateObjectsUsingBlock:^(id currPath, NSUInteger idx, BOOL *stop) {
			NSArray* candidates = [fm contentsOfDirectoryAtPath:currPath error:&error];
			for(NSString* currBundlePath in candidates)
			{
				if ([[currBundlePath pathExtension] isEqualToString:@"bundle"])
				{
					// we found a bundle, add it to the list
					[bundlePaths addObject:[currPath stringByAppendingPathComponent:currBundlePath]];
				}
			}
		}];

		NSMutableArray* alreadyImportedDrivers = [NSMutableArray array];
		for(NSString* bundlePath in bundlePaths)
		{
			NSBundle* driverBundle = [NSBundle bundleWithPath:bundlePath];
			NSString* identifier = [[driverBundle infoDictionary] objectForKey:@"CFBundleIdentifier"];
			if(![alreadyImportedDrivers containsObject:identifier])
			{
				Class pClass = [driverBundle principalClass];
				if([pClass isSubclassOfClass:[P3DMachineDriverBase class]])
				{
					PSLog(@"Machining",PSPrioNormal,@"Found driver plugin: %@",NSStringFromClass(pClass));
					[alreadyImportedDrivers addObject:identifier];
					[availableDrivers addObject:pClass];
				}
			}
		}
	}
	return self;
}

- (void)startup
{
    if(!started)
    {
        started=YES;
        /// set up notifications
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didAddPorts:) name:AMSerialPortListDidAddPortsNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRemovePorts:) name:AMSerialPortListDidRemovePortsNotification object:nil];

        AMSerialPortList* portList = [AMSerialPortList sharedPortList];
        NSArray* ports = [portList serialPortsOfType:(NSString*)CFSTR(kIOSerialBSDRS232Type)];
        [self didAddPorts:[NSNotification notificationWithName:AMSerialPortListDidAddPortsNotification object:self userInfo:[NSDictionary dictionaryWithObject:ports forKey:AMSerialPortListAddedPorts]]];
    }
}

+ (NSSet *)keyPathsForValuesAffectingAvailableDevices {
    return [NSSet setWithObjects:@"availableSerialDevices", @"availableDrivers", @"discovering", nil];
}

# pragma mark Notifications

- (void)didAddPorts:(NSNotification *)theNotification
{
	NSLog(@"A port was added");
    
    self.discovering = YES;

    NSArray* addedPorts = [[theNotification userInfo] objectForKey:AMSerialPortListAddedPorts];
    NSMutableArray* newDevices = [[NSMutableArray alloc] initWithCapacity:addedPorts.count];
    dispatch_group_t dpGroup = dispatch_group_create();
    dispatch_queue_t globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        
    // Iterate across all serial devices found.
    for(AMSerialPort* port in addedPorts)
    {
        BOOL alreadyValidated=NO;
        for(P3DSerialDevice* device in availableSerialDevices)
        {
            if([[port bsdPath] isEqualToString:[device.port bsdPath]])
            {
                alreadyValidated=YES;
                break;
            }
        }
        if(!alreadyValidated)
        {
            dispatch_group_async(dpGroup, globalQueue, ^{        
                for(Class driverClass in availableDrivers)
                {
                    Class deviceDriverClass = [driverClass deviceDriverClass];
                    if(deviceDriverClass)
                    {
                        P3DSerialDevice* device = [[deviceDriverClass alloc] initWithPort:port];
                        device.quiet=YES;
                        if([device registerDeviceIfValid])
                        {
                            device.quiet=NO;
                            dispatch_async(dispatch_get_main_queue(), ^{
                                NSLog(@"Discovered Valid Serial Service %@. Checking for known drivers", [port name]);
                                [newDevices addObject:device];
                                [self willChangeValueForKey:@"availableDevices"];
                                [availableSerialDevices addObject:device];
                                [self didChangeValueForKey:@"availableDevices"];
                            });
                            break;
                        }
                    }
                }
            });
        }
    }
    
    dispatch_async(globalQueue, ^{
        dispatch_group_wait(dpGroup, DISPATCH_TIME_FOREVER);
        dispatch_release(dpGroup);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[ConfiguredMachines sharedInstance] reconnectDevices:newDevices];
            self.discovering = NO;
            PSLog(@"Machining",PSPrioNormal,@"End of port discovery");
       });
    });
}

- (void)didRemovePorts:(NSNotification *)theNotification
{
	NSLog(@"A port was removed");
	[self willChangeValueForKey:@"availableDevices"];
	for(AMSerialPort* port in [[theNotification userInfo] objectForKey:AMSerialPortListRemovedPorts])
    {
        NSLog(@"%@", [port description]);
        for(P3DSerialDevice* device in availableSerialDevices)
        {
            if([[device.port bsdPath] isEqualToString:[port bsdPath]])
            {
                [availableSerialDevices removeObject:device];
                break;
            }
        }
    }
	[self didChangeValueForKey:@"availableDevices"];
}

- (NSArray*)availableDevices
{
    [self startup];
	NSMutableArray* undiscoveredDrivers = [NSMutableArray arrayWithArray:availableDrivers];
	NSMutableArray* availableMachines = [NSMutableArray array];
	for(P3DSerialDevice* device in availableSerialDevices)
	{
		NSDictionary* machineDict = [NSDictionary dictionaryWithObjectsAndKeys:
									 device.deviceName, @"deviceName",
									 [device.driverClass driverName], @"driverName",
									 [[device.port bsdPath] lastPathComponent], @"serialPort",
									 device, @"device",
									 nil];
									 
		[undiscoveredDrivers removeObject:device.driverClass];
		[availableMachines addObject:machineDict];
	}
	
	[availableMachines sortUsingComparator:^(id obj1, id obj2) {
		return [(NSString*)[obj1 objectForKey:@"deviceName"] compare:[obj2 objectForKey:@"deviceName"] options:NSCaseInsensitiveSearch];
	}];
#ifdef SHOW_UNDISCOVERED_DEVICES	 
	[undiscoveredDrivers sortUsingComparator:^(id obj1, id obj2) {
		return [(NSString*)[obj1 defaultMachineName] compare:[obj2 defaultMachineName] options:NSCaseInsensitiveSearch];
	}];
	
	for(Class driverClass in undiscoveredDrivers)
	{
        NSString* status = NSLocalizedStringFromTableInBundle(@"Offline", nil, [NSBundle bundleForClass:[self class]], @"Localized Machine Connection Status");
        if(discovering)
            status = NSLocalizedStringFromTableInBundle(@"Searching\\U2026", nil, [NSBundle bundleForClass:[self class]], @"Localized Machine Connection Status");
		NSDictionary* machineDict = [NSDictionary dictionaryWithObjectsAndKeys:
									 [driverClass defaultMachineName], @"deviceName",
									 [driverClass driverName], @"driverName",
									 status, @"serialPort",
									 NSStringFromClass(driverClass), @"driverClassName",
									 nil];
		
		[availableMachines addObject:machineDict];
	}
#endif
	return availableMachines;
}


- (P3DSerialDevice*)reconnectDevice:(Class)deviceDriverClass withBSDPath:(NSString*)bsdPath
{
    P3DSerialDevice* foundDevice=nil;
    
    if(deviceDriverClass)
    {
        for(P3DSerialDevice* device in availableSerialDevices)
        {
            if([bsdPath isEqualToString:[device.port bsdPath]] && [deviceDriverClass isKindOfClass:device.driverClass])
            {
                foundDevice = device;
                break;
            }
        }
        NSArray* ports = nil;
        if(foundDevice==nil) // Nothing found yet
        {        
            AMSerialPortList* portList = [AMSerialPortList sharedPortList];
            ports = [portList serialPortsOfType:(NSString*)CFSTR(kIOSerialBSDRS232Type)];
            for(AMSerialPort* port in ports)
            {
                if([[port bsdPath] isEqualToString:bsdPath])
                {
                    P3DSerialDevice* device = [[deviceDriverClass alloc] initWithPort:port];
                    device.quiet=YES;
                    if([device registerDeviceIfValid])
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self willChangeValueForKey:@"availableDevices"];
                            [availableSerialDevices addObject:device];
                            [self didChangeValueForKey:@"availableDevices"];
                        });
                        foundDevice = device;
                        device.quiet=NO;
                    }
                    break;
                }
            }
        }
        if(foundDevice==nil) // Nothing found yet
        {
            for(AMSerialPort* port in ports)
            {
            }
        }
    }
    return foundDevice;
}

@end
