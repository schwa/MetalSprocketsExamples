#include "MetalSprocketsExampleShaders.h"

using namespace metal;

// ---------------------------------------------------------------------------
// 2001: A Space Odyssey "Stargate" / slit-scan effect.
//
// Douglas Trumbull's original effect was achieved optically by exposing a
// single slit of film at a time while moving artwork past the camera, then
// repeating across the frame. Here we fake the look procedurally:
//   * A full-screen triangle is drawn (no geometry required).
//   * The fragment shader warps screen coordinates into a "tunnel" where
//     depth is a function of the distance from the center axis.
//   * Streaks of colour are produced by sampling a noise-ish palette along
//     the tunnel's depth axis, stretched by the slit-scan direction.
//
// Five fragment variants (v1–v5) evolve the effect from a simple radial
// tunnel to the organic vertical-vanishing-line look of the film.
// ---------------------------------------------------------------------------

namespace Stargate {

    struct FSOut {
        float4 position [[position]];
        float2 uv;
    };

    // Fullscreen triangle: emits a single oversized triangle that covers the
    // viewport without needing a vertex buffer. vid ∈ {0,1,2}.
    [[vertex]] FSOut stargateVertex(uint vid [[vertex_id]]) {
        float2 positions[3] = {
            float2(-1.0, -1.0),
            float2( 3.0, -1.0),
            float2(-1.0,  3.0)
        };
        float2 p = positions[vid];
        FSOut out;
        out.position = float4(p, 0.0, 1.0);
        // UV in 0..1 across the visible portion of the triangle.
        out.uv = (p * 0.5) + 0.5;
        return out;
    }

    // Cheap hash-based pseudo-noise. Good enough for coloured streaks.
    static inline float hash(float2 p) {
        p = fract(p * float2(123.34, 456.21));
        p += dot(p, p + 45.32);
        return fract(p.x * p.y);
    }

    static inline float3 palette(float t) {
        // Iconic Stargate colours: electric blue/cyan, magenta, orange, green.
        float3 a = float3(0.5, 0.5, 0.5);
        float3 b = float3(0.5, 0.5, 0.5);
        float3 c = float3(1.0, 1.0, 1.0);
        float3 d = float3(0.0, 0.33, 0.67);
        return a + b * cos(6.2831853 * (c * t + d));
    }

    // Toggle flags - must match StargateFeatures in StargateDemoView.swift.
    constant uint FEATURE_STREAKS       = 1u << 0;
    constant uint FEATURE_SLICE_FADE    = 1u << 1;
    constant uint FEATURE_RADIAL_BANDS  = 1u << 2;
    constant uint FEATURE_CORE          = 1u << 3;
    constant uint FEATURE_VIGNETTE      = 1u << 4;
    constant uint FEATURE_FLICKER      = 1u << 5;
    constant uint FEATURE_FILM_TONE     = 1u << 6;
    constant uint FEATURE_COLOR_PALETTE = 1u << 7;
    constant uint FEATURE_TUNNEL_GRID   = 1u << 8;

