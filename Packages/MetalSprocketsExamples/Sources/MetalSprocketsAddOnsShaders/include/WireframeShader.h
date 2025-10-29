#pragma once

#import "MetalSprocketsAddOnsShaders.h"

struct WireframeUniforms {
    float4x4 modelViewProjectionMatrix;
    float4 wireframeColor;
};
