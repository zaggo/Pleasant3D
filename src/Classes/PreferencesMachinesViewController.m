//
//  PreferencesMachineViewController.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 24.03.2010.
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