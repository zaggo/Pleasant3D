//
//  STLPreviewController.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 14.01.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class STLPreviewView;
@interface STLPreviewController : NSViewController {
	IBOutlet STLPreviewView* previewView;

}
@property (retain) IBOutlet STLPreviewView* previewView;

@end
