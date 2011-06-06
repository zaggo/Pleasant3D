//
//  PSMutableIntegerArray.h
//  PSMutableIntegerArray is a high performance variant of NSMutableArray for NSInteger values
//	Requires Garbage Collection!
//
//  Created by Eberhard Rensch on 27.07.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PSMutableIntegerArray : NSObject <NSCoding>
{
	NSInteger integersPerChunk;
	NSInteger count;
	NSMutableArray* dataChunks;
}

@property (readonly) NSInteger count;
- (id)initWithChunkSize:(NSInteger)chunkSize;

- (void)addInteger:(NSInteger)value;
- (NSInteger)integerAtIndex:(NSInteger)index;
- (NSInteger)lastInteger;
- (void)removeLastInteger;
- (void)removeAllIntegers;
@end
