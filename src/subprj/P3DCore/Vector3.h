//
//  Vector3.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 23.07.09.
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

#import <Foundation/Foundation.h>
#import "Vector2.h"

@interface Vector3 : NSObject <NSCoding> {
	float x, y, z;
}
@property (assign) float x;
@property (assign) float y;
@property (assign) float z;

- (id)initVectorWithX:(float)inX Y:(float)inY Z:(float)inZ;
- (float)abs;
- (Vector3*)add:(Vector3*)other;
- (NSString*)asKey;
- (Vector3*)sub:(Vector3*)other;
- (Vector3*)isub:(Vector3*)other;
- (Vector3*)idiv:(float)factor;
- (Vector3*)imul:(float)factor;
- (float)distance:(Vector3*)other;
- (void)setToVector3:(Vector3*)other;
- (void)maximizeWith:(Vector3*)other;
- (void)minimizeWith:(Vector3*)other;
- (void)maximizeWithX:(float)x Y:(float)y Z:(float)z;
- (void)minimizeWithX:(float)x Y:(float)y Z:(float)z;
- (Vector2*)dropAxis:(NSInteger)which;
- (Vector3*)resetWith:(Vector3*)other;
- (Vector3*)normalize;
- (Vector3*)getNormalized;
- (Vector3*)cross:(Vector3*)other;
- (float)dot:(Vector3*)other;
- (Vector3*)negate;
- (Vector3*)inegate;
@end
