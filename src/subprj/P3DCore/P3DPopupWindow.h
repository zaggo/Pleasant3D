//
//  P3DPopupWindow.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 02.08.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//

#import <Quartz/Quartz.h>
#import <Cocoa/Cocoa.h>

@interface P3DPopupWindow : NSWindow {
@private
    NSRect _originalWidowFrame;
    NSRect _originalLayerFrame;
    
    NSView *_oldContentView;
    NSResponder *_oldFirstResponder;
    NSView *_animationView;
    CALayer *_animationLayer;
    
    BOOL _growing;
    BOOL _shrinking;
    BOOL _pretendKeyForDrawing;
}

- (void)popup;

@end
