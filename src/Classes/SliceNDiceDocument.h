//
//  MyDocument.h
//  MacSkeinforge
//
//  Created by Eberhard Rensch on 23.07.09.
//  Copyright Pleasant Software 2009 . All rights reserved.
//


#import <Cocoa/Cocoa.h>
#import <P3DCore/P3DCore.h>

@class ToolBinView, MachinePool;
@interface SliceNDiceDocument : P3DMachinableDocument <NSBrowserDelegate, SliceNDiceHost>
{
	IBOutlet ToolBinView* toolBin;	
	IBOutlet NSView* previewView;
	NSViewController* previewController;

	NSInteger saveMode;
	BOOL saveToDisk;
	
	float currentPreviewLayerHeight;
	
	NSData* loadedDocData;
}
@property (assign) IBOutlet NSView* previewView;
@property (assign) IBOutlet ToolBinView* toolBin;
@property (retain) NSViewController* previewController;
@property (assign) float currentPreviewLayerHeight;
@property (assign) NSInteger saveMode;
@property (readonly) BOOL encodeLightWeight;

@end
