//
//  STLDocument.h
//  PleasantSTL
//
//  Created by Eberhard Rensch on 12.10.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//


#import <Cocoa/Cocoa.h>
#import <P3DCore/P3DCore.h>

@class STLModel, STLPreviewView, STLShapeShifter;
@interface STLDocument : P3DMachinableDocument
{
	STLModel* loadedSTLModel;
	IBOutlet STLShapeShifter* stlShapeShifter;
	IBOutlet STLPreviewView* stlPreviewView;
}

@property (retain) STLModel* loadedSTLModel;
@property (retain) IBOutlet STLShapeShifter* stlShapeShifter;
@property (retain) IBOutlet STLPreviewView* stlPreviewView;

@end
