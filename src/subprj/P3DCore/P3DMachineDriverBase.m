//
//  P3DMachineDriverBase.m
//  P3DCore
//
//  Created by Eberhard Rensch on 18.02.10.
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
#import "P3DMachineDriverBase.h"
#import "P3DMachinableDocument.h"
#import "P3DMachiningQueue.h"
#import "P3DSerialDevice.h"
#import "P3DMachineJob.h"
#import "AvailableDevices.h"
#import "AMSerialPortList.h"

@implementation P3DMachineDriverBase
@synthesize isMachining, isPaused, currentDevice, discovered, lastKnownBSDPath;
@dynamic statusString, printDialogView, driverImagePath, statusLightImage, driverName, driverManufacturer, driverVersionString, dimBuildPlattform, zeroBuildPlattform;

- (id)initWithOptionPropertyList:(NSDictionary*)options
{
	self = [super init];
	if(self)
	{
		// Overload in subclasses...
	}
	
	return self;
}

+ (NSString*)driverIdentifier
{
	return nil;
}

+ (Class)deviceDriverClass;
{
	return nil;
}

+ (NSString*)driverName
{
	return nil;
}

+ (NSString*)defaultMachineName;
{
	return nil;
}

+ (NSString*)driverVersionString
{
	return nil;
}

+ (NSString*)driverImagePath
{
	return nil;
}

+ (NSString*)driverManufacturer
{
	return nil;
}

+ (NSSet *)keyPathsForValuesAffectingStatusString {
    return [NSSet setWithObjects:@"isMachining", @"isPaused", @"currentDevice", @"errorMessage", @"discovered", nil];
}

+ (NSSet *)keyPathsForValuesAffectingStatusLightImage {
    return [NSSet setWithObjects:@"isMachining", @"isPaused", @"currentDevice", @"errorMessage", @"discovered", nil];
}

#pragma mark -

- (NSString*)driverImagePath
{
	return [[self class] driverImagePath];
}

- (NSString*)driverName
{
	return [[self class] driverName];
}

- (NSString*)driverVersionString
{
	return [[self class] driverVersionString];
}

- (NSString*)driverManufacturer
{
	return [[self class] driverManufacturer];
}

- (NSImage*)statusLightImage
{
	NSImage* statusLight;
	
	if(self.currentDevice)
	{
		if(self.currentDevice.errorMessage)
			statusLight = [NSImage imageNamed:@"RedLight.png"];
		else if(self.currentDevice.deviceIsBusy)
			statusLight = [NSImage imageNamed:@"YellowLight.png"];
		else
			statusLight = [NSImage imageNamed:@"GreenLight.png"];
	}
	else if(discovered)
		statusLight = [NSImage imageNamed:@"RedLight.png"];
    else
        statusLight = [NSImage imageNamed:@"GrayLight.png"];
    
	return statusLight;
}

- (NSString*)statusString
{
	NSString* statusDisplayString=nil;
	if(self.currentDevice)
	{
		if(self.currentDevice.errorMessage)
		{
			statusDisplayString =  self.currentDevice.errorMessage;
		}
		else if(self.currentDevice.deviceIsBusy)
		{
			if(self.isPaused)
				statusDisplayString =  NSLocalizedStringFromTableInBundle(@"Paused", nil, [NSBundle bundleForClass:[self class]], @"Localized Machine Status Message");
			else
				statusDisplayString =  NSLocalizedStringFromTableInBundle(@"Machining", nil, [NSBundle bundleForClass:[self class]], @"Localized Machine Status Message");
		}
		else
			statusDisplayString =  NSLocalizedStringFromTableInBundle(@"Idle", nil, [NSBundle bundleForClass:[self class]], @"Localized Machine Status Message");
	}
	else if(discovered)
		statusDisplayString =  NSLocalizedStringFromTableInBundle(@"Offline", nil, [NSBundle bundleForClass:[self class]], @"Localized Machine Status Message");
    else
    {
        statusDisplayString =  NSLocalizedStringFromTableInBundle(@"Unknown", nil, [NSBundle bundleForClass:[self class]], @"Localized Machine Status Message");
        if(!discovering)
        {
            discovering=YES;
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                P3DSerialDevice* device = [[AvailableDevices sharedInstance] reconnectDevice:[[self class] deviceDriverClass] withBSDPath:lastKnownBSDPath];
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.currentDevice = device;
                    self.discovered = YES;
                });
            });
        }
    }

	return statusDisplayString;
}


#pragma mark -

- (void)setCurrentDevice:(P3DSerialDevice*)device
{
	if(device==nil || [device isKindOfClass:[[self class] deviceDriverClass]])
	{
		currentDevice = device;
	}
	else
	{
		NSLog(@"Device %@ is not the correct serial driver device (%@)", NSStringFromClass([device class]), NSStringFromClass([[self class] deviceDriverClass]));
	}	
}

- (P3DMachineJob*)createMachineJob:(P3DMachinableDocument*)doc
{
	return nil;
}

- (MachineOptionsViewController*)machineOptionsViewController
{
	return nil;
}

- (NSDictionary*)driverOptionsAsPropertyList
{
	return nil;
}

- (Vector3*)dimBuildPlattform
{
    return nil;
}

- (Vector3*)zeroBuildPlattform
{
    return nil;
}

@end
