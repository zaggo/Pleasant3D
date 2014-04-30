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
#import "PSToolboxPanel.h"

@implementation SliceNDiceDocument
{
	BOOL _saveToDisk;
	NSData* _loadedDocData;
}

@dynamic encodeLightWeight, rawGCode;

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"SliceNDiceDocument";
}

- (BOOL)handleLoadedDocData
{
	BOOL success = YES;
	if(_loadedDocData)
	{		
		[[self undoManager] disableUndoRegistration];
		
		ToolPool* toolPool = [ToolPool sharedToolPool]; // Import Tools if necessary
		while(toolPool.loading)
			[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.1]];
			
		NSDictionary* docDict = [NSKeyedUnarchiver unarchiveObjectWithData:_loadedDocData];
		success = [_toolBin deserializeTools:[docDict objectForKey:@"tools"]];
		_toolBin.indexOfPreviewedTool = [[docDict objectForKey:@"indexOfPreviewedTool"] unsignedIntegerValue];
		
		self.saveMode = [[docDict objectForKey:@"saveMode"] integerValue];
		if([self.configuredMachines configuredMachineForUUID:[docDict objectForKey:@"selectedMachineUUID"]]!=nil)
			self.selectedMachineUUID = [docDict objectForKey:@"selectedMachineUUID"];
		
		[[self undoManager] enableUndoRegistration];
	}
	[[self undoManager] removeAllActions];
	_loadedDocData=nil;
	return success;
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];
	
	_saveMode = 0;// [[NSUserDefaults standardUserDefaults] integerForKey:@"P3DDocumentSaveMode"];
		
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
	[self handleLoadedDocData];	
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
	NSData* docData = nil;
	if([typeName isEqualToString:@"com.pleasantsoftware.uti.p3d"])
	{
		_saveToDisk = YES; // see encodeLightWeight
		NSDictionary* docDict = [NSDictionary dictionaryWithObjectsAndKeys:
									[_toolBin currentToolsArray], @"tools",
									[NSNumber numberWithUnsignedInteger:_toolBin.indexOfPreviewedTool], @"indexOfPreviewedTool",
								 [NSNumber numberWithInteger:self.saveMode], @"saveMode",
								 self.selectedMachineUUID, @"selectedMachineUUID",
									nil];
									
		docData = [NSKeyedArchiver archivedDataWithRootObject:docDict];
		_saveToDisk = NO; // see encodeLightWeight

	}
    if ( docData==nil && outError!=nil ) {
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:writErr userInfo:NULL];
	}
	return docData;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	_loadedDocData = data;
	BOOL success = (_loadedDocData!=nil);
	if(_toolBin && _loadedDocData)
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
	return	_saveToDisk && _saveMode == kP3DSaveModeLightWeight;
}

- (void)setPreviewController:(NSViewController*)controller
{	
	if(controller)
	{
		PSLog(@"Preview", PSPrioNormal, @"Set preview to %@", NSStringFromClass([[controller view] class]));
		[[_previewView animator] addSubview:[controller view]];
		[[controller view] setFrame:[_previewView bounds]];
	}
	else
	{
		PSLog(@"Preview", PSPrioNormal, @"Remove preview of %@", NSStringFromClass([[_previewController view] class]));
		[[[_previewController view] animator] removeFromSuperview];
	}
	_previewController = controller;
}

- (void)setSelectedMachineUUID:(NSString*)value
{
	if(![value isEqualToString:self.selectedMachineUUID])
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setSelectedMachineUUID:self.selectedMachineUUID];
		super.selectedMachineUUID = value;
        [_toolBin reprocessProject]; // TODO: Necessary?
	}
}

- (BOOL)canPrintDocument
{
	return self.toolBin.canPrintDocument;
}

- (NSString*)rawGCode
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
