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

- (id)initVectorWithX:(float)inX Y:(float)inY Z:(float)inZ
{
	self = [super init];
	if (self != nil) {
		_x = inX;
		_y = inY;
		_z = inZ;
	}
	return self;
}

- (id)initWithCoder:(NSCoder*)decoder
{
	self = [super init];
	if(self)
	{
		_x = [decoder decodeFloatForKey:@"x"];
		_y = [decoder decodeFloatForKey:@"y"];
		_z = [decoder decodeFloatForKey:@"z"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder*)encoder
{
	[encoder encodeFloat:_x forKey:@"x"];
	[encoder encodeFloat:_y forKey:@"y"];
	[encoder encodeFloat:_z forKey:@"z"];
}

- (Vector3*)copyWithZone:(NSZone *)zone
{
	return [[Vector3 alloc] initVectorWithX:_x Y:_y Z:_z];
}

// Get the magnitude of the Vector3.
- (float)abs
{
	return sqrtf(_x*_x + _y*_y + _z*_z);
}

// Get the sum of this Vector3 and other one.
- (Vector3*)add:(Vector3*)other;
{
	return [[Vector3 alloc] initVectorWithX:_x+other.x Y:_y+other.y Z:_z+other.z];
}


// Get a new Vector3 by dividing each component by the factor.
- (Vector3*)div:(float)factor
{
	return [[Vector3 alloc] initVectorWithX:_x/factor Y:_y/factor Z:_z/factor];
}

// Get a new Vector3 by floor dividing each component by the factor.
- (Vector3*)floordiv:(float)factor
{
	return [[Vector3 alloc] initVectorWithX:floorf(_x/factor) Y:floorf(_y/factor) Z:floorf(_z/factor)];
}

- (BOOL)isEqual:(Vector3*)other
{
	if(other==nil)
		return NO;
	return (_x==other.x && _y==other.y && _z==other.z);
}

- (NSUInteger)hash
{
	return (NSInteger)(_x+_y+_z);
}

- (Vector3*)iadd:(Vector3*)other
{
	_x+=other.x;
	_y+=other.y;
	_z+=other.z;
	return self;
}

- (Vector3*)idiv:(float)factor
{
	_x/=factor;
	_y/=factor;
	_z/=factor;
	return self;
}

- (Vector3*)ifloordiv:(float)factor
{
	_x=floorf(_x/factor);
	_y=floorf(_y/factor);
	_z=floorf(_z/factor);
	return self;
}

- (Vector3*)imul:(float)factor
{
	_x*=factor;
	_y*=factor;
	_z*=factor;
	return self;
}

- (Vector3*)isub:(Vector3*)other
{
	_x-=other.x;
	_y-=other.y;
	_z-=other.z;
	return self;
}

- (Vector3*)mul:(float)other
{
	return [[Vector3 alloc] initVectorWithX:_x*other Y:_y*other Z:_z*other];
}

- (BOOL)nonzero
{
	return (fabsf(_x)>FLT_EPSILON && fabsf(_y)>FLT_EPSILON && fabsf(_z)>FLT_EPSILON);
}

- (NSString*)description
{
	return [NSString stringWithFormat:@"Vector3(%f, %f, %f)",_x,_y,_z];
}

- (NSString*)asKey
{
	return [NSString stringWithFormat:@"%f,%f,%f",_x,_y,_z];
}

- (Vector3*)rdiv:(Vector3*)other
{
	return [[Vector3 alloc] initVectorWithX:_x/other.x Y:_y/other.y Z:_z/other.z];
}

- (Vector3*)rfloordiv:(Vector3*)other
{
	return [[Vector3 alloc] initVectorWithX:floorf(_x/other.x) Y:floorf(_y/other.y) Z:floorf(_z/other.z)];
}

- (Vector3*)rmul:(Vector3*)other
{
	return [[Vector3 alloc] initVectorWithX:_x*other.x Y:_y*other.y Z:_z*other.z];
}

- (Vector3*)sub:(Vector3*)other
{
	return [[Vector3 alloc] initVectorWithX:_x-other.x Y:_y-other.y Z:_z-other.z];
}

- (Vector3*)cross:(Vector3*)other
{
	return [[Vector3 alloc] initVectorWithX:_y*other.z-_z*other.y Y:-_x*other.z+_z*other.x Z:_x*other.y-_y*other.x];
}

- (float)distanceSquared:(Vector3*)other
{
	float separationX = _x - other.x;
	float separationY = _y - other.y;
	float separationZ = _z - other.z;
	return separationX * separationX + separationY * separationY + separationZ * separationZ;
}

- (float)distance:(Vector3*)other
{
	return sqrtf([self distanceSquared:other]);
}

- (float)dot:(Vector3*)other
{
	return _x * other.x + _y * other.y + _z * other.z;
}

- (Vector2*)dropAxis:(NSInteger)which
{
	switch(which)
	{
		case 0:
			return [[Vector2 alloc] initVectorWithX:_y Y:_z];
		case 1:
			return [[Vector2 alloc] initVectorWithX:_x Y:_z];
		default:
			return [[Vector2 alloc] initVectorWithX:_x Y:_y];
	}
}

- (Vector3*)getNormalized
{
	float magnitude = [self abs];
	if(magnitude<FLT_EPSILON)
		return [self copy];
	return [self div:magnitude];
}

- (float)magnitudeSquared
{
	return (_x*_x+_y*_y+_z*_z);
}

- (Vector3*)normalize
{
	float magnitude = [self abs];
	if(magnitude>FLT_EPSILON)
		[self idiv:magnitude];
    return self;
}

- (Vector3*)reflect:(Vector3*)normale
{
	float distance = 2.*(_x*normale.x+_y*normale.y+_z*normale.z);
	return [[Vector3 alloc] initVectorWithX:_x-distance*normale.x Y:_y-distance*normale.y Z:_z-distance*normale.z];
}

- (Vector3*)negate
{
    return [[Vector3 alloc] initVectorWithX:-_x Y:-_y Z:-_z];
}

- (Vector3*)inegate
{
    _x=-_x;
    _y=-_y;
    _z=-_z;
    return self;
}


- (void)setToVector3:(Vector3*)other
{
	_x = other.x;
	_y = other.y;
	_z = other.z;
}

- (void)maximizeWith:(Vector3*)other
{
	_x = MAX( _x, other.x );
	_y = MAX( _y, other.y );
	_z = MAX( _z, other.z );
}

- (void)minimizeWith:(Vector3*)other
{
	_x = MIN( _x, other.x );
	_y = MIN( _y, other.y );
	_z = MIN( _z, other.z );
}

- (void)maximizeWithX:(float)inX Y:(float)inY Z:(float)inZ;
{
	_x = MAX( _x, inX );
	_y = MAX( _y, inY );
	_z = MAX( _z, inZ );
}

- (void)minimizeWithX:(float)inX Y:(float)inY Z:(float)inZ;
{
	_x = MIN( _x, inX );
	_y = MIN( _y, inY );
	_z = MIN( _z, inZ );
}

- (Vector3*)resetWith:(Vector3*)other;
{
	_x = other.x;
	_y = other.y;
	_z = other.z;
	return self;
}
@end
