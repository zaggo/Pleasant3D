//
//  NSView+SearchSubview.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 01.08.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//

#import "NSView+SearchSubview.h"

@implementation NSView (SearchSubview)

- (NSView*)subviewOfClass:(Class)classOfSubview;
{
	if([self isKindOfClass:classOfSubview])
		return self;
	
	for(NSView* subview in [self subviews])
	{
		NSView* view = [subview subviewOfClass:classOfSubview];
		if(view)
			return view;
	}
	return nil;
}

@end
