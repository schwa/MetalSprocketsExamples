#include "MetalSprocketsExampleShaders.h"

using namespace metal;

namespace OpenSea {

    // OpenSeaUniforms is declared in OpenSeaShaders.h, shared with Swift.
    using Uniforms = OpenSeaUniforms;

    struct Wave {
        float2 direction;
        float k;          // wave number, 2pi / wavelength
        float c;          // angular propagation, sqrt(g * k)
        float steepness;
    };

    // Five directional Gerstner components. Constants precomputed from
    // (wavelength, steepness) pairs so the shader never divides by pi.
    constant Wave kWaves[5] = {
        { float2( 1.00000,  0.00000), 0.104720, 1.013040, 0.12 },
        { float2( 0.60000,  0.80000), 0.202683, 1.409357, 0.12 },
        { float2(-0.70711,  0.70711), 0.349066, 1.849554, 0.09 },
        { float2( 0.30113, -0.95357), 0.661388, 2.545900, 0.07 },
        { float2(-0.34894, -0.93716), 1.256637, 3.509276, 0.05 }
    };

    static inline float wavePhase(constant Wave &w, float2 xz, float time) {
        return w.k * (dot(w.direction, xz) - time * w.c);
    }

    struct WaveSample {
        float3 position;
        float3 normal;
        float crest;
    };

    // Position, analytic normal and crest all fall out of the same sines and cosines,
    // so the vertex shader evaluates them together.
    static WaveSample sampleWaves(float2 xz, float time, float sea) {
        float3 p = float3(xz.x, 0.0, xz.y);
        float3 tangent = float3(1.0, 0.0, 0.0);
        float3 binormal = float3(0.0, 0.0, 1.0);
        float crest = 0.0;
        for (int i = 0; i < 5; ++i) {
            constant Wave &w = kWaves[i];
            float q = w.steepness * sea;
            float a = q / w.k;
            float f = wavePhase(w, xz, time);
            float s = sin(f);
            float co = cos(f);
            float dx = w.direction.x;
            float dz = w.direction.y;

            p.x += a * dx * co;
            p.y += a * s;
            p.z += a * dz * co;
            crest += a * s;

            tangent.x -= q * dx * dx * s;
            tangent.y += q * dx * co;
            tangent.z -= q * dx * dz * s;
            binormal.x -= q * dx * dz * s;
            binormal.y += q * dz * co;
            binormal.z -= q * dz * dz * s;
        }
        return WaveSample { p, cross(binormal, tangent), crest };
    }

    struct SurfaceSample {
        float3 normal;
        float crest;   // signed crest height
    };

    // Analytic tangent/binormal derivatives give stable broad normals with no dFdx.
    // The crest height reuses the same sines, so it costs nothing extra.
    static SurfaceSample sampleSurface(float2 xz, float time, float sea) {
        float3 tangent = float3(1.0, 0.0, 0.0);
        float3 binormal = float3(0.0, 0.0, 1.0);
        float crest = 0.0;
        for (int i = 0; i < 5; ++i) {
            constant Wave &w = kWaves[i];
            float q = w.steepness * sea;
            float f = wavePhase(w, xz, time);
            float s = sin(f);
            float co = cos(f);
            crest += (q / w.k) * s;
            float dx = w.direction.x;
            float dz = w.direction.y;
            tangent.x -= q * dx * dx * s;
            tangent.y += q * dx * co;
            tangent.z -= q * dx * dz * s;
            binormal.x -= q * dx * dz * s;
            binormal.y += q * dz * co;
            binormal.z -= q * dz * dz * s;
        }
        return SurfaceSample { normalize(cross(binormal, tangent)), crest };
    }

    // MARK: - Procedural gradient noise + 3-octave FBM

    // Integer bit-mix hash. `p` is always an integer lattice point, so the exact
    // value is irrelevant as long as gradients stay uniform in [-1, 1].
    constant uint kHashA = 1597334673u;
    constant uint kHashB = 3812015801u;

    // 11-bit gradients convert straight from integer to half (every value up to 2048 is
    // exact in half), avoiding a float round trip per component.
    static inline half2 hashMix(uint qx, uint qy) {
        uint n = (qx ^ qy) * kHashA;
        uint2 r = uint2(n, n * kHashB) >> 21;
        return half2(ushort2(r)) * (2.0h / 2047.0h) - 1.0h;
    }

