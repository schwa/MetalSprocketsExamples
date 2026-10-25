#include "MetalSprocketsExampleShaders.h"

using namespace metal;

// Volumetric cloud rendered two ways, side by side:
//   left  = ray marching (fixed steps, deterministic, smooth)
//   right = path tracing (delta tracking, unbiased, noisy)
namespace CloudShaders {

    struct VertexOut {
        float4 position [[position]];
        float2 ndc;
    };

    [[vertex]] VertexOut vertex_main(uint vertexID [[vertex_id]]) {
        float2 positions[3] = { float2(-1, -1), float2(3, -1), float2(-1, 3) };
        VertexOut out;
        out.position = float4(positions[vertexID], 0, 1);
        out.ndc = positions[vertexID];
        return out;
    }

    // MARK: - Random numbers

    struct RNG {
        uint state;
        float next() {
            state = state * 747796405u + 2891336453u;
            uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
            word = (word >> 22u) ^ word;
            return float(word) * (1.0 / 4294967296.0);
        }
    };

    uint hashUInt(uint x) {
        x ^= x >> 16; x *= 0x7feb352du;
        x ^= x >> 15; x *= 0x846ca68bu;
        x ^= x >> 16;
        return x;
    }

    // MARK: - Density field

    // MARK: Noise bake
    //
    // Tileable noise baked once into a 3D texture:
    //   r = Perlin-Worley (low-frequency billows), g = Worley fbm (high-frequency erosion detail).
    // The lattice wraps at `period` so the texture repeats seamlessly.

    uint3 hashUInt3(int3 cell) {
        uint3 v = uint3(cell) * uint3(1597334673u, 3812015801u, 2798796415u);
        v = (v.x ^ v.y ^ v.z) * uint3(1597334673u, 3812015801u, 2798796415u);
        return v;
    }

    float3 hashFloat3(int3 cell) {
        return float3(hashUInt3(cell)) * (1.0 / 4294967296.0);
    }

    int3 wrap(int3 cell, int period) {
        return (cell % period + period) % period;
    }

    float tileablePerlin(float3 p, int period) {
        int3 i = int3(floor(p));
        float3 f = fract(p);
        float3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
        float corners[8];
        for (int c = 0; c < 8; c++) {
            int3 offset = int3(c & 1, (c >> 1) & 1, (c >> 2) & 1);
            float3 gradient = normalize(hashFloat3(wrap(i + offset, period)) * 2.0 - 1.0);
            corners[c] = dot(gradient, f - float3(offset));
        }
        float x00 = mix(corners[0], corners[1], u.x);
        float x10 = mix(corners[2], corners[3], u.x);
        float x01 = mix(corners[4], corners[5], u.x);
        float x11 = mix(corners[6], corners[7], u.x);
        return mix(mix(x00, x10, u.y), mix(x01, x11, u.y), u.z);
    }

    // 1 at feature points, falling to 0 between them (inverted Worley).
    float tileableWorley(float3 p, int period) {
        int3 i = int3(floor(p));
        float3 f = fract(p);
        float nearest = 1.0;
        for (int z = -1; z <= 1; z++) {
            for (int y = -1; y <= 1; y++) {
                for (int x = -1; x <= 1; x++) {
                    int3 offset = int3(x, y, z);
                    float3 feature = float3(offset) + hashFloat3(wrap(i + offset, period));
                    nearest = min(nearest, length_squared(feature - f));
                }
            }
        }
        return 1.0 - sqrt(nearest);
    }

    float worleyFbm(float3 p, int period) {
        return tileableWorley(p, period) * 0.625
            + tileableWorley(p * 2.0, period * 2) * 0.25
            + tileableWorley(p * 4.0, period * 4) * 0.125;
    }

    float remap(float value, float oldMin, float oldMax, float newMin, float newMax) {
        return newMin + (value - oldMin) / (oldMax - oldMin) * (newMax - newMin);
    }

    [[kernel]] void bake_noise(texture3d<float, access::write> noise [[texture(0)]], uint3 gid [[thread_position_in_grid]]) {
        uint size = noise.get_width();
        if (any(gid >= uint3(size))) {
            return;
        }
        float3 uvw = (float3(gid) + 0.5) / float(size);

        // Perlin fbm over 4 octaves, base period 4 cells.
        float perlin = 0;
        float amplitude = 0.5;
        int period = 4;
        for (int octave = 0; octave < 4; octave++) {
            perlin += amplitude * tileablePerlin(uvw * float(period), period);
            amplitude *= 0.5;
            period *= 2;
        }
        perlin = saturate(perlin * 0.9 + 0.5);

        float worleyLow = worleyFbm(uvw * 4.0, 4);
        // Perlin-Worley: Worley carves Perlin into round billows.
        float perlinWorley = saturate(remap(perlin, worleyLow - 1.0, 1.0, 0.0, 1.0));
        float detail = worleyFbm(uvw * 8.0, 8);
        noise.write(float4(perlinWorley, detail, 0, 0), gid);
    }

