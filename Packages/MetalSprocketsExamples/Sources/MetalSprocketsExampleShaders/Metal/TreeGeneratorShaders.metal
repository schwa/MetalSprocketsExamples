#include "MetalSprocketsExampleShaders.h"

using namespace metal;

namespace TreeGenerator {

    struct VertexIn {
        float3 position [[attribute(0)]];
        float3 normal   [[attribute(1)]];
        float3 color    [[attribute(2)]];
    };

    struct VertexOut {
        float4 position [[position]];
        float3 worldPosition;
        float3 normal;
        float3 color;
    };

    [[vertex]] VertexOut vertexMain(
        VertexIn in [[stage_in]],
        // The vertex buffer occupies index 0.
        constant TreeGeneratorUniforms &uniforms [[buffer(1)]]
    ) {
        VertexOut out;
        out.position = uniforms.viewProjection * float4(in.position, 1.0);
        out.worldPosition = in.position;
        out.normal = in.normal;
        out.color = in.color;
        return out;
    }

    [[fragment]] float4 fragmentMain(
        VertexOut in [[stage_in]],
        bool frontFacing [[front_facing]],
        constant TreeGeneratorUniforms &uniforms
    ) {
        // Leaves are single-sided quads, so light both faces.
        float3 n = normalize(in.normal) * (frontFacing ? 1.0 : -1.0);
        float3 l = normalize(uniforms.lightDirection);
        float3 v = normalize(uniforms.cameraPosition - in.worldPosition);

        // Wrapped diffuse keeps the shadow side of thin tubes from going black.
        float diffuse = saturate((dot(n, l) + 0.3) / 1.3);
        float3 sunColor = float3(1.0, 0.92, 0.78) * 2.2;
        // Hemisphere ambient: sky from above, ground bounce from below.
        float3 ambient = mix(float3(0.22, 0.20, 0.17), float3(0.55, 0.65, 0.80), n.y * 0.5 + 0.5);
        // Back-lit leaves glow a little, like light passing through them.
        float translucency = pow(saturate(dot(-v, l)), 4.0) * 0.5;
        // Soft sky rim along silhouettes.
        float rim = pow(1.0 - saturate(dot(n, v)), 3.0) * 0.25;

        float3 color = in.color * (ambient + (diffuse + translucency) * sunColor) + rim * float3(0.55, 0.65, 0.80) * in.color * 2.0;
        // Reinhard tone map, then gamma encode: the drawable is not sRGB.
        color = color / (1.0 + color);
        color = pow(color, 1.0 / 2.2);
        return float4(color, 1.0);
    }
}
