//
//  P3DMachiningQueueManager.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 11.04.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import "P3DMachiningQueueManager.h"


@implementation P3DMachiningQueueManager

+ (P3DMachiningQueueManager*)sharedInstance
{
	static P3DMachiningQueueManager* _singleton = nil;
	static dispatch_once_t	justOnce=(dispatch_once_t)nil;
	dispatch_once(&justOnce, ^{
		_singleton = [[P3DMachiningQueueManager alloc] init];
    });
	return _singleton;
}

- (id) init
{
	self = [super init];
	if (self != nil) {
		printingQueues = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (P3DMachiningQueue*)printingQueueForDriver:(P3DMachineDriverBase*)driver
{
	P3DMachiningQueue* queue = nil;
	if(driver.currentDevice)
	{
		NSString* deviceIdentifier = [[[NSBundle bundleForClass:[driver.currentDevice class]] infoDictionary] objectForKey:@"CFBundleIdentifier"];
		if(deviceIdentifier)
		{
			queue = [printingQueues objectForKey:deviceIdentifier];
			if(queue==nil)
			{
				queue = [[P3DMachiningQueue alloc] init];
				[printingQueues setObject:queue forKey:deviceIdentifier];
			}
		}
	}
	return queue;
}

@end
