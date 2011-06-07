//
//  P3DMachinableDocument.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 18.02.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ConfiguredMachines, P3DMachineDriveBase;
@interface P3DMachinableDocument : NSDocument
{
    NSString* selectedMachineUUID;
}

@property (readonly) NSString* gCodeToMachine;
@property (readonly) ConfiguredMachines* configuredMachines;
@property (copy) NSString* selectedMachineUUID;
@property (assign) NSInteger selectedMachineIndex;
@property (readonly) P3DMachineDriveBase* currentMachine;
@end
