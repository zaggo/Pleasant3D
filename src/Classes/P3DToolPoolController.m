//
//  P3DToolPoolController.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 28.07.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
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
