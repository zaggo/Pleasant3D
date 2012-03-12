//
//  ToolPool.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 13.01.10.
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

#import "ToolPool.h"
#import <P3DCore/P3DCore.h>

// Needed for _NSGetArgc/_NSGetArgv
// "crt_externs.h" has no C++ guards [3126393], so we have to provide them 
// ourself otherwise we get a link error.
#ifdef __cplusplus
extern "C" {
#endif
#include <crt_externs.h>
#ifdef __cplusplus
}
#endif

@interface ToolPool (Private)
- (void)importToolPlugins;
@end


@implementation ToolPool
@synthesize availableTools, loading, availableImporterUTIs, supportedToolCreatingUTIs;

+ (ToolPool*)sharedToolPool
{
	static ToolPool* _sharedToolPool=nil;
	if(_sharedToolPool==nil)
	{
		_sharedToolPool = [[ToolPool alloc] init];
		[_sharedToolPool importToolPlugins];
	}
	return _sharedToolPool;
}

- (id) init
{
	self = [super init];
	if (self != nil) {
		availableTools = [[NSMutableArray alloc] init];
		availableImporterUTIs = [[NSMutableArray alloc] init];
        supportedToolCreatingUTIs = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)importToolPlugins
{
	self.loading=YES;
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		__block NSError* error;
		NSFileManager* fm = [NSFileManager defaultManager];
		
		// Search order: ~/Library/AppSupport, /Library/AppSupport, inside app's plugins
		NSMutableArray* bundlePaths = [NSMutableArray array];
		NSMutableArray*    bundleSearchPaths = [NSMutableArray array];
		
		// Special feature for Developers: Launch argument -i<path> sets additional directory for searching
		// of plugins. Since the import algorithm does only load the first instance of a plugin (dependant on
		// the plugins CFBundleIdentifier), this mechanism can also be used to temporary overwrite an existing plugin
		int* argc = _NSGetArgc();
		char***argv=_NSGetArgv();
		for(int i=1;i<*argc;i++)
		{
			NSString* arg = [NSString stringWithCString:(*argv)[i] encoding:NSUTF8StringEncoding];
			if([arg hasPrefix:@"-i"])
			{
				NSString* pluginPath = [arg substringFromIndex:[@"-i" length]];
				NSLog(@"Additional bundleSearchPaths added: %@",pluginPath);
				[bundleSearchPaths addObject:pluginPath];
			}
		}
		
		NSBundle* mainBundle = [NSBundle mainBundle];
		NSString* pluginsPath = [mainBundle builtInPlugInsPath];
		NSString* appName = [[mainBundle infoDictionary] objectForKey:@"CFBundleName"];
		if(appName)
		{
			NSArray* librarySearchPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
			for(NSString* librarySearchPath in librarySearchPaths)
			{
				NSString* appSupPath = [[librarySearchPath stringByAppendingPathComponent:appName] stringByAppendingPathComponent:[pluginsPath lastPathComponent]];
				[bundleSearchPaths addObject:appSupPath];
				if(![fm fileExistsAtPath:appSupPath])
					[fm createDirectoryAtPath:appSupPath withIntermediateDirectories:YES attributes:nil error:&error];
			}
			librarySearchPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSLocalDomainMask, YES);
			for(NSString* librarySearchPath in librarySearchPaths)
			{
				[bundleSearchPaths addObject:[[librarySearchPath stringByAppendingPathComponent:appName] stringByAppendingPathComponent:[pluginsPath lastPathComponent]]];
			}
		}
		[bundleSearchPaths addObject:pluginsPath];
		
		[bundleSearchPaths enumerateObjectsUsingBlock:^(id currPath, NSUInteger idx, BOOL *stop) {
			NSArray* candidates = [fm contentsOfDirectoryAtPath:currPath error:&error];
			for(NSString* currBundlePath in candidates)
			{
				if ([[currBundlePath pathExtension] isEqualToString:@"bundle"])
				{
					// we found a bundle, add it to the list
					[bundlePaths addObject:[currPath stringByAppendingPathComponent:currBundlePath]];
				}
			}
		}];
		
		NSMutableArray* alreadyImportedPlugins = [NSMutableArray array];
		NSMutableArray* tempAvailableTools = [NSMutableArray array];
		for(NSString* bundlePath in bundlePaths)
		{
			NSBundle* plugin = [NSBundle bundleWithPath:bundlePath];
			NSString* identifier = [[plugin infoDictionary] objectForKey:@"CFBundleIdentifier"];
			if(![alreadyImportedPlugins containsObject:identifier])
			{
				Class pClass = [plugin principalClass];
				if([pClass isSubclassOfClass:[P3DToolBase class]])
				{
					// Allows overloading existing Plugins
					PSLog(@"ToolPool",PSPrioNormal,@"Adding plugin: %@",identifier);
					[alreadyImportedPlugins addObject:identifier];
					NSString* typeNameJoin = [[pClass toolType] stringByAppendingString:[pClass localizedToolName]];
					NSString* iconPath = nil;
					NSString* iconName = [pClass iconName];
					if(iconName)
						iconPath = [[NSBundle bundleForClass:pClass] pathForResource:iconName ofType:nil];
					if(iconPath==nil)
						iconPath = [[NSBundle mainBundle] pathForResource:@"Tool.png" ofType:nil];
					NSDictionary* toolDesc = [NSDictionary dictionaryWithObjectsAndKeys:
											  NSStringFromClass(pClass), kMSFPersistenceClass,
											  [pClass localizedToolName], @"localizedToolName",
											  typeNameJoin, @"toolType",
											  iconPath, @"toolIcon",
											  nil];
					[tempAvailableTools addObject:toolDesc];
					if([[pClass toolType] isEqualToString:P3DTypeImporter] && [pClass requiredInputFormats])
						[availableImporterUTIs addObjectsFromArray:[pClass requiredInputFormats]];
                    if([pClass respondsToSelector:@selector(importedContentDataUTIs)] && [pClass importedContentDataUTIs])
                        [supportedToolCreatingUTIs addObjectsFromArray:[pClass importedContentDataUTIs]];
				}
				
			}
		}
		
		dispatch_async(dispatch_get_main_queue(), ^{
			[self willChangeValueForKey:@"availableTools"];
			[availableTools addObjectsFromArray:tempAvailableTools];
			[self didChangeValueForKey:@"availableTools"];
			self.loading=NO;
		});
	});
}

@end
