#include <metal_stdlib>
using namespace metal;

namespace DepthTextureView {

    struct VertexOut {
        float4 position [[position]];
        float2 texCoord;
    };

    // Fullscreen triangle — 3 vertices, no vertex buffer needed
    [[vertex]] VertexOut vertex_main(uint vertexID [[vertex_id]]) {
        float2 positions[] = { float2(-1, -1), float2(3, -1), float2(-1, 3) };
        float2 texCoords[] = { float2(0, 1), float2(2, 1), float2(0, -1) };
        VertexOut out;
        out.position = float4(positions[vertexID], 0, 1);
        out.texCoord = texCoords[vertexID];
        return out;
    }

    [[fragment]] float4 fragment_main(
        VertexOut in [[stage_in]],
        depth2d<float, access::sample> depthTexture [[texture(0)]],
        sampler textureSampler [[sampler(0)]]
    ) {
        float depth = depthTexture.sample(textureSampler, in.texCoord);
        return float4(depth, depth, depth, 1.0);
    }

}
