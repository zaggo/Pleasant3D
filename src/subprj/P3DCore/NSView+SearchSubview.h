//
//  NSView+SearchSubview.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 01.08.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSView (SearchSubview)

- (NSView*)subviewOfClass:(Class)classOfSubview;

@end
