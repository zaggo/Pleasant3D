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
    
    NSNumberFormatter *_layerZFormatter;
}

#pragma mark - View Life Cycle
- (void)awakeFromNib
{
	[super awakeFromNib];
    _objectVBONeedsRefresh=YES;
    [self addObserver:self forKeyPath:@"othersAlpha" options:NSKeyValueObservingOptionNew context:NULL];
    [self addObserver:self forKeyPath:@"showArrows" options:NSKeyValueObservingOptionNew context:NULL];
    [self addObserver:self forKeyPath:@"threeD" options:NSKeyValueObservingOptionNew context:NULL];
    
    self.currentLayer = NSUIntegerMax;
    
    _layerZFormatter = [[NSNumberFormatter alloc] init];
    [_layerZFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [_layerZFormatter setFormat:@"0.0mm;0.0mm;-0.0mm"];
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
    }
}


#pragma mark - GUI Binding
+ (NSSet *)keyPathsForValuesAffectingCurrentZ {
    return [NSSet setWithObjects:@"currentLayer", @"parsedGCode", nil];
}

- (NSString*)currentZ
{
	NSString* currentZ = nil;
    if([_parsedGCode isKindOfClass:[P3DParsedGCodePrinter class]]) {
        currentZ = @"- mm";
        if(self.currentLayer<_parsedGCode.vertexIndex.count) {
            NSDictionary* infoDict = _parsedGCode.vertexIndex[self.currentLayer];
            if(infoDict[kMinLayerZ] && infoDict[kMaxLayerZ]) {
                float minZ = [infoDict[kMinLayerZ] floatValue];
                float maxZ = [infoDict[kMaxLayerZ] floatValue];

                if(fabsf(maxZ-minZ)<.1f)
                    currentZ = [_layerZFormatter stringFromNumber:infoDict[kMaxLayerZ]];
                else
                    currentZ = [NSString stringWithFormat:@"%@ - %@",
                                    [_layerZFormatter stringFromNumber:infoDict[kMinLayerZ]],
                                    [_layerZFormatter stringFromNumber:infoDict[kMaxLayerZ]]];
            }
        }
    } else if([_parsedGCode isKindOfClass:[P3DParsedGCodeMill class]]) {
        currentZ = @"- m : - s";
        if(self.currentLayer<_parsedGCode.vertexIndex.count) {
            NSDictionary* infoDict = _parsedGCode.vertexIndex[self.currentLayer];
            
            NSTimeInterval raw = (NSTimeInterval)[infoDict[kTimestamp] floatValue];
            NSInteger minutes = floorf(raw / 60.f);
            NSInteger seconds = floorf(raw - (NSTimeInterval)minutes * 60.f);
            
            if (minutes > 0)
                currentZ = [NSString stringWithFormat:NSLocalizedString(@"%d m : %02d s", @"Template for total current machining time"), minutes, seconds];
            else
                currentZ = [NSString stringWithFormat:NSLocalizedString(@"%02d s", @"Template for total current machining time"), seconds];
        }
    }
    
	return currentZ;
}

+ (NSSet *)keyPathsForValuesAffectingMaxLayers {
    return [NSSet setWithObjects:@"parsedGCode", nil];
}

