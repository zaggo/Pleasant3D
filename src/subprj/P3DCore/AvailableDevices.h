//
//  ConnectedMakerbots.h
//  Sanguino3G
//
//  Created by Eberhard Rensch on 16.03.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class P3DSerialDevice;
@interface AvailableDevices : NSObject 
{
    BOOL started;
    BOOL discovering;
	NSMutableArray* availableDrivers;
	NSMutableArray* availableSerialDevices;
	
	IONotificationPortRef notificationPort;
	io_iterator_t	deviceAddedNotificationIterator;	
}

@property (readonly) NSArray* availableDevices;
@property (assign) BOOL discovering;

+ (AvailableDevices*)sharedInstance;
- (void)startup;

- (P3DSerialDevice*)reconnectDevice:(Class)deviceDriverClass withBSDPath:(NSString*)bsdPath;

@end
