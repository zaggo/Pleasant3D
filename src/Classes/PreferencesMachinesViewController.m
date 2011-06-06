//
//  PreferencesMachineViewController.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 24.03.2010.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import "PreferencesMachinesViewController.h"
#import "MachineOptionsController.h"
#import <P3DCore/P3DCore.h>
#import <IOKit/IOMessage.h>

@implementation PreferencesMachinesViewController
@synthesize machinesController;
@dynamic configuredMachines, availableDevices, windowForSheet, defaultMachineSelectedIndex;

- (void)awakeFromNib
{
	[machinesController setSortDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"machineName" ascending:YES]]];
}

- (NSString *)title
{
	return NSLocalizedString(@"Machines", @"Title of 'Machines' preference pane");
}

- (NSString *)identifier
{
	return @"PreferencesMachinePane";
}

- (NSImage *)image
{
	return [NSImage imageNamed:@"Machine"];
}


- (ConfiguredMachines*)configuredMachines
{
	return [ConfiguredMachines sharedInstance];
}

- (AvailableDevices*)availableDevices
{
    AvailableDevices* ad = [AvailableDevices sharedInstance];
    return ad;
}

- (NSWindow*)windowForSheet
{
	return self.view.window;
}

- (IBAction)addMachine:(id)sender
{
	if(addMachineSheet==nil)
	{
		[NSBundle loadNibNamed:@"AddMachine" owner:self];
	}
	
	[NSApp beginSheet:addMachineSheet modalForWindow:self.windowForSheet modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];	
}

- (IBAction)removeMachine:(id)sender
{
    for(NSDictionary* printer in [machinesController selectedObjects])
    {
        NSLog(@"Delete %@", [printer description]);
        [[ConfiguredMachines sharedInstance] removeMachine:[printer objectForKey:@"uuid"]];
        if([[[NSUserDefaults standardUserDefaults] objectForKey:@"defaultMachine"] isEqualToString:[printer objectForKey:@"uuid"]])
        {
            if([[[ConfiguredMachines sharedInstance] configuredMachines] count]>0)
                [[NSUserDefaults standardUserDefaults] setObject:[[[[ConfiguredMachines sharedInstance] configuredMachines] objectAtIndex:0] objectForKey:@"uuid"] forKey:@"defaultMachine"];
            else
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"defaultMachine"];
        }
    }
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
{
	[sheet close];
	if(returnCode)
	{
		[[ConfiguredMachines sharedInstance] syncConfiguredMachinesToPreferences];
	}
}

- (NSInteger)defaultMachineSelectedIndex
{
	__block NSInteger selectedIndex = 0;
	
	NSString* uuid = [[NSUserDefaults standardUserDefaults] objectForKey:@"defaultMachine"];
	if(uuid)
	{
		[[machinesController arrangedObjects] enumerateObjectsUsingBlock:^(id printerDict, NSUInteger idx, BOOL *stop) {
			if([uuid isEqualToString:[printerDict objectForKey:@"uuid"]])
			{	
				selectedIndex = idx;
				*stop = YES;
			}
		}];
	}
	return selectedIndex;
}

- (void)setDefaultMachineSelectedIndex:(NSInteger)value
{
	NSDictionary* printerDict = [[machinesController arrangedObjects] objectAtIndex:value];
	[[NSUserDefaults standardUserDefaults] setObject:[printerDict objectForKey:@"uuid"] forKey:@"defaultMachine"];
}
	 
- (IBAction)addMachineAddPressed:(id)devicesToAdd
{
	[self willChangeValueForKey:@"defaultMachineSelectedIndex"];
	
	for(NSDictionary* printerDict in devicesToAdd)
	{
		if([printerDict objectForKey:@"device"])
			[[ConfiguredMachines sharedInstance] addConnectedMachine:[printerDict objectForKey:@"device"]];
		else
			[[ConfiguredMachines sharedInstance] addUnconnectedMachine:[printerDict objectForKey:@"driverClassName"]];
	}
    if([[[ConfiguredMachines sharedInstance] configuredMachines] count]==1)
        [[NSUserDefaults standardUserDefaults] setObject:[[[[ConfiguredMachines sharedInstance] configuredMachines] objectAtIndex:0] objectForKey:@"uuid"] forKey:@"defaultMachine"];
	[self didChangeValueForKey:@"defaultMachineSelectedIndex"];

	[NSApp endSheet:addMachineSheet returnCode:YES];
}

- (IBAction)addMachineCancelPressed:(id)sender
{
	[NSApp endSheet:addMachineSheet returnCode:NO];
}

- (IBAction)showMachineOptions:(id)selectedMachine
{
	MachineOptionsController* poc = [[MachineOptionsController alloc] initWithWindowNibName:@"MachineOptionSheet"];	
	poc.representedMachine = selectedMachine;
	
	[NSApp beginSheet:poc.window modalForWindow:self.windowForSheet modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];	
}

@end