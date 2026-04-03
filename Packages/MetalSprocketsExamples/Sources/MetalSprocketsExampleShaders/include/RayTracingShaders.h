#pragma once

#import "MetalSprocketsExampleShaders.h"

struct RayTracingUniforms {
    simd_float3 cameraPosition;
    simd_float3 cameraForward;
    simd_float3 cameraRight;
    simd_float3 cameraUp;
    simd_float2 resolution;
    unsigned int frameIndex;
    unsigned int samplesPerPixel;
    unsigned int maxBounces;
};

// Per-triangle material data
struct TriangleMaterial {
    simd_float3 color;
    simd_float3 emission;
};
