#include <metal_stdlib>
using namespace metal;

struct SkinningVertexIn {
    float3 position  [[attribute(0)]];
    float3 normal    [[attribute(1)]];
    ushort2 boneIndices [[attribute(2)]];
    float2 boneWeights [[attribute(3)]];
};

struct SkinningVertexOut {
    float4 position [[position]];
    float3 worldNormal;
    float3 worldPosition;
};

struct SkinningUniforms {
    float4x4 viewProjectionMatrix;
    float4x4 modelMatrix;
    float3 cameraPosition;
};

// Two bone matrices: bone[0] = root, bone[1] = tip
struct SkinningBoneMatrices {
    float4x4 bones[2];
    float4x4 boneNormals[2]; // inverse transpose for normals
};

[[vertex]] SkinningVertexOut skinning_vertex(
    const SkinningVertexIn in [[stage_in]],
    constant SkinningUniforms &uniforms [[buffer(1)]],
    constant SkinningBoneMatrices &bones [[buffer(2)]]
) {
    // Compute skinned position
    float4 pos = float4(in.position, 1.0);
    float4 norm = float4(in.normal, 0.0);

    ushort idx0 = in.boneIndices.x;
    ushort idx1 = in.boneIndices.y;
    float w0 = in.boneWeights.x;
    float w1 = in.boneWeights.y;

    float4 skinnedPos = w0 * (bones.bones[idx0] * pos) + w1 * (bones.bones[idx1] * pos);
    float4 skinnedNorm = w0 * (bones.boneNormals[idx0] * norm) + w1 * (bones.boneNormals[idx1] * norm);

    float4 worldPos = uniforms.modelMatrix * skinnedPos;

    SkinningVertexOut out;
    out.position = uniforms.viewProjectionMatrix * worldPos;
    out.worldNormal = normalize((uniforms.modelMatrix * skinnedNorm).xyz);
    out.worldPosition = worldPos.xyz;
    return out;
}

[[fragment]] float4 skinning_fragment(
    SkinningVertexOut in [[stage_in]],
    constant SkinningUniforms &uniforms [[buffer(1)]]
) {
    // Simple directional + ambient lighting
    float3 lightDir = normalize(float3(1.0, 2.0, 1.5));
    float3 N = normalize(in.worldNormal);
    float3 V = normalize(uniforms.cameraPosition - in.worldPosition);
    float3 H = normalize(lightDir + V);

    float NdotL = max(dot(N, lightDir), 0.0);
    float NdotH = max(dot(N, H), 0.0);

    float3 ambient = float3(0.15, 0.12, 0.18);
    float3 diffuseColor = float3(0.6, 0.75, 0.85);
    float3 specularColor = float3(1.0, 1.0, 1.0);

    float3 diffuse = diffuseColor * NdotL;
    float spec = pow(NdotH, 64.0);
    float3 specular = specularColor * spec;

    float3 color = ambient + diffuse + specular * 0.5;
    return float4(color, 1.0);
}

// MARK: - Bone Visualization Shaders

struct BoneVertexIn {
    float3 position [[attribute(0)]];
};

struct BoneVertexOut {
    float4 position [[position]];
    float4 color;
};

struct BoneUniforms {
    float4x4 viewProjectionMatrix;
};

[[vertex]] BoneVertexOut bone_vertex(
    const BoneVertexIn in [[stage_in]],
    constant BoneUniforms &uniforms [[buffer(1)]],
    constant float4 &color [[buffer(2)]]
) {
    BoneVertexOut out;
    out.position = uniforms.viewProjectionMatrix * float4(in.position, 1.0);
    out.color = color;
    return out;
}

[[fragment]] float4 bone_fragment(
    BoneVertexOut in [[stage_in]]
) {
    return in.color;
}