    [[fragment]] float4 stargateFragment_v1(
        FSOut in [[stage_in]],
        constant float &time,
        constant float2 &resolution,
        constant uint &features
    ) {
        // Aspect-correct centered coordinates. p.x,p.y in roughly [-1,1].
        float2 p = in.uv * 2.0 - 1.0;
        p.x *= resolution.x / max(resolution.y, 1.0);

        // Small offset so we never divide by zero exactly on-axis.
        float r = length(p) + 1e-4;
        float a = atan2(p.y, p.x);

        // Tunnel coordinates:
        //   * u wraps around the tunnel (azimuth)
        //   * v is depth along the tunnel, racing toward us as time advances
        float u = a / 6.2831853;            // -0.5 .. 0.5
        float v = 1.0 / r;                   // blows up near centre (vanishing point)

        // The slit-scan look: streaks are stretched along depth, not azimuth.
        // Quantise v into depth "slices" and jitter their colour over time.
        float depth = v + time * 1.2;
        float slice = floor(depth * 6.0);
        float sliceF = fract(depth * 6.0);

        // Per-slice streak colour, modulated around the tunnel.
        float n = hash(float2(slice, floor(u * 64.0)));
        float3 streak = (features & FEATURE_COLOR_PALETTE)
            ? palette(n + time * 0.05 + u * 2.0)
            : float3(n);  // grayscale fallback

        // Radial streaks: sharpen bands along the azimuth.
        float bands = 1.0;
        if (features & FEATURE_RADIAL_BANDS) {
            bands = 0.5 + 0.5 * cos(u * 120.0 + n * 30.0 + time * 2.0);
            bands = pow(bands, 6.0);
        }

        // Fade streaks along each depth slice so they look like moving lines,
        // not a flat checkerboard.
        float along = 1.0;
        if (features & FEATURE_SLICE_FADE) {
            along = smoothstep(0.0, 0.15, sliceF) * smoothstep(1.0, 0.85, sliceF);
        }

        float3 color = float3(0.0);
        if (features & FEATURE_STREAKS) {
            color = streak * bands * along;
        }

        // Bright hot core at the vanishing point, and a falloff toward the edges
        // so the frame doesn't read as a flat colour field.
        if (features & FEATURE_CORE) {
            float core = smoothstep(0.6, 0.0, r);
            color += float3(1.0, 0.95, 0.8) * core * 0.9;
        }

        // Subtle vignette.
        if (features & FEATURE_VIGNETTE) {
            float vignette = smoothstep(1.6, 0.3, r);
            color *= vignette;
        }

        // Gentle flicker to evoke film.
        if (features & FEATURE_FLICKER) {
            float flicker = 0.92 + 0.08 * hash(float2(floor(time * 48.0), 7.0));
            color *= flicker;
        }

        // Tone shape: lift blacks slightly for that 70s film feel.
        if (features & FEATURE_FILM_TONE) {
            color = pow(max(color, 0.0), float3(0.9));
        }

        return float4(color, 1.0);
    }

    // -----------------------------------------------------------------------
    // V2 - vertical-line vanishing point (closer to the actual 2001 shot).
    //
    // Instead of a single centred vanishing *point*, V2 uses a vertical
    // vanishing *line* at x = 0. Streaks rush horizontally outward from that
    // line; their vertical position is (nearly) preserved, so you get long
    // horizontal ribbons instead of radial spokes.
    // -----------------------------------------------------------------------

    [[fragment]] float4 stargateFragment_v2(
        FSOut in [[stage_in]],
        constant float &time,
        constant float2 &resolution,
        constant uint &features
    ) {
        // Aspect-correct centered coords.
        float2 p = in.uv * 2.0 - 1.0;
        p.x *= resolution.x / max(resolution.y, 1.0);

        // Horizontal distance from the vertical vanishing line.
        float ax = abs(p.x) + 1e-4;
        float side = sign(p.x);          // which side of the line we're on (-1 / +1)
        float y = p.y;                    // vertical position = which streak

        // Depth along the line of travel. Small |x| => far away, big |x| => near.
        // This is the direct analogue of r->1/r from V1 but only in x.
        float depth = 1.0 / ax;

        // Streaks race outward from the line. Time pushes depth toward the viewer.
        float scroll = depth + time * 1.2;
        float slice = floor(scroll * 4.0);
        float sliceF = fract(scroll * 4.0);

        // "Which streak am I" = vertical position, subtly warped by depth so the
        // ribbons fan very slightly instead of being perfectly parallel.
        float streakId = floor(y * 40.0 + side * 0.5);

        // Per-(slice, streak) colour.
        float n = hash(float2(slice, streakId + side * 1000.0));
        float3 streak = (features & FEATURE_COLOR_PALETTE)
            ? palette(n + time * 0.05 + y * 1.2)
            : float3(n);

        // Thin horizontal ribbons: sharpen along y so the streaks read as many
        // tight parallel lines rather than broad blocks.
        float bands = 1.0;
        if (features & FEATURE_RADIAL_BANDS) {
            bands = 0.5 + 0.5 * cos(y * 180.0 + n * 30.0 + time * 1.5);
            bands = pow(bands, 6.0);
        }

        // Fade each depth slice in/out so ribbons look like moving lines.
        float along = 1.0;
        if (features & FEATURE_SLICE_FADE) {
            along = smoothstep(0.0, 0.15, sliceF) * smoothstep(1.0, 0.85, sliceF);
        }

        float3 color = float3(0.0);
        if (features & FEATURE_STREAKS) {
            color = streak * bands * along;
        }

        // "Hot core" for V2: a bright vertical seam along x = 0 (the vanishing
        // line), not a central point.
        if (features & FEATURE_CORE) {
            float core = smoothstep(0.12, 0.0, ax);
            color += float3(1.0, 0.95, 0.8) * core * 0.9;
        }

        // Horizontal-biased vignette: darken the far left/right edges and a bit
        // of top/bottom. Keeps eyes drawn toward the vertical line.
        if (features & FEATURE_VIGNETTE) {
            float vx = smoothstep(1.6, 0.2, ax);
            float vy = smoothstep(1.4, 0.2, abs(y));
            color *= vx * vy;
        }

        if (features & FEATURE_FLICKER) {
            float flicker = 0.92 + 0.08 * hash(float2(floor(time * 48.0), 7.0));
            color *= flicker;
        }

        if (features & FEATURE_FILM_TONE) {
            color = pow(max(color, 0.0), float3(0.9));
        }

        return float4(color, 1.0);
    }

