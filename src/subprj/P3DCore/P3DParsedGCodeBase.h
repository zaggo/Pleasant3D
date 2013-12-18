//
//  P3DParsedGCodeBase.h
//  P3DCore
//
//  Created by Eberhard Rensch on 16.12.13.
//  Copyright (c) 2013 Pleasant Software. All rights reserved.
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

#import <Foundation/Foundation.h>
#import <OpenGL/OpenGL.h>

#define kTimestamp @"timestamp"
#define kFirstVertexIndex @"firstVertexIndex"
#define kMinLayerZ @"minLayerZ"
#define kMaxLayerZ @"maxLayerZ"

#define kRapidMoveAlpha .6f // This is used to define the _extrusionOffColor resp. _fastMoveColor, GCodeView uses this value to recognize those lines

@class P3DPrinterDriverBase, Vector3;
@interface P3DParsedGCodeBase : NSObject {
    P3DPrinterDriverBase* _currentPrinter;
    Vector3* _cornerHigh;
    Vector3* _cornerLow;
    NSData* _vertexBuffer;
    GLsizei _vertexCount;
    GLsizei _vertexStride;
    
    NSArray* _vertexIndex;
    NSMutableArray* _parsingErrors;
}

@property (readonly, strong) Vector3* cornerHigh;
@property (readonly, strong) Vector3* cornerLow;
@property (readonly) GLfloat* vertexArray;
@property (readonly) GLsizei vertexCount;
@property (readonly) GLsizei vertexStride;
@property (readonly, strong) NSArray* vertexIndex;
@property (readonly) NSArray* parsingErrors;

- (id)initWithGCodeString:(NSString*)gcode printer:(P3DPrinterDriverBase*)currentPrinter;

- (void)addError:(NSString*)formatString, ...;
@end
