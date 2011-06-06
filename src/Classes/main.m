//
//  main.m
//  PleasantSTL
//
//  Created by Eberhard Rensch on 12.10.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <P3DCore/P3DCore.h>

int main(int argc, char *argv[])
{
#if defined(__VERBOSE__) || defined(__DEBUG__)
	switchToFileLogging();
#endif
	//Debugger();
	return NSApplicationMain(argc, (const char **) argv);
}
