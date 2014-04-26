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

enum {
    kMinXMaxY = 0,
    kMidXMaxY,
    kMaxXMaxY,
    kMinXMidY,
    kMidXMidY,
    kMaxXMidY,
    kMinXMinY,
    kMidXMinY,
    kMaxXMinY
};

@implementation PleasantMill
{
    Vector3* _dimBuildPlatform;
    Vector3* _zeroBuildPlattform;
}

- (id) init
{
	return [self initWithOptionPropertyList:nil];
}

- (id)initWithOptionPropertyList:(NSDictionary*)options
{
	self = [super init];
	if(self) {
        _fastXYFeedrate = 1100.f; // mm/min
        _fastZFeedrate = 1100.f; // mm/min
        _slowFeedrate = 150.f; // mm/min
        
		if(options) {
			_driverOptions = [[NSMutableDictionary alloc] initWithDictionary:options copyItems:YES];
        } else {
			_driverOptions = [@{@"machinableAreaX": @200., @"machinableAreaY": @120., @"machinableAreaZ": @50., @"horizontalOrigin":@(kMidXMidY)} mutableCopy];
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
	return _printerDialogView;
}

- (P3DMachineJob*)createMachineJob:(P3DMachinableDocument*)doc
{
	PleasantMillMachiningJob* job = [[PleasantMillMachiningJob alloc] initWithGCode:doc.rawGCode];
	job.driver = self;
	return job;
}

- (MachineOptionsViewController*)machineOptionsViewController
{
	PleasantMillMachineOptionsController* optionController = [[PleasantMillMachineOptionsController alloc] initWithNibName:@"PleasantMillMachineOptions" bundle:[NSBundle bundleForClass:[PleasantMill class]]];
	
	NSMutableDictionary* options = [[NSMutableDictionary alloc] initWithDictionary:_driverOptions copyItems:YES];
	
	NSString* value;
	if((value = [self.currentDevice.deviceName copy])!=nil)
		[options setObject:value forKey:@"deviceName"];	
	
	optionController.representedObject = options;
	optionController.machineOptionsDelegate = self;
	return optionController;
}

- (BOOL)validateAndSaveChanges:(NSDictionary*)changedValues
{
    BOOL changesValid=YES;
    
    if([changedValues[@"machinableAreaX"] floatValue]<=0.f)
        changesValid=NO;
    if([changedValues[@"machinableAreaY"] floatValue]<=0.f)
        changesValid=NO;
    if([changedValues[@"machinableAreaZ"] floatValue]<0.f)
        changesValid=NO;
    if([changedValues[@"horizontalOrigin"] integerValue]<0 || [changedValues[@"horizontalOrigin"] integerValue]>8)
        changesValid=NO;
    
    if(changesValid) {
        _driverOptions[@"machinableAreaX"] = changedValues[@"machinableAreaX"];
        _driverOptions[@"machinableAreaY"] = changedValues[@"machinableAreaY"];
        _driverOptions[@"machinableAreaZ"] = changedValues[@"machinableAreaZ"];
        
        _dimBuildPlatform=nil;
        
        _driverOptions[@"horizontalOrigin"] = changedValues[@"horizontalOrigin"];
        _zeroBuildPlattform=nil;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:P3DCurrentMachineSettingsChangedNotifiaction object:self];
    }

    if(![self.currentDevice.deviceName isEqualToString:[changedValues objectForKey:@"deviceName"]]) {
		[(PleasantMillDevice*)self.currentDevice changeMachineName:[changedValues objectForKey:@"deviceName"]];
	}

	return changesValid;
}

- (NSDictionary*)driverOptionsAsPropertyList
{
	return _driverOptions;
}

- (Vector3*)dimBuildPlattform
{
    if(_dimBuildPlatform==nil)
        _dimBuildPlatform = [[Vector3 alloc] initVectorWithX:[_driverOptions[@"machinableAreaX"] floatValue]  Y:[_driverOptions[@"machinableAreaY"] floatValue] Z:[_driverOptions[@"machinableAreaZ"] floatValue]];
    return _dimBuildPlatform;
}

- (Vector3*)zeroBuildPlattform
{
    if(_zeroBuildPlattform==nil) {
        Vector3* dim = self.dimBuildPlattform;
        switch([_driverOptions[@"horizontalOrigin"] integerValue]) {
            case kMinXMidY:
                _zeroBuildPlattform = [[Vector3 alloc] initVectorWithX:0.f Y:dim.y/2.f Z:0.f];
                break;
            case kMinXMaxY:
                _zeroBuildPlattform = [[Vector3 alloc] initVectorWithX:0.f Y:dim.y Z:0.f];
                break;
            case kMidXMinY:
                _zeroBuildPlattform = [[Vector3 alloc] initVectorWithX:dim.x/2.f Y:0.f Z:0.f];
                break;
            case kMidXMidY:
                _zeroBuildPlattform = [[Vector3 alloc] initVectorWithX:dim.x/2.f Y:dim.y/2.f Z:0.f];
                break;
            case kMidXMaxY:
                _zeroBuildPlattform = [[Vector3 alloc] initVectorWithX:dim.x/2.f Y:dim.y Z:0.f];
                break;
            case kMaxXMinY:
                _zeroBuildPlattform = [[Vector3 alloc] initVectorWithX:dim.x Y:0.f Z:0.f];
                break;
            case kMaxXMidY:
                _zeroBuildPlattform = [[Vector3 alloc] initVectorWithX:dim.x Y:dim.y/2.f Z:0.f];
                break;
            case kMaxXMaxY:
                _zeroBuildPlattform = [[Vector3 alloc] initVectorWithX:dim.x Y:dim.y Z:0.f];
                break;
            default:
                _zeroBuildPlattform = [[Vector3 alloc] initVectorWithX:0.f Y:0.f Z:0.f];
        }
    }
    return _zeroBuildPlattform;
}

- (NSInteger)gcodeStyle
{
    return kGCodeStyleMill;
}

@end
