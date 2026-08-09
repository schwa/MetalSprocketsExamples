import Metal
import MetalKit
import MetalSprockets
import MetalSprocketsExampleShaders
import MetalSprocketsSupport
import ModelIO
import simd

// MARK: - Global Uniforms

struct PBRShader<Content>: Element where Content: Element {
    var vertexShader: VertexShader
    var fragmentShader: FragmentShader
    var content: Content

    init(@ElementBuilder content: () throws -> Content) throws {
        let shaderBundle = Bundle.metalSprocketsExampleShaders()
        let shaderLibrary = try ShaderLibrary(bundle: shaderBundle).namespaced("PBR")
        self.vertexShader = try shaderLibrary.vertex_main
        self.fragmentShader = try shaderLibrary.fragment_main
        self.content = try content()
    }

    var body: some Element {
        get throws {
            try RenderPipeline(label: "PBR Shader", vertexShader: vertexShader, fragmentShader: fragmentShader) {
                content
            }
        }
    }
}

// MARK: - Element Extensions for PBR

/// The matrix that takes normals from model space to world space.
///
/// This is the inverse transpose of the model transform's upper-left 3x3, which is what keeps normals
/// perpendicular to the surface under non-uniform scale.
func pbrNormalMatrix(modelTransform: float4x4) -> float3x3 {
    float3x3(modelTransform[0].xyz, modelTransform[1].xyz, modelTransform[2].xyz).transpose.inverse
}

public extension Element {
    /// Supplies the per-model PBR uniforms.
    ///
    /// Apply this per draw. The per-view uniforms are separate — see ``pbrViewUniforms(cameraMatrix:projectionMatrix:)``.
    func pbrModelUniforms(modelTransform: float4x4) -> some Element {
        let uniforms = PBRUniforms(modelMatrix: modelTransform, normalMatrix: pbrNormalMatrix(modelTransform: modelTransform))
        return self
            .parameter("uniforms", functionType: .vertex, value: uniforms)
            .parameter("uniforms", functionType: .fragment, value: uniforms)
    }

    /// Supplies the per-view PBR uniforms.
    ///
    /// These do not vary per model, so apply this once around everything drawn with the same camera
    /// rather than per draw.
    func pbrViewUniforms(cameraMatrix: float4x4, projectionMatrix: float4x4) -> some Element {
        let viewUniforms = [PBRAmplifiedUniforms(
            viewProjectionMatrix: projectionMatrix * cameraMatrix.inverse,
            cameraPosition: cameraMatrix.translation
        )]
        return self
            .parameter("amplifiedUniforms", functionType: .vertex, values: viewUniforms)
            .parameter("amplifiedUniforms", functionType: .fragment, values: viewUniforms)
    }

    func pbrEnvironment(_ texture: MTLTexture) -> some Element {
        self
            .parameter("environmentTexture", functionType: .fragment, texture: texture)
            .useResource(texture, usage: .read, stages: .fragment)
    }
}
