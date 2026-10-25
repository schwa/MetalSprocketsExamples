#pragma once

#import "MetalSprocketsExampleShaders.h"

struct CloudUniforms {
    simd_float4x4 inverseViewProjection;
    simd_float3 cameraPosition;
    simd_float3 sunDirection;
    float time;
    float density;
    float split;            // 0...1 screen x; left of it is ray marched, right is path traced
    int mode;               // 0 = emissive (absorption + emission), 1 = lit (scattering)
    int samplesPerPixel;
    int maxBounces;
    int tricubic;                   // 1 = tricubic B-spline density sampling, 0 = trilinear
    int chromatic;                  // 1 = wavelength-dependent extinction (Lit mode only)
    unsigned int frameIndex;        // RNG seed
    int resetAccumulation;          // 1 discards the accumulation texture's contents
};
