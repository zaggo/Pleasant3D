//
//  ___PACKAGENAME___.m
//  ___PACKAGENAME___
//
//  Created by ___FULLUSERNAME___ on ___DATE___.
//  Copyright ___YEAR___ ___ORGANIZATIONNAME___. All rights reserved.
//
//  This plugin is based on Pleasant3D and the P3DCore.framework
//  created by Eberhard Rensch - Pleasant Software, Offenburg/Germany
//  Pleasant3D and the P3DCore.framework are Copyright 2009-___YEAR___ Pleasant Software.
//  All rights reserved.
//

#import "___PACKAGENAME___.h"
#import <dispatch/dispatch.h>

@implementation ___PACKAGENAME___
@synthesize sampleAttribute;

+ (void)initialize
{
	// Provide default values for all tool attributes and 
	// register them as the default preset for this tool
	NSDictionary *ddef = [NSDictionary dictionaryWithObjectsAndKeys:
						  [NSNumber numberWithFloat:1.23], @"sampleAttribute",
						  nil];
	[___PROJECTNAME___ registerDefaultPreset:ddef];
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
		sampleAttribute = [decoder decodeFloatForKey:@"sampleAttribute"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder*)encoder
{
	[super encodeWithCoder:encoder];
	
	[encoder encodeFloat:sampleAttribute forKey:@"sampleAttribute"];
}

#pragma mark Preset Handling

// Save all tool attributes to a given preset
- (void)saveSettingsToPreset:(NSMutableDictionary*)preset
{
	[preset setObject:[NSNumber numberWithFloat:self.sampleAttribute] forKey:@"sampleAttribute"];
}

// Read all tool attributes from a given preset
- (void)loadSettingsFromPreset:(NSDictionary*)preset
{
	self.sampleAttribute = [[preset objectForKey:@"sampleAttribute"] floatValue];
}

#pragma mark Tool Identity
+ (NSString*)localizedToolName
{
	return NSLocalizedStringFromTableInBundle(@"___PACKAGENAME___ Tool", nil, [NSBundle bundleForClass:[self class]], @"Localized Display Name for Tool");
}

+ (NSString*)toolType
{
	// See P3DToolBase/P3DToolBase.h for other options
	return P3DTypeTool;
}

// The format of input data, this tool can handle 
// If the tool doesn't handle any input format (e.g. import tools, reading the data from disk)
// remove this method or return nil
// If toolType is P3DToolImporter, return an array of file UTIs, the importer can read
+ (NSArray*)requiredInputFormats
{
	// See P3DToolBase/P3DFormatRegistration.h for other options
	return [NSArray arrayWithObject:P3DFormatAnyProcessedData];
}

// The format of the output data, provided by this tool
+ (NSString*)providesOutputFormat
{
	// See P3DToolBase/P3DFormatRegistration.h for other options
	return P3DFormatOutputSameAsInput;
}

/*
// This tool shows a progress bar
// If this property isn't defined or returns NO,
// the tool GUI shows an indeterminate progress indicator (spinner)
- (BOOL)showsProgress
{
	return YES;
}
*/

// Settings GUI: Return the name of the settingsView xib file (without file extension)
// If you choose to handle clicks on the tool panel by yourself (see customSettingsAction below), remove this method
- (NSString*)settingsViewNibName
{
	return @"___PROJECTNAME___SettingsGUI";
}

#pragma mark Data Processing

// This method is called whenever the inputProvider signals changes in its outData
// or when the user requested data processing (see - (IBAction)reprocessData:(id)sender)
- (void)processData
{	
	if(isWorking)
	{
		// If the tool is currently working, abort the current processing and try again later
		if(!abortRequested)
			[self abortProcessData:self];
		[self performSelector:@selector(processData) withObject:nil afterDelay:.5];
	}
	else
	{
		// Process the data: First step: invalidate the current out data
		self.outData=nil;
		
		// Only process data, if the input provider actually provides input data...
		if(self.inputProvider.outData)
		{
		
			// Update the GUI
			self.toolState = NSLocalizedStringFromTableInBundle(@"Working…", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
			
			self.isWorking = YES; // This automatically shows the progress indicator (see also showsProgress)
			
			// Do the actual work in background, so the GUI isn't blocked...
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				NSDate* startTime = [NSDate date];
					
				// DO THE WORK HERE
				// In most cases, it's a good idea to outsource the work to a separate kernel object
				/*
					// This sample code shows how to work with a progress bar in the tool GUI (see also self.showsProgress)
					for(NSInteger loop = 0; loop < 10; loop++)
					{
						// If processing needs some time, try to poll the abortRequested property from time to time
						// and abort your processing if it returns YES
						if(self.abortRequested)
							break;
							
						// Some fake work here...
						[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:self.sampleAttribute]];
						
						// Advance the progressbar. Since we're in a background thread, use the following
						// threadsave setter. The built-in progressbar runs always from 0. to 1.
						[self setThreadSaveToolProgress:(CGFloat)loop/10.f];
					}
				*/
				
				NSTimeInterval duration = -[startTime timeIntervalSinceNow];
				
				// Since output is likely bound to GUI-Elements, the outData setter has to run in the main thread!
				dispatch_async(dispatch_get_main_queue(), ^{
					self.isWorking = NO; // This implicitly updates the tool panel GUI (progress indicator)
					
					if(self.abortRequested)
					{
						self.toolInfo1 = @"";
						self.toolState = NSLocalizedStringFromTableInBundle(@"Aborted", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
					}
					else
					{
						self.outData = [self.inputProvider.outData copy]; // Never assign the input data directly to the output!
						self.toolInfo1 = @"";
						self.toolState = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Done after %@", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message"), [self timeStringForTimeInterval:duration]];
					}
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
