//
//  P3DMachineDriverBase.h
//  P3DCore
//
//  Created by Eberhard Rensch on 18.02.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class P3DMachinableDocument, Vector3;
@class P3DSerialDevice, MachineOptionsViewController, P3DMachineJob;
@interface P3DMachineDriverBase : NSObject {
    BOOL discovered;
    BOOL discovering;
	BOOL isMachining;
	BOOL isPaused;
    NSString* lastKnownBSDPath;
    
	P3DSerialDevice* currentDevice;
}

@property (assign) BOOL discovered;
@property (assign) BOOL isMachining;
@property (assign) BOOL isPaused;
@property (copy) NSString* lastKnownBSDPath;
@property (readonly) NSString* statusString;
@property (readonly) NSView* printDialogView;

@property (assign) P3DSerialDevice* currentDevice;

@property (readonly) NSImage* statusLightImage;

// Properties for Class Methods (for binding)
@property (readonly) NSString* driverImagePath;
@property (readonly) NSString* driverName;
@property (readonly) NSString* driverVersionString;
@property (readonly) NSString* driverManufacturer;
@property (readonly) Vector3* dimBuildPlattform;
@property (readonly) Vector3* zeroBuildPlattform;

+ (NSString*)driverIdentifier;
+ (Class)deviceDriverClass;
+ (NSString*)driverName;
+ (NSString*)defaultMachineName;
+ (NSString*)driverVersionString;
+ (NSString*)driverImagePath;
+ (NSString*)driverManufacturer;

- (id)initWithOptionPropertyList:(NSDictionary*)options;

- (P3DMachineJob*)createMachineJob:(P3DMachinableDocument*)doc;

- (MachineOptionsViewController*)machineOptionsViewController;
- (NSDictionary*)driverOptionsAsPropertyList;

@end