    // MARK: Density

    constant float3 boundsMin = float3(-2.2, -1.3, -1.6);
    constant float3 boundsMax = float3(2.2, 1.5, 1.6);

    constexpr sampler noiseSampler(filter::linear, address::repeat);

    // Tricubic B-spline filtering from 8 trilinear taps (Sigg & Hadwiger, GPU Gems 2 ch. 20).
    // Removes the blocky, faceted look of trilinear interpolation at the cost of 8x the samples.
    float2 sampleTricubic(texture3d<float> texture, float3 uvw) {
        float3 size = float3(texture.get_width(), texture.get_height(), texture.get_depth());
        float3 coord = uvw * size - 0.5;
        float3 index = floor(coord);
        float3 f = coord - index;
        float3 f2 = f * f;
        float3 f3 = f2 * f;
        float3 w0 = (1.0 - 3.0 * f + 3.0 * f2 - f3) / 6.0;
        float3 w1 = (4.0 - 6.0 * f2 + 3.0 * f3) / 6.0;
        float3 w2 = (1.0 + 3.0 * f + 3.0 * f2 - 3.0 * f3) / 6.0;
        float3 w3 = f3 / 6.0;
        float3 g0 = w0 + w1;
        float3 g1 = w2 + w3;
        float3 h0 = (index - 0.5 + w1 / g0) / size;
        float3 h1 = (index + 1.5 + w3 / g1) / size;

        float2 result = 0;
        for (int corner = 0; corner < 8; corner++) {
            bool3 upper = bool3(corner & 1, corner & 2, corner & 4);
            float3 position = select(h0, h1, upper);
            float3 weight = select(g0, g1, upper);
            result += weight.x * weight.y * weight.z * texture.sample(noiseSampler, position).rg;
        }
        return result;
    }

    float2 sampleNoise(texture3d<float> texture, float3 uvw, constant CloudUniforms &uniforms) {
        return uniforms.tricubic ? sampleTricubic(texture, uvw) : texture.sample(noiseSampler, uvw).rg;
    }

    // Normalised density in [0, 1]. Multiplied by uniforms.density to get the extinction coefficient.
    float cloudDensity(float3 p, constant CloudUniforms &uniforms, texture3d<float> noise) {
        float time = uniforms.time;
        // A few overlapping blobs give the base cumulus shape.
        float shape = 0;
        shape = max(shape, 1.0 - length((p - float3(0.0, 0.1, 0.0)) / float3(1.3, 0.9, 1.0)));
        shape = max(shape, 1.0 - length((p - float3(-1.0, -0.3, 0.2)) / float3(0.9, 0.6, 0.8)));
        shape = max(shape, 1.0 - length((p - float3(1.0, -0.4, -0.1)) / float3(0.9, 0.55, 0.8)));
        shape = max(shape, 1.0 - length((p - float3(0.3, 0.7, 0.1)) / float3(0.7, 0.6, 0.6)));
        // Flatten the bottom like a real cumulus.
        shape *= smoothstep(-0.9, -0.6, p.y);

        if (shape <= 0) {
            return 0;
        }

        float3 wind = float3(time * 0.03, -time * 0.01, 0);
        float base = sampleNoise(noise, p * 0.22 + wind, uniforms).r;
        // Coverage: the noise survives only where the shape allows it, so edges break into billows.
        float density = saturate(remap(base, 1.0 - saturate(shape * 1.4), 1.0, 0.0, 1.0));
        // Erode the edges with high-frequency Worley; the core stays solid.
        float detail = sampleNoise(noise, p * 0.9 + wind * 3.0, uniforms).g;
        density = saturate(remap(density, detail * 0.35, 1.0, 0.0, 1.0));
        return saturate(density * 2.5);
    }

    bool intersectBounds(float3 origin, float3 direction, thread float &tNear, thread float &tFar) {
        float3 inverse = 1.0 / direction;
        float3 t0 = (boundsMin - origin) * inverse;
        float3 t1 = (boundsMax - origin) * inverse;
        float3 tMin = min(t0, t1);
        float3 tMax = max(t0, t1);
        tNear = max(max(tMin.x, tMin.y), max(tMin.z, 0.0));
        tFar = min(min(tMax.x, tMax.y), tMax.z);
        return tFar > tNear;
    }

