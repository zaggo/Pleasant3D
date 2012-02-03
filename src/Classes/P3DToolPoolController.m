//
//  P3DToolPoolController.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 28.07.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
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

#import "P3DToolPoolController.h"
#import <P3DCore/P3DCore.h>
#import "ToolPool.h"

@implementation P3DToolPoolController
@synthesize collectionView, toolCollection, sortingMode;
@dynamic toolPool;

+ (void)initialize
{
	NSDictionary *ddef = [NSDictionary dictionaryWithObjectsAndKeys:
						  [NSNumber numberWithInteger:1], @"toolPoolSortingMode",
						  nil];
	[[NSUserDefaults standardUserDefaults] registerDefaults:ddef];	
}

- (void)awakeFromNib
{
	[collectionView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];
	[collectionView setMinItemSize:NSMakeSize(90, 80)];
	[collectionView setMaxItemSize:NSMakeSize(90, 80)];
	self.sortingMode=[[NSUserDefaults standardUserDefaults] integerForKey:@"toolPoolSortingMode"];
}

- (ToolPool*)toolPool
{
	return [ToolPool sharedToolPool];
}

// -------------------------------------------------------------------------------
//	setSortingMode:newMode
// -------------------------------------------------------------------------------
- (void)setSortingMode:(NSUInteger)newMode
{
    sortingMode = newMode;
	[[NSUserDefaults standardUserDefaults] setInteger:sortingMode forKey:@"toolPoolSortingMode"];
	
    NSSortDescriptor *sort = [[[NSSortDescriptor alloc]
                               initWithKey:(sortingMode == 0)?@"localizedToolName":@"toolType"
                               ascending:YES
                               selector:@selector(caseInsensitiveCompare:)] autorelease];
    [toolCollection setSortDescriptors:[NSArray arrayWithObject:sort]];
}

- (BOOL)collectionView:(NSCollectionView *)cv writeItemsAtIndexes:(NSIndexSet *)indexes toPasteboard:(NSPasteboard *)pasteboard
{
	NSDictionary *toolDict = [[cv content] objectAtIndex:[indexes firstIndex]];
	
	P3DToolBase* tool = [[NSClassFromString([toolDict objectForKey:kMSFPersistenceClass]) alloc] init];
	
	[pasteboard clearContents];
	BOOL success = [pasteboard writeObjects:[NSArray arrayWithObject:tool]];
	return success;
}

@end
