//
//  P3DPopupWindow.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 02.08.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//	Based on Apple's sample code for ATPopupWindow
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
#import <QuartzCore/QuartzCore.h>
#import "P3DPopupWindow.h"

#define GROW_ANIMATION_DURATION 0.20
#define GROW_SCALE 1.25

#define SHRINK_ANIMATION_DURATION 0.10
#define SHRINK_SCALE 0.80

#define RESTORE_ANIMATION_DURATION 0.10

@implementation P3DPopupWindow

- (void)_cleanupAndRestoreViews {
    // Swap back the content view
    if (_oldContentView != nil) {
        // We disable screen updates to avoid any flashing that might happening when one layer backed view goes away and another regular view replaces it.
        NSDisableScreenUpdates();
        [self setFrame:_originalWidowFrame display:NO];
        [self setContentView:_oldContentView];
        [_oldContentView release];
        _oldContentView = nil;
        
        [self makeFirstResponder:_oldFirstResponder];
        _oldFirstResponder = nil;
        
        [_animationView release];
        _animationView = nil;
        
        _animationLayer = nil; // Non retained
        NSEnableScreenUpdates();
    }
    _shrinking = NO;
    _growing = NO;
}

- (CATransform3D)_transformForScale:(CGFloat)scale {
    if (scale == 1.0) {
        return CATransform3DIdentity;
    } else {
        // Start at the scale percentage
        CATransform3D scaleTransform = CATransform3DScale(CATransform3DIdentity, scale, scale, 1.0);
        // Create a translation to make us popup from somewhere other than the center
        CGFloat yTrans = NSHeight(_originalLayerFrame)/2.0 - (NSHeight(_originalLayerFrame)*scale)/2.0;
        CGFloat xTrans = 0; // No X translating -- we popup from the X center
        CATransform3D translateTransform = CATransform3DTranslate(CATransform3DIdentity, xTrans, yTrans, 1.0);
        return CATransform3DConcat(scaleTransform, translateTransform);
    }
}

- (void)_addAnimationToScale:(CGFloat)scale duration:(NSTimeInterval)duration {
    CABasicAnimation *transformAni = [CABasicAnimation animation];
    transformAni.fromValue = [NSValue valueWithCATransform3D:_animationLayer.transform];
    transformAni.duration = duration;
    // We make ourselves the delegate to get notified when the animation ends
    transformAni.delegate = self;
    // Set the final "toValue" for the animation and the layer contents. 
    // At the end of the animation it is left at this value, which is what we want
    _animationLayer.transform = [self _transformForScale:scale];
    [_animationLayer addAnimation:transformAni forKey:@"transform"];
}

// Chain several animations together -- one starting at the end of the other
- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
    if (!flag) {
        _animationLayer.transform = [self _transformForScale:1.0];
        [self _cleanupAndRestoreViews];
    } else if (_growing) {
        _growing = NO;
        _shrinking = YES;
        [self _addAnimationToScale:SHRINK_SCALE duration:SHRINK_ANIMATION_DURATION];
    } else if (_shrinking) {
        _shrinking = NO;
        [self _addAnimationToScale:1.0 duration:RESTORE_ANIMATION_DURATION];
    } else {
        [self _cleanupAndRestoreViews];
    }
}

// Our window doesn't have a title bar or a resize bar, but we want it to still become key. However, we want the tableview to draw as the first responder even when the window isn't key. So, we return NO when we are drawing to work around that.
- (BOOL)canBecomeKeyWindow {
    if (_pretendKeyForDrawing) return NO;
    return YES;
}

// The scrollers always draw blue if they are in a key window. Temporarily tell them that our window is key for caching the proper image.
- (BOOL)isKeyWindow {
    if (_pretendKeyForDrawing) return YES;
    return [super isKeyWindow];
}

- (void)popup {
    // Stop any existing animations
    if (_animationView != nil) {
        [_animationLayer removeAllAnimations];
        [self _cleanupAndRestoreViews];
    }
    
    // Perform some initial setup - hide the window and make us not have a shadow while animating
    if ([self isVisible]) {
        [self orderOut:nil];
    }
    
    // Grab the content view and cache its contents
    _oldContentView = [[self contentView] retain];
    // We also want to restore the current first responder
    _oldFirstResponder = [self firstResponder];

    _pretendKeyForDrawing = YES;
    NSRect visibleRect = [_oldContentView visibleRect];
    NSBitmapImageRep *imageRep = [_oldContentView bitmapImageRepForCachingDisplayInRect:visibleRect];
    [_oldContentView cacheDisplayInRect:visibleRect toBitmapImageRep:imageRep];
    _pretendKeyForDrawing = NO;
    
    // Create a new content view for animating
    _animationView = [[NSView alloc] initWithFrame:visibleRect];
    [_animationView setWantsLayer:YES];
    [self setContentView:_animationView];
    
    // Temporarily enlargen the window size to accomidate the "grow" animation.
    _originalWidowFrame = self.frame;
    CGFloat xGrow = NSWidth(_originalWidowFrame)*0.5;
    CGFloat yGrow = NSHeight(_originalWidowFrame)*0.5;
    [self setFrame:NSInsetRect(_originalWidowFrame, -xGrow, -yGrow) display:NO];

    // Calculate where we want the animation layer to be based off of the offset we set above
    _originalLayerFrame = visibleRect;
    _originalLayerFrame.origin.x += xGrow;
    _originalLayerFrame.origin.y += yGrow;

    // Create a manual layer and control it's contents and position
    _animationLayer = [CALayer layer];
    _animationLayer.frame = NSRectToCGRect(_originalLayerFrame);
    _animationLayer.contents = (id)[imageRep CGImage];
    // A shadow is needed to match what the window normally has
    _animationLayer.shadowOpacity = 0.50;
    _animationLayer.shadowRadius = 4;
    // Start at 1% scale
    _animationLayer.transform = [self _transformForScale:0.01];
    
    // Get the layer into the rendering tree
    [[_animationView layer] addSublayer:_animationLayer];

    // Bring the window up and flush the contents
    [self makeKeyAndOrderFront:nil];
    [self displayIfNeeded];
    
    // Start the grow animation
    _growing = YES;
    [self _addAnimationToScale:GROW_SCALE duration:GROW_ANIMATION_DURATION];
}

@end
