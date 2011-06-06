//
//  SliceNDiceHost.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 11.01.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define kP3DSaveModeFull		0
#define kP3DSaveModeLightWeight 1

@class P3DToolBase;
@protocol SliceNDiceHost
@property (retain) NSViewController* previewController;
@property (readonly) BOOL encodeLightWeight;
//@property (readonly) NSDictionary* currentMachineDescription;
//
//@property (assign) NSUInteger currentPreviewLayer;

- (void)removeToolFromToolBin:(P3DToolBase*)tool;
- (void)disableOtherPreviews:(P3DToolBase*)exclude;
- (NSWindow*)windowForSheet;
- (void)hideToolbox;
- (void)hideToolboxThenExecute:(NSOperation*)operation;
- (NSUndoManager*)undoManager;
- (NSViewController*)defaultPreviewControllerForTool:(P3DToolBase*)tool;
- (NSString*)projectPath;
@end
