//
//  MachineOptionsViewController.m
//  P3DCore
//
//  Created by Eberhard Rensch on 09.04.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import "MachineOptionsViewController.h"


@implementation MachineOptionsViewController
@synthesize machineOptionsDelegate;

- (BOOL)validateAndSaveChanges
{
	BOOL validated = NO;
	
	if([(NSObject*)machineOptionsDelegate respondsToSelector:@selector(validateAndSaveChanges:)])
	{
		validated = [machineOptionsDelegate validateAndSaveChanges:self.representedObject];
	}
	
	return validated;
}
@end
