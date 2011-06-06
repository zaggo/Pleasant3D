//
//  P3DMachiningQueue.m
//  P3DCore
//
//  Created by Eberhard Rensch on 18.02.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import "P3DMachiningQueue.h"
#import "P3DMachinableDocument.h"
#import "P3DMachineDriverBase.h"
#import "P3DMachineJob.h"

@implementation P3DMachiningQueue
@synthesize queue;

- (id) init
{
	self = [super init];
	if (self != nil) {
		queue = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)addMachiningJobForDocument:(P3DMachinableDocument*)doc withDriver:(P3DMachineDriverBase*)driver;
{
	P3DMachineJob* job = [driver createMachineJob:doc];
	if(job)
	{
        job.document = doc;
		job.queue = self;
		[self willChangeValueForKey:@"queue"];
		[queue addObject:job];
		[self didChangeValueForKey:@"queue"];
		if(queue.count==1)
		{
			[(P3DMachineJob*)[queue objectAtIndex:0] processJob];
			[[NSDocumentController sharedDocumentController] performSelector:@selector(showMachiningQueue:) withObject:self];
		}
	}
}

- (void)machiningComplete:(P3DMachineJob*)job
{
	[self willChangeValueForKey:@"queue"];
	[queue removeObject:job];
	[self didChangeValueForKey:@"queue"];
	if(queue.count>0)
	{
		//P3DPrintJob* firstInQueue = [queue objectAtIndex:0];
		[(P3DMachineJob*)[queue objectAtIndex:0] processJob];
	}	
}

@end
