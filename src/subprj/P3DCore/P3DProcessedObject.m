//
//  P3DProcessedObject.m
//  P3DCore
//
//  Created by Eberhard Rensch on 16.01.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
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
