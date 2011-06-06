//
//  ToolSettingsViewController.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 02.08.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString* const P3DToolSettingsWindowCloseNotification;

@class P3DPopupWindow;
@interface ToolSettingsViewController : NSViewController {
    P3DPopupWindow *_window;
	NSPanel* _panelWindow;
    id _eventMonitor;	
}

@property (readonly) P3DPopupWindow * window;

- (void)editToolLocatedAtScreenRect:(NSRect)rect;
- (void)unanchorView;

- (IBAction)valueRequireingRecalculationDidChange:(id)sender;
@end
