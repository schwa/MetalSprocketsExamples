#pragma once

#import "MetalSprocketsAddOnsShaders.h"

#import "GargantuaShaders.h"
#import "GrassShaders.h"
#import "LiquidGlassShaders.h"
#import "OpenSeaShaders.h"
#import "MeshDissolveShaders.h"
#import "MetalCanvasShaders.h"
#import "PBRShaders.h"
#import "Panorama.h"
#import "ParticleEffectsShader.h"
#import "PBRShaders.h"
#import "SDFShader.h"
#import "SpiralParticlesShader.h"
#import "RayTracingShaders.h"
#import "VoxelShaders.h"

#ifdef __OBJC__
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSBundle (Module)
+ (NSBundle *)metalSprocketsExampleShadersBundle;
@end

NS_ASSUME_NONNULL_END

#endif
