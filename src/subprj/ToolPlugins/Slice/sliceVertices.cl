
//
//  sliceVertices.cl
//  Slice
//
//  Created by Eberhard Rensch on 12.08.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
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

#include "clSliceTypes.h"
#include "clEdgeIndexTypes.h"

#define VERBOSE 1

const size_t kSlicedEdgeSize=sizeof(SlicedEdge);
const size_t kSTLFacetSize=sizeof(STLFacetCL);
const size_t kLineOffsetSize=sizeof(LineOffset);

// FIXME: Why is M_PI not defined when compiling for GPU? 
//#define M_PI 3.1415926

const float k2Pi = (2.f*(float)M_PI);

// This function calculates the needed memory for slicing a specific facet
__kernel void calcLineOffsets(__global LineOffset *lineOffsets, __global const STLFacetCL *facets, const float zStart, const float layerHeight)
{		
	const size_t facetIndex = get_global_id(0);

#if VERBOSE
	printf("calcLineOffsets #%d\n", facetIndex);
#endif		
	__global const STLFacetCL* facet = facets+facetIndex*kSTLFacetSize;

	float minZ = facet->p0.z;
	float maxZ = facet->p0.z;	
	minZ=min(minZ, facet->p1.z);
	maxZ=max(maxZ, facet->p1.z);
	minZ=min(minZ, facet->p2.z);
	maxZ=max(maxZ, facet->p2.z);
	
	// Calculate the min layer and the max layer affecting by this facet
	lineOffsets[facetIndex].minLayer = (uint)((minZ-zStart)/layerHeight);
	lineOffsets[facetIndex].maxLayer = max((uint)((maxZ-zStart)/layerHeight), lineOffsets[facetIndex].minLayer)+1;
	
	// Calculate the number of layers affecting this layer
	// This number of sliced lines needs to be reserved for this facet
	// Slice the facet. Only try slicing between the min/max layers calculated in calcLineOffsets
	
	lineOffsets[facetIndex].offset = 0;
	for(uint layerIndex = lineOffsets[facetIndex].minLayer; layerIndex<lineOffsets[facetIndex].maxLayer; layerIndex++)
	{
		float facetPX, facetPY, facetPZ;
		float facetQX, facetQY, facetQZ;
		
		float z=zStart+(float)layerIndex*layerHeight+layerHeight/2.; // The height for this slice
		uint edge1;
		for(edge1 = 0; edge1<3; edge1++)
		{
			switch(edge1)
			{
				case 0: facetPX=facet->p0.x; facetPY=facet->p0.y; facetPZ=facet->p0.z;
						facetQX=facet->p1.x; facetQY=facet->p1.y; facetQZ=facet->p1.z;
						break;
				case 1: facetPX=facet->p0.x; facetPY=facet->p0.y; facetPZ=facet->p0.z;
						facetQX=facet->p2.x; facetQY=facet->p2.y; facetQZ=facet->p2.z;
						break;
				case 2: facetPX=facet->p1.x; facetPY=facet->p1.y; facetPZ=facet->p1.z;
						facetQX=facet->p2.x; facetQY=facet->p2.y; facetQZ=facet->p2.z;
						break;
			}
			
			if((facetPZ<=z && facetQZ>z) || (facetPZ>z && facetQZ<=z)) // This edge is cut by the layer
				break;
		}

		if(edge1<2) // There's still a chance for a second edge!
		{
			for(uint edge2 = edge1+1; edge2<3; edge2++)
			{
				switch(edge2)
				{
					case 0: facetPX=facet->p0.x; facetPY=facet->p0.y; facetPZ=facet->p0.z;
							facetQX=facet->p1.x; facetQY=facet->p1.y; facetQZ=facet->p1.z;
							break;
					case 1: facetPX=facet->p0.x; facetPY=facet->p0.y; facetPZ=facet->p0.z;
							facetQX=facet->p2.x; facetQY=facet->p2.y; facetQZ=facet->p2.z;
							break;
					case 2: facetPX=facet->p1.x; facetPY=facet->p1.y; facetPZ=facet->p1.z;
							facetQX=facet->p2.x; facetQY=facet->p2.y; facetQZ=facet->p2.z;
							break;
				}
				if((facetPZ<=z && facetQZ>z) || (facetPZ>z && facetQZ<=z)) // This edge is cut by the layer, we have a winner!
				{
					lineOffsets[facetIndex].offset++;
					break;
				}
			}
		}
	}
}

