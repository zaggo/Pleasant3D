//
//  GCodeParser.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 07.02.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <P3DCore/P3DCore.h>

@interface ParsedGCode : NSObject {
	Vector3* cornerHigh;
	Vector3* cornerLow;
	float extrusionWidth;
	
	NSMutableArray* panes;	
}

@property (readonly) Vector3* cornerHigh;
@property (readonly) Vector3* cornerLow;
@property (readonly) float extrusionWidth;
@property (readonly) NSArray* panes;

- (id)initWithGCodeString:(NSString*)gcode;
@end
