#include "MetalSprocketsExampleShaders.h"

using namespace metal;

namespace LiquidGlass {

    // LiquidGlassUniforms is declared in LiquidGlassShaders.h, shared with Swift.
    using Uniforms = LiquidGlassUniforms;

    struct VSOut {
        float4 position [[position]];
        float2 uv;
    };

    [[vertex]] VSOut fullscreenVertex(uint vid [[vertex_id]]) {
        // Fullscreen triangle: (0,0) (2,0) (0,2) in uv space.
        float2 pos = float2((vid << 1) & 2, vid & 2);
        VSOut out;
        out.position = float4(pos * 2.0 - 1.0, 0.0, 1.0);
        out.uv = float2(pos.x, 1.0 - pos.y);
        return out;
    }

    // MARK: Background

    static half3 backgroundColor(float2 p, constant Uniforms &u, texture2d<half> textTex) {
        constexpr sampler textSampler(address::repeat, filter::linear);
        float2 res = u.resolution;
        float2 q = p / res;

        half3 col = mix(half3(0.055h, 0.06h, 0.11h), half3(0.10h, 0.05h, 0.17h), half(q.y));

        // Two soft color blobs drifting around, so refraction has something juicy to bend.
        float2 b1 = res * float2(0.30 + 0.18 * sin(u.time * 0.23), 0.35 + 0.14 * cos(u.time * 0.17));
        float2 b2 = res * float2(0.72 + 0.16 * cos(u.time * 0.19), 0.62 + 0.15 * sin(u.time * 0.29));
        col += half3(0.22h, 0.05h, 0.28h) * half(exp(-distance(p, b1) / (0.35 * res.y)));
        col += half3(0.03h, 0.17h, 0.24h) * half(exp(-distance(p, b2) / (0.30 * res.y)));

        // Marquee rows: alternate directions, per-row speeds.
        const float rows = 8.0;
        const float texAspect = 2.0;
        float v = q.y;
        float row = floor(v * rows);
        float dir = (fmod(row, 2.0) < 1.0) ? 1.0 : -1.0;
        float speed = dir * (0.025 + 0.02 * fract(row * 0.381));
        float uCoord = p.x / (res.y * texAspect) + speed * u.time;
        half text = textTex.sample(textSampler, float2(uCoord, v)).r;
        col = mix(col, half3(0.86h, 0.88h, 0.96h), text * 0.88h);

        return col;
    }

    // MARK: Glass

    static float sdPill(float2 p, float4 pill, float time, float phase) {
        float2 b = pill.zw;
        // Gentle breathing so the glass feels liquid rather than rigid.
        b += float2(sin(time * 1.1 + phase), cos(time * 1.7 + phase)) * (0.02 * b);
        float r = min(b.x, b.y);
        float2 q = abs(p - pill.xy) - b + r;
        return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
    }

    static float smin(float a, float b, float k) {
        float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
        return mix(b, a, h) - k * h * (1.0 - h);
    }

    // Smooth-min union: pills merge like liquid when they approach.
    static float sdScene(float2 p, constant Uniforms &u) {
        float d = 1e6;
        for (uint i = 0; i < u.pillCount; i++) {
            float di = sdPill(p, u.pills[i], u.time, float(i) * 2.1);
            d = smin(d, di, max(u.blend, 1.0));
        }
        return d;
    }

    static half3 blurredBackground(float2 p, float radius, constant Uniforms &u, texture2d<half> textTex) {
        if (radius < 0.25) {
            return backgroundColor(p, u, textTex);
        }
        constexpr float2 taps[6] = {
            float2(0.000, 0.000), float2(0.866, 0.500), float2(-0.866, 0.500),
            float2(0.000, -1.000), float2(0.433, -0.500), float2(-0.433, 0.866)
        };
        half3 sum = 0.0h;
        for (int i = 0; i < 6; i++) {
            sum += backgroundColor(p + taps[i] * radius, u, textTex);
        }
        return sum / 6.0h;
    }

    [[fragment]] half4 liquidGlassFragment(VSOut in [[stage_in]],
                                           constant LiquidGlassUniforms &uniforms,
                                           texture2d<half> textTexture) {
        constant Uniforms &u = uniforms;
        texture2d<half> textTex = textTexture;
        float2 p = in.uv * u.resolution;
        float d = sdScene(p, u);
        half3 col = backgroundColor(p, u, textTex);

        // Soft drop shadow outside the pill.
        if (d > 0.0) {
            col *= 1.0h - 0.30h * half(exp(-d / (0.05 * u.resolution.y)));
        }

        float aa = max(fwidth(d), 0.75);
        if (d < aa) {
            float w = max(u.bevelWidth, 1.0);

            // Circular-bevel height profile: flat top, quarter-round rim.
            float x = clamp(-d / w, 0.0, 1.0);
            float h = sqrt(max(1.0 - (1.0 - x) * (1.0 - x), 0.0));
            float dhdx = (x > 0.001 && x < 0.999) ? (1.0 - x) / max(h, 1e-3) : 0.0;

            const float eps = 1.0;
            float2 g = float2(sdScene(p + float2(eps, 0.0), u) - sdScene(p - float2(eps, 0.0), u),
                              sdScene(p + float2(0.0, eps), u) - sdScene(p - float2(0.0, eps), u));
            g = normalize(g + 1e-6);

            // Heightfield normal; leans outward at the rim, flat in the middle.
            float3 n = normalize(float3(g * dhdx, 1.0));

            // Per-channel refraction through a slab of glass for chromatic dispersion.
            float travel = w * 1.6;
            half3 refracted;
            for (int c = 0; c < 3; c++) {
                float ior = u.ior + float(c - 1) * u.dispersion;
                float3 refr = refract(float3(0.0, 0.0, -1.0), n, 1.0 / max(ior, 1.001));
                float2 offset = refr.xy * (travel / max(-refr.z, 0.2));
                half3 sample = blurredBackground(p + offset, u.frost, u, textTex);
                refracted[c] = sample[c];
            }

            // Fresnel rim glow and a keylight specular running along the bevel.
            half fresnel = half(pow(1.0 - n.z, 1.6));
            float3 light = normalize(float3(-0.4, -0.55, 0.75));
            float3 halfway = normalize(light + float3(0.0, 0.0, 1.0));
            half spec = half(pow(max(dot(n, halfway), 0.0), 90.0));
            half sheen = half(pow(max(dot(n, halfway), 0.0), 8.0));

            half3 glass = refracted * 1.04h + 0.015h;
            glass += fresnel * half3(0.35h, 0.38h, 0.45h);
            glass += spec * 0.9h + sheen * 0.08h;

            // Thin dark line just inside the edge for definition.
            glass *= 1.0h - 0.25h * half(smoothstep(3.0, 0.0, -d));

            half mask = half(smoothstep(aa, -aa, d));
            col = mix(col, glass, mask);
        }

        return half4(col, 1.0h);
    }

} // namespace LiquidGlass
