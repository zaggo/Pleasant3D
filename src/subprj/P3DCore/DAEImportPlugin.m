//
//  DAEImportPlugin.m
//  P3DCore
//
//  Created by Eberhard Rensch on 30.03.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
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

#import "DAEImportPlugin.h"
#import "STLModel.h"


@implementation DAEImportPlugin

- (STLModel*)readDAEModel:(NSData*)daeData error:(NSError**)error
{
	//	NSLog(@"Sizeof float: %d CGFloat: %d GLfloat: %d NSInteger: %d long: %d", sizeof(float), sizeof(CGFloat), sizeof(GLfloat), sizeof(NSInteger), sizeof(long));
	
	STLModel* result = nil;
	if(daeData)
	{
		NSInteger faceCount = 0;
		NSXMLDocument* xmlDoc = [[NSXMLDocument alloc] initWithData:daeData options:0 error:error];
		for(NSXMLElement* mesh in [xmlDoc nodesForXPath:@".//mesh" error:error])
		{
			for(NSXMLElement* count in [mesh nodesForXPath:@"./triangles/@count" error:error])
			{
				faceCount += [[count stringValue] intValue];
			}
		}

		size_t bufferlen = faceCount * 50 + sizeof(STLBinaryHead);
		char* buffer = malloc(bufferlen);
		NSData* stlData = [[NSData alloc] initWithBytesNoCopy:buffer length:bufferlen freeWhenDone:YES];
		STLBinaryHead* stlHead = (STLBinaryHead*)buffer;
		stlHead->numberOfFacets = faceCount;

		STLFacet* facet = firstFacet(stlHead);
		for(NSXMLElement* mesh in [xmlDoc nodesForXPath:@".//mesh" error:error])
		{	
			NSString* positionSourceId = [[[mesh nodesForXPath:@"./vertices/input[@semantic='POSITION']/@source" error:error] lastObject] stringValue];
			NSXMLElement* positionSource = [[mesh nodesForXPath:[NSString stringWithFormat:@"./source[ends-with('%@',@id)]", positionSourceId]  error:error] lastObject];
			NSArray* positionCoordinates = [[[[positionSource nodesForXPath:@"./float_array"  error:error] lastObject] stringValue] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			NSInteger posCoordTriangleCount = positionCoordinates.count;
			
			NSString* normalSourceId = [[[mesh nodesForXPath:@"./vertices/input[@semantic='NORMAL']/@source" error:error] lastObject] stringValue];
			NSXMLElement* normalSource = [[mesh nodesForXPath:[NSString stringWithFormat:@"./source[ends-with('%@',@id)]", normalSourceId]  error:error] lastObject];
			NSArray* normalCoordinates = [[[[normalSource nodesForXPath:@"./float_array"  error:error] lastObject] stringValue] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			
			for(NSXMLElement* triangles in [mesh nodesForXPath:@"./triangles" error:error])
			{
				NSXMLElement* countAttrib = [[triangles nodesForXPath:@"./@count" error:error] objectAtIndex:0];
				NSString* countString = [countAttrib stringValue];
				NSInteger triangleCount = [countString integerValue];
				
				NSArray* triangleInputs = [triangles nodesForXPath:@"./input" error:error];
				NSArray* vertexInput = [triangles nodesForXPath:@"./input[@semantic='VERTEX']/@offset" error:error];
				if(vertexInput.count==1)
				{
					NSInteger vertexOffset = [[[vertexInput objectAtIndex:0] stringValue] intValue];
				
					NSArray* triangleCornerIndexes = [[[[triangles nodesForXPath:@"./p" error:error] objectAtIndex:0] stringValue] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			
					if(triangleCornerIndexes.count/triangleInputs.count==triangleCount*3)
					{
						NSInteger cornerIndex=0;
						for(NSInteger triangleNumber=0; triangleNumber<triangleCount; triangleNumber++)
						{
							facet->normal.x = 0.f;
							facet->normal.y = 0.f;
							facet->normal.z = 0.f;
							for(NSInteger cornerPoint = 0; cornerPoint<3; cornerPoint++)
							{
								NSInteger tIndex=3*[[triangleCornerIndexes objectAtIndex:cornerIndex+vertexOffset] intValue];
								cornerIndex+=triangleInputs.count;
								
								if(tIndex>=0 && tIndex<posCoordTriangleCount)
								{
									facet->p[cornerPoint].x = [[positionCoordinates objectAtIndex:tIndex] floatValue];
									facet->p[cornerPoint].y = [[positionCoordinates objectAtIndex:tIndex+1] floatValue];
									facet->p[cornerPoint].z = [[positionCoordinates objectAtIndex:tIndex+2] floatValue];
									
									facet->normal.x += [[normalCoordinates objectAtIndex:tIndex] floatValue];
									facet->normal.y += [[normalCoordinates objectAtIndex:tIndex+1] floatValue];
									facet->normal.z += [[normalCoordinates objectAtIndex:tIndex+2] floatValue];
								}
								else
								{
									stlData = nil;
									break;
								}
							}
							if(stlData == nil)
								break;
								
							facet->normal.x /= 3.f;
							facet->normal.y /= 3.f;
							facet->normal.z /= 3.f;
							facet = nextFacet(facet);
						}
					}
				}
				if(stlData == nil)
					break;
			}
			if(stlData == nil)
				break;
		}
		if(stlData)
		{
			result = [[STLModel alloc] initWithStlData:stlData]; // Calculates min/max corner
		}
	}
	return result;
}
		
@end
