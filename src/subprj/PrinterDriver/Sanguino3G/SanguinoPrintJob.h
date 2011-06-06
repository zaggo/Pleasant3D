//
//  SanguinoPrintJob.h
//  Sanguino3G
//
//  Created by Eberhard Rensch on 11.04.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <P3DCore/P3DCore.h>


@interface SanguinoPrintJob : P3DMachineJob {
	NSArray* bytecodeBuffers;
}

- (id)initWithBytecodeBuffers:(NSArray*)buffers;

@end
