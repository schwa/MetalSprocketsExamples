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

        float diffuse = saturate(dot(n, l));
        // Hemisphere ambient: sky from above, ground bounce from below.
        float3 ambient = mix(float3(0.18, 0.16, 0.12), float3(0.35, 0.42, 0.55), n.y * 0.5 + 0.5);
        // Back-lit leaves glow a little, like light passing through them.
        float translucency = saturate(dot(-v, l)) * 0.3;

        float3 color = in.color * (ambient + (diffuse + translucency) * float3(1.0, 0.95, 0.85) * 1.6);
        return float4(color, 1.0);
    }
}