    // -----------------------------------------------------------------------
    // V3 - vertical vanishing line + receding grid tunnel.
    //
    // Adds two things on top of V2:
    //  1) Each streak has a random length class: most are short pulses, some
    //     are long ribbons. This is done by making `along` depend not just on
    //     the slice, but on per-streak "length" and "phase" hashes.
    //  2) A receding rectangular tunnel of glowing cells - floor, ceiling,
    //     and two side walls - all converging on the same vertical vanishing
    //     line.
    // -----------------------------------------------------------------------

    // Render one wall of the receding tunnel.
    //   ax:        horizontal distance from vanishing line (depth proxy)
    //   wallCoord: position across the wall (-1 to 1)
    //   wallAxis:  0 = floor/ceiling, 1 = sidewall (seeds differently)
    //   side:      -1 left, +1 right
    static inline float3 tunnelWall(float ax, float wallCoord, float wallAxis, float side, float time, uint features) {
        float depth = 1.0 / (ax + 1e-4);
        float scroll = depth + time * 1.5;

        float cellDepth = floor(scroll * 3.0);
        float cellAcross = floor(wallCoord * 12.0);

        float depthFrac = fract(scroll * 3.0);
        float acrossFrac = fract(wallCoord * 12.0);

        // Per-cell random: some cells dark, others glowing.
        float lit = hash(float2(cellDepth, cellAcross + wallAxis * 17.0 + side * 53.0));
        if (lit < 0.55) return float3(0.0);

        // Cell interior with dark grout.
        float inset = 0.15;
        float cellMask = smoothstep(inset, inset + 0.05, depthFrac)
                       * smoothstep(1.0 - inset, 1.0 - inset - 0.05, depthFrac)
                       * smoothstep(inset, inset + 0.05, acrossFrac)
                       * smoothstep(1.0 - inset, 1.0 - inset - 0.05, acrossFrac);

        float3 col = (features & FEATURE_COLOR_PALETTE)
            ? palette(lit + time * 0.03 + wallAxis * 0.2)
            : float3(lit);

        float fade = smoothstep(0.0, 0.05, ax) * smoothstep(1.8, 0.6, ax);
        return col * cellMask * fade * 0.8;
    }

