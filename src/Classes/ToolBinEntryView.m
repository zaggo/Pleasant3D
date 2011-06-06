//
//  ToolBinEntryView.m
//  MacSkeinforge
//
//  Created by Eberhard Rensch on 02.08.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//

#import "ToolBinEntryView.h"
#import <QuartzCore/QuartzCore.h>

@implementation ToolBinEntryView

- (void)moveToX:(CGFloat)newX animated:(BOOL)animated;
{	
	NSRect myFrame = [self frame];
	myFrame.origin.x = newX;
	if(animated) 
	{
		[NSAnimationContext beginGrouping];
		[[NSAnimationContext currentContext] setDuration:.3];
		[[self animator] setFrame:myFrame];
		[NSAnimationContext endGrouping];
	}
	else
	{
		[self setFrame:myFrame];
	}
}

//- (void)moveBy:(CGFloat)moveBy animated:(BOOL)animated;
//{	
//	NSRect myFrame = [self frame];
//	myFrame.origin.x +=moveBy;
//	CGFloat newx=myFrame.origin.x;
//	NSLog(@"Move ToolBinEntryView to X=%f %@",newx, animated?@"animated":@"immediate");
//	if(animated)
//	{
//		[NSAnimationContext beginGrouping];
//		[[NSAnimationContext currentContext] setDuration:.3];
//		[[self animator] setFrame:myFrame];
//		[NSAnimationContext endGrouping];
//	}
//	else
//	{
//		[self setFrame:myFrame];
//	}
//}

@end
