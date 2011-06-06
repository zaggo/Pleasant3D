//
//  STLPreviewController.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 14.01.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import "STLPreviewController.h"
#import "STLPreviewView.h"
#import <P3DCore/P3DCore.h>

@implementation STLPreviewController
@synthesize previewView;

- (void)awakeFromNib
{
	[previewView bind:@"stlModel" toObject:self withKeyPath:@"representedObject.previewData.stlModel" options:nil];
}

@end
