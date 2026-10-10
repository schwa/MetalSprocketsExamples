#include "MetalSprocketsExampleShaders.h"

using namespace metal;

// 3D PIC/FLIP fluid, after "Fluid Implicit Particle Simulation for CPU and GPU"
// (Centeno & Pereira, 2024). Ported from the MetalFLIP app.

namespace MetalFLIP {

typedef MetalFLIPParameters Parameters;
typedef MetalFLIPCamera Camera;

constant uint particlesPerCell = 12;

struct Statistics {
    atomic_uint maximumSpeed, particleCount;
    float timeStep, simulatedTime;
};

uint index3(int3 coordinate, uint width) {
    return uint(coordinate.x) + width * (uint(coordinate.y) + width * uint(coordinate.z));
}
int3 coordinate3(uint index, uint width) {
    return int3(index % width, (index / width) % width, index / (width * width));
}
bool inside(int3 coordinate, uint width) {
    return all(coordinate >= 0) && all(coordinate < int(width));
}
float randomValue(uint seed) {
    seed ^= seed >> 16;
    seed *= 0x7feb352du;
    seed ^= seed >> 15;
    seed *= 0x846ca68bu;
    seed ^= seed >> 16;
    return float(seed & 0x00ffffffu) / 16777216.0f;
}
float3 randomVector(uint seed) {
    return float3(randomValue(seed), randomValue(seed + 971u), randomValue(seed + 2791u));
}
float3 faceOffset(uint axis) {
    float3 offset(0.5f);
    offset[axis] = 0;
    return offset;
}
bool solidFace(int3 coordinate, uint axis, uint width) {
    return coordinate[axis] == 0 || coordinate[axis] == int(width);
}
bool fluidCell(int3 coordinate, device const float4 *positions, uint width) {
    return inside(coordinate, width) && positions[index3(coordinate, width) * particlesPerCell].w > 0;
}
float3 sampleVelocity(device const float4 *grid, float3 position, constant Parameters &parameters) {
    float3 result(0);
    uint width = parameters.resolution + 1;
    for (uint axis = 0; axis < 3; ++axis) {
        float3 location = position / parameters.spacing - faceOffset(axis);
        int3 base = int3(floor(location));
        float3 fraction = fract(location);
        for (int z = 0; z < 2; ++z) for (int y = 0; y < 2; ++y) for (int x = 0; x < 2; ++x) {
            int3 corner(x, y, z);
            float3 weights = select(1 - fraction, fraction, bool3(corner));
            int3 coordinate = clamp(base + corner, int3(0), int3(width - 1));
            result[axis] += grid[index3(coordinate, width)][axis] * weights.x * weights.y * weights.z;
        }
    }
    return result;
}

// MARK: - Simulation

kernel void seedParticles(device float4 *positions, device float4 *velocities, constant Parameters &parameters, uint index [[thread_position_in_grid]]) {
    if (index >= parameters.capacity) return;
    uint slot = index % particlesPerCell;
    int3 cell = coordinate3(index / particlesPerCell, parameters.resolution);
    float3 center = (float3(cell) + 0.5f) * parameters.spacing;
    bool filled;
    if (parameters.scene == 1) {
        filled = center.y < 0.16f || distance(center, float3(0.5f, 0.68f, 0.5f)) < 0.19f;
    } else if (parameters.scene == 2) {
        filled = center.y < 0.52f && ((center.x < 0.25f && center.z < 0.7f) || (center.x > 0.75f && center.z > 0.3f));
    } else {
        filled = center.x < 0.38f && center.y < 0.78f && center.z > 0.12f && center.z < 0.88f;
    }
    float3 subcell = float3(slot & 1u, (slot >> 1u) & 1u, (slot >> 2u) & 1u);
    float3 position = (float3(cell) + (subcell + 0.25f + 0.5f * randomVector(index + 1)) * 0.5f) * parameters.spacing;
    positions[index] = float4(position, filled && slot < 8 ? 1.0f : 0.0f);
    float speed = parameters.scene == 2 ? (center.x < 0.5f ? 1.5f : -1.5f) : 0;
    velocities[index] = float4(speed, 0, 0, 0);
}

kernel void clearStatistics(device Statistics &statistics, uint index [[thread_position_in_grid]]) {
    if (index != 0) return;
    atomic_store_explicit(&statistics.maximumSpeed, 0, memory_order_relaxed);
    atomic_store_explicit(&statistics.particleCount, 0, memory_order_relaxed);
}
kernel void measureParticles(device const float4 *positions, device const float4 *velocities, device Statistics &statistics, constant Parameters &parameters, uint index [[thread_position_in_grid]]) {
    if (index >= parameters.capacity || positions[index].w == 0) return;
    atomic_fetch_max_explicit(&statistics.maximumSpeed, as_type<uint>(length(velocities[index].xyz)), memory_order_relaxed);
    atomic_fetch_add_explicit(&statistics.particleCount, 1, memory_order_relaxed);
}
kernel void chooseTimeStep(device Statistics &statistics, constant Parameters &parameters, uint index [[thread_position_in_grid]]) {
    if (index != 0) return;
    float speed = as_type<float>(atomic_load_explicit(&statistics.maximumSpeed, memory_order_relaxed));
    // Include acceleration in the displacement bound, using a conservative half-cell CFL number.
    float bound = speed + sqrt(parameters.gravity * parameters.spacing);
    statistics.timeStep = min(parameters.maximumTimeStep, 0.5f * parameters.spacing / max(bound, 0.001f));
    statistics.simulatedTime += statistics.timeStep;
}

kernel void particleToGrid(device const float4 *positions, device const float4 *velocities, device float4 *grid, constant Parameters &parameters, uint index [[thread_position_in_grid]]) {
    uint width = parameters.resolution + 1;
    if (index >= width * width * width) return;
    int3 coordinate = coordinate3(index, width);
    float3 velocity(0);
    uint valid = 0;
    for (uint axis = 0; axis < 3; ++axis) {
        if (solidFace(coordinate, axis, parameters.resolution)) {
            valid |= 1u << axis;
            continue;
        }
        float3 face = float3(coordinate) + faceOffset(axis);
        float weightedVelocity = 0, totalWeight = 0;
        for (int z = -1; z <= 1; ++z) for (int y = -1; y <= 1; ++y) for (int x = -1; x <= 1; ++x) {
            int3 cell = coordinate + int3(x, y, z);
            if (!inside(cell, parameters.resolution)) continue;
            uint start = index3(cell, parameters.resolution) * particlesPerCell;
            for (uint slot = 0; slot < particlesPerCell; ++slot) {
                float4 particle = positions[start + slot];
                if (particle.w == 0) break;
                float3 weights = max(1 - abs(particle.xyz / parameters.spacing - face), 0.0f);
                float weight = weights.x * weights.y * weights.z;
                weightedVelocity += weight * velocities[start + slot][axis];
                totalWeight += weight;
            }
        }
        if (totalWeight > 1e-6f) {
            velocity[axis] = weightedVelocity / totalWeight;
            valid |= 1u << axis;
        }
    }
    grid[index] = float4(velocity, float(valid));
}

kernel void extrapolateVelocity(device const float4 *input, device float4 *output, constant Parameters &parameters, uint index [[thread_position_in_grid]]) {
    uint width = parameters.resolution + 1;
    if (index >= width * width * width) return;
    int3 coordinate = coordinate3(index, width);
    float4 value = input[index];
    uint valid = uint(value.w);
    for (uint axis = 0; axis < 3; ++axis) {
        if (valid & (1u << axis)) continue;
        float sum = 0;
        uint count = 0;
        for (uint direction = 0; direction < 3; ++direction) for (int sign = -1; sign <= 1; sign += 2) {
            int3 neighbor = coordinate;
            neighbor[direction] += sign;
            if (!inside(neighbor, width)) continue;
            float4 sample = input[index3(neighbor, width)];
            if (uint(sample.w) & (1u << axis)) {
                sum += sample[axis];
                ++count;
            }
        }
        if (count > 0) {
            value[axis] = sum / float(count);
            valid |= 1u << axis;
        }
    }
    output[index] = float4(value.xyz, float(valid));
}

kernel void applyGravity(device float4 *grid, device const Statistics &statistics, constant Parameters &parameters, uint index [[thread_position_in_grid]]) {
    uint width = parameters.resolution + 1;
    if (index >= width * width * width) return;
    int3 coordinate = coordinate3(index, width);
    if (!solidFace(coordinate, 1, parameters.resolution) && (uint(grid[index].w) & 2u)) {
        grid[index].y -= parameters.gravity * statistics.timeStep;
    }
}

kernel void computeDivergence(device const float4 *positions, device const float4 *grid, device float *divergence, device float *pressure, constant Parameters &parameters, uint index [[thread_position_in_grid]]) {
    uint width = parameters.resolution;
    if (index >= width * width * width) return;
    int3 cell = coordinate3(index, width);
    float sum = 0;
    if (fluidCell(cell, positions, width)) {
        for (uint axis = 0; axis < 3; ++axis) {
            int3 upper = cell;
            upper[axis] += 1;
            sum += grid[index3(upper, width + 1)][axis] - grid[index3(cell, width + 1)][axis];
        }
    }
    divergence[index] = sum;
    pressure[index] = 0;
}

kernel void solvePressure(device const float4 *positions, device const float *divergence, device float *pressure, constant uint &parity, constant Parameters &parameters, uint index [[thread_position_in_grid]]) {
    uint width = parameters.resolution;
    if (index >= width * width * width) return;
    int3 cell = coordinate3(index, width);
    if (uint(cell.x + cell.y + cell.z) % 2 != parity || !fluidCell(cell, positions, width)) return;
    float sum = 0;
    uint diagonal = 0;
    for (uint axis = 0; axis < 3; ++axis) for (int sign = -1; sign <= 1; sign += 2) {
        int3 neighbor = cell;
        neighbor[axis] += sign;
        if (!inside(neighbor, width)) continue;
        ++diagonal;
        if (fluidCell(neighbor, positions, width)) sum += pressure[index3(neighbor, width)];
    }
    // Pressure is scaled by dt / (density * spacing), so projection subtracts it directly.
    pressure[index] = diagonal > 0 ? (sum - divergence[index]) / float(diagonal) : 0;
}

kernel void projectVelocity(device const float4 *positions, device const float *pressure, device float4 *grid, constant Parameters &parameters, uint index [[thread_position_in_grid]]) {
    uint width = parameters.resolution;
    if (index >= (width + 1) * (width + 1) * (width + 1)) return;
    int3 upper = coordinate3(index, width + 1);
    float3 velocity = grid[index].xyz;
    uint valid = 0;
    for (uint axis = 0; axis < 3; ++axis) {
        int3 lower = upper;
        --lower[axis];
        if (solidFace(upper, axis, width)) {
            velocity[axis] = 0;
            valid |= 1u << axis;
        } else if (fluidCell(lower, positions, width) || fluidCell(upper, positions, width)) {
            float lowerPressure = inside(lower, width) ? pressure[index3(lower, width)] : 0;
            float upperPressure = inside(upper, width) ? pressure[index3(upper, width)] : 0;
            velocity[axis] -= upperPressure - lowerPressure;
            valid |= 1u << axis;
        } else {
            velocity[axis] = 0;
        }
    }
    grid[index] = float4(velocity, float(valid));
}

kernel void gridToParticle(device float4 *positions, device float4 *velocities, device const float4 *grid, device const float4 *oldGrid, device const Statistics &statistics, constant Parameters &parameters, uint index [[thread_position_in_grid]]) {
    if (index >= parameters.capacity || positions[index].w == 0) return;
    float3 position = positions[index].xyz;
    float3 pic = sampleVelocity(grid, position, parameters);
    float3 flip = velocities[index].xyz + pic - sampleVelocity(oldGrid, position, parameters);
    float3 velocity = mix(pic, flip, parameters.flipRatio);
    // Midpoint advection follows the projected field, not the noisy FLIP particle velocity.
    float3 midpoint = position + 0.5f * statistics.timeStep * pic;
    position += statistics.timeStep * sampleVelocity(grid, midpoint, parameters);
    float skin = parameters.spacing * 0.05f;
    for (uint axis = 0; axis < 3; ++axis) {
        if (position[axis] < skin) velocity[axis] = max(velocity[axis], 0.0f);
        if (position[axis] > 1 - skin) velocity[axis] = min(velocity[axis], 0.0f);
    }
    positions[index] = float4(clamp(position, skin, 1 - skin), 1);
    velocities[index] = float4(velocity, 0);
}

kernel void clearBins(device atomic_int *heads, constant Parameters &parameters, uint index [[thread_position_in_grid]]) {
    uint width = parameters.resolution;
    if (index < width * width * width) atomic_store_explicit(&heads[index], -1, memory_order_relaxed);
}
kernel void binParticles(device const float4 *positions, device atomic_int *heads, device int *next, constant Parameters &parameters, uint index [[thread_position_in_grid]]) {
    if (index >= parameters.capacity || positions[index].w == 0) return;
    int3 cell = clamp(int3(positions[index].xyz / parameters.spacing), int3(0), int3(parameters.resolution - 1));
    next[index] = atomic_exchange_explicit(&heads[index3(cell, parameters.resolution)], int(index), memory_order_relaxed);
}

kernel void reseedParticles(device const float4 *positions, device const float4 *velocities, device const int *heads, device const int *next, device float4 *outputPositions, device float4 *outputVelocities, constant Parameters &parameters, uint index [[thread_position_in_grid]]) {
    uint width = parameters.resolution;
    if (index >= width * width * width) return;
    uint start = index * particlesPerCell, count = 0;
    int particle = heads[index];
    while (particle >= 0 && count < particlesPerCell) {
        outputPositions[start + count] = positions[particle];
        outputVelocities[start + count] = velocities[particle];
        particle = next[particle];
        ++count;
    }
    uint target = count == 0 ? 0 : max(count, 3u);
    float3 centroid(0), meanVelocity(0);
    if (count > 0 && count < 3) {
        for (uint slot = 0; slot < count; ++slot) {
            centroid += outputPositions[start + slot].xyz / float(count);
            meanVelocity += outputVelocities[start + slot].xyz / float(count);
        }
    }
    // Keep new markers inside the existing convex hull to avoid inflating sparse surface cells.
    for (uint slot = count; slot < particlesPerCell; ++slot) {
        outputPositions[start + slot] = float4(centroid, slot < target ? 1.0f : 0.0f);
        outputVelocities[start + slot] = float4(meanVelocity, 0);
    }
}

kernel void reconstructSurface(device const float4 *positions, texture3d<float, access::write> surface, constant Parameters &parameters, uint3 coordinate [[thread_position_in_grid]]) {
    if (any(coordinate >= uint3(surface.get_width()))) return;
    float3 position = float3(coordinate) / float(surface.get_width() - 1);
    int3 center = int3(position / parameters.spacing);
    float radius = 1.5f * parameters.spacing;
    float3 weightedPosition(0);
    float totalWeight = 0;
    for (int z = -2; z <= 2; ++z) for (int y = -2; y <= 2; ++y) for (int x = -2; x <= 2; ++x) {
        int3 cell = center + int3(x, y, z);
        if (!inside(cell, parameters.resolution)) continue;
        uint start = index3(cell, parameters.resolution) * particlesPerCell;
        for (uint slot = 0; slot < particlesPerCell; ++slot) {
            float4 particle = positions[start + slot];
            if (particle.w == 0) break;
            float distanceSquared = distance_squared(position, particle.xyz) / (radius * radius);
            float weight = pow(max(1 - distanceSquared, 0.0f), 3.0f);
            weightedPosition += weight * particle.xyz;
            totalWeight += weight;
        }
    }
    float field = totalWeight > 1e-6f ? distance(position, weightedPosition / totalWeight) - 0.55f * parameters.spacing : parameters.spacing;
    // Close the reconstructed surface against the six tank walls.
    float wall = max(max(max(-position.x, position.x - 1), max(-position.y, position.y - 1)), max(-position.z, position.z - 1));
    surface.write(float4(max(field, wall)), coordinate);
}

// MARK: - Rendering

struct ScreenVertex {
    float4 position [[position]];
    float2 coordinate;
};
struct FragmentOutput {
    float4 color [[color(0)]];
    float depth [[depth(any)]];
};

vertex ScreenVertex screenVertex(uint index [[vertex_id]]) {
    float2 coordinate = float2((index << 1u) & 2u, index & 2u);
    return { float4(coordinate * 2 - 1, 0, 1), coordinate };
}
float depthForPosition(float3 position, constant Camera &camera) {
    float distance = max(dot(position - camera.origin.xyz, camera.forward.xyz), 0.01f);
    return clamp(20.0f / 19.99f - (0.2f / 19.99f) / distance, 0.0f, 1.0f);
}
float3 environmentColor(float3 direction) {
    float sky = smoothstep(-0.3f, 0.8f, direction.y);
    float3 color = mix(float3(0.025f, 0.045f, 0.075f), float3(0.35f, 0.48f, 0.63f), sky);
    float key = pow(max(dot(direction, normalize(float3(-0.6f, 1, 0.4f))), 0.0f), 64.0f);
    float strip = pow(max(dot(direction, normalize(float3(0.8f, 0.4f, -0.6f))), 0.0f), 96.0f);
    return color + key * float3(2.2f, 2.1f, 1.9f) + strip * float3(0.8f, 1.2f, 1.7f);
}
float3 floorColor(float3 origin, float3 direction) {
    float3 color = float3(0.018f, 0.027f, 0.047f) + max(direction.y, 0.0f) * 0.018f;
    if (direction.y >= -0.0001f) return color;
    float distance = (-0.035f - origin.y) / direction.y;
    if (distance <= 0) return color;
    float3 hit = origin + distance * direction;
    float2 cell = abs(fract(hit.xz * 12) - 0.5f);
    float line = smoothstep(0.46f, 0.49f, max(cell.x, cell.y));
    float fade = exp(-0.16f * distance * distance);
    float insideTank = all(hit.xz >= 0) && all(hit.xz <= 1) ? 1 : 0;
    float3 ground = mix(float3(0.075f, 0.10f, 0.14f), float3(0.11f, 0.15f, 0.2f), line * 0.5f);
    ground += insideTank * float3(0.025f, 0.032f, 0.04f);
    return mix(color, ground, fade);
}
float2 intersectBox(float3 origin, float3 direction) {
    float3 inverse = 1 / direction;
    float3 lower = (0 - origin) * inverse;
    float3 upper = (1 - origin) * inverse;
    float3 minimum = min(lower, upper), maximum = max(lower, upper);
    return float2(max(max(minimum.x, minimum.y), minimum.z), min(min(maximum.x, maximum.y), maximum.z));
}
float sampleSurface(texture3d<float> field, float3 position) {
    constexpr sampler linearSampler(coord::normalized, address::clamp_to_edge, filter::linear);
    float width = float(field.get_width());
    return field.sample(linearSampler, (position * (width - 1) + 0.5f) / width).r;
}
float3 surfaceNormal(texture3d<float> field, float3 position, float epsilon) {
    float3 gradient;
    for (uint axis = 0; axis < 3; ++axis) {
        float3 offset(0);
        offset[axis] = epsilon;
        gradient[axis] = sampleSurface(field, position + offset) - sampleSurface(field, position - offset);
    }
    return length_squared(gradient) > 1e-12f ? normalize(gradient) : float3(0, 1, 0);
}
float tankEdges(float3 origin, float3 direction, float limit, float pixelWidth) {
    float intensity = 0;
    for (uint axis = 0; axis < 3; ++axis) {
        uint first = (axis + 1) % 3, second = (axis + 2) % 3;
        for (uint corner = 0; corner < 4; ++corner) {
            float3 start(0), edge(0);
            start[first] = float(corner & 1u);
            start[second] = float((corner >> 1u) & 1u);
            edge[axis] = 1;
            float3 offset = origin - start;
            float parallel = dot(direction, edge);
            float denominator = max(1 - parallel * parallel, 1e-6f);
            float rayDistance = (parallel * dot(edge, offset) - dot(direction, offset)) / denominator;
            float edgeDistance = clamp(dot(edge, offset) + rayDistance * parallel, 0.0f, 1.0f);
            rayDistance = dot(start + edge * edgeDistance - origin, direction);
            float distance = length(origin + rayDistance * direction - start - edgeDistance * edge);
            if (rayDistance > 0 && rayDistance < limit) {
                intensity = max(intensity, 1 - smoothstep(pixelWidth * rayDistance * 0.5f, pixelWidth * rayDistance * 1.5f, distance));
            }
        }
    }
    return intensity;
}

fragment FragmentOutput surfaceFragment(ScreenVertex input [[stage_in]], constant Camera &camera, texture3d<float> field) {
    float2 coordinate = input.coordinate * 2 - 1;
    float aspect = camera.viewport.x / camera.viewport.y;
    float3 direction = normalize(camera.forward.xyz + camera.viewport.z * (coordinate.x * aspect * camera.right.xyz + coordinate.y * camera.up.xyz));
    float3 origin = camera.origin.xyz;
    float3 color = floorColor(origin, direction);
    float depth = 1, distanceToHit = 100;
    float2 interval = intersectBox(origin, direction);
    float step = camera.fluid.x * 0.3f;
    if (camera.viewport.w < 0.5f && interval.y > max(interval.x, 0.0f)) {
        float distance = max(interval.x, 0.0f) + 0.0001f;
        float previous = distance;
        for (uint iteration = 0; iteration < 384 && distance < interval.y; ++iteration) {
            float3 position = origin + distance * direction;
            if (sampleSurface(field, position) <= 0) {
                float lower = previous, upper = distance;
                for (uint refine = 0; refine < 7; ++refine) {
                    float midpoint = (lower + upper) * 0.5f;
                    if (sampleSurface(field, origin + midpoint * direction) > 0) lower = midpoint;
                    else upper = midpoint;
                }
                distanceToHit = (lower + upper) * 0.5f;
                position = origin + distanceToHit * direction;
                float3 normal = surfaceNormal(field, position, camera.fluid.x * 0.25f);
                if (dot(normal, direction) > 0) normal = -normal;
                float thickness = 0;
                for (float sampleDistance = distance + step; sampleDistance < interval.y; sampleDistance += step * 2) {
                    if (sampleSurface(field, origin + sampleDistance * direction) < 0) thickness += step * 2;
                }
                float fresnel = 0.02f + 0.98f * pow(1 - max(dot(-direction, normal), 0.0f), 5.0f);
                float3 transmission = exp(-float3(4.5f, 1.3f, 0.65f) * max(thickness, 0.04f));
                float3 refraction = refract(direction, normal, 1 / 1.333f);
                float3 transmitted = floorColor(position, refraction) * transmission + float3(0.018f, 0.25f, 0.36f) * (1 - transmission);
                float3 reflection = environmentColor(reflect(direction, normal));
                float diffuse = max(dot(normal, normalize(float3(-0.6f, 1, 0.4f))), 0.0f);
                color = mix(transmitted, reflection, fresnel) + diffuse * float3(0.015f, 0.055f, 0.07f);
                depth = depthForPosition(position, camera);
                break;
            }
            previous = distance;
            distance += step;
        }
    }
    float edge = tankEdges(origin, direction, distanceToHit + 0.001f, 1.0f / camera.viewport.y);
    color = mix(color, float3(0.25f, 0.38f, 0.5f), edge * 0.7f);
    return { float4(color, 1), depth };
}

struct ParticleVertex {
    float4 position [[position]];
    float2 local;
    float3 center;
    float speed;
};
vertex ParticleVertex particleVertex(uint vertexIndex [[vertex_id]], uint instance [[instance_id]], device const float4 *positions, device const float4 *velocities, constant Camera &camera) {
    constexpr float2 corners[] = {float2(-1, -1), float2(1, -1), float2(-1, 1), float2(-1, 1), float2(1, -1), float2(1, 1)};
    float2 local = corners[vertexIndex];
    float3 center = positions[instance].xyz;
    float radius = camera.fluid.x * 0.15f;
    float3 position = center + radius * (local.x * camera.right.xyz + local.y * camera.up.xyz);
    float3 offset = position - camera.origin.xyz;
    float distance = dot(offset, camera.forward.xyz);
    float aspect = camera.viewport.x / camera.viewport.y;
    float4 clip(dot(offset, camera.right.xyz) / (camera.viewport.z * aspect), dot(offset, camera.up.xyz) / camera.viewport.z, distance * 20 / 19.99f - 0.2f / 19.99f, distance);
    if (positions[instance].w == 0) clip = float4(2, 2, 2, 1);
    return {clip, local, center, length(velocities[instance].xyz)};
}
fragment FragmentOutput particleFragment(ParticleVertex input [[stage_in]], constant Camera &camera) {
    float squaredRadius = dot(input.local, input.local);
    if (squaredRadius > 1) discard_fragment();
    float3 normal = input.local.x * camera.right.xyz + input.local.y * camera.up.xyz - sqrt(1 - squaredRadius) * camera.forward.xyz;
    float3 position = input.center + normal * camera.fluid.x * 0.15f;
    float lighting = 0.25f + 0.75f * max(dot(normal, normalize(float3(-0.5f, 1, 0.7f))), 0.0f);
    float3 color = mix(float3(0.04f, 0.4f, 0.7f), float3(0.4f, 0.95f, 1), clamp(input.speed / 3, 0.0f, 1.0f));
    return {float4(color * lighting, 1), depthForPosition(position, camera)};
}

} // namespace MetalFLIP
