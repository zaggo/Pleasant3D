//
//  Slice.m
//  Slice
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

#import "Slice.h"
#import <dispatch/dispatch.h>
#import "SliceKernel.h"

@implementation Slice
@synthesize layerThickness, extrusionWidthOverThickness;
@dynamic extrusionWidth;

// Provide default values for all tool setting
+ (void)initialize
{
	NSDictionary *ddef = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithFloat:.4], @"layerThickness",
		[NSNumber numberWithFloat:1.5], @"extrusionWidthOverThickness",
		nil];
	[Slice registerDefaultPreset:ddef];
}

- (id) initWithHost:(id <SliceNDiceHost>)host;
{
	self = [super initWithHost:host];
	if (self != nil) {
		self.toolInfo1 = NSLocalizedStringFromTableInBundle(@"No Input", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
		self.toolState = NSLocalizedStringFromTableInBundle(@"Waiting", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
		
		slicer = [[SliceKernel alloc] init];
	}
	return self;
}

- (id)initWithCoder:(NSCoder*)decoder
{
	self = [super initWithCoder:decoder];
	if(self)
	{
		layerThickness = [decoder decodeFloatForKey:@"layerThickness"];
		extrusionWidthOverThickness = [decoder decodeFloatForKey:@"extrusionWidthOverThickness"];
		slicer = [[SliceKernel alloc] init];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder*)encoder
{
	[super encodeWithCoder:encoder];
	
	[encoder encodeFloat:layerThickness forKey:@"layerThickness"];
	[encoder encodeFloat:extrusionWidthOverThickness forKey:@"extrusionWidthOverThickness"];
}

- (void)saveSettingsToPreset:(NSMutableDictionary*)preset
{
	[preset setObject:[NSNumber numberWithFloat:self.layerThickness] forKey:@"layerThickness"];
	[preset setObject:[NSNumber numberWithFloat:self.extrusionWidthOverThickness] forKey:@"extrusionWidthOverThickness"];
}

- (void)loadSettingsFromPreset:(NSDictionary*)preset
{
	self.layerThickness = [[preset objectForKey:@"layerThickness"] floatValue];
	self.extrusionWidthOverThickness = [[preset objectForKey:@"extrusionWidthOverThickness"] floatValue];
}

+ (NSString*)localizedToolName
{
	return NSLocalizedStringFromTableInBundle(@"Slice", nil, [NSBundle bundleForClass:[self class]], @"Localized Display Name for Tool");
}

+ (NSString*)toolType
{
	// See P3DToolBase/P3DToolBase.h for other options
	return P3DTypeTool;
}

// The icon of this tool in the toolbox
// In not implemented, the default tool icon is used
/*+ (NSString*)iconName
{
	// If you return a custom image's name, be sure to
	// include the image file in this bundle's resources
	return @"Custom.png";
}*/

// The format of input data, this tool can handle 
// If the tool doesn't handle any input format (e.g. import tools, reading the data from disk)
// remove this method or return nil
+ (NSArray*)requiredInputFormats
{
	// See P3DToolBase/P3DToolBase.h for other options
	return [NSArray arrayWithObject:P3DFormatIndexedSTL];
}

// The format of the output data, provided by this tool
+ (NSString*)providesOutputFormat
{
	// See P3DToolBase/P3DToolBase.h for other options
	return P3DFormatLoops;
}

// Load the Settings GUI: Return the name of the settingsView nib
// If you choose to handle clicks by yourself (see customSettingsAction below), remove this method
- (NSString*)settingsViewNibName
{
	return @"SliceSettingsGUI";
}

+ (NSSet *)keyPathsForValuesAffectingExtrusionWidth {
    return [NSSet setWithObjects:@"layerThickness", @"extrusionWidthOverThickness", nil];
}

- (void)setExtrusionWidth:(float)value
{
	self.extrusionWidthOverThickness = value/layerThickness;
}

- (float)extrusionWidth
{
	return self.extrusionWidthOverThickness*layerThickness;
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
			if([self.inputProvider.outData isKindOfClass:[IndexedSTLModel class]])
			{
				self.toolInfo1 = NSLocalizedStringFromTableInBundle(@"Working\\U2026", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
				self.isWorking = YES;

	#if !__disable_gcd	
				dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
	#endif
					NSDate* startTime = [NSDate date];
					
					slicer.extrusionHeight = self.layerThickness;
					slicer.extrusionWidth = self.layerThickness*self.extrusionWidthOverThickness;
					
					P3DLoops* processedData = [slicer slice:(IndexedSTLModel*)self.inputProvider.outData];
					NSTimeInterval duration = -[startTime timeIntervalSinceNow];
					
					// Since output is possibly bound to GUI-Elements, the setter has to run in the main thread!
	#if !__disable_gcd	
					dispatch_async(dispatch_get_main_queue(), ^{
	#endif
						self.isWorking = NO;
						self.outData = processedData;
						self.toolInfo1 = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"%d Layers", nil, [NSBundle bundleForClass:[self class]], @"Localized Slice Tool Status Message"), processedData.layers.count];
						self.toolState = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Sliced after %@", nil, [NSBundle bundleForClass:[self class]], @"Localized Slice Tool Status Message"), [self timeStringForTimeInterval:duration]];
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
			self.toolState = NSLocalizedStringFromTableInBundle(@"Waiting", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
		}
	}
}

@end
