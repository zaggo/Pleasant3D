//
//  P3DProcessedObject.h
//  P3DCore
//
//  Created by Eberhard Rensch on 16.01.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface P3DProcessedObject : NSObject <NSCoding, NSCopying> {
	NSString* uuid;
}
@property (retain) NSString* uuid;
@property (readonly) NSUInteger byteLength;

@property (readonly) NSString* dataFormat;

- (void)signalChange;

- (BOOL)writeToFile:(NSString*)path error:(NSError**)error;
@end
