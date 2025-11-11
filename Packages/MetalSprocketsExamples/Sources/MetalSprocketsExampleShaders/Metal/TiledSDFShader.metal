#include "MetalSprocketsExampleShaders.h"

#include <metal_imageblocks>

using namespace metal;

namespace TiledSDFShader {

// ============================================================================
// MARK: - Structures
// ============================================================================

struct SDFPrimitive {
    uint type;              // 0 = circle, 1 = line, 2 = quadratic bezier
    uint _padding0;
    uint _padding1;
    uint _padding2;
    float2 p0;              // Circle: center, Line/Bezier: start
    float2 p1;              // Circle: (radius, 0), Line: end, Bezier: control
    float2 p2;              // Circle: unused, Line: (width, 0), Bezier: end
    float2 _padding3;
    float3 color;
    float _padding4;
    float4 bbox;            // min_x, min_y, max_x, max_y
};

struct TiledSDFUniforms {
    uint2 resolution;
    uint tileSize;
    uint tilesX;
    uint tilesY;
    uint primitiveCount;
    uint maxPrimitivesPerTile;
    uint visualMode;
    float time;
    float3 _padding;
};

// ============================================================================
// MARK: - SDF Distance Functions
// ============================================================================

// Signed distance to circle
float sdCircle(float2 p, float2 center, float radius) {
    return length(p - center) - radius;
}

// Distance to line segment
float sdLineSegment(float2 p, float2 a, float2 b, float width) {
    float2 pa = p - a;
    float2 ba = b - a;
    float h = saturate(dot(pa, ba) / dot(ba, ba));
    float dist = length(pa - ba * h);
    return dist - width * 0.5;
}

// Distance to quadratic Bezier curve (approximation)
float sdQuadraticBezier(float2 p, float2 p0, float2 p1, float2 p2) {
    // Simple approximation: subdivide into line segments
    const int segments = 8;
    float minDist = 1e10;

    for (int i = 0; i < segments; i++) {
        float t0 = float(i) / float(segments);
        float t1 = float(i + 1) / float(segments);

        float2 a = mix(mix(p0, p1, t0), mix(p1, p2, t0), t0);
        float2 b = mix(mix(p0, p1, t1), mix(p1, p2, t1), t1);

        float2 pa = p - a;
        float2 ba = b - a;
        float h = saturate(dot(pa, ba) / dot(ba, ba));
        float dist = length(pa - ba * h);
        minDist = min(minDist, dist);
    }

    return minDist - 2.0; // Fixed width
}

// Evaluate distance for any primitive type
float evaluatePrimitive(float2 p, SDFPrimitive prim) {
    if (prim.type == 0) {
        // Circle
        return sdCircle(p, prim.p0, prim.p1.x);
    } else if (prim.type == 1) {
        // Line segment
        return sdLineSegment(p, prim.p0, prim.p1, prim.p2.x);
    } else if (prim.type == 2) {
        // Quadratic Bezier
        return sdQuadraticBezier(p, prim.p0, prim.p1, prim.p2);
    }
    return 1e10; // Very large distance for unknown types
}

// ============================================================================
// MARK: - Tile Culling Kernel
// ============================================================================

kernel void cullPrimitivesToTiles(
    constant SDFPrimitive *primitives [[buffer(0)]],
    device uint *tilePrimitives [[buffer(1)]],
    device atomic_uint *tilePrimitiveCounts [[buffer(2)]],
    constant TiledSDFUniforms &uniforms [[buffer(3)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= uniforms.primitiveCount) {
        return;
    }

    SDFPrimitive prim = primitives[gid];

    // Get primitive bounding box
    float minX = prim.bbox.x;
    float minY = prim.bbox.y;
    float maxX = prim.bbox.z;
    float maxY = prim.bbox.w;

    // Skip invalid primitives
    if (minX >= maxX || minY >= maxY) {
        return;
    }

    // Convert to tile coordinates
    uint tileMinX = max(0, int(minX) / int(uniforms.tileSize));
    uint tileMinY = max(0, int(minY) / int(uniforms.tileSize));
    uint tileMaxX = min(uniforms.tilesX - 1, uint(maxX) / uniforms.tileSize);
    uint tileMaxY = min(uniforms.tilesY - 1, uint(maxY) / uniforms.tileSize);

    // Add primitive to all overlapping tiles
    for (uint ty = tileMinY; ty <= tileMaxY; ty++) {
        for (uint tx = tileMinX; tx <= tileMaxX; tx++) {
            uint tileIndex = ty * uniforms.tilesX + tx;

            // Atomic increment to get slot in tile's primitive list
            uint slot = atomic_fetch_add_explicit(
                &tilePrimitiveCounts[tileIndex],
                1,
                memory_order_relaxed
            );

            // Only store if within limit
            if (slot < uniforms.maxPrimitivesPerTile) {
                uint writeIndex = tileIndex * uniforms.maxPrimitivesPerTile + slot;
                tilePrimitives[writeIndex] = gid;
            }
        }
    }
}

// ============================================================================
// MARK: - Imageblock Layout for Tile Memory
// ============================================================================

// Imageblock structure for tile-local memory with raster_order_group
struct TileImageblock {
    half4 color [[raster_order_group(0)]];
};

// ============================================================================
// MARK: - Tile-Based Fragment Shader with Imageblock
// ============================================================================

struct VertexOut {
    float4 position [[position]];
    float2 pixelCoord;
};

struct FragmentOut {
    TileImageblock imageblock [[imageblock_data(TileImageblock)]];
};

vertex VertexOut sdfVertex(
    uint vertexID [[vertex_id]],
    constant float2 *vertices [[buffer(0)]],
    constant TiledSDFUniforms &uniforms [[buffer(1)]]
) {
    VertexOut out;
    out.position = float4(vertices[vertexID], 0.0, 1.0);
    // Convert from [-1, 1] to pixel coordinates
    out.pixelCoord = (vertices[vertexID] * 0.5 + 0.5) * float2(uniforms.resolution);
    out.pixelCoord.y = float(uniforms.resolution.y) - out.pixelCoord.y; // Flip Y
    return out;
}

// IMAGEBLOCK DEMO: Fragment shader using explicit tile memory (imageblock)
// This keeps all color data in on-chip tile memory until the tile is complete
// Using [[imageblock_data]] for explicit imageblock layout with raster_order_group
fragment FragmentOut sdfFragment(
    VertexOut in [[stage_in]],
    constant SDFPrimitive *primitives [[buffer(0)]],
    constant uint *tilePrimitives [[buffer(1)]],
    constant uint *tilePrimitiveCounts [[buffer(2)]],
    constant TiledSDFUniforms &uniforms [[buffer(3)]],
    TileImageblock imageblockIn [[imageblock_data(TileImageblock)]],
    ushort2 pixelPositionInTile [[pixel_position_in_tile]],
    ushort2 pixelsPerTile [[pixels_per_tile]]
) {
    uint2 pixelPos = uint2(in.pixelCoord);

    FragmentOut out;

    if (pixelPos.x >= uniforms.resolution.x || pixelPos.y >= uniforms.resolution.y) {
        half4 red = half4(1.0, 0.0, 0.0, 1.0);
        out.imageblock.color = red;
        return out;
    }

    // Calculate tile index from pixel position
    uint2 tilePos = pixelPos / uniforms.tileSize;
    uint tileIndex = tilePos.y * uniforms.tilesX + tilePos.x;

    // Get number of primitives in this tile
    uint count = tilePrimitiveCounts[tileIndex];
    count = min(count, uniforms.maxPrimitivesPerTile);

    // Evaluate SDF at this pixel by reading primitives from device memory
    // (Note: fragment shaders can't use threadgroup memory, but the imageblock
    // keeps output in tile memory, avoiding framebuffer writes until tile complete)
    float2 pixelPosFloat = float2(pixelPos);
    float minDist = 1e10;
    float3 closestColor = float3(0.0);

    // Only evaluate SDF if we have primitives
    if (count > 0) {
        // Iterate through tile's primitives
        for (uint i = 0; i < count; i++) {
            uint primIndex = tilePrimitives[tileIndex * uniforms.maxPrimitivesPerTile + i];
            SDFPrimitive prim = primitives[primIndex];
            float dist = evaluatePrimitive(pixelPosFloat, prim);

            if (dist < minDist) {
                minDist = dist;
                closestColor = prim.color;
            }
        }
    }

    // Visualization based on mode
    half4 color;

    if (uniforms.visualMode == 0) {
        // Normal rendering: show shapes with smooth edges on background
        float alpha = 1.0 - smoothstep(-1.0, 1.0, minDist);

        // Background color
        half3 backgroundColor = half3(0.1, 0.1, 0.15);

        // Blend shape color over background
        half3 finalColor = mix(backgroundColor, half3(closestColor), half(alpha));
        color = half4(finalColor, 1.0);
    } else if (uniforms.visualMode == 1) {
        // Distance field visualization with background
        if (minDist < 1e9) {  // Only if we found a primitive
            float dist = abs(minDist);
            float normalizedDist = saturate(dist / 50.0);

            // Create isolines
            float isoline = fract(dist / 5.0);
            isoline = smoothstep(0.4, 0.5, isoline) - smoothstep(0.5, 0.6, isoline);

            float3 distColor = float3(normalizedDist, 1.0 - normalizedDist, 0.5);
            distColor = mix(distColor, float3(1.0), isoline);

            color = half4(half3(distColor), 1.0);
        } else {
            // Background for areas with no primitives
            color = half4(0.1, 0.1, 0.15, 1.0);
        }
    } else if (uniforms.visualMode == 2) {
        // Contour lines visualization with background
        if (minDist < 1e9) {  // Only if we found a primitive
            float contourSpacing = 8.0; // Distance between contour lines
            float contourWidth = 1.5;   // Width of contour lines

            // Create sharp contour lines
            float contour = abs(fract(minDist / contourSpacing + 0.5) - 0.5) * 2.0;
            float contourLine = 1.0 - smoothstep(0.0, contourWidth / contourSpacing, contour);

            // Color inside/outside differently
            float alpha = 1.0 - smoothstep(-1.0, 1.0, minDist);
            float3 insideColor = closestColor * 0.3; // Dimmed shape color inside
            float3 outsideColor = float3(0.95); // Light gray outside

            float3 baseColor = mix(outsideColor, insideColor, alpha);
            float3 finalColor = mix(baseColor, float3(0.0), contourLine); // Black contour lines

            // Add a subtle gradient based on distance
            float gradient = smoothstep(0.0, 30.0, abs(minDist));
            finalColor = mix(finalColor, finalColor * 0.7, gradient * 0.3);

            color = half4(half3(finalColor), 1.0);
        } else {
            // Background for areas with no primitives
            color = half4(0.1, 0.1, 0.15, 1.0);
        }
    } else {
        // Tile visualization with background
        uint2 tilePos = pixelPos / uniforms.tileSize;
        float3 tileColor = float3(
            float(tilePos.x % 3) / 2.0,
            float(tilePos.y % 3) / 2.0,
            float((tilePos.x + tilePos.y) % 2)
        );

        // Show tile boundaries
        uint2 pixelInTile = pixelPos % uniforms.tileSize;
        float border = 0.0;
        if (pixelInTile.x == 0 || pixelInTile.y == 0 ||
            pixelInTile.x == uniforms.tileSize - 1 || pixelInTile.y == uniforms.tileSize - 1) {
            border = 1.0;
        }

        // Show primitive count as brightness modulation
        float densityFactor = float(count) / float(uniforms.maxPrimitivesPerTile);
        float3 baseColor = tileColor * 0.3 * (0.5 + 0.5 * densityFactor);

        if (minDist < 1e9) {  // If we have primitives
            // Blend with shape rendering
            float alpha = 1.0 - smoothstep(-1.0, 1.0, minDist);
            float3 shapeColor = closestColor * alpha;
            float3 finalColor = mix(baseColor, shapeColor, alpha);
            finalColor = mix(finalColor, float3(1.0), border * 0.5);

            color = half4(half3(finalColor), 1.0);
        } else {
            // No primitives - just show tile pattern with borders
            float3 finalColor = mix(baseColor, float3(1.0), border * 0.5);
            color = half4(half3(finalColor), 1.0);
        }
    }

    // IMAGEBLOCK WRITE: Write color to imageblock tile memory
    // The imageblock stays in fast tile memory throughout the rendering pass
    // The raster_order_group ensures proper ordering within the tile
    out.imageblock.color = color;
    return out;
}

// ============================================================================
// MARK: - Final Blit Shader (Imageblock to Color Attachment)
// ============================================================================

// This shader reads from the imageblock and outputs to the color attachment
// It runs as a final full-screen pass after all SDF evaluation is complete
fragment half4 sdfBlitFragment(
    VertexOut in [[stage_in]],
    TileImageblock imageblockIn [[imageblock_data(TileImageblock)]],
    ushort2 pixelPositionInTile [[pixel_position_in_tile]],
    ushort2 pixelsPerTile [[pixels_per_tile]]
) {
    // Read the color from the imageblock and output to color attachment
    // This is when the tile memory data finally gets written to the framebuffer
    return imageblockIn.color;
}

} // namespace TiledSDFShader
