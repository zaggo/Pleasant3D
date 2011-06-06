//
//  STLImportPlugin.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 23.07.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@class STLModel;
@interface STLImportPlugin : NSObject {

}

- (STLModel*)readSTLModel:(NSData*)rawData;
@end
