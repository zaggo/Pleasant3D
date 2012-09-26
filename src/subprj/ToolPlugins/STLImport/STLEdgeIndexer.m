//
//  STLEdgeIndex.m
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

#import "STLEdgeIndexer.h"

#include "edgeMatchOpenCLSource.h" // Will be generated from edgeMatch.cl during build time (processOpenCL.pl Build Rule)

const size_t kFacetEdgeSize=sizeof(FacetEdge);
const size_t kEdgeIndexSize=sizeof(EdgeIndex);
const cl_float kEdgeFinderPrecision=1000.;

static int compareCl_Int4(cl_int4 i1, cl_int4 i2)
{
	if(i1.s[0] < i2.s[0])
		return -1;
	if(i1.s[0] > i2.s[0])
		return 1;
	if(i1.s[1] < i2.s[1])
		return -1;
	if(i1.s[1] > i2.s[1])
		return 1;
	if(i1.s[2] < i2.s[2])
		return -1;
	if(i1.s[2] > i2.s[2])
		return 1;
	return 0;
}

@implementation STLEdgeIndexer
- (BOOL)prepareOpelCL
{
	cl_int err;
	BOOL gpu = NO;
	err = clGetDeviceIDs(NULL, gpu ? CL_DEVICE_TYPE_GPU : CL_DEVICE_TYPE_CPU, 1, &device_id, NULL);
	if (err != CL_SUCCESS) {
		PSErrorLog(@"clGetDeviceIDs returns %d",err);
		return NO;
	}
	
	context = clCreateContext(0, 1, &device_id, NULL, NULL, &err);
	if (!context) {
		PSErrorLog(@"clCreateContext returns %d",err);
		return NO;
	}
	
	queue = clCreateCommandQueue(context, device_id, 0, &err);
	if (!queue) {
		PSErrorLog(@"clCreateCommandQueue returns %d",err);
		return NO;
	}

	program = clCreateProgramWithSource(context, edgeMatchSourceCodeCount,	edgeMatchSourceCode, NULL, &err);
	if (!program) {
		PSErrorLog(@"clCreateProgramWithSource returns %d",err);
		return NO;
	}
	
	err = clBuildProgram(program, 0, NULL, NULL, NULL, NULL);
	if (err != CL_SUCCESS)
	{
		size_t len;
		char buffer[2048];
		
		PSErrorLog(@"Error: Failed to build program executable");
		clGetProgramBuildInfo(program, device_id, CL_PROGRAM_BUILD_LOG, sizeof(buffer), buffer, &len);
		PSErrorLog(@"%s\nn***", buffer);
		return NO;
	}
	
	kernelEdgeMatch = clCreateKernel(program, "edgeMatch", &err);
    if (!kernelEdgeMatch || err != CL_SUCCESS) {
		PSErrorLog(@"clCreateKernel kernelEdgeMatch returns %d",err);
		return NO;
	}
		
	return YES;
}

- (void)cleanupOpenCL
{
	if(kernelEdgeMatch) clReleaseKernel(kernelEdgeMatch);
	if(program) clReleaseProgram(program);
	if(queue) clReleaseCommandQueue(queue);
	if(context) clReleaseContext(context);		
	context=nil; // This marks the whole OpenCL setup as "cleaned up"	
}

- (void)finalize
{
	[self cleanupOpenCL];
	[super finalize];
}

