//
//  P3DFormatRegistration.h
//  P3DCore
//
//  Created by Eberhard Rensch on 09.02.10.
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

// Well known InputFormats
extern NSString* const P3DFormatAnyProcessedData;

extern NSString* const P3DFormatIndexedSTL;
extern NSString* const P3DFormatLoops;
extern NSString* const P3DFormatGCode;

extern NSString* const P3DFormatOutputSameAsInput;


@interface P3DFormatRegistration : NSObject {
	NSMutableDictionary* formatDatabase;
}
+ (P3DFormatRegistration*)sharedInstance;

- (void)registerFormat:(NSString*)format conformsTo:(NSString*)baseFormat localizedName:(NSString*)name;
- (BOOL)format:(NSString*)format conformsTo:(NSString*)otherFormat;
- (BOOL)format:(NSString*)format conformsToAnyFormatInArray:(NSArray*)candidateFormats;
- (NSString*)localizedNameOfFormat:(NSString*)format;
@end