    struct CornerGradients {
        half2 g00, g10, g01, g11;
    };

    // All four lattice corners at once. Stepping by one cell is an exact addition in
    // the hash's modular arithmetic, so this matches a per-corner hash bit for bit
    // while dropping six of the eight multiplies.
    static inline CornerGradients cornerGradients(float2 i) {
        uint2 q = uint2(int2(i)) * uint2(kHashA, kHashB);
        uint qx1 = q.x + kHashA;
        uint qy1 = q.y + kHashB;
        return CornerGradients {
            hashMix(q.x, q.y),
            hashMix(qx1, q.y),
            hashMix(q.x, qy1),
            hashMix(qx1, qy1)
        };
    }

    // The lattice cell is unit sized, so everything after `fract` fits comfortably in
    // half precision, which runs at double rate on Apple GPUs.
    static float gradNoise(float2 p) {
        float2 i = floor(p);
        half2 f = half2(fract(p));
        half2 u = f * f * f * (f * (f * 6.0h - 15.0h) + 10.0h); // quintic curve
        CornerGradients corners = cornerGradients(i);
        half n00 = dot(corners.g00, f);
        half n10 = dot(corners.g10, f - half2(1.0h, 0.0h));
        half n01 = dot(corners.g01, f - half2(0.0h, 1.0h));
        half n11 = dot(corners.g11, f - half2(1.0h, 1.0h));
        return float(mix(mix(n00, n10, u.x), mix(n01, n11, u.x), u.y));
    }

    // Value plus analytic gradient (d/dx, d/dy) of the gradient noise.
    static half3 gradNoiseD(float2 p) {
        float2 i = floor(p);
        half2 f = half2(fract(p));
        // Cubic (C1) interpolant rather than quintic: the derivative still vanishes at the
        // cell boundaries, so gradients stay continuous, at roughly half the ALU.
        half2 u = f * f * (3.0h - 2.0h * f);
        half2 du = 6.0h * f * (1.0h - f);

        CornerGradients corners = cornerGradients(i);
        half2 g00 = corners.g00;
        half2 g10 = corners.g10;
        half2 g01 = corners.g01;
        half2 g11 = corners.g11;

        half n00 = dot(g00, f);
        half n10 = dot(g10, f - half2(1.0h, 0.0h));
        half n01 = dot(g01, f - half2(0.0h, 1.0h));
        half n11 = dot(g11, f - half2(1.0h, 1.0h));

        // Nested mixes map to fused multiply-adds; the expanded polynomial form does not.
        half nx0 = mix(n00, n10, u.x);
        half nx1 = mix(n01, n11, u.x);
        half value = mix(nx0, nx1, u.y);

        half a = n10 - n00;
        half b = n01 - n00;
        half c = n00 - n10 - n01 + n11;
        half2 gradient = mix(mix(g00, g10, u.x), mix(g01, g11, u.x), u.y)
            + du * half2(a + c * u.y, b + c * u.x);
        return half3(value, gradient);
    }

    static float fbm(float2 p) {
        return gradNoise(p)
             + gradNoise(p * 2.04 + float2(17.3, 9.1)) * 0.5
             + gradNoise(p * 4.11 + float2(42.7, 28.6)) * 0.25;
    }

    // Same field as the animated capillary-detail FBM, returning
    // (height, dH/dx, dH/dz, second-band FBM value reused by the glitter term)
    // analytically instead of requiring sampled evaluations.
    // `footprint` is the world-space size of a pixel: octaves finer than it can only
    // alias, so they are faded out instead of sampled.
    static float4 detailHeightD(float2 xz, float time, float footprint) {
        float2 driftA = float2(time * 0.55, time * 0.32);
        float2 driftB = float2(time * -0.4, time * 0.5);

        float3 result = 0.0;
        const float scaleA[3] = { 0.85, 0.85 * 2.04, 0.85 * 4.11 };
        const float weightA[3] = { 1.0, 0.5, 0.25 };
        const float2 offsetA[3] = { float2(0.0), float2(17.3, 9.1), float2(42.7, 28.6) };
        for (int i = 0; i < 3; ++i) {
            float fade = saturate(2.0 - 2.0 * footprint * scaleA[i]);
            if (fade <= 0.0) { continue; }
            float3 n = float3(gradNoiseD(xz * scaleA[i] + driftA * (scaleA[i] / 0.85) + offsetA[i]));
            result += float3(n.x * weightA[i], n.yz * (weightA[i] * scaleA[i])) * fade;
        }
        const float scaleB[3] = { 2.1, 2.1 * 2.04, 2.1 * 4.11 };
        float bandB = 0.0;
        for (int i = 0; i < 3; ++i) {
            float fade = saturate(2.0 - 2.0 * footprint * scaleB[i]);
            if (fade <= 0.0) { continue; }
            float3 n = float3(gradNoiseD(xz * scaleB[i] + driftB * (scaleB[i] / 2.1) + offsetA[i]));
            bandB += n.x * weightA[i] * fade;
            result += float3(n.x * weightA[i], n.yz * (weightA[i] * scaleB[i])) * (0.45 * fade);
        }
        return float4(result, bandB);
    }

