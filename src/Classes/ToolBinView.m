//
//  ToolBinView.m
//  MacSkeinforge
//
//  Created by Eberhard Rensch on 02.08.09.
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

#import "ToolBinView.h"
#import <QuartzCore/QuartzCore.h>
#import <P3DCore/P3DCore.h>
#import "ToolBinEntryView.h"
#import "ToolPanelView.h"
#import "SliceNDiceDocument.h"
#import "ToolPool.h"

typedef enum 
{
	kBeforeTool,
	kLeftOnTool,
	kRightOnTool,
	kAfterTool
} HitPart;

@interface ToolBinView (Privat)
- (void)findHitToolForLocation:(NSPoint)localPoint outIndex:(NSInteger*)outIndex outHitPart:(HitPart*)outHitPart outToolBinEntryView:(ToolBinEntryView**)outToolBinEntryView;
- (void)makeGapAtIndex:(NSInteger)gapNeededAtIndex hitPart:(HitPart)part;
@end

@implementation ToolBinView
@dynamic indexOfPreviewedTool, canPrintDocument;

- (void)awakeFromNib
{
	toolViewControllers = [NSMutableArray array];
	

	// The following layer ist just for debugging purposes
//	CALayer* layer;
//	layer = [CALayer layer];
//	layer.frame = NSRectToCGRect([self bounds]);
//	layer.backgroundColor = CGColorCreateGenericRGB(1., 0., 0., .2);
//	layer.contentsGravity = kCAGravityResize;
//	layer.autoresizingMask = kCALayerWidthSizable;
//	[self.layer addSublayer:layer];
	
	
	[self registerForDraggedTypes:[NSArray arrayWithObjects:P3DToolUTI, NSURLPboardType, nil]];
	
	gapAtIndex = -1; // No Gap yet
}

- (BOOL)acceptsFirstResponder {
    // We want this view to be able to receive key events.
    return YES;
}

- (void)resizeToolBin
{
	NSRect binFrame = [self frame];
	binFrame.size.width =MAX(NSWidth([[self superview] visibleRect]),NSMaxX([(ToolBinEntryView*)[[toolViewControllers lastObject] view] frame]));
	[self setFrame:binFrame];	
}

- (void)insertTool:(P3DToolBase*)tool atIndex:(NSInteger)index
{
	SliceNDiceDocument* document = (SliceNDiceDocument*)[[[self window] windowController] document];
	[[[document undoManager] prepareWithInvocationTarget:self] removeToolFromToolBin:tool];
	
	NSViewController* dropped = [[NSViewController alloc] initWithNibName:@"ToolPanel" bundle:nil];
	[toolViewControllers insertObject:dropped atIndex:index];
	[dropped setRepresentedObject:tool];
	[self addSubview:[dropped view]];

	NSInteger pos=0;
	for(NSViewController* viewCtrl in toolViewControllers)
	{
		ToolBinEntryView* toolView = (ToolBinEntryView*)[viewCtrl view];
		[toolView moveToX:kToolBinEntryViewWidth*pos++ animated:NO];
	}

	[tool prepareForDuty];
	
	// There's a predecessor, connect it
	if(index>0)
	{
		tool.inputProvider = (P3DToolBase*)[[toolViewControllers objectAtIndex:index-1] representedObject];
	}
	
	// There's a successor, connect it
	if(index+1<toolViewControllers.count)
	{
		P3DToolBase* successor = (P3DToolBase*)[[toolViewControllers objectAtIndex:index+1] representedObject];
		successor.inputProvider = tool;
	}
	else // If the new tool is the last in the bin, change the preview
	{
		[self disableOtherPreviews:tool];
		tool.showPreview = YES;
	}
	
	[self resizeToolBin];
	[self setNeedsDisplay:YES];
}

