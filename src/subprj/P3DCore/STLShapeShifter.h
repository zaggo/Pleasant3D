//
//  STLShapeShifter.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 14.01.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//
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
