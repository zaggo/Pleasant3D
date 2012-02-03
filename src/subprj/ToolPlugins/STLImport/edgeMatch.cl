//
//  edgeMatch.cl
//  STLImport
//
//  Created by Eberhard Rensch on 12.01.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
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

#include "clEdgeIndexTypes.h"
__kernel void edgeMatch(__constant FacetEdge* inFacetEdges, __global EdgeIndex* inOutIndexedEdges, __constant uint numberOfEdges)
{
	const uint idx = get_global_id(0);
		
	if(inOutIndexedEdges[idx].touchesFacetIndex == (uint)-1) // if not handled already
	{
		// TODO: There probably is a faster way to do the following search!
		uint edgeIndex;			
		for(edgeIndex=0;edgeIndex<numberOfEdges;edgeIndex++)
		{
			if(all(isequal(inOutIndexedEdges[idx].roundedP, inFacetEdges[edgeIndex].roundedP)))
				break;
		}
		
		
		while(edgeIndex<numberOfEdges && all(isequal(inOutIndexedEdges[idx].roundedP, inFacetEdges[edgeIndex].roundedP)))
		{
			if(inFacetEdges[edgeIndex].facetIndex!=inOutIndexedEdges[idx].facetIndex && 
				all(isequal(inOutIndexedEdges[idx].roundedQ, inFacetEdges[edgeIndex].roundedQ)))
			{
				inOutIndexedEdges[idx].touchesFacetIndex = inFacetEdges[edgeIndex].facetIndex;
				inOutIndexedEdges[idx].touchesEdgeIndex = inFacetEdges[edgeIndex].edgeIndex;
				
				uint otherIndex = inFacetEdges[edgeIndex].facetIndex*3+inFacetEdges[edgeIndex].edgeIndex;
				inOutIndexedEdges[otherIndex].touchesFacetIndex = inOutIndexedEdges[idx].facetIndex;
				inOutIndexedEdges[otherIndex].touchesEdgeIndex = inOutIndexedEdges[idx].edgeIndex;
				break;
			}
			edgeIndex++;
		}
	}
}

