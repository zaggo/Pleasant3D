//
//  MachinePool.m
//  P3DCore
//
//  Created by Eberhard Rensch on 12.02.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import "MachinePool.h"
#import "PSLog.h"

@interface NSXMLNode (SingleObjectValue)
- (id)singleObjectForXPath:(NSString*)xpath error:(NSError**)error;
@end

@implementation NSXMLNode (SingleObjectValue)
- (id)singleObjectForXPath:(NSString*)xpath error:(NSError**)error
{
	NSArray* objects = [self nodesForXPath:xpath error:error];
	if(objects.count==1)
		return [objects objectAtIndex:0];
	return nil;
}
@end

@implementation MachinePool
@synthesize machineNames, machineSettings;

+ (MachinePool*)sharedInstance
{
	static MachinePool* _singleton = nil;
	static dispatch_once_t	justOnce=nil;
    dispatch_once(&justOnce, ^{
		_singleton = [[MachinePool alloc] init];
    });
	return _singleton;
}

+ (NSString*)machinesPath
{
	NSString* machinesPath=nil;
	
	NSError* error;
	NSFileManager* fm = [NSFileManager defaultManager];
	NSBundle* mainBundle = [NSBundle mainBundle];
	NSString* appName = [[mainBundle infoDictionary] objectForKey:@"CFBundleName"];
	NSArray* librarySearchPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	if(librarySearchPaths.count>0)
	{
		NSString* librarySearchPath=[librarySearchPaths objectAtIndex:0];
		machinesPath = [[librarySearchPath stringByAppendingPathComponent:appName] stringByAppendingPathComponent:@"Machines"];
		if(![fm fileExistsAtPath:machinesPath])
		{
			if([fm createDirectoryAtPath:machinesPath withIntermediateDirectories:YES attributes:nil error:&error])
			{
				NSString* defaultXMLPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"machines" ofType:@"xml"];
				[fm copyItemAtPath:defaultXMLPath toPath:[machinesPath stringByAppendingPathComponent:[defaultXMLPath lastPathComponent]] error:&error];
			}
		}
	}
	
	return machinesPath;
}

- (NSDictionary*)parseMachineDescription:(NSXMLNode*)machine
{
	NSError* error;
	NSMutableDictionary* machineDescription = [NSMutableDictionary dictionary];
	
	// Extract the name
	NSString* name = [[machine singleObjectForXPath:@"./name" error:&error] stringValue];
	if(name)
		[machineDescription setObject:name forKey:@"name"];
	else
		machineDescription=nil;
	
	NSArray* axes = [machine nodesForXPath:@"./geometry/axis" error:&error];
	if(machineDescription && axes.count>0)
	{
		NSMutableDictionary* geometryDict = [NSMutableDictionary dictionary];
		for(NSXMLNode* axis in axes)
		{
			NSString* axisId = [[axis singleObjectForXPath:@"./@id" error:&error] stringValue];
			if(axisId)
			{
				float length = [[[axis singleObjectForXPath:@"./@length" error:&error] stringValue] floatValue];
				float maxfeedrate = [[[axis singleObjectForXPath:@"./@maxfeedrate" error:&error] stringValue] floatValue];
				float scale = [[[axis singleObjectForXPath:@"./@scale" error:&error] stringValue] floatValue];
				[geometryDict setObject:[NSDictionary dictionaryWithObjectsAndKeys:
										 [NSNumber numberWithFloat:length], @"length",
										 [NSNumber numberWithFloat:maxfeedrate], @"maxfeedrate",
										 [NSNumber numberWithFloat:scale], @"scale",
											nil] forKey:axisId];
			}
		}
		[machineDescription setObject:geometryDict forKey:@"geometry"];
	}
	
	NSXMLNode* driver = [machine singleObjectForXPath:@"./driver" error:&error];
	if(machineDescription && driver)
	{
		NSString* name = [[driver singleObjectForXPath:@"./@name" error:&error] stringValue];
		if(name)
		{
			NSMutableDictionary* driverDict = [NSMutableDictionary dictionaryWithObject:name forKey:@"name"];
			
			NSString* portname = [[driver singleObjectForXPath:@"./portname" error:&error] stringValue];
			if(portname) [driverDict setObject:portname forKey:@"portname"];
			
			NSInteger rate = [[[driver singleObjectForXPath:@"./rate" error:&error] stringValue] intValue];
			[driverDict setObject:[NSNumber numberWithInt:rate] forKey:@"rate"];
			NSInteger parity = [[[driver singleObjectForXPath:@"./parity" error:&error] stringValue] intValue];
			[driverDict setObject:[NSNumber numberWithInt:parity] forKey:@"parity"];
			NSInteger databits = 1;
			if([driver singleObjectForXPath:@"./databits" error:&error])
				databits = [[[driver singleObjectForXPath:@"./databits" error:&error] stringValue] intValue];
			[driverDict setObject:[NSNumber numberWithInt:databits] forKey:@"databits"];
			NSString* stopbits = [[driver singleObjectForXPath:@"./databits" error:&error] stringValue];
			if(stopbits)
				[driverDict setObject:stopbits forKey:@"stopbits"];
			else
				[driverDict setObject:@"N" forKey:@"stopbits"];
				
			NSInteger debuglevel = [[[driver singleObjectForXPath:@"./debuglevel" error:&error] stringValue] intValue];
			[driverDict setObject:[NSNumber numberWithInt:debuglevel] forKey:@"debuglevel"];
			
			[machineDescription setObject:driverDict forKey:@"driver"];
		}
	}
	
	
	NSArray* tools = [machine nodesForXPath:@"./tools/tool" error:&error];
	if(machineDescription && tools.count>0)
	{
		NSMutableArray* toolsArray = [NSMutableArray array];
		for(NSXMLNode* tool in tools)
		{
			NSString* toolName = [[tool singleObjectForXPath:@"./@name" error:&error] stringValue];
			if(toolName)
			{
				NSMutableDictionary* toolDict = [NSMutableDictionary dictionaryWithObject:toolName forKey:@"name"];
				[toolsArray addObject:toolDict];
				
				NSString* type = [[tool singleObjectForXPath:@"./@type" error:&error] stringValue];
				if(type) [toolDict setObject:type forKey:@"type"];
				NSString* material = [[tool singleObjectForXPath:@"./@material" error:&error] stringValue];
				if(type) [toolDict setObject:material forKey:@"material"];
				NSString* motor = [[tool singleObjectForXPath:@"./@motor" error:&error] stringValue];
				[toolDict setObject:[NSNumber numberWithBool:[motor isEqualToString:@"true"]] forKey:@"motor"];
				NSString* floodcoolant = [[tool singleObjectForXPath:@"./@floodcoolant" error:&error] stringValue];
				[toolDict setObject:[NSNumber numberWithBool:[floodcoolant isEqualToString:@"true"]] forKey:@"floodcoolant"];
				NSString* mistcoolant = [[tool singleObjectForXPath:@"./@mistcoolant" error:&error] stringValue];
				[toolDict setObject:[NSNumber numberWithBool:[mistcoolant isEqualToString:@"true"]] forKey:@"mistcoolant"];
				NSString* fan = [[tool singleObjectForXPath:@"./@fan" error:&error] stringValue];
				[toolDict setObject:[NSNumber numberWithBool:[fan isEqualToString:@"true"]] forKey:@"fan"];
				NSString* valve = [[tool singleObjectForXPath:@"./@valve" error:&error] stringValue];
				[toolDict setObject:[NSNumber numberWithBool:[valve isEqualToString:@"true"]] forKey:@"valve"];
				NSString* heatedplatform = [[tool singleObjectForXPath:@"./@heatedplatform" error:&error] stringValue];
				[toolDict setObject:[NSNumber numberWithBool:[heatedplatform isEqualToString:@"true"]] forKey:@"heatedplatform"];
				NSString* collet = [[tool singleObjectForXPath:@"./@collet" error:&error] stringValue];
				[toolDict setObject:[NSNumber numberWithBool:[collet isEqualToString:@"true"]] forKey:@"collet"];
				NSString* heater = [[tool singleObjectForXPath:@"./@heater" error:&error] stringValue];
				[toolDict setObject:[NSNumber numberWithBool:[heater isEqualToString:@"true"]] forKey:@"heater"];
				NSString* motorSteps = [[tool singleObjectForXPath:@"./@motor_steps" error:&error] stringValue];
				if(motorSteps) [toolDict setObject:[NSNumber numberWithInt:[motorSteps intValue]] forKey:@"motor_steps"];
			}
		}
		[machineDescription setObject:toolsArray forKey:@"tools"];
	}
	return machineDescription;
}


