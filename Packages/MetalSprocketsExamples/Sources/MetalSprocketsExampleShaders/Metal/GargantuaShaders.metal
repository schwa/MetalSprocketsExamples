#include "MetalSprocketsExampleShaders.h"

using namespace metal;

namespace Gargantua {

    // Uniform structs are declared in GargantuaShaders.h, shared with Swift.
    using RayUniforms = GargantuaRayUniforms;
    using CompositeUniforms = GargantuaCompositeUniforms;
    using BloomUniforms = GargantuaBloomUniforms;

    struct VOut {
        float4 position [[position]];
        float2 uv;
    };

    [[vertex]] VOut fullscreenVertex(uint vid [[vertex_id]]) {
        // one oversized triangle covering the viewport
        float2 p = float2((vid << 1) & 2, vid & 2);
        VOut o;
        o.position = float4(p * 2.0 - 1.0, 0.0, 1.0);
        o.uv = float2(p.x, 1.0 - p.y);
        return o;
    }

    #define RS 1.0

    // ---------------------------------------------------------------- noise -----
    static float hash1(float3 p) {
        p = fract(p * 0.3183099 + float3(0.10, 0.17, 0.13));
        p *= 17.0;
        return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
    }
    static float3 hash3(float3 p) {
        p = fract(p * float3(0.1031, 0.1030, 0.0973));
        p += dot(p, p.yxz + 33.33);
        return fract((p.xxy + p.yxx) * p.zyx);
    }
    static float vnoise(float3 x) {
        float3 i = floor(x);
        float3 f = fract(x);
        f = f * f * (3.0 - 2.0 * f);
        float n000 = hash1(i);
        float n100 = hash1(i + float3(1.0, 0.0, 0.0));
        float n010 = hash1(i + float3(0.0, 1.0, 0.0));
        float n110 = hash1(i + float3(1.0, 1.0, 0.0));
        float n001 = hash1(i + float3(0.0, 0.0, 1.0));
        float n101 = hash1(i + float3(1.0, 0.0, 1.0));
        float n011 = hash1(i + float3(0.0, 1.0, 1.0));
        float n111 = hash1(i + float3(1.0, 1.0, 1.0));
        return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
                   mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
    }
    // five-octave value-noise FBM, frequency x2.03 + 11.3, amplitude halved
    static float fbm(float3 p) {
        float v = 0.0;
        float a = 0.5;
        for (int i = 0; i < 5; i++) {
            v += a * vnoise(p);
            p = p * 2.03 + 11.3;
            a *= 0.5;
        }
        return v;
    }

    // ------------------------------------------------------ pseudo-blackbody ----
    static float3 blackbody(float t) {
        float3 c = mix(float3(0.55, 0.06, 0.01), float3(1.00, 0.42, 0.10), smoothstep(0.00, 0.55, t));
        c = mix(c, float3(1.00, 0.86, 0.55), smoothstep(0.50, 1.05, t));
        c = mix(c, float3(0.85, 0.92, 1.25), smoothstep(1.05, 1.90, t));
        return c;
    }

