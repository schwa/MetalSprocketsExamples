#include "RayTracingShaders.h"

using namespace metal;
using namespace raytracing;

namespace RayTracingShaders {

inline float hash(uint seed) {
    seed = (seed ^ 61u) ^ (seed >> 16u);
    seed *= 9u;
    seed = seed ^ (seed >> 4u);
    seed *= 0x27d4eb2du;
    seed = seed ^ (seed >> 15u);
    return float(seed) / float(0xFFFFFFFFu);
}

inline float3 randomInHemisphere(float3 normal, thread uint &seed) {
    float u1 = hash(seed);
    seed++;
    float u2 = hash(seed);
    seed++;
    float r = sqrt(u1);
    float theta = 2.0 * M_PI_F * u2;
    float x = r * cos(theta);
    float y = r * sin(theta);
    float z = sqrt(max(0.0, 1.0 - u1));
    float3 up = abs(normal.y) < 0.999 ? float3(0, 1, 0) : float3(1, 0, 0);
    float3 tangent = normalize(cross(up, normal));
    float3 bitangent = cross(normal, tangent);
    return normalize(tangent * x + bitangent * y + normal * z);
}

[[kernel]]
void raytrace_kernel(
    uint2 tid [[thread_position_in_grid]],
    constant RayTracingUniforms &uniforms [[buffer(0)]],
    instance_acceleration_structure accelerationStructure [[buffer(1)]],
    device const TriangleMaterial *materials [[buffer(2)]],
    device const float3 *vertices [[buffer(3)]],
    device const uint *indices [[buffer(4)]],
    device const uint *materialIndices [[buffer(5)]],
    device const float3 *normals [[buffer(6)]],
    texture2d<float, access::read_write> accumTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]]
) {
    if (tid.x >= uint(uniforms.resolution.x) || tid.y >= uint(uniforms.resolution.y)) return;

    uint seed = tid.x + tid.y * uint(uniforms.resolution.x)
              + uniforms.frameIndex * uint(uniforms.resolution.x) * uint(uniforms.resolution.y);

    // Sub-pixel jitter for anti-aliasing
    float jx = hash(seed);
    seed++;
    float jy = hash(seed);
    seed++;
    float2 jitter = float2(jx, jy);
    float2 uv = (float2(tid) + jitter) / uniforms.resolution;
    uv = uv * 2.0 - 1.0;
    uv.y = -uv.y;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;

    float fov = 0.4;
    float3 rayDir = normalize(uniforms.cameraForward
                            + uv.x * fov * uniforms.cameraRight
                            + uv.y * fov * uniforms.cameraUp);

    float3 color = float3(0.0);
    float3 throughput = float3(1.0);
    float3 rayOrigin = uniforms.cameraPosition;

    intersector<instancing, triangle_data> inter;
    inter.assume_geometry_type(geometry_type::triangle);
    inter.force_opacity(forced_opacity::opaque);

    // Light quad area for PDF
    float lightArea = length(cross(uniforms.lightEdge1, uniforms.lightEdge2));

    for (uint bounce = 0; bounce <= uniforms.maxBounces; bounce++) {
        ray r;
        r.origin = rayOrigin;
        r.direction = rayDir;
        r.min_distance = 0.001;
        r.max_distance = 1e38;

        auto intersection = inter.intersect(r, accelerationStructure);
        if (intersection.type == intersection_type::none) break;

        uint instanceIndex = intersection.instance_id;
        uint matIndex = materialIndices[instanceIndex];
        TriangleMaterial mat = materials[matIndex];

        float3 hitPoint = rayOrigin + rayDir * intersection.distance;

        // Compute face normal
        // Use precomputed per-quad normal (both triangles share the same normal)
        float3 normal = normalize(float3(normals[instanceIndex]));
        if (dot(normal, rayDir) > 0.0) normal = -normal;

        // Hit the light directly
        if (any(mat.emission > 0.0)) {
            // Only count direct hits on bounce 0 to avoid double-counting with NEE
            if (bounce == 0) color += throughput * mat.emission;
            break;
        }

        // --- Next Event Estimation: explicit light sampling ---
        {
            // Sample a random point on the light quad
            float s = hash(seed++);
            float t2 = hash(seed++);
            float3 lightPoint = uniforms.lightCorner
                              + s * uniforms.lightEdge1
                              + t2 * uniforms.lightEdge2;

            float3 toLight = lightPoint - hitPoint;
            float dist = length(toLight);
            float3 lightDir = toLight / dist;

            float cosTheta = max(0.0, dot(normal, lightDir));

            if (cosTheta > 0.0) {
                // Shadow ray
                ray shadowRay;
                shadowRay.origin = hitPoint + normal * 0.001;
                shadowRay.direction = lightDir;
                shadowRay.min_distance = 0.001;
                shadowRay.max_distance = dist - 0.002;

                auto shadowHit = inter.intersect(shadowRay, accelerationStructure);

                if (shadowHit.type == intersection_type::none) {
                    // Light normal points down (0,-1,0)
                    float3 lightNormal = float3(0, -1, 0);
                    float cosLight = max(0.0, dot(-lightDir, lightNormal));

                    // Solid angle PDF: p = dist^2 / (lightArea * cosLight)
                    float pdf = (dist * dist) / max(lightArea * cosLight, 1e-6);

                    // Lambertian BRDF = albedo / PI, cosine term = cosTheta
                    // Contribution = throughput * albedo/PI * cosTheta * emission / pdf
                    float3 contrib = throughput * mat.color * (1.0 / M_PI_F)
                                   * cosTheta * uniforms.lightEmission / pdf;
                    color += contrib;
                }
            }
        }

        // --- Indirect bounce ---
        throughput *= mat.color;

        // Russian roulette
        if (bounce >= 3) {
            float p = max(throughput.r, max(throughput.g, throughput.b));
            if (hash(seed++) > p) break;
            throughput /= p;
        }

        rayDir = randomInHemisphere(normal, seed);
        rayOrigin = hitPoint + normal * 0.001;
    }

    // Accumulate running average
    float4 prev = uniforms.frameIndex == 0 ? float4(0) : accumTexture.read(tid);
    // prev.xyz = running sum, prev.w = sample count
    float4 newAccum = float4(prev.xyz + color, prev.w + 1.0);
    accumTexture.write(newAccum, tid);

    // Reinhard tone map + gamma
    float3 averaged = newAccum.xyz / newAccum.w;
    averaged = averaged / (averaged + 1.0);
    averaged = pow(saturate(averaged), 1.0 / 2.2);
    outputTexture.write(float4(averaged, 1.0), tid);
}

} // namespace RayTracingShaders