    // MARK: - Lighting

    constant float3 emissionColor = float3(1.0, 0.82, 0.45) * 2.5;
    constant float3 emissiveBackground = float3(0.01, 0.025, 0.04);
    constant float3 sunColor = float3(1.0, 0.95, 0.85) * 6.0;
    constant float albedo = 0.95;
    constant float phaseG = 0.6;

    float henyeyGreenstein(float cosTheta, float g);

    // Cheap analytic atmosphere: a Rayleigh-like zenith/horizon gradient plus a Mie forward-scattering
    // halo around the sun. The sun disk itself is optional: scattered rays leave it to next-event estimation.
    float3 sky(float3 direction, float3 sunDirection, bool includeSunDisk) {
        const float3 zenith = float3(0.18, 0.36, 0.78);
        const float3 horizon = float3(0.62, 0.76, 0.92);
        float up = direction.y;
        float3 color = mix(horizon, zenith, pow(saturate(up), 0.45));
        // Below the horizon fade to a hazy, darker band instead of a hard edge.
        color *= mix(1.0, 0.65, saturate(-up * 3.0));

        float cosSun = dot(direction, sunDirection);
        // Rayleigh phase (1 + cos^2) brightens the sky on the sun's side and opposite it.
        color *= 0.85 + 0.25 * cosSun * cosSun;
        // Mie halo: strongly forward-peaked glow around the sun.
        color += sunColor * 0.035 * henyeyGreenstein(cosSun, 0.8);

        // Sun disk, ~0.6 degrees across with a soft limb.
        if (includeSunDisk) {
            color += sunColor * 40.0 * smoothstep(0.99994, 0.99997, cosSun);
        }
        return color;
    }

    // Per-channel extinction relative to uniforms.density. Blue is extinguished more than red, so light that
    // travels deep into the cloud comes out warm. Kept <= 1 so uniforms.density * 1 stays a valid majorant.
    float3 extinctionScale(constant CloudUniforms &uniforms) {
        return (uniforms.mode == 1 && uniforms.chromatic) ? float3(0.4, 0.65, 1.0) : float3(1.0);
    }

    float3 background(float3 direction, constant CloudUniforms &uniforms, bool includeSunDisk) {
        return uniforms.mode == 0 ? emissiveBackground : sky(direction, uniforms.sunDirection, includeSunDisk);
    }

    float henyeyGreenstein(float cosTheta, float g) {
        float denominator = 1.0 + g * g - 2.0 * g * cosTheta;
        return (1.0 - g * g) / (4.0 * M_PI_F * denominator * sqrt(denominator));
    }

    // Two-lobe phase gives a forward silver lining and some back-scatter.
    float phase(float cosTheta) {
        return mix(henyeyGreenstein(cosTheta, -0.2), henyeyGreenstein(cosTheta, phaseG), 0.7);
    }

    float3 sampleHenyeyGreenstein(float3 incoming, float g, float u1, float u2) {
        float cosTheta;
        if (abs(g) < 1e-3) {
            cosTheta = 1.0 - 2.0 * u1;
        } else {
            float s = (1.0 - g * g) / (1.0 - g + 2.0 * g * u1);
            cosTheta = (1.0 + g * g - s * s) / (2.0 * g);
        }
        float sinTheta = sqrt(max(0.0, 1.0 - cosTheta * cosTheta));
        float phi = 2.0 * M_PI_F * u2;
        float3 up = abs(incoming.y) < 0.999 ? float3(0, 1, 0) : float3(1, 0, 0);
        float3 tangent = normalize(cross(up, incoming));
        float3 bitangent = cross(incoming, tangent);
        return normalize(tangent * (sinTheta * cos(phi)) + bitangent * (sinTheta * sin(phi)) + incoming * cosTheta);
    }

    // MARK: - Ray marching

    // Per-channel optical depth from p toward the light, marched in a few steps.
    float3 marchedOpticalDepth(float3 p, float3 lightDirection, constant CloudUniforms &uniforms, texture3d<float> noise) {
        float tNear, tFar;
        if (!intersectBounds(p, lightDirection, tNear, tFar)) {
            return 0.0;
        }
        const int steps = 8;
        float stepSize = tFar / float(steps);
        float opticalDepth = 0;
        for (int i = 0; i < steps; i++) {
            float3 q = p + lightDirection * ((float(i) + 0.5) * stepSize);
            opticalDepth += cloudDensity(q, uniforms, noise) * uniforms.density * stepSize;
        }
        return opticalDepth * extinctionScale(uniforms);
    }

