//
//  P3DMachinableDocument.m
//  P3DCore
//
//  Created by Eberhard Rensch on 06.06.11.
//  Copyright 2011 Pleasant Software. All rights reserved.
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
#import "P3DMachinableDocument.h"
#import "ConfiguredMachines.h"
#import "P3DMachineDriverBase.h"

@implementation P3DMachinableDocument
@dynamic configuredMachines, selectedMachineIndex, currentMachine;

- (id)init
{
    self = [super init];
    if (self) {
        self.selectedMachineUUID = [[NSUserDefaults standardUserDefaults] objectForKey:@"defaultMachine"];
    }
    return self;
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
//    [[NSNotificationCenter defaultCenter] postNotificationName:P3DCurrentMachineSettingsChangedNotifiaction object:self];
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

- (P3DMachineDriverBase*)currentMachine
{
    P3DMachineDriverBase* machine = nil;
    NSInteger selected = self.selectedMachineIndex;
    if(selected>=0 && selected < self.configuredMachines.configuredMachines.count)
        machine = [[self.configuredMachines.configuredMachines objectAtIndex:selected] objectForKey:@"driver"];
    else if(self.configuredMachines.configuredMachines.count>0)
        machine = self.configuredMachines.configuredMachines[0][@"driver"];
    return machine;
}
@end
