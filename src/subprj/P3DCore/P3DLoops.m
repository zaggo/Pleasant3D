//
//  P3DLoops.m
//  P3DCore
//
//  Created by Eberhard Rensch on 17.01.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import "P3DLoops.h"
#import "P3DToolBase.h"


@implementation P3DLoops
@synthesize layers, extrusionHeight, extrusionWidth, cornerMaximum, cornerMinimum;
@dynamic loopCorners, loopCornerCount;

- (id)initWithLoopCornerData:(NSData*)data;
{
	self = [super init];
	if(self)
	{
		insetLoopCornerData = data;
	}
	return self;
}

- (P3DLoops*)copyWithZone:(NSZone*)zone
{
	P3DLoops* copy = [[P3DLoops alloc] initWithLoopCornerData:insetLoopCornerData];
	copy.layers = [layers copy];
	copy.extrusionHeight = extrusionHeight;
	copy.extrusionWidth = extrusionWidth;
	copy.cornerMaximum = [cornerMaximum copy];
	copy.cornerMinimum = [cornerMinimum copy];
	
	return copy;
}	
	
- (InsetLoopCorner*)loopCorners
{
	return (InsetLoopCorner*)[insetLoopCornerData bytes];
}

- (NSUInteger)loopCornerCount
{
	return [insetLoopCornerData length]/sizeof(InsetLoopCorner);
}

- (void)finalize
{
	[super finalize];
}

- (NSString*)dataFormat
{
	return P3DFormatLoops;
}

@end
