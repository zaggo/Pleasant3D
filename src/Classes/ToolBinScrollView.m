//
//  ToolBinScrollView.m
//  MacSkeinforge
//
//  Created by Eberhard Rensch on 02.08.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//

#import "ToolBinScrollView.h"
#import <P3DCore/P3DCore.h>
#import "ToolBinView.h"

@implementation ToolBinScrollView

- (void)awakeFromNib
{
	CALayer* layer;
	// Add a background layer to the parent (scroll view)
	layer = [CALayer layer];
	NSRect frame = NSZeroRect;
	frame.size = [self contentSize];
	frame = NSInsetRect(frame, -1, -1);
	frame.origin.y=NSMaxY([self bounds])-frame.size.height-1.;
	
	layer.frame = NSRectToCGRect(frame);
	CGImageRef backgroundImage = GetCGImageNamed(@"ToolBinBackground.png");
	layer.contents = (id)backgroundImage;
	layer.contentsGravity = kCAGravityResize;
	layer.autoresizingMask = kCALayerWidthSizable;
	[self.layer insertSublayer:layer atIndex:0];

}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
	if(newWindow)
	{
		[self setPostsFrameChangedNotifications:YES];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(frameWillChange:) name:NSViewFrameDidChangeNotification object:nil];
	}
	else
	{
		[self setPostsFrameChangedNotifications:NO];
		[[NSNotificationCenter defaultCenter] removeObserver:self];
	}

}

- (void)frameWillChange:(NSNotification*)n
{
	NSView* view = [[self contentView] documentView];
	if([view isKindOfClass:[ToolBinView class]])
		[(ToolBinView*)view resizeToolBin];
}
	 
@end
