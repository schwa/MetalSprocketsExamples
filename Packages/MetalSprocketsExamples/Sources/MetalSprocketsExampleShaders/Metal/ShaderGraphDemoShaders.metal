#include "MetalSprocketsExampleShaders.h"

using namespace metal;

namespace ShaderGraphDemo {

    // MARK: - Vertex Shader

    struct VertexIn {
        float2 position [[attribute(0)]];
        float4 color [[attribute(1)]];
        float2 uv [[attribute(2)]];
    };

    struct VertexOut {
        float4 position [[position]];
        float4 color;
        float2 uv;
    };

    [[vertex]] VertexOut vertex_main(const VertexIn in [[stage_in]]) {
        VertexOut out;
        out.position = float4(in.position, 0.0, 1.0);
        out.color = in.color;
        out.uv = in.uv;
        return out;
    }

    // MARK: - Fragment Shader

    // Function signature: (float4 color, float2 uv, float time, float contrastAmount) -> float4
    using ColorFunction = float4(float4, float2, float, float);

    [[fragment]] float4 fragment_main(
        VertexOut in [[stage_in]],
        constant float &time [[buffer(0)]],
        constant float &contrastAmount [[buffer(1)]],
        visible_function_table<ColorFunction> colorFunction [[buffer(2)]]
    ) {
        return colorFunction[0](in.color, in.uv, time, contrastAmount);
    }

    // All shader operations are now done via pure graph operations in Swift!
    // The stdlib provides sin, cos, mix, arithmetic, swizzles, and float4 construction.

} // namespace ShaderGraphDemo
