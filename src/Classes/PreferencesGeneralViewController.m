//
//  PreferencesGeneralViewController.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 24.03.2010.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import "PreferencesGeneralViewController.h"


@implementation PreferencesGeneralViewController

- (NSString *)title
{
	return NSLocalizedString(@"General", @"Title of 'General' preference pane");
}

- (NSString *)identifier
{
	return @"PreferencesGeneralPane";
}

- (NSImage *)image
{
	return [NSImage imageNamed:@"NSPreferencesGeneral"];
}

@end