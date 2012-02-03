//
//  GCodeDocument.m
//  PleasantSTL
//
//  Created by Eberhard Rensch on 18.10.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
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

#import "GCodeDocument.h"
#import "GCodeView.h"
#import <P3DCore/P3DCore.h>
#import <P3DCore/NSArray+GCode.h>
#import "ParsedGCode.h"
#import "P3DMachiningController.h"

@implementation GCodeDocument
@synthesize gCodeString, openGLView, calculatingPreview, maxLayers, currentPreviewLayerHeight;
@dynamic gCodeToMachine, formattedGCode;

+ (NSSet *)keyPathsForValuesAffectingCorrectedMaxLayers {
    return [NSSet setWithObjects:@"maxLayers", nil];
}

- (NSString *)windowNibName {
    // Implement this to return a nib to load OR implement -makeWindowControllers to manually create your controllers.
    return @"GCodeDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];
    [openGLView bind:@"currentMachine" toObject:self withKeyPath:@"currentMachine" options:nil];
}

- (NSInteger)correctedMaxLayers
{
	return maxLayers+1;
}

- (NSString*)gCodeToMachine
{
	return self.gCodeString;
}

- (NSAttributedString*)formattedGCode
{
    return [[NSAttributedString alloc] initWithString:gCodeString];
}

- (void)setFormattedGCode:(NSAttributedString*)value
{
    self.gCodeString = value.string;
}

- (void)setGCodeString:(NSString*)value;
{
	if(gCodeString!=value)
	{
		self.calculatingPreview=YES;
		gCodeString = value;
		
		if(gCodeString)
		{
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

				ParsedGCode* parsedGCode = [[ParsedGCode alloc] initWithGCodeString:value];						
				dispatch_async(dispatch_get_main_queue(), ^{
					if([parsedGCode.panes count]>0)
					{
						self.maxLayers = [parsedGCode.panes count]-1;
						self.currentPreviewLayerHeight=0.;
						openGLView.parsedGCode = parsedGCode;
						
						// This is a hack! Otherwise, the OpenGL-View doesn't reshape properly.
						// Not sure if this is a SnowLeopard Bug...
						NSRect b = [openGLView bounds];
						[openGLView setFrame:NSInsetRect(b, 1, 1)];
						[openGLView setFrame:b];
					}
					else
					{
						self.maxLayers = 0;
						self.currentPreviewLayerHeight=0.;
						openGLView.parsedGCode = nil;
					}
					self.calculatingPreview=NO;
				});
			});
		}
		else
		{
			self.maxLayers = 0;
			self.currentPreviewLayerHeight=0.;
			openGLView.parsedGCode = nil;
			self.calculatingPreview=NO;
		}
	}
}


- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	self.gCodeString = nil;
	if([typeName isEqualToString:@"com.pleasantsoftware.uti.gcode"])
	{
		self.gCodeString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	}
    if (gCodeString==nil && outError != NULL ) {
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
	}
    return (gCodeString!=nil);
}

- (BOOL)canPrintDocument
{
	return YES;
}

- (IBAction)printDocument:(id)sender
{
	P3DMachiningController* printer = [[P3DMachiningController alloc] initWithMachinableDocument:self];
	[printer showPrintDialog];
}

- (void)textDidChange:(NSNotification *)aNotification
{
    [changesCommitTimer invalidate];
    changesCommitTimer = [NSTimer scheduledTimerWithTimeInterval:2. target:self selector:@selector(commitChanges:) userInfo:[aNotification object] repeats:NO];
}

- (void)commitChanges:(NSTimer*)timer
{
    NSTextView* tv = (NSTextView*)[timer userInfo];
    self.gCodeString = [[tv textStorage] string];
}

@end
