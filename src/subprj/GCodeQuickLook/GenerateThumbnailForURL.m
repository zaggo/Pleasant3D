#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import "GCodePreviewGenerator.h"

/* -----------------------------------------------------------------------------
    Generate a thumbnail for file

   This function's job is to create thumbnail for designated file as fast as possible
   ----------------------------------------------------------------------------- */

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize)
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	BOOL thumbnailIcon = [[(NSDictionary*)options objectForKey:@"IconMode"] boolValue];
	CGSize renderSize;
	if(thumbnailIcon)
		renderSize = CGSizeMake(400., 512.);
	else
		renderSize = CGSizeMake(800., 600.);
	CGContextRef cgContext = QLThumbnailRequestCreateContext(thumbnail, renderSize, YES, nil);
	if(cgContext) 
	{	
		GCodePreviewGenerator* previewGen = [[GCodePreviewGenerator alloc] initWithURL:(NSURL *)url size:renderSize forThumbnail:thumbnailIcon];
		
		CGImageRef cgImage = [previewGen newPreviewImage];
		if(cgImage)
		{
            CGContextDrawImage(cgContext, CGRectMake(0.,0.,renderSize.width,renderSize.height), cgImage);
			
			QLThumbnailRequestFlushContext(thumbnail, cgContext);
			CFRelease(cgImage);
		}
		[previewGen release];
		CFRelease(cgContext);
	}
	[pool drain];
    return noErr;
}

void CancelThumbnailGeneration(void* thisInterface, QLThumbnailRequestRef thumbnail)
{
    // implement only if supported
}
