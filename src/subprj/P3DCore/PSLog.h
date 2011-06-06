/*
 *  PSoftLog.h
 *  Pleasant Software
 *
 *  Created by Eberhard Rensch on 22.05.07.
 *  Copyright 2007 E.R.S Pleasant Software for the People. All rights reserved.
 *
 */
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