- (void)removeToolFromToolBin:(P3DToolBase*)tool
{
	NSInteger indexOfTool=-1;
	NSInteger count = [toolViewControllers count];
	for(NSInteger i = 0; i<count; i++)
	{
		if([[toolViewControllers objectAtIndex:i] representedObject] == tool)
		{
			indexOfTool = i;
			break;
		}
	}
	if(indexOfTool>=0)
	{
		SliceNDiceDocument* document = (SliceNDiceDocument*)[[[self window] windowController] document];
		[[[document undoManager] prepareWithInvocationTarget:self] insertTool:tool atIndex:indexOfTool];
		
		// There's a successor, disconnect it
		P3DToolBase* successor=nil;
		if(indexOfTool+1<toolViewControllers.count)
		{
			successor = (P3DToolBase*)[[toolViewControllers objectAtIndex:indexOfTool+1] representedObject];
			successor.inputProvider = tool.inputProvider;
		}
		
		tool.inputProvider = nil;
		
		tool.showPreview=NO;
		[[[toolViewControllers objectAtIndex:indexOfTool] view] removeFromSuperview];

		[toolViewControllers removeObjectAtIndex:indexOfTool];
		count--;
		//NSLog(@"Close Gap at %d",indexOfTool);
		for(NSInteger i = indexOfTool; i<count;i++)
			[(ToolBinEntryView*)[[toolViewControllers objectAtIndex:i] view] moveToX:kToolBinEntryViewWidth*(CGFloat)i animated:YES];
		[self resizeToolBin];
		[self setNeedsDisplay:YES];
	}
}

