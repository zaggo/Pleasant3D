//
//  P3DMachineDriverBase.h
//  P3DCore
//
//  Created by Eberhard Rensch on 18.02.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
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
#import <Cocoa/Cocoa.h>

@class P3DMachinableDocument, Vector3;
@class P3DSerialDevice, MachineOptionsViewController, P3DMachineJob;
@interface P3DMachineDriverBase : NSObject {
    BOOL discovered;
    BOOL discovering;
	BOOL isMachining;
	BOOL isPaused;
    NSString* lastKnownBSDPath;
    
	P3DSerialDevice* currentDevice;
}

@property (assign) BOOL discovered;
@property (assign) BOOL isMachining;
@property (assign) BOOL isPaused;
@property (copy) NSString* lastKnownBSDPath;
@property (readonly) NSString* statusString;
@property (readonly) NSView* printDialogView;

@property (assign) P3DSerialDevice* currentDevice;

@property (readonly) NSImage* statusLightImage;

// Properties for Class Methods (for binding)
@property (readonly) NSString* driverImagePath;
@property (readonly) NSString* driverName;
@property (readonly) NSString* driverVersionString;
@property (readonly) NSString* driverManufacturer;
@property (readonly) Vector3* dimBuildPlattform;
@property (readonly) Vector3* zeroBuildPlattform;

+ (NSString*)driverIdentifier;
+ (Class)deviceDriverClass;
+ (NSString*)driverName;
+ (NSString*)defaultMachineName;
+ (NSString*)driverVersionString;
+ (NSString*)driverImagePath;
+ (NSString*)driverManufacturer;

- (id)initWithOptionPropertyList:(NSDictionary*)options;

- (P3DMachineJob*)createMachineJob:(P3DMachinableDocument*)doc;

- (MachineOptionsViewController*)machineOptionsViewController;
- (NSDictionary*)driverOptionsAsPropertyList;

@end
