//
//  P3DLoopsPreviewController.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 17.01.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import "P3DLoopsPreviewController.h"
#import "P3DLoopsPreviewView.h"
#import <P3DCore/P3DCore.h>


@implementation P3DLoopsPreviewController
@synthesize previewView;

- (void)awakeFromNib
{
	[previewView bind:@"loops" toObject:self withKeyPath:@"representedObject.previewData" options:nil];
	[previewView bind:@"currentLayerHeight" toObject:self withKeyPath:@"representedObject.sliceNDiceHost.currentPreviewLayerHeight" options:nil];
}

@end
