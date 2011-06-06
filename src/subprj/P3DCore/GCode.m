//
//  GCode.m
//  P3DCore
//
//  Created by Eberhard Rensch on 07.02.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import "GCode.h"
#import "P3DFormatRegistration.h"

@implementation GCode
@synthesize gCodeString;
@dynamic lineCount;

- (id) initWithGCodeString:(NSString*)value
{
	self = [super init];
	if (self != nil) {
		self.gCodeString = value;
	}
	return self;
}

- (GCode*)copyWithZone:(NSZone*)zone
{
	GCode* copy = [[GCode alloc] initWithGCodeString:gCodeString];
	return copy;
}	

+ (NSSet *)keyPathsForValuesAffectingLineCount {
    return [NSSet setWithObjects:@"gCode", nil];
}

- (NSInteger)lineCount
{
	const char * cstr = [gCodeString cStringUsingEncoding:NSUTF8StringEncoding];
	NSInteger lineCount=1;
	NSInteger i=0;
	while(cstr[i]!=0x0)
	{
		if(cstr[i++]=='\n')
			lineCount++;
	}
	return lineCount;
}

- (BOOL)writeToFile:(NSString*)path error:(NSError**)error;
{
	return [self.gCodeString writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:error];
}

- (NSUInteger)byteLength
{
	return [gCodeString length];
}

- (NSString*)dataFormat
{
	return P3DFormatGCode;
}

@end
