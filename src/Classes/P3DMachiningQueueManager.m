//
//  P3DMachiningQueueManager.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 11.04.10.
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