    // ------------------------------------------------------------ star field ----
    static float3x3 layerRot(float ay, float ax) {
        float cy = cos(ay), sy = sin(ay), cx = cos(ax), sx = sin(ax);
        return float3x3(float3(cy, 0.0, -sy),
                        float3(sy * sx, cx, cy * sx),
                        float3(sy * cx, -sx, cy * cx));
    }
    static float3 starLayer(float3 d, float scale, float thresh, float3x3 rot, float sharp) {
        float3 p = rot * d * scale;
        float3 id = floor(p);
        float3 f = fract(p);
        float h = hash1(id);
        if (h < thresh) { return float3(0.0); }
        float3 sp = 0.15 + 0.70 * hash3(id + 4.7);
        float dist = length(f - sp);
        float star = exp(-dist * dist * sharp);
        float bright = (h - thresh) / (1.0 - thresh);
        bright *= bright;
        float3 tint = mix(float3(0.72, 0.84, 1.0), float3(1.0, 0.86, 0.70), hash1(id + 13.1));
        return star * bright * tint * 4.0;
    }
    static float3 heroStars(float3 d) {
        float3 p = d * 14.0;
        float3 id = floor(p);
        float3 f = fract(p);
        float h = hash1(id + 91.7);
        if (h < 0.9975) { return float3(0.0); }
        float3 sp = 0.20 + 0.60 * hash3(id + 3.3);
        float dist = length(f - sp);
        float glow = exp(-dist * dist * 22.0) * 0.85 + exp(-dist * dist * 240.0) * 1.5;
        float3 tint = mix(float3(0.70, 0.82, 1.0), float3(1.0, 0.80, 0.60), step(0.5, hash1(id + 5.5)));
        return glow * tint;
    }
    static float3 milkyway(float3 d) {
        float3 n = normalize(float3(0.25, 1.0, 0.15));
        float w = dot(d, n);
        float band = exp(-w * w * 7.0);
        float3 p = d * 2.6;
        float cloud = fbm(p * 1.4 + 5.2);
        float dust = fbm(p * 2.3 + 9.1);
        float3 col = mix(float3(0.04, 0.07, 0.20), float3(0.42, 0.24, 0.52), smoothstep(0.25, 0.85, cloud));
        col *= band;
        col *= 1.0 - 0.62 * smoothstep(0.45, 0.85, dust);
        col *= 1.15;
        return col;
    }
    // milkyway() is a pure function of direction with no time dependence, so it is
    // baked into a cubemap once at startup instead of costing ten octaves of value
    // noise on every escaping ray. It is a smooth low-frequency wash, which is why
    // a modest face resolution reproduces it.
    constexpr sampler cubeLinear(filter::linear, mip_filter::none, address::clamp_to_edge);

    // ------------------------------------------------------------- disk LUT ----
    // turb and lane are pure functions of (pattern angle, qr): |rp| is exactly 1,
    // so the noise field is two-dimensional and static in the rotating frame. Both
    // are baked once. Only qr < DISK_LUT_QR matters -- past that innerDetail is 0
    // and the terms collapse to constants -- which keeps the radial range tight.
    #define DISK_LUT_QR 18.0

    constexpr sampler diskLinear(filter::linear, mip_filter::none,
                                 s_address::repeat, t_address::clamp_to_edge);

    static float2 diskNoiseAt(float theta, float qr) {
        float2 rp = float2(cos(theta), sin(theta));
        float3 pc = float3(rp.x * 3.0, rp.y * 3.0, qr * 0.85);
        float3 warp = float3(fbm(pc * 1.5),
                             fbm(pc * 1.5 + float3(5.2, 1.3, 2.8)),
                             fbm(pc * 1.5 + float3(9.7, 4.1, 7.3)));
        return float2(fbm(pc * 2.0 + warp * 1.5),
                      fbm(float3(rp.x * 5.0, rp.y * 5.0, qr * 0.55) + warp * 0.8));
    }

