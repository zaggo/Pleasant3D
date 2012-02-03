//
//  P3DMachiningQueue.m
//  P3DCore
//
//  Created by Eberhard Rensch on 18.02.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify it under
//  the terms of the GNU General Public License as published by the Free Software 
//  Foundation; either version 3 of the License, or (at your option) any later 
//  version.
// 
//  This program is distributed in the hope that it will be useful, but WITHOUT ANY 
//  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A 
//  PARTICULAR PURPOSE. See the GNU General Public License for more details.
// 
//  You should have received a copy of the GNU General Public License along with 
//  this program; if not, see <http://www.gnu.org/licenses>.
// 
//  Additional permission under GNU GPL version 3 section 7
// 
//  If you modify this Program, or any covered work, by linking or combining it 
//  with the P3DCore.framework (or a modified version of that framework), 
//  containing parts covered by the terms of Pleasant Software's software license, 
//  the licensors of this Program grant you additional permission to convey the 
//  resulting work.
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
