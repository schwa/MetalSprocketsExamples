#pragma once

#import <simd/simd.h>

#if defined(__METAL_VERSION__)
#import <metal_stdlib>
#define ATTRIBUTE(INDEX) [[attribute(INDEX)]]
#define TEXTURE2D(TYPE, ACCESS) texture2d<TYPE, ACCESS>
#define DEPTH2D(TYPE, ACCESS) depth2d<TYPE, ACCESS>
#define TEXTURECUBE(TYPE, ACCESS) texturecube<TYPE, ACCESS>
#define SAMPLER sampler
#define BUFFER(ADDRESS_SPACE, TYPE) ADDRESS_SPACE TYPE
using namespace metal;
#else
#import <Metal/Metal.h>
#define ATTRIBUTE(INDEX)
#define TEXTURE2D(TYPE, ACCESS) MTLResourceID
#define DEPTH2D(TYPE, ACCESS) MTLResourceID
#define TEXTURECUBE(TYPE, ACCESS) MTLResourceID
#define SAMPLER MTLResourceID
#define BUFFER(ADDRESS_SPACE, TYPE) TYPE
#endif

typedef simd_float4x4 float4x4;
typedef simd_float3x3 float3x3;
typedef simd_float4 float4;
typedef simd_float3 float3;
typedef simd_float2 float2;

// Copied from <CoreFoundation/CFAvailability.h>
#define __MS_ENUM_ATTRIBUTES __attribute__((enum_extensibility(open)))
#define __MS_ANON_ENUM(_type) enum __MS_ENUM_ATTRIBUTES : _type
#define __MS_NAMED_ENUM(_type, _name)                                                                                  \
    enum __MS_ENUM_ATTRIBUTES _name : _type _name;                                                                     \
    enum _name : _type
#define __MS_ENUM_GET_MACRO(_1, _2, NAME, ...) NAME
#define MS_ENUM(...) __MS_ENUM_GET_MACRO(__VA_ARGS__, __MS_NAMED_ENUM, __MS_ANON_ENUM, )(__VA_ARGS__)

