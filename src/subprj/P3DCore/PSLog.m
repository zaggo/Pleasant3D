/*
 *  PSoftLog.mm
 *  Ubercaster
 *
 *  Created by Eberhard Rensch on 22.05.07.
 *  Copyright 2007 E.R.S Pleasant Software for the People. All rights reserved.
 *
 */

#include "PSLog.h"

#if defined(__DEBUG__) || defined(__VERBOSE__)
#include <unistd.h>

void switchToFileLogging()
{
	NSAutoreleasePool* pool = [NSAutoreleasePool new];
	NSString* path = [[NSBundle mainBundle] pathForResource:@"debugScopes" ofType:@"plist"];
	NSDictionary* scopeDict = [NSDictionary dictionaryWithContentsOfFile:path];
	
	if([[scopeDict objectForKey:@"writeLogFile"] boolValue])
	{
		NSDate* jetzt = [NSDate date];
		NSString* logFileName = [NSString stringWithFormat:@"~/Desktop/UCLogFile-%@.txt",[jetzt description]];
		freopen([[logFileName stringByExpandingTildeInPath] UTF8String], "w+", stderr);
        
		NSLog(@"=========== Log for run at %@ ===========",[jetzt description]);
	}
	[pool drain];
}

void PSoftLog(char* filename, NSInteger line, NSString* scope, NSInteger priority, NSString* logTxt, ...)
{
    va_list ap;
    va_start(ap, logTxt);
    
    static NSMutableArray* enabledScopes=nil;
    static NSMutableArray* disabledScopes=nil;
    static NSInteger verbosity = PSPrioNormal;
    static BOOL showNoneScoped=NO;
    if(enabledScopes==nil)
    {
		NSAutoreleasePool* pool=[NSAutoreleasePool new];
        NSString* path = [[NSBundle mainBundle] pathForResource:@"debugScopes" ofType:@"plist"];
        NSDictionary* scopeDict = [NSDictionary dictionaryWithContentsOfFile:path];
		enabledScopes = [NSMutableArray new];
		NSDictionary* enabledSwitches = [scopeDict objectForKey:@"enabledScopes"];
		NSEnumerator* keyEnum = [enabledSwitches keyEnumerator];
		NSString* key;
		while((key = [keyEnum nextObject]))
		{
			if([[enabledSwitches objectForKey:key] boolValue])
				[enabledScopes addObject:key];
		}
        if([enabledScopes containsObject:@"*"])
            showNoneScoped=YES;
		disabledScopes = [NSMutableArray new];
		NSDictionary* disabledSwitches = [scopeDict objectForKey:@"disabledScopes"];
		keyEnum = [disabledSwitches keyEnumerator];
		while((key = [keyEnum nextObject]))
		{
			if([[disabledSwitches objectForKey:key] boolValue])
				[disabledScopes addObject:key];
		}
        verbosity = [[scopeDict objectForKey:@"verbosity"] intValue];
		NSLog(@"PSLogging is ON and shows priorities %@ and above", ((verbosity==PSPrioLow)?@"LOW":(verbosity==PSPrioNormal)?@"NORMAL":(verbosity==PSPrioHigh)?@"HIGH":[NSString stringWithFormat:@"<%d>",verbosity]));
		[pool drain];
    }
    
	if(verbosity <= priority)
	{
		NSAutoreleasePool* pool=[NSAutoreleasePool new];
		NSString* fileNameCleaned = [[NSString stringWithCString:filename encoding:NSMacOSRomanStringEncoding] lastPathComponent];
		
		BOOL logInScope=NO;
		
		NSMutableArray* scopes = [NSMutableArray arrayWithObject:[fileNameCleaned stringByDeletingPathExtension]];
		if([scope length]>0)
		{
			[scopes addObjectsFromArray:[scope componentsSeparatedByString:@","]];
		}
		
		logInScope=showNoneScoped; // May be "YES"
		if(scopes)
		{
			if(enabledScopes && [enabledScopes firstObjectCommonWithArray:scopes]!=nil)
				logInScope=YES;
			if(disabledScopes && [disabledScopes firstObjectCommonWithArray:scopes]!=nil)
				logInScope=NO;
		}
        
		if(logInScope)
		{
			NSString* log;
			if([logTxt length]>0)
				log = [NSString stringWithFormat:@"%@ (%@:%d)",logTxt, fileNameCleaned, line];
			else
				log = @"";
			NSLogv(log, ap);
		}
		[pool drain];
	}
}
#endif

void PSoftErrorLog(char* filename, NSInteger line, NSString* logTxt, ...)
{
    va_list ap;
    va_start(ap, logTxt);
    NSAutoreleasePool* pool=[NSAutoreleasePool new];
	NSString* log = [NSString stringWithFormat:@"%@ (%@:%d)",logTxt, [[NSString stringWithCString:filename encoding:NSMacOSRomanStringEncoding] lastPathComponent], line];
	NSLogv(log, ap);
	[pool drain];
}


BOOL PSoftAssert(char* filename, NSInteger line, BOOL condition, NSString* logTxt, ...)
{
	if(!condition)
	{
		va_list ap;
		va_start(ap, logTxt);
		NSAutoreleasePool* pool=[NSAutoreleasePool new];
		NSString* log = [NSString stringWithFormat:@"*** ASSERTION FAILED!! %@ (%@:%d)",logTxt, [[NSString stringWithCString:filename encoding:NSMacOSRomanStringEncoding] lastPathComponent], line];
		NSLogv(log, ap);
		
#if defined(__DEBUG__) || defined(__VERBOSE__)
        NSAlert* fatalError = [NSAlert alertWithMessageText:@"Assertion failed!" defaultButton:@"Fail" alternateButton:nil otherButton:nil informativeTextWithFormat:log ];
        [fatalError runModal];
#endif
		[pool drain];
	}
	
	return condition;
}