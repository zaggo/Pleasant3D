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

- (id)initWithGCode:(NSString*)gc;
{
	self = [super init];
	if (self != nil) {
        gCode = [gc componentsSeparatedByString:@"\n"];
	}
	return self;
}

- (void)implProcessJob
{
	NSInteger totalLength = (float)gCode.count;	
	float percent = 0.f;
	
	PleasantMillDevice* device = (PleasantMillDevice*)(self.driver.currentDevice);
    for(NSInteger lineIndex=0; lineIndex<totalLength; lineIndex++)
    {
        NSString* cleanLine = [[gCode objectAtIndex:lineIndex] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if(cleanLine.length>0 && ![cleanLine hasPrefix:@";"])
        {
            response = nil;
            NSError* error = [device sendStringAsynchron:[cleanLine stringByAppendingString:@"\r"]];
            if(error!=nil)
            {
                break;
            }
            
            while(response==nil)
            {
                if(self.jobAbort)
                    break;
            }
            
            if(![response hasPrefix:@"ok"])
            {
                PSErrorLog(@"Error Response: %@", response);
                break;
            }

        }

        percent = (float)lineIndex/(float)totalLength;
        if((NSInteger)(self.progress*100.f)<(NSInteger)(percent*100.f))
            dispatch_async(dispatch_get_main_queue(), ^{
                self.progress = percent;
                NSLog(@"Sent Job: %f%%",(percent*100.f));
            });
		
		if(self.jobAbort)
			break;
	}
}

- (void)handleDeviceResponse:(NSString*)r
{
    response=r;
}

@end