- (NSDragOperation)draggingEntered:(id < NSDraggingInfo >)sender
{
	NSDragOperation dragOp = NSDragOperationNone;
	
	NSPasteboard *pasteboard;
//    NSDragOperation sourceDragMask;
//	    
//	sourceDragMask = [sender draggingSourceOperationMask];
	pasteboard = [sender draggingPasteboard];
	NSPoint localPoint = [self convertPoint:[sender draggingLocation] fromView:nil];
	
	NSInteger gapNeededAtIndex =-1;
	if ( [pasteboard canReadObjectForClasses:[NSArray arrayWithObject:[P3DToolBase class]] options:nil] ) 
	{
		dragOp = NSDragOperationCopy;
		//BOOL copy = (sourceDragMask & NSDragOperationCopy);
		
		NSArray* draggedTools = [pasteboard readObjectsForClasses:[NSArray arrayWithObject:[P3DToolBase class]] options:nil];
		P3DToolBase* tool = [draggedTools lastObject];
		
		if( ([sender draggingSource] == self) )
		{
			dragOp = NSDragOperationMove;
		}	

		if(dragOp==NSDragOperationMove || dragOp==NSDragOperationCopy)
		{
			HitPart part;
			ToolBinEntryView* toolBinEntryView;
			[self findHitToolForLocation:localPoint outIndex:&gapNeededAtIndex outHitPart:&part outToolBinEntryView:&toolBinEntryView];			
			
			NSInteger previousIndex = gapNeededAtIndex-1;
			switch(part)
			{
				case kRightOnTool:
				case kAfterTool:
					previousIndex++;
					break;
                default:
                    break;
			}
			
			P3DToolBase* pre = nil;
			P3DToolBase* next = nil;
			if(previousIndex>=0)
				pre = (P3DToolBase*)[[toolViewControllers objectAtIndex:previousIndex] representedObject];
			
			NSInteger nextIndex = gapNeededAtIndex;
			switch(part)
			{
				case kRightOnTool:
				case kAfterTool:
					nextIndex++;
					break;
                default:
                    break;
			}
			if(nextIndex<[toolViewControllers count])
				next = (P3DToolBase*)[[toolViewControllers objectAtIndex:nextIndex] representedObject];
		
			if(![tool canHandleInputFromTool:pre andProvideOutputForTool:next])
			{
				dragOp = NSDragOperationDelete;
			}
			
			if(dragOp == NSDragOperationDelete && gapAtIndex!=-1)
			{
				//NSLog(@"Close Gap at %d",gapAtIndex);
				for(NSInteger i = gapAtIndex; i<[toolViewControllers count];i++)
					[(ToolBinEntryView*)[[toolViewControllers objectAtIndex:i] view] moveToX:kToolBinEntryViewWidth*(CGFloat)i animated:YES];
				gapAtIndex=-1;
				[self resizeToolBin];
				[self setNeedsDisplay:YES];
			}
			else if(dragOp != NSDragOperationDelete)
				[self makeGapAtIndex:gapNeededAtIndex hitPart:part];
		}
    }
	else
	{
		NSArray* currentTools = [self currentToolsArray];
		P3DToolBase* currentFirstTool = nil;
		NSArray* requiredInputFormats = nil; 
		if(currentTools.count>0)
		{
			currentFirstTool = [currentTools objectAtIndex:0];
			requiredInputFormats = [[currentFirstTool class] requiredInputFormats];
		}
		NSMutableArray* possibleUTIs=[NSMutableArray array];
		if(currentFirstTool && [[[currentFirstTool class] toolType] isEqualToString:P3DTypeImporter] && requiredInputFormats)
			[possibleUTIs addObjectsFromArray:requiredInputFormats];
		else
        {
            NSArray* availableImporterUTIs = [[ToolPool  sharedToolPool] availableImporterUTIs];
			if(availableImporterUTIs)
                [possibleUTIs addObjectsFromArray:availableImporterUTIs];
        }
        NSArray* supportedToolCreatingUTIs = [[ToolPool  sharedToolPool] supportedToolCreatingUTIs];
        if(supportedToolCreatingUTIs)
            [possibleUTIs addObjectsFromArray:supportedToolCreatingUTIs];

		for(NSString* uti in possibleUTIs)
		{
			NSDictionary* pbReadOptions = [NSDictionary dictionaryWithObjectsAndKeys:
										   (id)kCFBooleanTrue, NSPasteboardURLReadingFileURLsOnlyKey,
										   [NSArray arrayWithObject:uti], NSPasteboardURLReadingContentsConformToTypesKey,
										   nil];
			if ( [pasteboard canReadObjectForClasses:[NSArray arrayWithObject:[NSURL class]] options:pbReadOptions] )
			{
				NSArray* draggedFiles = [pasteboard readObjectsForClasses:[NSArray arrayWithObject:[NSURL class]] options:pbReadOptions];
				if(draggedFiles.count==1) // Only single files
				{
					if(currentFirstTool)
					{
                        if([currentFirstTool.requiredInputFormats containsObject:uti])
                            dragOp = NSDragOperationCopy;
                        else
                        {
                            NSMutableArray* possibleTools = [NSMutableArray array];
                            NSArray* allTools = [[ToolPool  sharedToolPool] availableTools];
                            for(NSDictionary* toolDesc in allTools)
                            {
                                Class toolClass = NSClassFromString([toolDesc objectForKey:kMSFPersistenceClass]);
                                if([[toolClass requiredInputFormats] containsObject:uti] && 
                                   [requiredInputFormats containsObject:[toolClass providesOutputFormat]])
                                {								
                                    [self makeGapAtIndex:0 hitPart:kBeforeTool];
                                    dragOp = NSDragOperationCopy;
                                    break;
                                }
                                else if([[toolClass importedContentDataUTIs] containsObject:uti])
                                {
                                    [possibleTools addObject:toolClass];
                                }
                            }
                            if(dragOp==NSDragOperationNone && possibleTools.count>0)
                            {
                                HitPart part;
                                ToolBinEntryView* toolBinEntryView;
                                [self findHitToolForLocation:localPoint outIndex:&gapNeededAtIndex outHitPart:&part outToolBinEntryView:&toolBinEntryView];			
                                
                                NSInteger previousIndex = gapNeededAtIndex-1;
                                switch(part)
                                {
                                    case kRightOnTool:
                                    case kAfterTool:
                                        previousIndex++;
                                        break;
                                    default:
                                        break;
                                }
                                
                                P3DToolBase* pre = nil;
                                P3DToolBase* next = nil;
                                if(previousIndex>=0)
                                    pre = (P3DToolBase*)[[toolViewControllers objectAtIndex:previousIndex] representedObject];
                                
                                NSInteger nextIndex = gapNeededAtIndex;
                                switch(part)
                                {
                                    case kRightOnTool:
                                    case kAfterTool:
                                        nextIndex++;
                                        break;
                                    default:
                                        break;
                                }
                                if(nextIndex<[toolViewControllers count])
                                    next = (P3DToolBase*)[[toolViewControllers objectAtIndex:nextIndex] representedObject];

                                for(Class toolClass in possibleTools)
                                {
                                    P3DToolBase* tool = [[toolClass alloc] init];
                                    if([tool canHandleInputFromTool:pre andProvideOutputForTool:next])
                                    {
                                        dragOp = NSDragOperationCopy;
                                        break;
                                    }
                                }    
                                
                                if(dragOp == NSDragOperationNone)
                                    dragOp = NSDragOperationDelete;
                                
                                if(dragOp == NSDragOperationNone && gapAtIndex!=-1)
                                {
                                    //NSLog(@"Close Gap at %d",gapAtIndex);
                                    for(NSInteger i = gapAtIndex; i<[toolViewControllers count];i++)
                                        [(ToolBinEntryView*)[[toolViewControllers objectAtIndex:i] view] moveToX:kToolBinEntryViewWidth*(CGFloat)i animated:YES];
                                    gapAtIndex=-1;
                                    [self resizeToolBin];
                                    [self setNeedsDisplay:YES];
                                }
                                else if(dragOp != NSDragOperationDelete)
                                    [self makeGapAtIndex:gapNeededAtIndex hitPart:part];
                            }
                        }
					}
					else
						dragOp = NSDragOperationCopy;
				}
			}
		}
	}

    NSEvent *event = [NSApp currentEvent];
    [[self superview] autoscroll:event];
	
	switch(dragOp)
	{
		case NSDragOperationDelete:
			[[NSCursor operationNotAllowedCursor] set];
			dragOp = NSDragOperationNone;
			break;
		case NSDragOperationCopy:
			[[NSCursor dragCopyCursor] set];
			break;
		default:
			[[NSCursor arrowCursor] set];
	}
    return dragOp;
}

