//
//  ToolBinEntryView.m
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
