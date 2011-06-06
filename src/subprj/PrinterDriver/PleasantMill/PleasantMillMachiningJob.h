//
//  PleasantMillPrintJob.h
//  PleasantMill
//
//  Created by Eberhard Rensch on 11.04.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <P3DCore/P3DCore.h>


@interface PleasantMillMachiningJob : P3DMachineJob {
	NSArray* gCode;
    NSString* response;
}

- (id)initWithGCode:(NSString*)gc;

@end
