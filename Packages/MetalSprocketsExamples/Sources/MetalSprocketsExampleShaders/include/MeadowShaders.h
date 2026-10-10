#pragma once

#import "MetalSprocketsExampleShaders.h"

struct MeadowUniforms {
    simd_float4 origin;
    simd_float4 forward;
    simd_float4 right;
    simd_float4 up;
    // xyz: direction to the sun, w: sun intensity.
    simd_float4 sun;
    // x: haze, y: cloud coverage, z: cloud time, w: exposure.
    simd_float4 atmosphere;
    // x: frame index, y: accumulated sample count.
    simd_uint4 frame;
};
