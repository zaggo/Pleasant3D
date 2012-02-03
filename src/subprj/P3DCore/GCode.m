//
//  GCode.m
//  P3DCore
//
//  Created by Eberhard Rensch on 07.02.10.
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
