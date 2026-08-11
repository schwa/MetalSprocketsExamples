#include "MetalSprocketsExampleShaders.h"

using namespace metal;

namespace MeshDissolve {

    // MeshDissolveUniforms is declared in MeshDissolveShaders.h, shared with Swift.
    using Uniforms = MeshDissolveUniforms;

    // Effect IDs (mirror MeshDissolveEffect in Swift)
    constant int EFFECT_NONE              = 0;
    constant int EFFECT_NOISE_DISSOLVE    = 1;
    constant int EFFECT_VORONOI_CHUNKS    = 4;
    constant int EFFECT_CELL_SHRINK       = 5;
    constant int EFFECT_FRACTURE          = 6;
    constant int EFFECT_CHECKERBOARD_FLIP = 7;
    constant int EFFECT_RIPPLE            = 8;
    constant int EFFECT_PIXEL_WIPE        = 9;
    constant int EFFECT_STRIPE_WIPE       = 10;
    constant int EFFECT_HEX_CELLS         = 11;
    constant int EFFECT_CRUMBLE           = 12;
    constant int EFFECT_INKBLOT           = 13;
    constant int EFFECT_VOXEL_COLLAPSE    = 14;

    // MARK: - Vertex I/O (matches SwiftMesh's interleaved layout: position + normal)

    struct VertexIn {
        float3 position [[attribute(0)]];
        float3 normal   [[attribute(1)]];
    };

    struct VertexOut {
        float4 position [[position]];
        float3 modelPos; // Object-space position (used as "world" for triplanar / dissolve)
        float3 normal;   // Object-space normal
    };

    // MARK: - Hash / noise helpers

    // Cheap 3D hash → [0,1)
    static float hash31(float3 p) {
        p = fract(p * float3(0.1031, 0.1030, 0.0973));
        p += dot(p, p.yxz + 33.33);
        return fract((p.x + p.y) * p.z);
    }

    // 3D value noise
    static float valueNoise3(float3 p) {
        float3 i = floor(p);
        float3 f = fract(p);
        float3 u = f * f * (3.0 - 2.0 * f);

        float n000 = hash31(i + float3(0, 0, 0));
        float n100 = hash31(i + float3(1, 0, 0));
        float n010 = hash31(i + float3(0, 1, 0));
        float n110 = hash31(i + float3(1, 1, 0));
        float n001 = hash31(i + float3(0, 0, 1));
        float n101 = hash31(i + float3(1, 0, 1));
        float n011 = hash31(i + float3(0, 1, 1));
        float n111 = hash31(i + float3(1, 1, 1));

        float nx00 = mix(n000, n100, u.x);
        float nx10 = mix(n010, n110, u.x);
        float nx01 = mix(n001, n101, u.x);
        float nx11 = mix(n011, n111, u.x);
        float nxy0 = mix(nx00, nx10, u.y);
        float nxy1 = mix(nx01, nx11, u.y);
        return mix(nxy0, nxy1, u.z);
    }

    // 3D cellular / voronoi-ish: returns (F1 distance, cell id)
    static float2 cells3(float3 p) {
        float3 i = floor(p);
        float3 f = fract(p);
        float minDist = 1.0;
        float cellId = 0.0;
        for (int z = -1; z <= 1; ++z) {
            for (int y = -1; y <= 1; ++y) {
                for (int x = -1; x <= 1; ++x) {
                    float3 g = float3(x, y, z);
                    float3 o = float3(hash31(i + g + 1.17),
                                      hash31(i + g + 3.71),
                                      hash31(i + g + 7.93));
                    float3 r = g + o - f;
                    float d = dot(r, r);
                    if (d < minDist) {
                        minDist = d;
                        cellId = hash31(i + g);
                    }
                }
            }
        }
        return float2(sqrt(minDist), cellId);
    }

    // MARK: - Vertex shader