- (NSDragOperation)draggingUpdated:(id < NSDraggingInfo >)sender
{
    return [self draggingEntered:sender];
}

- (void)draggingExited:(id < NSDraggingInfo >)sender
{
//	NSPasteboard *pasteboard;
//    NSDragOperation sourceDragMask;
//	
//    sourceDragMask = [sender draggingSourceOperationMask];
//	pasteboard = [sender draggingPasteboard];
// 	NSArray* draggedClasses = [NSArray arrayWithObject:[P3DToolBase class]];
//    if ( [pasteboard canReadObjectForClasses:draggedClasses options:nil] ) 
	{
		if(gapAtIndex!=-1)
		{
			//NSLog(@"Close Gap at %d",gapAtIndex);
			for(NSInteger i = gapAtIndex; i<[toolViewControllers count];i++)
				[(ToolBinEntryView*)[[toolViewControllers objectAtIndex:i] view] moveToX:kToolBinEntryViewWidth*(CGFloat)i animated:YES];
			gapAtIndex=-1;
			[self resizeToolBin];
			[self setNeedsDisplay:YES];
		}
		if([sender draggingSource]==self)
			[[NSCursor disappearingItemCursor] set];
		else
			[[NSCursor operationNotAllowedCursor] set];
	}
}

- (void)draggingEnded:(id < NSDraggingInfo >)sender
{
	NSPoint localPoint = [self convertPoint:[sender draggingLocation] fromView:nil];
	if(!NSPointInRect(localPoint, [self visibleRect]))
	{
		NSPasteboard* pboard = [sender draggingPasteboard];
		[pboard clearContents];

		//NSLog(@"DraggingEmptied");
	}
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
	BOOL result=NO;
    NSPasteboard *pasteboard;
//    NSDragOperation sourceDragMask;
//	
//    sourceDragMask = [sender draggingSourceOperationMask];
    pasteboard = [sender draggingPasteboard];
	if ( [pasteboard canReadObjectForClasses:[NSArray arrayWithObject:[P3DToolBase class]] options:nil] ) 
	{
		NSArray* draggedTools = [pasteboard readObjectsForClasses:[NSArray arrayWithObject:[P3DToolBase class]] options:nil];
		P3DToolBase* tool = [draggedTools lastObject];
		if(tool)
		{
			NSInteger index;
			HitPart part;
			ToolBinEntryView* toolBinEntryView;
			[self findHitToolForLocation:[self convertPoint:[sender draggingLocation] fromView:nil] outIndex:&index outHitPart:&part outToolBinEntryView:&toolBinEntryView];
			[self makeGapAtIndex:index hitPart:part];
			switch(part)
			{
				case kRightOnTool:
				case kAfterTool:
					index++;
					break;
                default:
                    break;
			}
		
			tool.sliceNDiceHost = (SliceNDiceDocument*)[[[self window] windowController] document];
			[self insertTool:tool atIndex:index];

			result=YES;
		}
    } 
	else
	{
		NSArray* currentTools = [self currentToolsArray];
		P3DToolBase* currentFirstTool = nil;
		NSArray* requiredInputFormats = nil; 
		if(currentTools.count>0)
		{
			currentFirstTool = [currentTools objectAtIndex:0];
			requiredInputFormats = [[currentFirstTool class] requiredInputFormats];
		}
		NSMutableArray* possibleUTIs=[NSMutableArray array];
		if(currentFirstTool && [[[currentFirstTool class] toolType] isEqualToString:P3DTypeImporter] && requiredInputFormats)
			[possibleUTIs addObjectsFromArray:requiredInputFormats];
		else
        {
            NSArray* availableImporterUTIs = [[ToolPool  sharedToolPool] availableImporterUTIs];
			if(availableImporterUTIs)
                [possibleUTIs addObjectsFromArray:availableImporterUTIs];
        }
        NSArray* supportedToolCreatingUTIs = [[ToolPool  sharedToolPool] supportedToolCreatingUTIs];
        if(supportedToolCreatingUTIs)
            [possibleUTIs addObjectsFromArray:supportedToolCreatingUTIs];
		
		for(NSString* uti in possibleUTIs)
		{
			NSDictionary* pbReadOptions = [NSDictionary dictionaryWithObjectsAndKeys:
										   (id)kCFBooleanTrue, NSPasteboardURLReadingFileURLsOnlyKey,
										   [NSArray arrayWithObject:uti], NSPasteboardURLReadingContentsConformToTypesKey,
										   nil];
			if ( [pasteboard canReadObjectForClasses:[NSArray arrayWithObject:[NSURL class]] options:pbReadOptions] )
			{
				NSArray* draggedFiles = [pasteboard readObjectsForClasses:[NSArray arrayWithObject:[NSURL class]] options:pbReadOptions];
				if(draggedFiles.count==1) // Only single files
				{
                    if(currentFirstTool && [currentFirstTool.requiredInputFormats containsObject:uti])
                    {
                        SEL pathSetterSel = [currentFirstTool pathSetterForImportContentDataWithUTI:uti];
                        if(pathSetterSel && [currentFirstTool respondsToSelector:pathSetterSel])
                            [currentFirstTool performSelector:pathSetterSel withObject:[[draggedFiles lastObject] path]];
                        result = YES;
                    }
                    else
                    {
                        NSMutableArray* possibleTools = [NSMutableArray array];
                        NSArray* allTools = [[ToolPool  sharedToolPool] availableTools];
                        for(NSDictionary* toolDesc in allTools)
                        {
                            Class toolClass = NSClassFromString([toolDesc objectForKey:kMSFPersistenceClass]);
                            if((currentFirstTool==nil || ![[[currentFirstTool class] toolType] isEqualToString:P3DTypeImporter]) && [[toolClass requiredInputFormats] containsObject:uti])
                            {								
								currentFirstTool = [[toolClass alloc] initWithHost:[[[self window] windowController] document]];
								[self insertTool:currentFirstTool atIndex:0];
                                SEL pathSetterSel = [currentFirstTool pathSetterForImportContentDataWithUTI:uti];
                                if(pathSetterSel && [currentFirstTool respondsToSelector:pathSetterSel])
                                    [currentFirstTool performSelector:pathSetterSel withObject:[[draggedFiles lastObject] path]];
                                result = YES;
                                break;
                            }
                            else if([[toolClass importedContentDataUTIs] containsObject:uti])
                            {
                                [possibleTools addObject:toolClass];
                            }
                        }
                        if(!result && possibleTools.count>0)
                        {
                            NSInteger gapNeededAtIndex =-1;
                            NSPoint localPoint = [self convertPoint:[sender draggingLocation] fromView:nil];
                            HitPart part;
                            ToolBinEntryView* toolBinEntryView;
                            [self findHitToolForLocation:localPoint outIndex:&gapNeededAtIndex outHitPart:&part outToolBinEntryView:&toolBinEntryView];			
                            NSInteger previousIndex = gapNeededAtIndex-1;
                            switch(part)
                            {
                                case kRightOnTool:
                                case kAfterTool:
                                    previousIndex++;
                                    break;
                                default:
                                    break;
                            }
                            
                            P3DToolBase* pre = nil;
                            P3DToolBase* next = nil;
                            if(previousIndex>=0)
                                pre = (P3DToolBase*)[[toolViewControllers objectAtIndex:previousIndex] representedObject];
                            
                            NSInteger nextIndex = gapNeededAtIndex;
                            switch(part)
                            {
                                case kRightOnTool:
                                case kAfterTool:
                                    nextIndex++;
                                    break;
                                default:
                                    break;
                            }
                            if(nextIndex<[toolViewControllers count])
                                next = (P3DToolBase*)[[toolViewControllers objectAtIndex:nextIndex] representedObject];
                            
                            for(Class toolClass in possibleTools)
                            {
                                P3DToolBase* tool = [[toolClass alloc] init];
                                if([tool canHandleInputFromTool:pre andProvideOutputForTool:next])
                                {
                                    tool = [[toolClass alloc] initWithHost:[[[self window] windowController] document]];
                                    [self insertTool:tool atIndex:nextIndex];
                                    
                                    SEL pathSetterSel = [tool pathSetterForImportContentDataWithUTI:uti];
                                    if(pathSetterSel && [tool respondsToSelector:pathSetterSel])
                                        [tool performSelector:pathSetterSel withObject:[[draggedFiles lastObject] path]];
                                    result = YES;
                                    break; // TODO: What's about multiple matches?
                                }
                            }    
                        }
                    }
				}
			}
		}
	}
	gapAtIndex=-1;
	return result;
}

