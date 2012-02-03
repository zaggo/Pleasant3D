//
//  Vector3.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 23.07.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
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

#import "Vector3.h"


@implementation Vector3
@synthesize x,y,z;

- (id)initVectorWithX:(float)inX Y:(float)inY Z:(float)inZ
{
	self = [super init];
	if (self != nil) {
		x = inX;
		y = inY;
		z = inZ;
	}
	return self;
}

- (id)initWithCoder:(NSCoder*)decoder
{
	self = [super init];
	if(self)
	{
		x = [decoder decodeFloatForKey:@"x"];
		y = [decoder decodeFloatForKey:@"y"];
		z = [decoder decodeFloatForKey:@"z"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder*)encoder
{
	[encoder encodeFloat:x forKey:@"x"];
	[encoder encodeFloat:y forKey:@"y"];
	[encoder encodeFloat:z forKey:@"z"];
}

- (Vector3*)copyWithZone:(NSZone *)zone
{
	return [[Vector3 alloc] initVectorWithX:x Y:y Z:z];
}

// Get the magnitude of the Vector3.
- (float)abs
{
	return sqrtf(x*x + y*y + z*z);
}

// Get the sum of this Vector3 and other one.
- (Vector3*)add:(Vector3*)other;
{
	return [[[Vector3 alloc] initVectorWithX:x+other.x Y:y+other.y Z:z+other.z] autorelease];
}


// Get a new Vector3 by dividing each component of this one.
- (Vector3*)div:(float)other
{
	return [[[Vector3 alloc] initVectorWithX:x/other Y:y/other Z:z/other] autorelease];
}

// Get a new Vector3 by dividing each component of this one.
- (Vector3*)floordiv:(float)other
{
	return [[[Vector3 alloc] initVectorWithX:floorf(x/other) Y:floorf(y/other) Z:floorf(z/other)] autorelease];
}

- (BOOL)isEqual:(Vector3*)other
{
	if(other==nil)
		return NO;
	return (x==other.x && y==other.y && z==other.z);
}

- (NSUInteger)hash
{
	return (NSInteger)(x+y+z);
}

- (Vector3*)iadd:(Vector3*)other
{
	x+=other.x;
	y+=other.y;
	z+=other.z;
	return self;
}

- (Vector3*)idiv:(float)other
{
	x/=other;
	y/=other;
	z/=other;
	return self;
}

- (Vector3*)ifloordiv:(float)other
{
	x=floorf(x/other);
	y=floorf(y/other);
	z=floorf(z/other);
	return self;
}

- (Vector3*)imul:(float)other
{
	x*=other;
	y*=other;
	z*=other;
	return self;
}

- (Vector3*)isub:(Vector3*)other
{
	x-=other.x;
	y-=other.y;
	z-=other.z;
	return self;
}

- (Vector3*)mul:(float)other
{
	return [[[Vector3 alloc] initVectorWithX:x*other Y:y*other Z:z*other] autorelease];
}

- (Vector3*)neg
{
	return [[[Vector3 alloc] initVectorWithX:-x Y:-y Z:-z] autorelease];
}

- (BOOL)nonzero
{
	return (fabsf(x)>FLT_EPSILON && fabsf(y)>FLT_EPSILON && fabsf(z)>FLT_EPSILON);
}

- (NSString*)description
{
	return [NSString stringWithFormat:@"Vector3(%f, %f, %f)",x,y,z];
}

- (NSString*)asKey
{
	return [NSString stringWithFormat:@"%f,%f,%f",x,y,z];
}

- (Vector3*)rdiv:(Vector3*)other
{
	return [[[Vector3 alloc] initVectorWithX:x/other.x Y:y/other.y Z:z/other.z] autorelease];
}

- (Vector3*)rfloordiv:(Vector3*)other
{
	return [[[Vector3 alloc] initVectorWithX:floorf(x/other.x) Y:floorf(y/other.y) Z:floorf(z/other.z)] autorelease];
}

- (Vector3*)rmul:(Vector3*)other
{
	return [[[Vector3 alloc] initVectorWithX:x*other.x Y:y*other.y Z:z*other.z] autorelease];
}

- (Vector3*)sub:(Vector3*)other
{
	return [[[Vector3 alloc] initVectorWithX:x-other.x Y:y-other.y Z:z-other.z] autorelease];
}

- (Vector3*)cross:(Vector3*)other
{
	return [[[Vector3 alloc] initVectorWithX:y*other.z-z*other.y Y:-x*other.z+z*other.x Z:x*other.y-y*other.x] autorelease];
}

- (float)distanceSquared:(Vector3*)other
{
	float separationX = x - other.x;
	float separationY = y - other.y;
	float separationZ = z - other.z;
	return separationX * separationX + separationY * separationY + separationZ * separationZ;
}

- (float)distance:(Vector3*)other
{
	return sqrtf([self distanceSquared:other]);
}

- (float)dot:(Vector3*)other
{
	return x * other.x + y * other.y + z * other.z;
}

- (Vector2*)dropAxis:(NSInteger)which
{
	switch(which)
	{
		case 0:
			return [[[Vector2 alloc] initVectorWithX:y Y:z] autorelease];
		case 1:
			return [[[Vector2 alloc] initVectorWithX:x Y:z] autorelease];
		default:
			return [[[Vector2 alloc] initVectorWithX:x Y:y] autorelease];
	}
}

- (Vector3*)getNormalized
{
	float magnitude = [self abs];
	if(magnitude<FLT_EPSILON)
		return [[self copy] autorelease];
	return [self div:magnitude];
}

- (float)magnitudeSquared
{
	return (x*x+y*y+z*z);
}

- (void)normalize
{
	float magnitude = [self abs];
	if(magnitude>FLT_EPSILON)
		[self idiv:magnitude];
}

- (Vector3*)reflect:(Vector3*)normale
{
	float distance = 2.*(x*normale.x+y*normale.y+z*normale.z);
	return [[[Vector3 alloc] initVectorWithX:x-distance*normale.x Y:y-distance*normale.y Z:z-distance*normale.z] autorelease];
}

- (void)setToVec3:(Vector3*)other
{
	x = other.x;
	y = other.y;
	z = other.z;
}

- (void)maximizeWith:(Vector3*)other
{
	x = MAX( x, other.x );
	y = MAX( y, other.y );
	z = MAX( z, other.z );
}

- (void)minimizeWith:(Vector3*)other
{
	x = MIN( x, other.x );
	y = MIN( y, other.y );
	z = MIN( z, other.z );
}

- (void)maximizeWithX:(float)inX Y:(float)inY Z:(float)inZ;
{
	x = MAX( x, inX );
	y = MAX( y, inY );
	z = MAX( z, inZ );
}

- (void)minimizeWithX:(float)inX Y:(float)inY Z:(float)inZ;
{
	x = MIN( x, inX );
	y = MIN( y, inY );
	z = MIN( z, inZ );
}

- (Vector3*)resetWith:(Vector3*)other;
{
	x = other.x;
	y = other.y;
	z = other.z;
	return self;
}
@end
