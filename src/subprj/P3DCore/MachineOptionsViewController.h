//
//  MachineOptionsViewController.h
//  P3DCore
//
//  Created by Eberhard Rensch on 09.04.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol MachineOptionsDelegate;
@interface MachineOptionsViewController : NSViewController {
	id <MachineOptionsDelegate> machineOptionsDelegate;
}

@property (assign) id <MachineOptionsDelegate> machineOptionsDelegate;

- (BOOL)validateAndSaveChanges;

@end

@protocol MachineOptionsDelegate
- (BOOL)validateAndSaveChanges:(NSDictionary*)changedValues;
@end

