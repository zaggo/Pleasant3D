//
//  ToolPanelView.h
//  MacSkeinforge
//
//  Created by Eberhard Rensch on 02.08.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

@interface ToolPanelView : NSView {
	BOOL isSelected;
	NSViewController* viewController;
	CAGradientLayer* backgroundLayer;
	NSMenu* contextMenu;
	
	
	
	// Since NSView::cacheDisplayInRect doesn't capture CAGradientLayer, we need the
	// following "ordinary" background while capturing the panel for a drag operation
	// It will be used as long the useCocoaBackground flag is set to YES
	BOOL useCocoaBackground;
	NSBezierPath* panelShape;
	NSGradient* nonLayeredBackground;
}

@property (assign) IBOutlet NSViewController* viewController;
@property (assign) IBOutlet NSMenu* contextMenu;
@property (assign) BOOL isSelected;

- (NSImage*)imageForDragging;
@end
