#pragma once

#import "MetalSprocketsExampleShaders.h"

// Uniforms for panorama rendering
struct PanoramaUniforms {
    int showMS;            // 0 = show texture, 1 = show MS coordinates as colors
    float3 cameraLocation; // Camera location in model space
    float rotation;        // Panorama rotation in radians
};
