#include "SpiralParticlesShader.h"

using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

struct PrimitiveOut {
    float spiralProgress;
    float distanceFromCenter;
};

// Define mesh type: 192 vertices, 192 indices (64 triangles max), triangles
using MeshType = mesh<VertexOut, PrimitiveOut, 192, 192, topology::triangle>;

// Object shader: one thread per particle
[[object, max_total_threads_per_threadgroup(1)]]
void spiralParticleObjectShader(
    uint objectID [[thread_position_in_grid]],
    object_data SpiralParticleObjectPayload& payload [[payload]],
    mesh_grid_properties mgp
) {
    payload.particleIndex = objectID;
    // Launch one mesh threadgroup per particle
    mgp.set_threadgroups_per_grid(uint3(1, 1, 1));
}

// Mesh shader: multiple threads generate spiral triangles in parallel
[[mesh, max_total_threads_per_threadgroup(32)]]
void spiralParticleMeshShader(
    MeshType mesh_out,
    const device SpiralParticleData* particleData [[buffer(0)]],
    const device SpiralParticleUniforms& uniforms [[buffer(1)]],
    object_data const SpiralParticleObjectPayload& payload [[payload]],
    uint threadID [[thread_position_in_threadgroup]],
    uint threadsPerThreadgroup [[threads_per_threadgroup]]
) {
    uint particleIndex = payload.particleIndex;
    SpiralParticleData particle = particleData[particleIndex];

    // Skip rendering if particle has zero size (dummy particle)
    if (particle.size <= 0.0) {
        if (threadID == 0) {
            mesh_out.set_primitive_count(0);
        }
        return;
    }

    // Spiral parameters
    const uint trianglesPerSpiral = uniforms.trianglesPerSpiral;
    const float spiralTurns = 3.0;
    const float spiralRadius = particle.size;

    // Each thread generates triangles for its assigned segment
    // Distribute triangles across threads
    uint trianglesPerThread = (trianglesPerSpiral + threadsPerThreadgroup - 1) / threadsPerThreadgroup;
    uint startTriangle = threadID * trianglesPerThread;
    uint endTriangle = min(startTriangle + trianglesPerThread, trianglesPerSpiral);

    // Rotation matrix for the particle
    float angle = particle.rotation + uniforms.time;
    float cosAngle = cos(angle);
    float sinAngle = sin(angle);
    float3x3 rotationMatrix = float3x3(
        float3(cosAngle, 0, sinAngle),
        float3(0, 1, 0),
        float3(-sinAngle, 0, cosAngle)
    );

    // Generate triangles for this thread's segment as a ribbon (not a fan)
    for (uint i = startTriangle; i < endTriangle; i++) {
        // We need 2 triangles per segment to make a ribbon
        // So we're working with segments, each segment = 2 triangles
        uint segmentIndex = i / 2;
        bool isFirstTriangle = (i % 2) == 0;

        float t = float(segmentIndex) / float(trianglesPerSpiral / 2);
        float nextT = float(segmentIndex + 1) / float(trianglesPerSpiral / 2);

        // Spiral equations
        float currentAngle = t * spiralTurns * 2.0 * M_PI_F;
        float nextAngle = nextT * spiralTurns * 2.0 * M_PI_F;

        float currentRadius = spiralRadius * (0.1 + t * 0.9); // Start at 10% radius
        float nextRadius = spiralRadius * (0.1 + nextT * 0.9);

        // Height increases gradually along the spiral (simple upward spiral)
        float currentHeight = t * 0.4; // Goes from 0 to 0.4
        float nextHeight = nextT * 0.4;

        float ribbonWidth = 0.15 * particle.size;

        // Generate 4 positions for the ribbon segment (inner and outer edges)
        float3 currentInner = float3(
            cos(currentAngle) * (currentRadius - ribbonWidth),
            currentHeight,
            sin(currentAngle) * (currentRadius - ribbonWidth)
        );

        float3 currentOuter = float3(
            cos(currentAngle) * (currentRadius + ribbonWidth),
            currentHeight,
            sin(currentAngle) * (currentRadius + ribbonWidth)
        );

        float3 nextInner = float3(
            cos(nextAngle) * (nextRadius - ribbonWidth),
            nextHeight,
            sin(nextAngle) * (nextRadius - ribbonWidth)
        );

        float3 nextOuter = float3(
            cos(nextAngle) * (nextRadius + ribbonWidth),
            nextHeight,
            sin(nextAngle) * (nextRadius + ribbonWidth)
        );

        // Apply rotation
        currentInner = rotationMatrix * currentInner;
        currentOuter = rotationMatrix * currentOuter;
        nextInner = rotationMatrix * nextInner;
        nextOuter = rotationMatrix * nextOuter;

        // World positions - create 2 triangles for this segment
        float3 worldPos0, worldPos1, worldPos2;

        if (isFirstTriangle) {
            // First triangle: currentInner, currentOuter, nextInner
            worldPos0 = particle.position + currentInner;
            worldPos1 = particle.position + currentOuter;
            worldPos2 = particle.position + nextInner;
        } else {
            // Second triangle: currentOuter, nextOuter, nextInner
            worldPos0 = particle.position + currentOuter;
            worldPos1 = particle.position + nextOuter;
            worldPos2 = particle.position + nextInner;
        }

        // Transform to clip space
        float4 clipPos0 = uniforms.viewProjectionMatrix * float4(worldPos0, 1.0);
        float4 clipPos1 = uniforms.viewProjectionMatrix * float4(worldPos1, 1.0);
        float4 clipPos2 = uniforms.viewProjectionMatrix * float4(worldPos2, 1.0);

        // Rainbow colors that vary along the spiral
        float hue = fract(t + particle.color.x);
        float3 baseColor = particle.color;

        // HSV to RGB for rainbow effect
        float3 color0 = baseColor * 0.5;
        float3 color1 = float3(
            abs(sin(hue * M_PI_F * 2.0)),
            abs(sin((hue + 0.333) * M_PI_F * 2.0)),
            abs(sin((hue + 0.666) * M_PI_F * 2.0))
        );
        float3 color2 = float3(
            abs(sin((hue + 0.1) * M_PI_F * 2.0)),
            abs(sin((hue + 0.433) * M_PI_F * 2.0)),
            abs(sin((hue + 0.766) * M_PI_F * 2.0))
        );

        // Write vertices
        uint baseVertexIndex = i * 3;
        mesh_out.set_vertex(baseVertexIndex + 0, VertexOut{clipPos0, float4(color0, 1.0)});
        mesh_out.set_vertex(baseVertexIndex + 1, VertexOut{clipPos1, float4(color1, 1.0)});
        mesh_out.set_vertex(baseVertexIndex + 2, VertexOut{clipPos2, float4(color2, 1.0)});

        // Write indices
        uint baseIndexIndex = i * 3;
        mesh_out.set_index(baseIndexIndex + 0, baseVertexIndex + 0);
        mesh_out.set_index(baseIndexIndex + 1, baseVertexIndex + 1);
        mesh_out.set_index(baseIndexIndex + 2, baseVertexIndex + 2);

        // Set per-primitive data (constant across the whole triangle, not interpolated)
        PrimitiveOut primData;
        primData.spiralProgress = (t + nextT) * 0.5; // Use midpoint
        primData.distanceFromCenter = (currentRadius + nextRadius) * 0.5;
        mesh_out.set_primitive(i, primData);
    }

    // Only first thread sets primitive count
    if (threadID == 0) {
        mesh_out.set_primitive_count(trianglesPerSpiral);
    }
}

struct FragmentInput {
    VertexOut vin;
    PrimitiveOut pin [[center_perspective]];
};

[[fragment]]
float4 spiralParticleFragmentShader(FragmentInput in [[stage_in]]) {
    // Use per-primitive data (constant across the whole triangle, not interpolated)
    // Add a glow effect that gets brighter toward the spiral end
    float glow = in.pin.spiralProgress * 0.5;

    // Pulse effect based on distance from center
    float pulse = sin(in.pin.distanceFromCenter * 10.0) * 0.2 + 0.8;

    float3 finalColor = in.vin.color.rgb * pulse + float3(glow);
    return float4(finalColor, 1.0);
}
