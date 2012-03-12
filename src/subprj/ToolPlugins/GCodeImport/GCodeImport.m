//
//  GCodeImport.m
//  GCodeImport
//
// Created by Eberhard Rensch on 29.2.2012
// Copyright 2010-12 Pleasant Software. All rights reserved.
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

#import "GCodeImport.h"
#import <dispatch/dispatch.h>
#import <P3DCore/P3DCore.h>
#import <P3DCore/GCodeShapeShifter.h>

static NSData* aliasDataForAbsolutePath(NSString* path)
{
	NSData* aliasData = nil;
	
	FSRef theRef;
	NSURL *absFileURL = [NSURL fileURLWithPath:path];
	BOOL fsrefGot = CFURLGetFSRef((CFURLRef)absFileURL, &theRef);
	if(fsrefGot)
	{
		AliasHandle aliasHandle;
		OSErr err = FSNewAlias(NULL, &theRef, &aliasHandle);
		if(err==noErr)
		{
			Size size = GetAliasSize(aliasHandle);
			HLock((Handle)aliasHandle);
			aliasData = [NSData dataWithBytes:*aliasHandle length:size];
			HUnlock((Handle)aliasHandle);
			DisposeHandle((Handle)aliasHandle);
		}
	}
	
	return aliasData;
}

static NSString* absolutePathForAliasData(NSData* aliasData)
{
	NSString* path = nil;
	
	AliasPtr aliasPtr = (AliasPtr)[aliasData bytes];
	AliasHandle aliasHandle;
	OSErr err =  PtrToHand(aliasPtr, (Handle*)&aliasHandle, [aliasData length]);
	if(err==noErr)
	{
		FSRef target;
		Boolean wasChanged=NO;
		err = FSResolveAlias(NULL, aliasHandle, &target, &wasChanged);
		if(err==noErr)
		{
			CFURLRef fileURL = CFURLCreateFromFSRef(NULL, &target);
			path = [(NSURL*)fileURL path];
			CFRelease(fileURL);
		}
		DisposeHandle((Handle)aliasHandle);
	}
	return path;
}


@implementation GCodeImport
@synthesize loadPolicy, sourceData, sourceFilePath, sourceFileUTI;

// Provide default values for all tool setting
+ (void)initialize
{
	NSDictionary *ddef = [NSDictionary dictionaryWithObjectsAndKeys:
						  [NSNumber numberWithInteger:0], @"loadPolicy",
						  nil];
	[GCodeImport registerDefaultPreset:ddef];
}

// Keep the GUI up-to-date
+ (NSSet *)keyPathsForValuesAffectingSourcePath {
    return [NSSet setWithObject:@"inData"];
}

+ (NSSet *)keyPathsForValuesAffectingOutData {
    return [NSSet setWithObject:@"shapeShifter.processedGCodeString"];
}

