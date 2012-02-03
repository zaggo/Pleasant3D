/*
 *  EdgeIndexTypes.h
 *  Pleasant3D
 *
 *  Created by Eberhard Rensch on 12.01.10.
 *  Copyright 2010 Pleasant Software. All rights reserved.
 *
 */
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