    [[vertex]] VertexOut vertexMain(
        VertexIn in [[stage_in]],
        // Explicit indices: the mesh's vertex buffer occupies index 0, so
        // auto-assigned argument indices would collide with it.
        constant float4x4 &transform [[buffer(1)]],
        constant Uniforms &uniforms [[buffer(2)]]
    ) {
        constant Uniforms &u = uniforms;
        VertexOut out;
        float3 pos = in.position;

        // Crumble: displace each voronoi shard outward along its vertex normal,
        // scaled by per-cell hash and overall progress. Fragment-side still
        // discards via the shared dissolveField, so shards explode then vanish.
        if (u.effect == EFFECT_CRUMBLE) {
            float elapsed = max(0.0, u.time - u.animationStart);
            float progress = saturate(elapsed / max(u.animationDuration, 1e-4));
            float2 c = cells3(pos * 1.8);
            // Each shard gets a unique push magnitude (0.3–1.0× base).
            float jitter = 0.3 + 0.7 * c.y;
            // Shards that are still visible barely move; shards near their
            // discard threshold push hard. 1.25 matches the fragment overshoot.
            float localProgress = saturate((progress * 1.25 - c.y) * 2.0);
            float push = localProgress * jitter * 0.6;
            pos += in.normal * push;
        }

        out.position = transform * float4(pos, 1.0);
        out.modelPos = pos;
        out.normal   = in.normal;
        return out;
    }

    // MARK: - Triplanar grid

    // Sample a 2D grid pattern on the given 2D coordinate.
    // Returns a line mask: 1 on lines, 0 in cells.
    static float gridLine2D(float2 uv, float lineWidth) {
        // Distance to nearest integer cell edge, per axis, in cell units
        float2 g = abs(fract(uv - 0.5) - 0.5);
        // Anti-aliased line using fwidth
        float2 w = fwidth(uv) * 1.0;
        // Smoothstep from (lineWidth) → (lineWidth + w)
        float2 line2 = 1.0 - smoothstep(float2(lineWidth),
                                        float2(lineWidth) + w,
                                        g);
        return max(line2.x, line2.y);
    }

    // Per-cell 2D grid: returns (lineMask, cellFill) using a per-cell shrink
    // driven by `progress`. Each integer cell hashes to a threshold in [0,1];
    // once progress passes it the cell's interior winks out over a small band.
    static float2 gridLine2DShrink(float2 uv, float baseLineWidth, float progress, float hashSeed) {
        float2 cell = floor(uv);
        float t = hash31(float3(cell, hashSeed));
        // Band over which a single cell closes from open to fully winked out.
        const float band = 0.08;
        float close = smoothstep(t, t + band, progress);
        // Line width grows from base to 0.5 (cells fully closed).
        float lw = mix(baseLineWidth, 0.5, close);

        float2 g = abs(fract(uv - 0.5) - 0.5);
        float2 w = fwidth(uv);
        float2 line2 = 1.0 - smoothstep(float2(lw), float2(lw) + w, g);
        float lineMask = max(line2.x, line2.y);

        // cellFill: 1 while the cell is alive, fades to 0 as it closes.
        float cellFill = 1.0 - close;
        return float2(lineMask, cellFill);
    }

    // Triplanar grid: project p onto three axis planes and blend by |normal|.
    static float triplanarGrid(float3 p, float3 n, float cellSize, float lineWidthFrac) {
        float3 uvw = p / cellSize;
        float2 uvX = uvw.yz; // plane perpendicular to X
        float2 uvY = uvw.xz; // plane perpendicular to Y
        float2 uvZ = uvw.xy; // plane perpendicular to Z

        float lX = gridLine2D(uvX, lineWidthFrac);
        float lY = gridLine2D(uvY, lineWidthFrac);
        float lZ = gridLine2D(uvZ, lineWidthFrac);

        float3 w = abs(normalize(n));
        // Sharpen blend weights so we don't smear the grid at corners.
        w = pow(w, float3(4.0));
        w /= max(w.x + w.y + w.z, 1e-5);

        return lX * w.x + lY * w.y + lZ * w.z;
    }

    // Triplanar variant of the cell-shrink grid. Returns (lineMask, cellAlive)
    // blended across the three axis projections using the same weighting as
    // `triplanarGrid`.
    static float2 triplanarGridShrink(float3 p, float3 n, float cellSize, float lineWidthFrac, float progress) {
        float3 uvw = p / cellSize;
        float2 uvX = uvw.yz;
        float2 uvY = uvw.xz;
        float2 uvZ = uvw.xy;

        float2 rX = gridLine2DShrink(uvX, lineWidthFrac, progress, 1.17);
        float2 rY = gridLine2DShrink(uvY, lineWidthFrac, progress, 3.71);
        float2 rZ = gridLine2DShrink(uvZ, lineWidthFrac, progress, 7.93);

        float3 w = abs(normalize(n));
        w = pow(w, float3(4.0));
        w /= max(w.x + w.y + w.z, 1e-5);

        float lineMask = rX.x * w.x + rY.x * w.y + rZ.x * w.z;
        float cellAlive = rX.y * w.x + rY.y * w.y + rZ.y * w.z;
        return float2(lineMask, cellAlive);
    }

