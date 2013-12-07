//  Created by Eberhard Rensch on 07.01.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
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
#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "STLImportPlugin.h"
#import "STLPreviewGenerator.h"
#import <QuartzCore/QuartzCore.h>
#import "QuartzUtils.h"

static CGImageRef CGImageCreateWithNSImage(NSImage *image, CGSize renderSize) {
    NSSize imageSize = [image size];
    CGFloat ratio = imageSize.width/imageSize.height;
    
    CGFloat renderWidth = renderSize.height*ratio;
    
    CGContextRef bitmapContext = CGBitmapContextCreate(NULL, renderSize.width, renderSize.height, 8, 0, [[NSColorSpace genericRGBColorSpace] CGColorSpace], kCGBitmapByteOrder32Host|kCGImageAlphaPremultipliedFirst);
    
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:bitmapContext flipped:NO]];
    [image drawInRect:NSMakeRect((renderSize.width-renderWidth)/2.f, 0.f, renderWidth, renderSize.height) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
    [NSGraphicsContext restoreGraphicsState];
    
    CGImageRef cgImage = CGBitmapContextCreateImage(bitmapContext);
    CGContextRelease(bitmapContext);
    return cgImage;
}


/* -----------------------------------------------------------------------------
    Generate a thumbnail for file

   This function's job is to create thumbnail for designated file as fast as possible
   ----------------------------------------------------------------------------- */

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize)
{
    @autoreleasepool {
	STLImportPlugin* plugin = [[STLImportPlugin alloc] init];
		STLModel* model = [plugin readSTLModel:[NSData dataWithContentsOfURL:(__bridge NSURL*)url]];
	
		BOOL thumbnailIcon = [[(__bridge NSDictionary*)options objectForKey:@"IconMode"] boolValue];
	CGSize renderSize;
	if(thumbnailIcon)
		renderSize = CGSizeMake(400., 512.);
	else
		renderSize = CGSizeMake(800., 600.);
	CGContextRef cgContext = QLThumbnailRequestCreateContext(thumbnail, renderSize, YES, nil);
	if(cgContext) 
	{	
		STLPreviewGenerator* previewGen = [[STLPreviewGenerator alloc] initWithSTLModel:model size:renderSize forThumbnail:thumbnailIcon];
		
		CGImageRef cgImage = [previewGen newPreviewImage];
        if(cgImage == NULL) {
            NSImage *theicon = [[NSWorkspace sharedWorkspace] iconForFile:[(__bridge NSURL*)url path]];
            cgImage = CGImageCreateWithNSImage(theicon, renderSize);
        }

		if(cgImage)
		{
            CGContextDrawImage(cgContext, CGRectMake(0.,0.,renderSize.width,renderSize.height), cgImage);
			CFRelease(cgImage);
		}
        QLThumbnailRequestFlushContext(thumbnail, cgContext);

		CFRelease(cgContext);
	}
    return noErr;
}
}

void CancelThumbnailGeneration(void* thisInterface, QLThumbnailRequestRef thumbnail)
{
    // implement only if supported
}
