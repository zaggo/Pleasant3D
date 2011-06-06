/*
 *  clSliceTypes.h
 *  Slice
 *
 *  Created by Eberhard Rensch on 17.01.10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

// Don't import anything in this file, since it's processed for use in OpenCL!

typedef struct tagSTLFacetCL {
	cl_float4 p0;
	cl_float4 p1;
	cl_float4 p2;
	cl_float4 normal;
}	STLFacetCL;

typedef struct tagSlicedEdge {
	cl_float2 startPoint;
	cl_float2 endPoint;
	cl_float2 normal;	
	
	cl_uint	parentFacet;
	cl_uint	parentStartEdge;
	cl_uint	parentEndEdge;
	cl_uint connectsTo;
	cl_uint layerIndex;
	cl_uint optimizedIndex;
} SlicedEdge;

typedef struct tagSlicedEdgeLayerReference {
	cl_uint layerIndex;
	cl_uint slicedEdgeIndex;
} SlicedEdgeLayerReference;

typedef struct tagLineOffset {
	cl_uint minLayer;
	cl_uint maxLayer;
	cl_uint offset;
	cl_uint padding;
} LineOffset;

typedef struct tagInsetLoopCorner {
	cl_float2 point;
	cl_float2 normal;
	
//	cl_uint   sort;
//	// Alignment fix
//	cl_uint padding;
} InsetLoopCorner;
