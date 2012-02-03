//
//  P3DBorderView.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 02.08.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//
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

#import "P3DBorderView.h"
#import "ToolSettingsViewController.h"

const CGFloat kTriangleSize = 15.0;
const CGFloat kCornerRadius = 10.0;

//@interface NSButtonCell (NSButtonCellPrivate)
//- (NSButtonType)_buttonType;
//@end
//
//@interface NSView (HUDable)
//- (void)setHudMode:(BOOL)value;
//@end
//
//@implementation NSView (HUDable)
//- (void)setHudMode:(BOOL)value
//{
//	NSColor* newTextColor;
//	if(value)
//	newTextColor = [NSColor whiteColor];
//	else
//	newTextColor = [NSColor blackColor];
//
//	for(NSView* view in [self subviews])
//	{
//		if([view isKindOfClass:[NSTextField class]] && ![(NSTextField*)view isEditable])
//			[(NSTextField*)view setTextColor:newTextColor];
//		else if([view isKindOfClass:[NSBox class]])
//		{
//			[[(NSBox*)view titleCell] setTextColor:newTextColor];
//			[view setHudMode:value];
//		}
//		else if([view isKindOfClass:[NSButton class]])
//		{
//			if([[(NSButton*)view cell] _buttonType] == NSSwitchButton || [[(NSButton*)view cell] _buttonType] == NSRadioButton)
//			{
//				NSMutableAttributedString *colorTitle =
//				[[NSMutableAttributedString alloc] initWithAttributedString:[(NSButton*)view attributedTitle]];
//				
//				NSRange titleRange = NSMakeRange(0, [colorTitle length]);
//				
//				[colorTitle addAttribute:NSForegroundColorAttributeName
//								   value:newTextColor
//								   range:titleRange];
//				
//				[(NSButton*)view setAttributedTitle:colorTitle];
//			}
//		}
//		else 
//			[view setHudMode:value];
//	}
//}
//@end
//
@implementation P3DBorderView
@synthesize offsetX, isUnanchoredView;

- (BOOL)isOpaque {
    return NO;
}

- (void)drawRect:(NSRect)dirtyRect {
    // Some constants that easily could be changed to meet your needs
	NSBezierPath *borderPath;
	NSRect bounds = self.bounds;
	if(!isUnanchoredView)
	{
		bounds.size.height -= kTriangleSize;
		borderPath = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:kCornerRadius yRadius:kCornerRadius];
		
		// Draw a triangle at the top. We are not flipped (the default), so our origin is the bottom left.
		NSPoint point =NSMakePoint(floor(NSMidX(bounds) - kTriangleSize)-offsetX, NSMaxY(bounds));
		[borderPath moveToPoint:point];
		point.x += kTriangleSize;
		point.y += kTriangleSize;
		[borderPath lineToPoint:point];
		point.x += kTriangleSize;
		point.y -= kTriangleSize;
		[borderPath lineToPoint:point];
		// And fill
		[[NSColor windowBackgroundColor] setFill];
		[borderPath fill];
	}

	
	if(!isUnanchoredView && drawUnanchorPending)
	{
		NSBezierPath *trianglePath = [NSBezierPath bezierPath];
		// Draw a triangle at the top. We are not flipped (the default), so our origin is the bottom left.
		NSPoint point =NSMakePoint(floor(NSMidX(bounds) - kTriangleSize)-offsetX, NSMaxY(bounds));
		[trianglePath moveToPoint:point];
		point.x += kTriangleSize;
		point.y += kTriangleSize;
		[trianglePath lineToPoint:point];
		point.x += kTriangleSize;
		point.y -= kTriangleSize;
		[trianglePath lineToPoint:point];
		[trianglePath closePath];
		
		[[NSColor colorWithCalibratedWhite:0. alpha:.2] setFill];
		[trianglePath fill];
	}
}

- (void)setOffsetX:(CGFloat)value
{
	CGFloat maxOffset = NSMidX(self.bounds)-kTriangleSize-kCornerRadius;
	offsetX = MIN(value, maxOffset);
	offsetX = MAX(offsetX, -maxOffset);
}

- (void)mouseDown:(NSEvent*)theEvent
{
	if(!isUnanchoredView)
	{
		NSPoint hit = [self convertPoint:[theEvent locationInWindow] fromView:nil];
		
		NSRect bounds = self.bounds;
		bounds.size.height -= kTriangleSize;
		NSBezierPath *trianglePath = [NSBezierPath bezierPath];
		// Draw a triangle at the top. We are not flipped (the default), so our origin is the bottom left.
		NSPoint point =NSMakePoint(floor(NSMidX(bounds) - kTriangleSize)-offsetX, NSMaxY(bounds));
		[trianglePath moveToPoint:point];
		point.x += kTriangleSize;
		point.y += kTriangleSize;
		[trianglePath lineToPoint:point];
		point.x += kTriangleSize;
		point.y -= kTriangleSize;
		[trianglePath lineToPoint:point];
		[trianglePath closePath];
		
		if([trianglePath containsPoint:hit])
		{
			hitOffset = hit;
			unanchorPending=YES;
			drawUnanchorPending=YES;
			[self setNeedsDisplay:YES];
		}
	}
}

- (void)mouseDragged:(NSEvent*)theEvent
{
	if(!isUnanchoredView && unanchorPending)
	{
		NSPoint hit = [theEvent locationInWindow];
		hit=[self.window convertBaseToScreen:[self convertPoint:hit fromView:nil]];
		NSPoint newOrigin = NSMakePoint(hit.x-hitOffset.x, hit.y-hitOffset.y);
		[[self window] setFrameOrigin:newOrigin];
	}
}

- (void)mouseUp:(NSEvent*)theEvent
{
	if(!isUnanchoredView)
	{
		[[self window] setMovableByWindowBackground:NO];
		if(unanchorPending && drawUnanchorPending)
		{
			[viewController unanchorView];
			[[self window] setMovableByWindowBackground:YES];
		}
		unanchorPending=NO;
		drawUnanchorPending=NO;
		[self setNeedsDisplay:YES];
	}
}

@end
