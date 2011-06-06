//
//  QuartzUtils.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 02.08.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//

#import "QuartzUtils.h"


CGImageRef CreateCGImageFromFile( NSString *path )
{
    CGImageRef image = NULL;
    CFURLRef url = (CFURLRef) [NSURL fileURLWithPath: path];
    CGImageSourceRef src = CGImageSourceCreateWithURL(url, NULL);
    if( src ) {
        image = CGImageSourceCreateImageAtIndex(src, 0, NULL);
        CFRelease(src);
        if(!image) NSLog(@"Warning: CGImageSourceCreateImageAtIndex failed on file %@ (ptr size=%d)", path, (int)sizeof(void*));
    }
    return image;
}


CGImageRef GetCGImageNamed( NSString *name)
{
	return GetCGImageNamedFromBundleWithClass(name, nil);
}

CGImageRef GetCGImageNamedFromBundleWithClass( NSString *name, Class bundleClass)
{
    // For efficiency, loaded images are cached in a dictionary by name.
    static NSMutableDictionary *sMap=nil;
    if( ! sMap )
        sMap = [[NSMutableDictionary alloc] init];
    
    CGImageRef image = (CGImageRef) [sMap objectForKey: name];
    if( ! image ) {
        // Hasn't been cached yet, so load it:
        NSString *path;
        if( [name hasPrefix: @"/"] )
            path = name;
        else {
			if(bundleClass==nil)
				path = [[NSBundle mainBundle] pathForResource:name ofType: nil];
			else
				path = [[NSBundle bundleForClass:bundleClass] pathForResource:name ofType:nil];
            NSCAssert1(path,@"Couldn't find bundle image resource '%@'",name);
        }
        image = CreateCGImageFromFile(path);
        NSCAssert1(image,@"Failed to load image from %@",path);
        [sMap setObject: (id)image forKey: name];
    }
    return image;
}
