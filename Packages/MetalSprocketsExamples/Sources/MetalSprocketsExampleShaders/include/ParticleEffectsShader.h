#pragma once

#import "MetalSprocketsExampleShaders.h"

struct Particle {
    simd_float3 position;
    simd_float3 velocity;
    simd_float3 color;
    float life;
    float size;
};

struct ParticleUniforms {
    simd_float4x4 viewMatrix;
    simd_float4x4 projectionMatrix;
    float time;
    float _padding1[3]; // Align to 16 bytes
    simd_float3 gravity;
    float baseSize;
};

struct ParticleEmitterParams {
    simd_float3 position;
    int emitterType;
    float emissionRate;
    float time;
};
