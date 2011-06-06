//
//  P3DToolBase.h
//  Pleasant3D
//
//  Created by Eberhard Rensch on 30.07.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// Tool Classification
extern NSString* const P3DTypeImporter;
extern NSString* const P3DTypeTool;
extern NSString* const P3DTypeExporter;
extern NSString* const P3DTypeHelper;
extern NSString* const P3DTypeUnknown;

// uti for internal drag and drop handling
extern NSString* const P3DToolUTI;

@protocol SliceNDiceHost;
@class ToolSettingsViewController, P3DProcessedObject;
@interface P3DToolBase : NSObject <NSCoding, NSPasteboardWriting, NSPasteboardReading> {
	id <SliceNDiceHost> sliceNDiceHost;
	
	BOOL isWorking;
	BOOL abortRequested;

	CGFloat toolProgress;
	
	NSString* toolInfo1;
	NSString* toolInfo2;
	NSString* toolState;
	
	P3DToolBase* inputProvider;
	P3DProcessedObject* _outData;
	
	NSViewController*	previewViewController;
	ToolSettingsViewController* settingsViewController;
	
	BOOL showPreview;
	
	NSMutableArray* toolPresets;
	NSMutableArray* toolPresetNames;
	NSUInteger selectedPresetIndex;
}
@property (retain) id <SliceNDiceHost>sliceNDiceHost;
@property (assign) BOOL isWorking;
@property (assign) BOOL abortRequested;

@property (readonly) BOOL showsProgress;
@property (assign) CGFloat toolProgress;

@property (copy) NSString* toolInfo1;
@property (copy) NSString* toolInfo2;
@property (copy) NSString* toolState;

@property (readonly) NSString* iconPath;

@property (readonly) NSString* localizedToolName;

@property (readonly) NSArray* requiredInputFormats;
@property (readonly) NSString* inputFormatNames;
@property (readonly) NSString* providesOutputFormat;
@property (readonly) NSString* outputFormatName;
@property (readonly) NSArray* possibleOutputFormats;

// The format of the data delivered by the previewData property
// The default implementation returns providesOutputFormat
@property (readonly) NSString* providesPreviewFormat;

@property (retain) P3DToolBase* inputProvider;
@property (retain) P3DProcessedObject* outData;

// Will be bound to the previewViewController.
// Default implementation returns outData if showPreview==YES
@property (readonly) id previewData; 

@property (assign) BOOL showPreview;

@property (readonly) NSImage* dataFlowButtonImage;
@property (readonly) NSImage* dataFlowButtonAltImage;

// The default implementation returns nil. In this
// case Pleasant3D calls customSettinsAction: on clicks
// on a tool panel
@property (readonly) NSString* settingsViewNibName;

// Return a subclass of ToolSettingsViewController
// The default implementation loads the nib file with the name
// returned by settingsViewNibName
// If overloaded, the controller should be allocated and initialized
// lazyly on first call. There's the settingsViewController iVar
// for caching the controller
@property (readonly) ToolSettingsViewController* settingsViewController;


// Return a subclass of NSViewController for the preview view
// The subclass should bind the previewData property to its content view
// The default implementation returns nil. In this case Pleasant3D will
// fall back to it's built in preview controllers for kMSFFormatIndexedSTL,
// kMSFFormatLoops or kMSFFormatGCode data
// If overloaded, the controller should be allocated and initialized
// lazyly on first call. There's the previewViewController iVar
// for caching the controller
@property (readonly) NSViewController* previewViewController;

// Preset Menu handling
@property (retain) NSArray* toolPresets;
@property (retain) NSArray* toolPresetNames;
@property (assign) NSUInteger selectedPresetIndex;

- (id) initWithHost:(id <SliceNDiceHost>)host;

+ (NSString*)uuid;

+ (NSString*)toolType;
+ (NSString*)iconName;

+ (BOOL) isExperimental;

+ (NSString*)localizedToolName;

+ (void)registerDefaultPreset:(NSDictionary*)preset;
- (void)saveSettingsToPreset:(NSMutableDictionary*)preset;
- (void)loadSettingsFromPreset:(NSDictionary*)preset;

// Define the data formats in this two class methods (not in the properties!)
// The properies are for convenience only and call these class methods
+ (NSArray*)requiredInputFormats;
+ (NSString*)providesOutputFormat;

// if the settingsViewController property returns nil (default implementation),
// Pleasant3D calls this action when the tool panel view is clicked on.
- (IBAction)customSettingsAction:(id)sender;

// This method is called exactly once after a tool is inserted in the tool bin
// (after a drag'n'drop action or loading a document)
- (void)prepareForDuty;

// The data processing
// This is automatically called when the user opt-clicks on a tool panel
- (IBAction)reprocessData:(id)sender; 
// This is called whenever the inputProviders outData changes (or in case of a manual request)
- (void)processData;
// This is automatically called when the user clicks on a tool panel, currently processing
- (IBAction)abortProcessData:(id)sender;

- (IBAction)removeToolFromToolBin:(id)sender;

// Validation for drag and drop handling
- (BOOL)canHandleInputFromTool:(P3DToolBase*)inputCandidate andProvideOutputForTool:(P3DToolBase*)outputConsumer;

- (void)setThreadSaveToolProgress:(CGFloat)progress;

// Helper method: Returns a formatted string for a timeInterval
- (NSString*)timeStringForTimeInterval:(NSTimeInterval)timeInterval;
@end
