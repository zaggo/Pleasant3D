//
//  PSDocumentController.m
//  PleasantSTL
//
//  Created by Eberhard Rensch on 18.10.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
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

#import "P3DDocumentController.h"
#import "PSToolboxPanel.h"
#import "MBPreferencesController.h"
#import "PreferencesGeneralViewController.h"
#import "PreferencesMachinesViewController.h"

@implementation P3DDocumentController
@synthesize toolbox, machiningQueue, machiningQueueWindow;

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
	return NO;
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSMutableDictionary *ddef = [NSMutableDictionary dictionary];
	[ddef setObject:[P3DToolBase uuid] forKey:@"defaultMachine"];
	[[NSUserDefaults standardUserDefaults] registerDefaults:ddef];

    [AvailableDevices sharedInstance]; // Load MachineDriver Plugins
	
	// Preferences
	PreferencesGeneralViewController *general = [[PreferencesGeneralViewController alloc] initWithNibName:@"PreferencesGeneral" bundle:nil];
	PreferencesMachinesViewController *printer = [[PreferencesMachinesViewController alloc] initWithNibName:@"PreferencesMachines" bundle:nil];
	[[MBPreferencesController sharedController] setModules:[NSArray arrayWithObjects:general, printer, nil]];
	[general release];
	[printer release];

	if([[self documents] count] == 0)
	{
		//[self openDocument:self];
		[self newDocument:self];
	}		
}

- (IBAction)showToolbox:(id)sender
{
	if(toolbox==nil)
	{
		[NSBundle loadNibNamed:@"Toolbox" owner:self];
	}
	[toolbox fadeIn];
}

- (IBAction)showMachiningQueue:(id)sender
{
	if(machiningQueueWindow==nil)
	{
		[NSBundle loadNibNamed:@"MachiningQueue" owner:self];
	}
	[machiningQueueWindow makeKeyAndOrderFront:self];
}

- (IBAction)showPreferences:(id)sender
{
	[[MBPreferencesController sharedController] showWindow:sender];
}

- (NSString *)defaultType
{
	return @"com.pleasantsoftware.uti.p3d";
}

- (P3DMachiningQueue*)machiningQueue
{
	if(machiningQueue==nil)
	{
		machiningQueue = [[P3DMachiningQueue alloc] init];
	}
	return machiningQueue;
}

@end
