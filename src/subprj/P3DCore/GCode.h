//
//  GCode.h
//  P3DCore
//
//  Created by Eberhard Rensch on 07.02.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "P3DProcessedObject.h"

@interface GCode : P3DProcessedObject {
	NSString* gCodeString;
}
@property (retain) NSString* gCodeString;
@property (readonly) NSInteger lineCount;
- (id) initWithGCodeString:(NSString*)value;
@end
