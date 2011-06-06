//
//  P3DBorderView.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 02.08.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ToolSettingsViewController;
@interface P3DBorderView : NSView {
	IBOutlet ToolSettingsViewController* viewController;
	BOOL unanchorPending;
	BOOL drawUnanchorPending;
	BOOL isUnanchoredView;
	NSPoint hitOffset;
	
	CGFloat offsetX;
}
@property (assign) CGFloat offsetX;
@property (assign) BOOL isUnanchoredView;
@end