    [[fragment]] float4 stargateFragment_v3(
        FSOut in [[stage_in]],
        constant float &time,
        constant float2 &resolution,
        constant uint &features
    ) {
        float2 p = in.uv * 2.0 - 1.0;
        p.x *= resolution.x / max(resolution.y, 1.0);

        float ax = abs(p.x) + 1e-4;
        float side = sign(p.x);
        float y = p.y;
        float yAbs = abs(y);

        // ----- Horizontal streak layer (variable-length streaks) -----------
        float depth = 1.0 / ax;
        float scroll = depth + time * 1.2;
        float slice = floor(scroll * 4.0);
        float sliceF = fract(scroll * 4.0);

        float streakId = floor(y * 50.0 + side * 0.5);

        // Per-streak length class: ~30% long ribbons, ~70% short pulses.
        float lenHash = hash(float2(streakId, side * 7.0 + 3.0));
        float isLong = step(0.7, lenHash);

        float n = hash(float2(slice, streakId + side * 1000.0));

        float3 streak = (features & FEATURE_COLOR_PALETTE)
            ? palette(n + time * 0.05 + y * 1.2)
            : float3(n);

        float bands = 1.0;
        if (features & FEATURE_RADIAL_BANDS) {
            bands = 0.5 + 0.5 * cos(y * 220.0 + n * 30.0 + time * 1.5);
            bands = pow(bands, 8.0);
        }

        float along = 1.0;
        if (features & FEATURE_SLICE_FADE) {
            // Short pulse: tight hot spike. Long ribbon: gentle envelope.
            float pulse = pow(max(0.0, sin(sliceF * 3.1415926)), 8.0);
            float ribbon = smoothstep(0.0, 0.15, sliceF) * smoothstep(1.0, 0.85, sliceF);
            along = mix(pulse, ribbon, isLong);
        }

        float3 color = float3(0.0);
        if (features & FEATURE_STREAKS) {
            color = streak * bands * along;
        }

        // ----- Receding grid tunnel ----------------------------------------
        // Floor/ceiling: only visible where |y| is large enough.
        float floorGate = smoothstep(0.15, 0.25, yAbs);
        color += tunnelWall(ax, y * 1.2, 0.0, side, time, features) * floorGate;

        // Side walls: only visible where |y| is small (eye-level band).
        float sideGate = smoothstep(0.9, 0.7, yAbs);
        color += tunnelWall(ax, y, 1.0, side, time, features) * sideGate;

        // ----- Hot bloomed vertical seam -----------------------------------
        if (features & FEATURE_CORE) {
            float core = smoothstep(0.14, 0.0, ax);
            float bloom = smoothstep(0.45, 0.0, ax) * 0.35;
            color += float3(1.0, 0.95, 0.85) * (core + bloom);
        }

        // ----- Vignette ----------------------------------------------------
        if (features & FEATURE_VIGNETTE) {
            float vx = smoothstep(1.8, 0.3, ax);
            float vy = smoothstep(1.4, 0.2, yAbs);
            color *= vx * vy;
        }

        if (features & FEATURE_FLICKER) {
            float flicker = 0.92 + 0.08 * hash(float2(floor(time * 48.0), 7.0));
            color *= flicker;
        }

        if (features & FEATURE_FILM_TONE) {
            color = pow(max(color, 0.0), float3(0.9));
        }

        return float4(color, 1.0);
    }

    // -----------------------------------------------------------------------
    // V4 - diverging streaks + finer tunnel grid (gated by FEATURE_TUNNEL_GRID).
    //
    // Refinements over V3:
    //  1) Streaks fan outward from the vertical vanishing line: instead of a
    //     streak's y being fixed, we treat y*|x| as the streak identity - so
    //     the apparent y on screen diverges from the midline as |x| grows.
    //     This makes the rays radiate from the seam instead of being
    //     perfectly horizontal.
    //  2) Tunnel cells are smaller with thicker grout, and gated by a
    //     dedicated FEATURE_TUNNEL_GRID toggle.
    // -----------------------------------------------------------------------

