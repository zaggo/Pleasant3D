//
//  Vector2.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 23.07.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface Vector2 : NSObject <NSCoding> {
	float x;
	float y;
}

@property (assign) float x;
@property (assign) float y;

- (id)initVectorWithX:(float)inX Y:(float)inY;
- (Vector2*)vectorByAddingVector:(Vector2*)other;
- (Vector2*)vectorBySubtractingVector:(Vector2*)other;
- (Vector2*)vectorByMultiplyingVector:(Vector2*)other;
- (Vector2*)vectorByMultiplyingScalar:(float)scalar;
- (Vector2*)vectorByDividingScalar:(float)scalar;
- (Vector2*)addVector:(Vector2*)other;
- (Vector2*)subtractVector:(Vector2*)other;
- (Vector2*)multiplyVector:(Vector2*)other;
- (Vector2*)multiplyScalar:(float)scalar;
- (Vector2*)divideScalar:(float)scalar;
- (float)lengthOfSubtractionWithVector:(Vector2*)other;
- (float)length;
- (float)dotProduct:(Vector2*)other;
- (float)dotProductPlusOne:(Vector2*)other;
- (Vector2*)vectorByNormalizing;
- (Vector2*)normalize;
- (float)getWiddershinsDot:(Vector2*)other;
- (void)maximizeWithVector:(Vector2*)other;
- (void)minimizeWithVector:(Vector2*)other;
- (Vector2*)vectorBySqrt;
@end
