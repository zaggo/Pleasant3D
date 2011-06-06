//
//  QuartzUtils.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 02.08.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//

#import <Quartz/Quartz.h>

CGImageRef CreateCGImageFromFile( NSString *path );
CGImageRef GetCGImageNamed( NSString *name);
CGImageRef GetCGImageNamedFromBundleWithClass( NSString *name, Class bundleClass);
