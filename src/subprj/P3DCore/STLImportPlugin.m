//
//  STLImportPlugin.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 23.07.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//

#import "STLImportPlugin.h"
#import "STLModel.h"

@implementation STLImportPlugin

- (NSData*)convertASCIISTL:(NSString*)stlText
{
	NSScanner* scanner = [NSScanner scannerWithString:stlText];

	NSInteger numberOfFaces = 0;	
	[scanner scanUpToString:@"normal" intoString:nil];
	while([scanner scanString:@"normal" intoString:nil])
	{
		numberOfFaces++;
		[scanner scanUpToString:@"normal" intoString:nil];
	}
	
	size_t bufferlen = numberOfFaces * 50 + sizeof(STLBinaryHead);
	
	char* buffer = malloc(bufferlen);
	NSData* converted = [[NSData alloc] initWithBytesNoCopy:buffer length:bufferlen freeWhenDone:YES];
	
	STLBinaryHead* stlHead = (STLBinaryHead*)buffer;
	stlHead->numberOfFacets = numberOfFaces;
	
	STLFacet* facet = firstFacet(stlHead);
	
	[scanner setScanLocation:0];
	[scanner scanUpToString:@"normal" intoString:nil];
	while([scanner scanString:@"normal" intoString:nil])
	{
		if([scanner scanFloat:(float*)&(facet->normal.x)] &&
		   [scanner scanFloat:(float*)&(facet->normal.y)] &&
		   [scanner scanFloat:(float*)&(facet->normal.z)] )
		{
			for(NSInteger pIndex = 0; pIndex<3; pIndex++)
			{
				[scanner scanUpToString:@"vertex" intoString:nil];
				if([scanner scanString:@"vertex" intoString:nil])
				{
					[scanner scanFloat:(float*)&(facet->p[pIndex].x)];
					[scanner scanFloat:(float*)&(facet->p[pIndex].y)];
					[scanner scanFloat:(float*)&(facet->p[pIndex].z)];
				}
			}
		}
		[scanner scanUpToString:@"normal" intoString:nil];
		facet = nextFacet(facet);
	}
	return [converted autorelease];
}

- (STLModel*)readSTLModel:(NSData*)stlData
{
//	NSLog(@"Sizeof float: %d CGFloat: %d GLfloat: %d NSInteger: %d long: %d", sizeof(float), sizeof(CGFloat), sizeof(GLfloat), sizeof(NSInteger), sizeof(long));
	
	STLModel* result = nil;
	if(stlData)
	{		
		// Check for a Text-STL file
		NSInteger numberOfVertexStrings = 0;
		NSInteger dataLength = stlData.length;
		NSData* vertexKeyWord = [@"vertex" dataUsingEncoding:NSUTF8StringEncoding];
		NSRange searchRange = NSMakeRange(0, dataLength);

		NSRange foundKeyword = [stlData rangeOfData:vertexKeyWord options:0 range:searchRange];
		while(foundKeyword.location != NSNotFound)
		{
			numberOfVertexStrings++;
			searchRange.location = NSMaxRange(foundKeyword);
			searchRange.length = dataLength-searchRange.location;
			foundKeyword = [stlData rangeOfData:vertexKeyWord options:0 range:searchRange];
		}		
		NSInteger requiredVertexStringsForText = MAX( 2, dataLength/8000);
		if(numberOfVertexStrings > requiredVertexStringsForText)
		{
			NSString* asciiSTL = [[NSString alloc] initWithBytesNoCopy:(char*)[stlData bytes] length:[stlData length] encoding:NSUTF8StringEncoding freeWhenDone:NO];
			stlData = [self convertASCIISTL:asciiSTL];
			[asciiSTL release];
		}
		
		if(stlData)
		{
			result = [[[STLModel alloc] initWithStlData:stlData] autorelease]; // Calculates min/max corner
		}
	}
	
	return result;
}

@end
