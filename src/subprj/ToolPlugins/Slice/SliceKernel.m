//
//  SliceKernel.m
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

#import "SliceKernel.h"

#include "sliceVerticesOpenCLSource.h" // Will be generated from sliceVertices.cl during build time (processOpenCL.pl Build Rule)

#define __verbose 0

const size_t kSTLFacetCLSize=sizeof(STLFacetCL);
const size_t kSlicedEdgeSize=sizeof(SlicedEdge);
const size_t kSlicedEdgeLayerReferenceSize=sizeof(SlicedEdgeLayerReference);
const size_t kLineOffsetSize=sizeof(LineOffset);
const size_t kFacetEdgeSize=sizeof(FacetEdge);
const size_t kEdgeIndexSize=sizeof(EdgeIndex);
const size_t kInsetLoopCornerSize=sizeof(InsetLoopCorner);

static void inverseSlicedEdge(SlicedEdge* edge)
{
	cl_uint endEdge = edge->parentEndEdge;
	edge->parentEndEdge = edge->parentStartEdge;
	edge->parentStartEdge = endEdge;
	cl_float2 p;
	p.s[0] = edge->startPoint.s[0];
	p.s[1] = edge->startPoint.s[1];
	edge->startPoint.s[0] = edge->endPoint.s[0];
	edge->startPoint.s[1] = edge->endPoint.s[1];
	edge->endPoint.s[0] = p.s[0];
	edge->endPoint.s[1] = p.s[1];
}


@implementation SliceKernel
@synthesize extrusionHeight, extrusionWidth;

- (BOOL)prepareOpelCL
{
	int err;
	int gpu = 0;
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
		
	program = clCreateProgramWithSource(context, sliceVerticesSourceCodeCount,	sliceVerticesSourceCode, NULL, &err);
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
	
	kernelCalcLineOffsets = clCreateKernel(program, "calcLineOffsets", &err);
    if (!kernelCalcLineOffsets || err != CL_SUCCESS) {
		PSErrorLog(@"clCreateKernel kernelCalcLineOffsets returns %d",err);
		return NO;
	}
	
	kernelSliceTriangles = clCreateKernel(program, "sliceTriangles", &err);
    if (!kernelSliceTriangles || err != CL_SUCCESS) {
		PSErrorLog(@"clCreateKernel kernelSliceTriangles returns %d",err);
		return NO;
	}
	
	kernelInsetLoop = clCreateKernel(program, "insetLoop", &err);
    if (!kernelInsetLoop || err != CL_SUCCESS) {
		PSErrorLog(@"clCreateKernel kernelInsetLoop returns %d",err);
		return NO;
	}
	
	kernelOptimizeCornerPoints = clCreateKernel(program, "optimizeCornerPoints", &err);
    if (!kernelOptimizeCornerPoints || err != CL_SUCCESS) {
		PSErrorLog(@"clCreateKernel kernelOptimizeCornerPoints returns %d",err);
		return NO;
	}
	
	kernelOptimizeConnections = clCreateKernel(program, "optimizeConnections", &err);
    if (!kernelOptimizeConnections || err != CL_SUCCESS) {
		PSErrorLog(@"clCreateKernel kernelOptimizeConnections returns %d",err);
		return NO;
	}
	
	return YES;
}

- (void)cleanupOpenCL
{
	PSLog(@"Slice",PSPrioNormal,@"PSSlice: Cleaning up OpenCL");
	if(kernelCalcLineOffsets) clReleaseKernel(kernelCalcLineOffsets);
	if(kernelSliceTriangles) clReleaseKernel(kernelSliceTriangles);
	if(kernelInsetLoop) clReleaseKernel(kernelInsetLoop);
	if(kernelOptimizeCornerPoints) clReleaseKernel(kernelOptimizeCornerPoints);
	if(kernelOptimizeConnections) clReleaseKernel(kernelOptimizeConnections);
	if(program) clReleaseProgram(program);
	if(queue) clReleaseCommandQueue(queue);
	if(context) clReleaseContext(context);	
	context=nil; // This marks the whole OpenCL setup as "cleaned up"	
}


- (id) init
{
	self = [super init];
	if (self != nil) {
		extrusionHeight = .4;
		extrusionWidth = 1.5*extrusionHeight;
	}
	return self;
}

- (void)finalize
{
	if(context)
		[self cleanupOpenCL];
	[super finalize];
}

