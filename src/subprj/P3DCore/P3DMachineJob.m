//
//  P3DPrintJob.m
//  P3DCore
//
//  Created by Eberhard Rensch on 11.04.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import "P3DMachineJob.h"
#import "P3DMachiningQueue.h"
#import "P3DSerialDevice.h"

@implementation P3DMachineJob
@synthesize driver, queue, progress, jobAbort, document;

- (void)processJob
{
	if(driver.currentDevice && driver.currentDevice.activeMachineJob==nil)
	{
		self.progress = 0.;
        driver.currentDevice.activeMachineJob = self;
		driver.isMachining = YES;
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			[self implProcessJob];
			dispatch_async(dispatch_get_main_queue(), ^{
				driver.isMachining = NO;
                driver.currentDevice.activeMachineJob = nil;
				[self.queue machiningComplete:self];
				});
		});
	}
}

// Abstract
- (void)implProcessJob
{
}

// Abstract
- (void)handleDeviceResponse:(NSString*)response
{
}
@end
