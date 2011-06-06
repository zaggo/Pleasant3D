//
//  PSDocumentController.h
//  PleasantSTL
//
//  Created by Eberhard Rensch on 18.10.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <P3DCore/P3DCore.h>

@class PSToolboxPanel;
@interface P3DDocumentController : NSDocumentController {
	IBOutlet PSToolboxPanel* toolbox;
	P3DMachiningQueue* machiningQueue;
	IBOutlet NSWindow* machiningQueueWindow;
}
@property (retain) IBOutlet PSToolboxPanel* toolbox;
@property (retain) IBOutlet NSWindow* machiningQueueWindow;
@property (readonly) P3DMachiningQueue* machiningQueue;

- (IBAction)showMachiningQueue:(id)sender;
- (IBAction)showPreferences:(id)sender;

@end
