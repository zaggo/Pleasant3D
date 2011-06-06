//
//  SkeinView.h
//  MacSkeinforge
//
//  Created by Eberhard Rensch on 04.08.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ThreeDPreviewView.h"

@class ParsedGCode;
@interface GCodeView : ThreeDPreviewView	{
	ParsedGCode* parsedGCode;
		
	CGFloat currentLayerMinZ;
	CGFloat currentLayerMaxZ;

}

@property (assign) ParsedGCode* parsedGCode;
@property (assign) CGFloat currentLayerMinZ;
@property (assign) CGFloat currentLayerMaxZ;
@end
