#pragma once

#import "MetalSprocketsExampleShaders.h"

struct SpiralParticleData {
    simd_float3 position;
    simd_float3 color;
    float size;
    float rotation;
};

struct SpiralParticleUniforms {
    simd_float4x4 viewProjectionMatrix;
    float time;
    uint32_t trianglesPerSpiral;
};

struct SpiralParticleObjectPayload {
    uint32_t particleIndex;
};
