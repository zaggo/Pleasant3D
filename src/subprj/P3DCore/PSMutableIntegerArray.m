//
//  PSMutableIntegerArray.m
//  PSMutableIntegerArray is a high performance variant of NSMutableArray for NSInteger values
//	Requires Garbage Collection!
//
//  Created by Eberhard Rensch on 27.07.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//

#import "PSMutableIntegerArray.h"

// Only for debugging!
static NSInteger sortLexically(NSNumber* n1, NSNumber* n2, void * context)
{
	return [[n1 stringValue] compare:[n2 stringValue]];
}

@interface PSMutableIntegerArray (Private)
- (NSData*)dataForIntegers;
@end

@implementation PSMutableIntegerArray
@synthesize count;
- (id) init
{
	return [self initWithChunkSize:4096];
}

- (id)initWithChunkSize:(NSInteger)chunkSize
{
	self = [super init];
	if (self != nil) {
		integersPerChunk=chunkSize;
		dataChunks = [NSMutableArray arrayWithObject:[self dataForIntegers]];
		count=0;
	}
	return self;
}

- (id)initWithCoder:(NSCoder*)decoder
{
	self = [super init];
	if (self != nil) {
		integersPerChunk = [decoder decodeIntForKey:@"integersPerChunk"];
		dataChunks = [decoder decodeObjectForKey:@"dataChunks"];
		count = [decoder decodeIntForKey:@"count"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder*)encoder
{
	[encoder encodeInt:integersPerChunk forKey:@"integersPerChunk"];
	[encoder encodeObject:dataChunks forKey:@"dataChunks"];
	[encoder encodeInt:count forKey:@"count"];
}

- (void)addInteger:(NSInteger)value
{
	NSInteger chunkIndex = count/integersPerChunk;
	NSInteger indexInChunk = count-(chunkIndex*integersPerChunk);
	if(chunkIndex>=[dataChunks count])
		[dataChunks addObject:[self dataForIntegers]];
	NSInteger* chunkPtr = (NSInteger*)[[dataChunks objectAtIndex:chunkIndex] bytes];
	
	chunkPtr[indexInChunk] = value;
	count++;
}

- (NSInteger)integerAtIndex:(NSInteger)index
{
	if(index<0 || index>=count)
		@throw [NSException exceptionWithName:@"PSIntegerArray: indexOufOfRange" 
							reason:[NSString stringWithFormat:@"index %d is out of array range [0..%d]",index, count] 
							userInfo:nil];
							
	NSInteger chunkIndex = index/integersPerChunk;
	NSInteger indexInChunk = index-(chunkIndex*integersPerChunk);
	NSInteger* chunkPtr = (NSInteger*)[[dataChunks objectAtIndex:chunkIndex] bytes];
	return chunkPtr[indexInChunk];
}

- (void)setInteger:(NSInteger)value atIndex:(NSInteger)index
{
	if(index<0 || index>=count)
		@throw [NSException exceptionWithName:@"PSIntegerArray: indexOufOfRange" 
									   reason:[NSString stringWithFormat:@"index %d is out of array range [0..%d]",index, count] 
									 userInfo:nil];
	
	NSInteger chunkIndex = index/integersPerChunk;
	NSInteger indexInChunk = index-(chunkIndex*integersPerChunk);
	NSInteger* chunkPtr = (NSInteger*)[[dataChunks objectAtIndex:chunkIndex] bytes];
	chunkPtr[indexInChunk] = value;
}

- (NSInteger)lastInteger
{
	return [self integerAtIndex:count-1];
}

- (void)removeLastInteger
{
	if(count>0)
		count--;
}

- (void)removeAllIntegers
{
	if([dataChunks count]>1)
		dataChunks = [NSMutableArray arrayWithObject:[self dataForIntegers]];
	count=0;
}

- (NSData*)dataForIntegers
{
//	NSLog(@"create chunk");
	NSInteger numBytes = sizeof(NSInteger)*integersPerChunk;
	return [NSData dataWithBytesNoCopy:malloc(numBytes) length:numBytes freeWhenDone:YES];
}

- (NSString*)description
{
	NSMutableString* desc=[NSMutableString stringWithFormat:@"IntegerArray with %d integers", count];
	if(count>0)
	{
		[desc appendString:@" ("];
		for(int i=0;i<count;i++)
			[desc appendFormat:@"%d, ", [self integerAtIndex:i]];
		[desc deleteCharactersInRange:NSMakeRange([desc length]-2, 2)];
	}
	[desc appendString:@")"];
	return desc;
}
@end
