//
//  PSDocumentController.m
//  PleasantSTL
//
//  Created by Eberhard Rensch on 18.10.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
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
