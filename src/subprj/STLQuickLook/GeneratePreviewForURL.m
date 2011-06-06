#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "STLImportPlugin.h"
#import "STLPreviewGenerator.h"

/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file
   ----------------------------------------------------------------------------- */

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	STLImportPlugin* plugin = [[STLImportPlugin alloc] init];
	STLModel* model = [plugin readSTLModel:[NSData dataWithContentsOfURL:(NSURL*)url]];
	[plugin release];
	
	CGSize renderSize = CGSizeMake(800., 600.);
	CGContextRef cgContext = QLPreviewRequestCreateContext(preview, renderSize, YES, nil);
	if(cgContext) 
	{
		STLPreviewGenerator* previewGen = [[STLPreviewGenerator alloc] initWithSTLModel:model size:renderSize forThumbnail:NO];
		CGImageRef cgImage = [previewGen generatePreviewImage];
		if(cgImage)
		{
			CGContextDrawImage(cgContext, CGRectMake(0.,0.,renderSize.width,renderSize.height), cgImage);
			CFRelease(cgImage);
			QLPreviewRequestFlushContext(preview, cgContext);
		}
		
		//		QTMovie* previewMovie = [previewGen generatePreviewMovie];
		//		QLPreviewRequestSetDataRepresentation(preview, (CFDataRef)[previewMovie movieFormatRepresentation], kUTTypeMovie, nil);
		
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
