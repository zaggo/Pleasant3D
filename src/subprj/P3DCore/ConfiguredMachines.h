//
//  ConfiguredMachines.h
//  P3DCore
//
//  Created by Eberhard Rensch on 01.04.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class P3DSerialDevice;
@interface ConfiguredMachines : NSObject {
	NSMutableArray* configuredMachines;
}
@property (readonly) NSArray* configuredMachines;

+ (ConfiguredMachines*)sharedInstance;
- (void)addConnectedMachine:(P3DSerialDevice*)device;
- (void)addUnconnectedMachine:(NSString*)driverClassName;
- (void)removeMachine:(NSString*)uuid;

- (NSDictionary*)configuredMachineForUUID:(NSString*)uuid;

- (void)deviceRemoved:(P3DSerialDevice*)device;
- (void)reconnectDevices:(NSArray*)newDevices;

- (IBAction)openMachiningQueue:(id)selectedMachines;

- (void)syncConfiguredMachinesToPreferences;
@end
