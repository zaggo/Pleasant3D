//
//  P3DProcessedObject.m
//  P3DCore
//
//  Created by Eberhard Rensch on 16.01.10.
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

#import "P3DProcessedObject.h"


@implementation P3DProcessedObject
@synthesize uuid;
@dynamic byteLength, dataFormat;

+ (NSString*)uuid
{
	NSString* uuid=nil;
	CFUUIDRef uuidRef = CFUUIDCreate(kCFAllocatorDefault);
	CFStringRef strRef = CFUUIDCreateString(kCFAllocatorDefault, uuidRef);
	if(strRef)
	{
		uuid = [NSString stringWithString:(NSString*)strRef];
		CFRelease(strRef);
	}
	if(uuidRef)
		CFRelease(uuidRef);
	return uuid;
}

+ (NSSet *)keyPathsForValuesAffectingHash {
    return [NSSet setWithObject:@"uuid"];
}

- (id) init
{
	self = [super init];
	if (self != nil) {
		uuid = [P3DProcessedObject uuid];
	}
	return self;
}

- (id)initWithCoder:(NSCoder*)decoder
{
	self = [super init];
	uuid = [decoder decodeObjectForKey:@"uuid"];
	return self;
}

- (void)encodeWithCoder:(NSCoder*)encoder
{
	[encoder encodeObject:uuid forKey:@"uuid"];
}

- (P3DProcessedObject*)copyWithZone:(NSZone *)zone
{
	P3DProcessedObject* theCopy = [[P3DProcessedObject alloc] init];
	return theCopy;
}

- (void)signalChange
{
	self.uuid = [P3DProcessedObject uuid];
}

- (BOOL)isEqual:(id)other
{
	if([other isKindOfClass:[P3DProcessedObject class]])
		return [uuid isEqualToString:[(P3DProcessedObject*)other uuid]];
	return NO;
}

- (NSUInteger)hash
{
	return [uuid hash];
}

- (BOOL)writeToFile:(NSString*)path error:(NSError**)error;
{
	return NO;
}

- (NSUInteger)byteLength
{
	return 0;
}

- (NSString*)dataFormat
{
	return nil;
}
@end
