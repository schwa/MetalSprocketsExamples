#include "MetalSprocketsExampleShaders.h"

#include <metal_imageblocks>

using namespace metal;

namespace TileAverageShader {

// ============================================================================
// MARK: - Structures
// ============================================================================

struct TileAverageUniforms {
    uint2 resolution;
    uint tileSize;
    uint _padding;
    float3x3 transform;
};

// ============================================================================
// MARK: - Imageblock Layout for Tile Memory
// ============================================================================

// Imageblock structure for tile-local memory with raster_order_group
struct TileImageblock {
    half4 color [[raster_order_group(0)]];
};

// ============================================================================
// MARK: - Vertex Shader
// ============================================================================

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut tileAverageVertex(
    uint vertexID [[vertex_id]],
    constant float2 *vertices [[buffer(0)]],
    constant TileAverageUniforms &uniforms [[buffer(1)]]
) {
    VertexOut out;

    // Apply transformation matrix
    float3 transformed = uniforms.transform * float3(vertices[vertexID], 1.0);
    out.position = float4(transformed.xy, 0.0, 1.0);

    // Convert from [-1, 1] to [0, 1] for texture coordinates
    out.texCoord = transformed.xy * 0.5 + 0.5;
    out.texCoord.y = 1.0 - out.texCoord.y; // Flip Y for texture coordinates
    return out;
}

// ============================================================================
// MARK: - Fragment Shader: Compute Per-Tile Average Color
// ============================================================================

struct FragmentOut {
    TileImageblock imageblock [[imageblock_data(TileImageblock)]];
};

// IMAGEBLOCK DEMO: Per-Tile Average Color
// This demonstrates the simplest imageblock usage:
// 1. Each tile loads its source pixels into the imageblock
// 2. The tile computes the average color of all pixels
// 3. Every pixel in that tile outputs that average color
// Result: A pixelated/mosaic effect where each block is a flat color

fragment FragmentOut tileAverageFragment(
    VertexOut in [[stage_in]],
    texture2d<half> sourceTexture [[texture(0)]],
    constant TileAverageUniforms &uniforms [[buffer(0)]],
    TileImageblock imageblockIn [[imageblock_data(TileImageblock)]],
    ushort2 pixelPositionInTile [[pixel_position_in_tile]],
    ushort2 pixelsPerTile [[pixels_per_tile]]
) {
    constexpr sampler textureSampler(
        mag_filter::linear,
        min_filter::linear,
        address::clamp_to_edge
    );

    // TILE ATTRIBUTES:
    // pixelPositionInTile: Position of this pixel within the tile (0,0) to (tileSize-1, tileSize-1)
    // pixelsPerTile: Dimensions of the tile (e.g., (16,16) or (32,32))

    // Get pixel position
    uint2 pixelPos = uint2(in.position.xy);

    // Calculate tile position
    uint2 tilePos = pixelPos / uniforms.tileSize;

    // Calculate tile bounds
    uint2 tileMin = tilePos * uniforms.tileSize;
    uint2 tileMax = min(tileMin + uniforms.tileSize, uniforms.resolution);
    uint tileWidth = tileMax.x - tileMin.x;
    uint tileHeight = tileMax.y - tileMin.y;
    uint pixelsInTile = tileWidth * tileHeight;

    // IMAGEBLOCK ACCUMULATION:
    // We're using imageblock memory, which is fast on-chip tile-local memory.
    // For this simple demo, each fragment samples all pixels in its tile to compute
    // the average. A more efficient approach would use threadgroup barriers and
    // parallel reduction, but this keeps the example straightforward.

    half4 accumulatedColor = half4(0.0);

    // Inverse transform to map screen space back to texture space
    float3x3 inverseTransform = transpose(uniforms.transform); // For rotation matrices, transpose = inverse

    for (uint y = 0; y < tileHeight; y++) {
        for (uint x = 0; x < tileWidth; x++) {
            uint2 samplePixelPos = tileMin + uint2(x, y);

            // Convert pixel position to NDC [-1, 1]
            float2 ndc = (float2(samplePixelPos) + 0.5) / float2(uniforms.resolution) * 2.0 - 1.0;
            ndc.y = -ndc.y; // Flip Y for NDC

            // Apply inverse transform to get original (pre-rotation) position
            float3 originalPos = inverseTransform * float3(ndc, 1.0);

            // Convert back to texture coordinates [0, 1]
            float2 sampleTexCoord = originalPos.xy * 0.5 + 0.5;
            sampleTexCoord.y = 1.0 - sampleTexCoord.y; // Flip Y for texture

            half4 sampleColor = sourceTexture.sample(textureSampler, sampleTexCoord);
            accumulatedColor += sampleColor;
        }
    }

    // Compute average
    half4 averageColor = accumulatedColor / half(pixelsInTile);

    FragmentOut out;
    // IMAGEBLOCK WRITE: Write the averaged color to imageblock tile memory
    out.imageblock.color = averageColor;
    return out;
}

// ============================================================================
// MARK: - Blit Shader: Imageblock to Color Attachment
// ============================================================================

// This shader reads from the imageblock and outputs to the color attachment
fragment half4 tileAverageBlitFragment(
    VertexOut in [[stage_in]],
    TileImageblock imageblockIn [[imageblock_data(TileImageblock)]],
    ushort2 pixelPositionInTile [[pixel_position_in_tile]],
    ushort2 pixelsPerTile [[pixels_per_tile]]
) {
    // Read the averaged color from the imageblock and output to framebuffer
    return imageblockIn.color;
}

} // namespace TileAverageShader
