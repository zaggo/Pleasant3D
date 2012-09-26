//
//  ForwardTool.m
//  ForwardTool
//
// Created by Eberhard Rensch on 16.01.10.
// Copyright 2010 PleasantSoftware. All rights reserved.
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

#import "ForwardTool.h"
#import <dispatch/dispatch.h>

@implementation ForwardTool
@synthesize delayTime;

// Provide default values for all tool setting
+ (void)initialize
{
	NSDictionary *ddef = [NSDictionary dictionaryWithObjectsAndKeys:
						  [NSNumber numberWithFloat:.3], @"delayTime",
						  nil];
	[ForwardTool registerDefaultPreset:ddef];
}

- (id) initWithHost:(id <SliceNDiceHost>)host;
{
	self = [super initWithHost:host];
	if (self != nil) {
		self.toolInfo1 = NSLocalizedStringFromTableInBundle(@"No Input", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
		self.toolState = NSLocalizedStringFromTableInBundle(@"Waiting", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
	}
	return self;
}

- (id)initWithCoder:(NSCoder*)decoder
{
	self = [super initWithCoder:decoder];
	if(self)
	{
		delayTime = [decoder decodeFloatForKey:@"delayTime"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder*)encoder
{
	[super encodeWithCoder:encoder];
	
	[encoder encodeFloat:delayTime forKey:@"delayTime"];
}

- (void)saveSettingsToPreset:(NSMutableDictionary*)preset
{
	[preset setObject:[NSNumber numberWithFloat:self.delayTime] forKey:@"delayTime"];
}

- (void)loadSettingsFromPreset:(NSDictionary*)preset
{
	self.delayTime = [[preset objectForKey:@"delayTime"] floatValue];
}

+ (NSString*)localizedToolName
{
	return NSLocalizedStringFromTableInBundle(@"Pass-through", nil, [NSBundle bundleForClass:[self class]], @"Localized Display Name for Tool");
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
	return [NSArray arrayWithObject:P3DFormatAnyProcessedData];
}

// The format of the output data, provided by this tool
+ (NSString*)providesOutputFormat
{
	// See P3DToolBase/P3DToolBase.h for other options
	return P3DFormatOutputSameAsInput;
}

// Load the Settings GUI: Return the name of the settingsView nib
// If you choose to handle clicks by yourself (see customSettingsAction below), remove this method
- (NSString*)settingsViewNibName
{
	return @"ForwardSettingsGUI";
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
		dispatch_async(dispatch_get_main_queue(), ^{
			self.toolInfo2 = [NSString stringWithFormat:@"%C %@ %C",(unsigned short)0x25ba,NSStringFromClass([self.inputProvider.outData class]),(unsigned short)0x25ba];
			});
		self.outData=nil;		
		if(self.inputProvider.outData)
		{
			self.toolState = NSLocalizedStringFromTableInBundle(@"Delaying", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
			self.toolInfo1 = NSLocalizedStringFromTableInBundle(@"Working\\U2026", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
			self.isWorking = YES;
			
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				NSDate* startTime = [NSDate date];
									
				[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:delayTime]];
								
				NSTimeInterval duration = -[startTime timeIntervalSinceNow];
				
				// Since output is possibly bound to GUI-Elements, the setter has to run in the main thread!
				dispatch_async(dispatch_get_main_queue(), ^{
					self.isWorking = NO;
					self.outData = [self.inputProvider.outData copy];
					self.toolInfo1 = @"";
					self.toolState = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Done after %@", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message"), [self timeStringForTimeInterval:duration]];
				});
			});
		}
		else
		{
			self.toolInfo1 = NSLocalizedStringFromTableInBundle(@"No Input", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
			self.toolInfo2 = @"";
			self.toolState = NSLocalizedStringFromTableInBundle(@"Waiting", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
		}
	}
}

@end
