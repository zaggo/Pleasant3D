/*
 *  PSoftLog.mm
 *  
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
		NSLog(@"PSLogging is ON and shows priorities %@ and above", ((verbosity==PSPrioLow)?@"LOW":(verbosity==PSPrioNormal)?@"NORMAL":(verbosity==PSPrioHigh)?@"HIGH":[NSString stringWithFormat:@"<%d>",(int32_t)verbosity]));
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
				log = [NSString stringWithFormat:@"%@ (%@:%d)",logTxt, fileNameCleaned, (int32_t)line];
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
	NSString* log = [NSString stringWithFormat:@"%@ (%@:%d)",logTxt, [[NSString stringWithCString:filename encoding:NSMacOSRomanStringEncoding] lastPathComponent], (int32_t)line];
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
		NSString* log = [NSString stringWithFormat:@"*** ASSERTION FAILED!! %@ (%@:%d)",logTxt, [[NSString stringWithCString:filename encoding:NSMacOSRomanStringEncoding] lastPathComponent], (int32_t)line];
		NSLogv(log, ap);
		
#if defined(__DEBUG__) || defined(__VERBOSE__)
        NSAlert* fatalError = [NSAlert alertWithMessageText:@"Assertion failed!" defaultButton:@"Fail" alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@",log ];
        [fatalError runModal];
#endif
		[pool drain];
	}
	
	return condition;
}