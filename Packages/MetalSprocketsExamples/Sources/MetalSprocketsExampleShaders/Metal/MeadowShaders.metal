#include <metal_stdlib>
#include <metal_raytracing>
#include "MeadowShaders.h"

using namespace metal;
using namespace raytracing;

namespace MeadowShaders {

typedef MeadowUniforms Uniforms;

float random(thread uint &state) {
    state = state * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return float((word >> 22u) ^ word) / 4294967296.0;
}

float hash(float3 position) {
    position = fract(position * 0.1031);
    position += dot(position, position.yzx + 33.33);
    return fract((position.x + position.y) * position.z);
}

float noise(float3 position) {
    float3 cell = floor(position);
    float3 fraction = fract(position);
    fraction = fraction * fraction * (3.0 - 2.0 * fraction);
    return mix(mix(mix(hash(cell), hash(cell + float3(1,0,0)), fraction.x),
                   mix(hash(cell + float3(0,1,0)), hash(cell + float3(1,1,0)), fraction.x), fraction.y),
               mix(mix(hash(cell + float3(0,0,1)), hash(cell + float3(1,0,1)), fraction.x),
                   mix(hash(cell + float3(0,1,1)), hash(cell + float3(1,1,1)), fraction.x), fraction.y), fraction.z);
}

float fractal(float3 position) {
    float value = 0;
    float weight = 0.55;
    for (uint octave = 0; octave < 4; ++octave) {
        value += noise(position) * weight;
        position = position * 2.03 + float3(7.1, 13.7, 2.9);
        weight *= 0.48;
    }
    return value;
}

float cloudDensity(float3 position, constant Uniforms &uniforms) {
    float height = (position.y - 100.0) / 100.0;
    float profile = smoothstep(0.0, 0.18, height) * (1.0 - smoothstep(0.55, 1.0, height));
    float3 coordinate = position * float3(0.009, 0.016, 0.009);
    coordinate.x += uniforms.atmosphere.z * 0.008;
    float shape = fractal(coordinate);
    float weather = noise(float3(coordinate.x * 0.85 + 4.1, 0.7, coordinate.z * 0.85 + 7.3));
    float coverage = smoothstep(0.65 - uniforms.atmosphere.y * 0.5, 0.85 - uniforms.atmosphere.y * 0.5, weather);
    return max(0.0, shape - 0.42) * coverage * profile * 0.16 * uniforms.atmosphere.y;
}

float3 sky(float3 direction, constant Uniforms &uniforms) {
    float elevation = saturate(direction.y);
    float sunCosine = dot(direction, uniforms.sun.xyz);
    float horizon = pow(1.0 - elevation, 4.0);
    float3 color = mix(float3(0.16, 0.36, 0.69), float3(0.72, 0.77, 0.78), horizon);
    float glow = pow(saturate(sunCosine), 24.0);
    color += uniforms.sun.w * float3(1.0, 0.65, 0.29) * glow * 0.45;
    color += smoothstep(cos(0.005), cos(0.004), sunCosine) * float3(20, 16, 10);
    return color;
}

float visibility(float3 position, float3 direction, primitive_acceleration_structure scene);

float3 atmosphere(float3 origin, float3 direction, float distance, float3 background, constant Uniforms &uniforms, primitive_acceleration_structure scene, thread uint &state) {
    float sunCosine = dot(direction, uniforms.sun.xyz);
    float phase = 0.025 + 0.04 / pow(max(0.08, 1.0 + 0.72 * 0.72 - 1.44 * sunCosine), 1.5);
    float fogDistance = min(distance, 650.0);
    float fogTransmission = 1;
    float3 fogScattering = 0;
    float fogStep = fogDistance / 12.0;
    float fogJitter = random(state);
    for (uint index = 0; index < 12; ++index) {
        float3 position = origin + direction * ((float(index) + fogJitter) * fogStep);
        float density = uniforms.atmosphere.x * exp(-max(0.0, position.y) * 0.045);
        float absorption = 1.0 - exp(-density * fogStep);
        float sunlight = visibility(position, uniforms.sun.xyz, scene);
        float3 airLight = float3(0.28, 0.40, 0.58) + float3(1.0, 0.69, 0.33) * phase * uniforms.sun.w * sunlight;
        fogScattering += fogTransmission * absorption * airLight;
        fogTransmission *= 1.0 - absorption;
    }
    float3 color = background * fogTransmission + fogScattering;
    if (direction.y <= 0.015) return color;
    float start = max(0.0, (100.0 - origin.y) / direction.y);
    float finish = min(distance, (200.0 - origin.y) / direction.y);
    if (finish <= start) return color;
    float stepSize = min((finish - start) / 40.0, 24.0);
    float transmission = 1.0;
    float3 scattering = 0;
    float offset = random(state);
    for (uint index = 0; index < 40; ++index) {
        float travel = start + (float(index) + offset) * stepSize;
        if (travel > finish || transmission < 0.015) break;
        float3 position = origin + direction * travel;
        float density = cloudDensity(position, uniforms);
        if (density > 0.0001) {
            float opticalDepth = 0;
            for (uint sample = 1; sample <= 5; ++sample) {
                opticalDepth += cloudDensity(position + uniforms.sun.xyz * float(sample) * 15.0, uniforms) * 15.0;
            }
            float absorption = 1.0 - exp(-density * stepSize);
            float3 light = float3(0.32, 0.41, 0.56) + float3(1.0, 0.83, 0.57) * exp(-opticalDepth) * (1.0 + phase * 3.0);
            scattering += transmission * absorption * light;
            transmission *= 1.0 - absorption;
        }
    }
    return color * transmission + scattering;
}

float3 hemisphere(float3 normal, thread uint &state) {
    float azimuth = random(state) * 6.2831853;
    float radius = sqrt(random(state));
    float3 tangent = normalize(cross(normal, abs(normal.y) < 0.99 ? float3(0,1,0) : float3(1,0,0)));
    return normalize(tangent * (cos(azimuth) * radius) + cross(normal, tangent) * (sin(azimuth) * radius) + normal * sqrt(1.0 - radius * radius));
}

float visibility(float3 position, float3 direction, primitive_acceleration_structure scene) {
    intersector<triangle_data> query;
    query.assume_geometry_type(geometry_type::triangle);
    query.accept_any_intersection(true);
    ray shadow(position, direction, 0.008, 500.0);
    return query.intersect(shadow, scene).type == intersection_type::none ? 1.0 : 0.0;
}

float3 surfaceLight(float3 position, float3 normal, float4 material, constant Uniforms &uniforms, primitive_acceleration_structure scene, thread uint &state) {
    float3 sunDirection = normalize(uniforms.sun.xyz + hemisphere(uniforms.sun.xyz, state) * 0.009);
    float sunlight = visibility(position + sunDirection * 0.015, sunDirection, scene);
    float cosine = dot(normal, sunDirection);
    float diffuse = max(0.0, cosine) + material.w * 0.35 * max(0.0, -cosine);
    float cloudShadow = exp(-cloudDensity(position + sunDirection * ((135.0 - position.y) / sunDirection.y), uniforms) * 120.0);
    return material.xyz * float3(1.0, 0.83, 0.57) * uniforms.sun.w * diffuse * sunlight * cloudShadow;
}

[[kernel]] void traceMeadow(texture2d<float, access::write> output [[texture(0)]],
                        texture2d<float, access::read_write> history [[texture(1)]],
                        constant Uniforms &uniforms [[buffer(0)]],
                        device const float3 *vertices [[buffer(1)]],
                        device const float4 *materials [[buffer(2)]],
                        primitive_acceleration_structure scene [[buffer(3)]],
                        uint2 pixel [[thread_position_in_grid]]) {
    if (pixel.x >= output.get_width() || pixel.y >= output.get_height()) return;
    uint state = (pixel.x + pixel.y * output.get_width()) * 1973u + uniforms.frame.x * 9277u + 89173u;
    float2 jitter = float2(random(state), random(state));
    float2 coordinate = (float2(pixel) + jitter) / float2(output.get_width(), output.get_height()) * 2.0 - 1.0;
    coordinate.x *= float(output.get_width()) / float(output.get_height());
    float3 direction = normalize(uniforms.forward.xyz + 0.62 * (coordinate.x * uniforms.right.xyz - coordinate.y * uniforms.up.xyz));
    ray primary(uniforms.origin.xyz, direction, 0.01, 2000.0);
    intersector<triangle_data> query;
    query.assume_geometry_type(geometry_type::triangle);
    auto hit = query.intersect(primary, scene);
    float3 radiance;
    float distance = 2000.0;
    if (hit.type == intersection_type::none) {
        radiance = sky(direction, uniforms);
    } else {
        distance = hit.distance;
        uint base = hit.primitive_id * 3;
        float3 normal = normalize(cross(vertices[base + 1] - vertices[base], vertices[base + 2] - vertices[base]));
        normal = faceforward(normal, direction, normal);
        float3 position = primary.origin + direction * hit.distance;
        float4 material = materials[hit.primitive_id];
        if (material.w == 0 && normal.y > 0.7) {
            material.xyz *= 0.65 + 0.6 * noise(position * 1.5);
        }
        radiance = surfaceLight(position, normal, material, uniforms, scene, state);
        float3 bounceDirection = hemisphere(normal, state);
        ray bounce(position + normal * 0.008, bounceDirection, 0.008, 400.0);
        auto secondHit = query.intersect(bounce, scene);
        float3 indirect;
        if (secondHit.type == intersection_type::none) {
            indirect = sky(bounceDirection, uniforms) * 0.65;
        } else {
            uint secondBase = secondHit.primitive_id * 3;
            float3 secondNormal = normalize(cross(vertices[secondBase + 1] - vertices[secondBase], vertices[secondBase + 2] - vertices[secondBase]));
            secondNormal = faceforward(secondNormal, bounceDirection, secondNormal);
            float3 secondPosition = bounce.origin + bounceDirection * secondHit.distance;
            float4 secondMaterial = materials[secondHit.primitive_id];
            indirect = surfaceLight(secondPosition, secondNormal, secondMaterial, uniforms, scene, state)
                + secondMaterial.xyz * float3(0.07, 0.10, 0.13);
        }
        radiance += material.xyz * indirect;
    }
    radiance = atmosphere(primary.origin, direction, distance, radiance, uniforms, scene, state);
    radiance = min(radiance, float3(24.0));
    float count = float(uniforms.frame.y);
    float3 accumulated = count == 0 ? radiance : mix(history.read(pixel).xyz, radiance, 1.0 / (count + 1.0));
    history.write(float4(accumulated, 1), pixel);
    float3 exposed = accumulated * uniforms.atmosphere.w;
    float3 mapped = saturate((exposed * (2.51 * exposed + 0.03)) / (exposed * (2.43 * exposed + 0.59) + 0.14));
    float3 encoded = select(1.055 * pow(mapped, float3(1.0 / 2.4)) - 0.055, mapped * 12.92, mapped <= 0.0031308);
    output.write(float4(encoded, 1), pixel);
}

} // namespace MeadowShaders