    // MARK: - Dissolve fields
    //
    // Each field returns a scalar d in roughly [0,1]:
    //   d <  progress  →  discard (dissolved)
    //   d ~= progress  →  on the leading edge (glow)
    //   d >  progress  →  still visible

    static float dissolveNoise(float3 p, float time) {
        // Low-frequency animated noise so the pattern breathes a little.
        float n = valueNoise3(p * 2.5 + float3(0, time * 0.15, 0));
        return n;
    }

    static float dissolveVoronoi(float3 p, float time) {
        float2 c = cells3(p * 3.0 + float3(0, time * 0.1, 0));
        // Use cell id as the discard threshold (stepped), with a tiny jitter
        // from F1 distance so chunks don't all pop at the exact same frame.
        return saturate(c.y + c.x * 0.15);
    }

    // Per-shard voronoi with larger cells and no animation. Each shard gets a
    // fully independent threshold, so chunks pop off in a random order instead
    // of sweeping spatially.
    static float dissolveFracture(float3 p) {
        float2 c = cells3(p * 1.8);
        return saturate(c.y);
    }

    // Grid-quantized checker: each axis-aligned cell in a coarse grid gets a
    // hashed threshold. Cells pop out independently.
    static float dissolveCheckerboard(float3 p) {
        float3 cell = floor(p * 4.0);
        return hash31(cell + 0.5);
    }

    // Ripple: concentric shells of value noise, monotonic in time. The field is
    // equivalent to noise dissolve, but we visually highlight the moving band in
    // the fragment path so it reads as an advancing wavefront.
    static float dissolveRipple(float3 p, float time) {
        float n = valueNoise3(p * 4.0 + float3(0, time * 0.2, 0));
        return n;
    }

    // Pixel wipe: quantize position into fat "pixels" and hash each pixel.
    static float dissolvePixelWipe(float3 p) {
        float3 cell = floor(p * 6.0);
        return hash31(cell + 11.3);
    }

    // Stripe wipe: per-coarse-cell stripe direction/phase; each stripe sweeps
    // across its cell, giving a "scanlines rolling through tiles" look.
    static float dissolveStripeWipe(float3 p) {
        float3 cell = floor(p * 2.5);
        float3 local = fract(p * 2.5);
        // Hash picks one of three axis-aligned stripe directions + a phase.
        float h = hash31(cell + 5.1);
        float axis = floor(h * 3.0);
        float phase = hash31(cell + 9.3);
        float coord = (axis < 0.5) ? local.x : (axis < 1.5) ? local.y : local.z;
        // Stripe threshold walks from 0 to 1 across the cell, offset by phase.
        return saturate(fract(coord + phase));
    }

    // Hex cells: F1 voronoi in a sheared lattice produces hex-like cells in 2D;
    // we apply it per triplanar plane and take the minimum so every face reads
    // as hex tiles regardless of orientation.
    static float dissolveHexCells(float3 p) {
        // Shear each plane so voronoi cells tile as hex.
        float2 xy = p.xy * 2.5; xy.x += xy.y * 0.5;
        float2 yz = p.yz * 2.5; yz.x += yz.y * 0.5;
        float2 xz = p.xz * 2.5; xz.x += xz.y * 0.5;
        float dXY = cells3(float3(xy, 0.0)).y;
        float dYZ = cells3(float3(yz, 1.7)).y;
        float dXZ = cells3(float3(xz, 3.3)).y;
        return saturate(min(min(dXY, dYZ), dXZ));
    }

    // Inkblot: FBM noise (three octaves) for wet, organic edges.
    static float dissolveInkblot(float3 p, float time) {
        float t = time * 0.1;
        float n = 0.0;
        n += valueNoise3(p * 1.5 + float3(0, t, 0)) * 0.5;
        n += valueNoise3(p * 3.0 + float3(t, 0, 0)) * 0.3;
        n += valueNoise3(p * 6.0 + float3(0, 0, t)) * 0.2;
        return saturate(n);
    }

