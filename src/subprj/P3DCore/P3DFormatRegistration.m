//
//  P3DFormatRegistration.m
//  P3DCore
//
//  Created by Eberhard Rensch on 09.02.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import "P3DFormatRegistration.h"

// Well known InputFormats
NSString* const P3DFormatAnyProcessedData = @"P3DFormatAnyProcessedData";

NSString* const P3DFormatIndexedSTL=@"P3DFormatIndexedSTL";
NSString* const P3DFormatLoops=@"P3DFormatLoops";
NSString* const P3DFormatGCode=@"P3DFormatGCode";

// Wildcard for output format
NSString* const P3DFormatOutputSameAsInput=@"P3DFormatOutputSameAsInput";

@implementation P3DFormatRegistration
+ (void)initialize
{
	[[P3DFormatRegistration sharedInstance] registerFormat:P3DFormatAnyProcessedData conformsTo:nil localizedName:NSLocalizedStringFromTableInBundle(@"All Formats", nil, [NSBundle bundleForClass:[self class]], @"Localized input format name")];
	
	[[P3DFormatRegistration sharedInstance] registerFormat:P3DFormatIndexedSTL conformsTo:P3DFormatAnyProcessedData localizedName:NSLocalizedStringFromTableInBundle(@"Indexed STL Data", nil, [NSBundle bundleForClass:[self class]], @"Localized input format name")];
	[[P3DFormatRegistration sharedInstance] registerFormat:P3DFormatLoops conformsTo:P3DFormatAnyProcessedData localizedName:NSLocalizedStringFromTableInBundle(@"Loops", nil, [NSBundle bundleForClass:[self class]], @"Localized input format name")];
	[[P3DFormatRegistration sharedInstance] registerFormat:P3DFormatGCode conformsTo:P3DFormatAnyProcessedData localizedName:NSLocalizedStringFromTableInBundle(@"GCode", nil, [NSBundle bundleForClass:[self class]], @"Localized input format name")];
	
	[[P3DFormatRegistration sharedInstance] registerFormat:P3DFormatOutputSameAsInput conformsTo:nil localizedName:NSLocalizedStringFromTableInBundle(@"Same as Input Format", nil, [NSBundle bundleForClass:[self class]], @"Localized input format name")];
}

- (id) init
{
	self = [super init];
	if (self != nil) {
		formatDatabase = [[NSMutableDictionary alloc] init];
	}
	return self;
}

+ (P3DFormatRegistration*)sharedInstance
{
	static P3DFormatRegistration* _singleton = nil;
	static dispatch_once_t	justOnce=(dispatch_once_t)nil;
    dispatch_once(&justOnce, ^{
		_singleton = [[P3DFormatRegistration alloc] init];
    });
	return _singleton;
}

- (void)registerFormat:(NSString*)format conformsTo:(NSString*)baseFormat localizedName:(NSString*)name;
{
	NSMutableDictionary* desc = [NSMutableDictionary dictionary];
	if(baseFormat)
		[desc setObject:baseFormat forKey:@"baseFormat"];
	if(name)
		[desc setObject:name forKey:@"localizedName"];
	[formatDatabase setObject:desc forKey:format];
}


- (BOOL)format:(NSString*)format conformsTo:(NSString*)otherFormat;
{
	BOOL conforms = NO;
	if([format isEqualToString:otherFormat])
		conforms = YES;
	else
	{
		NSString* baseFormat = [[formatDatabase objectForKey:format] objectForKey:@"baseFormat"];
		if(baseFormat)
			conforms = [self format:baseFormat conformsTo:otherFormat];
	}
	return conforms;
}

- (BOOL)format:(NSString*)format conformsToAnyFormatInArray:(NSArray*)candidateFormats
{
	__block BOOL valid = NO;
	[candidateFormats enumerateObjectsUsingBlock:^(id candidateFormat, NSUInteger idx, BOOL *stop) {
			if([self format:format conformsTo:candidateFormat])
			{
				valid = YES;
				*stop = YES;
			}
		}];

	return valid;
}

- (NSString*)localizedNameOfFormat:(NSString*)format
{
	NSString* name = [[formatDatabase objectForKey:format] objectForKey:@"localizedName"];
	if(name == nil)
		name = format;
	return name;
}

@end