- (void)dragToolPanel:(ToolPanelView*)panel withEvent:(NSEvent*)theEvent
{
	NSImage* dragImage = [panel imageForDragging];

	NSViewController* panelViewController = [panel viewController];
	//NSInteger recoverPanelDragIndex = [toolViewControllers indexOfObject:panelViewController];
	
	P3DToolBase* tool = (P3DToolBase*)[panelViewController representedObject];
	
	NSRect panelViewRect = [panel bounds];
	panelViewRect = [self convertRect:panelViewRect fromView:panel];
	
	NSPasteboard* pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
	[pboard declareTypes:[NSArray arrayWithObject:P3DToolUTI] owner:nil];
	
//	NSMutableDictionary* toolDict = [NSMutableDictionary dictionaryWithDictionary:[tool dictForPersistence]];
//	[toolDict setObject:[NSNumber numberWithInt:recoverPanelDragIndex] forKey:@"recoverPanelDragIndex"];
	
	//		BOOL success = [pboard setPropertyList:toolDict forType:kMSFToolUTI];
	NSData* data = [NSKeyedArchiver archivedDataWithRootObject:tool];
	BOOL success = [pboard setData:data forType:P3DToolUTI];
	
	if(success)
	{
		BOOL optKey = ([theEvent modifierFlags]&NSAlternateKeyMask)!=0;
		if(!optKey)
			[self removeToolFromToolBin:tool];
		[self dragImage:dragImage at:panelViewRect.origin offset:NSZeroSize event:theEvent pasteboard:pboard source:self slideBack:NO];
	}
}

