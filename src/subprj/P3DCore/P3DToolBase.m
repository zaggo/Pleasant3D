//
//  P3DToolBase.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 30.07.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
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
#import "P3DToolBase.h"
#import <dispatch/dispatch.h>
#import "ToolSettingsViewController.h"
#import "SliceNDiceHost.h"
#import "P3DProcessedObject.h"
#import "PSLog.h"
#import "IndexedSTLModel.h"
#import "P3DFormatRegistration.h"

// Tool Classification
NSString* const P3DTypeImporter=@"A";
NSString* const P3DTypeTool=@"B";
NSString* const P3DTypeExporter=@"C";
NSString* const P3DTypeHelper=@"D";
NSString* const P3DTypeUnknown=@"X";

// uti for internal drag and drop handling
NSString* const P3DToolUTI=@"com.pleasantsoftware.P3DTool";


@interface P3DToolBase (Private)
- (void)loadLastPreset;
- (void)setCurrentPreset:(NSString*)key;
@end

@implementation P3DToolBase
@synthesize isWorking, toolInfo1, toolInfo2, toolState, settingsViewController, previewViewController;
@synthesize inputProvider;
@synthesize outData=_outData;
@synthesize sliceNDiceHost, showPreview,  abortRequested, toolProgress, toolPresetNames, toolPresets, selectedPresetIndex;
@dynamic dataFlowButtonImage, dataFlowButtonAltImage, previewData, showsProgress, iconPath, localizedToolName, requiredInputFormats, inputFormatNames, providesOutputFormat, outputFormatName, providesPreviewFormat, possibleOutputFormats, settingsViewNibName, importedContentDataUTIs;

