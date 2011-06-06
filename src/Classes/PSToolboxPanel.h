//
//  PSToolboxPanel.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 29.12.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PSToolboxPanel : NSPanel {
	BOOL animated;
}

- (void)fadeIn;
@end
