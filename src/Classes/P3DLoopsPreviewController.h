//
//  P3DLoopsPreviewController.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 17.01.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class P3DLoopsPreviewView;
@interface P3DLoopsPreviewController : NSViewController {
	IBOutlet P3DLoopsPreviewView* previewView;
}
@property (retain) IBOutlet P3DLoopsPreviewView* previewView;

@end
