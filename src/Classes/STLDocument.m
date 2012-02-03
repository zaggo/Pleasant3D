//
//  STLDocument.m
//  PleasantSTL
//
//  Created by Eberhard Rensch on 12.10.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
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


    [stlPreviewView bind:@"currentMachine" toObject:self withKeyPath:@"currentMachine" options:nil];
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
