//
//  PSToolboxPanel.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 29.12.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//

#import "PSToolboxPanel.h"

@implementation PSToolboxPanel

- (void)awakeFromNib
{
	[self setMovableByWindowBackground:NO];
}

//- (void)orderFront:(id)sender
//{
//	NSLog(@"orderFront");
//	[super orderFront:sender];
//}

- (void)fadeIn
{
	[self setAlphaValue:[self isVisible]?1.:0.];
	[super makeKeyAndOrderFront:self];
	[NSTimer scheduledTimerWithTimeInterval:.05 target:self selector:@selector(fadeIn:) userInfo:nil repeats:YES];
}

- (void)fadeIn:(NSTimer*)timer
{
	float alpha = [self alphaValue];
	if(alpha>.8)
	{
		[self setAlphaValue:1.];
		[timer invalidate];
	}
	else
		[self setAlphaValue:alpha+.2];
	
}

- (void)orderOut:(id)context
{
	[NSTimer scheduledTimerWithTimeInterval:.05 target:self selector:@selector(fadeOut:) userInfo:context repeats:YES];
}

- (void)fadeOut:(NSTimer*)timer
{
	float alpha = [self alphaValue];
	if(alpha<.2)
	{
		id context = [timer userInfo];
		[self setAlphaValue:0.];
		[timer invalidate];
		[super orderOut:self];
		if([context isKindOfClass:[NSOperation class]])
			[(NSOperation*)context start];
	}
	else
		[self setAlphaValue:alpha-.2];

}

@end
