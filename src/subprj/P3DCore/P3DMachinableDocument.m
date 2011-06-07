//
//  P3DMachinableDocument.m
//  P3DCore
//
//  Created by Eberhard Rensch on 06.06.11.
//  Copyright 2011 Pleasant Software. All rights reserved.
//

#import "P3DMachinableDocument.h"
#import "ConfiguredMachines.h"

@implementation P3DMachinableDocument
@synthesize selectedMachineUUID;
@dynamic configuredMachines, selectedMachineIndex, currentMachine;

+ (void)initialize
{
	NSMutableDictionary *ddef = [NSMutableDictionary dictionary];
	[ddef setObject:[NSNumber numberWithInteger:0] forKey:@"DefaultMachineIndex"];
	NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults registerDefaults:ddef];
}


- (NSString*)gCodeToMachine
{
	return nil; // Abstract
}

- (ConfiguredMachines*)configuredMachines
{
	return [ConfiguredMachines sharedInstance];
}


+ (NSSet *)keyPathsForValuesAffectingSelectedMachineIndex {
    return [NSSet setWithObjects:@"selectedMachineUUID", nil];
}

+ (NSSet *)keyPathsForValuesAffectingCurrentMachine {
    return [NSSet setWithObjects:@"selectedMachineIndex", nil];
}

- (void)setSelectedMachineIndex:(NSInteger)value
{
	self.selectedMachineUUID = [[self.configuredMachines.configuredMachines objectAtIndex:value] objectForKey:@"uuid"];
}

- (NSInteger)selectedMachineIndex
{
	__block NSInteger selectedIndex = 0;
	[self.configuredMachines.configuredMachines enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		if([[obj objectForKey:@"uuid"] isEqualToString:self.selectedMachineUUID])
		{
			selectedIndex = idx;
			*stop=YES;
		}
	}];
	return selectedIndex;
}

- (P3DMachineDriveBase*)currentMachine
{
    P3DMachineDriveBase* machine = nil;
    NSInteger selected = self.selectedMachineIndex;
    if(selected>=0 && selected < self.configuredMachines.configuredMachines.count)
        machine = [[self.configuredMachines.configuredMachines objectAtIndex:selected] objectForKey:@"driver"];
    return machine;
}
@end
