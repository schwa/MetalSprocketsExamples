#pragma once

#import <simd/simd.h>

// TODO: Break this up.

// MARK: Cross-environment macros

#if defined(__METAL_VERSION__)
#import <metal_stdlib>
#define ATTRIBUTE(INDEX) [[attribute(INDEX)]]
#define TEXTURE2D(TYPE, ACCESS) metal::texture2d<TYPE, ACCESS>
#define DEPTH2D(TYPE, ACCESS) metal::depth2d<TYPE, ACCESS>
#define TEXTURECUBE(TYPE, ACCESS) metal::texturecube<TYPE, ACCESS>
#define SAMPLER metal::sampler
#define BUFFER(ADDRESS_SPACE, TYPE) ADDRESS_SPACE TYPE
#else
#import <Metal/Metal.h>
#define ATTRIBUTE(INDEX)
#define TEXTURE2D(TYPE, ACCESS) MTLResourceID
#define DEPTH2D(TYPE, ACCESS) MTLResourceID
#define TEXTURECUBE(TYPE, ACCESS) MTLResourceID
#define SAMPLER MTLResourceID
#define BUFFER(ADDRESS_SPACE, TYPE) TYPE
#endif

// MARK: SIMD Type aliases

typedef simd_float4x4 float4x4;
typedef simd_float3x3 float3x3;
typedef simd_float4 float4;
typedef simd_float3 float3;
typedef simd_float2 float2;

// MARK: Enum macros

// Copied from <CoreFoundation/CFAvailability.h>
#define __MS_ENUM_ATTRIBUTES __attribute__((enum_extensibility(open)))
#define __MS_ANON_ENUM(_type) enum __MS_ENUM_ATTRIBUTES : _type
#define __MS_NAMED_ENUM(_type, _name)                                                                                  \
    enum __MS_ENUM_ATTRIBUTES _name : _type _name;                                                                     \
    enum _name : _type
#define __MS_ENUM_GET_MACRO(_1, _2, NAME, ...) NAME
#define MS_ENUM(...) __MS_ENUM_GET_MACRO(__VA_ARGS__, __MS_NAMED_ENUM, __MS_ANON_ENUM, )(__VA_ARGS__)

// MARK: Frame uniforms

// TODO: Move to MetalSprocketsShaders.h (does not exist yet?)
struct FrameUniforms {
    uint index;
    float time;
    float deltaTime;
    simd_int2 viewportSize;
};
typedef struct FrameUniforms FrameUniforms;

// MARK: Math utilities

#if defined(__METAL_VERSION__)
inline float square(float x) {
    return x * x;
}

inline float3x3 extractNormalMatrix(float4x4 modelMatrix) {
    return float3x3(modelMatrix[0].xyz, modelMatrix[1].xyz, modelMatrix[2].xyz);
}
#endif

// MARK: Buffer descriptor and accessors

struct BufferDescriptor {
    uint count;        // elements in the buffer
    uint stride;       // bytes per element
    uint valueOffset;  // byte offset of the value within each element
};

#if defined(__METAL_VERSION__)
// Generic unaligned load: works for any T
template <typename T>
inline T load_at(device const uchar* base, constant BufferDescriptor& d, uint i) {
    T out;
    device const uchar* src = base + i * d.stride + d.valueOffset;
    thread uchar* dst = reinterpret_cast<thread uchar*>(&out);
    // tiny copy (no std::memcpy in MSL)
    for (uint b = 0; b < sizeof(T); ++b) { dst[b] = src[b]; }
    return out;
}

// Special-case float3 via packed_float3 to avoid alignment traps
template <>
inline float3 load_at<float3>(device const uchar* base, constant BufferDescriptor& d, uint i) {
    packed_float3 p = load_at<packed_float3>(base, d, i);
    return float3(p);
}

// Optional bounds-checked variant
template <typename T>
inline bool try_load(device const uchar* base, constant BufferDescriptor& d, uint i, thread T& out) {
    if (i >= d.count) return false;
    out = load_at<T>(base, d, i);
    return true;
}

#endif
