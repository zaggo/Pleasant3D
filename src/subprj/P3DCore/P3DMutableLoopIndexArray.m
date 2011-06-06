//
//  P3DMutableLoopIndexArray.m
//  P3DCore
//
//  Created by Eberhard Rensch on 07.03.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import "P3DMutableLoopIndexArray.h"


@implementation P3DMutableLoopIndexArray
@synthesize metaData;

- (id) init
{
	self = [super init];
	if (self != nil) {
		metaData = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (id)initWithChunkSize:(NSInteger)chunkSize
{
	self = [super initWithChunkSize:chunkSize];
	if (self != nil) {
		metaData = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (id)initWithCoder:(NSCoder*)decoder
{
	self = [super initWithCoder:decoder];
	if (self != nil) {
		metaData = [decoder decodeObjectForKey:@"metaData"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder*)encoder
{
	[super encodeWithCoder:encoder];
	[encoder encodeObject:metaData forKey:@"metaData"];
}

@end
