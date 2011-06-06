//
//  P3DPrintJob.h
//  P3DCore
//
//  Created by Eberhard Rensch on 11.04.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "P3DMachineDriverBase.h"

@class P3DMachiningQueue;
@protocol P3DMachinableDocument;
@interface P3DMachineJob : NSObject {
	P3DMachineDriverBase* driver;
	P3DMachiningQueue* queue;
    P3DMachinableDocument* document;
    
	float progress;
	BOOL  jobAbort;
}

@property (assign) P3DMachineDriverBase* driver;
@property (assign) P3DMachiningQueue* queue;
@property (assign) P3DMachinableDocument* document;
@property (assign) float progress;
@property (assign) BOOL jobAbort;

- (void)processJob;
- (void)implProcessJob;
- (void)handleDeviceResponse:(NSString*)response;
@end
