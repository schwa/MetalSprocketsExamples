#include "MetalSprocketsExampleShaders.h"

using namespace metal;

// Jos Stam's "Real-Time Fluid Dynamics for Games" (GDC 2003)
// GPU implementation of the Navier-Stokes solver.
//
// Grid is (N+2)*(N+2) with a 1-cell boundary layer.
// Index macro: IX(i,j) = i + (N+2)*j

namespace StamFluidShader {

    struct FluidParams {
        uint N;          // grid resolution (interior cells per side)
        float dt;        // time step
        float diff;      // diffusion rate
        float visc;      // viscosity
    };

    // IX(i,j) for a grid of width (N+2)
    inline uint IX(uint i, uint j, uint N) {
        return i + (N + 2) * j;
    }

    // --- Add source ---
    kernel void addSource(device float *x [[buffer(0)]],
                          device const float *s [[buffer(1)]],
                          constant FluidParams &params [[buffer(2)]],
                          uint gid [[thread_position_in_grid]]) {
        uint size = (params.N + 2) * (params.N + 2);
        if (gid >= size) return;
        x[gid] += params.dt * s[gid];
    }

    // --- Gauss-Seidel relaxation (one iteration) ---
    // For diffuse: solves (1 + 4a)*x[IX(i,j)] - a*(neighbors) = x0[IX(i,j)]
    // Red-black ordering for GPU parallelism.
    kernel void diffuseRedBlack(device float *x [[buffer(0)]],
                                device const float *x0 [[buffer(1)]],
                                constant FluidParams &params [[buffer(2)]],
                                constant int &colorPass [[buffer(3)]],   // 0 = red, 1 = black
                                constant float &a [[buffer(4)]],
                                uint2 gid [[thread_position_in_grid]]) {
        uint N = params.N;
        uint i = gid.x + 1; // interior starts at 1
        uint j = gid.y + 1;
        if (i > N || j > N) return;

        // Red-black: skip cells that don't match this pass
        if (((i + j) % 2) != uint(colorPass)) return;

        x[IX(i, j, N)] = (x0[IX(i, j, N)] + a * (x[IX(i - 1, j, N)] + x[IX(i + 1, j, N)] +
                                                    x[IX(i, j - 1, N)] + x[IX(i, j + 1, N)])) / (1.0 + 4.0 * a);
    }

    // --- Set boundary conditions ---
    kernel void setBoundary(device float *x [[buffer(0)]],
                            constant FluidParams &params [[buffer(1)]],
                            constant int &b [[buffer(2)]],
                            uint gid [[thread_position_in_grid]]) {
        uint N = params.N;
        if (gid >= N) return;
        uint i = gid + 1;

        x[IX(0, i, N)]     = (b == 1) ? -x[IX(1, i, N)] : x[IX(1, i, N)];
        x[IX(N + 1, i, N)] = (b == 1) ? -x[IX(N, i, N)] : x[IX(N, i, N)];
        x[IX(i, 0, N)]     = (b == 2) ? -x[IX(i, 1, N)] : x[IX(i, 1, N)];
        x[IX(i, N + 1, N)] = (b == 2) ? -x[IX(i, N, N)] : x[IX(i, N, N)];
    }

    // Corner cells
    kernel void setBoundaryCorners(device float *x [[buffer(0)]],
                                   constant FluidParams &params [[buffer(1)]],
                                   uint gid [[thread_position_in_grid]]) {
        if (gid != 0) return;
        uint N = params.N;
        x[IX(0, 0, N)]         = 0.5 * (x[IX(1, 0, N)]     + x[IX(0, 1, N)]);
        x[IX(0, N + 1, N)]     = 0.5 * (x[IX(1, N + 1, N)] + x[IX(0, N, N)]);
        x[IX(N + 1, 0, N)]     = 0.5 * (x[IX(N, 0, N)]     + x[IX(N + 1, 1, N)]);
        x[IX(N + 1, N + 1, N)] = 0.5 * (x[IX(N, N + 1, N)] + x[IX(N + 1, N, N)]);
    }

    // --- Advect (semi-Lagrangian backtrace) ---
    kernel void advect(device float *d [[buffer(0)]],
                       device const float *d0 [[buffer(1)]],
                       device const float *u [[buffer(2)]],
                       device const float *v [[buffer(3)]],
                       constant FluidParams &params [[buffer(4)]],
                       uint2 gid [[thread_position_in_grid]]) {
        uint N = params.N;
        uint i = gid.x + 1;
        uint j = gid.y + 1;
        if (i > N || j > N) return;

        float dt0 = params.dt * float(N);
        float x = float(i) - dt0 * u[IX(i, j, N)];
        float y = float(j) - dt0 * v[IX(i, j, N)];

        if (x < 0.5) x = 0.5;
        if (x > float(N) + 0.5) x = float(N) + 0.5;
        uint i0 = uint(x);
        uint i1 = i0 + 1;

        if (y < 0.5) y = 0.5;
        if (y > float(N) + 0.5) y = float(N) + 0.5;
        uint j0 = uint(y);
        uint j1 = j0 + 1;

        float s1 = x - float(i0);
        float s0 = 1.0 - s1;
        float t1 = y - float(j0);
        float t0 = 1.0 - t1;

        d[IX(i, j, N)] = s0 * (t0 * d0[IX(i0, j0, N)] + t1 * d0[IX(i0, j1, N)]) +
                          s1 * (t0 * d0[IX(i1, j0, N)] + t1 * d0[IX(i1, j1, N)]);
    }

