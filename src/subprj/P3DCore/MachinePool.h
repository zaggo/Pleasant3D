//
//  MachinePool.h
//  P3DCore
//
//  Created by Eberhard Rensch on 12.02.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MachinePool : NSObject {
	NSMutableArray* machineNames;
	NSMutableArray* machineSettings;
}
@property (readonly) NSArray* machineNames;
@property (readonly) NSArray* machineSettings;

+ (MachinePool*)sharedInstance;
@end
