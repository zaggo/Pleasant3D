//
//  P3DLoops.m
//  P3DCore
//
//  Created by Eberhard Rensch on 17.01.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
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
