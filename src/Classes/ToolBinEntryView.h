//
//  ToolBinEntryView.h
//  MacSkeinforge
//
//  Created by Eberhard Rensch on 02.08.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define kToolBinEntryViewWidth 150.

@interface ToolBinEntryView : NSView {

}

- (void)moveToX:(CGFloat)newX animated:(BOOL)animated;
//- (void)moveBy:(CGFloat)moveBy animated:(BOOL)animated;

@end
