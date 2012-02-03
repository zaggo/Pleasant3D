//
//  MachineOptionsController.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 09.04.10.
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