    // Finer tunnel wall for V4: smaller cells, thicker grout, dimmer.
    //
    // Perspective note: we want cells to be small near the vanishing seam
    // (small ax = far away) and grow toward the screen edges (large ax = near
    // camera). So the depth coordinate that drives cell size is ax itself,
    // scaled logarithmically. The animation scrolls this coordinate so cells
    // appear to emerge from the seam and rush outward past us.
    static inline float3 tunnelWallV4(float ax, float wallCoord, float wallAxis, float side, float time, uint features) {
        // Depth = -log(ax): small ax -> large (far), large ax -> small (near).
        // +time scrolls cells from seam outward past the viewer.
        float depth = -log(ax + 0.02) + time * 1.5;

        // Across-the-wall coord foreshortens.
        float acrossCoord = wallCoord / (ax + 0.05);

        float cellDepth = floor(depth * 1.5);
        float cellAcross = floor(acrossCoord * 2.5);

        float depthFrac = fract(depth * 1.5);
        float acrossFrac = fract(acrossCoord * 2.5);

        // Per-cell randomness. Note: cellDepth changes as cells scroll, so
        // each "generation" of a given across-slot gets a fresh seed.
        float2 cellId = float2(cellDepth, cellAcross + wallAxis * 17.0 + side * 53.0);
        float brightness = hash(cellId);
        if (brightness < 0.55) return float3(0.0);

        // Per-cell phase: shift the birth/death within the cell's depth slot.
        // This breaks the lockstep - cells still scroll with the tunnel, but
        // they appear/disappear at random points along their slot instead of
        // all fading in at 0.0 and out at 1.0.
        float phase = hash(cellId + float2(13.0, 7.0));
        float animF = fract(depthFrac + phase);

        // Variable ON fraction so some cells are brief flashes, others linger.
        float onFrac = mix(0.35, 0.95, hash(cellId + float2(91.0, 29.0)));
        float life = smoothstep(0.0, 0.06, animF)
                   * smoothstep(onFrac, onFrac - 0.06, animF);

        // Thicker grout: cells occupy a smaller fraction of each grid square.
        float inset = 0.28;
        float edge = 0.06;
        float cellMask = smoothstep(inset, inset + edge, acrossFrac)
                       * smoothstep(1.0 - inset, 1.0 - inset - edge, acrossFrac);

        float colorSeed = hash(cellId + float2(5.0, 41.0));
        float3 col = (features & FEATURE_COLOR_PALETTE)
            ? palette(colorSeed + wallAxis * 0.2)
            : float3(brightness);

        // Fade at seam (too small to resolve) and at far edges.
        float fade = smoothstep(0.02, 0.08, ax) * smoothstep(1.8, 0.8, ax);
        return col * cellMask * life * fade * 0.6;
    }

