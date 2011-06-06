//
//  GcodeGenerator.m
//  Pleasant3D
//
// Created by Eberhard Rensch on 16.01.10.
// Copyright 2010 Pleasant Software. All rights reserved.
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

#import "GcodeGenerator.h"
#import <dispatch/dispatch.h>
#import "GCodeKernel.h"

@implementation GcodeGenerator
@synthesize travelFeedRate, layerSettings;

// Provide default values for all tool setting
+ (void)initialize
{
	NSDictionary *ddef = [NSDictionary dictionaryWithObjectsAndKeys:
						  [NSNumber numberWithFloat:58.], @"travelFeedRate",
						  [NSMutableArray arrayWithObject:
							[NSMutableDictionary dictionaryWithObjectsAndKeys:
								@"all", @"layer",
								[NSNumber numberWithFloat:28.], @"feedRate",
								[NSNumber numberWithFloat:255.], @"flowRate",
								nil]], @"layerSettings",
						  nil];
	[GcodeGenerator registerDefaultPreset:ddef];	
}

- (id) initWithHost:(id <SliceNDiceHost>)host;
{
	self = [super initWithHost:host];
	if (self != nil) {
		self.toolInfo1 = NSLocalizedStringFromTableInBundle(@"No Input", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
		self.toolState = NSLocalizedStringFromTableInBundle(@"Waiting", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
		
		gCodeGen = [[GCodeKernel alloc] init];
	}
	return self;
}

- (id)initWithCoder:(NSCoder*)decoder
{
	self = [super initWithCoder:decoder];
	if(self)
	{
		self.travelFeedRate = [decoder decodeFloatForKey:@"travelFeedRate"];
		self.layerSettings = [decoder decodeObjectForKey:@"layerSettings"];
		gCodeGen = [[GCodeKernel alloc] init];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder*)encoder
{
	[super encodeWithCoder:encoder];

	[encoder encodeFloat:travelFeedRate forKey:@"travelFeedRate"];
	[encoder encodeObject:layerSettings forKey:@"layerSettings"];
}

- (void)saveSettingsToPreset:(NSMutableDictionary*)preset
{
	[preset setObject:[NSNumber numberWithFloat:self.travelFeedRate] forKey:@"travelFeedRate"];
	[preset setObject:self.layerSettings forKey:@"layerSettings"];
}

- (void)loadSettingsFromPreset:(NSDictionary*)preset
{
	self.travelFeedRate = [[preset objectForKey:@"travelFeedRate"] floatValue];
	self.layerSettings = [preset objectForKey:@"layerSettings"];
}

+ (NSString*)localizedToolName
{
	return NSLocalizedStringFromTableInBundle(@"GCoder", nil, [NSBundle bundleForClass:[self class]], @"Localized Display Name for Tool");
}

+ (NSString*)toolType
{
	// See P3DToolBase/P3DToolBase.h for other options
	return P3DTypeTool;
}

// The format of input data, this tool can handle 
// If the tool doesn't handle any input format (e.g. import tools, reading the data from disk)
// remove this method or return nil
+ (NSArray*)requiredInputFormats
{
	// See P3DToolBase/P3DToolBase.h for other options
	return [NSArray arrayWithObject:P3DFormatLoops];
}

// The format of the output data, provided by this tool
+ (NSString*)providesOutputFormat
{
	// See P3DToolBase/P3DToolBase.h for other options
	return P3DFormatGCode;
}

// Load the Settings GUI: Return the name of the settingsView nib
// If you choose to handle clicks by yourself (see customSettingsAction below), remove this method
- (NSString*)settingsViewNibName
{
	return @"GcodeGeneratorSettingsGUI";
}

- (void)processData
{	
	if(isWorking)
	{
		if(!abortRequested)
			[self abortProcessData:self];
		[self performSelector:@selector(processData) withObject:nil afterDelay:.5];
	}
	else
	{
		self.outData=nil;		
		if(self.inputProvider.outData)
		{
			if([self.inputProvider.outData isKindOfClass:[P3DLoops class]])
			{
				self.toolInfo1 = NSLocalizedStringFromTableInBundle(@"Encoding\\U2026", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
				self.isWorking = YES;

#if !__disable_gcd	
				dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
#endif
					NSDate* startTime = [NSDate date];
					
					GCode* gCode = [gCodeGen generateGCode:(P3DLoops*)self.inputProvider.outData owner:self];
															
					NSTimeInterval duration = -[startTime timeIntervalSinceNow];
					
					// Since output is possibly bound to GUI-Elements, the setter has to run in the main thread!
#if !__disable_gcd	
					dispatch_async(dispatch_get_main_queue(), ^{
#endif
						self.isWorking = NO;
												
						self.outData = gCode;
						self.toolInfo1 = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"%d Lines", nil, [NSBundle bundleForClass:[self class]], @"Localized Slice Tool Status Message"), gCode.lineCount];
						self.toolState = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Encoded after %@", nil, [NSBundle bundleForClass:[self class]], @"Localized Slice Tool Status Message"), [self timeStringForTimeInterval:duration]];
#if !__disable_gcd	
					});
				});
#endif
			}
			else
			{
				self.toolInfo1 = NSLocalizedStringFromTableInBundle(@"Wrong Data", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
			}
		}
		else
		{
			self.toolInfo1 = NSLocalizedStringFromTableInBundle(@"No Input", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
			;
			self.toolState = NSLocalizedStringFromTableInBundle(@"Waiting", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
		}
	}
}

@end
