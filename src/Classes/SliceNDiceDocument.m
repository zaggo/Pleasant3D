//
//  MyDocument.m
//  MacSkeinforge
//
//  Created by Eberhard Rensch on 23.07.09.
//  Copyright Pleasant Software 2009 . All rights reserved.
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

#import "SliceNDiceDocument.h"
#import <P3DCore/P3DCore.h>
#import "ToolBinView.h"
#import <dispatch/dispatch.h>
#import "P3DDocumentController.h"
#import "ToolPool.h"
#import "STLPreviewController.h"
#import "P3DLoopsPreviewController.h"
#import "P3DGCodePreviewController.h"
#import "P3DMachiningController.h"

@implementation SliceNDiceDocument
@synthesize previewView, toolBin, previewController, currentPreviewLayerHeight, saveMode;
@dynamic encodeLightWeight, gCodeToMachine;

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"SliceNDiceDocument";
}

- (BOOL)handleLoadedDocData
{
	BOOL success = YES;
	if(loadedDocData)
	{		
		[[self undoManager] disableUndoRegistration];
		
		ToolPool* toolPool = [ToolPool sharedToolPool]; // Import Tools if necessary
		while(toolPool.loading)
			[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.1]];
			
		NSDictionary* docDict = [NSKeyedUnarchiver unarchiveObjectWithData:loadedDocData];
		success = [toolBin deserializeTools:[docDict objectForKey:@"tools"]];
		toolBin.indexOfPreviewedTool = [[docDict objectForKey:@"indexOfPreviewedTool"] unsignedIntegerValue];
		
		self.saveMode = [[docDict objectForKey:@"saveMode"] integerValue];
		if([self.configuredMachines configuredMachineForUUID:[docDict objectForKey:@"selectedMachineUUID"]]!=nil)
			self.selectedMachineUUID = [docDict objectForKey:@"selectedMachineUUID"];
		
		[[self undoManager] enableUndoRegistration];
	}
	[[self undoManager] removeAllActions];
	loadedDocData=nil;
	return success;
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];
	
	saveMode = 0;// [[NSUserDefaults standardUserDefaults] integerForKey:@"P3DDocumentSaveMode"];
	
	self.selectedMachineUUID = [[NSUserDefaults standardUserDefaults] objectForKey:@"defaultMachine"];
		
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
	[self handleLoadedDocData];	
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
	NSData* docData = nil;
	if([typeName isEqualToString:@"com.pleasantsoftware.uti.p3d"])
	{
		saveToDisk = YES; // see encodeLightWeight
		NSDictionary* docDict = [NSDictionary dictionaryWithObjectsAndKeys:
									[toolBin currentToolsArray], @"tools",
									[NSNumber numberWithUnsignedInteger:toolBin.indexOfPreviewedTool], @"indexOfPreviewedTool",
								 [NSNumber numberWithInteger:self.saveMode], @"saveMode",
								 self.selectedMachineUUID, @"selectedMachineUUID",
									nil];
									
		docData = [NSKeyedArchiver archivedDataWithRootObject:docDict];
		saveToDisk = NO; // see encodeLightWeight

	}
    if ( docData==nil && outError!=nil ) {
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:writErr userInfo:NULL];
	}
	return docData;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	loadedDocData = data;
	BOOL success = (loadedDocData!=nil);
	if(toolBin && loadedDocData)
	{
		[self handleLoadedDocData];	
	}
    
    if (!success && outError!=nil) {
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:openErr userInfo:NULL];
	}
    return success;
}

- (BOOL)encodeLightWeight
{
	// The save mode is only relevant for Disk Saving (i.e. Drag & Drop is always "full")
	return	saveToDisk && saveMode == kP3DSaveModeLightWeight;
}

- (void)setPreviewController:(NSViewController*)controller
{	
	if(controller)
	{
		PSLog(@"Preview", PSPrioNormal, @"Set preview to %@", NSStringFromClass([[controller view] class]));
		[[previewView animator] addSubview:[controller view]];
		[[controller view] setFrame:[previewView bounds]];
	}
	else
	{
		PSLog(@"Preview", PSPrioNormal, @"Remove preview of %@", NSStringFromClass([[previewController view] class]));
		[[[previewController view] animator] removeFromSuperview];
	}
	previewController = controller;
}

- (void)setSelectedMachineUUID:(NSString*)value
{
	if(![value isEqualToString:selectedMachineUUID])
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setSelectedMachineUUID:selectedMachineUUID];
		selectedMachineUUID = value;
		[toolBin reprocessProject]; // TODO: Necessary?
	}
}

- (BOOL)canPrintDocument
{
	return self.toolBin.canPrintDocument;
}

- (NSString*)gCodeToMachine
{
	return nil; // TODO
}

- (IBAction)printDocument:(id)sender
{
	if(self.canPrintDocument)
	{
		P3DMachiningController* printer = [[P3DMachiningController alloc] initWithMachinableDocument:self];
		[printer showPrintDialog];
	}
}

#pragma mark SliceNDiceHost protocol
- (void)disableOtherPreviews:(P3DToolBase*)exclude
{
	[self.toolBin disableOtherPreviews:exclude];
}

- (void)removeToolFromToolBin:(P3DToolBase*)tool
{
	[self.toolBin removeToolFromToolBin:tool];
}

- (void)hideToolbox
{
	[[[P3DDocumentController sharedDocumentController] toolbox] orderOut:nil];
}

- (void)hideToolboxThenExecute:(NSOperation*)operation
{
	PSToolboxPanel* toolbox = [[P3DDocumentController sharedDocumentController] toolbox];
	if(toolbox)
		[[[P3DDocumentController sharedDocumentController] toolbox] orderOut:operation];
	else
		[operation start];
}

- (NSViewController*)defaultPreviewControllerForTool:(P3DToolBase*)tool 
{
	NSViewController* defaultPreviewViewController=nil;
	NSString* previewFormat = [tool providesPreviewFormat];
	if([previewFormat isEqualToString:P3DFormatIndexedSTL])
	{
		defaultPreviewViewController = [[STLPreviewController alloc] initWithNibName:@"STLImportPreviewGUI" bundle:nil];
		[defaultPreviewViewController setRepresentedObject:tool];
	}
	else if([previewFormat isEqualToString:P3DFormatLoops])
	{
		defaultPreviewViewController = [[P3DLoopsPreviewController alloc] initWithNibName:@"P3DLoopsPreviewGUI" bundle:nil];
		[defaultPreviewViewController setRepresentedObject:tool];
	}
	else if([previewFormat isEqualToString:P3DFormatGCode])
	{
		defaultPreviewViewController = [[P3DGCodePreviewController alloc] initWithNibName:@"P3DGCodePreviewGUI" bundle:nil];
		[defaultPreviewViewController setRepresentedObject:tool];
	}
	
	return defaultPreviewViewController;
}

+ (NSSet *)keyPathsForValuesAffectingProjectPath {
    return [NSSet setWithObjects:@"fileURL", nil];
}

- (NSString*)projectPath
{
	return [[self fileURL] path];
}

@end
