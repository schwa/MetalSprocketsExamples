#pragma once

#import "MetalSprocketsExampleShaders.h"

// Compiled into both the Metal shaders and the Swift module, so the layout
// can never drift between CPU and GPU.
struct OpenSeaUniforms {
    simd_float4x4 viewProjection;
    simd_float4x4 inverseViewProjection;
    simd_float3 cameraPosition;
    simd_float3 sunDirection;
    simd_float3 sunColor;
    simd_float3 horizonColor;
    simd_float3 zenithColor;
    simd_float3 deepColor;
    simd_float3 shallowColor;
    float time;
    float sea;
    unsigned int ringSpokes;
    float ringInnerRadius;
    float ringGrowth;
    simd_float2 gridCenter;
};
