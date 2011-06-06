#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "GCodePreviewGenerator.h"

/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file
   ----------------------------------------------------------------------------- */

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	CGSize renderSize = CGSizeMake(800., 600.);
	CGContextRef cgContext = QLPreviewRequestCreateContext(preview, renderSize, YES, nil);
	if(cgContext) 
	{
		GCodePreviewGenerator* previewGen = [[GCodePreviewGenerator alloc] initWithURL:(NSURL *)url size:renderSize forThumbnail:NO];
		CGImageRef cgImage = [previewGen generatePreviewImage];
		if(cgImage)
		{
			CGContextDrawImage(cgContext, CGRectMake(0.,0.,renderSize.width,renderSize.height), cgImage);
			CFRelease(cgImage);
			QLPreviewRequestFlushContext(preview, cgContext);
		}
				
		[previewGen release];
		CFRelease(cgContext);
	}
	[pool drain];
	return noErr;
}

void CancelPreviewGeneration(void* thisInterface, QLPreviewRequestRef preview)
{
    // implement only if supported
}
