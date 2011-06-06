//
//  IndexedEdges.m
//  P3DCore
//
//  Created by Eberhard Rensch on 15.01.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import "IndexedEdges.h"


@implementation IndexedEdges
- (id) initWithEdgeIndexData:(NSData*)data
{
	self = [super init];
	if (self != nil) {
		edgeIndexData = data;
	}
	return self;
}

- (id)initWithCoder:(NSCoder*)decoder
{
	self = [super init];
	edgeIndexData = [decoder decodeObjectForKey:@"edgeIndexData"];
	return self;
}

- (void)encodeWithCoder:(NSCoder*)encoder
{
	[encoder encodeObject:edgeIndexData forKey:@"edgeIndexData"];
}

- (IndexedEdges*)copyWithZone:(NSZone *)zone
{
	IndexedEdges* theCopy = [[IndexedEdges alloc] initWithEdgeIndexData:[edgeIndexData copy]];
	return theCopy;
}

- (EdgeIndex*)indexedEdges
{
	return (EdgeIndex*)[edgeIndexData bytes];
}

- (NSUInteger)numberOfIndexedEdges
{
	return [edgeIndexData length]/sizeof(EdgeIndex);
}

@end