    // Multiple-scattering approximation (Wrenninge et al. 2013, "Oz: The Great and Volumetric"):
    // sum single-scattering octaves with progressively weaker extinction, scattering, and phase
    // anisotropy. Light that has scattered many times penetrates further and is less directional.
    float3 multipleScatteredSun(float cosSun, float3 opticalDepth) {
        const int octaves = 6;
        const float scatteringFalloff = 0.6;   // a
        const float extinctionFalloff = 0.35;  // b
        const float anisotropyFalloff = 0.5;   // c
        float3 result = 0;
        float a = 1, b = 1, c = 1;
        for (int i = 0; i < octaves; i++) {
            float octavePhase = mix(henyeyGreenstein(cosSun, -0.2 * c), henyeyGreenstein(cosSun, phaseG * c), 0.7);
            result += a * octavePhase * exp(-b * opticalDepth);
            a *= scatteringFalloff;
            b *= extinctionFalloff;
            c *= anisotropyFalloff;
        }
        return sunColor * result;
    }

    float3 rayMarch(float3 origin, float3 direction, constant CloudUniforms &uniforms, texture3d<float> noise, float jitter) {
        float tNear, tFar;
        if (!intersectBounds(origin, direction, tNear, tFar)) {
            return background(direction, uniforms, true);
        }
        const int steps = 96;
        float stepSize = (tFar - tNear) / float(steps);
        float3 transmittance = 1.0;
        float3 radiance = 0;
        float cosSun = dot(direction, uniforms.sunDirection);
        float3 scale = extinctionScale(uniforms);
        for (int i = 0; i < steps; i++) {
            float3 p = origin + direction * (tNear + (float(i) + jitter) * stepSize);
            float sigma = cloudDensity(p, uniforms, noise) * uniforms.density;
            if (sigma <= 0) {
                continue;
            }
            float3 stepTransmittance = exp(-sigma * scale * stepSize);
            // Integrate the source term analytically over the step: (1 - exp(-sigma dt)) * source / sigma.
            float3 source;
            if (uniforms.mode == 0) {
                source = emissionColor;
            } else {
                float3 sunDepth = marchedOpticalDepth(p, uniforms.sunDirection, uniforms, noise);
                float3 direct = multipleScatteredSun(cosSun, sunDepth);
                // Sky light, attenuated by the cloud above with the same softened (multiply-scattered) extinction.
                float3 skyDepth = marchedOpticalDepth(p, float3(0, 1, 0), uniforms, noise);
                float3 skyLight = 0.5 * (sky(float3(0, 1, 0), uniforms.sunDirection, false) + sky(normalize(float3(1, 0.1, 0)), uniforms.sunDirection, false));
                float3 ambient = skyLight * exp(-0.25 * skyDepth);
                source = albedo * (direct + ambient);
            }
            radiance += transmittance * (1.0 - stepTransmittance) * source;
            transmittance *= stepTransmittance;
            if (max3(transmittance.x, transmittance.y, transmittance.z) < 0.005) {
                break;
            }
        }
        return radiance + transmittance * background(direction, uniforms, true);
    }

    // MARK: - Path tracing

    // Unbiased transmittance estimate between p and the volume exit along direction, for one channel's extinction scale.
    float ratioTrackingTransmittance(float3 p, float3 direction, constant CloudUniforms &uniforms, texture3d<float> noise, float channelScale, thread RNG &rng) {
        float tNear, tFar;
        if (!intersectBounds(p, direction, tNear, tFar)) {
            return 1.0;
        }
        float majorant = uniforms.density;
        float t = tNear;
        float transmittance = 1.0;
        for (int i = 0; i < 256; i++) {
            t -= log(1.0 - rng.next()) / majorant;
            if (t >= tFar) {
                break;
            }
            transmittance *= 1.0 - cloudDensity(p + direction * t, uniforms, noise) * channelScale;
            if (transmittance < 1e-3) {
                return 0;
            }
        }
        return transmittance;
    }

