#pragma once

#import "MetalSprocketsExampleShaders.h"

struct MetalFLIPParameters {
    unsigned int resolution;
    unsigned int capacity;
    unsigned int scene;
    float spacing;
    float maximumTimeStep;
    float flipRatio;
    float gravity;
};

// CPU view of the statistics buffer. The shaders use the same layout with atomic counters.
struct MetalFLIPStatistics {
    unsigned int maximumSpeedBits;
    unsigned int particleCount;
    float timeStep;
    float simulatedTime;
};

struct MetalFLIPCamera {
    simd_float4 origin;
    simd_float4 right;
    simd_float4 up;
    simd_float4 forward;
    // x, y: viewport size. z: tan(half field of view). w: 1 when drawing particles.
    simd_float4 viewport;
    // x: grid spacing.
    simd_float4 fluid;
};