__kernel void sliceTriangles(__global SlicedEdge* slicedEdges, __global SlicedEdgeLayerReference* slicedEdgeLayerReference, __global const STLFacetCL *facets, __global const LineOffset* lineOffsets, __constant const float zStart, __constant const float layerHeight)
{
	const size_t facetIndex = get_global_id(0);
	__global const STLFacetCL* facet = facets+facetIndex*kSTLFacetSize;
	
	if(lineOffsets[facetIndex].offset != (unsigned int)-1) // else there's nothing to slice!
	{
		// the start index for the sliced lines in the slicedEdges array for this line is calculated in the offset field
		unsigned int slicedEdgeIndex = lineOffsets[facetIndex].offset;

		// Slice the facet. Only try slicing between the min/max layers calculated in calcLineOffsets
		for(unsigned int layerIndex = lineOffsets[facetIndex].minLayer; layerIndex<lineOffsets[facetIndex].maxLayer; layerIndex++)
		{
			float facetPX, facetPY, facetPZ;
			float facetQX, facetQY, facetQZ;
			float z=zStart+(float)layerIndex*layerHeight+layerHeight/2.; // The height for this slice
			
			uint	edge1, 
					edge2=3;
			float2 edgeStart;
			
			// Look for an edge which is cut by the current z layer line
			for(edge1 = 0; edge1<3; edge1++)
			{
				switch(edge1)
				{
					case 0: facetPX=facet->p0.x; facetPY=facet->p0.y; facetPZ=facet->p0.z;
							facetQX=facet->p1.x; facetQY=facet->p1.y; facetQZ=facet->p1.z;
							break;
					case 1: facetPX=facet->p0.x; facetPY=facet->p0.y; facetPZ=facet->p0.z;
							facetQX=facet->p2.x; facetQY=facet->p2.y; facetQZ=facet->p2.z;
							break;
					case 2: facetPX=facet->p1.x; facetPY=facet->p1.y; facetPZ=facet->p1.z;
							facetQX=facet->p2.x; facetQY=facet->p2.y; facetQZ=facet->p2.z;
							break;
				}
				
				if((facetPZ<=z && facetQZ>z) || (facetPZ>z && facetQZ<=z)) // This edge is cut by the layer
				{
					float2 p = (float2)(facetPX, facetPY);
					float2 q = (float2)(facetQX, facetQY);
					float pZz = z-facetPZ;
					float faktor = pZz/(facetQZ-facetPZ);
					
					edgeStart=p+(q-p)*faktor;
					break;
				}
			}
			
			if(edge1<2) // There's still a chance for a second edge!
			{
				// Look for the second edge edge which is cut by the current z layer line
				for(edge2 = edge1+1; edge2<3; edge2++)
				{
					switch(edge2)
					{
						case 0: facetPX=facet->p0.x; facetPY=facet->p0.y; facetPZ=facet->p0.z;
								facetQX=facet->p1.x; facetQY=facet->p1.y; facetQZ=facet->p1.z;
								break;
						case 1: facetPX=facet->p0.x; facetPY=facet->p0.y; facetPZ=facet->p0.z;
								facetQX=facet->p2.x; facetQY=facet->p2.y; facetQZ=facet->p2.z;
								break;
						case 2: facetPX=facet->p1.x; facetPY=facet->p1.y; facetPZ=facet->p1.z;
								facetQX=facet->p2.x; facetQY=facet->p2.y; facetQZ=facet->p2.z;
								break;
					}
					if((facetPZ<=z && facetQZ>z) || (facetPZ>z && facetQZ<=z)) // This edge is cut by the layer
					{
						float2 p = (float2)(facetPX, facetPY);
						float2 q = (float2)(facetQX, facetQY);
						float pZz = z-facetPZ;
						float faktor = pZz/(facetQZ-facetPZ);
						
						// Payload
						slicedEdges[slicedEdgeIndex].endPoint = p+(q-p)*faktor;
						slicedEdges[slicedEdgeIndex].startPoint = edgeStart;

						// Meta-Data
						slicedEdges[slicedEdgeIndex].parentFacet = facetIndex;				
						slicedEdges[slicedEdgeIndex].parentStartEdge = edge1;				
						slicedEdges[slicedEdgeIndex].parentEndEdge = edge2;	
						slicedEdges[slicedEdgeIndex].normal = normalize((float2)(facet->normal.x,facet->normal.y));	
						slicedEdges[slicedEdgeIndex].connectsTo = (uint)-1;
						slicedEdges[slicedEdgeIndex].layerIndex = layerIndex; // This also validates the edge
						slicedEdges[slicedEdgeIndex].optimizedIndex = (uint)-1;

						slicedEdgeLayerReference[slicedEdgeIndex].layerIndex = layerIndex;
						slicedEdgeLayerReference[slicedEdgeIndex].slicedEdgeIndex = slicedEdgeIndex;
						slicedEdgeIndex++;
						break;						
					}
				}
			}
		}
	}
}