- (id)initWithHost:(id <SliceNDiceHost>)host
{
	self = [super init];
	if (self != nil) {
		self.sliceNDiceHost = host;
		self.toolInfo1 = NSLocalizedStringFromTableInBundle(@"Invalid", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
		self.toolState = NSLocalizedStringFromTableInBundle(@"Idle", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
		[self loadLastPreset]; // Init preset with last known preset
	}
	return self;
}

- (id)init
{
	self = [self initWithHost:nil];
	if (self != nil) {
	}
	return self;
}

- (id)initWithCoder:(NSCoder*)decoder
{
	self = [super init];
	if(self)
	{
		//_inData = [decoder decodeObjectForKey:@"inData"];
		
//		_outData = [decoder decodeObjectForKey:@"outData"];
//		if(_outData)
//			[_outData addObserver:self forKeyPath:@"uuid" options:nil context:nil];

		toolInfo1 = [decoder decodeObjectForKey:@"toolInfo1"];
		toolInfo2 = [decoder decodeObjectForKey:@"toolInfo2"];
		toolState = [decoder decodeObjectForKey:@"toolState"];
		
		NSString* presetId = [decoder decodeObjectForKey:@"presetId"];
		if(presetId)
			[self setCurrentPreset:presetId];
		else
			[self loadLastPreset]; // Init preset with last known preset
		// Don't save showPreview!
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	if(!sliceNDiceHost.encodeLightWeight) // Might be true when saving to disk in lightweight mode
	{
//		if([_inData isKindOfClass:[P3DProcessedObject class]])
//			[encoder encodeObject:[(P3DProcessedObject*)_inData uuid] forKey:@"inDataUUID"];
//		[encoder encodeObject:_outData forKey:@"outData"];
	}
	[encoder encodeObject:toolInfo1 forKey:@"toolInfo1"];
	[encoder encodeObject:toolInfo2 forKey:@"toolInfo2"];
	[encoder encodeObject:toolState forKey:@"toolState"];
	
	NSString* presetId = [[self.toolPresets objectAtIndex:self.selectedPresetIndex] objectForKey:@"presetKey"];
	if(presetId)
		[encoder encodeObject:presetId forKey:@"presetId"];

	// Don't load showPreview!
}

- (void)finalize
{
	if(inputProvider)
		[inputProvider removeObserver:self forKeyPath:@"outData.uuid"];
	[super finalize];
}

+ (NSSet *)keyPathsForValuesAffectingDataFlowButtonImage {
    return [NSSet setWithObjects:@"showPreview", @"outData", nil];
}

+ (NSSet *)keyPathsForValuesAffectingDataFlowButtonAltImage {
    return [NSSet setWithObject:@"outData"];
}

+ (NSSet *)keyPathsForValuesAffectingPreviewData {
    return [NSSet setWithObjects:@"showPreview", @"outData", nil];
}

+ (NSString*)localizedToolName
{
	return NSStringFromClass([self class]);
}

+ (BOOL)isExperimental
{
	return YES;
}

+ (NSString*)toolType
{
	return P3DTypeUnknown;
}

+ (NSString*)iconName
{
	return nil;
}

- (NSString*)iconPath
{
	NSString* iconPath=nil;
	NSString* name = [[self class] iconName];
	if(name)
		iconPath = [[NSBundle bundleForClass:[self class]] pathForResource:name ofType:nil];
	if(iconPath==nil)
		iconPath = [[NSBundle mainBundle] pathForResource:@"Tool" ofType:@"png"];
	return iconPath;
}

- (NSString*)localizedToolName
{
	return [[self class] localizedToolName];
}

- (NSString*)description
{
	return [[self class] localizedToolName];
}

+ (NSArray*)requiredInputFormats
{
	return nil;
}

- (NSArray*)requiredInputFormats
{
	return [[self class] requiredInputFormats];
}

+ (NSArray*)importedContentDataUTIs
{
    return nil;
}

- (NSArray*)importedContentDataUTIs
{
	return [[self class] importedContentDataUTIs];
}

- (SEL)pathSetterForImportContentDataWithUTI:(NSString*)uti
{
    return nil;
}

+ (NSString*)providesOutputFormat
{
	return nil;
}

- (NSString*)providesOutputFormat
{
	return [[self class] providesOutputFormat];
}

- (NSString*)providesPreviewFormat
{
	NSString* previewFormat = self.providesOutputFormat;
	if(self.outData && [self.outData isKindOfClass:[P3DProcessedObject class]])
		previewFormat = [(P3DProcessedObject*)self.outData dataFormat];
	return previewFormat;
}

- (NSString*)inputFormatNames
{
	if([[self class] requiredInputFormats]==nil)
		return NSLocalizedStringFromTableInBundle(@"None", nil, [NSBundle bundleForClass:[self class]], @"Localized fallback input format name (requiredInputFormat = nil)");
		
	__block NSMutableString* names = [[NSMutableString alloc] init];
	[self.requiredInputFormats enumerateObjectsUsingBlock:^(id format, NSUInteger idx, BOOL *stop) {
		[names appendFormat:@"%@\n", [[P3DFormatRegistration sharedInstance] localizedNameOfFormat:format]];
		}];
	if([names hasSuffix:@"\n"])
		[names deleteCharactersInRange:NSMakeRange([names length]-1, 1)];
	return names;
}

- (NSString*)outputFormatName
{
	if([self providesOutputFormat]==nil)
		return NSLocalizedStringFromTableInBundle(@"Unknown", nil, [NSBundle bundleForClass:[self class]], @"Localized fallback output format name (providesOutputFormat = nil)");
	return [[P3DFormatRegistration sharedInstance] localizedNameOfFormat:self.providesOutputFormat];
}

// This on gets called if the user clicks the toolpanel and settingsViewController returns nil
- (IBAction)customSettingsAction:(id)sender
{
}

//- (BOOL)validateInData:(id)value
//{
//	__block BOOL valid = NO;
//	
//	// If the requirement isn't a class name, default to NO, in this case the subclass needs to overwrite validateInData
//	// or don't call it anyway...
//	
//	[self.requiredInputFormats enumerateObjectsUsingBlock:^(id formatString, NSUInteger idx, BOOL *stop) {
//		if([formatString hasPrefix:kClassPrefix]) 
//		{
//			NSString* className = [formatString substringFromIndex:[kClassPrefix length]];
//			if(value==nil || [value isKindOfClass:NSClassFromString(className)])
//			{
//				valid = YES;
//				*stop = YES;
//			}
//		}
//	}];
//	return valid;
//}

- (NSArray*)possibleOutputFormats
{
	NSArray* possibleOutputFormats=nil;
	NSString* outputFormatString = self.providesOutputFormat;
	if([outputFormatString isEqualToString:P3DFormatOutputSameAsInput])
	{
		if(self.outData && [self.outData isKindOfClass:[P3DProcessedObject class]])
			possibleOutputFormats = [NSArray arrayWithObject:((P3DProcessedObject*)self.outData).dataFormat];
		else if(self.inputProvider)
			possibleOutputFormats = self.inputProvider.possibleOutputFormats;
		else
			possibleOutputFormats = self.requiredInputFormats;
	}
	else if(outputFormatString)
		possibleOutputFormats = [NSArray arrayWithObject:outputFormatString];
	return possibleOutputFormats;
}

- (BOOL)canHandleInputFromTool:(P3DToolBase*)inputCandidate andProvideOutputForTool:(P3DToolBase*)outputConsumer
{
	BOOL canHandle = YES;
	
	if(inputCandidate)
	{
		NSArray* providedInputFormats=inputCandidate.possibleOutputFormats;
		
		NSArray* toolCanHandleFormats = [self requiredInputFormats];
		
		if(toolCanHandleFormats==nil)
			canHandle = NO; // There is input, but this tool doesn't handle input...
		else if(providedInputFormats==nil && toolCanHandleFormats!=nil)
			canHandle = NO; // There is an inputProvider, providing no input, but this tool needs input...
		else
		{
			// There is an inputProvider, providing input, see, if provided data conforms to needed format
			P3DFormatRegistration* fr = [P3DFormatRegistration sharedInstance];
			__block BOOL formatMatchFound = NO;
			[providedInputFormats enumerateObjectsUsingBlock:^(id providedFormat, NSUInteger idx, BOOL *stop) {
				formatMatchFound = [fr format:providedFormat conformsToAnyFormatInArray:toolCanHandleFormats];
				*stop = formatMatchFound;
			}];
			
			if(!formatMatchFound)
				canHandle = NO;
		}
	}
			
	// If the input can be handled, check the output...		
	if(canHandle && outputConsumer)
	{
		NSArray* toolProvidedsFormats=[self possibleOutputFormats];
		if(toolProvidedsFormats.count==1 && [[toolProvidedsFormats objectAtIndex:0] isEqualToString:P3DFormatAnyProcessedData] && inputCandidate)
			toolProvidedsFormats = inputCandidate.possibleOutputFormats;
		NSArray* consumerCanHandleFormats = [outputConsumer requiredInputFormats];
		
		if(consumerCanHandleFormats==nil)
			canHandle = NO; 
		else if(toolProvidedsFormats==nil && consumerCanHandleFormats!=nil)
			canHandle = NO;
		else
		{
			P3DFormatRegistration* fr = [P3DFormatRegistration sharedInstance];
			__block BOOL formatMatchFound = NO;
			[toolProvidedsFormats enumerateObjectsUsingBlock:^(id providedFormat, NSUInteger idx, BOOL *stop) {
				formatMatchFound = [fr format:providedFormat conformsToAnyFormatInArray:consumerCanHandleFormats];
				*stop = formatMatchFound;
			}];
			
			if(!formatMatchFound)
				canHandle = NO;
		}
	}
	return canHandle;
}

- (void)setInputProvider:(P3DToolBase*)value
{
	if(inputProvider)
		[inputProvider removeObserver:self forKeyPath:@"outData.uuid"];
	inputProvider = value;
	if(inputProvider)
		[inputProvider addObserver:self forKeyPath:@"outData.uuid" options:0 context:nil];
	else
		[[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:P3DToolSettingsWindowCloseNotification object:self]];

	[self processData];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if(object==inputProvider && [keyPath isEqualToString:@"outData.uuid"])
	{
		[self processData];
	}
}


- (id)previewData
{
	if(self.showPreview)
		return self.outData;
	return nil;
}


- (NSImage*)dataFlowButtonImage
{
	if(showPreview) 
	{
		if(self.outData)
			return [NSImage imageNamed:@"dataFlowButton_Yes_Preview.pdf"];
		else
			return [NSImage imageNamed:@"dataFlowButton_No_Preview.pdf"];
	}
	else
	{
		if(self.outData)
			return [NSImage imageNamed:@"dataFlowButton_Yes_Forward.pdf"];
		else
			return [NSImage imageNamed:@"dataFlowButton_No_Forward.pdf"];
	}
}

- (NSImage*)dataFlowButtonAltImage
{
	if(self.outData)
		return [NSImage imageNamed:@"dataFlowButton_Yes_Intermed.pdf"];
	else
		return [NSImage imageNamed:@"dataFlowButton_No_Intermed.pdf"];
}

- (NSString*)settingsViewNibName
{
	return nil;
}

- (ToolSettingsViewController*)settingsViewController
{
	if(settingsViewController==nil && self.settingsViewNibName!=nil)
	{
		settingsViewController = [[ToolSettingsViewController alloc] initWithNibName:self.settingsViewNibName bundle:[NSBundle bundleForClass:[self class]]];
		[settingsViewController setRepresentedObject:self];
	}
	return settingsViewController;
}

- (void)setShowPreview:(BOOL)value
{
	if(showPreview!=value)
	{
		showPreview=value;
		if(showPreview)
		{
			NSViewController* pvc=[self previewViewController];
			if(pvc==nil)
			{
				// No custom preview controller, try to find a default preview controller
				pvc = [self.sliceNDiceHost defaultPreviewControllerForTool:self];
			}
			
			self.sliceNDiceHost.previewController = pvc;
		}
		else
			self.sliceNDiceHost.previewController = nil;
	}
}

- (void)prepareForDuty
{
//	[self loadLastPreset];
}

- (void)setIsWorking:(BOOL)value
{
	isWorking = value;
	if(isWorking)
		self.abortRequested = NO;
	else 
	{
		// Reset the progressbar
		// Delay the reset to after the GUI has updates...
		dispatch_async(dispatch_get_main_queue(), ^{
			self.toolProgress = 0.;
			});
	}
}

- (BOOL)showsProgress
{
	return NO;
}

- (IBAction)dataFlowButtonPressed:(id)sender
{
	if(!showPreview)
		[self.sliceNDiceHost disableOtherPreviews:self];
	self.showPreview = !self.showPreview;
	NSLog(@"previewbutton in %@ pressed, will be %@", NSStringFromClass([self class]), showPreview?@"Visible":@"Hidden");
}

- (IBAction)reprocessData:(id)sender
{
	[self processData];
}

- (void)processData
{
}

- (IBAction)abortProcessData:(id)sender
{
	if(isWorking && !abortRequested)
	{
		self.toolState = NSLocalizedStringFromTableInBundle(@"Aborting…", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
		abortRequested = YES;
	}
}

// Currently used from the panel context menu
- (IBAction)removeToolFromToolBin:(id)sender
{
	[self.sliceNDiceHost removeToolFromToolBin:self];
}

#pragma mark Preset Handling
+ (NSString*)uuid
{
	NSString* uuid=nil;
	CFUUIDRef uuidRef = CFUUIDCreate(kCFAllocatorDefault);
	CFStringRef strRef = CFUUIDCreateString(kCFAllocatorDefault, uuidRef);
	if(strRef)
	{
		uuid = [NSString stringWithString:(NSString*)strRef];
		CFRelease(strRef);
	}
	if(uuidRef)
		CFRelease(uuidRef);
	return uuid;
}

+ (NSString*)presetsPath
{
	NSString* presetsPath=nil;
	
	NSString* toolIdentifier = [[[NSBundle bundleForClass:[self class]] infoDictionary] objectForKey:@"CFBundleIdentifier"];
	NSError* error;
	NSFileManager* fm = [NSFileManager defaultManager];
	NSBundle* mainBundle = [NSBundle mainBundle];
	NSString* appName = [[mainBundle infoDictionary] objectForKey:@"CFBundleName"];
	NSArray* librarySearchPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	if(librarySearchPaths.count>0)
	{
		NSString* librarySearchPath=[librarySearchPaths objectAtIndex:0];
		presetsPath = [[[librarySearchPath stringByAppendingPathComponent:appName] stringByAppendingPathComponent:@"Presets"]stringByAppendingPathComponent:toolIdentifier];
		if(![fm fileExistsAtPath:presetsPath])
			[fm createDirectoryAtPath:presetsPath withIntermediateDirectories:YES attributes:nil error:&error];
	}
	
	return presetsPath;
}

+ (void)registerDefaultPreset:(NSDictionary*)preset
{
	NSMutableDictionary* def = [NSMutableDictionary dictionaryWithDictionary:preset];
	[def setObject:NSLocalizedStringFromTableInBundle(@"Default", nil, [NSBundle bundleForClass:[self class]], @"PresetMenu Default item name") forKey:@"presetName"];
	[def setObject:@"default" forKey:@"presetKey"];
	
	NSString* presetsPath = [[self class] presetsPath];
	if(presetsPath)
	{
		NSString* defaultPresetPath = [presetsPath stringByAppendingPathComponent:[def objectForKey:@"presetName"]];
		if(![[NSFileManager defaultManager] fileExistsAtPath:defaultPresetPath])
			[def writeToFile:defaultPresetPath atomically:YES];
	}
}

- (void)setCurrentPreset:(NSString*)key
{
	__block NSInteger foundPreset = -1;
	[self.toolPresets enumerateObjectsUsingBlock:^(id preset, NSUInteger idx, BOOL *stop) {
		if([preset isKindOfClass:[NSInvocation class]])
			*stop=YES;
		else if([[(NSDictionary*)preset objectForKey:@"presetKey"] isEqualToString:key])
		{
			foundPreset = idx;
			*stop=YES;
		}	
	}];
	
	if(foundPreset<0)
	{
		[self.toolPresets enumerateObjectsUsingBlock:^(id preset, NSUInteger idx, BOOL *stop) {
			if([preset isKindOfClass:[NSInvocation class]])
				*stop=YES;
			else if([[(NSDictionary*)preset objectForKey:@"presetKey"] isEqualToString:@"default"])
			{
				foundPreset = idx;
				*stop=YES;
			}	
		}];
	}
	
	if(foundPreset>=0)
	{
		self.selectedPresetIndex = foundPreset;
	}
}

- (void)loadLastPreset
{
	__block NSString* defaultPresetKey = @"default";
	
	NSString* toolIdentifier = [[[NSBundle bundleForClass:[self class]] infoDictionary] objectForKey:@"CFBundleIdentifier"];
	NSString* lastPresetKey = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"lastPreset-%@",toolIdentifier]];
	
	// Check for key
	[self.toolPresets enumerateObjectsUsingBlock:^(id preset, NSUInteger idx, BOOL *stop) {
		if([preset isKindOfClass:[NSInvocation class]])
			*stop=YES;
		else if([[(NSDictionary*)preset objectForKey:@"presetKey"] isEqualToString:lastPresetKey])
		{
			defaultPresetKey = lastPresetKey;
			*stop=YES;
		}	
	}];
	
	if(defaultPresetKey)
		[self setCurrentPreset:defaultPresetKey];
}


- (void)saveSettingsToPreset:(NSMutableDictionary*)preset
{
}

- (void)loadSettingsFromPreset:(NSDictionary*)preset
{
	NSLog(@"loadSettingsFromPreset (%@)", [preset objectForKey:@"presetName"]);
}

- (IBAction)savePreset:(id)sender
{
	NSMutableDictionary* currentPreset = [self.toolPresets objectAtIndex:selectedPresetIndex];
	NSString* filePath = [currentPreset objectForKey:@"filePath"];
	[self saveSettingsToPreset:currentPreset];
	[currentPreset removeObjectForKey:@"filePath"];
	if(![currentPreset writeToFile:filePath atomically:YES])
	{
		PSErrorLog(@"Couldn't save preset!");
		// TODO: Alert
	}
	[currentPreset setObject:filePath forKey:@"filePath"];

	dispatch_async(dispatch_get_main_queue(), ^{
		self.selectedPresetIndex = selectedPresetIndex;
	});
}

- (IBAction)savePresetAs:(id)sender
{
	NSString* presetsPath = [[self class] presetsPath];
	if(presetsPath)
	{
		NSMutableDictionary* currentPreset = [NSMutableDictionary dictionaryWithDictionary:[self.toolPresets objectAtIndex:selectedPresetIndex]];
		[self saveSettingsToPreset:currentPreset];
		
		NSSavePanel* savePanel = [[NSSavePanel alloc] init];
		[savePanel setCanCreateDirectories:NO];
		[savePanel setDirectoryURL:[NSURL fileURLWithPath:presetsPath]];
		[savePanel setMessage:[NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Save Preset for %@", nil, [NSBundle bundleForClass:[self class]], @"Preset SaveAs Prompt template"), self.localizedToolName]];
		[savePanel setNameFieldStringValue:[currentPreset objectForKey:@"presetName"]];
		
		//NSString* presetKey = [currentPreset objectForKey:@"presetKey"];
		
		[savePanel beginWithCompletionHandler:^(NSInteger result) {
			if(result==NSFileHandlingPanelOKButton)
			{
				NSURL* saveTo = [savePanel URL];
				NSString* newPresetKey = [[self class] uuid];
				NSDictionary* overwrittenPreset = [NSDictionary dictionaryWithContentsOfURL:saveTo];
				if(overwrittenPreset && [[overwrittenPreset objectForKey:@"presetKey"] isEqualToString:@"default"])
					newPresetKey = @"default";
				[currentPreset setObject:newPresetKey forKey:@"presetKey"];
				[currentPreset setObject:[savePanel nameFieldStringValue] forKey:@"presetName"];
				[currentPreset removeObjectForKey:@"filePath"];
				if([currentPreset writeToURL:saveTo atomically:YES])
				{
					// Force reload
					self.toolPresets=nil;
					self.toolPresetNames=nil;
					
					// Fallback to the previous selection
					dispatch_async(dispatch_get_main_queue(), ^{
						[self setCurrentPreset:newPresetKey];
					});
				}
				else
				{
					PSErrorLog(@"Couldn't save preset!");
					//TODO: Alert
					// Fallback to the previous selection
					dispatch_async(dispatch_get_main_queue(), ^{
						self.selectedPresetIndex = selectedPresetIndex;
					});
				}
			}
			else
			{
				// Fallback to the previous selection
				dispatch_async(dispatch_get_main_queue(), ^{
					self.selectedPresetIndex = selectedPresetIndex;
				});
			}
		}];
	}
	else
	{
		PSErrorLog(@"No Presets path!");
		// Fallback to the previous selection
		dispatch_async(dispatch_get_main_queue(), ^{
			self.selectedPresetIndex = selectedPresetIndex;
		});
	}
}

- (IBAction)deletePreset:(id)sender
{
	NSMutableDictionary* currentPreset = [NSMutableDictionary dictionaryWithDictionary:[self.toolPresets objectAtIndex:selectedPresetIndex]];
	if(![[currentPreset objectForKey:@"presetKey"] isEqualToString:@"default"])
	{
		// TODO: delete file
		
		// Force reload
		self.toolPresets=nil;
		self.toolPresetNames=nil;
		
		// Fallback to the previous selection
		dispatch_async(dispatch_get_main_queue(), ^{
			[self setCurrentPreset:@"default"];
		});
	}
	else
	{
		// TODO: Alert
		
		// Fallback to the previous selection
		dispatch_async(dispatch_get_main_queue(), ^{
			self.selectedPresetIndex = selectedPresetIndex;
		});
	}
}

- (void)setSelectedPresetIndex:(NSUInteger)value
{
	if(value<self.toolPresets.count)
	{
		id selection = [self.toolPresets objectAtIndex:value];
		if([selection isKindOfClass:[NSInvocation class]])
		{
			[[self.settingsViewController.view window] makeFirstResponder:nil]; // Commit any current changes
			[(NSInvocation*)selection invokeWithTarget:self];
		}
		else
		{
			selectedPresetIndex = value;
			
			NSString* toolIdentifier = [[[NSBundle bundleForClass:[self class]] infoDictionary] objectForKey:@"CFBundleIdentifier"];
			[[NSUserDefaults standardUserDefaults] setObject:[selection objectForKey:@"presetKey"] forKey:[NSString stringWithFormat:@"lastPreset-%@",toolIdentifier]];
			
			[self loadSettingsFromPreset:selection];
			[self reprocessData:self];
		}
	}
}

- (NSArray*)toolPresets
{
	if(toolPresets==nil)
	{
		toolPresets = [[NSMutableArray alloc] init];
		toolPresetNames = [[NSMutableArray alloc] init];
		
		NSString* presetsPath = [[self class] presetsPath];
		if(presetsPath)
		{
			NSError* error;
			NSArray* candidates = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:presetsPath error:&error];
			for(NSString* currPresetPath in candidates)
			{
				// we found a preset, add it to the list
				NSString* path = [presetsPath stringByAppendingPathComponent:currPresetPath];
				NSMutableDictionary* preset = [NSMutableDictionary dictionaryWithContentsOfFile:path];
				if(preset && [(NSString*)[preset objectForKey:@"presetName"] length]>0)
				{
					[preset setObject:path forKey:@"filePath"];
					[toolPresets addObject:preset];
				}
			}
		}
		[toolPresets sortUsingComparator:^(id obj1, id obj2) {
			return [(NSString*)[obj1 objectForKey:@"presetName"] compare:[obj2 objectForKey:@"presetName"] options:NSCaseInsensitiveSearch];
		}];
		
		[toolPresets enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			[toolPresetNames addObject:[obj objectForKey:@"presetName"]];
		}];
		
		[toolPresetNames addObject:NSLocalizedStringFromTableInBundle(@"Save Preset", nil, [NSBundle bundleForClass:[self class]], @"PresetMenu item")];
		NSMethodSignature* savePresetSig = [self methodSignatureForSelector:@selector(savePreset:)];
		NSInvocation* savePresetInvocation = [NSInvocation invocationWithMethodSignature:savePresetSig];
		[savePresetInvocation setSelector:@selector(savePreset:)];
		[toolPresets addObject:savePresetInvocation];
		[toolPresetNames addObject:NSLocalizedStringFromTableInBundle(@"Save Preset As…", nil, [NSBundle bundleForClass:[self class]], @"PresetMenu item")];
		NSMethodSignature* savePresetAsSig = [self methodSignatureForSelector:@selector(savePresetAs:)];
		NSInvocation* savePresetAsInvocation = [NSInvocation invocationWithMethodSignature:savePresetAsSig];
		[savePresetAsInvocation setSelector:@selector(savePresetAs:)];
		[toolPresets addObject:savePresetAsInvocation];
		[toolPresetNames addObject:NSLocalizedStringFromTableInBundle(@"Delete Preset", nil, [NSBundle bundleForClass:[self class]], @"PresetMenu item")];
		NSMethodSignature* deletePresetSig = [self methodSignatureForSelector:@selector(deletePreset:)];
		NSInvocation* deletePresetInvocation = [NSInvocation invocationWithMethodSignature:deletePresetSig];
		[deletePresetInvocation setSelector:@selector(deletePreset:)];
		[toolPresets addObject:deletePresetInvocation];
	}
	return toolPresets;
}

- (NSArray*)toolPresetNames
{
	if(toolPresetNames==nil)
		[self toolPresets];
	return toolPresetNames;
}

#pragma mark NSPasteboardWriting
- (NSArray *)writableTypesForPasteboard:(NSPasteboard *)pasteboard {
    static NSArray *writableTypes = nil;
	
    if (!writableTypes) {
        writableTypes = [[NSArray alloc] initWithObjects:P3DToolUTI, nil];
    }
    return writableTypes;
}

- (id)pasteboardPropertyListForType:(NSString *)type {
	
	id plist = nil;
    if ([type isEqualToString:P3DToolUTI]) {
        plist = [NSKeyedArchiver archivedDataWithRootObject:self];
    }
	return plist;
}

+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard {
	
    static NSArray *readableTypes = nil;
    if (!readableTypes) {
        readableTypes = [[NSArray alloc] initWithObjects:P3DToolUTI, nil];
    }
    return readableTypes;
}

+ (NSPasteboardReadingOptions)readingOptionsForType:(NSString *)type pasteboard:(NSPasteboard *)pboard {
	NSPasteboardReadingOptions options = 0;
    if ([type isEqualToString:P3DToolUTI]) {
        options = NSPasteboardReadingAsKeyedArchive;
    }
    return options;
}

- (void)setThreadSaveToolProgress:(CGFloat)progress
{
	if(progress != self.toolProgress)
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			self.toolProgress = progress;
		});
	}
}

