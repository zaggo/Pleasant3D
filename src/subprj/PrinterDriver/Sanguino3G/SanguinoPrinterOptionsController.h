//
//  SanguinoPrinterOptionsController.h
//  Sanguino3G
//
//  Created by Eberhard Rensch on 09.04.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <P3DCore/P3DCore.h>
@interface SanguinoPrinterOptionsController : MachineOptionsViewController {
	IBOutlet NSTextField* deviceName;
}

- (IBAction)changeDeviceName:(id)sender;
- (IBAction)addToolhead:(id)sender;
- (IBAction)removeToolhead:(id)sender;
@end
