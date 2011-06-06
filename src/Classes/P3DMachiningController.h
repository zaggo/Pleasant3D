//
//  PrintController.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 18.02.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <P3DCore/P3DCore.h>

@interface P3DMachiningController : NSObject {
	P3DMachinableDocument* document;
	
	IBOutlet NSWindow* printSheet;
	IBOutlet NSView* contentView;
	
	NSString* selectedMachineUUID;
}
@property (retain) P3DMachinableDocument* document;
@property (readonly) ConfiguredMachines* configuredMachines;
@property (assign) NSInteger selectedMachineIndex;

- (id) initWithMachinableDocument:(P3DMachinableDocument*)doc;

- (void)showPrintDialog;

- (IBAction)printPressed:(id)sender;
- (IBAction)cancelPressed:(id)sender;

@end
