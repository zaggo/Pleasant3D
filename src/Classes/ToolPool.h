//
//  ToolPool.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 13.01.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define kMSFPersistenceClass @"class"
#define kMSFPersistenceSettings @"settings"

@interface ToolPool : NSObject {
	NSMutableArray* availableTools;
	NSMutableArray* availableImporterUTIs;
	
	BOOL loading;
}

+ (ToolPool*)sharedToolPool;

@property (readonly) NSArray* availableTools;
@property (assign) BOOL loading;
@property (readonly) NSArray* availableImporterUTIs;

@end