    float3 pathTrace(float3 origin, float3 direction, constant CloudUniforms &uniforms, texture3d<float> noise, thread RNG &rng) {
        float majorant = uniforms.density;
        float3 throughput = 1.0;
        float3 radiance = 0;
        int bounces = 0;

        // Hero channel: with chromatic extinction each path tracks one RGB channel's medium and
        // contributes only to that channel (weighted by 3 for the 1/3 selection probability).
        float3 scale = extinctionScale(uniforms);
        float channelScale = 1.0;
        if (any(scale != 1.0)) {
            int channel = min(int(rng.next() * 3.0), 2);
            channelScale = scale[channel];
            throughput = float3(0);
            throughput[channel] = 3.0;
        }

        for (int iteration = 0; iteration < 1024; iteration++) {
            float tNear, tFar;
            if (!intersectBounds(origin, direction, tNear, tFar)) {
                // Primary rays see the background; scattered rays see sky (sun is handled by next-event estimation).
                if (bounces == 0 || uniforms.mode == 1) {
                    radiance += throughput * background(direction, uniforms, bounces == 0);
                }
                break;
            }

            // Delta (Woodcock) tracking: sample free-flight distances against the majorant,
            // accept as a real collision with probability sigma(p) / majorant.
            float t = tNear;
            bool collided = false;
            for (int i = 0; i < 512; i++) {
                t -= log(1.0 - rng.next()) / majorant;
                if (t >= tFar) {
                    break;
                }
                if (rng.next() < cloudDensity(origin + direction * t, uniforms, noise) * channelScale) {
                    collided = true;
                    break;
                }
            }

            if (!collided) {
                origin = origin + direction * (tFar + 1e-3);
                continue;
            }

            float3 p = origin + direction * t;
            if (uniforms.mode == 0) {
                // Pure absorber: every real collision absorbs and returns the emitted radiance.
                radiance += throughput * emissionColor;
                break;
            }

            // Scattering medium: absorb with probability 1 - albedo (Russian roulette on albedo).
            if (rng.next() > albedo || bounces >= uniforms.maxBounces) {
                break;
            }

            // Next-event estimation toward the sun.
            float sunTransmittance = ratioTrackingTransmittance(p, uniforms.sunDirection, uniforms, noise, channelScale, rng);
            radiance += throughput * sunColor * phase(dot(direction, uniforms.sunDirection)) * sunTransmittance;

            // Continue the walk. Picking a lobe by its mixture weight samples phase() exactly, so throughput is unchanged.
            float lobeG = rng.next() < 0.7 ? phaseG : -0.2;
            direction = sampleHenyeyGreenstein(direction, lobeG, rng.next(), rng.next());
            origin = p;
            bounces += 1;
        }
        return radiance;
    }

    // MARK: - Fragment

    [[fragment]] float4 fragment_main(
        VertexOut in [[stage_in]],
        constant CloudUniforms &uniforms [[buffer(0)]],
        texture2d<float, access::read_write> accumulation [[texture(0)]],
        texture3d<float> noise [[texture(1)]]
    ) {
        float4 nearPoint = uniforms.inverseViewProjection * float4(in.ndc, 0, 1);
        float4 farPoint = uniforms.inverseViewProjection * float4(in.ndc, 1, 1);
        float3 origin = uniforms.cameraPosition;
        float3 direction = normalize(farPoint.xyz / farPoint.w - nearPoint.xyz / nearPoint.w);

        uint2 pixel = uint2(in.position.xy);
        RNG rng { hashUInt(pixel.x * 1973u + pixel.y * 9277u + uniforms.frameIndex * 26699u) | 1u };

        float screenX = in.ndc.x * 0.5 + 0.5;
        float3 color = 0;
        if (screenX < uniforms.split) {
            color = rayMarch(origin, direction, uniforms, noise, rng.next());
        } else {
            int samples = max(uniforms.samplesPerPixel, 1);
            for (int i = 0; i < samples; i++) {
                color += pathTrace(origin, direction, uniforms, noise, rng);
            }
            color /= float(samples);

            // Progressive accumulation: running sum in rgb, sample count in alpha.
            if (pixel.x < accumulation.get_width() && pixel.y < accumulation.get_height()) {
                float4 previous = uniforms.resetAccumulation ? float4(0) : accumulation.read(pixel);
                float4 sum = previous + float4(color, 1);
                accumulation.write(sum, pixel);
                color = sum.rgb / sum.a;
            }
        }

        // Thin divider between the halves.
        float dividerWidth = abs(dfdx(screenX));
        if (uniforms.split > 0 && uniforms.split < 1 && abs(screenX - uniforms.split) < dividerWidth) {
            color = float3(1);
        }

        // Simple filmic tone map; render target is sRGB so no manual gamma.
        color = 1.0 - exp(-color * 1.2);
        return float4(color, 1);
    }

} // namespace CloudShaders
