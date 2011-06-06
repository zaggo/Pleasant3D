//
//  ToolBinView.h
//  MacSkeinforge
//
//  Created by Eberhard Rensch on 02.08.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class P3DToolBase, ToolPanelView;
@interface ToolBinView : NSView {
	NSInteger gapAtIndex;
	NSMutableArray* toolViewControllers;	
}
@property (assign) NSUInteger indexOfPreviewedTool;
@property (readonly) BOOL canPrintDocument;

- (void)resizeToolBin;
- (void)removeToolFromToolBin:(P3DToolBase*)tool;
- (void)disableOtherPreviews:(P3DToolBase*)exclude;
- (void)dragToolPanel:(ToolPanelView*)panel withEvent:(NSEvent*)theEvent;
- (NSArray*)currentToolsArray;
- (BOOL)deserializeTools:(NSArray*)serializedTools;

- (void)reprocessProject;
@end