// The optimization needs 2 steps (2 separate kernels). Otherwise we might run into problems with parallel processing
__kernel void optimizeCornerPoints(__global uint* outOptimizedConnections, __global SlicedEdge *inSlicedEdges)
{
	const size_t edgeIdex = get_global_id(0);
	SlicedEdge thisEdge = inSlicedEdges[edgeIdex];
	outOptimizedConnections[edgeIdex]=(uint)-1;
	if(thisEdge.connectsTo!=(uint)-1)
	{
		SlicedEdge nextEdge= inSlicedEdges[thisEdge.connectsTo];
		if(nextEdge.connectsTo!=(uint)-1)
		{
			float m1 = atan2(thisEdge.endPoint.y-thisEdge.startPoint.y, thisEdge.endPoint.x-thisEdge.startPoint.x);
			float m2 = atan2(nextEdge.endPoint.y-nextEdge.startPoint.y, nextEdge.endPoint.x-nextEdge.startPoint.x);
			float diff = fabs(m1-m2);
			int candidate = (diff<FLT_EPSILON);
			if(candidate) // Same Slope -> The next edge is unnecessary
			{
				outOptimizedConnections[edgeIdex]=nextEdge.connectsTo;
				//printf("Kandidat: %d\n", edgeIdex);
			}
		}
	}
}

__kernel void optimizeConnections(__global uint* outOptimizedConnections, __global SlicedEdge *inOutSlicedEdges)
{
	const size_t edgeIdex = get_global_id(0);
//	printf("edgeIndex=%d, inOutSlicedEdges[edgeIdex].connectsTo=%d outOptimizedConnections[edgeIdex]=%d\n", edgeIdex, inOutSlicedEdges[edgeIdex].connectsTo, outOptimizedConnections[edgeIdex]);
//	__global SlicedEdge* thisEdge = &inOutSlicedEdges[edgeIdex];
//	if(outOptimizedConnections[edgeIdex]!=(uint)-1 && thisEdge->connectsTo != outOptimizedConnections[edgeIdex])
//	{
//		if(thisEdge->connectsTo!=(uint)-1)
//		{
//			__global SlicedEdge* nextEdge= &inOutSlicedEdges[thisEdge->connectsTo];
//			nextEdge->connectsTo = (uint)-1;
//			thisEdge->endPoint=nextEdge->endPoint;
//		}
//		thisEdge->connectsTo = outOptimizedConnections[edgeIdex];
//	}
}

