//
//  STLModel.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 12.08.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//

#import "STLModel.h"
#import "Vector3.h"
#import "PSLog.h"

@implementation STLModel
@synthesize cornerMaximum, cornerMinimum, stlData, hasNormals;
@dynamic facets;

- (id)initWithStlData:(NSData*)data
{
	self = [super init];
	if(self)
	{
		stlData = [[NSData alloc] initWithBytes:[data bytes] length:[data length]];
		
		// Calculate Min/Max-Corner

		STLBinaryHead* stl = (STLBinaryHead*)[stlData bytes];
		STLFacet* facet = firstFacet(stl);
		cornerMinimum = [[Vector3 alloc] initVectorWithX:facet->p[0].x Y:facet->p[0].y Z:facet->p[0].z];
		cornerMaximum = [cornerMinimum copy];
		hasNormals = NO;
		for(UInt32 i = 0; i<stl->numberOfFacets; i++)
		{
			for(NSInteger pIndex = 0; pIndex<3; pIndex++)
			{
				[cornerMaximum maximizeWithX:facet->p[pIndex].x Y:facet->p[pIndex].y Z:facet->p[pIndex].z];
				[cornerMinimum minimizeWithX:facet->p[pIndex].x Y:facet->p[pIndex].y Z:facet->p[pIndex].z];
				if(!hasNormals && (facet->normal.x!=0. || facet->normal.y!=0. || facet->normal.z!=0.))
					hasNormals = YES;
			}
			facet = nextFacet(facet);
		}
	}

	return self;
}

- (id)initWithStlData:(NSData*)data cornerMinimum:(Vector3*)cmin cornerMaximum:(Vector3*)cmax hasNormals:(BOOL)normals
{
	self = [super init];
	if(self)
	{
		stlData = [[NSData alloc] initWithBytes:[data bytes] length:[data length]];
		cornerMinimum = [cmin copy];
		cornerMaximum = [cmax copy];
		hasNormals = normals;
	}
	return self;
}

- (id)initWithCoder:(NSCoder*)decoder
{
	self = [super init];
	stlData = [decoder decodeObjectForKey:@"rawSTLData"];
	cornerMaximum = [decoder decodeObjectForKey:@"cornerMaximum"];
	cornerMinimum = [decoder decodeObjectForKey:@"cornerMinimum"];
	hasNormals = [decoder decodeBoolForKey:@"hasNormals"];
	return self;
}

- (void)encodeWithCoder:(NSCoder*)encoder
{
	[encoder encodeObject:stlData forKey:@"rawSTLData"];
	[encoder encodeObject:cornerMaximum forKey:@"cornerMaximum"];
	[encoder encodeObject:cornerMinimum forKey:@"cornerMinimum"];
	[encoder encodeBool:hasNormals forKey:@"hasNormals"];
}

- (void) dealloc
{
	[clFacetsData release];
	[stlData release];
	[cornerMaximum release];
	[cornerMinimum release];
	
	[super dealloc];
}

- (STLModel*)copyWithZone:(NSZone *)zone
{
	return [[STLModel alloc] initWithStlData:stlData cornerMinimum:cornerMinimum cornerMaximum:cornerMaximum hasNormals:hasNormals];
}

- (STLBinaryHead*)stlHead
{
	return (STLBinaryHead*)[stlData bytes];
}

- (BOOL)writeToPath:(NSString*)destinationPath;
{
	return [stlData writeToFile:destinationPath atomically:YES];
}

- (STLFacetCL*)facets
{
    @synchronized(self) {
        if(clFacetsData==nil)
        {
            STLBinaryHead* stl = [self stlHead];
            clFacetsData = [[NSData alloc] initWithBytes:calloc(stl->numberOfFacets, sizeof(STLFacetCL)) length:stl->numberOfFacets];
            STLFacetCL* facets = (STLFacetCL*)clFacetsData.bytes;
            if(facets==nil)
                PSErrorLog(@"Out of memory!");
            
            STLFacet* facet = firstFacet(stl);		
            for(NSUInteger i = 0; i<stl->numberOfFacets; i++)
            {			
                facets[i].p0.s[0]=facet->p[0].x;
                facets[i].p0.s[1]=facet->p[0].y;
                facets[i].p0.s[2]=facet->p[0].z;
                
                facets[i].p1.s[0]=facet->p[1].x;
                facets[i].p1.s[1]=facet->p[1].y;
                facets[i].p1.s[2]=facet->p[1].z;
                
                facets[i].p2.s[0]=facet->p[2].x;
                facets[i].p2.s[1]=facet->p[2].y;
                facets[i].p2.s[2]=facet->p[2].z;
                
                facets[i].normal.s[0]=facet->normal.x;
                facets[i].normal.s[1]=facet->normal.y;
                facets[i].normal.s[2]=facet->normal.z;
                
                facet = nextFacet(facet);
            }
        }
    }
	return (STLFacetCL*)clFacetsData.bytes;
}
@end
