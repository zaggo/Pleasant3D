//
//  ToolSettingsViewController.m
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

#import "ToolSettingsViewController.h"
#import "P3DPopupWindow.h"
#import "P3DToolBase.h"
#import "P3DBorderView.h"

NSString* const P3DToolSettingsWindowCloseNotification = @"P3DToolSettingsWindowClose";

@implementation ToolSettingsViewController
@synthesize window = _window;

- (void)_createWindowIfNeeded {
	if (_window == nil) {
        NSRect viewFrame = self.view.frame;
        // Create and setup our window
        _window = [[P3DPopupWindow alloc] initWithContentRect:viewFrame styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
        [_window setReleasedWhenClosed:NO];
//        [_window setLevel:NSPopUpMenuWindowLevel];
        [_window setLevel:NSFloatingWindowLevel];
        [_window setHasShadow:YES];        
        
        // Make the window have a clear color and be non-opaque for our pop-up animation
        [_window setBackgroundColor:[NSColor clearColor]];
        [_window setOpaque:NO];
    }
	if([self.view window] != _window)
		[[_window contentView] addSubview:self.view];
}

- (void)_windowClosed:(NSNotification *)note {
    if (_eventMonitor) {
        [NSEvent removeMonitor:_eventMonitor];
        _eventMonitor = nil;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillCloseNotification object:_window];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSApplicationDidResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:P3DToolSettingsWindowCloseNotification object:nil];
}

- (void)_closeAndSendAction:(BOOL)sendAction {
	
    [_window close];
    if (sendAction) {
		[_window makeFirstResponder:nil];
		[(P3DToolBase*)[self representedObject] reprocessData:self];
    } else {
    }
}

- (void)_windowShouldClose:(NSNotification *)note {
    [self _closeAndSendAction:NO];
}

- (void)_panelShouldClose:(NSNotification *)note {
	//NSLog(@"[note object] = %p self.representedObject = %p representedObject = %@", [note object], self.representedObject, NSStringFromClass([self.representedObject class]));
	if([note object]==nil || [note object] == self.representedObject)
	{
		[_panelWindow close];
	//	NSLog(@"-> closing");
	}
}


- (void)_panelClosed:(NSNotification *)note {
	[_panelWindow makeFirstResponder:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillCloseNotification object:_panelWindow];
	((P3DBorderView*)self.view).isUnanchoredView=NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:P3DToolSettingsWindowCloseNotification object:nil];
}


- (void)editToolLocatedAtScreenRect:(NSRect)rect;
{
	if([_panelWindow isVisible])
		[_panelWindow makeKeyAndOrderFront:self];
	else
	{
		[self _createWindowIfNeeded];
		
		//[self _selectColor:color];
		NSPoint origin = rect.origin;
		NSRect windowFrame = [_window frame];
		// The origin is the lower left; subtract the window's height
		origin.y -= NSHeight(windowFrame);
		// Center the popup window under the rect
		origin.y += floor(NSHeight(rect) / 3.0);
		origin.x -= floor(NSWidth(windowFrame) / 2.0);
		origin.x += floor(NSWidth(rect) / 2.0);
		
		// Constrain the Window to the Current Screen
		CGFloat offsetX=0.;
		NSRect screenRect = NSInsetRect([[_window screen] visibleFrame], 8., 0.);
		if(origin.x<NSMinX(screenRect))
			offsetX = NSMinX(screenRect)-origin.x;
		else if(origin.x+NSWidth(windowFrame)>NSMaxX(screenRect))
			offsetX = NSMaxX(screenRect)-(origin.x+NSWidth(windowFrame));
		origin.x+=offsetX;
		((P3DBorderView*)self.view).offsetX=offsetX;
		
		[_window setFrameOrigin:origin];
		[_window popup];
		
		// Add some watches on the window and application
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_windowClosed:) name:NSWindowWillCloseNotification object:_window];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_windowShouldClose:) name:NSApplicationDidResignActiveNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_windowShouldClose:) name:P3DToolSettingsWindowCloseNotification object:nil];
		
		// Start watching events to figure out when to close the window
		NSAssert(_eventMonitor == nil, @"_eventMonitor should not be created yet");
		_eventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSLeftMouseDownMask | NSRightMouseDownMask | NSOtherMouseDownMask | NSKeyDownMask handler:^(NSEvent *incomingEvent) {
			NSEvent *result = incomingEvent;
			NSWindow *targetWindowForEvent = [incomingEvent window];
			if (targetWindowForEvent != _window) {
				[self _closeAndSendAction:NO];
			} else if ([incomingEvent type] == NSKeyDown) {
				if ([incomingEvent keyCode] == 53) {
					// Escape
					[self _closeAndSendAction:NO];
					result = nil; // Don't process the event
				} else if ([incomingEvent keyCode] == 36) {
					// Enter
					[self _closeAndSendAction:YES];
					result = nil;
				}
			}
			return result;
		}];
	}
}

- (void)unanchorView
{
	NSDisableScreenUpdates();
	
	if(_panelWindow==nil)
	{
		NSRect viewFrame = self.view.frame;
		_panelWindow = [[NSPanel alloc] initWithContentRect:viewFrame styleMask:NSUtilityWindowMask|NSTitledWindowMask|NSClosableWindowMask/*|NSHUDWindowMask*/ backing:NSBackingStoreBuffered defer:NO];
		
		[_panelWindow setReleasedWhenClosed:NO];
		[_panelWindow setLevel:NSNormalWindowLevel];
		[_panelWindow setHasShadow:YES];        
		[_panelWindow setTitle:[self.representedObject localizedToolName]];        
		[_panelWindow setHidesOnDeactivate:YES];
	}
	
	((P3DBorderView*)self.view).isUnanchoredView=YES;
	[_panelWindow setFrameOrigin:[_window frame].origin];
	if([self.view window] != _panelWindow)
		[[_panelWindow contentView] addSubview:self.view];
	[_window close];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_panelShouldClose:) name:P3DToolSettingsWindowCloseNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_panelClosed:) name:NSWindowWillCloseNotification object:_panelWindow];
	[_panelWindow makeKeyAndOrderFront:self];
	
	NSEnableScreenUpdates();
}

- (IBAction)valueRequireingRecalculationDidChange:(id)sender
{
	[self.representedObject reprocessData:sender];
}

@end