- (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation
{
//	// In case an internal Move gone wrong, try to recover the previous state
//	if( !(operation&NSDragOperationMove) && !(operation&NSDragOperationCopy) )
//	{
//		NSPasteboard* pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
//		if ( [[pboard types] containsObject:kMSFToolUTI] )
//		{
//			NSData* data = [pboard dataForType:kMSFToolUTI];
//			//NSDictionary* toolDict = [pboard propertyListForType:kMSFToolUTI];
//			if(data)
//			{
//				SkeinForgeDocument* document = (SkeinForgeDocument*)[[[self window] windowController] document];
//				P3DToolBase* tool = [P3DToolBase toolWithToolDict:toolDict andDocument:document];
//				NSViewController* dropped = [[NSViewController alloc] initWithNibName:@"ToolPanel" bundle:nil];
//				
//				if([toolDict objectForKey:@"recoverPanelDragIndex"])
//				{
//					[toolViewControllers insertObject:dropped atIndex:[[toolDict objectForKey:@"recoverPanelDragIndex"] intValue]];
//					[dropped setRepresentedObject:tool];
//					aPoint = [self convertPointFromBase:[[self window] convertScreenToBase:aPoint]];
//					[(ToolBinEntryView*)[dropped view] moveToX:aPoint.x animated:NO];
//					[self addSubview:[dropped view]];
//					NSInteger pos=0;
//					for(NSViewController* viewCtrl in toolViewControllers)
//					{
//						ToolBinEntryView* toolView = (ToolBinEntryView*)[viewCtrl view];
//						[toolView moveToX:kToolBinEntryViewWidth*pos++ animated:YES];
//					}
//					[self resizeToolBin];
//					[self setNeedsDisplay:YES];
//				}
//			}
//		}
//	}
}


- (void)findHitToolForLocation:(NSPoint)localPoint outIndex:(NSInteger*)outIndex outHitPart:(HitPart*)outHitPart outToolBinEntryView:(ToolBinEntryView**)outToolBinEntryView;
{
	NSInteger index=0;
	HitPart part = kBeforeTool;
	ToolBinEntryView* hitToolBinEntryView=nil;

	for(NSViewController* viewCtrl in toolViewControllers)
	{
		ToolBinEntryView* toolPanel = (ToolBinEntryView*)[viewCtrl view];
		NSRect toolFrame = [toolPanel frame];
		if(localPoint.x<NSMinX(toolFrame))
		{
			hitToolBinEntryView = toolPanel;
			part = kBeforeTool;
			break;
		}
		else if(localPoint.x<NSMidX(toolFrame))
		{
			hitToolBinEntryView = toolPanel;
			part = kLeftOnTool;
			break;
		}
		else if(localPoint.x<NSMaxX(toolFrame))
		{
			hitToolBinEntryView = toolPanel;
			part = kRightOnTool;
			break;
		}
		else
		{
			index++;
		}
	}

	if(index>0 && index>=[toolViewControllers count])
	{
		index--;
		part = kAfterTool;
		hitToolBinEntryView = (ToolBinEntryView*)[[toolViewControllers lastObject] view];
	}

	*outIndex = index;
	*outHitPart = part;
	*outToolBinEntryView = hitToolBinEntryView;
}

- (void)makeGapAtIndex:(NSInteger)gapNeededAtIndex hitPart:(HitPart)part
{
	
	NSInteger gapWillBeAt=gapNeededAtIndex;
	switch(part)
	{
		case kRightOnTool:
		case kAfterTool: 
			gapWillBeAt=gapNeededAtIndex+1;
			break;
        default:
            break;
	}
		
	if(gapAtIndex != gapWillBeAt) // Lücke erzeugen oder verschieben
	{
		if(gapAtIndex==-1)
		{
			if(part == kBeforeTool || part == kLeftOnTool)
			{
				//NSLog(@"Create (A) new Gap at %d",gapNeededAtIndex);
				for(NSInteger i = gapNeededAtIndex; i<[toolViewControllers count];i++)
					[(ToolBinEntryView*)[[toolViewControllers objectAtIndex:i] view] moveToX:kToolBinEntryViewWidth*(CGFloat)i+kToolBinEntryViewWidth animated:YES];
			}
			else
			{
				//NSLog(@"Create (B) new Gap at %d",gapNeededAtIndex+1);
				for(NSInteger i = gapNeededAtIndex+1; i<[toolViewControllers count];i++)
					[(ToolBinEntryView*)[[toolViewControllers objectAtIndex:i] view] moveToX:kToolBinEntryViewWidth*(CGFloat)i+kToolBinEntryViewWidth animated:YES];
			}
		}
		else if(gapAtIndex<gapWillBeAt)
		{
			if(part == kBeforeTool || part == kLeftOnTool)
			{
				//NSLog(@"Move (A) Gap from %d to %d",gapAtIndex, gapNeededAtIndex);
				for(NSInteger i = gapAtIndex; i<=gapNeededAtIndex-1;i++)
					[(ToolBinEntryView*)[[toolViewControllers objectAtIndex:i] view] moveToX:kToolBinEntryViewWidth*(CGFloat)i animated:YES];
			}
			else
			{
				//NSLog(@"Move (B) Gap from %d to %d",gapAtIndex, gapNeededAtIndex+1);
				for(NSInteger i = gapAtIndex; i<=gapNeededAtIndex;i++)
					[(ToolBinEntryView*)[[toolViewControllers objectAtIndex:i] view] moveToX:kToolBinEntryViewWidth*(CGFloat)i animated:YES];
			}
		}
		else // if(gapAtIndex>gapWillBeAt)
		{
			if(part == kBeforeTool || part == kLeftOnTool)
			{
				//NSLog(@"Move (C) Gap from %d to %d",gapAtIndex, gapNeededAtIndex);
				for(NSInteger i = gapNeededAtIndex; i<=gapAtIndex-1;i++)
					[(ToolBinEntryView*)[[toolViewControllers objectAtIndex:i] view] moveToX:kToolBinEntryViewWidth*(CGFloat)i+kToolBinEntryViewWidth animated:YES];
			}
			else
			{
				//NSLog(@"Move (D) Gap from %d to %d",gapAtIndex, gapNeededAtIndex+1);
				for(NSInteger i = gapNeededAtIndex+1; i<=gapAtIndex-1;i++)
					[(ToolBinEntryView*)[[toolViewControllers objectAtIndex:i] view] moveToX:kToolBinEntryViewWidth*(CGFloat)i+kToolBinEntryViewWidth animated:YES];
			}
		}
		
		gapAtIndex = gapWillBeAt;
		
		[self resizeToolBin];
		[self setNeedsDisplay:YES];
	}
}

- (void)disableOtherPreviews:(P3DToolBase*)exclude;
{
	for(NSViewController* viewCtrl in toolViewControllers)
	{
		P3DToolBase* tool = (P3DToolBase*)[viewCtrl representedObject];
		if(tool!=exclude && tool.showPreview)
		{
			//NSLog(@"autohide %@", [tool localizedToolName]);
			tool.showPreview=NO;
		}
	}
}		

- (void)setIndexOfPreviewedTool:(NSUInteger)index
{
	if(index<toolViewControllers.count)
	{
		NSViewController* toolPanelController = [toolViewControllers objectAtIndex:index];
		P3DToolBase* tool = [toolPanelController representedObject];
		tool.showPreview=YES;
	}
}

- (NSUInteger)indexOfPreviewedTool
{
	NSUInteger indexOfPreviewedTool = NSNotFound;
	for(NSViewController* toolPanelController in toolViewControllers)
	{
		P3DToolBase* tool = [toolPanelController representedObject];
		if(tool.showPreview)
		{
			indexOfPreviewedTool = [toolViewControllers indexOfObject:toolPanelController];
			break;
		}
	}
	return indexOfPreviewedTool;
}

- (NSArray*)currentToolsArray
{
	NSMutableArray* serializeTools = [NSMutableArray array];
	for(NSViewController* toolPanelController in toolViewControllers)
	{
		P3DToolBase* tool = [toolPanelController representedObject];
		[serializeTools addObject:tool];
	}
	return serializeTools;
}

- (BOOL)deserializeTools:(NSArray*)serializedTools
{
	BOOL success = NO;	
	if(serializedTools)
	{
		SliceNDiceDocument* document = (SliceNDiceDocument*)[[[self window] windowController] document];
		
		for(NSViewController* viewCtrl in toolViewControllers)
			[[viewCtrl view] removeFromSuperview];
		[toolViewControllers removeAllObjects];
		
		P3DToolBase* pre = nil;
		for(P3DToolBase* tool in serializedTools)
		{
			tool.sliceNDiceHost = document;
			NSViewController* loadedToolView = [[NSViewController alloc] initWithNibName:@"ToolPanel" bundle:nil];
			[toolViewControllers addObject:loadedToolView];
			[loadedToolView setRepresentedObject:tool];
			[self addSubview:[loadedToolView view]];
			
			[tool prepareForDuty];
			if(pre)
				tool.inputProvider = pre;
			pre = tool;
		}
		
		NSInteger pos=0;
		for(NSViewController* viewCtrl in toolViewControllers)
		{
			ToolBinEntryView* toolView = (ToolBinEntryView*)[viewCtrl view];
			[toolView moveToX:kToolBinEntryViewWidth*pos++ animated:NO];
		}

		[self resizeToolBin];
		[self setNeedsDisplay:YES];
		success = YES;
	}
	return success;
}

- (void)reprocessProject
{
	for(P3DToolBase* tool in self.currentToolsArray)
	{
		if(![[[tool class] toolType] isEqualToString:P3DTypeImporter])
		{
			[tool reprocessData:self];
			break;
		}
	}
}

- (BOOL)canPrintDocument
{
	P3DToolBase* tool = [[toolViewControllers lastObject] representedObject];
	if(tool && tool.outData && [tool.outData.dataFormat isEqualToString:P3DFormatGCode])
		return YES;
	return NO;
}
@end
