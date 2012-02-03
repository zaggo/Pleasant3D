//
//  STLImportPlugin.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 23.07.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//
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
        else
        {
//            STLFacetCL
        }
		
		if(stlData)
		{
			result = [[[STLModel alloc] initWithStlData:stlData] autorelease]; // Calculates min/max corner
		}
	}
	
	return result;
}

@end
