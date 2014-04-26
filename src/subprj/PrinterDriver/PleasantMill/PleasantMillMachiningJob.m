//
//  PleasantMillPrintJob.m
//  PleasantMill
//
//  Created by Eberhard Rensch on 11.04.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import "PleasantMillMachiningJob.h"
#import "PleasantMillDevice.h"


@implementation PleasantMillMachiningJob
{
    NSInteger _codeLineIndex;
    dispatch_block_t _jobCompletionHandler;
}

- (id)initWithGCode:(NSString*)gc;
{
	self = [super init];
	if (self != nil) {
        gCode = [gc componentsSeparatedByString:@"\n"];
	}
	return self;
}

- (void)implProcessJobWithCompletionHandler:(dispatch_block_t)completionHandler
{
    _jobCompletionHandler = completionHandler;
    _codeLineIndex = 0;
    [self processNextCodeLine];
}

- (void)processNextCodeLine
{
    BOOL successfullyProcessed = YES;
    
    PleasantMillDevice* device = (PleasantMillDevice*)self.driver.currentDevice;
    NSString* cleanLine = [[gCode objectAtIndex:_codeLineIndex] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if(cleanLine.length>0 && ![cleanLine hasPrefix:@";"]) {
        response = nil;
        NSError* error = [device sendStringAsynchron:[cleanLine stringByAppendingString:@"\r"]];
        if(error!=nil) {
            PSErrorLog(@"sendStringAsynchron failed (%@)", cleanLine);
            _jobCompletionHandler();
            successfullyProcessed = NO;
        } else {
            
            while(response==nil) {
                if(self.jobAbort)
                    break;
                usleep(100);
            }
            
            if([response hasPrefix:@"ok"]) {
            } else {
                NSRegularExpression* regEx = [[NSRegularExpression alloc] initWithPattern:@"(rs\\s+(\\d+))?.*\\[E(\\d+)\\]\\s*(.*)" options:NSRegularExpressionCaseInsensitive error:&error];
                NSTextCheckingResult* result = [regEx firstMatchInString:response options:0 range:NSMakeRange(0, response.length)];
                if(result) {
                    NSInteger errorCode = 0;
                    NSString* errorString = nil;
                    NSInteger codeLine = -1;
                    
                    NSRange range = [result rangeAtIndex:2];
                    if(range.location != NSNotFound)
                        codeLine = [[response substringWithRange:range] integerValue];
                    range = [result rangeAtIndex:3];
                    if(range.location != NSNotFound)
                        errorCode = [[response substringWithRange:range] integerValue];
                    range = [result rangeAtIndex:4];
                    if(range.location != NSNotFound)
                        errorString = [[response substringWithRange:range] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                    
                    PSErrorLog(@"Error #%d: %@ [Resend Line:%d]", errorCode, errorString, codeLine);
                    switch(errorCode) {
                        case kErrorCodeMachineNotArmed:
                        {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                NSAlert* alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Machine is not armed", @"Machine not armed error") defaultButton:NSLocalizedString(@"Cancel", @"Cancel Button") alternateButton:NSLocalizedString(@"Arm Mill and Continue", @"Machine not armed error: Arm Mill Button") otherButton:nil informativeTextWithFormat:NSLocalizedString(@"The Mill isn't armed for processing data from a computer. Press 'Arm Mill and Contiue' to automatically arm the machine and continue machining.", @"Machine not armed error: Informative Text")];
                                [alert beginSheetModalForWindow:self.document.windowForSheet completionHandler:^(NSModalResponse returnCode) {
                                    if(returnCode == 1) { // Cancel
                                        _jobCompletionHandler();
                                    } else if(codeLine>=0) {
                                        [self continueProcessingAtLine:codeLine];
                                    } else {
                                        [self continueProcessingAtLine:_codeLineIndex];
                                    }
                                }];
                            });
                        }
                            break;
                        default:
                            _jobCompletionHandler();
                    }
                } else {
                    PSErrorLog(@"Error Response: %@", response);
                    _jobCompletionHandler();
                }
                successfullyProcessed = NO;
            }
        }
    }
    
    if(successfullyProcessed)
        [self continueProcessingAtLine:_codeLineIndex+1];
}

- (void)continueProcessingAtLine :(NSInteger)nextLine
{
    _codeLineIndex=nextLine;
    
    float percent = percent = (float)_codeLineIndex/(float)gCode.count;
    if((NSInteger)(self.progress*100.f)<(NSInteger)(percent*100.f)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.progress = percent;
            PSLog(@"print", PSPrioNormal, @"Sent Job: %f%%",(percent*100.f));
        });
    }
    
    if(_codeLineIndex>=gCode.count || self.jobAbort)
        _jobCompletionHandler();
    else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self processNextCodeLine];
        });
    }
}

- (void)handleDeviceResponse:(NSString*)r
{
    response=r;
}

@end
