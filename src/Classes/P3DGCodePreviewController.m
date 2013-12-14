//
//  P3DLoopsPreviewController.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 17.01.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
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

#import "P3DGCodePreviewController.h"
#import "GCodeView.h"
#import "ParsedGCode.h"
#import <P3DCore/P3DCore.h>


@implementation P3DGCodePreviewController
{
    ParsedGCode* _parsedGCode;
}

- (void)awakeFromNib
{
	[self bind:@"gCode" toObject:self withKeyPath:@"representedObject.previewData" options:nil];
	[_previewView bind:@"currentLayerHeight" toObject:self withKeyPath:@"representedObject.sliceNDiceHost.currentPreviewLayerHeight" options:nil];
}

- (void)setGCode:(GCode*)value
{
	if(value != _gCode)
	{
		_gCode = value;
		NSString* gCodeString = _gCode.gCodeString;
		_parsedGCode = [[ParsedGCode alloc] initWithGCodeString:gCodeString printer:nil];
		dispatch_async(dispatch_get_main_queue(), ^{
			if([_parsedGCode.panes count]>0)
			{
				_previewView.parsedGCode = _parsedGCode;
				
				// This is a hack! Otherwise, the OpenGL-View doesn't reshape properly.
				// Not sure if this is a SnowLeopard Bug...
				NSRect b = [_previewView bounds];
				[_previewView setFrame:NSInsetRect(b, 1, 1)];
				[_previewView setFrame:b];
			}
			else
			{
				_previewView.parsedGCode = nil;
			}
		});
	}
}
@end