- (NSInteger)maxLayers
{
    return _parsedGCode.vertexIndex.count-1;
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

+ (NSSet *)keyPathsForValuesAffectingCorrectedCurrentLayer {
    return [NSSet setWithObjects:@"parsedGCode", @"currentLayer", nil];
}

- (NSInteger)correctedCurrentLayer
{
    if([_parsedGCode isKindOfClass:[P3DParsedGCodePrinter class]])
        return self.currentLayer+1;
    return (NSInteger)((float)self.currentLayer/(float)(_parsedGCode.vertexIndex.count-1)*100.f);
}

+ (NSSet *)keyPathsForValuesAffectingCorrectedMaxLayers {
    return [NSSet setWithObjects:@"parsedGCode", nil];
}

- (NSInteger)correctedMaxLayers
{
    if([_parsedGCode isKindOfClass:[P3DParsedGCodePrinter class]])
        return _parsedGCode.vertexIndex.count+1;
    else
        return 100;
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
    
        NSInteger hours = floorf(raw / 60.f);
        NSInteger minutes = floorf(raw - (float)hours * 60.f);
    
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

- (NSArray*)parsingErrors {
    return _parsedGCode.parsingErrors;
}

- (IBAction)showParsingErrors:(id)sender
{
    NSLog(@"Parsing Errors: %@", self.parsingErrors);
}

#pragma mark - GCode Setter

- (void)setParsedGCode:(P3DParsedGCodeBase*)value
{
	_parsedGCode = value;
    if(self.currentLayer>=_parsedGCode.vertexIndex.count)
        self.currentLayer = _parsedGCode.vertexIndex.count-1;
    
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
        GLint vboVerticesCount = _parsedGCode.vertexCount;
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
            glEnableClientState(GL_COLOR_ARRAY);
            glDisableClientState(GL_NORMAL_ARRAY);
            
            GLint startIndex = 0;
            GLsizei count = 0;
            const GLsizei stride = _parsedGCode.vertexStride;
            
            if(self.threeD) {
                // Draw Object
                if(self.currentLayer>0) {
                    glBindBuffer(GL_ARRAY_BUFFER, _vbo[kLowerLayerVBO]);
                    glColorPointer(4, GL_FLOAT, stride, (const GLvoid*)0);
                    glVertexPointer(3, GL_FLOAT, stride, (const GLvoid*)(4*sizeof(GLfloat)));
                    
                    glLineWidth(1.f);
                    count = (GLsizei)[_parsedGCode.vertexIndex[self.currentLayer][kFirstVertexIndex] integerValue];
                    glDrawArrays(GL_LINES, startIndex, count);
                    startIndex += count;
                }
                
                glBindBuffer(GL_ARRAY_BUFFER, _vbo[kCurrentLayerVBO]);
                glColorPointer(4, GL_FLOAT, stride, (const GLvoid*)0);
                glVertexPointer(3, GL_FLOAT, stride, (const GLvoid*)(4*sizeof(GLfloat)));
                
                glLineWidth(2.f);
                if(self.currentLayer < _parsedGCode.vertexIndex.count-1)
                    count = (GLsizei)[_parsedGCode.vertexIndex[self.currentLayer+1][kFirstVertexIndex] integerValue]-(GLsizei)startIndex;
                else
                    count = (GLsizei)(vboVerticesCount-startIndex);
                glDrawArrays(GL_LINES, startIndex, count);
                startIndex += count;
                
                if(self.currentLayer<_parsedGCode.vertexIndex.count-1) {
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
                
                startIndex = (GLint)[_parsedGCode.vertexIndex[self.currentLayer][kFirstVertexIndex] integerValue];
                if(self.currentLayer < _parsedGCode.vertexIndex.count-1)
                    count = (GLsizei)[_parsedGCode.vertexIndex[self.currentLayer+1][kFirstVertexIndex] integerValue]-(GLsizei)startIndex;
                else
                    count = (GLsizei)(vboVerticesCount-startIndex);
                
                glLineWidth(2.f);
                glDrawArrays(GL_LINES, startIndex, count);
            }
            
            if(self.showArrows && self.currentLayer<_parsedGCode.vertexIndex.count) {
                glDisable(GL_DEPTH_TEST);
                glDisableClientState(GL_COLOR_ARRAY);
                glBindBuffer(GL_ARRAY_BUFFER, _vbo[kArrowVBO]);
                glVertexPointer(3, GL_FLOAT, sizeof(GLfloat)*3, 0);
                
                NSInteger vertexIndex = [_parsedGCode.vertexIndex[self.currentLayer][kFirstVertexIndex] integerValue]*8;
                NSInteger lastVertexIndex;
                if(self.currentLayer < _parsedGCode.vertexIndex.count-1)
                    lastVertexIndex = [_parsedGCode.vertexIndex[self.currentLayer+1][kFirstVertexIndex] integerValue]*8;
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