- (id) initWithHost:(id <SliceNDiceHost>)host;
{
	self = [super initWithHost:host];
	if (self != nil) {
		shapeShifter = [[GCodeShapeShifter alloc] init];
		shapeShifter.undoManager = host.undoManager;

		self.toolInfo1 = NSLocalizedStringFromTableInBundle(@"No Input File", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
		self.toolState = NSLocalizedStringFromTableInBundle(@"Waiting", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
	}
	return self;
}

- (id)initWithCoder:(NSCoder*)decoder
{
	self = [super initWithCoder:decoder];
	if(self)
	{
		shapeShifter = [decoder decodeObjectForKey:@"shapeShifter"];		
		loadPolicy = [decoder decodeIntForKey:@"loadPolicy"];
		sourceFilePath = absolutePathForAliasData([decoder decodeObjectForKey:@"inputFileAlias"]);
		if(self.outData)
		{
			[self.outData bind:@"gCodeString" toObject:shapeShifter withKeyPath:@"processedGCodeString" options:0];
		}
		if(loadPolicy == kLoadPolicySelfContained || sourceFilePath==nil)
			sourceData = [decoder decodeObjectForKey:@"sourceData"];
		else
			sourceData = [NSData dataWithContentsOfFile:sourceFilePath];
	//	self.isWorking=NO;
		[self processData];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder*)encoder
{
	[super encodeWithCoder:encoder];
	[encoder encodeObject:shapeShifter forKey:@"shapeShifter"];
	[encoder encodeInt:loadPolicy forKey:@"loadPolicy"];
	if(sourceFilePath)
		[encoder encodeObject:aliasDataForAbsolutePath(sourceFilePath) forKey:@"inputFileAlias"];
	if(loadPolicy!=kLoadPolicyLightWeight)
		[encoder encodeObject:sourceData forKey:@"sourceData"];
}

- (void)saveSettingsToPreset:(NSMutableDictionary*)preset
{
	[preset setObject:[NSNumber numberWithInteger:loadPolicy] forKey:@"loadPolicy"];
}

- (void)loadSettingsFromPreset:(NSDictionary*)preset
{
	self.loadPolicy = [[preset objectForKey:@"layerThickness"] integerValue];
}

- (void)finalize
{		
	if(self.outData)
	{
		[self.outData unbind:@"gCodeString"];
	}
	[super finalize];
}

- (void)setSliceNDiceHost:(id <SliceNDiceHost>)value
{
	[super setSliceNDiceHost:value];
	shapeShifter.undoManager = value.undoManager;
}

+ (NSString*)localizedToolName
{
	return NSLocalizedStringFromTableInBundle(@"Import GCode", nil, [NSBundle bundleForClass:[self class]], @"Localized Display Name for Tool");
}

+ (NSString*)toolType
{
	// See P3DToolBase/P3DToolBase.h for other options
	return P3DTypeImporter;
}

+ (NSString*)iconName
{
	return @"Import.png";
}

+ (NSArray*)requiredInputFormats
{
	return [NSArray arrayWithObjects:@"com.pleasantsoftware.uti.gcode", nil];
}

- (SEL)pathSetterForImportContentDataWithUTI:(NSString*)uti
{
    return @selector(setSourceFilePath:);
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
	return @"GCodeImportSettingsGUI";
}

- (IBAction)openGCodeFile:(id)sender
{	
	[[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:P3DToolSettingsWindowCloseNotification object:nil]];
	[self.sliceNDiceHost hideToolboxThenExecute:[NSBlockOperation blockOperationWithBlock:^{
		NSOpenPanel* panel = [NSOpenPanel openPanel];
		[panel setCanChooseDirectories:NO];
		[panel setAllowsMultipleSelection:NO];
		
		__block NSMutableArray* fileTypes = [[NSMutableArray alloc] init];
		[self.requiredInputFormats enumerateObjectsUsingBlock:^(id formatString, NSUInteger idx, BOOL *stop) {
			NSDictionary* utiDict = (NSDictionary*)NSMakeCollectable(UTTypeCopyDeclaration((CFStringRef)formatString));
			[fileTypes addObjectsFromArray:[[utiDict objectForKey:(id)kUTTypeTagSpecificationKey] objectForKey:(id)kUTTagClassFilenameExtension]];
            
		}];
		[panel setAllowedFileTypes:fileTypes];
		[panel beginSheetModalForWindow:[self.sliceNDiceHost windowForSheet] completionHandler:^(NSInteger result) {
			if(result==NSFileHandlingPanelOKButton)
			{
				self.sourceFilePath = [[[panel URLs] objectAtIndex:0] path];
			}
		}];
	}]];
}

- (void)setSourceFilePath:(NSString*)value
{
	[[sliceNDiceHost.undoManager prepareWithInvocationTarget:self] setSourceFilePath:sourceFilePath];
	sourceFilePath = value;
	
	self.sourceFileUTI = nil;
	[self.requiredInputFormats enumerateObjectsUsingBlock:^(id formatString, NSUInteger idx, BOOL *stop) {
		NSDictionary* utiDict = (NSDictionary*)NSMakeCollectable(UTTypeCopyDeclaration((CFStringRef)formatString));
		
		for(NSString* extension in [[utiDict objectForKey:(id)kUTTypeTagSpecificationKey] objectForKey:(id)kUTTagClassFilenameExtension])
		{
			if([[sourceFilePath pathExtension] compare:extension options:NSCaseInsensitiveSearch]==NSOrderedSame)
			{
				self.sourceFileUTI = formatString;
				*stop=YES;
				break;
			}
		}
	}];
	
	self.sourceData = [NSData dataWithContentsOfFile:sourceFilePath];
	[self processData];
}

- (IBAction)rotateAxisX:(id)sender
{
	[shapeShifter rotateBy90OnAxis:0];
}

- (IBAction)rotateAxisY:(id)sender
{
	[shapeShifter rotateBy90OnAxis:1];
}

- (IBAction)rotateAxisZ:(id)sender
{
	[shapeShifter rotateBy90OnAxis:2];
}

- (IBAction)centerObject:(id)sender
{
	[shapeShifter centerObject:self];
}

- (IBAction)zeroObject:(id)sender
{
	[shapeShifter zeroObject:self];
}

// Remove automatic "Recalculation"
- (IBAction)reprocess:(id)sender
{
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
		self.isWorking = YES;
		self.toolState = NSLocalizedStringFromTableInBundle(@"Working\\U2026", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
		
		if(self.outData)
		{
			[self.outData unbind:@"gCodeString"];
		}
		self.outData=nil;		
		
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			NSDate* startTime = [NSDate date];
			if(self.sourceData)
			{
				BOOL sucess=NO;
				NSString* gCodeString = nil;
				if([sourceFileUTI isEqual:@"com.pleasantsoftware.uti.gcode"])
				{
					gCodeString = [[NSString alloc] initWithData:self.sourceData encoding:NSUTF8StringEncoding];
				}
				
				if(gCodeString)
				{
                    sucess=YES;
                    NSTimeInterval duration = -[startTime timeIntervalSinceNow];
                    NSLog(@"It took %1.1f seconds to import the file", duration );
						
                    // Since output is possibly bound to GUI-Elements, the setter has to run in the main thread!
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.isWorking = NO;
                        self.toolInfo1 = [self.sourceFilePath lastPathComponent];			
                        if(self.abortRequested)
                        {
                            self.toolInfo2 = @"";
                            self.toolState = NSLocalizedStringFromTableInBundle(@"Aborted", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
                        }
                        else
                        {
                            [shapeShifter resetWithGCodeString:gCodeString];
                            GCode* theData = [[GCode alloc] initWithGCodeString:shapeShifter.processedGCodeString];
                            self.outData = theData;
								
                            [self.outData bind:@"gCodeString" toObject:shapeShifter withKeyPath:@"processedGCodeString" options:0];
                            self.toolInfo2 = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"%d Lines", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message"), theData.lineCount];
								self.toolState = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Imported in %@", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message"),[self timeStringForTimeInterval:duration]];
                        }
							
                        if(self.sliceNDiceHost.previewController)
                            [self.sliceNDiceHost.previewController.view setNeedsDisplay:YES];
                        
                        self.abortRequested = NO;
                    });
				}
				if(!sucess)
				{
					dispatch_async(dispatch_get_main_queue(), ^{
						self.isWorking = NO;
						self.toolInfo1 = [self.sourceFilePath lastPathComponent];			
						self.toolInfo2 = NSLocalizedStringFromTableInBundle(@"Error", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
						self.toolState =  NSLocalizedStringFromTableInBundle(@"Idle", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
					});
				}
			}
			else
			{
				dispatch_async(dispatch_get_main_queue(), ^{
					self.isWorking = NO;
					self.toolInfo1 =  NSLocalizedStringFromTableInBundle(@"No Input File", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
					self.toolInfo2 = @"";
					self.toolState =  NSLocalizedStringFromTableInBundle(@"Idle", nil, [NSBundle bundleForClass:[self class]], @"Localized Tool Status Message");
				});
			}
		});
	}
}

@end
