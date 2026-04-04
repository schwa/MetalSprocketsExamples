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
    // Light quad: centre + two edge vectors + emission
    simd_float3 lightCorner;  // one corner of the light quad
    simd_float3 lightEdge1;   // edge along one axis
    simd_float3 lightEdge2;   // edge along other axis
    simd_float3 lightEmission;
};

// Per-triangle material data
struct TriangleMaterial {
    simd_float3 color;
    simd_float3 emission;
};
