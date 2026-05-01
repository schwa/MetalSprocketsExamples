#include "MetalSprocketsExampleShaders.h"

using namespace metal;

// Jos Stam's "Real-Time Fluid Dynamics for Games" (GDC 2003)
// GPU implementation using 2D textures (r32Float).
//
// Grid is (N+2)×(N+2) with a 1-cell boundary layer.
// Interior cells are [1..N] × [1..N].

namespace StamFluidShader {

    struct FluidParams {
        uint N;          // grid resolution (interior cells per side)
        float dt;        // time step
        float diff;      // diffusion rate
        float visc;      // viscosity
    };

    // --- Add source: x += dt * s ---
    kernel void addSource(texture2d<float, access::read_write> x [[texture(0)]],
                          texture2d<float, access::read> s [[texture(1)]],
                          constant FluidParams &params [[buffer(0)]],
                          uint2 gid [[thread_position_in_grid]]) {
        uint2 texSize = uint2(x.get_width(), x.get_height());
        if (gid.x >= texSize.x || gid.y >= texSize.y) return;

        float val = x.read(gid).r + params.dt * s.read(gid).r;
        x.write(float4(val, 0, 0, 0), gid);
    }

    // --- Gauss-Seidel relaxation (one red-black iteration) ---
    kernel void diffuseRedBlack(texture2d<float, access::read_write> x [[texture(0)]],
                                texture2d<float, access::read> x0 [[texture(1)]],
                                constant FluidParams &params [[buffer(0)]],
                                constant int &colorPass [[buffer(1)]],
                                constant float &a [[buffer(2)]],
                                uint2 gid [[thread_position_in_grid]]) {
        uint N = params.N;
        uint i = gid.x + 1;
        uint j = gid.y + 1;
        if (i > N || j > N) return;
        if (((i + j) % 2) != uint(colorPass)) return;

        float center = x0.read(uint2(i, j)).r;
        float neighbors = x.read(uint2(i - 1, j)).r + x.read(uint2(i + 1, j)).r +
                           x.read(uint2(i, j - 1)).r + x.read(uint2(i, j + 1)).r;
        float val = (center + a * neighbors) / (1.0 + 4.0 * a);
        x.write(float4(val, 0, 0, 0), uint2(i, j));
    }

    // --- Set boundary conditions (edges + corners) ---
    // Dispatch with N+1 threads.
    kernel void setBoundary(texture2d<float, access::read_write> x [[texture(0)]],
                            constant FluidParams &params [[buffer(0)]],
                            constant int &b [[buffer(1)]],
                            uint gid [[thread_position_in_grid]]) {
        uint N = params.N;

        if (gid < N) {
            uint i = gid + 1;
            float sign1 = (b == 1) ? -1.0 : 1.0;
            float sign2 = (b == 2) ? -1.0 : 1.0;

            x.write(float4(sign1 * x.read(uint2(1, i)).r, 0, 0, 0), uint2(0, i));
            x.write(float4(sign1 * x.read(uint2(N, i)).r, 0, 0, 0), uint2(N + 1, i));
            x.write(float4(sign2 * x.read(uint2(i, 1)).r, 0, 0, 0), uint2(i, 0));
            x.write(float4(sign2 * x.read(uint2(i, N)).r, 0, 0, 0), uint2(i, N + 1));
        } else if (gid == N) {
            x.write(float4(0.5 * (x.read(uint2(1, 0)).r     + x.read(uint2(0, 1)).r), 0, 0, 0), uint2(0, 0));
            x.write(float4(0.5 * (x.read(uint2(1, N + 1)).r + x.read(uint2(0, N)).r), 0, 0, 0), uint2(0, N + 1));
            x.write(float4(0.5 * (x.read(uint2(N, 0)).r     + x.read(uint2(N + 1, 1)).r), 0, 0, 0), uint2(N + 1, 0));
            x.write(float4(0.5 * (x.read(uint2(N, N + 1)).r + x.read(uint2(N + 1, N)).r), 0, 0, 0), uint2(N + 1, N + 1));
        }
    }

