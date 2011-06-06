//
//  IndexedEdges.h
//  P3DCore
//
//  Created by Eberhard Rensch on 15.01.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OpenCL/OpenCL.h>
#import "EdgeIndexTypes.h"

@interface IndexedEdges : NSObject <NSCoding, NSCopying> {
	NSData*	edgeIndexData;
}

@property (readonly) EdgeIndex* indexedEdges;
@property (readonly) NSUInteger numberOfIndexedEdges;

- (id)initWithEdgeIndexData:(NSData*)data;

@end
