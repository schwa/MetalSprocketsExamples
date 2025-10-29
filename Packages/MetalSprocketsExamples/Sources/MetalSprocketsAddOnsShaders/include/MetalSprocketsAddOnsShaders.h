#pragma once

#ifdef __OBJC__
#import <Foundation/Foundation.h>
@interface NSBundle (MetalSprocketsAddOns)
+ (NSBundle *)metalSprocketsAddOnsShadersBundle;
@end
#endif

#ifdef __METAL_VERSION__
#import <metal_stdlib>
#include <metal_uniform>
#endif

#import <simd/simd.h>

#import "AxisLines.h"
#import "Boxes.h"
#import "ColorSource.h"
#import "EdgeRenderingShaders.h"
#import "FlatShader.h"
#import "GraphicsContext3DShaders.h"
#import "Support.h"
#import "TextureBillboard.h"
#import "TexturedQuad3D.h"
#import "WireframeShader.h"
#import "GridShader.h"
#import "LambertianShader.h"
