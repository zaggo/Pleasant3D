//
//  StepperFieldEnabledTransformer.m
//  Sanguino3G
//
//  Created by Eberhard Rensch on 09.04.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import "StepperFieldEnabledTransformer.h"


@implementation StepperFieldEnabledTransformer

+ (Class)transformedValueClass
{
    return [NSNumber class];
}

+ (BOOL)allowsReverseTransformation
{
    return NO;
}

- (id)transformedValue:(id)value
{
    return [NSNumber numberWithBool:[value intValue]==3];
}

@end
