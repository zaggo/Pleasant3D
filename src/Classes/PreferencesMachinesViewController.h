//
//  PreferencesMachineViewController.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 24.03.2010.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MBPreferencesController.h"

@class AvailableDevices, ConfiguredMachines;
@interface PreferencesMachinesViewController : NSViewController <MBPreferencesModule> {
	IBOutlet NSWindow* addMachineSheet;
	IBOutlet NSArrayController* machinesController;
	
	NSTimer* deviceAlivePoll;
}

@property (readonly) ConfiguredMachines* configuredMachines;
@property (readonly) AvailableDevices* availableDevices; // For Add Machine Sheet
@property (assign) NSInteger defaultMachineSelectedIndex;

@property (readonly) NSWindow* windowForSheet;
@property (readonly) NSArrayController* machinesController;

- (NSString *)identifier;
- (NSImage *)image;


- (IBAction)addMachine:(id)sender;
- (IBAction)removeMachine:(id)sender;

- (IBAction)showMachineOptions:(id)selectedMachine;

// Add Machine Sheet

- (IBAction)addMachineAddPressed:(id)deviceToAdd;
- (IBAction)addMachineCancelPressed:(id)sender;


@end
