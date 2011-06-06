//
//  STLShapeShifter.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 14.01.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class STLModel, Vector3;
@interface STLShapeShifter : NSObject <NSCoding> {
	STLModel* sourceSTLModel;
	
	CGFloat dimX;
	CGFloat dimY;
	CGFloat dimZ;
	
	// ObjectRotate
	STLModel* processedSTLModel;
	CGFloat objectRotateX;
	CGFloat objectRotateY;
	CGFloat objectRotateZ;
	CGFloat objectScale;
	CGFloat centerX;
	CGFloat centerY;
	CGFloat minZ;
	
	NSUndoManager* undoManager;
}
@property (retain) STLModel* sourceSTLModel;
@property (readonly) STLModel* processedSTLModel;

@property (retain) NSUndoManager* undoManager;

@property (assign) CGFloat dimX;
@property (assign) CGFloat dimY;
@property (assign) CGFloat dimZ;

@property (assign) CGFloat centerX;
@property (assign) CGFloat centerY;
@property (assign) CGFloat minZ;

@property (assign) CGFloat objectRotateX;
@property (assign) CGFloat objectRotateY;
@property (assign) CGFloat objectRotateZ;
@property (assign) CGFloat objectScale;

- (void)resetWithSTLModel:(STLModel*)value;
- (void)rotateBy90OnAxis:(NSInteger)axis;
- (IBAction)rotateBy90:(id)sender;
- (IBAction)centerObject:(id)sender;

@end