    // --- Project step 1: compute divergence and clear pressure ---
    kernel void projectDivergence(device float *div [[buffer(0)]],
                                  device float *p [[buffer(1)]],
                                  device const float *u [[buffer(2)]],
                                  device const float *v [[buffer(3)]],
                                  constant FluidParams &params [[buffer(4)]],
                                  uint2 gid [[thread_position_in_grid]]) {
        uint N = params.N;
        uint i = gid.x + 1;
        uint j = gid.y + 1;
        if (i > N || j > N) return;

        float h = 1.0 / float(N);
        div[IX(i, j, N)] = -0.5 * h * (u[IX(i + 1, j, N)] - u[IX(i - 1, j, N)] +
                                         v[IX(i, j + 1, N)] - v[IX(i, j - 1, N)]);
        p[IX(i, j, N)] = 0.0;
    }

    // --- Project step 2: pressure solve (one Gauss-Seidel iteration, red-black) ---
    kernel void projectPressureRedBlack(device float *p [[buffer(0)]],
                                        device const float *div [[buffer(1)]],
                                        constant FluidParams &params [[buffer(2)]],
                                        constant int &colorPass [[buffer(3)]],
                                        uint2 gid [[thread_position_in_grid]]) {
        uint N = params.N;
        uint i = gid.x + 1;
        uint j = gid.y + 1;
        if (i > N || j > N) return;

        if (((i + j) % 2) != uint(colorPass)) return;

        p[IX(i, j, N)] = (div[IX(i, j, N)] + p[IX(i - 1, j, N)] + p[IX(i + 1, j, N)] +
                           p[IX(i, j - 1, N)] + p[IX(i, j + 1, N)]) / 4.0;
    }

    // --- Project step 3: subtract pressure gradient from velocity ---
    kernel void projectGradientSubtract(device float *u [[buffer(0)]],
                                        device float *v [[buffer(1)]],
                                        device const float *p [[buffer(2)]],
                                        constant FluidParams &params [[buffer(3)]],
                                        uint2 gid [[thread_position_in_grid]]) {
        uint N = params.N;
        uint i = gid.x + 1;
        uint j = gid.y + 1;
        if (i > N || j > N) return;

        float h = 1.0 / float(N);
        u[IX(i, j, N)] -= 0.5 * (p[IX(i + 1, j, N)] - p[IX(i - 1, j, N)]) / h;
        v[IX(i, j, N)] -= 0.5 * (p[IX(i, j + 1, N)] - p[IX(i, j - 1, N)]) / h;
    }

    // --- Clear buffer ---
    kernel void clearBuffer(device float *buf [[buffer(0)]],
                            uint gid [[thread_position_in_grid]]) {
        buf[gid] = 0.0;
    }

    // --- Decay: multiply all values by a factor < 1 to prevent saturation ---
    kernel void decay(device float *x [[buffer(0)]],
                      constant FluidParams &params [[buffer(1)]],
                      constant float &factor [[buffer(2)]],
                      uint gid [[thread_position_in_grid]]) {
        uint size = (params.N + 2) * (params.N + 2);
        if (gid >= size) return;
        x[gid] *= factor;
    }

    // --- Visualize density as a texture, sampling a 1D colormap texture ---
    kernel void visualizeDensity(device const float *dens [[buffer(0)]],
                                 texture2d<float, access::write> output [[texture(0)]],
                                 constant FluidParams &params [[buffer(1)]],
                                 texture1d<float, access::sample> colormapTex [[texture(1)]],
                                 uint2 gid [[thread_position_in_grid]]) {
        uint N = params.N;
        if (gid.x >= N || gid.y >= N) return;

        float d = dens[IX(gid.x + 1, gid.y + 1, N)];
        d = clamp(d, 0.0f, 1.0f);

        constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
        float3 color = colormapTex.sample(s, d).rgb;
        output.write(float4(color, 1.0), gid);
    }

    // --- Visualize velocity as a texture (direction → hue, magnitude → brightness) ---
    kernel void visualizeVelocity(device const float *u [[buffer(0)]],
                                  device const float *v [[buffer(1)]],
                                  texture2d<float, access::write> output [[texture(0)]],
                                  constant FluidParams &params [[buffer(2)]],
                                  uint2 gid [[thread_position_in_grid]]) {
        uint N = params.N;
        if (gid.x >= N || gid.y >= N) return;

        float uu = u[IX(gid.x + 1, gid.y + 1, N)];
        float vv = v[IX(gid.x + 1, gid.y + 1, N)];
        float mag = sqrt(uu * uu + vv * vv);
        float angle = atan2(vv, uu); // -pi..pi

        // HSV to RGB with hue from angle, saturation=1, value from magnitude
        float hue = (angle / M_PI_F + 1.0) * 0.5; // 0..1
        float val = clamp(mag * 10.0f, 0.0f, 1.0f);

        // Simple HSV->RGB
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
