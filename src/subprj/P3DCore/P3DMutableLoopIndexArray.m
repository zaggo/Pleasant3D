//
//  P3DMutableLoopIndexArray.m
//  P3DCore
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
