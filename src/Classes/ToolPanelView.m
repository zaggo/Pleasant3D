//
//  ToolPanelView.m
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

#import "ToolPanelView.h"
#import <P3DCore/P3DCore.h>
#import "SliceNDiceDocument.h"
#import "ToolBinView.h"

static CGColorRef CGColorCreateFromNSColor(NSColor *color)
{
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB ();
	NSColor *deviceColor = [color colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	
	CGFloat components[4];
	[deviceColor getRed: &components[0] green: &components[1] blue:&components[2] alpha:&components[3]];
	
	CGColorRef cgColorRef = CGColorCreate (colorSpace, components);
	CGColorSpaceRelease (colorSpace);
	return cgColorRef;
}

static NSColor* _panelColorTop = nil;
static NSColor* _panelColorBottom = nil;
static NSShadow* _nonLayeredShadow = nil;
static NSShadow* _nonLayeredUnShadow = nil;

@implementation ToolPanelView
@synthesize isSelected, viewController, contextMenu;
+ (void) initialize
{
	_panelColorTop = [NSColor colorWithDeviceRed:0.891 green:0.500 blue:0.138 alpha:1.];
	_panelColorBottom = [NSColor colorWithDeviceRed:1. green:0.561 blue:0.155 alpha:1.];
	_nonLayeredShadow = [[NSShadow alloc] init];
	[_nonLayeredShadow setShadowOffset:NSMakeSize(0., -2.)];
	[_nonLayeredShadow setShadowBlurRadius:2.];
	[_nonLayeredShadow setShadowColor:[NSColor colorWithDeviceWhite:0. alpha:.75]];
	_nonLayeredUnShadow = [[NSShadow alloc] init];
}

- (void)awakeFromNib
{
	NSRect backgroundRect = NSInsetRect([self bounds], 2., 2.);
	backgroundRect.origin.y=NSHeight([self bounds])-NSHeight(backgroundRect);
	
	backgroundLayer = [CAGradientLayer layer];
	
	CGColorRef cgTop = CGColorCreateFromNSColor(_panelColorTop);
	CGColorRef cgBottom = CGColorCreateFromNSColor(_panelColorBottom);
	backgroundLayer.colors = [NSArray arrayWithObjects:(id)cgTop, (id)cgBottom, nil];
	CGColorRelease(cgTop);
	CGColorRelease(cgBottom);
	
	backgroundLayer.frame = NSRectToCGRect(backgroundRect);
	backgroundLayer.cornerRadius=5.;
	backgroundLayer.shadowOpacity = .75;
	backgroundLayer.shadowOffset = CGSizeMake(0., -2.);
	backgroundLayer.shadowRadius = 2.;
	backgroundLayer.opaque=YES;
	[self.layer insertSublayer:backgroundLayer atIndex:0];

	panelShape = [NSBezierPath bezierPathWithRoundedRect:backgroundRect xRadius:5. yRadius:5.];
	nonLayeredBackground = [[NSGradient alloc] initWithColors:[NSArray arrayWithObjects:_panelColorTop, _panelColorBottom, nil]];
}

- (void)setIsSelected:(BOOL)value
{
	if(value!=isSelected)
	{
		isSelected = value;
		if(isSelected)
		{
			CGColorRef cgTop = CGColorCreateGenericRGB(.369, .576, .98, 1.);
			CGColorRef cgBottom = CGColorCreateGenericRGB(.337, .545, .976, 1.);
			backgroundLayer.colors = [NSArray arrayWithObjects:(id)cgTop, (id)cgBottom, nil];
			CGColorRelease(cgTop);
			CGColorRelease(cgBottom);
		}			
		else
		{
			CGColorRef cgTop = CGColorCreateFromNSColor(_panelColorTop);
			CGColorRef cgBottom = CGColorCreateFromNSColor(_panelColorBottom);
			backgroundLayer.colors = [NSArray arrayWithObjects:(id)cgTop, (id)cgBottom, nil];
			CGColorRelease(cgTop);
			CGColorRelease(cgBottom);
		}			
	}
}

- (void)drawRect:(NSRect)dirtyRect
{
	if(useCocoaBackground)
	{
		[_nonLayeredShadow set];
		[panelShape fill];
		[nonLayeredBackground drawInBezierPath:panelShape angle:-90.];
		[_nonLayeredUnShadow set];
	}
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)rightMouseDown:(NSEvent *)theEvent
{
	NSLog(@"rightMouseDown: %@", [(P3DToolBase*)[[self viewController] representedObject] localizedToolName]);
	[contextMenu popUpMenuPositioningItem:nil atLocation:[self convertPoint:[theEvent locationInWindow] fromView:nil]  inView:self];
}

- (void)mouseDown:(NSEvent *)theEvent
{
	if([theEvent modifierFlags]&  NSControlKeyMask)
		[self rightMouseDown:theEvent];
	else
		self.isSelected = YES;
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	if(self.isSelected) // Otherwise, thePanel is already dragged
	{
		self.isSelected=NO;
		P3DToolBase* tool = (P3DToolBase*)[[self viewController] representedObject];
		ToolBinView* toolBin = ((SliceNDiceDocument*)(tool.sliceNDiceHost)).toolBin;
		[toolBin dragToolPanel:self withEvent:theEvent];
	}
}

- (void)mouseUp:(NSEvent *)theEvent
{
	if(self.isSelected) // Otherwise, thePanel was dragged
	{
		self.isSelected = NO;
		
		P3DToolBase* tool = (P3DToolBase*)[[self viewController] representedObject];
		if(tool.isWorking)
			[tool abortProcessData:self];
		else if(([theEvent modifierFlags]&NSAlternateKeyMask)!=0)
		{
			[tool reprocessData:self];
		}
		else
		{
			ToolSettingsViewController* cntrl = [tool settingsViewController];
			if(cntrl)
			{
				NSRect panelRectInScreenCoordinates = [self convertRectToBase:[self convertRect:[self bounds] toView:nil]];
				panelRectInScreenCoordinates.origin = [self.window convertBaseToScreen:panelRectInScreenCoordinates.origin];
				panelRectInScreenCoordinates.origin.y-=NSHeight([self bounds])/3.-3.;
				[cntrl editToolLocatedAtScreenRect:panelRectInScreenCoordinates];
			}
			else
			{
				[tool customSettingsAction:self];
			}
		}
	}
}

- (NSImage*)imageForDragging
{
	NSRect visibleRect = [self visibleRect];
	
	NSBitmapImageRep *bitmap = [self bitmapImageRepForCachingDisplayInRect:visibleRect];
	useCocoaBackground=YES;
	[self cacheDisplayInRect:visibleRect toBitmapImageRep:bitmap];
	useCocoaBackground=NO;		
	
	NSImage* dragImage = [[NSImage alloc] initWithSize:visibleRect.size];
	[dragImage addRepresentation:bitmap];
	return dragImage;
}	
@end
