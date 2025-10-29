#pragma once

#import "Support.h" // TODO: Unsure why this is needed when MetalSprocketsAddOnsShaders.h already imports it
#import "MetalSprocketsAddOnsShaders.h"

struct AxisLinesUniforms {
    float4x4 mvpMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float2 viewportSize;
    float lineWidth; // in pixels
    float3 nudge;
    float4 xAxisColor;
    float4 yAxisColor;
    float4 zAxisColor;
};
