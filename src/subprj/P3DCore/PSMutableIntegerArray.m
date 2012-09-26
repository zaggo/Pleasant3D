//
//  PSMutableIntegerArray.m
//  PSMutableIntegerArray is a high performance variant of NSMutableArray for NSInteger values
//	Requires Garbage Collection!
//
//  Created by Eberhard Rensch on 07.01.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//
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
							reason:[NSString stringWithFormat:@"index %d is out of array range [0..%d]",(int32_t)index, (int32_t)count] 
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
									   reason:[NSString stringWithFormat:@"index %d is out of array range [0..%d]",(int32_t)index, (int32_t)count]
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
	NSMutableString* desc=[NSMutableString stringWithFormat:@"IntegerArray with %d integers", (int32_t)count];
	if(count>0)
	{
		[desc appendString:@" ("];
		for(int i=0;i<count;i++)
			[desc appendFormat:@"%d, ", (int32_t)[self integerAtIndex:i]];
		[desc deleteCharactersInRange:NSMakeRange([desc length]-2, 2)];
	}
	[desc appendString:@")"];
	return desc;
}
@end
