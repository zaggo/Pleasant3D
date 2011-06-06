//
//  P3DMachiningQueue.h
//  P3DCore
//
//  Created by Eberhard Rensch on 18.02.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class P3DMachinableDocument;
@class P3DMachineDriverBase, P3DMachineJob;
@interface P3DMachiningQueue : NSObject {
	NSMutableArray* queue;
}
@property (readonly) NSArray* queue;

- (void)addMachiningJobForDocument:(P3DMachinableDocument*)doc withDriver:(P3DMachineDriverBase*)driver;
- (void)machiningComplete:(P3DMachineJob*)driver;
@end