    // MARK: - Shared analytic sky, used by the dome and the water reflection

    // `dir` must already be unit length.
    static float3 skyColorUnit(float3 dir, constant Uniforms &u) {
        float up = clamp(dir.y, -0.15, 1.0);
        float3 sky = mix(u.horizonColor, u.zenithColor, pow(max(up, 0.0), 0.42));

        // Below-horizon haze so reflections never hit black.
        float3 haze = u.deepColor * 1.4 + u.horizonColor * 0.25;
        sky = mix(sky, haze, 1.0 - smoothstep(-0.15, 0.0, dir.y));

        float s = max(dot(dir, u.sunDirection), 0.0);
        sky += u.sunColor * pow(s, 10.0) * 0.18;                    // wide halo
        sky += u.sunColor * smoothstep(0.9994, 0.9998, s) * 30.0;   // sun disk
        return sky;
    }

    // MARK: - Tone mapping

    static float3 acesFilmic(float3 x) {
        const float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
        return saturate((x * (a * x + b)) / (x * (c * x + d) + e));
    }

    // MARK: - Sky pass (fullscreen triangle)

    struct SkyOut {
        float4 position [[position]];
        float3 direction;
    };

    [[vertex]] SkyOut sky_vertex(uint vertexID [[vertex_id]], constant Uniforms &uniforms) {
        constant Uniforms &u = uniforms;
        float2 corners[3] = { float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0) };
        float2 xy = corners[vertexID];
        SkyOut out;
        out.position = float4(xy, 1.0, 1.0);
        float4 far = u.inverseViewProjection * float4(xy, 1.0, 1.0);
        out.direction = far.xyz / far.w - u.cameraPosition;
        return out;
    }

    [[fragment]] float4 sky_fragment(SkyOut in [[stage_in]], constant Uniforms &uniforms) {
        constant Uniforms &u = uniforms;
        float3 dir = normalize(in.direction);
        float3 color = skyColorUnit(dir, u);

        // Procedural clouds confined to a low band near the horizon.
        // Outside the band the cloud contribution is zero, so the noise is skipped.
        float band = smoothstep(0.03, 0.16, dir.y) * (1.0 - smoothstep(0.22, 0.6, dir.y));
        if (band > 0.0) {
            float2 cloudUV = dir.xz / (dir.y + 0.18) * 0.55;
            float2 cloudDrift = float2(u.time * 0.006, u.time * 0.003);
            float cloudNoise = fbm(cloudUV + cloudDrift) * 0.5 + 0.5;
            float clouds = smoothstep(0.62, 0.95, cloudNoise) * band;
            float3 cloudColor = mix(float3(0.92, 0.9, 0.87), u.sunColor, 0.25);
            color = mix(color, cloudColor, saturate(clouds * 0.6));
        }

        return float4(acesFilmic(color), 1.0);
    }

    // MARK: - Ocean pass

    struct OceanOut {
        float4 position [[position]];
        float3 worldPosition;
        float3 waveNormal;
        float crest;
    };

    [[vertex]] OceanOut ocean_vertex(uint vertexID [[vertex_id]], constant Uniforms &uniforms) {
        constant Uniforms &u = uniforms;
        // Radial grid position derived from the vertex ID, so no vertex buffer is fetched.
        // Vertex 0 is the centre; the rest are rings of `ringSpokes` vertices whose radius
        // grows geometrically outwards.
        // The disc follows the camera, so the finest rings are always underfoot.
        float2 xz = u.gridCenter;
        if (vertexID > 0) {
            uint i = vertexID - 1;
            uint ring = i / u.ringSpokes;
            uint spoke = i - ring * u.ringSpokes;
            float radius = u.ringInnerRadius * exp(float(ring) * u.ringGrowth);
            float angle = float(spoke) * (2.0 * M_PI_F) / float(u.ringSpokes);
            xz += radius * float2(cos(angle), sin(angle));
        }
        WaveSample wave = sampleWaves(xz, u.time, u.sea);
        OceanOut out;
        out.position = u.viewProjection * float4(wave.position, 1.0);
        out.worldPosition = wave.position;
        out.waveNormal = wave.normal;
        out.crest = wave.crest;
        return out;
    }

    [[fragment]] float4 ocean_fragment(OceanOut in [[stage_in]], constant Uniforms &uniforms) {
        constant Uniforms &u = uniforms;
        float3 P = in.worldPosition;
        float2 xz = P.xz;

        // Near the eye the grid is about a metre across, far finer than the shortest wave,
        // so the interpolated vertex normal is indistinguishable from the analytic one and
        // the trig can be skipped. Rings widen geometrically, so the far field still needs
        // the per-pixel evaluation; the two are blended over a band to avoid a seam.
        float gridRadius = distance(xz, u.gridCenter);
        float ringSpacing = gridRadius * u.ringGrowth;
        float analyticWeight = saturate((ringSpacing - 1.0) * (1.0 / 1.0));
        SurfaceSample surface = { normalize(in.waveNormal), in.crest };
        if (analyticWeight > 0.0) {
            SurfaceSample exact = sampleSurface(xz, u.time, u.sea);
            surface.normal = normalize(mix(surface.normal, exact.normal, analyticWeight));
            surface.crest = mix(surface.crest, exact.crest, analyticWeight);
        }
        float footprint = max(length(fwidth(xz)), 1e-4);
        float4 detailD = detailHeightD(xz, u.time, footprint);
        float3 detail = float3(-0.1 * detailD.y, 0.0, -0.1 * detailD.z) * (1.5 * (u.sea * 0.6 + 0.4));
        float3 N = normalize(surface.normal + detail);

        float3 V = normalize(u.cameraPosition - P);
        float crest = surface.crest;

        // Body color, plus backlit subsurface crest glow before the fresnel mix.
        float3 body = mix(u.deepColor, u.shallowColor, saturate(crest * 0.35 + 0.45));
        float sss = pow(max(dot(V, u.sunDirection), 0.0), 3.0) * max(crest, 0.0) * 0.18;
        body += mix(u.shallowColor, u.sunColor, 0.5) * sss;

        // Sky reflection, ray clamped just above the horizon.
        float3 R = reflect(-V, N);
        R.y = max(R.y, 0.04);
        R = normalize(R);

        float fresnel = 0.02 + 0.98 * pow(1.0 - max(dot(N, V), 0.0), 5.0);
        float3 color = mix(body, skyColorUnit(R, u), fresnel);

        // Sun specular: tight noise-broken glitter plus a broad sheen.
        float3 H = normalize(u.sunDirection + V);
        // Same field as the detail FBM's second band, so it is reused instead of resampled.
        float glitterNoise = detailD.w * 0.5 + 0.5;
        float glitter = pow(max(dot(N, H), 0.0), 500.0) * mix(0.4, 3.4, glitterNoise);
        float sheen = pow(max(dot(N, H), 0.0), 48.0) * 0.12;
        color += u.sunColor * (glitter + sheen);

        // Sparse broken foam on high crests.
        // Only crests above 1.0 can show foam, so the noise is skipped everywhere else.
        float foamMask = smoothstep(1.0, 2.0, crest);
        if (foamMask > 0.0) {
            float foamNoise = fbm(xz * 1.1 + float2(u.time * 0.22, u.time * 0.14)) * 0.5 + 0.5;
            float foam = smoothstep(0.5, 0.95, foamNoise) * foamMask;
            color = mix(color, float3(0.82, 0.88, 0.9), saturate(foam * 0.85));
        }

        // Atmospheric concealment of the finite plane edge. The horizontal distance is
        // already known; the eye is a few metres up, which shifts the fade by under 0.1%.
        color = mix(color, u.horizonColor, smoothstep(150.0, 290.0, gridRadius));

        return float4(acesFilmic(color), 1.0);
    }

} // namespace OpenSea
