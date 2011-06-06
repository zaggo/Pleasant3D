//
//  FileSaver.m
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

#import "FileSaver.h"
#import <dispatch/dispatch.h>

@implementation FileSaver
@synthesize selectedTargetPath, targetPath, manualSave;

// Provide default values for all tool setting
+ (void)initialize
{
	NSDictionary *ddef = [NSDictionary dictionaryWithObjectsAndKeys:
						  [NSNumber numberWithInt:0], @"selectedTargetPath",
						  [NSNumber numberWithBool:NO], @"manualSave",
		nil];
	[FileSaver registerDefaultPreset:ddef];
}

- (id) initWithHost:(id <SliceNDiceHost>)host;
{
	self = [super initWithHost:host];
	if (self != nil) {
		self.toolInfo1 = NSLocalizedStringFromTableInBundle(@"No Input", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
		self.toolState = NSLocalizedStringFromTableInBundle(@"Waiting", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
		
		[(id)sliceNDiceHost addObserver:self forKeyPath:@"projectPath" options:NSKeyValueObservingOptionNew context:nil];
	}
	return self;
}

- (id)initWithCoder:(NSCoder*)decoder
{
	self = [super initWithCoder:decoder];
	if(self)
	{
		self.selectedTargetPath = [decoder decodeIntForKey:@"selectedTargetPath"];
		self.targetPath = [decoder decodeObjectForKey:@"targetPath"];
		self.manualSave = [decoder decodeBoolForKey:@"manualSave"];

		[(id)sliceNDiceHost addObserver:self forKeyPath:@"projectPath" options:NSKeyValueObservingOptionNew context:nil];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder*)encoder
{
	[super encodeWithCoder:encoder];

	[encoder encodeInt:selectedTargetPath forKey:@"selectedTargetPath"];
	[encoder encodeObject:targetPath forKey:@"targetPath"];
	[encoder encodeBool:manualSave forKey:@"manualSave"];
}

- (void)saveSettingsToPreset:(NSMutableDictionary*)preset
{
	[preset setObject:[NSNumber numberWithInt:self.selectedTargetPath] forKey:@"selectedTargetPath"];
	[preset setObject:self.targetPath forKey:@"targetPath"];
	[preset setObject:[NSNumber numberWithBool:self.manualSave] forKey:@"manualSave"];
}

- (void)loadSettingsFromPreset:(NSDictionary*)preset
{
	self.selectedTargetPath = [[preset objectForKey:@"selectedTargetPath"] intValue];
	self.targetPath = [preset objectForKey:@"targetPath"];
	self.manualSave = [[preset objectForKey:@"manualSave"] boolValue];
}



- (void)finalize
{
	[(id)sliceNDiceHost removeObserver:self];
	[super finalize];
}

- (void)setSliceNDiceHost:(id <SliceNDiceHost>)value
{
	if(sliceNDiceHost)
		[(id)sliceNDiceHost removeObserver:self];
	[super setSliceNDiceHost:value];
	[(id)sliceNDiceHost addObserver:self forKeyPath:@"projectPath" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if([keyPath isEqualToString:@"projectPath"])
	{
		[self saveFile:self];
	}
}

+ (NSString*)localizedToolName
{
	return NSLocalizedStringFromTableInBundle(@"FileSaver", nil, [NSBundle bundleForClass:[self class]], @"Localized Display Name for Tool");
}

+ (NSString*)toolType
{
	// See P3DToolBase/P3DToolBase.h for other options
	return P3DTypeExporter;
}

// The icon of this tool in the toolbox
// In not implemented, the default tool icon is used
+ (NSString*)iconName
{
	// If you return a custom image's name, be sure to
	// include the image file in this bundle's resources
	return @"Export.png";
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
	return @"FileSaverSettingsGUI";
}

+ (NSSet *)keyPathsForValuesAffectingTargetPath {
    return [NSSet setWithObjects:@"selectedTargetPath", nil];
}

- (NSString*)targetPath
{
	NSString* result = targetPath;
	switch(selectedTargetPath)
	{
		case 0:
			result = [[[sliceNDiceHost projectPath] stringByDeletingPathExtension] stringByAppendingPathExtension:@"gcode"];
			break;
		case 1:
			result = [[[[sliceNDiceHost projectPath] lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"gcode"];
			if(result)
				result = [targetPath stringByAppendingPathComponent:result];
			break;
	}
	return result;
}

- (IBAction)saveFile:(id)sender
{
	NSError* error=nil;

	if(self.outData==nil)
		self.toolInfo2 = NSLocalizedStringFromTableInBundle(@"No Data", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
	else if(self.targetPath)
	{
		if([((GCode*)self.outData).gCodeString writeToFile:self.targetPath atomically:YES encoding:NSUTF8StringEncoding error:&error])
			self.toolInfo2 = NSLocalizedStringFromTableInBundle(@"Saved", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
		else
		{
			// TODO: Handle error message from error var
			self.toolInfo2 = NSLocalizedStringFromTableInBundle(@"Write error", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
		}
	}
	else
		self.toolInfo2 = NSLocalizedStringFromTableInBundle(@"Project not saved", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");	
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
			self.toolInfo1 = NSLocalizedStringFromTableInBundle(@"Saving\\U2026", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
			self.isWorking = YES;

#if !__disable_gcd	
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
#endif
				NSDate* startTime = [NSDate date];
				
				BOOL fileSaved = NO;
				NSError* error=nil;
				
				NSString* path = self.targetPath;
				
				if(!self.manualSave && path)
					fileSaved = [self.inputProvider.outData writeToFile:path error:&error];
									
				NSTimeInterval duration = -[startTime timeIntervalSinceNow];
				
				// Since output is possibly bound to GUI-Elements, the setter has to run in the main thread!
#if !__disable_gcd	
				dispatch_async(dispatch_get_main_queue(), ^{
#endif
					self.isWorking = NO;
					if(!self.manualSave)
					{
						if(path)
						{
							if(fileSaved)
								self.toolInfo2 = NSLocalizedStringFromTableInBundle(@"Saved", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
							else
							{
								// TODO: Handle error message from error var
								self.toolInfo2 = NSLocalizedStringFromTableInBundle(@"Write error", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
							}
						}
						else
							self.toolInfo2 = NSLocalizedStringFromTableInBundle(@"Project not saved", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
					}
					else
						self.toolInfo2 = NSLocalizedStringFromTableInBundle(@"Manual save", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
					
					self.outData = self.inputProvider.outData; // No copy, the data is never changed inside
					self.toolInfo1 = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"%d Bytes", nil, [NSBundle bundleForClass:[self class]], @"Localized Slice Tool Status Message"), self.inputProvider.outData.byteLength];
					self.toolState = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Saved after %@", nil, [NSBundle bundleForClass:[self class]], @"Localized Slice Tool Status Message"), [self timeStringForTimeInterval:duration]];
#if !__disable_gcd	
				});
			});
#endif
		}
		else
		{
			self.toolInfo1 = NSLocalizedStringFromTableInBundle(@"No Input", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
			self.toolInfo2 = nil
			;
			self.toolState = NSLocalizedStringFromTableInBundle(@"Waiting", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
		}
	}
}
@end
