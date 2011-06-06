//
//  IndexedSTLData.m
//  STLImport
//
//  Created by Eberhard Rensch on 15.01.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "IndexedSTLModel.h"
#import "P3DToolBase.h"

@implementation IndexedSTLModel
@synthesize stlModel, edgeIndex;

- (id)initWithCoder:(NSCoder*)decoder
{
	self = [super init];
	stlModel = [decoder decodeObjectForKey:@"stlModel"];
	edgeIndex = [decoder decodeObjectForKey:@"edgeIndex"];
	return self;
}

- (void)encodeWithCoder:(NSCoder*)encoder
{
	[encoder encodeObject:stlModel forKey:@"stlModel"];
	[encoder encodeObject:edgeIndex forKey:@"edgeIndex"];
}

- (IndexedSTLModel*)copyWithZone:(NSZone *)zone
{
	IndexedSTLModel* theCopy = [[IndexedSTLModel alloc] init];
	theCopy.stlModel = [self.stlModel copy];
	theCopy.edgeIndex = [self.edgeIndex copy];
	return theCopy;
}

- (void)setStlModel:(STLModel*)value
{
	stlModel = value;
	//[self signalChange];
}

- (void)setEdgeIndex:(IndexedEdges*)value
{
	edgeIndex = value;
	[self signalChange];
}

- (NSUInteger)byteLength
{
	return [stlModel.stlData length];
}

- (NSString*)dataFormat
{
	return P3DFormatIndexedSTL;
}

@end
