/*
 *  EdgeIndexTypes.h
 *  Pleasant3D
 *
 *  Created by Eberhard Rensch on 12.01.10.
 *  Copyright 2010 Pleasant Software. All rights reserved.
 *
 */

// Don't import anything in this file, since it's processed for use in OpenCL!
typedef struct tagFacetEdge {
	cl_uint facetIndex;
	cl_uint edgeIndex;

	// Alignment fix
	cl_uint padding[2];
	
	cl_int4 roundedP;	
	cl_int4 roundedQ;
} FacetEdge;

typedef struct tagEdgeIndex {
	cl_uint facetIndex;
	cl_uint edgeIndex;
	cl_uint touchesFacetIndex;
	cl_uint touchesEdgeIndex;

	cl_int4 roundedP;
	cl_int4 roundedQ;	
} EdgeIndex;

