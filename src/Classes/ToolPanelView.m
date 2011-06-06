//
//  ToolPanelView.m
//  MacSkeinforge
//
//  Created by Eberhard Rensch on 02.08.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
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
