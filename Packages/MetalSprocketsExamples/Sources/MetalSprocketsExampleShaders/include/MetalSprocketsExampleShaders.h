#pragma once

#if defined(METAL) || defined(__OBJC__)
#import "MetalSprocketsAddOnsShaders.h"
#endif

#import "BlinnPhongShaders.h"
#import "DebugShaders.h"
#import "GrassShaders.h"
#import "MetalCanvasShaders.h"
#import "PBRShaders.h"
#import "Panorama.h"
#import "ParticleEffectsShader.h"
#import "SDFShader.h"
#import "Support.h"
#import "VoxelShaders.h"

#ifdef __OBJC__
#import <Foundation/Foundation.h>
@interface NSBundle (Module)
+ (NSBundle *)metalSprocketsExampleShadersBundle;
@end
#endif
