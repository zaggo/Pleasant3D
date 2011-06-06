//
//  P3DGCodePreviewController.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 17.01.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class GCodeView, ParsedGCode, GCode;
@interface P3DGCodePreviewController : NSViewController {
	IBOutlet GCodeView* previewView;
	ParsedGCode* parsedGCode;
	GCode* gCode;
}
@property (retain) IBOutlet GCodeView* previewView;
@property (assign) GCode* gCode;

@end
