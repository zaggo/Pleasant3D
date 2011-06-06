//
//  PreferencesGeneralViewController.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 24.03.2010.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MBPreferencesController.h"

@interface PreferencesGeneralViewController : NSViewController <MBPreferencesModule> {

}

- (NSString *)identifier;
- (NSImage *)image;

@end