- (IndexedEdges*)createEdgeIndex:(STLModel*)stlModel
{
#ifdef __DEBUG__
	NSDate* startEdgeIndex = [NSDate date];
#endif

	NSUInteger numberOfIndexedEdges=0;
	EdgeIndex* indexedEdges=nil;
	if(context || [self prepareOpelCL])
	{
		STLBinaryHead* stl = [stlModel stlHead];

		numberOfIndexedEdges = stl->numberOfFacets*3; // 3 edges per facet
		indexedEdges = (EdgeIndex*)malloc(numberOfIndexedEdges*kEdgeIndexSize);
		
		
		cl_uint numberOfFacetEdges = (cl_uint)stl->numberOfFacets*6; // 3 edges per facet, indexed twice (back and forth)
		FacetEdge* facetEdges = (FacetEdge*)malloc(numberOfFacetEdges*kFacetEdgeSize);
		
	#if __verbose
		PSLog(@"EdgeIndex",PSPrioNormal,@"Facets:");
	#endif
		
		STLFacet* facet = firstFacet(stl);	
		for(NSInteger facetIndex = 0; facetIndex<stl->numberOfFacets; facetIndex++)
		{
			cl_int4 roundedP0;
			roundedP0.s[0] = (cl_int)roundf(facet->p[0].x*kEdgeFinderPrecision);
			roundedP0.s[1] = (cl_int)roundf(facet->p[0].y*kEdgeFinderPrecision);
			roundedP0.s[2] = (cl_int)roundf(facet->p[0].z*kEdgeFinderPrecision);
			cl_int4 roundedP1;
			roundedP1.s[0] = (cl_int)roundf(facet->p[1].x*kEdgeFinderPrecision);
			roundedP1.s[1] = (cl_int)roundf(facet->p[1].y*kEdgeFinderPrecision);
			roundedP1.s[2] = (cl_int)roundf(facet->p[1].z*kEdgeFinderPrecision);
			cl_int4 roundedP2;
			roundedP2.s[0] = (cl_int)roundf(facet->p[2].x*kEdgeFinderPrecision);
			roundedP2.s[1] = (cl_int)roundf(facet->p[2].y*kEdgeFinderPrecision);
			roundedP2.s[2] = (cl_int)roundf(facet->p[2].z*kEdgeFinderPrecision);
			
	#if __verbose
			PSLog(@"EdgeIndex",PSPrioNormal,@"#%3d (%1.2f|%1.2f|%1.2f) - (%1.2f|%1.2f|%1.2f) - (%1.2f|%1.2f|%1.2f)", facetIndex,
				  (float)roundedP0[0]/kEdgeFinderPrecision, (float)roundedP0[1]/kEdgeFinderPrecision, (float)roundedP0[2]/kEdgeFinderPrecision,
				  (float)roundedP1[0]/kEdgeFinderPrecision, (float)roundedP1[1]/kEdgeFinderPrecision, (float)roundedP1[2]/kEdgeFinderPrecision,
				  (float)roundedP2[0]/kEdgeFinderPrecision, (float)roundedP2[1]/kEdgeFinderPrecision, (float)roundedP2[2]/kEdgeFinderPrecision);
	#endif
			
			
			NSUInteger facetEdgeIndex = facetIndex*6;
			
			// Six Facet Edges: 3 Edges per Facet x2 (back and forth)
			// Edge 0: p0->p1
			facetEdges[facetEdgeIndex].facetIndex = facetIndex;
			facetEdges[facetEdgeIndex].edgeIndex = 0;
			facetEdges[facetEdgeIndex].roundedP.s[0] = roundedP0.s[0];
			facetEdges[facetEdgeIndex].roundedP.s[1] = roundedP0.s[1];
			facetEdges[facetEdgeIndex].roundedP.s[2] = roundedP0.s[2];
			facetEdges[facetEdgeIndex].roundedP.s[3] = 0;
			facetEdges[facetEdgeIndex].roundedQ.s[0] = roundedP1.s[0];
			facetEdges[facetEdgeIndex].roundedQ.s[1] = roundedP1.s[1];
			facetEdges[facetEdgeIndex].roundedQ.s[2] = roundedP1.s[2];
			facetEdges[facetEdgeIndex].roundedQ.s[3] = 0;
			
			// Edge 1: p0->p2
			facetEdgeIndex++;
			facetEdges[facetEdgeIndex].facetIndex = facetIndex;
			facetEdges[facetEdgeIndex].edgeIndex = 1;
			facetEdges[facetEdgeIndex].roundedP.s[0] = roundedP0.s[0];
			facetEdges[facetEdgeIndex].roundedP.s[1] = roundedP0.s[1];
			facetEdges[facetEdgeIndex].roundedP.s[2] = roundedP0.s[2];
			facetEdges[facetEdgeIndex].roundedP.s[3] = 0;
			facetEdges[facetEdgeIndex].roundedQ.s[0] = roundedP2.s[0];
			facetEdges[facetEdgeIndex].roundedQ.s[1] = roundedP2.s[1];
			facetEdges[facetEdgeIndex].roundedQ.s[2] = roundedP2.s[2];
			facetEdges[facetEdgeIndex].roundedQ.s[3] = 0;
			
			// Edge 2: p1->p2
			facetEdgeIndex++;
			facetEdges[facetEdgeIndex].facetIndex = facetIndex;
			facetEdges[facetEdgeIndex].edgeIndex = 2;
			facetEdges[facetEdgeIndex].roundedP.s[0] = roundedP1.s[0];
			facetEdges[facetEdgeIndex].roundedP.s[1] = roundedP1.s[1];
			facetEdges[facetEdgeIndex].roundedP.s[2] = roundedP1.s[2];
			facetEdges[facetEdgeIndex].roundedP.s[3] = 0;
			facetEdges[facetEdgeIndex].roundedQ.s[0] = roundedP2.s[0];
			facetEdges[facetEdgeIndex].roundedQ.s[1] = roundedP2.s[1];
			facetEdges[facetEdgeIndex].roundedQ.s[2] = roundedP2.s[2];
			facetEdges[facetEdgeIndex].roundedQ.s[3] = 0;
			
			// Edge 0': p1->p0
			facetEdgeIndex++;
			facetEdges[facetEdgeIndex].facetIndex = facetIndex;
			facetEdges[facetEdgeIndex].edgeIndex = 0;
			facetEdges[facetEdgeIndex].roundedQ.s[0] = roundedP0.s[0];
			facetEdges[facetEdgeIndex].roundedQ.s[1] = roundedP0.s[1];
			facetEdges[facetEdgeIndex].roundedQ.s[2] = roundedP0.s[2];
			facetEdges[facetEdgeIndex].roundedP.s[0] = roundedP1.s[0];
			facetEdges[facetEdgeIndex].roundedP.s[1] = roundedP1.s[1];
			facetEdges[facetEdgeIndex].roundedP.s[2] = roundedP1.s[2];
			facetEdges[facetEdgeIndex].roundedP.s[3] = 0;
			facetEdges[facetEdgeIndex].roundedQ.s[3] = 0;
			
			// Edge 1': p2->p0
			facetEdgeIndex++;
			facetEdges[facetEdgeIndex].facetIndex = facetIndex;
			facetEdges[facetEdgeIndex].edgeIndex = 1;
			facetEdges[facetEdgeIndex].roundedQ.s[0] = roundedP0.s[0];
			facetEdges[facetEdgeIndex].roundedQ.s[1] = roundedP0.s[1];
			facetEdges[facetEdgeIndex].roundedQ.s[2] = roundedP0.s[2];
			facetEdges[facetEdgeIndex].roundedP.s[0] = roundedP2.s[0];
			facetEdges[facetEdgeIndex].roundedP.s[1] = roundedP2.s[1];
			facetEdges[facetEdgeIndex].roundedP.s[2] = roundedP2.s[2];
			facetEdges[facetEdgeIndex].roundedP.s[3] = 0;
			facetEdges[facetEdgeIndex].roundedQ.s[3] = 0;
			
			// Edge 2': p2->p1
			facetEdgeIndex++;
			facetEdges[facetEdgeIndex].facetIndex = facetIndex;
			facetEdges[facetEdgeIndex].edgeIndex = 2;
			facetEdges[facetEdgeIndex].roundedQ.s[0] = roundedP1.s[0];
			facetEdges[facetEdgeIndex].roundedQ.s[1] = roundedP1.s[1];
			facetEdges[facetEdgeIndex].roundedQ.s[2] = roundedP1.s[2];
			facetEdges[facetEdgeIndex].roundedP.s[0] = roundedP2.s[0];
			facetEdges[facetEdgeIndex].roundedP.s[1] = roundedP2.s[1];
			facetEdges[facetEdgeIndex].roundedP.s[2] = roundedP2.s[2];
			facetEdges[facetEdgeIndex].roundedP.s[3] = 0;
			facetEdges[facetEdgeIndex].roundedQ.s[3] = 0;
			
			
			
			facetEdgeIndex = facetIndex*3;
			
			// Edge 0: p0->p1
			indexedEdges[facetEdgeIndex].facetIndex = facetIndex;
			indexedEdges[facetEdgeIndex].edgeIndex = 0;
			indexedEdges[facetEdgeIndex].roundedP.s[0] = roundedP0.s[0];
			indexedEdges[facetEdgeIndex].roundedP.s[1] = roundedP0.s[1];
			indexedEdges[facetEdgeIndex].roundedP.s[2] = roundedP0.s[2];
			indexedEdges[facetEdgeIndex].roundedQ.s[0] = roundedP1.s[0];
			indexedEdges[facetEdgeIndex].roundedQ.s[1] = roundedP1.s[1];
			indexedEdges[facetEdgeIndex].roundedQ.s[2] = roundedP1.s[2];
			indexedEdges[facetEdgeIndex].touchesFacetIndex = (cl_uint)-1;
			indexedEdges[facetEdgeIndex].touchesEdgeIndex =  (cl_uint)-1;
			indexedEdges[facetEdgeIndex].roundedP.s[3] = 0;
			indexedEdges[facetEdgeIndex].roundedQ.s[3] = 0;
			
			// Edge 1: p0->p2
			facetEdgeIndex++;
			indexedEdges[facetEdgeIndex].facetIndex = facetIndex;
			indexedEdges[facetEdgeIndex].edgeIndex = 1;
			indexedEdges[facetEdgeIndex].roundedP.s[0] = roundedP0.s[0];
			indexedEdges[facetEdgeIndex].roundedP.s[1] = roundedP0.s[1];
			indexedEdges[facetEdgeIndex].roundedP.s[2] = roundedP0.s[2];
			indexedEdges[facetEdgeIndex].roundedQ.s[0] = roundedP2.s[0];
			indexedEdges[facetEdgeIndex].roundedQ.s[1] = roundedP2.s[1];
			indexedEdges[facetEdgeIndex].roundedQ.s[2] = roundedP2.s[2];
			indexedEdges[facetEdgeIndex].touchesFacetIndex = (cl_uint)-1;
			indexedEdges[facetEdgeIndex].touchesEdgeIndex =  (cl_uint)-1;
			indexedEdges[facetEdgeIndex].roundedP.s[3] = 0;
			indexedEdges[facetEdgeIndex].roundedQ.s[3] = 0;
			
			// Edge 2: p1->p2
			facetEdgeIndex++;
			indexedEdges[facetEdgeIndex].facetIndex = facetIndex;
			indexedEdges[facetEdgeIndex].edgeIndex = 2;
			indexedEdges[facetEdgeIndex].roundedP.s[0] = roundedP1.s[0];
			indexedEdges[facetEdgeIndex].roundedP.s[1] = roundedP1.s[1];
			indexedEdges[facetEdgeIndex].roundedP.s[2] = roundedP1.s[2];
			indexedEdges[facetEdgeIndex].roundedQ.s[0] = roundedP2.s[0];
			indexedEdges[facetEdgeIndex].roundedQ.s[1] = roundedP2.s[1];
			indexedEdges[facetEdgeIndex].roundedQ.s[2] = roundedP2.s[2];
			indexedEdges[facetEdgeIndex].touchesFacetIndex = (cl_uint)-1;
			indexedEdges[facetEdgeIndex].touchesEdgeIndex =  (cl_uint)-1;
			indexedEdges[facetEdgeIndex].roundedP.s[3] = 0;
			indexedEdges[facetEdgeIndex].roundedQ.s[3] = 0;
			
			facet = nextFacet(facet);
		}
		
		//	PSLog(@"Slice",PSPrioNormal,@"Time for indexprepare: %1.2fsec", -[startIndexPrepare timeIntervalSinceNow]);
		
		qsort_b(facetEdges, numberOfFacetEdges, kFacetEdgeSize, ^(const void *edge1, const void *edge2){
			return compareCl_Int4(((FacetEdge*)edge1)->roundedP, ((FacetEdge*)edge2)->roundedP);
		});
		
	#if __verbose
		PSLog(@"EdgeIndex",PSPrioNormal,@"Edges:");
		for(int i = 0; i<numberOfFacetEdges; i++)
			PSLog(@"EdgeIndex",PSPrioNormal,@"%3d: facet# %d edge# %d (%1.2f|%1.2f|%1.2f) - (%1.2f|%1.2f|%1.2f)", i, facetEdges[i].facetIndex, facetEdges[i].edgeIndex,
				  (float)facetEdges[i].roundedP[0]/kEdgeFinderPrecision, (float)facetEdges[i].roundedP[1]/kEdgeFinderPrecision, (float)facetEdges[i].roundedP[2]/kEdgeFinderPrecision,
				  (float)facetEdges[i].roundedQ[0]/kEdgeFinderPrecision, (float)facetEdges[i].roundedQ[1]/kEdgeFinderPrecision, (float)facetEdges[i].roundedQ[2]/kEdgeFinderPrecision );
	#endif

		cl_int err;	
		
		cl_mem inFacetEdges = clCreateBuffer(context, CL_MEM_READ_ONLY|CL_MEM_USE_HOST_PTR,  numberOfFacetEdges*kFacetEdgeSize, facetEdges, &err);
		if (!inFacetEdges || err != CL_SUCCESS)
		{
			PSErrorLog(@"clCreateBuffer inFacetEdges failed: %d",err);
            free(facetEdges);
            free(indexedEdges);
			return nil;
		}

		cl_mem inOutIndexedEdges = clCreateBuffer(context, CL_MEM_READ_WRITE|CL_MEM_USE_HOST_PTR, numberOfIndexedEdges*kEdgeIndexSize, indexedEdges, &err);
		if (!inOutIndexedEdges || err != CL_SUCCESS)
		{
			PSErrorLog(@"clCreateBuffer inOutIndexedEdges failed: %d",err);
            free(facetEdges);
            clReleaseMemObject(inFacetEdges);
            free(indexedEdges);
			return nil;
		}

		err = 0;
		err |= clSetKernelArg(kernelEdgeMatch, 0, sizeof(cl_mem), &inFacetEdges);
		err |= clSetKernelArg(kernelEdgeMatch, 1, sizeof(cl_mem), &inOutIndexedEdges);
		err |= clSetKernelArg(kernelEdgeMatch, 2, sizeof(cl_uint), &numberOfFacetEdges);
		if (err != CL_SUCCESS)
		{
			PSErrorLog(@"clSetKernelArg kernelEdgeMatch returns %d",err);
            free(facetEdges);
            free(indexedEdges);
            clReleaseMemObject(inFacetEdges);
            clReleaseMemObject(inOutIndexedEdges);
			return nil;
		}
		
		size_t global = numberOfIndexedEdges;
		err = clEnqueueNDRangeKernel(queue, kernelEdgeMatch, 1, NULL, &global, NULL, 0, NULL, NULL);
		if (err)
		{
			PSErrorLog(@"clEnqueueNDRangeKernel kernelEdgeMatch returns %d",err);
            free(facetEdges);
            free(indexedEdges);
            clReleaseMemObject(inFacetEdges);
            clReleaseMemObject(inOutIndexedEdges);
			return nil;
		}
			
		err = clEnqueueReadBuffer( queue, inOutIndexedEdges, CL_TRUE, 0, numberOfIndexedEdges*kEdgeIndexSize, indexedEdges, 0, NULL, NULL );  
		if (err != CL_SUCCESS)
		{
			PSErrorLog(@"clEnqueueReadBuffer returns %d",err);
            free(facetEdges);
            free(indexedEdges);
            clReleaseMemObject(inFacetEdges);
            clReleaseMemObject(inOutIndexedEdges);
			return nil;
		}
			
		clReleaseMemObject(inFacetEdges);
		clReleaseMemObject(inOutIndexedEdges);	
		free(facetEdges);
	}
	PSLog(@"Timer",PSPrioNormal,@"Time for edge index : %1.2fsec", -[startEdgeIndex timeIntervalSinceNow]);
	
#if __verbose
	PSLog(@"EdgeIndex",PSPrioNormal,@"Edge Index:");
	for(int i = 0; i<numberOfIndexedEdges; i++)
		PSLog(@"EdgeIndex",PSPrioNormal,@"facet# %d edge# %d <-> facet# %d edge# %d", indexedEdges[i].facetIndex, indexedEdges[i].edgeIndex, indexedEdges[i].touchesFacetIndex, indexedEdges[i].touchesEdgeIndex); 
#endif

	IndexedEdges* result = nil;
	if(indexedEdges)
		result = [[IndexedEdges alloc] initWithEdgeIndexData:[NSData dataWithBytesNoCopy:indexedEdges length:numberOfIndexedEdges*kEdgeIndexSize freeWhenDone:YES]];
	return result;
}

@end
