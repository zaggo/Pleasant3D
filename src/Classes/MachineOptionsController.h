//
//  MachineOptionsController.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 09.04.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MachineOptionsViewController;
@interface MachineOptionsController : NSWindowController {
	NSMutableDictionary* machineOptions;
	
	MachineOptionsViewController* machineOptionsViewController;
	
	id representedMachine;
	
	IBOutlet NSTextField* machineName;
//	IBOutlet NSTextField* deviceName;
	IBOutlet NSTextField* machineLocation;
    IBOutlet NSTabView* tabView;
    
	IBOutlet NSView* machineOptionsContainer;
}

@property (assign) id representedMachine;
@property (assign) NSMutableDictionary* machineOptions;
@property (assign) MachineOptionsViewController* machineOptionsViewController;

- (IBAction)machineOptionsOkPressed:(id)sender;
- (IBAction)machineOptionsCancelPressed:(id)sender;
//- (IBAction)machineOptionsChangeMachineName:(id)sender;

@end