- (P3DLoops*)slice:(IndexedSTLModel*)indexedModel
{
	NSMutableArray* layerLoops=nil;
	InsetLoopCorner* insetLoops=nil;
	NSUInteger totalCorners=0;
	if(context || [self prepareOpelCL])
	{
		cl_int err;	
		STLBinaryHead* stl = [indexedModel.stlModel stlHead];
			
	#pragma mark Step 1: Calc Line Offsets. Calculate the buffer sizes for slicing
		
		cl_float zStart = (cl_float)indexedModel.stlModel.cornerMinimum.z;
		NSUInteger totalLayers = (NSUInteger)((indexedModel.stlModel.cornerMaximum.z-indexedModel.stlModel.cornerMinimum.z)/extrusionHeight);
		LineOffset* lineOffsets = (LineOffset*)malloc(stl->numberOfFacets*kLineOffsetSize);
		
		// Get the stl facets from the stl model. The STLFacetCL array is aligned and suited for use in OpenCL kernels
		STLFacetCL* facetsCL = [indexedModel.stlModel facets];
		
		cl_mem inputFacets = clCreateBuffer(context, CL_MEM_READ_ONLY|CL_MEM_COPY_HOST_PTR,  kSTLFacetCLSize*stl->numberOfFacets, facetsCL, &err);
		if (!inputFacets || err != CL_SUCCESS)
		{
			PSErrorLog(@"clCreateBuffer inputFacets failed: %d",err);
			return nil;
		}
		
		cl_mem inOutLineOffsets = clCreateBuffer(context, CL_MEM_READ_WRITE|CL_MEM_COPY_HOST_PTR, kLineOffsetSize*stl->numberOfFacets, lineOffsets, &err);
		if (!inOutLineOffsets || err != CL_SUCCESS)
		{
			PSErrorLog(@"clCreateBuffer inOutLineOffsets failed: %d",err);
			return nil;
		}
					
		cl_float layerHeight = (cl_float)extrusionHeight;
		err = 0;
		err |= clSetKernelArg(kernelCalcLineOffsets, 0, sizeof(cl_mem), &inOutLineOffsets);
		err |= clSetKernelArg(kernelCalcLineOffsets, 1, sizeof(cl_mem), &inputFacets);
		err |= clSetKernelArg(kernelCalcLineOffsets, 2, sizeof(cl_float), &zStart);
		err |= clSetKernelArg(kernelCalcLineOffsets, 3, sizeof(cl_float), &layerHeight);
		if (err != CL_SUCCESS)
		{
			PSErrorLog(@"clSetKernelArg kernelCalcLineOffsets returns %d",err);
			return nil;
		}
		
		size_t global = stl->numberOfFacets;
		err = clEnqueueNDRangeKernel(queue, kernelCalcLineOffsets, 1, NULL, &global, NULL, 0, NULL, NULL);
		if (err)
		{
			PSErrorLog(@"clEnqueueNDRangeKernel returns %d",err);
			return nil;
		}
		
		err = clEnqueueReadBuffer( queue, inOutLineOffsets, CL_TRUE, 0, kLineOffsetSize*stl->numberOfFacets, lineOffsets, 0, NULL, NULL );  
		if (err != CL_SUCCESS)
		{
			PSErrorLog(@"clEnqueueReadBuffer returns %d",err);
			return nil;
		}
		
		//
		// Calculating the number of Sliced Lines from the intermed results
		// This step changes the meaning of the "offset" field
		// before it was the number of layers affecting the facet.
		// after it'll be the start index in the global slicedPoints array for this facet
		//
		NSUInteger totalSlices=0;
		for(NSInteger fIndex=0; fIndex<stl->numberOfFacets; fIndex++)
		{
			NSUInteger count=lineOffsets[fIndex].offset;
			if(count>0)
				lineOffsets[fIndex].offset = totalSlices;
			else
				lineOffsets[fIndex].offset = (cl_uint)-1; // Nothing to slice for this one
			totalSlices += count;
		}
			
	#pragma mark Step 2: Slice the triangles in the model
	#ifdef __DEBUG__
		NSDate* startOfSliceTriangles = [NSDate date];
	#endif

		// 
		// Create buffer for the endresults
		//
		
        if(totalSlices==0)
        {
			PSErrorLog(@"clCreateBuffer totalSlices==0");
            free(lineOffsets);
			return nil;
        }
		// This array holds all sliced points
		SlicedEdge* slicedEdges = (SlicedEdge*)malloc(totalSlices*kSlicedEdgeSize);
		// This array holds an index of "layerIndex" <-> "slicedPointIndex"
		SlicedEdgeLayerReference* slicedEdgeLayerReferences = (SlicedEdgeLayerReference*)malloc(totalSlices*kSlicedEdgeLayerReferenceSize);
		
		cl_mem inOutSlicedEdges;
		inOutSlicedEdges = clCreateBuffer(context, CL_MEM_READ_WRITE|CL_MEM_USE_HOST_PTR, totalSlices*kSlicedEdgeSize,slicedEdges, &err);
		if (!inOutSlicedEdges || err != CL_SUCCESS)
		{
			PSErrorLog(@"clCreateBuffer inOutSlicedEdges failed: %d", err);
            free(lineOffsets);
			return nil;
		}
		cl_mem inOutSlicedEdgeLayerReferences;
		inOutSlicedEdgeLayerReferences = clCreateBuffer(context, CL_MEM_READ_WRITE|CL_MEM_USE_HOST_PTR, totalSlices*kSlicedEdgeLayerReferenceSize,slicedEdgeLayerReferences, &err);
		if (!inOutSlicedEdgeLayerReferences || err != CL_SUCCESS)
		{
			PSErrorLog(@"clCreateBuffer inOutSlicedEdgeLayerReferences failed: %d", err);
            free(lineOffsets);
			return nil;
		}
		
		err = clSetKernelArg(kernelSliceTriangles, 0, sizeof(cl_mem), &inOutSlicedEdges);
		err |= clSetKernelArg(kernelSliceTriangles, 1, sizeof(cl_mem), &inOutSlicedEdgeLayerReferences);
		err |= clSetKernelArg(kernelSliceTriangles, 2, sizeof(cl_mem), &inputFacets);
		err |= clSetKernelArg(kernelSliceTriangles, 3, sizeof(cl_mem), &inOutLineOffsets);
		err |= clSetKernelArg(kernelSliceTriangles, 4, sizeof(cl_float), &zStart);
		err |= clSetKernelArg(kernelSliceTriangles, 5, sizeof(cl_float), &layerHeight);
		if (err != CL_SUCCESS)
		{
			PSErrorLog(@"clSetKernelArg kernelSliceTriangles returns %d",err);
            free(lineOffsets);
			return nil;
		}		
		
		global = stl->numberOfFacets;
		err = clEnqueueNDRangeKernel(queue, kernelSliceTriangles, 1, NULL, &global, NULL, 0, NULL, NULL);
		if (err)
		{
			PSErrorLog(@"clEnqueueNDRangeKernel returns %d",err);
            free(lineOffsets);
			return nil;
		}
			
		err = clEnqueueReadBuffer( queue, inOutSlicedEdges, CL_TRUE, 0, totalSlices*kSlicedEdgeSize, slicedEdges, 0, NULL, NULL );  
		if (err != CL_SUCCESS)
		{
			PSErrorLog(@"clEnqueueReadBuffer inOutSlicedPoints returns %d",err);
            free(lineOffsets);
			return nil;
		}
		
		err = clEnqueueReadBuffer( queue, inOutSlicedEdgeLayerReferences, CL_TRUE, 0, totalSlices*kSlicedEdgeLayerReferenceSize, slicedEdgeLayerReferences, 0, NULL, NULL );  
		if (err != CL_SUCCESS)
		{
			PSErrorLog(@"clEnqueueReadBuffer inOutSlicedPointLayerReferences returns %d",err);
            free(lineOffsets);
			return nil;
		}
		
		PSLog(@"Timer",PSPrioNormal,@"Time for executing OpenCL kernel SliceTriangles: %1.2f", -[startOfSliceTriangles timeIntervalSinceNow]);
	#if __verbose
		PSLog(@"Slice",PSPrioNormal,@"Sliced Edges:");
		for(int i = 0; i<totalSlices; i++)
			PSLog(@"Slice",PSPrioNormal,@"#%d Layer %d  Facet %d (%f|%f) [Edge %d] -> (%f|%f) [Edge %d]", i, slicedEdges[i].layerIndex, slicedEdges[i].parentFacet, 
				  slicedEdges[i].startPoint[0], slicedEdges[i].startPoint[1], slicedEdges[i].parentStartEdge,
				  slicedEdges[i].endPoint[0], slicedEdges[i].endPoint[1], slicedEdges[i].parentEndEdge);
	#endif
		
	#pragma mark Step 3: Sort and index the results from Step 2 for further processing
		
	#ifdef __DEBUG__
		NSDate* startSortAndIndex = [NSDate date];
	#endif	
		// Sort the Layer references
		qsort_b(slicedEdgeLayerReferences, totalSlices, kSlicedEdgeLayerReferenceSize, ^(const void *arg1, const void *arg2){
			return (int)(((SlicedEdgeLayerReference*)arg1)->layerIndex-((SlicedEdgeLayerReference*)arg2)->layerIndex);
		});

		// We can now access the sliced edges sorted by layerIndex
		
		// The layer catalog contains an Index from layerIndex -> slicedPointLayerReference (-> slicedPointIndex)
		// With help of this catalog, we have fast access on the first slicedPoint of a layer
		cl_uint* layerCatalog = (cl_uint*)calloc((totalLayers+1),sizeof(cl_uint));
		NSUInteger lastLayerIndex = 0;
		NSUInteger layerCatalogLength = 0;
		layerCatalog[layerCatalogLength++]=0;
		for(NSUInteger catRefIdx=0;catRefIdx<totalSlices; catRefIdx++)
		{
			if(lastLayerIndex<slicedEdgeLayerReferences[catRefIdx].layerIndex)
			{
				lastLayerIndex=slicedEdgeLayerReferences[catRefIdx].layerIndex;
				do
				{
					layerCatalog[layerCatalogLength++]=catRefIdx;
				} while(layerCatalogLength<lastLayerIndex);
			}
		}
		layerCatalog[layerCatalogLength++]=totalSlices; // Add a last (virtual) index for boundarie calculations
		
		PSLog(@"Timer",PSPrioNormal,@"Time for executing SortAndIndex: %1.2f", -[startSortAndIndex timeIntervalSinceNow]);

	#if __verbose
		PSLog(@"Slice",PSPrioNormal,@"Sorted EdgeLayerReferences:");
		for(int i = 0; i<totalSlices; i++)
			PSLog(@"Slice",PSPrioNormal,@"#%d Layer# %d -> Edge# %d", i, slicedEdgeLayerReferences[i].layerIndex, slicedEdgeLayerReferences[i].slicedEdgeIndex);
		
		
		PSLog(@"Slice",PSPrioNormal,@"LayerCatalog:");
		for(int i = 0; i<layerCatalogLength-1; i++)
			PSLog(@"Slice",PSPrioNormal,@"Layer# %d from %u to %u", i, layerCatalog[i], layerCatalog[i+1]-1);
	#endif
		
	#pragma mark Step 4: Connect the loops on each layer

	#ifdef __DEBUG__
		NSDate* startConnectLayerLoops = [NSDate date];
	#endif

		NSUInteger __block danglingEdges=0;
		
	#if !__disable_gcd	
		
		dispatch_queue_t globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
		dispatch_group_t dpGroup = dispatch_group_create();
	#endif
		
		for(NSInteger layerIndex = 0; layerIndex<totalLayers-1; layerIndex++)
		{
	#if !__disable_gcd	
		
			dispatch_group_async(dpGroup, globalQueue, ^{
	#endif		
			NSUInteger startIndex = layerCatalog[layerIndex];
			NSUInteger endIndex = layerCatalog[layerIndex+1];

			for(NSUInteger refIdx = startIndex; refIdx<endIndex; refIdx++)
			{
				NSUInteger currentEdgeIndex = slicedEdgeLayerReferences[refIdx].slicedEdgeIndex;
				if(slicedEdges[currentEdgeIndex].connectsTo==(cl_uint)-1) // Not yet handled
				{
					BOOL stillInLoop=YES;
					while(stillInLoop)
					{
						NSUInteger connectionIndex = slicedEdges[currentEdgeIndex].parentFacet*3+slicedEdges[currentEdgeIndex].parentEndEdge;
						if(connectionIndex>=indexedModel.edgeIndex.numberOfIndexedEdges)
						{
							PSErrorLog(@"Corrupted Data in indexedEdges");
							//stillInLoop=NO;
							break;
						}
						EdgeIndex connectionInfo = indexedModel.edgeIndex.indexedEdges[connectionIndex];
						
						BOOL conectionFound=NO;
						NSUInteger connectingRefIdx;
						for(connectingRefIdx = startIndex; connectingRefIdx<endIndex; connectingRefIdx++)
						{
							if(/*(slicedEdges[slicedEdgeLayerReferences[connectingRefIdx].slicedEdgeIndex].connectsTo==(cl_uint)-1 ||
								slicedEdgeLayerReferences[refIdx].slicedEdgeIndex == currentEdgeIndex) &&*/
							   slicedEdges[slicedEdgeLayerReferences[connectingRefIdx].slicedEdgeIndex].parentFacet == connectionInfo.touchesFacetIndex &&
							   (slicedEdges[slicedEdgeLayerReferences[connectingRefIdx].slicedEdgeIndex].parentStartEdge == connectionInfo.touchesEdgeIndex ||
							   slicedEdges[slicedEdgeLayerReferences[connectingRefIdx].slicedEdgeIndex].parentEndEdge == connectionInfo.touchesEdgeIndex))
							{
								if(slicedEdges[slicedEdgeLayerReferences[connectingRefIdx].slicedEdgeIndex].parentEndEdge == connectionInfo.touchesEdgeIndex)
								{
									inverseSlicedEdge(&(slicedEdges[slicedEdgeLayerReferences[connectingRefIdx].slicedEdgeIndex]));
								}
								
								slicedEdges[currentEdgeIndex].connectsTo = slicedEdgeLayerReferences[connectingRefIdx].slicedEdgeIndex;
								currentEdgeIndex = slicedEdgeLayerReferences[connectingRefIdx].slicedEdgeIndex;
								conectionFound=YES;
								if(slicedEdgeLayerReferences[refIdx].slicedEdgeIndex == currentEdgeIndex) // The Loop is closed!
								{
									stillInLoop=NO;
								}
								break;
							}
						}					
						if(!conectionFound)
						{
							//stillInLoop=NO;
							danglingEdges++;
							break;
						}
					}
				}
			}
			
	#if !__disable_gcd	
			}); // dispatch
	#endif		
		}
	#if !__disable_gcd	
		dispatch_group_wait(dpGroup, DISPATCH_TIME_FOREVER);
		dispatch_release(dpGroup);
	#endif	
		if(danglingEdges>0)
			PSErrorLog(@"Could't recover %d dangling edges",danglingEdges);
		PSLog(@"Timer",PSPrioNormal,@"Time for executing ConnectLayerLoops: %1.2f", -[startConnectLayerLoops timeIntervalSinceNow]);
			
	#if __verbose
		PSLog(@"Slice",PSPrioNormal,@"Sliced Connected Edges:");
		for(int i = 0; i<totalSlices; i++)
			PSLog(@"Slice",PSPrioNormal,@"#%d Layer %d Facet %d (%f|%f) [Edge %d] -> (%f|%f) [Edge %d] Connects To %d", i, slicedEdges[i].layerIndex, slicedEdges[i].parentFacet,
				  slicedEdges[i].startPoint[0], slicedEdges[i].startPoint[1], slicedEdges[i].parentStartEdge,
				  slicedEdges[i].endPoint[0], slicedEdges[i].endPoint[1], slicedEdges[i].parentEndEdge,
				  slicedEdges[i].connectsTo);
	#endif	

		
	#pragma mark Step 5: Optimize Loops - Mark all uneccessary points in the loops

	#ifdef __DEBUG__
		NSDate* startOfOptimize = [NSDate date];
	#endif
		
		// 
		// Create buffer for the endresults
		//
		
		// This array holds all sliced points
		cl_uint* optimizedConnections = (cl_uint*)malloc(totalSlices*sizeof(cl_uint));
		
		cl_mem inOutOptimizedConnections;
		inOutOptimizedConnections = clCreateBuffer(context, CL_MEM_READ_WRITE|CL_MEM_USE_HOST_PTR, totalSlices*sizeof(cl_uint), optimizedConnections, &err);
		if (!inOutOptimizedConnections || err != CL_SUCCESS)
		{
			PSErrorLog(@"clCreateBuffer inOutOptimizedConnections failed: %d", err);
            free(layerCatalog);
            free(slicedEdges);
            free(lineOffsets);
            free(optimizedConnections);
			return nil;
		}
		
		// TODO: Necessary?
		err = clEnqueueWriteBuffer(queue, inOutSlicedEdges, CL_FALSE, 0, totalSlices*kSlicedEdgeSize, slicedEdges, 0, NULL, NULL);
		if (err != CL_SUCCESS) {
			PSErrorLog(@"clEnqueueWriteBuffer inOutSlicedEdges returns %d",err);
            free(layerCatalog);
            free(slicedEdges);
            free(lineOffsets);
            free(optimizedConnections);
			return nil;
		}
		
		// Phase 1: Gather Information
		err = clSetKernelArg(kernelOptimizeCornerPoints, 0, sizeof(cl_mem), &inOutOptimizedConnections);
		err = clSetKernelArg(kernelOptimizeCornerPoints, 1, sizeof(cl_mem), &inOutSlicedEdges);
		if (err != CL_SUCCESS)
		{
			PSErrorLog(@"clSetKernelArg kernelOptimizeCornerPoints returns %d",err);
            free(layerCatalog);
            free(slicedEdges);
            free(lineOffsets);
            free(optimizedConnections);
			return nil;
		}		
		
		global = totalSlices;
		err = clEnqueueNDRangeKernel(queue, kernelOptimizeCornerPoints, 1, NULL, &global, NULL, 0, NULL, NULL);
		if (err)
		{
			PSErrorLog(@"clEnqueueNDRangeKernel kernelOptimizeCornerPoints returns %d",err);
            free(layerCatalog);
            free(slicedEdges);
            free(lineOffsets);
            free(optimizedConnections);
			return nil;
		}
				
		// Phase 2: Process Information		
		err = clSetKernelArg(kernelOptimizeConnections, 0, sizeof(cl_mem), &inOutOptimizedConnections);
		err = clSetKernelArg(kernelOptimizeConnections, 1, sizeof(cl_mem), &inOutSlicedEdges);
		if (err != CL_SUCCESS)
		{
			PSErrorLog(@"clSetKernelArg kernelOptimizeCornerPoints returns %d",err);
            free(layerCatalog);
            free(slicedEdges);
            free(lineOffsets);
            free(optimizedConnections);
			return nil;
		}		
		global = totalSlices;
		err = clEnqueueNDRangeKernel(queue, kernelOptimizeConnections, 1, NULL, &global, NULL, 0, NULL, NULL);
		if (err)
		{
			PSErrorLog(@"clEnqueueNDRangeKernel kernelOptimizeCornerPoints returns %d",err);
            free(layerCatalog);
            free(slicedEdges);
            free(lineOffsets);
            free(optimizedConnections);
			return nil;
		}
		
		err = clEnqueueReadBuffer( queue, inOutSlicedEdges, CL_TRUE, 0, totalSlices*kSlicedEdgeSize, slicedEdges, 0, NULL, NULL );  
		if (err != CL_SUCCESS)
		{
			PSErrorLog(@"clEnqueueReadBuffer inOutSlicedPoints returns %d",err);
            free(layerCatalog);
            free(slicedEdges);
            free(lineOffsets);
            free(optimizedConnections);
			return nil;
		}
		
		
		clReleaseMemObject(inOutOptimizedConnections);
		free(optimizedConnections);
		PSLog(@"Timer",PSPrioNormal,@"Time for executing OpenCL kernel OptimizeCornerPoints: %1.2f", -[startOfOptimize timeIntervalSinceNow]);
		
		layerLoops = [[NSMutableArray alloc] initWithCapacity:totalLayers];
		for(NSUInteger layerIndex = 0; layerIndex<totalLayers; layerIndex++)
			[layerLoops addObject:[[NSMutableArray alloc] init]];
		totalCorners=0;
		for(NSUInteger sliceIndex = 0; sliceIndex<totalSlices; sliceIndex++)
		{
			if(slicedEdges[sliceIndex].connectsTo!=(cl_uint)-1 && slicedEdges[sliceIndex].optimizedIndex==(cl_uint)-1) // relevant and not yet handled
			{
				P3DMutableLoopIndexArray* loop = [[P3DMutableLoopIndexArray alloc] init];
				[loop.metaData setObject:(id)kCFBooleanTrue forKey:@"isPerimeter"];
				
				[loop addInteger:totalCorners];
				slicedEdges[sliceIndex].optimizedIndex = totalCorners++;

				NSUInteger currentSliceIndex = sliceIndex;
				
				while(slicedEdges[currentSliceIndex].connectsTo!=(cl_uint)-1)
				{
					//NSUInteger thisIndex = currentSliceIndex;
					currentSliceIndex=slicedEdges[currentSliceIndex].connectsTo;
					//slicedEdges[thisIndex].connectsTo=(cl_uint)-1;
					if(currentSliceIndex==sliceIndex) // Loop closed!
					{
						[loop addInteger:slicedEdges[sliceIndex].optimizedIndex];
						[[layerLoops objectAtIndex:slicedEdges[currentSliceIndex].layerIndex] addObject:loop];
						loop=nil;
						break;
					}
//					if(slicedEdges[currentSliceIndex].optimizedIndex!=(cl_uint)-1)
//					{
//						NSLog(@"Loopbreak");
//						break;
//					}
						
					
					[loop addInteger:totalCorners];
					slicedEdges[currentSliceIndex].optimizedIndex = totalCorners++;
				}
				if([loop count]>1)	// Dangling edge (worth to try...)
				{
					[[layerLoops objectAtIndex:slicedEdges[currentSliceIndex].layerIndex] addObject:loop];
				}
			}
		}
		PSLog(@"Timer",PSPrioNormal,@"Time for executing OptimizeCornerPoints: %1.2f", -[startOfOptimize timeIntervalSinceNow]);
#if __verbose
		PSLog(@"Slice",PSPrioNormal,@"Optimized Edges:");
		for(int i = 0; i<totalSlices; i++)
			if(slicedEdges[i].connectsTo!=(cl_uint)-1)
				PSLog(@"Slice",PSPrioNormal,@"#%d Layer %d Facet %d (%f|%f) [Edge %d] -> (%f|%f) [Edge %d] Connects To %d Optimized Index: %d", i, slicedEdges[i].layerIndex, slicedEdges[i].parentFacet,
				  slicedEdges[i].startPoint[0], slicedEdges[i].startPoint[1], slicedEdges[i].parentStartEdge,
				  slicedEdges[i].endPoint[0], slicedEdges[i].endPoint[1], slicedEdges[i].parentEndEdge,
				  slicedEdges[i].connectsTo, slicedEdges[i].optimizedIndex);
		PSLog(@"Slice",PSPrioNormal,@"Invalidated slices:");
		for(int i = 0; i<totalSlices; i++)
			if(slicedEdges[i].connectsTo==(cl_uint)-1)
				PSLog(@"Slice",PSPrioNormal,@"(#%d Layer %d Facet %d (%f|%f) [Edge %d] -> (%f|%f) [Edge %d] Connects To %d Optimized Index: %d)", i, slicedEdges[i].layerIndex, slicedEdges[i].parentFacet,
				  slicedEdges[i].startPoint[0], slicedEdges[i].startPoint[1], slicedEdges[i].parentStartEdge,
				  slicedEdges[i].endPoint[0], slicedEdges[i].endPoint[1], slicedEdges[i].parentEndEdge,
				  slicedEdges[i].connectsTo, slicedEdges[i].optimizedIndex);
#endif	
		
	#pragma mark Step 6: Inset the Loops

	#ifdef __DEBUG__
		NSDate* startOfInsetLoops = [NSDate date];
	#endif
		
		// 
		// Create buffer for the endresults
		//
		
        if(totalCorners==0)
		{
			PSErrorLog(@"clCreateBuffer totalCorners==0");
            free(layerCatalog);
            free(slicedEdges);
            free(lineOffsets);
			return nil;
		}
		// This array holds all sliced points
		insetLoops = (InsetLoopCorner*)malloc(totalCorners*kInsetLoopCornerSize);
		
		
		// SKALAR:
//		float inset = extrusionWidth;
		
	//	char* facetPtr = (char*)firstFacet(stl);
	//	for(unsigned int globalId = 0; globalId< totalSlices;globalId++)
	//	{
	//	
	//		SlicedEdge thisEdge = slicedEdges[globalId];
	//		
	//		if(thisEdge.connectsTo!=(unsigned int)-1)
	//		{
	//			SlicedEdge nextEdge= slicedEdges[thisEdge.connectsTo];
	//
	//			Vector2d* thisEdgeNormal2d = [[Vector2d alloc] initWithX:thisEdge.normal[0] Y:thisEdge.normal[1]];
	//			Vector2d* thisEndPoint = [[Vector2d alloc] initWithX:thisEdge.endPoint[0] Y:thisEdge.endPoint[1]];
	//
	//			Vector2d* nextEdgeNormal2d = [[Vector2d alloc] initWithX:nextEdge.normal[0] Y:nextEdge.normal[1]];
	//			
	//			// Calculate the cornerpoint's normal
	//			
	//			float rad1 = atan2(thisEdgeNormal2d.y, thisEdgeNormal2d.x);
	//			float rad2 = atan2(nextEdgeNormal2d.y, nextEdgeNormal2d.x);
	//			float drad1=rad1-rad2;
	//			if(drad1<0.) drad1+=2.*M_PI;
	//			float drad2=rad2-rad1;
	//			if(drad2<0.) drad2+=2.*M_PI;		
	//			float prad;
	//			if(fabsf(drad1)>fabsf(drad2))
	//				prad = rad1+drad2/2.;
	//			else
	//				prad = rad2+drad1/2.;
	//		//	NSLog(@"#%d this: %1.1f° next: %1.1f° Sum: %1.1f°",globalId, rad1/M_PI*180., rad2/M_PI*180., prad/M_PI*180.);
	//			
	//			insetLoops[globalId].normal[0] = cosf(prad);
	//			insetLoops[globalId].normal[1] = sinf(prad);
	//
	//			insetLoops[globalId].point[0] = thisEndPoint.x-insetLoops[globalId].normal[0]*inset;
	//			insetLoops[globalId].point[1] = thisEndPoint.y-insetLoops[globalId].normal[1]*inset;
	//		}
	//		else
	//		{
	//			insetLoops[globalId].point[0] = -INFINITY;
	//			insetLoops[globalId].point[1] = -INFINITY;
	//			insetLoops[globalId].normal[0] = 0.;
	//			insetLoops[globalId].normal[1] = 0.;
	//		}
	//	}

	//	for(int i=0; i< totalSlices;i++)
	//		PSLog(@"Slice",PSPrioNormal,@"Inset Corner: #%d P(%1.2f|%1.2f) N(%1.2f|%1.2f)", i, insetLoops[i].point[0], insetLoops[i].point[1], insetLoops[i].normal[0], insetLoops[i].normal[1]);
	//
	//	NSInteger ln=0;
	//	for(PSMutableIntegerArray* loop in layerLoops)
	//	{
	//		PSLog(@"Slice",PSPrioNormal,@"Loop %d: %@",ln++, [loop description]);
	//	}
		
		// OpenCL:
		cl_mem outInsetLoops;
		outInsetLoops = clCreateBuffer(context, CL_MEM_WRITE_ONLY|CL_MEM_USE_HOST_PTR, totalCorners*kInsetLoopCornerSize,insetLoops, &err);
		if (!outInsetLoops || err!=CL_SUCCESS)
		{
			PSErrorLog(@"clCreateBuffer outInsetLoops failed: %d",err);
			free(insetLoops);
            free(layerCatalog);
            free(slicedEdges);
            free(lineOffsets);
            return nil;
		}
		
		err = clEnqueueWriteBuffer(queue, inOutSlicedEdges, CL_FALSE, 0, totalSlices*kSlicedEdgeSize, slicedEdges, 0, NULL, NULL);
		if (err != CL_SUCCESS) {
			PSErrorLog(@"clEnqueueWriteBuffer inOutSlicedEdges returns %d",err);
            free(layerCatalog);
            free(slicedEdges);
            free(lineOffsets);
			free(insetLoops);
			return nil;
		}
				
		err = clSetKernelArg(kernelInsetLoop, 0, sizeof(cl_mem), &outInsetLoops);
		err = clSetKernelArg(kernelInsetLoop, 1, sizeof(cl_mem), &inOutSlicedEdges);
		err |= clSetKernelArg(kernelInsetLoop, 2, sizeof(float), &extrusionWidth);
		if (err != CL_SUCCESS)
		{
			PSErrorLog(@"clSetKernelArg kernelInsetLoop returns %d",err);
            free(layerCatalog);
            free(slicedEdges);
            free(lineOffsets);
			free(insetLoops);
			return nil;
		}		
		global = totalSlices;
		err = clEnqueueNDRangeKernel(queue, kernelInsetLoop, 1, NULL, &global, NULL, 0, NULL, NULL);
		if (err)
		{
			PSErrorLog(@"clEnqueueNDRangeKernel kernelInsetLoop returns %d",err);
			free(insetLoops);
            free(layerCatalog);
            free(slicedEdges);
            free(lineOffsets);
			return nil;
		}
		
		err = clEnqueueReadBuffer( queue, outInsetLoops, CL_TRUE, 0, totalCorners*kInsetLoopCornerSize, insetLoops, 0, NULL, NULL );  
		if (err != CL_SUCCESS)
		{
			PSErrorLog(@"clEnqueueReadBuffer kernelInsetLoop returns %d",err);
			free(insetLoops);
            free(layerCatalog);
            free(slicedEdges);
            free(lineOffsets);
			return nil;
		}
			
		PSLog(@"Timer",PSPrioNormal,@"Time for executing OpenCL kernel InsetLoop: %1.2f", -[startOfInsetLoops timeIntervalSinceNow]);
	#if __verbose
		PSLog(@"Slice",PSPrioNormal,@"Inset Loop Corners:");
		for(int i = 0; i<totalCorners; i++)
			PSLog(@"Slice",PSPrioNormal,@"Corner (%f|%f) Normal (%f|%f)", insetLoops[i].point[0], insetLoops[i].point[1], insetLoops[i].normal[0], insetLoops[i].normal[1]);
	#endif	
		
		
	#pragma mark Cleaning up

		clReleaseMemObject(inOutSlicedEdges);
		clReleaseMemObject(inOutSlicedEdgeLayerReferences);
		clReleaseMemObject(inputFacets);
		clReleaseMemObject(inOutLineOffsets);
		clReleaseMemObject(outInsetLoops);
		free(lineOffsets);
		free(slicedEdgeLayerReferences);
		free(layerCatalog);
		free(slicedEdges);
		// insetLoops will be free'd by the following NSData object when done...
	}
	
	P3DLoops* result = nil;
	if(insetLoops)
	{
		result = [[P3DLoops alloc] initWithLoopCornerData:[[NSData alloc] initWithBytesNoCopy:insetLoops length:totalCorners*kInsetLoopCornerSize freeWhenDone:YES]];
		result.layers = layerLoops;
		result.extrusionHeight = extrusionHeight;
		result.extrusionWidth = extrusionWidth;
		result.cornerMaximum = indexedModel.stlModel.cornerMaximum;
		result.cornerMinimum = indexedModel.stlModel.cornerMinimum;
	}
		
	return result;
}	
@end