    // Voxel collapse: quantize to fat cubes, rank them by height (bias toward
    // falling from the top). Range is large so `progress * 1.25` covers it.
    static float dissolveVoxelCollapse(float3 p) {
        float3 cell = floor(p * 3.0);
        float h = hash31(cell + 7.7);
        // Higher y cells dissolve first; soft bias so it's not strictly by layer.
        float heightBias = saturate(1.0 - (cell.y * 0.08 + 0.5));
        return saturate(heightBias * 0.7 + h * 0.3);
    }

    // Normalized [0,1] dissolve field for effects that don't care about world scale.
    static float dissolveField(int effect, float3 p, float3 n, float time) {
        switch (effect) {
            case EFFECT_NOISE_DISSOLVE:    return dissolveNoise(p, time);
            case EFFECT_VORONOI_CHUNKS:    return dissolveVoronoi(p, time);
            case EFFECT_FRACTURE:          return dissolveFracture(p);
            case EFFECT_CHECKERBOARD_FLIP: return dissolveCheckerboard(p);
            case EFFECT_RIPPLE:            return dissolveRipple(p, time);
            case EFFECT_PIXEL_WIPE:        return dissolvePixelWipe(p);
            case EFFECT_STRIPE_WIPE:       return dissolveStripeWipe(p);
            case EFFECT_HEX_CELLS:         return dissolveHexCells(p);
            case EFFECT_CRUMBLE:           return dissolveFracture(p); // shares voronoi field
            case EFFECT_INKBLOT:           return dissolveInkblot(p, time);
            case EFFECT_VOXEL_COLLAPSE:    return dissolveVoxelCollapse(p);
            default:                       return 1.0; // never dissolve
        }
    }

    // MARK: - Fragment

    [[fragment]] float4 fragmentMain(
        VertexOut in [[stage_in]],
        constant Uniforms &uniforms
    ) {
        constant Uniforms &u = uniforms;
        float3 p = in.modelPos;
        float3 n = in.normal;

        // Progress is driven entirely by the clock. When animationStart == time
        // (the idle case) progress is 0; once the user fires the animation, the
        // CPU freezes animationStart and the shader ramps progress toward 1.
        float elapsed = max(0.0, u.time - u.animationStart);
        float progress = saturate(elapsed / max(u.animationDuration, 1e-4));

        // 1) Dissolve test (scalar-field effects).
        if (u.effect != EFFECT_NONE && u.effect != EFFECT_CELL_SHRINK) {
            // Normalized [0,1] field. Overshoot to 1.25 so progress=1 fully discards.
            float d = dissolveField(u.effect, p, n, u.time);
            float threshold = progress * 1.25;
            if (d < threshold) {
                discard_fragment();
            }
        }

        // 2) Triplanar grid color. Cell-shrink effect uses a specialized path
        // that closes individual cells based on progress.
        float line;
        float cellAlive = 1.0;
        if (u.effect == EFFECT_CELL_SHRINK) {
            float p01 = saturate(progress * 1.1);
            float2 r = triplanarGridShrink(p, n, u.gridCellSize, u.gridLineWidth, p01);
            cellAlive = r.y;
            if (cellAlive < 0.01) {
                discard_fragment();
            }
            line = r.x;
        } else {
            line = triplanarGrid(p, n, u.gridCellSize, u.gridLineWidth);
        }
        float4 color = mix(u.backgroundColor, u.foregroundColor, line);

        // 3) Leading-edge glow (for effects with a meaningful edge).
        // Skip when progress == 0 so noise/voronoi don't flash edge color at idle.
        if (progress > 0.0 && u.effect != EFFECT_NONE && u.effect != EFFECT_CELL_SHRINK) {
            float d = dissolveField(u.effect, p, n, u.time);
            float threshold = progress * 1.25;
            float edge = 1.0 - smoothstep(0.0, u.edgeWidth, d - threshold);
            edge = max(edge, 0.0);
            color.rgb = mix(color.rgb, u.edgeColor.rgb, edge * u.edgeColor.a);
        } else if (progress > 0.0 && u.effect == EFFECT_CELL_SHRINK) {
            // Tint cells in the act of closing with the edge color.
            float closing = 1.0 - cellAlive;
            float edge = smoothstep(0.0, 1.0, closing) * (1.0 - smoothstep(0.85, 1.0, closing));
            color.rgb = mix(color.rgb, u.edgeColor.rgb, edge * u.edgeColor.a);
        }

        return color;
    }

} // namespace MeshDissolve
