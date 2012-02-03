//
//  ToolBinScrollView.m
//  MacSkeinforge
//
//  Created by Eberhard Rensch on 02.08.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify it under
//  the terms of the GNU General Public License as published by the Free Software 
//  Foundation; either version 3 of the License, or (at your option) any later 
//  version.
// 
//  This program is distributed in the hope that it will be useful, but WITHOUT ANY 
//  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A 
//  PARTICULAR PURPOSE. See the GNU General Public License for more details.
// 
//  You should have received a copy of the GNU General Public License along with 
//  this program; if not, see <http://www.gnu.org/licenses>.
// 
//  Additional permission under GNU GPL version 3 section 7
// 
//  If you modify this Program, or any covered work, by linking or combining it 
//  with the P3DCore.framework (or a modified version of that framework), 
//  containing parts covered by the terms of Pleasant Software's software license, 
//  the licensors of this Program grant you additional permission to convey the 
//  resulting work.
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
