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

    float hash3(float3 p) {
        p = fract(p * 0.3183099 + 0.1);
        p *= 17.0;
        return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
    }

    float valueNoise(float3 x) {
        float3 i = floor(x);
        float3 f = fract(x);
        f = f * f * (3.0 - 2.0 * f);
        return mix(mix(mix(hash3(i + float3(0, 0, 0)), hash3(i + float3(1, 0, 0)), f.x),
                       mix(hash3(i + float3(0, 1, 0)), hash3(i + float3(1, 1, 0)), f.x), f.y),
                   mix(mix(hash3(i + float3(0, 0, 1)), hash3(i + float3(1, 0, 1)), f.x),
                       mix(hash3(i + float3(0, 1, 1)), hash3(i + float3(1, 1, 1)), f.x), f.y), f.z);
    }

    float fbm(float3 p) {
        float sum = 0;
        float amplitude = 0.5;
        for (int i = 0; i < 5; i++) {
            sum += amplitude * valueNoise(p);
            p = p * 2.03 + float3(1.7, 9.2, 3.1);
            amplitude *= 0.5;
        }
        return sum;
    }

    constant float3 boundsMin = float3(-2.2, -1.3, -1.6);
    constant float3 boundsMax = float3(2.2, 1.5, 1.6);

    // Normalised density in [0, 1]. Multiplied by uniforms.density to get the extinction coefficient.
    float cloudDensity(float3 p, float time) {
        // A few overlapping blobs give the base cumulus shape.
        float shape = 0;
        shape = max(shape, 1.0 - length((p - float3(0.0, 0.1, 0.0)) / float3(1.3, 0.9, 1.0)));
        shape = max(shape, 1.0 - length((p - float3(-1.0, -0.3, 0.2)) / float3(0.9, 0.6, 0.8)));
        shape = max(shape, 1.0 - length((p - float3(1.0, -0.4, -0.1)) / float3(0.9, 0.55, 0.8)));
        shape = max(shape, 1.0 - length((p - float3(0.3, 0.7, 0.1)) / float3(0.7, 0.6, 0.6)));
        // Flatten the bottom like a real cumulus.
        shape *= smoothstep(-0.9, -0.6, p.y);

        float3 wind = float3(time * 0.08, -time * 0.03, 0);
        float noise = fbm(p * 2.2 + wind);
        return saturate((shape * 1.6 + noise * 0.8 - 0.7) * 3.0);
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

    float3 sky(float3 direction) {
        float t = saturate(direction.y * 0.5 + 0.5);
        return mix(float3(0.55, 0.6, 0.7), float3(0.25, 0.45, 0.85), t);
    }

    float3 background(float3 direction, constant CloudUniforms &uniforms) {
        return uniforms.mode == 0 ? emissiveBackground : sky(direction);
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

    float marchedSunTransmittance(float3 p, constant CloudUniforms &uniforms) {
        float tNear, tFar;
        if (!intersectBounds(p, uniforms.sunDirection, tNear, tFar)) {
            return 1.0;
        }
        const int steps = 8;
        float stepSize = tFar / float(steps);
        float opticalDepth = 0;
        for (int i = 0; i < steps; i++) {
            float3 q = p + uniforms.sunDirection * ((float(i) + 0.5) * stepSize);
            opticalDepth += cloudDensity(q, uniforms.time) * uniforms.density * stepSize;
        }
        return exp(-opticalDepth);
    }

    float3 rayMarch(float3 origin, float3 direction, constant CloudUniforms &uniforms, float jitter) {
        float tNear, tFar;
        if (!intersectBounds(origin, direction, tNear, tFar)) {
            return background(direction, uniforms);
        }
        const int steps = 96;
        float stepSize = (tFar - tNear) / float(steps);
        float transmittance = 1.0;
        float3 radiance = 0;
        float cosSun = dot(direction, uniforms.sunDirection);
        for (int i = 0; i < steps; i++) {
            float3 p = origin + direction * (tNear + (float(i) + jitter) * stepSize);
            float sigma = cloudDensity(p, uniforms.time) * uniforms.density;
            if (sigma <= 0) {
                continue;
            }
            float stepTransmittance = exp(-sigma * stepSize);
            // Integrate the source term analytically over the step: (1 - exp(-sigma dt)) * source / sigma.
            float3 source;
            if (uniforms.mode == 0) {
                source = emissionColor;
            } else {
                float3 direct = sunColor * phase(cosSun) * marchedSunTransmittance(p, uniforms);
                // Cheap multiple-scattering stand-in: ambient sky light.
                float3 ambient = sky(float3(0, 1, 0)) * 0.6;
                source = albedo * (direct + ambient);
            }
            radiance += transmittance * (1.0 - stepTransmittance) * source;
            transmittance *= stepTransmittance;
            if (transmittance < 0.005) {
                break;
            }
        }
        return radiance + transmittance * background(direction, uniforms);
    }

    // MARK: - Path tracing

    // Unbiased transmittance estimate between p and the volume exit along direction.
    float ratioTrackingTransmittance(float3 p, float3 direction, constant CloudUniforms &uniforms, thread RNG &rng) {
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
            transmittance *= 1.0 - cloudDensity(p + direction * t, uniforms.time);
            if (transmittance < 1e-3) {
                return 0;
            }
        }
        return transmittance;
    }

    float3 pathTrace(float3 origin, float3 direction, constant CloudUniforms &uniforms, thread RNG &rng) {
        float majorant = uniforms.density;
        float3 throughput = 1.0;
        float3 radiance = 0;
        int bounces = 0;

        for (int iteration = 0; iteration < 1024; iteration++) {
            float tNear, tFar;
            if (!intersectBounds(origin, direction, tNear, tFar)) {
                // Primary rays see the background; scattered rays see sky (sun is handled by next-event estimation).
                if (bounces == 0 || uniforms.mode == 1) {
                    radiance += throughput * background(direction, uniforms);
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
                if (rng.next() < cloudDensity(origin + direction * t, uniforms.time)) {
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
            float sunTransmittance = ratioTrackingTransmittance(p, uniforms.sunDirection, uniforms, rng);
            radiance += throughput * sunColor * phase(dot(direction, uniforms.sunDirection)) * sunTransmittance;

            // Continue the walk. Sampling the forward lobe only and weighting by phase/pdf keeps it unbiased.
            float3 newDirection = sampleHenyeyGreenstein(direction, phaseG, rng.next(), rng.next());
            float cosTheta = dot(direction, newDirection);
            throughput *= phase(cosTheta) / henyeyGreenstein(cosTheta, phaseG);
            direction = newDirection;
            origin = p;
            bounces += 1;
        }
        return radiance;
    }

    // MARK: - Fragment

    [[fragment]] float4 fragment_main(
        VertexOut in [[stage_in]],
        constant CloudUniforms &uniforms [[buffer(0)]],
        texture2d<float, access::read_write> accumulation [[texture(0)]]
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
            color = rayMarch(origin, direction, uniforms, rng.next());
        } else {
            int samples = max(uniforms.samplesPerPixel, 1);
            for (int i = 0; i < samples; i++) {
                color += pathTrace(origin, direction, uniforms, rng);
            }
            color /= float(samples);

            // Progressive accumulation: running sum in rgb, averaged by frame count.
            if (pixel.x < accumulation.get_width() && pixel.y < accumulation.get_height()) {
                float3 previous = uniforms.accumulatedFrames == 0 ? float3(0) : accumulation.read(pixel).rgb;
                float3 sum = previous + color;
                accumulation.write(float4(sum, 1), pixel);
                color = sum / float(uniforms.accumulatedFrames + 1);
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
