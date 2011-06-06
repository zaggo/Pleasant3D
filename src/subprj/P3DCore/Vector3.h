//
//  Vector3.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 23.07.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
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
- (Vector3*)idiv:(float)other;
- (void)maximizeWith:(Vector3*)other;
- (void)minimizeWith:(Vector3*)other;
- (void)maximizeWithX:(float)x Y:(float)y Z:(float)z;
- (void)minimizeWithX:(float)x Y:(float)y Z:(float)z;
- (Vector2*)dropAxis:(NSInteger)which;
- (Vector3*)resetWith:(Vector3*)other;
@end
