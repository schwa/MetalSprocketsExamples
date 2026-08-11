#pragma once

#import "MetalSprocketsExampleShaders.h"

#define kLiquidGlassMaxPills 8

// Compiled into both the Metal shaders and the Swift module, so the layout
// can never drift between CPU and GPU.
struct LiquidGlassUniforms {
    simd_float2 resolution;
    float time;
    unsigned int pillCount;
    float ior;
    float dispersion;
    float bevelWidth;
    float frost;
    float blend;
    simd_float4 pills[kLiquidGlassMaxPills]; // center.xy, halfSize.zw in pixels
};