    [[fragment]] float4 stargateFragment_v4(
        FSOut in [[stage_in]],
        constant float &time,
        constant float2 &resolution,
        constant uint &features
    ) {
        float2 p = in.uv * 2.0 - 1.0;
        p.x *= resolution.x / max(resolution.y, 1.0);

        float ax = abs(p.x) + 1e-4;
        float side = sign(p.x);
        float y = p.y;
        float yAbs = abs(y);

        // ----- Diverging streak layer --------------------------------------
        // A streak's identity is determined by its "angle" from the vanishing
        // seam: y normalised by ax. Small ax -> tight cluster near the seam;
        // large ax -> same streaks fanned out vertically. This is the fan shape.
        float angle = y / ax;                     // diverges as we move outward
        float streakId = floor(angle * 18.0 + side * 0.5);
        float angleF = fract(angle * 18.0);       // position within the streak band

        // Depth along the line of travel.
        float depth = 1.0 / ax;
        float scroll = depth + time * 1.2;
        float slice = floor(scroll * 4.0);
        float sliceF = fract(scroll * 4.0);

        // Length class: ~30% long ribbons, rest short pulses.
        float lenHash = hash(float2(streakId, side * 7.0 + 3.0));
        float isLong = step(0.7, lenHash);

        float n = hash(float2(slice, streakId + side * 1000.0));

        float3 streak = (features & FEATURE_COLOR_PALETTE)
            ? palette(n + time * 0.05 + streakId * 0.12)
            : float3(n);

        // Band sharpening across the streak (now in angle space, not raw y).
        float bands = 1.0;
        if (features & FEATURE_RADIAL_BANDS) {
            // Tight cosine in angleF so each streak is a thin ray.
            bands = 0.5 + 0.5 * cos(angleF * 6.2831853);
            bands = pow(bands, 10.0);
        }

        float along = 1.0;
        if (features & FEATURE_SLICE_FADE) {
            float pulse = pow(max(0.0, sin(sliceF * 3.1415926)), 8.0);
            float ribbon = smoothstep(0.0, 0.15, sliceF) * smoothstep(1.0, 0.85, sliceF);
            along = mix(pulse, ribbon, isLong);
        }

        // Attenuate streaks at steep angles (off-screen) and extremely near the seam.
        float streakGate = smoothstep(0.0, 0.06, ax) * smoothstep(2.5, 1.2, abs(angle));

        float3 color = float3(0.0);
        if (features & FEATURE_STREAKS) {
            color = streak * bands * along * streakGate;
        }

        // ----- Tunnel grid (toggleable) ------------------------------------
        if (features & FEATURE_TUNNEL_GRID) {
            float floorGate = smoothstep(0.18, 0.3, yAbs);
            color += tunnelWallV4(ax, y * 1.2, 0.0, side, time, features) * floorGate;

            float sideGate = smoothstep(0.9, 0.7, yAbs);
            color += tunnelWallV4(ax, y, 1.0, side, time, features) * sideGate;
        }

        // ----- Hot bloomed vertical seam -----------------------------------
        if (features & FEATURE_CORE) {
            float core = smoothstep(0.14, 0.0, ax);
            float bloom = smoothstep(0.45, 0.0, ax) * 0.35;
            color += float3(1.0, 0.95, 0.85) * (core + bloom);
        }

        if (features & FEATURE_VIGNETTE) {
            float vx = smoothstep(1.8, 0.3, ax);
            float vy = smoothstep(1.4, 0.2, yAbs);
            color *= vx * vy;
        }

        if (features & FEATURE_FLICKER) {
            float flicker = 0.92 + 0.08 * hash(float2(floor(time * 48.0), 7.0));
            color *= flicker;
        }

        if (features & FEATURE_FILM_TONE) {
            color = pow(max(color, 0.0), float3(0.9));
        }

        return float4(color, 1.0);
    }

    // -----------------------------------------------------------------------
    // V5 - organic, desynced streaks.
    //
    // V4's streaks used a hard integer grid in (angle, slice) so every streak
    // lived on the same clock and evenly spaced rays. V5 breaks that:
    //   * Each angular band gets a per-streak angular jitter, so streaks
    //     aren't perfectly fanned.
    //   * Each streak has its own period, phase, and ON fraction (same trick
    //     that made the tunnel grid feel alive).
    //   * Per-streak scroll speed so some streaks race past and others crawl.
    //
    // Tunnel grid code is unchanged from V4.
    // -----------------------------------------------------------------------

