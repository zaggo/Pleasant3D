//
//  SerialPort.h
//  PleasantMill
//
//  Created by Eberhard Rensch on 16.03.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <P3DCore/P3DCore.h>

@interface PleasantMillDevice : P3DSerialDevice {
    CGFloat machinableAreaX;
    CGFloat machinableAreaY;
    CGFloat machinableAreaZ;
}

- (void)changeMachineName:(NSString*)newName;
@end