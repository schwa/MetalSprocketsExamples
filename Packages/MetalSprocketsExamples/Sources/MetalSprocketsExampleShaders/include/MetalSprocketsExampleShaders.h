#pragma once

#import "MetalSprocketsAddOnsShaders.h"

#import "BlinnPhongShaders.h"
#import "DebugShaders.h"
#import "GrassShaders.h"
#import "Lighting.h"
#import "MetalCanvasShaders.h"
#import "PBRShaders.h"
#import "Panorama.h"
#import "ParticleEffectsShader.h"
#import "PBRShaders.h"
#import "SDFShader.h"
#import "VoxelShaders.h"

#ifdef __OBJC__
#import <Foundation/Foundation.h>
@interface NSBundle (Module)
+ (NSBundle *)metalSprocketsExampleShadersBundle;
@end
#endif
