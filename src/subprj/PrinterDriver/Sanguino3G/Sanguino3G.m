//
//  Sanguino3G.m
//  Sanguino3G
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

#import "Sanguino3G.h"
#import "SanguinoDevice.h"
#import "SanguinoPrinterOptionsController.h"
#import "StepperFieldEnabledTransformer.h"
#import "GCodeParser.h"
#import "SanguinoPrintJob.h"

@implementation Sanguino3G
@synthesize driverOptions;

+ (void)inititalize
{
	StepperFieldEnabledTransformer *stepperFieldEnabledTransformer;
	
	// create an autoreleased instance of our value transformer
	stepperFieldEnabledTransformer = [[[StepperFieldEnabledTransformer alloc] init] autorelease];
	
	// register it with the name that we refer to it with
	[NSValueTransformer setValueTransformer:stepperFieldEnabledTransformer forName:@"StepperFieldEnabledTransformer"];
}

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
			[driverOptions setObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
									  [NSNumber numberWithInt:300], @"length",
									  [NSNumber numberWithInt:5000], @"maxFeedrate",
									  [NSNumber numberWithFloat:11.767463], @"scale",
									  nil] forKey:@"xAxis"];
			[driverOptions setObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
									  [NSNumber numberWithInt:300], @"length",
									  [NSNumber numberWithInt:5000], @"maxFeedrate",
									  [NSNumber numberWithFloat:11.767463], @"scale",
									  nil] forKey:@"yAxis"];
			[driverOptions setObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
									  [NSNumber numberWithInt:300], @"length",
									  [NSNumber numberWithInt:150], @"maxFeedrate",
									  [NSNumber numberWithFloat:320], @"scale",
									  nil] forKey:@"zAxis"];
			[driverOptions setObject:[NSMutableArray arrayWithObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
																	  @"Pinch Wheel Extruder v1", @"toolheadName",
																	  [NSNumber numberWithInt:1], @"motor",
																	  [NSNumber numberWithInt:200], @"motorSteps",
																	  [NSNumber numberWithBool:YES], @"heater",
																	  nil]] forKey:@"toolheads"];
		}
	}
	
	return self;
}

+ (NSString*)driverIdentifier
{
	return @"sanguino3g";
}

+ (Class)deviceDriverClass;
{
	return [SanguinoDevice class];
}

+ (NSString*)driverName
{
	return NSLocalizedStringFromTableInBundle(@"MakerBot Sanguino 3G", nil, [NSBundle bundleForClass:[self class]], @"Localized Display Name for Driver");
}

+ (NSString*)defaultMachineName;
{
	return NSLocalizedStringFromTableInBundle(@"MakerBot", nil, [NSBundle bundleForClass:[self class]], @"Localized Display Name for Default Printer this driver is for");
}

+ (NSString*)driverVersionString
{
	return [[[NSBundle bundleForClass:[Sanguino3G class]] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
}

+ (NSString*)driverImagePath
{
	return [[NSBundle bundleForClass:[Sanguino3G class]] pathForImageResource:@"mbIcon.png"];
}

+ (NSString*)driverManufacturer
{
	return @"Pleasant Software";
}

- (NSView*)printDialogView
{
	[NSBundle loadNibNamed:@"PrintDialog" owner:self];
	return printerDialogView;
}

- (P3DMachineJob*)createMachineJob:(P3DMachinableDocument*)doc
{
	GCodeParser* parser = [[GCodeParser alloc] init];
	parser.driver = self;
	NSArray* bytecodeBuffers = [parser parse:doc.gCodeToMachine];
	
	SanguinoPrintJob* job = [[SanguinoPrintJob alloc] initWithBytecodeBuffers:bytecodeBuffers];
	job.driver = self;
	
	return job;
}

- (MachineOptionsViewController*)machineOptionsViewController
{
	SanguinoPrinterOptionsController* optionController = [[SanguinoPrinterOptionsController alloc] initWithNibName:@"Sanguino3GPrinterOptions" bundle:[NSBundle bundleForClass:[Sanguino3G class]]];
	
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
	[driverOptions setObject:[changedValues objectForKey:@"xAxis"] forKey:@"xAxis"];
	[driverOptions setObject:[changedValues objectForKey:@"yAxis"] forKey:@"yAxis"];
	[driverOptions setObject:[changedValues objectForKey:@"zAxis"] forKey:@"zAxis"];
	[driverOptions setObject:[changedValues objectForKey:@"toolheads"] forKey:@"toolheads"];
	
	if(![currentDevice.deviceName isEqualToString:[changedValues objectForKey:@"deviceName"]])
	{
		[(SanguinoDevice*)currentDevice changeMachineName:[changedValues objectForKey:@"deviceName"]];
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
        _dimBuildPlatform = [[Vector3 alloc] initVectorWithX:100. Y:100. Z:0.];
    return _dimBuildPlatform;
}

- (Vector3*)zeroBuildPlattform
{
    static Vector3* _zeroBuildPlattform=nil;
    if(_zeroBuildPlattform==nil)
        _zeroBuildPlattform = [[Vector3 alloc] initVectorWithX:50. Y:50. Z:0.];
    return _zeroBuildPlattform;
}

@end
