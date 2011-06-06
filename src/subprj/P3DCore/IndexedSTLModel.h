//
//  IndexedSTLData.h
//  STLImport
//
//  Created by Eberhard Rensch on 15.01.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <P3DCore/P3DCore.h>

@interface IndexedSTLModel : P3DProcessedObject {
	STLModel* stlModel;
	IndexedEdges* edgeIndex;
}

@property (retain) STLModel* stlModel;
@property (retain) IndexedEdges* edgeIndex;

@end
