//
//  P3DLoopsPreviewController.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 17.01.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import "P3DGCodePreviewController.h"
#import "GCodeView.h"
#import "ParsedGCode.h"
#import <P3DCore/P3DCore.h>


@implementation P3DGCodePreviewController
@synthesize previewView, gCode;

- (void)awakeFromNib
{
	[self bind:@"gCode" toObject:self withKeyPath:@"representedObject.previewData" options:nil];
	[previewView bind:@"currentLayerHeight" toObject:self withKeyPath:@"representedObject.sliceNDiceHost.currentPreviewLayerHeight" options:nil];
}

- (void)setGCode:(GCode*)value
{
	if(value != gCode)
	{
		gCode = value;
		NSString* gCodeString = gCode.gCodeString;
		parsedGCode = [[ParsedGCode alloc] initWithGCodeString:gCodeString];
		dispatch_async(dispatch_get_main_queue(), ^{
			if([parsedGCode.panes count]>0)
			{
				previewView.parsedGCode =parsedGCode;
				
				// This is a hack! Otherwise, the OpenGL-View doesn't reshape properly.
				// Not sure if this is a SnowLeopard Bug...
				NSRect b = [previewView bounds];
				[previewView setFrame:NSInsetRect(b, 1, 1)];
				[previewView setFrame:b];
			}
			else
			{
				previewView.parsedGCode = nil;
			}
		});
	}
}
@end
