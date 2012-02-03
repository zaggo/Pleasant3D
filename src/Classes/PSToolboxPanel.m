//
//  PSToolboxPanel.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 29.12.09.
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
