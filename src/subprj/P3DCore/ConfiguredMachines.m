//
//  ConfiguredMachines.m
//  P3DCore
//
//  Created by Eberhard Rensch on 01.04.10.
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
#import "ConfiguredMachines.h"
#import "P3DSerialDevice.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <P3DCore/P3DCore.h>

@implementation ConfiguredMachines
@synthesize configuredMachines;

+ (ConfiguredMachines*)sharedInstance
{
	static ConfiguredMachines* _singleton = nil;
	static dispatch_once_t	justOnce=(dispatch_once_t)nil;
    dispatch_once(&justOnce, ^{
		_singleton = [[ConfiguredMachines alloc] init];
    });
	return _singleton;
}

+ (void)initialize
{
//	CFStringEncoding theEncoding;
//	SCDynamicStoreRef dynRef = SCDynamicStoreCreate(kCFAllocatorSystemDefault, CFSTR("MyName"), NULL, NULL); 
//	CFStringRef computerName = SCDynamicStoreCopyComputerName(dynRef, &theEncoding);
//	
//	NSString* localComputerName = [(NSString*)computerName copy];
//	CFRelease(computerName);
//	CFRelease(dynRef);
//	
//	NSString* defaultMachineUUID = [[NSUserDefaults standardUserDefaults] objectForKey:@"defaultMachine"];
	
//	NSMutableDictionary *ddef = [NSMutableDictionary dictionary];
//	[ddef setObject:@"Sanguino3G" forKey:@"driverClassName"];
//	[ddef setObject:defaultMachineUUID forKey:@"uuid"];
//	[ddef setObject:@"MakerBot" forKey:@"localMachineName"];
//	[ddef setObject:localComputerName forKey:@"locationString"];
//	NSArray* darr = [NSArray arrayWithObject:ddef];
//		
//	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObject:darr forKey:@"configuredMachines"]];
}

- (id) init
{
	self = [super init];
	if (self != nil) {
		configuredMachines = [[NSMutableArray alloc] init];
		NSArray* configs = [[NSUserDefaults standardUserDefaults] objectForKey:@"configuredMachines"];
		for(NSDictionary* dict in configs)
		{
			Class driverClass = NSClassFromString([dict objectForKey:@"driverClassName"]);
			if(driverClass)
			{
				P3DMachineDriverBase* driver = [[driverClass alloc] initWithOptionPropertyList:[dict objectForKey:@"driverOptions"]];
                if([dict objectForKey:@"lastKnownBSDPath"])
                    driver.lastKnownBSDPath = [dict objectForKey:@"lastKnownBSDPath"];
				NSMutableDictionary* printerDict = [NSMutableDictionary dictionaryWithDictionary:dict];
				[printerDict removeObjectForKey:@"driverClassName"];
				[printerDict setObject:driver forKey:@"driver"];
				[configuredMachines addObject:printerDict];
			}
		}
	}
	return self;
}

- (void)syncConfiguredMachinesToPreferences
{
	NSMutableArray* configs = [NSMutableArray array];
	for(NSDictionary* dict in configuredMachines)
	{
		NSMutableDictionary* conf = [NSMutableDictionary dictionaryWithDictionary:dict];
		P3DMachineDriverBase* driver = [dict objectForKey:@"driver"];
		[conf setObject:NSStringFromClass([driver class]) forKey:@"driverClassName"];
		
		NSDictionary* driverOptions = [driver driverOptionsAsPropertyList];
		if(driverOptions)
			[conf setObject:driverOptions forKey:@"driverOptions"];
		
		[conf removeObjectForKey:@"driver"];
		[conf removeObjectForKey:@"device"];
		[configs addObject:conf];
	}
	[[NSUserDefaults standardUserDefaults] setObject:configs forKey:@"configuredMachines"];
}

- (NSString*)localComputerName
{
	CFStringEncoding theEncoding;
	SCDynamicStoreRef dynRef = SCDynamicStoreCreate(kCFAllocatorSystemDefault, CFSTR("MyName"), NULL, NULL); 
	CFStringRef computerName = SCDynamicStoreCopyComputerName(dynRef, &theEncoding);
	
	NSString* localComputerName = [(NSString*)computerName copy];
	CFRelease(computerName);
	CFRelease(dynRef);
	
	return localComputerName;
}

- (void)addConnectedMachine:(P3DSerialDevice*)device
{
	Class driverClass = device.driverClass;
	P3DMachineDriverBase* driver = [[driverClass alloc] init];
	NSMutableDictionary* printerDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
								 [P3DToolBase uuid], @"uuid",
								 device, @"device",
								 [device.port bsdPath], @"lastKnownBSDPath",
								 device.deviceName, @"localMachineName",
								 driver, @"driver",
								 [self localComputerName], @"locationString",
								 nil];
	[self willChangeValueForKey:@"configuredMachines"];
	[[printerDict objectForKey:@"driver"] setCurrentDevice:device];
	[configuredMachines addObject:printerDict];
	[self didChangeValueForKey:@"configuredMachines"];
	[self syncConfiguredMachinesToPreferences];
}

