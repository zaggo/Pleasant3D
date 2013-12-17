//
//  GCodeView.m
//  MacSkeinforge
//
//  Created by Eberhard Rensch on 04.08.09.
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

#import "GCodeView.h"
#import <OpenGL/glu.h>
#import <P3DCore/P3DCore.h>

enum {
    kLowerLayerVBO,
    kCurrentLayerVBO,
    kUpperLayerVBO,
    kArrowVBO,
    kVBOCount
};

@implementation GCodeView
{
    BOOL _objectVBONeedsRefresh;
    GLuint _vbo[kVBOCount];
}

#pragma mark - View Life Cycle
- (void)awakeFromNib
{
	[super awakeFromNib];
    _objectVBONeedsRefresh=YES;
	self.currentLayerMinZ = FLT_MAX;
	self.currentLayerMaxZ = -FLT_MAX;
    [self addObserver:self forKeyPath:@"othersAlpha" options:NSKeyValueObservingOptionNew context:NULL];
    [self addObserver:self forKeyPath:@"showArrows" options:NSKeyValueObservingOptionNew context:NULL];
    [self addObserver:self forKeyPath:@"currentLayer" options:NSKeyValueObservingOptionNew context:NULL];
    [self addObserver:self forKeyPath:@"threeD" options:NSKeyValueObservingOptionNew context:NULL];
    
    self.currentLayer = NSUIntegerMax;
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
    [super viewWillMoveToWindow:newWindow];
    if(newWindow==nil) {
        PSLog(@"OpenGL", PSPrioNormal, @"%d VBOs deleted", kVBOCount);
        [self.openGLContext makeCurrentContext]; // Ensure we're in the right OpenGL context
        glDeleteBuffers(kVBOCount, _vbo);
        bzero(_vbo, kVBOCount*sizeof(GLuint));
    }
}

- (void)dealloc
{
    [self removeObserver:self forKeyPath:@"othersAlpha"];
    [self removeObserver:self forKeyPath:@"showArrows"];
    [self removeObserver:self forKeyPath:@"currentLayer"];
    [self removeObserver:self forKeyPath:@"threeD"];
}

#pragma mark - Observers

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if([keyPath isEqualToString:@"othersAlpha"] || [keyPath isEqualToString:@"showArrows"] || [keyPath isEqualToString:@"threeD"]) {
        _objectVBONeedsRefresh=YES;
    } else if([keyPath isEqualToString:@"currentLayer"]) {
        if([_parsedGCode isKindOfClass:[P3DParsedGCodePrinter class]]) {
            if(self.currentLayer<((P3DParsedGCodePrinter*)_parsedGCode).paneIndex.count) {
                NSDictionary* paneInfo = ((P3DParsedGCodePrinter*)_parsedGCode).paneIndex[self.currentLayer];
                self.currentLayerMinZ=[paneInfo[kMinLayerZ] floatValue];
                self.currentLayerMaxZ=[paneInfo[kMaxLayerZ] floatValue];
            } else {
                self.currentLayerMinZ=FLT_MAX;
                self.currentLayerMaxZ=-FLT_MAX;
            }
        }
    }
}


#pragma mark - GUI Binding
+ (NSSet *)keyPathsForValuesAffectingCurrentZ {
    return [NSSet setWithObjects:@"currentLayerMaxZ", @"currentLayerMinZ", nil];
}

