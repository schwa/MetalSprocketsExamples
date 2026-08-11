#pragma once

#import "MetalSprocketsExampleShaders.h"

// Compiled into both the Metal shaders and the Swift module, so the layout
// can never drift between CPU and GPU.
struct MeshDissolveUniforms {
    // Current frame time in seconds.
    float time;
    // Time when the dissolve animation started. If equal to `time`, progress is 0.
    float animationStart;
    // Animation duration in seconds. progress = saturate((time - animationStart) / duration).
    float animationDuration;
    // Selected dissolve effect (MeshDissolveEffect raw value).
    int effect;
    // Grid cell size in world-space units.
    float gridCellSize;
    // Grid line width as a fraction of gridCellSize (0...0.5).
    float gridLineWidth;
    simd_float4 backgroundColor;
    simd_float4 foregroundColor;
    // Edge glow color for effects that have a leading edge.
    simd_float4 edgeColor;
    // Edge glow softness in world units.
    float edgeWidth;
};