- (NSArray*)machineSettings
{
	if(machineSettings==nil)
	{
		machineSettings = [[NSMutableArray alloc] init];
		machineNames = [[NSMutableArray alloc] init];
		
		NSString* machinesPath = [[self class] machinesPath];
		if(machinesPath)
		{
			BOOL useExperimentals = [[NSUserDefaults standardUserDefaults] boolForKey:@"LoadExperimentalMachines"];
			__block NSError* error;
			NSArray* candidates = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:machinesPath error:&error];
			for(NSString* currMachinePath in candidates)
			{
				// we found a preset, add it to the list
				NSString* path = [machinesPath stringByAppendingPathComponent:currMachinePath];
				if([[path pathExtension] isEqualToString:@"xml"])
				{
					NSXMLDocument *xmlDoc = [[NSXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] options:(NSXMLNodePreserveWhitespace|NSXMLNodePreserveCDATA) error:&error];
					if (xmlDoc == nil)
						xmlDoc = [[NSXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] options:NSXMLDocumentTidyXML error:&error];
					if (xmlDoc)
					{
						NSArray *nodes = [xmlDoc nodesForXPath:@"./machines/machine" error:&error];
						[nodes enumerateObjectsUsingBlock:^(id machine, NSUInteger idx, BOOL *stop) {

							// Only use definitions that are not experimental
							// unless
							NSArray* experimental = [(NSXMLNode*)machine nodesForXPath:@"./@experimental" error:&error];
							if(experimental.count==0 || [[[experimental objectAtIndex:0] objectValue] intValue]==0 || useExperimentals)
							{
								NSDictionary* parsedMachineDescription = [self parseMachineDescription:(NSXMLNode*)machine];
								if(parsedMachineDescription)
								{
									[machineSettings addObject:parsedMachineDescription];
								}
							}
						}];
					}
					else
					{
						PSErrorLog(@"Cannot read XML file at %@: %@",path, [error localizedDescription]);
					}					
				}
			}
		}
		[machineSettings sortUsingComparator:^(id obj1, id obj2) {
			return [(NSString*)[obj1 objectForKey:@"name"] compare:[obj2 objectForKey:@"name"] options:NSCaseInsensitiveSearch];
		}];
		
		[machineSettings enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			[machineNames addObject:[obj objectForKey:@"name"]];
		}];
	}
	return machineSettings;
}

- (NSArray*)machineNames
{
	if(machineNames==nil)
		[self machineSettings];
	return machineNames;
}
@end
