#pragma once

#import "MetalSprocketsExampleShaders.h"

// Interleaved vertex shared by bark tubes and leaf quads.
// simd_float3 is 16 bytes on both CPU and GPU: offsets 0, 16, 32; stride 48.
struct TreeVertex {
    simd_float3 position;
    simd_float3 normal;
    simd_float3 color;
};

struct TreeGeneratorUniforms {
    simd_float4x4 viewProjection;
    simd_float3 lightDirection;
    simd_float3 cameraPosition;
};