- (NSString*)currentZ
{
	NSString* currentZ = @"- mm";
	if(_currentLayerMinZ<FLT_MAX && _currentLayerMaxZ>-FLT_MAX)
	{
		NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
		[numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
		[numberFormatter setFormat:@"0.0mm;0.0mm;-0.0mm"];

		if(fabsf(_currentLayerMaxZ-_currentLayerMinZ)<0.1)
		{
			currentZ = [numberFormatter stringFromNumber:[NSNumber numberWithFloat:_currentLayerMaxZ]];
		}
		else
		{
			currentZ = [NSString stringWithFormat:@"%@ - %@",[numberFormatter stringFromNumber:[NSNumber numberWithFloat:_currentLayerMinZ]], [numberFormatter stringFromNumber:[NSNumber numberWithFloat:_currentLayerMaxZ]]];
		}
	}
	return currentZ;
}

+ (NSSet *)keyPathsForValuesAffectingMaxLayers {
    return [NSSet setWithObjects:@"parsedGCode", nil];
}

- (NSInteger)maxLayers
{
    if([_parsedGCode isKindOfClass:[P3DParsedGCodePrinter class]])
        return ((P3DParsedGCodePrinter*)_parsedGCode).paneIndex.count-1;
    return 0;
}

+ (NSSet *)keyPathsForValuesAffectingDimensionsString {
    return [NSSet setWithObjects:@"parsedGCode", nil];
}

- (Vector3*)objectDimensions
{
    return [_parsedGCode.cornerHigh sub:_parsedGCode.cornerLow];
}

+ (NSSet *)keyPathsForValuesAffectingLayerInfoString {
    return [NSSet setWithObjects:@"parsedGCode", @"currentLayer", nil];
}

- (NSString*)dimensionsString
{
	Vector3* dimension = [_parsedGCode.cornerHigh sub:_parsedGCode.cornerLow];
	
	NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
	[numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
	[numberFormatter setFormat:@"0.0mm;0.0mm;-0.0mm"];
	
	NSString* dimString = [NSString stringWithFormat:@"%@ (X) x %@ (Y) x %@ (Z)", [numberFormatter stringFromNumber:[NSNumber numberWithFloat:dimension.x]], [numberFormatter stringFromNumber:[NSNumber numberWithFloat:dimension.y]], [numberFormatter stringFromNumber:[NSNumber numberWithFloat:dimension.z]]];
	return dimString;
}

- (NSString*)layerInfoString
{
    NSString* infoString = nil;
    if(_parsedGCode) {
        NSString* infoString = NSLocalizedString(@"Layer - of -: - mm",nil);
        if([_parsedGCode isKindOfClass:[P3DParsedGCodePrinter class]]) {
            infoString = [NSString stringWithFormat: NSLocalizedString(@"Layer %d of %d: %@",nil),
                            self.currentLayer+1,
                            ((P3DParsedGCodePrinter*)_parsedGCode).paneIndex.count,
                            [self currentZ]];
        }
    }
	return infoString;
}

+ (NSSet *)keyPathsForValuesAffectingCorrectedCurrentLayer {
    return [NSSet setWithObjects:@"currentLayer", nil];
}

- (NSInteger)correctedCurrentLayer
{
	return self.currentLayer+1;
}

+ (NSSet *)keyPathsForValuesAffectingObjectWeight {
    return [NSSet setWithObjects:@"parsedGCode", nil];
}

- (CGFloat)objectWeight
{
    if([_parsedGCode isKindOfClass:[P3DParsedGCodePrinter class]])
        return [(P3DParsedGCodePrinter*)_parsedGCode objectWeight];
    return 0.f;
}

+ (NSSet *)keyPathsForValuesAffectingTotalMachiningTime {
    return [NSSet setWithObjects:@"parsedGCode", nil];
}

- (NSString*)totalMachiningTime
{
    NSString* timeString = nil;
    if([_parsedGCode isKindOfClass:[P3DParsedGCodePrinter class]]) {
        float raw = [(P3DParsedGCodePrinter*)_parsedGCode totalMachiningTime];
    
        int hours = floor(raw / 60);
        int minutes = floor(raw - hours * 60);
    
        if (hours > 0)
            timeString = [NSString stringWithFormat:NSLocalizedString(@"%d h %02d min", @"Template for total machining time"), hours, minutes];
        else
            timeString = [NSString stringWithFormat:NSLocalizedString(@"%02d min", @"Template for total machining time"), minutes];
    }
    
    return timeString;
}

+ (NSSet *)keyPathsForValuesAffectingFilamentLengthToolA {
    return [NSSet setWithObjects:@"parsedGCode", nil];
}

- (CGFloat)filamentLengthToolA
{
    if([_parsedGCode isKindOfClass:[P3DParsedGCodePrinter class]])
        return [(P3DParsedGCodePrinter*)_parsedGCode filamentLengthToolA];
    return 0.f;
}

+ (NSSet *)keyPathsForValuesAffectingFilamentLengthToolB {
    return [NSSet setWithObjects:@"parsedGCode", nil];
}

- (CGFloat)filamentLengthToolB
{
    if([_parsedGCode isKindOfClass:[P3DParsedGCodePrinter class]])
        return [(P3DParsedGCodePrinter*)_parsedGCode filamentLengthToolB];
    return 0.f;
}

+ (NSSet *)keyPathsForValuesAffectingMovementLinesCount {
    return [NSSet setWithObjects:@"parsedGCode", nil];
}

- (CGFloat)movementLinesCount
{
    if([_parsedGCode isKindOfClass:[P3DParsedGCodePrinter class]])
        return ((P3DParsedGCodePrinter*)_parsedGCode).gCodeStatistics.movementLinesCount;
    return 0.f;
}

+ (NSSet *)keyPathsForValuesAffectingLayerThickness {
    return [NSSet setWithObjects:@"parsedGCode", nil];
}

- (NSInteger)layerThickness
{
    if([_parsedGCode isKindOfClass:[P3DParsedGCodePrinter class]])
        return ((P3DParsedGCodePrinter*)_parsedGCode).layerHeight;
    return 0;
}

+ (NSSet *)keyPathsForValuesAffectingDimX {
    return [NSSet setWithObjects:@"parsedGCode", nil];
}

- (CGFloat)dimX
{
	Vector3* dimension = [_parsedGCode.cornerHigh sub:_parsedGCode.cornerLow];
	return dimension.x;
}

+ (NSSet *)keyPathsForValuesAffectingDimY {
    return [NSSet setWithObjects:@"parsedGCode", nil];
}

- (CGFloat)dimY
{
	Vector3* dimension = [_parsedGCode.cornerHigh sub:_parsedGCode.cornerLow];
	return dimension.y;
}

+ (NSSet *)keyPathsForValuesAffectingDimZ {
    return [NSSet setWithObjects:@"parsedGCode", nil];
}

- (CGFloat)dimZ
{
	Vector3* dimension = [_parsedGCode.cornerHigh sub:_parsedGCode.cornerLow];
	return dimension.z;
}

- (float)layerHeight
{
    if([_parsedGCode isKindOfClass:[P3DParsedGCodePrinter class]] && ((P3DParsedGCodePrinter*)_parsedGCode).paneIndex.count>0)
		return self.dimZ/((P3DParsedGCodePrinter*)_parsedGCode).paneIndex.count;
	return 1.f;
}

#pragma mark - GCode Setter

- (void)setParsedGCode:(P3DParsedGCodeBase*)value
{
	_parsedGCode = value;
    
    if([_parsedGCode isKindOfClass:[P3DParsedGCodePrinter class]]) {
        if(self.currentLayer>=((P3DParsedGCodePrinter*)_parsedGCode).paneIndex.count)
            self.currentLayer = ((P3DParsedGCodePrinter*)_parsedGCode).paneIndex.count-1;
    }
    
    _objectVBONeedsRefresh=YES;
	[self setNeedsDisplay:YES];
}

#pragma mark - Render OpenGL
- (void)prepareOpenGL
{
    [super prepareOpenGL];
    
    glGenBuffers(kVBOCount, _vbo);
    PSLog(@"OpenGL", PSPrioNormal, @"%d VBOs generated", kVBOCount);
    
    [self setupArrowVBOWithBufferName:_vbo[kArrowVBO]];
}

- (void)renderContent
{		
	if(_parsedGCode) {
        if([_parsedGCode isKindOfClass:[P3DParsedGCodePrinter class]])
            [self renderPrinterGCode];
    }
}

- (void)renderPrinterGCode
{
    GLint vboVerticesCount = ((P3DParsedGCodePrinter*)_parsedGCode).vertexCount;
    
    if(_objectVBONeedsRefresh) {
        PSLog(@"OpenGL", PSPrioNormal, @"objectVBONeedsRefresh");
        if(vboVerticesCount>0) {
            GLfloat* vertexBuffer = [self createVarrayForObjectVBO];
            [self setupObjectVBOWithBufferName:_vbo[kCurrentLayerVBO] vertexBuffer:vertexBuffer alphaMultiplier:1.f];
            [self setupObjectVBOWithBufferName:_vbo[kLowerLayerVBO] vertexBuffer:vertexBuffer alphaMultiplier:powf((GLfloat)self.othersAlpha,3.f)];
            [self setupObjectVBOWithBufferName:_vbo[kUpperLayerVBO] vertexBuffer:vertexBuffer alphaMultiplier:powf((GLfloat)self.othersAlpha,3.f)/(1.f+20.f*powf((GLfloat)self.othersAlpha, 3.f))];
            free(vertexBuffer);
        }
        _objectVBONeedsRefresh=NO;
    }

    if(vboVerticesCount>0) {
        NSArray* paneIndex = ((P3DParsedGCodePrinter*)_parsedGCode).paneIndex;

        glEnableClientState(GL_COLOR_ARRAY);
        glDisableClientState(GL_NORMAL_ARRAY);
        
        GLint startIndex = 0;
        GLsizei count = 0;
        const GLsizei stride = sizeof(GLfloat)*8; // RGBA + XYZW

        if(self.threeD) {
            // Draw Object
            if(self.currentLayer>0) {
                glBindBuffer(GL_ARRAY_BUFFER, _vbo[kLowerLayerVBO]);
                glColorPointer(4, GL_FLOAT, stride, (const GLvoid*)0);
                glVertexPointer(3, GL_FLOAT, stride, (const GLvoid*)(4*sizeof(GLfloat)));

                glLineWidth(1.f);
                count = (GLsizei)[paneIndex[self.currentLayer][kFirstVertexIndex] integerValue];
                glDrawArrays(GL_LINES, startIndex, count);
                startIndex += count;
            }
            
            glBindBuffer(GL_ARRAY_BUFFER, _vbo[kCurrentLayerVBO]);
            glColorPointer(4, GL_FLOAT, stride, (const GLvoid*)0);
            glVertexPointer(3, GL_FLOAT, stride, (const GLvoid*)(4*sizeof(GLfloat)));

            glLineWidth(2.f);
            if(self.currentLayer < paneIndex.count-1)
                count = (GLsizei)[paneIndex[self.currentLayer+1][kFirstVertexIndex] integerValue]-(GLsizei)startIndex;
            else
                count = (GLsizei)(vboVerticesCount-startIndex);
            glDrawArrays(GL_LINES, startIndex, count);
            startIndex += count;
            
            if(self.currentLayer<paneIndex.count-1) {
                glBindBuffer(GL_ARRAY_BUFFER, _vbo[kUpperLayerVBO]);
                glColorPointer(4, GL_FLOAT, stride, (const GLvoid*)0);
                glVertexPointer(3, GL_FLOAT, stride, (const GLvoid*)(4*sizeof(GLfloat)));
                
                glLineWidth(1.f);
                count = vboVerticesCount-startIndex;
                glDrawArrays(GL_LINES, startIndex, count);
            }
        } else {
            glBindBuffer(GL_ARRAY_BUFFER, _vbo[kCurrentLayerVBO]);
            glColorPointer(4, GL_FLOAT, stride, 0);
            glVertexPointer(3, GL_FLOAT, stride, (const GLvoid*)(4*sizeof(GLfloat)));
            
            startIndex = (GLint)[paneIndex[self.currentLayer][kFirstVertexIndex] integerValue];
            if(self.currentLayer < paneIndex.count-1)
                count = (GLsizei)[paneIndex[self.currentLayer+1][kFirstVertexIndex] integerValue]-(GLsizei)startIndex;
            else
                count = (GLsizei)(vboVerticesCount-startIndex);
            
            glLineWidth(2.f);
            glDrawArrays(GL_LINES, startIndex, count);
        }

        if(self.showArrows && self.currentLayer<paneIndex.count) {
            glDisable(GL_DEPTH_TEST);
            glDisableClientState(GL_COLOR_ARRAY);
            glBindBuffer(GL_ARRAY_BUFFER, _vbo[kArrowVBO]);
            glVertexPointer(3, GL_FLOAT, sizeof(GLfloat)*3, 0);
            
            NSInteger vertexIndex = [paneIndex[self.currentLayer][kFirstVertexIndex] integerValue]*8;
            NSInteger lastVertexIndex;
            if(self.currentLayer < paneIndex.count-1)
                lastVertexIndex = [paneIndex[self.currentLayer+1][kFirstVertexIndex] integerValue]*8;
            else
                lastVertexIndex = vboVerticesCount*8;
            GLfloat* vertexArray = ((P3DParsedGCodePrinter*)_parsedGCode).vertexArray;
            BOOL threeD = self.threeD;
            for(; vertexIndex<lastVertexIndex; vertexIndex+=16) {
                glColor4f((GLfloat)vertexArray[vertexIndex],
                          (GLfloat)vertexArray[vertexIndex+1],
                          (GLfloat)vertexArray[vertexIndex+2],
                          (GLfloat)vertexArray[vertexIndex+3]);
                
                GLfloat x1 = vertexArray[vertexIndex+4];
                GLfloat y1 = vertexArray[vertexIndex+5];
                GLfloat z1 = (threeD?vertexArray[vertexIndex+6]:0.f);
                GLfloat x2 = vertexArray[vertexIndex+12];
                GLfloat y2 = vertexArray[vertexIndex+13];
                GLfloat z2 = (threeD?vertexArray[vertexIndex+14]:0.f);
                
                glPushMatrix();
                glTranslatef((GLfloat)(x2+x1)/2.f, (GLfloat)(y2+y1)/2.f, (GLfloat)(z2+z1)/2.f);
                glRotatef((GLfloat)(180.f*atan2f((y1-y2),(x1-x2))/M_PI), 0.f, 0.f, 1.f);
                glDrawArrays(GL_TRIANGLES, 0, 3);
                glPopMatrix();
            }
            glEnable(GL_DEPTH_TEST);
        }

        glBindBuffer(GL_ARRAY_BUFFER, 0);
    }
}

- (void)setupArrowVBOWithBufferName:(GLuint)bufferName
{
    const GLfloat kArrowLen = .3f;
    const GLsizei stride = sizeof(GLfloat)*3;
    const GLint numVertices = 3;
    GLsizeiptr bufferSize = stride * numVertices;

    GLfloat* varray = (GLfloat*)malloc(bufferSize);

    NSInteger i = 0;
    varray[i++] = (GLfloat)kArrowLen;
    varray[i++] = (GLfloat)kArrowLen;
    varray[i++] = (GLfloat)0.f;
    varray[i++] = (GLfloat)-kArrowLen;
    varray[i++] = (GLfloat)0.f;
    varray[i++] = (GLfloat)0.f;
    varray[i++] = (GLfloat)kArrowLen;
    varray[i++] = (GLfloat)-kArrowLen;
    varray[i++] = (GLfloat)0.f;

    glBindBuffer(GL_ARRAY_BUFFER, bufferName);
    glBufferData(GL_ARRAY_BUFFER, bufferSize, varray, GL_STATIC_DRAW);
    PSLog(@"OpenGL", PSPrioNormal, @"setupArrowVBOWithBufferName created buffer for %d with %d vertices", bufferName, i/3);
    free(varray);
}

- (GLfloat *)createVarrayForObjectVBO {
    GLsizei vertexCount = ((P3DParsedGCodePrinter*)_parsedGCode).vertexCount;
    GLsizei vertexStride = ((P3DParsedGCodePrinter*)_parsedGCode).vertexStride;
    
    GLsizeiptr bufferSize = vertexCount*vertexStride;

    return (GLfloat*)malloc(bufferSize);
}

- (void)setupObjectVBOWithBufferName:(GLuint)bufferName vertexBuffer:(GLfloat*)vertexBuffer alphaMultiplier:(GLfloat)alphaMultiplier
{
    GLsizei vertexCount = ((P3DParsedGCodePrinter*)_parsedGCode).vertexCount;
    GLsizei vertexStride = ((P3DParsedGCodePrinter*)_parsedGCode).vertexStride;
    GLsizeiptr bufferSize = vertexCount*vertexStride;
    
    BOOL threeD=self.threeD;
    if(alphaMultiplier!=1.f || !threeD) {
        memcpy(vertexBuffer, ((P3DParsedGCodePrinter*)_parsedGCode).vertexArray, bufferSize);
        NSInteger totalVertices = vertexCount*8;
        for(NSInteger i = 0; i<totalVertices; i+=8) {
            vertexBuffer[i+3] *= alphaMultiplier;   // Adjust Alpha
            if(!threeD)
                vertexBuffer[i+6] = 0.f;            // 2D: Z == 0.f
        }
    } else {
        vertexBuffer = ((P3DParsedGCodePrinter*)_parsedGCode).vertexArray;
    }
    
    glBindBuffer(GL_ARRAY_BUFFER, bufferName);
    glBufferData(GL_ARRAY_BUFFER, bufferSize, vertexBuffer, GL_STATIC_DRAW);
    
    PSLog(@"OpenGL", PSPrioNormal, @"setupObjectVBOWithBufferName created buffer for %d with %d vertices", bufferName, vertexCount);
}

@end
