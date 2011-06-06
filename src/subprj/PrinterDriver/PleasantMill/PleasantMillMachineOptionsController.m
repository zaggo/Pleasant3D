//
// PleasantMillMachineOptionsController.m
//  PleasantMill
//
//  Created by Eberhard Rensch on 09.04.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import "PleasantMillMachineOptionsController.h"


@implementation PleasantMillMachineOptionsController

- (IBAction)changeDeviceName:(id)sender
{
	[sender setHidden:YES];
	[deviceName setHidden:NO];
	[self.view.window makeFirstResponder:deviceName];
}

- (IBAction)addToolhead:(id)sender
{
}

- (IBAction)removeToolhead:(id)sender
{
}

@end