- (void)addUnconnectedMachine:(NSString*)driverClassName
{
	Class driverClass = NSClassFromString(driverClassName);
	P3DMachineDriverBase* driver = [[driverClass alloc] init];
	
	NSMutableDictionary* printerDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
								 [P3DToolBase uuid], @"uuid",
								 [driverClass defaultMachineName], @"localMachineName",
								 driver, @"driver",
								 [self localComputerName], @"locationString",
								 nil];
	[self willChangeValueForKey:@"configuredMachines"];
	[configuredMachines addObject:printerDict];
	[self didChangeValueForKey:@"configuredMachines"];
	[self syncConfiguredMachinesToPreferences];
}

- (void)removeMachine:(NSString*)uuid
{
	for(NSDictionary* dict in configuredMachines)
	{
		if([uuid isEqualToString:[dict objectForKey:@"uuid"]])
		{
			[self willChangeValueForKey:@"configuredMachines"];
			[configuredMachines removeObject:dict];
			[self didChangeValueForKey:@"configuredMachines"];
			[self syncConfiguredMachinesToPreferences];
			break;
		}
	}
}

- (void)deviceRemoved:(P3DSerialDevice*)device
{
	[self willChangeValueForKey:@"configuredMachines"];
	for(NSMutableDictionary* printerDict in configuredMachines)
	{
		if([printerDict objectForKey:@"device"]==device)
		{
			[[printerDict objectForKey:@"driver"] setCurrentDevice:nil];
			[printerDict removeObjectForKey:@"device"];
			break;
		}
	}
	[self didChangeValueForKey:@"configuredMachines"];
}

- (void)reconnectDevices:(NSArray*)newDevices
{
	for(P3DSerialDevice* device in newDevices)
	{
		Class driverClass = device.driverClass;
		NSString* bsdPath = [device.port bsdPath];

		NSMutableArray* matchingMachineDicts = [NSMutableArray array];
		
		// Step 1: Try to find an unconnected entry with matching driver class and lastKnownBSDPath
		for(NSMutableDictionary* printerDict in configuredMachines)
		{
			if([printerDict objectForKey:@"device"]==nil && [[printerDict objectForKey:@"lastKnownBSDPath"] isEqualToString:bsdPath] && [[printerDict objectForKey:@"driver"] isKindOfClass:driverClass])
			{
				[matchingMachineDicts addObject:printerDict];
			}
		}
		
		// Step 2: Try to find an uncconected entry with matching driver class
		if(matchingMachineDicts.count==0)
		{
			for(NSMutableDictionary* printerDict in configuredMachines)
			{
				if([printerDict objectForKey:@"device"]==nil && [[printerDict objectForKey:@"driver"] isKindOfClass:driverClass])
				{
					[matchingMachineDicts addObject:printerDict];
					break;
				}
			}
		}
		
		if(matchingMachineDicts.count>0)
		{
			[self willChangeValueForKey:@"configuredMachines"];
			for(NSMutableDictionary* matchingMachineDict in matchingMachineDicts)
			{
				[[matchingMachineDict objectForKey:@"driver"] setCurrentDevice:device];
				[matchingMachineDict setObject:device forKey:@"device"];
				[matchingMachineDict setObject:[device.port bsdPath] forKey:@"lastKnownBSDPath"];
				if([[matchingMachineDict objectForKey:@"localMachineName"] isEqualToString:[device.driverClass defaultMachineName]])
					[matchingMachineDict setObject:device.deviceName forKey:@"localMachineName"];
				//[matchingMachineDict setObject:[self localComputerName] forKey:@"configuredMachines];
			}
			[self didChangeValueForKey:@"configuredMachines"];
		}
	}
}

- (IBAction)openMachiningQueue:(id)selectedMachines
{
	NSDictionary* machineDict = [selectedMachines lastObject];
	NSLog(@"openMachiningQueue for %@", [machineDict objectForKey:@"localMachineName"]);
}

- (NSDictionary*)configuredMachineForUUID:(NSString*)uuid
{
	if(uuid==nil)
		uuid = [[NSUserDefaults standardUserDefaults] objectForKey:@"defaultMachine"];
	__block NSDictionary* existingMachine = nil;
	[self.configuredMachines enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		if([uuid isEqualToString:[obj objectForKey:@"uuid"]])
		{
			existingMachine=obj;
			*stop=YES;
		} 
	}];
	return existingMachine;
}

@end