    // --- Advect (semi-Lagrangian backtrace with hardware bilinear sampling) ---
    kernel void advect(texture2d<float, access::write> d [[texture(0)]],
                       texture2d<float, access::sample> d0 [[texture(1)]],
                       texture2d<float, access::read> u [[texture(2)]],
                       texture2d<float, access::read> v [[texture(3)]],
                       constant FluidParams &params [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]]) {
        uint N = params.N;
        uint i = gid.x + 1;
        uint j = gid.y + 1;
        if (i > N || j > N) return;

        float dt0 = params.dt * float(N);
        float x = float(i) - dt0 * u.read(uint2(i, j)).r;
        float y = float(j) - dt0 * v.read(uint2(i, j)).r;

        // Clamp to interior
        x = clamp(x, 0.5f, float(N) + 0.5f);
        y = clamp(y, 0.5f, float(N) + 0.5f);

        // Sample with bilinear interpolation using normalized coordinates
        // Pixel center for texel (x,y) is at (x+0.5)/texSize in normalized coords
        float texW = float(N + 2);
        float texH = float(N + 2);
        constexpr sampler bilinear(coord::normalized, address::clamp_to_edge, filter::linear);
        float val = d0.sample(bilinear, float2((x + 0.5) / texW, (y + 0.5) / texH)).r;

        d.write(float4(val, 0, 0, 0), uint2(i, j));
    }

    // --- Project step 1: compute divergence and clear pressure ---
    kernel void projectDivergence(texture2d<float, access::write> div [[texture(0)]],
                                  texture2d<float, access::write> p [[texture(1)]],
                                  texture2d<float, access::read> u [[texture(2)]],
                                  texture2d<float, access::read> v [[texture(3)]],
                                  constant FluidParams &params [[buffer(0)]],
                                  uint2 gid [[thread_position_in_grid]]) {
        uint N = params.N;
        uint i = gid.x + 1;
        uint j = gid.y + 1;
        if (i > N || j > N) return;

        float h = 1.0 / float(N);
        float d = -0.5 * h * (u.read(uint2(i + 1, j)).r - u.read(uint2(i - 1, j)).r +
                               v.read(uint2(i, j + 1)).r - v.read(uint2(i, j - 1)).r);
        div.write(float4(d, 0, 0, 0), uint2(i, j));
        p.write(float4(0, 0, 0, 0), uint2(i, j));
    }

    // --- Project step 2: pressure solve (one red-black iteration) ---
    kernel void projectPressureRedBlack(texture2d<float, access::read_write> p [[texture(0)]],
                                        texture2d<float, access::read> div [[texture(1)]],
                                        constant FluidParams &params [[buffer(0)]],
                                        constant int &colorPass [[buffer(1)]],
                                        uint2 gid [[thread_position_in_grid]]) {
        uint N = params.N;
        uint i = gid.x + 1;
        uint j = gid.y + 1;
        if (i > N || j > N) return;
        if (((i + j) % 2) != uint(colorPass)) return;

        float val = (div.read(uint2(i, j)).r +
                     p.read(uint2(i - 1, j)).r + p.read(uint2(i + 1, j)).r +
                     p.read(uint2(i, j - 1)).r + p.read(uint2(i, j + 1)).r) / 4.0;
        p.write(float4(val, 0, 0, 0), uint2(i, j));
    }

    // --- Project step 3: subtract pressure gradient ---
    kernel void projectGradientSubtract(texture2d<float, access::read_write> u [[texture(0)]],
                                        texture2d<float, access::read_write> v [[texture(1)]],
                                        texture2d<float, access::read> p [[texture(2)]],
                                        constant FluidParams &params [[buffer(0)]],
                                        uint2 gid [[thread_position_in_grid]]) {
        uint N = params.N;
        uint i = gid.x + 1;
        uint j = gid.y + 1;
        if (i > N || j > N) return;

        float h = 1.0 / float(N);
        float uVal = u.read(uint2(i, j)).r - 0.5 * (p.read(uint2(i + 1, j)).r - p.read(uint2(i - 1, j)).r) / h;
        float vVal = v.read(uint2(i, j)).r - 0.5 * (p.read(uint2(i, j + 1)).r - p.read(uint2(i, j - 1)).r) / h;
        u.write(float4(uVal, 0, 0, 0), uint2(i, j));
        v.write(float4(vVal, 0, 0, 0), uint2(i, j));
    }

    // --- Decay: x *= factor ---
    kernel void decay(texture2d<float, access::read_write> x [[texture(0)]],
                      constant float &factor [[buffer(0)]],
                      uint2 gid [[thread_position_in_grid]]) {
        uint2 texSize = uint2(x.get_width(), x.get_height());
        if (gid.x >= texSize.x || gid.y >= texSize.y) return;
        float val = x.read(gid).r * factor;
        x.write(float4(val, 0, 0, 0), gid);
    }

    // --- Visualization ---

    struct VisualizeParams {
        float scale;
        float bias;
        int mode;     // 0=direct scalar, 1=speed(|a,b|), 2=vorticity(curl(a,b))
    };

    // Unified colormap visualization. texA is primary, texB is secondary (for speed/vorticity).
    kernel void visualizeColormap(texture2d<float, access::read> texA [[texture(0)]],
                                  texture2d<float, access::read> texB [[texture(1)]],
                                  texture2d<float, access::write> output [[texture(2)]],
                                  texture1d<float, access::sample> colormapTex [[texture(3)]],
                                  constant FluidParams &params [[buffer(0)]],
                                  constant VisualizeParams &vizParams [[buffer(1)]],
                                  uint2 gid [[thread_position_in_grid]]) {
        uint N = params.N;
        if (gid.x >= N || gid.y >= N) return;

        uint i = gid.x + 1;
        uint j = gid.y + 1;
        float d;

        switch (vizParams.mode) {
        case 1: { // Speed
            float uu = texA.read(uint2(i, j)).r;
            float vv = texB.read(uint2(i, j)).r;
            d = sqrt(uu * uu + vv * vv);
            break;
        }
        case 2: { // Vorticity
            float dvdx = (texB.read(uint2(i + 1, j)).r - texB.read(uint2(i - 1, j)).r) * 0.5 * float(N);
            float dudy = (texA.read(uint2(i, j + 1)).r - texA.read(uint2(i, j - 1)).r) * 0.5 * float(N);
            d = dvdx - dudy;
            break;
        }
        default:
            d = texA.read(uint2(i, j)).r;
            break;
        }

        d = clamp(d * vizParams.scale + vizParams.bias, 0.0f, 1.0f);

        constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
        float3 color = colormapTex.sample(s, d).rgb;
        output.write(float4(color, 1.0), gid);
    }

    // Velocity: direction→hue, magnitude→brightness (HSV)
    kernel void visualizeVelocity(texture2d<float, access::read> u [[texture(0)]],
                                  texture2d<float, access::read> v [[texture(1)]],
                                  texture2d<float, access::write> output [[texture(2)]],
                                  constant FluidParams &params [[buffer(0)]],
                                  uint2 gid [[thread_position_in_grid]]) {
        uint N = params.N;
        if (gid.x >= N || gid.y >= N) return;

        float uu = u.read(uint2(gid.x + 1, gid.y + 1)).r;
        float vv = v.read(uint2(gid.x + 1, gid.y + 1)).r;
        float mag = sqrt(uu * uu + vv * vv);
        float angle = atan2(vv, uu);

        float hue = (angle / M_PI_F + 1.0) * 0.5;
        float val = clamp(mag * 10.0f, 0.0f, 1.0f);

        float h6 = hue * 6.0;
        float f = h6 - floor(h6);
        float q = val * (1.0 - f);
        float t = val * f;
        int hi = int(h6) % 6;

        float3 color;
        if (hi == 0) color = float3(val, t, 0);
        else if (hi == 1) color = float3(q, val, 0);
        else if (hi == 2) color = float3(0, val, t);
        else if (hi == 3) color = float3(0, q, val);
        else if (hi == 4) color = float3(t, 0, val);
        else color = float3(val, 0, q);

        output.write(float4(color, 1.0), gid);
    }

} // namespace StamFluidShader