- (NSString*)timeStringForTimeInterval:(NSTimeInterval)timeInterval
{
	NSString* formatted;
	if(timeInterval<1.)	// Show ms
		formatted = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"%d ms", nil, [NSBundle bundleForClass:[self class]], @"Localized time formatting string template"), (NSInteger)(timeInterval*1000.)];
	else if(timeInterval<60.) // Show seconds
	{
		NSNumberFormatter* formatter = [[NSNumberFormatter alloc] init];
		[formatter setMinimumIntegerDigits:1];
		[formatter setMaximumFractionDigits:2];
		[formatter setMinimumFractionDigits:2];
		formatted = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"%@ s", nil, [NSBundle bundleForClass:[self class]], @"Localized time formatting string template"), [formatter stringFromNumber:[NSNumber numberWithFloat:timeInterval]]];
	}
	else
	{
		NSNumberFormatter* formatter = [[NSNumberFormatter alloc] init];
		[formatter setMinimumIntegerDigits:1];
		[formatter setMaximumFractionDigits:1];
		[formatter setMinimumFractionDigits:1];
		formatted = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"%@ m", nil, [NSBundle bundleForClass:[self class]], @"Localized time formatting string template"), [formatter stringFromNumber:[NSNumber numberWithFloat:timeInterval/60.]]];
	}
	return formatted;
}

@end
