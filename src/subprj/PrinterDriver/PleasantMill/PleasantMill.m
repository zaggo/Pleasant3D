//
//  PleasantMill.m
//  PleasantMill
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

#import "PleasantMill.h"
#import "PleasantMillDevice.h"
#import "PleasantMillMachineOptionsController.h"
#import "PleasantMillMachiningJob.h"

@implementation PleasantMill
@synthesize driverOptions;

- (id) init
{
	return [self initWithOptionPropertyList:nil];
}

- (id)initWithOptionPropertyList:(NSDictionary*)options
{
	self = [super init];
	if(self)
	{
		if(options)
			driverOptions = [[NSMutableDictionary alloc] initWithDictionary:options copyItems:YES];
		else
		{
			driverOptions = [[NSMutableDictionary alloc] init];
		}
	}
	
	return self;
}

+ (NSString*)driverIdentifier
{
	return @"pleasantmill";
}

+ (Class)deviceDriverClass;
{
	return [PleasantMillDevice class];
}

+ (NSString*)driverName
{
	return NSLocalizedStringFromTableInBundle(@"Pleasant Mill", nil, [NSBundle bundleForClass:[self class]], @"Localized Display Name for Driver");
}

+ (NSString*)defaultMachineName;
{
	return NSLocalizedStringFromTableInBundle(@"Pleasant Mill", nil, [NSBundle bundleForClass:[self class]], @"Localized Display Name for Default Machine this driver is for");
}

+ (NSString*)driverVersionString
{
	return [[[NSBundle bundleForClass:[PleasantMill class]] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
}

+ (NSString*)driverImagePath
{
	return [[NSBundle bundleForClass:[PleasantMill class]] pathForImageResource:@"pmIcon.png"];
}

+ (NSString*)driverManufacturer
{
	return @"Pleasant Software";
}

- (NSView*)printDialogView
{
	[NSBundle loadNibNamed:@"FabDialog" owner:self];
	return printerDialogView;
}

- (P3DMachineJob*)createMachineJob:(P3DMachinableDocument*)doc
{
	PleasantMillMachiningJob* job = [[PleasantMillMachiningJob alloc] initWithGCode:doc.gCodeToMachine];
	job.driver = self;
	return job;
}

- (MachineOptionsViewController*)machineOptionsViewController
{
	PleasantMillMachineOptionsController* optionController = [[PleasantMillMachineOptionsController alloc] initWithNibName:@"PleasantMillMachineOptions" bundle:[NSBundle bundleForClass:[PleasantMill class]]];
	
	NSMutableDictionary* options = [[NSMutableDictionary alloc] initWithDictionary:driverOptions copyItems:YES];
	
	NSString* value;
	if((value = [currentDevice.deviceName copy])!=nil)
		[options setObject:value forKey:@"deviceName"];	
	
	optionController.representedObject = options;
	optionController.machineOptionsDelegate = self;
	return optionController;
}

- (BOOL)validateAndSaveChanges:(NSDictionary*)changedValues
{
//	[driverOptions setObject:[changedValues objectForKey:@"xAxis"] forKey:@"xAxis"];
//	[driverOptions setObject:[changedValues objectForKey:@"yAxis"] forKey:@"yAxis"];
//	[driverOptions setObject:[changedValues objectForKey:@"zAxis"] forKey:@"zAxis"];
//	[driverOptions setObject:[changedValues objectForKey:@"toolheads"] forKey:@"toolheads"];
	
	if(![currentDevice.deviceName isEqualToString:[changedValues objectForKey:@"deviceName"]])
	{
		[(PleasantMillDevice*)currentDevice changeMachineName:[changedValues objectForKey:@"deviceName"]];
	}
	
	return YES;
}

- (NSDictionary*)driverOptionsAsPropertyList
{
	return driverOptions;
}

- (Vector3*)dimBuildPlattform
{
    static Vector3* _dimBuildPlatform=nil;
    if(_dimBuildPlatform==nil)
        _dimBuildPlatform = [[Vector3 alloc] initVectorWithX:300. Y:150. Z:0.];
    return _dimBuildPlatform;
}

- (Vector3*)zeroBuildPlattform
{
    static Vector3* _zeroBuildPlattform=nil;
    if(_zeroBuildPlattform==nil)
        _zeroBuildPlattform = [[Vector3 alloc] initVectorWithX:0. Y:0. Z:0.];
    return _zeroBuildPlattform;
}

@end
