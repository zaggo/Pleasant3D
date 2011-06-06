//
//  STLModel.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 12.08.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BinarySTLStructs.h"
#import "SliceTypes.h"

@class Vector3;
@interface STLModel : NSObject <NSCoding, NSCopying> {
	NSData* stlData;
	NSData* clFacetsData;
	Vector3*	cornerMinimum;
	Vector3*	cornerMaximum;
	BOOL		hasNormals;
}

@property (retain) NSData* stlData;
@property (readonly) STLFacetCL* facets;
@property (retain) Vector3*	cornerMinimum;
@property (retain) Vector3*	cornerMaximum;
@property (assign) BOOL		hasNormals;

- (id)initWithStlData:(NSData*)data;
- (STLBinaryHead*)stlHead;
- (BOOL)writeToPath:(NSString*)destinationPath;
@end
