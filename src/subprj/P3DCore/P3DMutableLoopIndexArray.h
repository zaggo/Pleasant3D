//
//  P3DMutableLoopIndexArray.h
//  P3DCore
//
//  Created by Eberhard Rensch on 07.03.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PSMutableIntegerArray.h"

@interface P3DMutableLoopIndexArray : PSMutableIntegerArray {
	NSMutableDictionary* metaData;
}

@property (readonly) NSMutableDictionary* metaData;

@end
