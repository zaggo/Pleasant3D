//
//  P3DMillDriverBase.h
//  P3DCore
//
//  Created by Eberhard Rensch on 14.12.13.
//  Copyright (c) 2013 Pleasant Software. All rights reserved.
//

#import <P3DCore/P3DCore.h>

@interface P3DMillDriverBase : P3DMachineDriverBase
{
    float _fastXYFeedrate;
    float _fastZFeedrate;
    float _slowFeedrate;
}
@property (readonly) float fastXYFeedrate;
@property (readonly) float fastZFeedrate;
@property (readonly) float slowFeedrate;
@end
