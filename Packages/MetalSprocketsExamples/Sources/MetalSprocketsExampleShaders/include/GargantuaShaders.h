#pragma once

#import "MetalSprocketsExampleShaders.h"

// Compiled into both the Metal shaders and the Swift module, so the layout
// can never drift between CPU and GPU. Fields are packed into float4s the
// same way the original app laid them out.
struct GargantuaRayUniforms {
    simd_float4 resTimeFov;   // res.xy, time, fov
    simd_float4 camPos;
    simd_float4 camTarget;
    simd_float4 p0;           // din, dout, dopMax, opNear
    simd_float4 p1;           // opFar, diskBright, starBright, skyFloor
    simd_float4 p2;           // rotSpeed, rotSign, steps, debug
};

struct GargantuaCompositeUniforms {
    simd_float4 a;            // res.xy, time, vignette
    simd_float4 b;            // grain, ca, bloomStrength, bloomRadius
};

struct GargantuaBloomUniforms {
    simd_float4 a;            // srcTexel.xy, threshold, filterRadius
};