    // The 22x streak needs far more angular resolution than turb and lane (its
    // finest octave is 374 cycles in radius, so ~2350 around the circle) but far
    // less radial, so it gets its own tall-and-thin bake rather than forcing the
    // main LUT up to 8192 square.
    [[kernel]] void bakeDiskStreak(texture2d<float, access::write> dst,
                                   uint2 gid [[thread_position_in_grid]]) {
        if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) { return; }
        float theta = (float(gid.x) + 0.5) / float(dst.get_width()) * (2.0 * M_PI_F);
        float qr = (float(gid.y) + 0.5) / float(dst.get_height()) * DISK_LUT_QR;
        float2 rp = float2(cos(theta), sin(theta));
        dst.write(float4(fbm(float3(rp.x * 22.0, rp.y * 22.0, qr * 1.4)), 0.0, 0.0, 0.0), gid);
    }

    [[kernel]] void bakeDiskNoise(texture2d<float, access::write> dst,
                                  uint2 gid [[thread_position_in_grid]]) {
        if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) { return; }
        float theta = (float(gid.x) + 0.5) / float(dst.get_width()) * (2.0 * M_PI_F);
        float qr = (float(gid.y) + 0.5) / float(dst.get_height()) * DISK_LUT_QR;
        dst.write(float4(diskNoiseAt(theta, qr), 0.0, 0.0), gid);
    }

    [[kernel]] void bakeMilkyway(texturecube<float, access::write> dst,
                                 uint3 gid [[thread_position_in_grid]]) {
        float size = float(dst.get_width());
        if (gid.x >= dst.get_width() || gid.y >= dst.get_width()) { return; }
        float2 uv = (float2(gid.xy) + 0.5) / size * 2.0 - 1.0;
        float3 d;
        switch (gid.z) {
            case 0: d = float3( 1.0, -uv.y, -uv.x); break;
            case 1: d = float3(-1.0, -uv.y,  uv.x); break;
            case 2: d = float3( uv.x,  1.0,  uv.y); break;
            case 3: d = float3( uv.x, -1.0, -uv.y); break;
            case 4: d = float3( uv.x, -uv.y,  1.0); break;
            default: d = float3(-uv.x, -uv.y, -1.0); break;
        }
        dst.write(float4(milkyway(normalize(d)), 1.0), gid.xy, gid.z);
    }

    static float3 background(float3 d, float skyFloor, float starBright,
                             texturecube<float> milkywayMap) {
        float3 col = skyFloor * float3(0.10, 0.13, 0.28);
        col += milkywayMap.sample(cubeLinear, d).rgb;
        col += starLayer(d, 26.0, 0.952, layerRot(0.7, 0.4), 120.0);
        col += starLayer(d, 47.0, 0.952, layerRot(2.1, 1.1), 200.0);
        col += starLayer(d, 83.0, 0.952, layerRot(4.0, 2.3), 320.0);
        col += starLayer(d, 150.0, 0.968, layerRot(5.3, 0.9), 480.0);
        col += heroStars(d);
        return col * starBright;
    }

    // Schwarzschild null-geodesic acceleration (c = G = 1, RS = 1).
    // v is a unit vector, so |p x v|^2 = |p|^2 - (p.v)^2 and the cross product
    // never has to be formed; callers that already know r2 and p.v pass them in.
    // r must equal sqrt(r2); the march already has it, so no sqrt is taken here.
    static float3 accAt(float3 p, float r2, float r, float pdotv) {
        float h2 = max(r2 - pdotv * pdotv, 0.0);
        return -1.5 * RS * h2 / (r2 * r2 * r) * p;
    }
    static float3 accAt(float3 p, float3 v) {
        float r2 = dot(p, p);
        return accAt(p, r2, sqrt(r2), dot(p, v));
    }

    struct RayState {
        float3 col;
        float trans;
        float crossCount;
        float validCross;
        float firstAng;
        float crossRad;
        float turbDbg;
    };

    // Accretion-disk plane crossing (multiple crossings permitted).
    // Returns true when front-to-back opacity saturates (ray absorbed by disk).
    static bool diskCross(float3 a, float3 b, float3 rayDir,
                          thread RayState &st, constant RayUniforms &U,
                          texture2d<float> diskNoise, texture2d<float> diskStreak) {
        if (a.y * b.y > 0.0) { return false; }
        float din = U.p0.x, dout = U.p0.y, dopMax = U.p0.z, opNear = U.p0.w;
        float opFar = U.p1.x, diskBright = U.p1.y;
        float rotSpeed = U.p2.x, rotSign = U.p2.y;
        float uTime = U.resTimeFov.z;

        float t = abs(a.y) / (abs(a.y) + abs(b.y) + 1e-5);
        float3 q = mix(a, b, t);
        float qr = length(q.xz);
        st.crossCount += 1.0;
        if (qr <= din || qr >= dout) { return false; }
        st.validCross += 1.0;
        float ang = atan2(q.z, q.x);
        if (st.validCross < 1.5) { st.firstAng = ang; st.crossRad = qr; }

        // Novikov-Thorne style flux, ISCO = 3 RS
        float x = max(qr, 3.001);
        float u = 3.0 / x;
        float su = sqrt(u);
        float flux = max(u * u * u * (1.0 - su), 0.0);
        float temp = sqrt(sqrt(flux * 10.0));

        // seamless rotating pattern coords (rotate cartesian, never atan-sample)
        float w = 3.0 / qr;
        float omega = rotSign * 1.1 * rotSpeed * w * sqrt(w);
        float rot = omega * uTime;
        float ca = cos(rot), sa = sin(rot);
        float3 qp = float3(ca * q.x + sa * q.z, 0.0, -sa * q.x + ca * q.z);
        float2 rp = qp.xz / qr;

        // turbulence: warp at 1.5x, inner detail, 22x streaks, lane mask
        float innerDetail = 1.0 - smoothstep(4.0, 18.0, qr);
        // past qr = 18 innerDetail is exactly 0 and every noise term collapses to
        // its constant end of the mix, so all six FBMs are dead work out there
        float turb = 0.50, streak = 0.95, laneMask = 0.85;
        if (innerDetail > 0.0) {
            // rp sits at angle (ang - rot), and the LUT wraps in that axis, so no
            // extra atan2 is needed -- both terms are already known.
            float2 uv = float2((ang - rot) * (0.5 / M_PI_F), qr * (1.0 / DISK_LUT_QR));
            float2 lut = diskNoise.sample(diskLinear, uv).rg;
            turb = mix(0.50, lut.r * 1.7, innerDetail);
            float streakN = diskStreak.sample(diskLinear, uv).r;
            streak = mix(0.95, mix(0.55, 1.15, smoothstep(0.25, 0.85, streakN)), innerDetail);
            laneMask = mix(0.85, mix(0.50, 1.30, smoothstep(0.15, 0.80, lut.g)), innerDetail);
        }
        // radial gain: inner disk fierce, outer disk a dim smooth haze
        float radialGain = mix(0.38, 1.0, innerDetail);
        st.turbDbg = turb;

        float I = flux * 11.0 * turb * streak * laneMask * radialGain;
        float glowD = (qr - 3.1) * 3.0;
        I += exp(-glowD * glowD) * 2.8;                          // inner glow
        float outerFade = 1.0 - smoothstep(dout - 14.0, dout, qr);
        I *= outerFade;

        // relativistic beaming + gravitational redshift
        float beta = sqrt(0.5 / qr);
        float gamma = 1.0 / sqrt(max(1.0 - beta * beta, 1e-4));
        float3 tdir = normalize(float3(-sin(ang), 0.0, cos(ang))) * rotSign;
        float dop = 1.0 / (gamma * (1.0 - dot(tdir * beta, rayDir)));
        dop = clamp(dop, 0.50, dopMax);
        float g = sqrt(max(1.0 - RS / qr, 0.0));

        float3 dcol = blackbody(temp * dop * g) * I * (dop * dop * dop) * g * diskBright;
        float alpha = mix(opFar, opNear, 1.0 - smoothstep(4.0, 13.0, qr)) * outerFade;
        st.col += st.trans * alpha * dcol;
        st.trans *= 1.0 - alpha;
        if (st.trans < 0.02) { st.trans = 0.0; return true; }
        return false;
    }

    // ------------------------------------------------------------------ main ----
    [[fragment]] float4 rayFragment(VOut in [[stage_in]],
                                    constant RayUniforms &uniforms,
                                    texturecube<float> milkywayMap,
                                    texture2d<float> diskNoise,
                                    texture2d<float> diskStreak,
                                    uint simdWidth [[threads_per_simdgroup]]) {
        constant RayUniforms &U = uniforms;
        float2 uRes = U.resTimeFov.xy;
        float uFov = U.resTimeFov.w;
        int uSteps = int(U.p2.z);
        int uDebug = int(U.p2.w);
        float din = U.p0.x, dout = U.p0.y;
        float diskBright = U.p1.y, starBright = U.p1.z, skyFloor = U.p1.w;

        // Metal's fragment position is top-left origin; flip to match GL.
        float2 fragCoord = float2(in.position.x, uRes.y - in.position.y);
        float2 p = (fragCoord - 0.5 * uRes) / uRes.y;
        float3 ro = U.camPos.xyz;
        float3 ww = normalize(U.camTarget.xyz - ro);
        float3 uu = normalize(cross(ww, float3(0.0, 1.0, 0.0)));
        float3 vv = cross(uu, ww);
        float3 rd = normalize(p.x * uu + p.y * vv + uFov * ww);

        float3 pos = ro;
        float3 vel = rd;
        RayState st;
        st.col = float3(0.0);              // disk accumulator (front-to-back)
        st.trans = 1.0;
        st.crossCount = 0.0;
        st.validCross = 0.0;
        st.firstAng = 0.0;
        st.crossRad = 0.0;
        st.turbDbg = 0.0;

        // |p x v|^2 is conserved along a null geodesic, so the ray's impact
        // parameter is known before the march starts. Rays near the critical value
        // b = 3*sqrt(3)/2 either fall in or skim back out; for them a pixel is a
        // black/bright coin flip, so they get the reference treatment -- no
        // striding and the RK2 refinement near the hole. Everything else, which is
        // the overwhelming majority of the frame, strides with plain Euler.
        float bImpact2 = max(dot(ro, ro) - dot(ro, rd) * dot(ro, rd), 0.0);
        bool nearCritical = bImpact2 <= 12.25;

        float3 haloCol = float3(0.0);      // volumetric halo (dropped if captured)
        float minR = 1e5;
        float lastR = length(ro);
        int stepsUsed = 0;

        for (int i = 0; i < 600; i++) {
            if (i >= uSteps) { break; }
            float r2 = dot(pos, pos);
            float r = sqrt(r2);
            float pdotv = dot(pos, vel);
            lastR = r;
            if (r < 1.03 * RS) { st.trans = 0.0; break; }          // event horizon
            if (r > 45.0 && pdotv > 0.0) { break; }                // escaped
            stepsUsed = i + 1;
            minR = min(minR, r);

            float dt = max(0.012, r * mix(0.02, 0.06, smoothstep(6.0, 20.0, r)));

            // thin volumetric halo hugging the disk plane
            float absY = abs(pos.y);

            // Rays high above or below the disk plane can stride further without
            // losing anything. |vel| is 1, so a step shorter than absY cannot reach
            // y = 0, and since r >= absY it cannot overshoot the hole either. The
            // stride is still capped by the per-step deflection 1.5 * h2 / r^4 so
            // trajectories bend no more coarsely than the fixed schedule allows.
            if (!nearCritical) {
                float h2 = max(r2 - pdotv * pdotv, 0.0);
                float dtBend = 0.0002 * (r2 * r2) / (1.5 * max(h2, 1e-4));
                dt = max(dt, min(0.9 * absY, dtBend));
            }
            // beyond dout - 1 the radial fade is exactly zero, so the whole halo
            // term (blackbody, flux, exp) is dead work out there
            if (absY < 0.45 && r > din && r < dout - 1.0) {
                float dens = exp(-absY * 30.0) * 0.03 * (1.0 - smoothstep(10.0, dout - 1.0, r));
                float xh = max(r, 3.001);
                float uh = 3.0 / xh;
                float fluxh = max(uh * uh * uh * (1.0 - sqrt(uh)), 0.0);
                float3 glowc = blackbody(sqrt(sqrt(fluxh * 10.0)) * 0.9);
                haloCol += st.trans * glowc * (fluxh * 3.5) * dens * dt * diskBright;
            }

            if (nearCritical && r < 4.4) {
                // two fixed half-substeps with midpoint acceleration (RK2); total
                // advancement still matches dt
                float hdt = dt * 0.5;
                bool absorbed = false;
                for (int s = 0; s < 2; s++) {
                    float3 k1 = (s == 0) ? accAt(pos, r2, r, pdotv) : accAt(pos, vel);
                    float3 pm = pos + vel * (hdt * 0.5);
                    float3 vm = normalize(vel + k1 * (hdt * 0.5));
                    float3 k2 = accAt(pm, vm);
                    float3 pn = pos + vm * hdt;
                    vel = normalize(vel + k2 * hdt);
                    if (diskCross(pos, pn, vel, st, U, diskNoise, diskStreak)) { absorbed = true; }
                    pos = pn;
                    minR = min(minR, length(pos));
                }
                if (absorbed) { break; }
            } else {
                vel = normalize(vel + accAt(pos, r2, r, pdotv) * dt);
                float3 npos = pos + vel * dt;
                if (diskCross(pos, npos, vel, st, U, diskNoise, diskStreak)) {
                    pos = npos;
                    break;
                }
                pos = npos;
            }
        }

        // lensed background sampled only in the final escape direction
        float3 bgAdd = float3(0.0);
        if (st.trans > 0.0) {
            float deep = clamp((lastR - 1.03) * 0.45, 0.45, 1.0);
            st.col += haloCol * deep;
            bgAdd = st.trans * background(vel, skyFloor, starBright, milkywayMap) * deep;
        }
        // photon ring from the tracked perigee (thin critical curve, bloom-fed)
        float ringD = (minR - 1.55) * 4.0;
        float3 ringAdd = float3(1.0, 0.92, 0.80) * exp(-ringD * ringD) * 0.05;

        float3 outCol;
        if (uDebug == 1) {                     // disk / halo only
            outCol = st.col;
        } else if (uDebug == 2) {              // lensed background only
            outCol = bgAdd;
        } else if (uDebug == 3) {              // step usage
            outCol = float3(float(stepsUsed) / float(max(uSteps, 1)));
        } else if (uDebug == 4) {              // first-crossing radius map
            float v = clamp(st.crossRad / max(dout, 1e-3), 0.0, 1.0);
            outCol = (st.validCross > 0.5) ? float3(v, v * (1.0 - v) * 2.4, 1.0 - v) : float3(0.0);
        } else if (uDebug == 5) {              // raw turbulence
            outCol = float3(clamp(st.turbDbg, 0.0, 1.0));
        } else if (uDebug == 6) {              // minR (red) / crossing count (green)
            outCol = float3(clamp(minR / 12.0, 0.0, 1.0), clamp(st.crossCount / 4.0, 0.0, 1.0), 0.0);
        } else if (uDebug == 7) {              // valid crossing count
            if (st.validCross < 0.5)      { outCol = float3(0.0); }
            else if (st.validCross < 1.5) { outCol = float3(0.0, 0.0, 1.0); }
            else if (st.validCross < 2.5) { outCol = float3(0.0, 1.0, 0.0); }
            else                          { outCol = float3(1.0, 0.0, 0.0); }
        } else if (uDebug == 8) {              // three-phase sine of first crossing angle
            outCol = (st.validCross > 0.5)
                ? 0.5 + 0.5 * sin(st.firstAng + float3(0.0, 2.0944, 4.1888))
                : float3(0.0);
        } else if (uDebug == 9) {              // crossing-radius bands
            float band = fmod(floor(st.crossRad), 2.0);
            outCol = (st.validCross > 0.5)
                ? mix(float3(0.05, 0.15, 0.45), float3(0.95, 0.55, 0.15), band)
                : float3(0.0);
        } else if (uDebug == 10) {             // SIMD occupancy: mean / max steps
            float mine = float(stepsUsed);
            float groupMax = simd_max(mine);
            float groupMean = simd_sum(mine) / float(simdWidth);
            outCol = float3(groupMean / max(groupMax, 1.0));
        } else {                               // 0 - normal
            outCol = st.col + bgAdd + ringAdd;
        }

        outCol = clamp(max(outCol, float3(0.0)), float3(0.0), float3(64.0));
        return float4(outCol, 1.0);
    }

    // ============================================================= bloom chain ==
    constexpr sampler linearClamp(filter::linear, mip_filter::none, address::clamp_to_edge);

    // Progressive dual-filter bloom (Jimenez, "Next Generation Post Processing in
    // Call of Duty: Advanced Warfare"): a 13-tap downsample pyramid followed by
    // tent-filter upsampling that accumulates back into each larger mip. Runs as
    // compute so the whole chain fits in one encoder instead of eleven render
    // passes ping-ponging through scratch textures.

    /// 13-tap box-of-boxes downsample, centred on `uv` in the source texture.
    static float3 downsample13(texture2d<float, access::sample> src, float2 uv, float2 t) {
        float3 a = src.sample(linearClamp, uv + float2(-2.0 * t.x,  2.0 * t.y)).rgb;
        float3 b = src.sample(linearClamp, uv + float2( 0.0,        2.0 * t.y)).rgb;
        float3 c = src.sample(linearClamp, uv + float2( 2.0 * t.x,  2.0 * t.y)).rgb;
        float3 d = src.sample(linearClamp, uv + float2(-2.0 * t.x,  0.0)).rgb;
        float3 e = src.sample(linearClamp, uv).rgb;
        float3 f = src.sample(linearClamp, uv + float2( 2.0 * t.x,  0.0)).rgb;
        float3 g = src.sample(linearClamp, uv + float2(-2.0 * t.x, -2.0 * t.y)).rgb;
        float3 h = src.sample(linearClamp, uv + float2( 0.0,       -2.0 * t.y)).rgb;
        float3 i = src.sample(linearClamp, uv + float2( 2.0 * t.x, -2.0 * t.y)).rgb;
        float3 j = src.sample(linearClamp, uv + float2(-t.x,  t.y)).rgb;
        float3 k = src.sample(linearClamp, uv + float2( t.x,  t.y)).rgb;
        float3 l = src.sample(linearClamp, uv + float2(-t.x, -t.y)).rgb;
        float3 m = src.sample(linearClamp, uv + float2( t.x, -t.y)).rgb;
        return e * 0.125
             + (a + c + g + i) * 0.03125
             + (b + d + f + h) * 0.0625
             + (j + k + l + m) * 0.125;
    }

    static float2 destUV(uint2 gid, texture2d<float, access::write> dst) {
        return (float2(gid) + 0.5) / float2(dst.get_width(), dst.get_height());
    }

    // scene -> mip 0: luminosity high pass fused into the first downsample
    [[kernel]] void bloomPrefilter(texture2d<float, access::sample> src,
                                   texture2d<float, access::write> dst,
                                   constant BloomUniforms &uniforms,
                                   uint2 gid [[thread_position_in_grid]]) {
        if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) { return; }
        float3 c = downsample13(src, destUV(gid, dst), uniforms.a.xy);
        float v = dot(c, float3(0.2126, 0.7152, 0.0722));
        float threshold = uniforms.a.z;
        float alpha = smoothstep(threshold - 0.01, threshold + 0.01, v);
        dst.write(float4(c * alpha, 1.0), gid);
    }

    // mip N -> mip N+1
    [[kernel]] void bloomDownsample(texture2d<float, access::sample> src,
                                    texture2d<float, access::write> dst,
                                    constant BloomUniforms &uniforms,
                                    uint2 gid [[thread_position_in_grid]]) {
        if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) { return; }
        dst.write(float4(downsample13(src, destUV(gid, dst), uniforms.a.xy), 1.0), gid);
    }

    // mip N+1 -> mip N: 3x3 tent, added on top of what is already there
    [[kernel]] void bloomUpsample(texture2d<float, access::sample> src,
                                  texture2d<float, access::read_write> dst,
                                  constant BloomUniforms &uniforms,
                                  uint2 gid [[thread_position_in_grid]]) {
        if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) { return; }
        float2 uv = (float2(gid) + 0.5) / float2(dst.get_width(), dst.get_height());
        float2 r = uniforms.a.xy * uniforms.a.w;
        float3 sum = src.sample(linearClamp, uv + float2(-r.x,  r.y)).rgb
                   + src.sample(linearClamp, uv + float2( 0.0,  r.y)).rgb * 2.0
                   + src.sample(linearClamp, uv + float2( r.x,  r.y)).rgb
                   + src.sample(linearClamp, uv + float2(-r.x,  0.0)).rgb * 2.0
                   + src.sample(linearClamp, uv).rgb * 4.0
                   + src.sample(linearClamp, uv + float2( r.x,  0.0)).rgb * 2.0
                   + src.sample(linearClamp, uv + float2(-r.x, -r.y)).rgb
                   + src.sample(linearClamp, uv + float2( 0.0, -r.y)).rgb * 2.0
                   + src.sample(linearClamp, uv + float2( r.x, -r.y)).rgb;
        float3 base = dst.read(gid).rgb;
        dst.write(float4(base + sum * (1.0 / 16.0), 1.0), gid);
    }

    // final tone map / grade, with the bloom pyramid folded in
    [[fragment]] float4 compositeFragment(VOut in [[stage_in]],
                                          texture2d<float> scene,
                                          texture2d<float> bloomTex,
                                          constant CompositeUniforms &uniforms) {
        constant CompositeUniforms &U = uniforms;
        float2 uRes = U.a.xy;
        float uTime = U.a.z;
        float uVignette = U.a.w;
        float uGrain = U.b.x, uCA = U.b.y, strength = U.b.z;

        float2 uv = in.uv;
        float2 dir = uv - 0.5;

        // chromatic aberration (radial, R/B symmetric)
        float ca = uCA * dot(dir, dir);
        float3 col;
        col.r = scene.sample(linearClamp, uv + dir * ca).r;
        col.g = scene.sample(linearClamp, uv).g;
        col.b = scene.sample(linearClamp, uv - dir * ca).b;

        // bloom pyramid, already accumulated into mip 0 by the upsample chain
        col += strength * bloomTex.sample(linearClamp, uv).rgb;

        // manual ACES (no hardware tone mapping in the pipe)
        col *= 0.95;
        col = clamp((col * (2.51 * col + 0.03)) / (col * (2.43 * col + 0.59) + 0.14), 0.0, 1.0);

        // aspect-aware vignette
        float aspect = uRes.x / max(uRes.y, 1.0);
        float vig = smoothstep(1.30, 0.30, length(dir * float2(aspect, 1.0)) * 1.15);
        col *= mix(1.0, vig, uVignette);

        // animated fine grain, centered [-.5,.5]
        float2 fc = in.position.xy;
        float g = fract(sin(dot(fc + fract(uTime * 13.7) * 97.0, float2(127.1, 311.7))) * 43758.5453) - 0.5;
        col += g * uGrain * (1.0 - 0.5 * col);

        return float4(col, 1.0);
    }

} // namespace Gargantua
