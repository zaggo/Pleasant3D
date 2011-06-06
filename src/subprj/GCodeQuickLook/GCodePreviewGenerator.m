//
//  GCodePreviewGenerator.m
//  GCodeQuickLook
//
//  Created by Eberhard Rensch on 07.01.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import "GCodePreviewGenerator.h"
//#import <P3DCore/NSArray+GCode.h>
#import "NSArray+GCode.h"
#import <OpenGL/glu.h>

static void swizzleBitmap(void * data, int rowBytes, int height) {
    int top, bottom;
    void *buffer;
    void *topP;
    void *bottomP;
    void *base;
	
    top = 0;
    bottom = height - 1;
    base = data;
    buffer = malloc(rowBytes);
	
    while (top < bottom) {
        topP = (void *)((top * rowBytes) + (intptr_t)base);
        bottomP = (void *)((bottom * rowBytes) + (intptr_t)base);
		
        bcopy(topP, buffer, rowBytes);
        bcopy(bottomP, topP, rowBytes);
        bcopy(buffer, bottomP, rowBytes);
		
        ++top;
        --bottom;
    }
    free(buffer);
}

const CGFloat kRenderUpsizeFaktor=3.;
@interface NSScanner (ParseGCode)
- (void)updateLocation:(Vector3*)currentLocation;
- (BOOL)isLayerStartWithCurrentLocation:(Vector3*)currentLocation oldZ:(CGFloat*)oldZ layerStartWordExists:(BOOL)layerStartWordExist;
@end

@implementation NSScanner (ParseGCode)
- (void)updateLocation:(Vector3*)currentLocation
{
	float value;
	if([self scanString:@"X" intoString:nil])
	{
		[self scanFloat:&value];
		currentLocation.x = value;
	}
	if([self scanString:@"Y" intoString:nil])
	{
		[self scanFloat:&value];
		currentLocation.y = value;
	}
	if([self scanString:@"Z" intoString:nil])
	{
		[self scanFloat:&value];
		currentLocation.z = value;
	}
}

- (BOOL)isLayerStartWithCurrentLocation:(Vector3*)currentLocation oldZ:(CGFloat*)oldZ layerStartWordExists:(BOOL)layerStartWordExist
{
	BOOL isLayerStart = NO;
	
	if(layerStartWordExist)
	{
		if([self scanString:@"(<layer>" intoString:nil])
			isLayerStart = YES;
	}
	else if([self scanString:@"G1" intoString:nil] || 
			[self scanString:@"G2" intoString:nil] ||
			[self scanString:@"G3" intoString:nil])
	{
		[self updateLocation:currentLocation];
		if(currentLocation.z-*oldZ >.1)
		{
			*oldZ=currentLocation.z;
			isLayerStart = YES;
		}
	}
	[self setScanLocation:0];
	return isLayerStart;
}

@end

@implementation GCodePreviewGenerator
@synthesize renderSize, gCodePanes;

- (NSArray*)parseLines:(NSArray*)gCodeLineScanners
{
	BOOL isThereALayerStartWord=[gCodeLineScanners isThereAFirstWord:@"(<layer>"];
		
	__block NSMutableArray* panes = [NSMutableArray array];
	__block NSMutableArray* currentPane = nil;
	__block Vector3* currentLocation = [[Vector3 alloc] initVectorWithX:0. Y:0. Z:0.];
	__block CGFloat oldZ = -FLT_MAX;
	__block NSInteger extrusionNumber=0;
	__block Vector3* highCorner = [[Vector3 alloc] initVectorWithX:-FLT_MAX Y:-FLT_MAX Z:-FLT_MAX];
	__block Vector3* lowCorner = [[Vector3 alloc] initVectorWithX:FLT_MAX Y:FLT_MAX Z:FLT_MAX];
	[gCodeLineScanners enumerateObjectsUsingBlock:^(id scanner, NSUInteger idx, BOOL *stop) {
		NSScanner* lineScanner = (NSScanner*)scanner;
		[lineScanner setScanLocation:0];
		if([lineScanner isLayerStartWithCurrentLocation:currentLocation oldZ:&oldZ layerStartWordExists:isThereALayerStartWord])
		{
			extrusionNumber = 0;
			currentPane = [[NSMutableArray alloc] init];
			[panes addObject:currentPane];
			[currentPane release];
		}
		if([lineScanner scanString:@"G1" intoString:nil])
		{
			[lineScanner updateLocation:currentLocation];
			[currentPane addObject:[[currentLocation copy] autorelease]]; // Add the centered point
			[lowCorner minimizeWith:currentLocation];
			[highCorner maximizeWith:currentLocation];
		}
		else if([lineScanner scanString:@"M101" intoString:nil])
		{
			extrusionNumber++;
			[currentPane addObject:[extrusionColors objectAtIndex:extrusionNumber%[extrusionColors count]]];
		}
		else if([lineScanner scanString:@"M103" intoString:nil])
		{
			[currentPane addObject:(id)extrusionOffColor];
		}			
	}];
	cornerMinimum = lowCorner;
	cornerMaximum = highCorner;
	
	[currentLocation release];
		
	return panes;
}

