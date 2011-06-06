//
//  STLDocument.m
//  PleasantSTL
//
//  Created by Eberhard Rensch on 12.10.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//

#import "STLDocument.h"
#import <P3DCore/P3DCore.h>
#import <P3DCore/STLImportPlugin.h>
#import <P3DCore/DAEImportPlugin.h>
#import <P3DCore/STLShapeShifter.h>

@implementation STLDocument
@synthesize stlShapeShifter, stlPreviewView, loadedSTLModel;

- (NSString *)windowNibName
{
    return @"STLDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];
	
	stlShapeShifter.undoManager = [self undoManager];
	[stlShapeShifter resetWithSTLModel:loadedSTLModel];
	[stlPreviewView bind:@"stlModel" toObject:stlShapeShifter withKeyPath:@"processedSTLModel" options:0];
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
	NSData* dataToSave=nil;
	if([typeName isEqualToString:@"com.pleasantsoftware.uti.stl"] && self.loadedSTLModel)
	{
		STLModel* processedModel = self.stlShapeShifter.processedSTLModel;
		self.loadedSTLModel = processedModel;
		stlShapeShifter.objectScale = 0.; // Force Reset
		[stlShapeShifter resetWithSTLModel:loadedSTLModel];
		[[self undoManager] removeAllActions];
		dataToSave=processedModel.stlData;
	}
		
    if ( outError != NULL ) {
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
	}
	return dataToSave;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	if(outError != NULL)
		*outError=nil;
	self.loadedSTLModel = nil;
	if([typeName isEqualToString:@"com.pleasantsoftware.uti.stl"])
	{
		STLImportPlugin* plugin = [[STLImportPlugin alloc] init];
		self.loadedSTLModel = [plugin readSTLModel:data];
		[stlShapeShifter resetWithSTLModel:loadedSTLModel];
	}
	else if([typeName isEqualToString:@"org.khronos.collada.digital-asset-exchange"])
	{
		DAEImportPlugin* plugin = [[DAEImportPlugin alloc] init];
		self.loadedSTLModel = [plugin readDAEModel:data error:outError];
		[stlShapeShifter resetWithSTLModel:loadedSTLModel];
	}
    if (self.loadedSTLModel==nil && outError != nil && *outError==nil) 
	{
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
	}
    return (self.loadedSTLModel!=nil);
}

- (BOOL)canPrintDocument
{
	return NO;
}
@end