    [[fragment]] float4 stargateFragment_v5(
        FSOut in [[stage_in]],
        constant float &time,
        constant float2 &resolution,
        constant uint &features
    ) {
        float2 p = in.uv * 2.0 - 1.0;
        p.x *= resolution.x / max(resolution.y, 1.0);

        float ax = abs(p.x) + 1e-4;
        float side = sign(p.x);
        float y = p.y;
        float yAbs = abs(y);

        // ----- Streak layer (organic / desynced) ---------------------------
        //
        // Each band is ~1 unit of `angle` space. Inside a band we sample the
        // current streak's random angular centre, perturbing where within the
        // band the streak actually sits. We also check the neighbour bands in
        // case those streaks' jitter has pushed them into our slot.
        float angle = y / ax;
        float3 color = float3(0.0);

        if (features & FEATURE_STREAKS) {
            // Scale angle so bands are narrow (many streaks per unit angle).
            float bandScale = 18.0;
            float angleScaled = angle * bandScale;
            // Iterate current band and neighbours so jittered streaks that
            // spill across band borders still render.
            float bandBase = floor(angleScaled);
            for (int db = -4; db <= 4; ++db) {
                float band = bandBase + float(db);
                float2 sid = float2(band, side * 101.0 + 7.0);

                // Per-streak angular jitter (centre of the streak within band).
                float jitter = hash(sid + float2(3.0, 19.0));
                float streakAngle = band + jitter;

                // Distance from this pixel's scaled angle to the streak's centre.
                float d = angleScaled - streakAngle;
                if (abs(d) > 0.5) continue;

                // Streak half-width (in scaled-angle space).
                float width = mix(0.1, 0.7, hash(sid + float2(23.0, 41.0)));
                float across = smoothstep(width, 0.0, abs(d));
                if (across <= 0.0) continue;

                // Per-streak depth / time parameters.
                float speed    = mix(0.4, 1.8, hash(sid + float2(5.0, 53.0)));
                float period   = mix(0.8, 3.5, hash(sid + float2(11.0, 67.0)));
                float phase    = hash(sid + float2(31.0, 71.0));
                float isLong   = step(0.4, hash(sid + float2(59.0, 97.0))); // most are long ribbons
                // Long ribbons stay lit most of their cycle; short pulses flash.
                float onFrac   = isLong > 0.5
                    ? mix(0.75, 0.98, hash(sid + float2(43.0, 83.0)))
                    : mix(0.25, 0.6,  hash(sid + float2(43.0, 83.0)));

                // Streak depth coordinate - same perspective as tunnel grid.
                float depth = 1.0 / ax;
                float scroll = depth * speed + time * speed * 1.2;

                // Each streak's own lifetime clock, independent from neighbours.
                float cyc = fract(time / period + phase + scroll * 0.15);

                float life;
                if (isLong > 0.5) {
                    // Long ribbons: wide envelope inside the cycle.
                    life = smoothstep(0.0, 0.1, cyc)
                         * smoothstep(onFrac, onFrac - 0.1, cyc);
                } else {
                    // Short pulse: narrow spike.
                    float pulseC = onFrac * 0.5;
                    life = pow(max(0.0, 1.0 - abs(cyc - pulseC) / (onFrac * 0.5 + 1e-4)), 2.5);
                }
                if (life <= 0.0) continue;

                // Per-streak colour seed (stable across its lifetime).
                float colorSeed = hash(sid + float2(67.0, 113.0));
                float3 sc = (features & FEATURE_COLOR_PALETTE)
                    ? palette(colorSeed + band * 0.01)
                    : float3(0.8 + 0.2 * colorSeed);

                // Attenuate streaks close to seam (they'd look frozen). Keep the
                // full fan visible out to screen edges (top/bottom of frame).
                float gate = smoothstep(0.0, 0.05, ax);

                color += sc * across * life * gate;
            }
        }

        // ----- Tunnel grid (unchanged from V4) -----------------------------
        if (features & FEATURE_TUNNEL_GRID) {
            float floorGate = smoothstep(0.18, 0.3, yAbs);
            color += tunnelWallV4(ax, y * 1.2, 0.0, side, time, features) * floorGate;

            float sideGate = smoothstep(0.9, 0.7, yAbs);
            color += tunnelWallV4(ax, y, 1.0, side, time, features) * sideGate;
        }

        // ----- Hot bloomed vertical seam -----------------------------------
        if (features & FEATURE_CORE) {
            float core = smoothstep(0.14, 0.0, ax);
            float bloom = smoothstep(0.45, 0.0, ax) * 0.35;
            color += float3(1.0, 0.95, 0.85) * (core + bloom);
        }

        if (features & FEATURE_VIGNETTE) {
            float vx = smoothstep(1.8, 0.3, ax);
            float vy = smoothstep(1.4, 0.2, yAbs);
            color *= vx * vy;
        }

        if (features & FEATURE_FLICKER) {
            float flicker = 0.92 + 0.08 * hash(float2(floor(time * 48.0), 7.0));
            color *= flicker;
        }

        if (features & FEATURE_FILM_TONE) {
            color = pow(max(color, 0.0), float3(0.9));
        }

        return float4(color, 1.0);
    }

} // namespace Stargate
