//
//  NSArray+GCode.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 05.08.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//

#import "NSArray+GCode.h"


@implementation NSArray (GCode)

- (BOOL)isThereAFirstWord:(NSString*)word
{
	__block BOOL itIs=NO;
	[self enumerateObjectsWithOptions:NSEnumerationConcurrent 
						   usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
							   [obj setScanLocation:0];
							   if([obj scanString:word intoString:nil])
							   {
								  itIs = YES;
								  *stop=YES;
							   }
						   }];
	return itIs;
}

@end
