/*
 *  PSoftLog.h
 *  Pleasant Software
 */
 //  Created by Eberhard Rensch on 07.01.10.
 //  Copyright 2010 Pleasant Software. All rights reserved.
 //
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
#import <Foundation/Foundation.h>

#if defined(__DEBUG__) || defined(__VERBOSE__)
#if defined(__cplusplus)
extern "C"
{
#endif
    void switchToFileLogging();
    void PSoftLog(char* filename, NSInteger line, NSString* scope, NSInteger priority, NSString* logTxt, ...);
#if defined(__cplusplus)
}
#endif

#define PSLog(scope,priority,logtxt,...) PSoftLog(__FILE__,__LINE__,scope,priority,logtxt,##__VA_ARGS__)

#else

#define PSLog(scope,priority,logtxt,...) {}

#endif

#if defined(__cplusplus)
extern "C"
{
#endif
    void PSoftErrorLog(char* filename, NSInteger line, NSString* logTxt, ...);
    BOOL PSoftAssert(char* filename, NSInteger line, BOOL condition, NSString* logTxt, ...);
#if defined(__cplusplus)
}
#endif

#define PSErrorLog(logtxt,...) PSoftErrorLog(__FILE__,__LINE__,logtxt,##__VA_ARGS__)

#define PSAssert(condition,logtxt,...) PSoftAssert(__FILE__,__LINE__,condition,logtxt,##__VA_ARGS__)
#define PSAssertOrReturn(condition,logtxt,...) if(!PSoftAssert(__FILE__,__LINE__,condition,logtxt,##__VA_ARGS__)) return;
#define PSAssertOrReturnNil(condition,logtxt,...) if(!PSoftAssert(__FILE__,__LINE__,condition,logtxt,##__VA_ARGS__)) return nil;

#define PSPrioLow 0
#define PSPrioNormal 1
#define PSPrioHigh 2