- (id)initWithURL:(NSURL*)gCodeURL size:(CGSize)size forThumbnail:(BOOL)forThumbnail
{
	self = [super init];
	if(self)
	{
		// 'brown', 'red', 'orange', 'yellow', 'green', 'blue', 'purple'
		extrusionColors = [[NSArray alloc] initWithObjects:(id)CGColorCreateGenericRGB(0.855, 0.429, 0.002, 1.000), (id)CGColorCreateGenericRGB(1.000, 0.000, 0.000, 1.000), (id)CGColorCreateGenericRGB(1.000, 0.689, 0.064, 1.000), (id)CGColorCreateGenericRGB(1.000, 1.000, 0.000, 1.000), (id)CGColorCreateGenericRGB(0.367, 0.742, 0.008, 1.000), (id)CGColorCreateGenericRGB(0.607, 0.598, 1.000, 1.000), CGColorCreateGenericRGB(0.821, 0.000, 0.833, 1.000), nil];
		extrusionOffColor = CGColorCreateGenericRGB(0.902, 0.902, 0.902, .1);

		thumbnail = forThumbnail;
		
		othersAlpha = .75;
		
		if(thumbnail)
			renderSize = CGSizeMake(512.,512.);
		else
			renderSize = CGSizeMake(size.width*kRenderUpsizeFaktor,size.height*kRenderUpsizeFaktor);
		
		dimBuildPlattform = [[Vector3 alloc] initVectorWithX:100. Y:100. Z:0.];
		zeroBuildPlattform = [[Vector3 alloc] initVectorWithX:50. Y:50. Z:0.];

		NSError* error;
		NSString* gCode = [[NSString alloc] initWithContentsOfURL:gCodeURL encoding:NSUTF8StringEncoding error:&error];
		if(gCode)
		{
			// Create an array of linescanners
			NSMutableArray* gCodeLineScanners = [[NSMutableArray alloc] init];
			NSArray* untrimmedLines = [gCode componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
			NSCharacterSet* whiteSpaceSet = [NSCharacterSet whitespaceCharacterSet];
			[untrimmedLines enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
				[(NSMutableArray*)gCodeLineScanners addObject:[NSScanner scannerWithString:[obj stringByTrimmingCharactersInSet:whiteSpaceSet]]];
			}];
								
			self.gCodePanes = [self parseLines:gCodeLineScanners];
			
			[gCodeLineScanners release];
			
			if([gCodePanes count]>0)
			{
				NSInteger maxLayers = [self.gCodePanes count]-1;
				currentLayer=maxLayers*.7;
				//NSLog(@"%@ Parsed %d panes",gCodeURL, maxLayers);
			}
			else
			{
				NSLog(@"Error while parsing: %@",gCodeURL);
				currentLayer=0;
			}
		}
		else
			NSLog(@"Error while reading: %@: %@",gCodeURL, [error localizedDescription]);
		
		[gCode release];
		
		cameraOffset =- 1.75*MAX( dimBuildPlattform.x, dimBuildPlattform.y);
		
		rotateX = 0.;
		rotateY = -45.;
	}
	return self;
}

- (void) dealloc
{
	[gCodePanes release];

	for(id ref in extrusionColors)
		CFRelease((CGColorRef)ref);
	[extrusionColors release];
	CFRelease(extrusionOffColor);
	[dimBuildPlattform release];
	[zeroBuildPlattform release];
	
	[super dealloc];
}

