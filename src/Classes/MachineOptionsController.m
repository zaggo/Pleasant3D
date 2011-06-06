//
//  MachineOptionsController.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 09.04.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import "MachineOptionsController.h"
#import <P3DCore/P3DCore.h>

@implementation MachineOptionsController
@synthesize machineOptions, representedMachine, machineOptionsViewController;

- (void)setRepresentedMachine:(id)machine
{
	representedMachine = machine;
	
	NSMutableDictionary* options = [[NSMutableDictionary alloc] init];
	NSString* value;
	if((value = [[machine valueForKey:@"localMachineName"] copy])!=nil)
		[options setObject:value forKey:@"localMachineName"];
	if((value = [[machine valueForKey:@"locationString"] copy])!=nil)
		[options setObject:value forKey:@"locationString"];

	// Readonly values
    P3DMachineDriverBase* driver = (P3DMachineDriverBase*)[machine valueForKey:@"driver"];
	if((value = [driver driverName])!=nil)
		[options setObject:value forKey:@"driverName"];
	if((value = [driver driverVersionString])!=nil)
		[options setObject:value forKey:@"driverVersionString"];
    
    P3DSerialDevice* device = [driver currentDevice];
    AMSerialPort* port = [device port];
	if((value = [port bsdPath])!=nil)
		[options setObject:value forKey:@"bsdPath"];

	self.machineOptionsViewController = [(P3DMachineDriverBase*)[machine valueForKey:@"driver"] machineOptionsViewController];

	self.machineOptions = options;
}

- (IBAction)machineOptionsOkPressed:(id)sender
{	
	BOOL shouldClose = YES;
	[self.window makeFirstResponder:nil];
	
	// Validate
	if(shouldClose && 
	   ![[representedMachine valueForKey:@"localMachineName"] isEqualToString:[machineOptions objectForKey:@"localMachineName"]] && 
	   [(NSString*)[machineOptions objectForKey:@"localMachineName"] length]==0)
	{
		shouldClose = NO;
        [tabView selectTabViewItemAtIndex:0];
		[self.window makeFirstResponder:machineName];
	}
	
	if(shouldClose && 
	   ![[representedMachine valueForKey:@"locationString"] isEqualToString:[machineOptions objectForKey:@"locationString"]] && 
	   [(NSString*)[machineOptions objectForKey:@"locationString"] length]==0)
	{
		shouldClose = NO;
        [tabView selectTabViewItemAtIndex:0];
		[self.window makeFirstResponder:machineLocation];
	}

	if(shouldClose)
    {
		shouldClose = [machineOptionsViewController validateAndSaveChanges];
        if(!shouldClose)
            [tabView selectTabViewItemAtIndex:1];
    }
		
	// Set Values
	if(shouldClose)
	{
		if(![[representedMachine valueForKey:@"localMachineName"] isEqualToString:[machineOptions objectForKey:@"localMachineName"]])
			[representedMachine setValue:[machineOptions objectForKey:@"localMachineName"] forKey:@"localMachineName"];
		if(![[representedMachine valueForKey:@"locationString"] isEqualToString:[machineOptions objectForKey:@"locationString"]])
			[representedMachine setValue:[machineOptions objectForKey:@"locationString"] forKey:@"locationString"];
		[NSApp endSheet:self.window returnCode:YES];
	}
	else
		NSBeep();
}

- (IBAction)machineOptionsCancelPressed:(id)sender
{
	[NSApp endSheet:self.window returnCode:NO];
}

//- (IBAction)machineOptionsChangeMachineName:(id)sender
//{
//	[sender setEnabled:NO];
//	[deviceName setHidden:NO];
//	[self.window makeFirstResponder:deviceName];
//}
//
- (void)setMachineOptionsViewController:(MachineOptionsViewController*)value
{
	machineOptionsViewController = value;
	NSView* optionView = machineOptionsViewController.view;
	
	NSRect wFrame = self.window.frame;
	NSRect oFrame = optionView.frame;
	NSRect ocFrame = machineOptionsContainer.frame;
	CGFloat optionContentHeight = NSHeight(ocFrame);
	CGFloat wantedHeight = NSHeight(oFrame);
	
	if(optionContentHeight<wantedHeight)
	{
		wFrame.size.height+=(wantedHeight-optionContentHeight);
		[self.window setFrame:wFrame display:NO];
		ocFrame.size.height=wantedHeight;
		ocFrame.origin.y+=(wantedHeight-optionContentHeight);
		machineOptionsContainer.frame = ocFrame;
		[self.window setMinSize:wFrame.size];
	}
	else
	{
		oFrame.origin.y = (optionContentHeight-wantedHeight);
		optionView.frame = oFrame;
	}
	wFrame.size.height=1200.;
	[self.window setMaxSize:wFrame.size];

	[machineOptionsContainer addSubview:optionView];
}

@end
