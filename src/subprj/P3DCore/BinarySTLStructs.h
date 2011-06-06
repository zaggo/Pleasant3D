//
//  STLBinaryStructs.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 12.08.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//

#pragma pack(2)
typedef struct tagSTLVertex {
	GLfloat	x;
	GLfloat	y;
	GLfloat	z;
} STLVertex;

typedef struct tagSTLFacet {
	STLVertex normal;
	STLVertex p[3];		
	UInt16 attrib;
}	STLFacet;

typedef struct tagPaddedSTLFacet {
	STLVertex normal;
	STLVertex p[3];		
	UInt16 attrib;
}	PaddedSTLFacet;

typedef struct tagSTLBinaryHead {
	char header[80];
	UInt32	numberOfFacets;
}	STLBinaryHead;

#define firstFacet(x)	(STLFacet*)((const char*)x + 84)
#define nextFacet(x)	(STLFacet*)((const char*)x + 50)

#pragma options align=reset