- (CGImageRef)generatePreviewImage
{	
	CGImageRef cgImage=nil;
	CGLPixelFormatAttribute attribs[] = // 1
	{
		kCGLPFAOffScreen,
		kCGLPFAColorSize, 32,
		kCGLPFADepthSize, 32,
		kCGLPFAAlphaSize, 8,
		0
	} ;
	CGLPixelFormatObj pixelFormatObj;
	GLint numPixelFormats;
	CGLChoosePixelFormat (attribs, &pixelFormatObj, &numPixelFormats); // 2
	
	
	
	long bytewidth = (GLsizei)renderSize.width * 4; // Assume 4 bytes/pixel for now
	bytewidth = (bytewidth + 3) & ~3; // Align to 4 bytes
	
	/* Build bitmap context */
	void *data;
	data = malloc((GLsizei)renderSize.width * bytewidth);
	if (data == NULL) {
		return nil;
	}
	
	CGColorSpaceRef cSpace = CGColorSpaceCreateWithName (kCGColorSpaceGenericRGB);
	CGContextRef bitmap;
	bitmap = CGBitmapContextCreate(data, (GLsizei)renderSize.width, (GLsizei)renderSize.height, 8, bytewidth, cSpace, kCGImageAlphaNoneSkipFirst /* XRGB */);
	CFRelease(cSpace);

	CGLContextObj contextObj;
	CGLCreateContext (pixelFormatObj, NULL, &contextObj); // 3
	CGLDestroyPixelFormat (pixelFormatObj);
	CGLSetCurrentContext (contextObj); // 4
	void* memBuffer = (void *) malloc ((GLsizei)renderSize.width * (GLsizei)renderSize.height * 32 / 8); // 5
	CGLSetOffScreen (contextObj, (GLsizei)renderSize.width, (GLsizei)renderSize.height, (GLsizei)renderSize.width * 4, memBuffer); 
	
	glViewport(0, 0, renderSize.width, renderSize.height);
	
    glMatrixMode( GL_PROJECTION );
    glLoadIdentity();
    gluPerspective( 45.f, (GLfloat)(renderSize.width / renderSize.height), 0.1f, 1000.0f );
		
	glMatrixMode( GL_MODELVIEW );
    // Clear the framebuffer.
	if(thumbnail)
		glClearColor( 0.f, 1.f, 0.f, 1.f);
	else
		glClearColor( 0.f, 0.f, 0.f, 0.f);
    glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
	glLoadIdentity();	
	
	glEnable (GL_LINE_SMOOTH); 
	glEnable (GL_BLEND); 
	glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
//	glPolygonMode( GL_FRONT_AND_BACK, GL_LINE );
					
	glTranslatef(0.f,0.f,(GLfloat)cameraOffset);
	glRotatef((GLfloat)rotateX, 0.f, 1.f, 0.f);
	glRotatef((GLfloat)rotateY, 1.f, 0.f, 0.f);
	
	if(thumbnail)
		glColor4f(.252f, .212f, .122f, 1.f);
	else
		glColor4f(1.f, .749f, 0.f, .1f);
	glBegin(GL_QUADS);
	glVertex3f((GLfloat)-zeroBuildPlattform.x, (GLfloat)-zeroBuildPlattform.y, 0.f);
	glVertex3f((GLfloat)-zeroBuildPlattform.x, (GLfloat)dimBuildPlattform.y-(GLfloat)zeroBuildPlattform.y, 0.f);
	glVertex3f((GLfloat)dimBuildPlattform.x-(GLfloat)zeroBuildPlattform.x, (GLfloat)dimBuildPlattform.y-(GLfloat)zeroBuildPlattform.y, 0.f);
	glVertex3f((GLfloat)dimBuildPlattform.x-(GLfloat)zeroBuildPlattform.x, (GLfloat)-zeroBuildPlattform.y, 0.f);
	glEnd();
	
	glColor4f(1., 0., 0., .4);
	glBegin(GL_LINES);
	for(float x=-zeroBuildPlattform.x; x<dimBuildPlattform.x-zeroBuildPlattform.x; x+=10.f)
	{
		glVertex3f((GLfloat)x, (GLfloat)-zeroBuildPlattform.y, 0.f);
		glVertex3f((GLfloat)x, (GLfloat)dimBuildPlattform.y-(GLfloat)zeroBuildPlattform.y, 0.f);
	}
	glVertex3f((GLfloat)dimBuildPlattform.x-(GLfloat)zeroBuildPlattform.x, (GLfloat)-zeroBuildPlattform.y, 0.f);
	glVertex3f((GLfloat)dimBuildPlattform.x-(GLfloat)zeroBuildPlattform.x, (GLfloat)dimBuildPlattform.y-(GLfloat)zeroBuildPlattform.y, 0.f);
	
	for(float y=-zeroBuildPlattform.y; y<dimBuildPlattform.y-zeroBuildPlattform.y; y+=10.f)
	{
		glVertex3f((GLfloat)-zeroBuildPlattform.x, (GLfloat)y, 0.f);
		glVertex3f((GLfloat)dimBuildPlattform.x-(GLfloat)zeroBuildPlattform.x, (GLfloat)y, 0.f);
	}
	glVertex3f((GLfloat)-zeroBuildPlattform.x, (GLfloat)dimBuildPlattform.y-(GLfloat)zeroBuildPlattform.y, 0.f);
	glVertex3f((GLfloat)dimBuildPlattform.x-(GLfloat)zeroBuildPlattform.x, (GLfloat)dimBuildPlattform.y-(GLfloat)zeroBuildPlattform.y, 0.f);
	glEnd();


	NSInteger layer=0;
	for(NSArray* pane in gCodePanes)
	{
		glLineWidth((layer==currentLayer)?1.f:2.f);
		
		Vector3* lastPoint = nil;
		for(id elem in pane)
		{
			if([elem isKindOfClass:[Vector3 class]])
			{
				Vector3* point = (Vector3*)elem;
				if(lastPoint)
				{
					glBegin(GL_LINES);
					glVertex3f((GLfloat)lastPoint.x,(GLfloat)lastPoint.y, (GLfloat)lastPoint.z);
					glVertex3f((GLfloat)point.x,(GLfloat)point.y, (GLfloat)point.z);
					glEnd();
				}

				lastPoint = point;
			}
			else
			{
				const CGFloat* color = CGColorGetComponents((CGColorRef)elem);
				if(currentLayer > layer)
					glColor4f((GLfloat)color[0], (GLfloat)color[1], (GLfloat)color[2], (GLfloat)color[3]*powf((GLfloat)othersAlpha,3.f)); 
				else if(currentLayer < layer)
					glColor4f((GLfloat)color[0], (GLfloat)color[1], (GLfloat)color[2], ((GLfloat)color[3]*powf((GLfloat)othersAlpha,3.f))/(1.f+20.f*powf((GLfloat)othersAlpha, 3.f))); 
				else
					glColor4f((GLfloat)color[0], (GLfloat)color[1], (GLfloat)color[2], (GLfloat)color[3]);
			}
		}
		layer++;
	}
	
	glFlush();
	
	/* Read framebuffer into our bitmap */
	glPixelStorei(GL_PACK_ALIGNMENT, (GLint)4); /* Force 4-byte alignment */
	glPixelStorei(GL_PACK_ROW_LENGTH, (GLint)0);
	glPixelStorei(GL_PACK_SKIP_ROWS, (GLint)0);
	glPixelStorei(GL_PACK_SKIP_PIXELS, (GLint)0);
	
	/* Fetch the data in XRGB format, matching the bitmap context. */
	glReadPixels((GLint)0, (GLint)0, (GLsizei)renderSize.width, (GLsizei)renderSize.width, GL_BGRA,
				 GL_UNSIGNED_INT_8_8_8_8, // for Intel! http://lists.apple.com/archives/quartz-dev/2006/May/msg00100.html
				 data);
	swizzleBitmap(data, bytewidth, (GLsizei)renderSize.height);
	
	/* Make an image out of our bitmap; does a cheap vm_copy of the bitmap */
	cgImage = CGBitmapContextCreateImage(bitmap);
	
	/* Get rid of bitmap */
	CFRelease(bitmap);
	free(data);
	
	CGLSetCurrentContext (NULL);
	CGLClearDrawable (contextObj);
	CGLDestroyContext (contextObj);

	return cgImage;
}

@end
