/*
 *  clSliceTypes.h
 *  Slice
 *
 *  Created by Eberhard Rensch on 17.01.10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */
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
