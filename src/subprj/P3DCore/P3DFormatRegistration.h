//
//  P3DFormatRegistration.h
//  P3DCore
//
//  Created by Eberhard Rensch on 09.02.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// Well known InputFormats
extern NSString* const P3DFormatAnyProcessedData;

extern NSString* const P3DFormatIndexedSTL;
extern NSString* const P3DFormatLoops;
extern NSString* const P3DFormatGCode;

extern NSString* const P3DFormatOutputSameAsInput;


@interface P3DFormatRegistration : NSObject {
	NSMutableDictionary* formatDatabase;
}
+ (P3DFormatRegistration*)sharedInstance;

- (void)registerFormat:(NSString*)format conformsTo:(NSString*)baseFormat localizedName:(NSString*)name;
- (BOOL)format:(NSString*)format conformsTo:(NSString*)otherFormat;
- (BOOL)format:(NSString*)format conformsToAnyFormatInArray:(NSArray*)candidateFormats;
- (NSString*)localizedNameOfFormat:(NSString*)format;
@end
