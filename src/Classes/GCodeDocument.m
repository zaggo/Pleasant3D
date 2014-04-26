//
//  GCodeDocument.m
//  PleasantSTL
//
//  Created by Eberhard Rensch on 18.10.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
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

#import "GCodeDocument.h"
#import <P3DCore/NSArray+GCode.h>
#import <P3DCore/P3DCore.h>
#import "GCodeView.h"
#import "P3DMachiningController.h"

@implementation GCodeDocument
{
    NSArray* _gCodeLineScanners;
	
	Vector3* _cornerHigh;
	Vector3* _cornerLow;
	CGFloat _extrusionWidth;
	CGFloat _scale;
	Vector2d* _scaleCornerHigh;
	Vector2d* _scaleCornerLow;
    
    NSTimer* _changesCommitTimer;
}

#pragma mark - Document Life Cycle
- (NSString *)windowNibName {
    // Implement this to return a nib to load OR implement -makeWindowControllers to manually create your controllers.
    return @"GCodeDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];
    [_openGL3DPrinterView bind:@"currentMachine" toObject:self withKeyPath:@"currentMachine" options:nil];
    [self setupParameterView];
    [self addObserver:self forKeyPath:@"selectedMachineUUID" options:NSKeyValueObservingOptionNew context:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(currentMachineSettingsChanged:) name:P3DCurrentMachineSettingsChangedNotifiaction object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self removeObserver:self forKeyPath:@"selectedMachineUUID"];
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	self.rawGCode = nil;
	if([typeName isEqualToString:@"com.pleasantsoftware.uti.gcode"])
		self.rawGCode = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    if (_rawGCode==nil && outError != nil )
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
    
    return (_rawGCode!=nil);
}

- (BOOL)canPrintDocument
{
	return self.currentMachine.canPrint;
}

- (IBAction)printDocument:(id)sender
{
    if(self.currentMachine.canPrint) {
        P3DMachiningController* printer = [[P3DMachiningController alloc] initWithMachinableDocument:self];
        [printer showPrintDialog];
    }
}

#pragma mark - Observers
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if([keyPath isEqualToString:@"selectedMachineUUID"]) {
		[self setupParameterView];
        [self parseGCodeString:_rawGCode];
    }
}

- (void)currentMachineSettingsChanged:(NSNotification*)notification
{
    [self parseGCodeString:_rawGCode];
}

- (void)textDidChange:(NSNotification *)aNotification
{
    [_changesCommitTimer invalidate];
    _changesCommitTimer = [NSTimer scheduledTimerWithTimeInterval:2. target:self selector:@selector(commitChanges:) userInfo:[aNotification object] repeats:NO];
}

- (void)commitChanges:(NSTimer*)timer
{
    NSTextView* tv = (NSTextView*)[timer userInfo];
    self.rawGCode = [[tv textStorage] string];
}


#pragma mark - Service

- (void)setupParameterView
{
    NSRect viewRect;
    switch(self.currentMachine.gcodeStyle) {
        case kGCodeStyleMill:
            viewRect = _millParameters.frame;
            viewRect.origin.x = NSWidth(_mainContainerView.frame)-NSWidth(viewRect);
            viewRect.origin.y = 0.f;
            viewRect.size.height = NSHeight(_mainContainerView.frame);
            _millParameters.frame = viewRect;
            [_parameters3DPrint removeFromSuperview];
            [_mainContainerView addSubview:_millParameters];
            break;
        default: // 3DPrinter
            viewRect = _parameters3DPrint.frame;
            viewRect.origin.x = NSWidth(_mainContainerView.frame)-NSWidth(viewRect);
            viewRect.origin.y = 0.f;
            viewRect.size.height = NSHeight(_mainContainerView.frame);
            _parameters3DPrint.frame = viewRect;
            [_millParameters removeFromSuperview];
            [_mainContainerView addSubview:_parameters3DPrint];
            break;
    }
}

- (void)parseGCodeString:(NSString*)gcodeString
{
    self.calculatingPreview=YES;
    if(_rawGCode) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            P3DParsedGCodeBase* parsedGCode;
            switch(self.currentMachine.gcodeStyle) {
                case kGCodeStyle3DPrinter:
                    parsedGCode = [[P3DParsedGCodePrinter alloc] initWithGCodeString:gcodeString printer:(P3DPrinterDriverBase*)self.currentMachine];
                    break;
                default:
                    parsedGCode = [[P3DParsedGCodeMill alloc] initWithGCodeString:gcodeString printer:(P3DPrinterDriverBase*)self.currentMachine];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if(parsedGCode.vertexIndex.count>0) {
                    _openGL3DPrinterView.parsedGCode = parsedGCode;
                } else {
                    _openGL3DPrinterView.parsedGCode = nil;
                }
                self.calculatingPreview=NO;
            });
        });
    } else {
        _openGL3DPrinterView.parsedGCode = nil;
        self.calculatingPreview=NO;
    }
}


#pragma mark - GUI Bindings

- (NSAttributedString*)formattedGCode
{
    return [[NSAttributedString alloc] initWithString:_rawGCode attributes:@{NSFontAttributeName: [NSFont fontWithName:@"Courier" size:13.]}];
}

- (void)setFormattedGCode:(NSAttributedString*)value
{
    self.rawGCode = value.string;
}

- (void)setRawGCode:(NSString*)value;
{
	if(_rawGCode!=value) {
		_rawGCode = value;
        [self parseGCodeString:_rawGCode];
	}
}

@end
