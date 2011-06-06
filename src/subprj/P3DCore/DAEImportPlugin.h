//
//  DAEImportPlugin.h
//  P3DCore
//
//  Created by Eberhard Rensch on 30.03.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class STLModel;
@interface DAEImportPlugin : NSObject {
	
}

- (STLModel*)readDAEModel:(NSData*)stlData error:(NSError**)error;
@end