__kernel void insetLoop(__global InsetLoopCorner* outInsetLoopCorners, __global const SlicedEdge *inSlicedEdges, __constant const float inset)
{
	const size_t edgeIdex = get_global_id(0);
//	printf("sizeof(InsetLoopCorner)=%d, sizeof(SlicedEdge)=%d\n", sizeof(InsetLoopCorner), sizeof(SlicedEdge));
	
	SlicedEdge thisEdge = inSlicedEdges[edgeIdex];
		
	if(thisEdge.connectsTo!=(uint)-1 && thisEdge.optimizedIndex!=(uint)-1)
	{
//		printf("Handling Edge #%d Layer %d Facet %d (%f|%f)[E%d] -> (%f|%f)[E%d] N(%f|%f) ConnectsTo:%d LayerIndex:%d OptimizedIndex:%d\n",
//		edgeIdex, thisEdge.layerIndex, thisEdge.parentFacet, thisEdge.startPoint.x,thisEdge.startPoint.y, thisEdge.parentStartEdge, thisEdge.endPoint.x, thisEdge.endPoint.y, thisEdge.parentEndEdge, thisEdge.normal.x, thisEdge.normal.y, thisEdge.connectsTo, thisEdge.optimizedIndex);
		SlicedEdge nextEdge= inSlicedEdges[thisEdge.connectsTo];

//		float2 g1v = thisEdge.normal*inset;
//		float2 g1p1 = thisEdge.startPoint-g1v;
//		float2 g1p2 = thisEdge.endPoint-g1v;
//				
//		float2 g2v = nextEdge.normal*inset;
//		float2 g2p1 = nextEdge.startPoint-g2v;
//		float2 g2p2 = nextEdge.endPoint-g2v;
//		
//		// Slope of g1
//		float m1 = INFINITY;
//		if(g1p2.x!=g1p1.x)
//			m1 = (g1p2.y-g1p1.y)/(g1p2.x-g1p1.x);
//			
//		// Slope of g2
//		float m2 = INFINITY;
//		if(g2p2.x!=g2p1.x)
//			m2 = (g2p2.y-g2p1.y)/(g2p2.x-g2p1.x);
//
//		if(m1==m2)
//		{
//			// TODO: This point is not necessary and should be deleted from the loop!
//			outInsetLoopCorners[edgeIdex].point = g1p2;
//			outInsetLoopCorners[edgeIdex].sort = 0;
//		}
//		else if(m1==INFINITY)
//		{
//			float t2 = g2p1.y-m2*g2p1.x;
//			outInsetLoopCorners[edgeIdex].point = (float2)(g1p2.x, m2*g1p2.x+t2);
//			outInsetLoopCorners[edgeIdex].sort = 1;
//		}
//		else if(m2==INFINITY)
//		{
//			float t1 = g1p1.y-m1*g1p1.x;
//			outInsetLoopCorners[edgeIdex].point = (float2)(g2p2.x, m1*g2p2.x+t1);
//			outInsetLoopCorners[edgeIdex].sort = 2;
//		}	
//        else
//		{
//			float t1 = g1p1.y-m1*g1p1.x;
//			float t2 = g2p1.y-m2*g2p1.x;
//			
//			outInsetLoopCorners[edgeIdex].point = (float2)((t2-t1)/(m1-m2), (m1*t2-m2*t1)/(m1-m2));
//			outInsetLoopCorners[edgeIdex].sort = 3;
//		}
//		
		// Calculate the cornerpoint's normal
		
		float rad1 = atan2(thisEdge.normal.y, thisEdge.normal.x);
		float rad2 = atan2(nextEdge.normal.y, nextEdge.normal.x);
		
		float drad1=rad1-rad2;
		if(drad1<0.) drad1+=k2Pi;
		
		float drad2=rad2-rad1;
		if(drad2<0.) drad2+=k2Pi;		
		
		float prad;
		if(fabs(drad1)>fabs(drad2))
			prad = rad1+drad2/2.f;
		else
			prad = rad2+drad1/2.f;
		
		outInsetLoopCorners[thisEdge.optimizedIndex].normal = (float2)(cos(prad), sin(prad));		
		outInsetLoopCorners[thisEdge.optimizedIndex].point = thisEdge.endPoint;//-outInsetLoopCorners[edgeIdex].normal*inset;
	}	
}