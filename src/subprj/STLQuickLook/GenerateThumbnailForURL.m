#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "STLImportPlugin.h"
#import "STLPreviewGenerator.h"
#import <QuartzCore/QuartzCore.h>
#import "QuartzUtils.h"

/* -----------------------------------------------------------------------------
    Generate a thumbnail for file

   This function's job is to create thumbnail for designated file as fast as possible
   ----------------------------------------------------------------------------- */

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize)
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	STLImportPlugin* plugin = [[STLImportPlugin alloc] init];
	STLModel* model = [plugin readSTLModel:[NSData dataWithContentsOfURL:(NSURL*)url]];
	[plugin release];
	
	BOOL thumbnailIcon = [[(NSDictionary*)options objectForKey:@"IconMode"] boolValue];
	CGSize renderSize;
	if(thumbnailIcon)
		renderSize = CGSizeMake(400., 512.);
	else
		renderSize = CGSizeMake(800., 600.);
	CGContextRef cgContext = QLThumbnailRequestCreateContext(thumbnail, renderSize, YES, nil);
	if(cgContext) 
	{	
		STLPreviewGenerator* previewGen = [[STLPreviewGenerator alloc] initWithSTLModel:model size:renderSize forThumbnail:thumbnailIcon];
		
		CGImageRef cgImage = [previewGen generatePreviewImage];
		if(cgImage)
		{
			if(thumbnailIcon)
			{
				CIContext* ciContext = [CIContext contextWithCGContext:cgContext options: nil];
				
				size_t bitsPerComponent = CGImageGetBitsPerComponent(cgImage);
				float maxComponent = (float)((int)1 << bitsPerComponent)-1.0;
				float redF = rintf(0*maxComponent);
				float greenF = rintf(1*maxComponent);
				float blueF = rintf(0*maxComponent);
				const float maskingMinMax[] = { redF, redF, greenF, greenF, blueF, blueF }; 
				CGImageRef maskedImage = CGImageCreateWithMaskingColors(cgImage, (CGFloat*)maskingMinMax);
				CIImage* ciImage = [CIImage imageWithCGImage:maskedImage];
				CFRelease(maskedImage);
				
				NSAffineTransform *affineTransform = [NSAffineTransform transform];
				[affineTransform scaleBy:.75];
				[affineTransform translateXBy:60. yBy:renderSize.height-360.];
				CIFilter* positioningFilter = [CIFilter filterWithName:@"CIAffineTransform"];
				[positioningFilter setDefaults];
				[positioningFilter setValue:ciImage forKey:@"inputImage"];
				[positioningFilter setValue:affineTransform forKey:@"inputTransform"];
				
//				CIImage* composit = [positioningFilter valueForKey: @"outputImage"];
				CGImageRef tagRef = GetCGImageNamedFromBundleWithClass(@"stlTagImage.png", [STLPreviewGenerator class]);
				if(tagRef==nil)
				{
					NSLog(@"Cannot read stlTagImage");
					[previewGen release];
					CFRelease(cgContext);
					[pool drain];
					return noErr;
				}
				CIImage* ciTag = [CIImage imageWithCGImage:tagRef];
				
				NSAffineTransform *tagTransform = [NSAffineTransform transform];
				[tagTransform translateXBy:160.5 yBy:40.5];
				CIFilter* tagPositionFilter = [CIFilter filterWithName:@"CIAffineTransform"];
				[tagPositionFilter setDefaults];
				[tagPositionFilter setValue:ciTag forKey:@"inputImage"];
				[tagPositionFilter setValue:tagTransform forKey:@"inputTransform"];
				
				CIFilter* taggingFilter = [CIFilter filterWithName:@"CISourceOverCompositing"];
				[taggingFilter setDefaults];
				[taggingFilter setValue:[tagPositionFilter valueForKey: @"outputImage"] forKey:@"inputImage"];
				[taggingFilter setValue:[positioningFilter valueForKey: @"outputImage"] forKey:@"inputBackgroundImage"];
				
				CIImage* composit = [taggingFilter valueForKey: @"outputImage"];
				[ciContext  drawImage:composit atPoint:CGPointMake(-40., 0.) fromRect:CGRectMake(0., 0., renderSize.width, renderSize.height)];
				CFRelease(tagRef);
		}
			else
			{
				CGContextDrawImage(cgContext, CGRectMake(0.,0.,renderSize.width,renderSize.height), cgImage);
			}
			
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
