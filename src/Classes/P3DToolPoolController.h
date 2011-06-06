//
//  P3DToolPoolController.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 28.07.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ToolPool;
@interface P3DToolPoolController : NSObject {
	NSCollectionView* collectionView;
	NSArrayController* toolCollection;
	NSUInteger sortingMode;
}

@property (assign) IBOutlet NSCollectionView* collectionView;
@property (assign) IBOutlet NSArrayController* toolCollection;
@property (assign) NSUInteger sortingMode;
@property (readonly) ToolPool* toolPool;
@end
