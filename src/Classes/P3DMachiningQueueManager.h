//
//  P3DMachiningQueueManager.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 11.04.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <P3DCore/P3DCore.h>

@interface P3DMachiningQueueManager : NSObject {
	NSMutableDictionary* printingQueues;
}

+ (P3DMachiningQueueManager*)sharedInstance;

- (P3DMachiningQueue*)printingQueueForDriver:(P3DMachineDriverBase*)driver;
@end
