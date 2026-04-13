import Foundation
import MetalSprockets
import MetalSprocketsExampleShaders

struct DebugRenderPipeline<Content>: Element where Content: Element {
    let modelMatrix: float4x4
    let normalMatrix: float3x3
    let debugMode: DebugShadersMode
    let lightPosition: float3
    let cameraPosition: float3
    let viewProjectionMatrix: float4x4

    let content: Content

    @MSState
    var vertexShader: VertexShader

    @MSState
    var fragmentShader: FragmentShader

    init(modelMatrix: float4x4, normalMatrix: float3x3, debugMode: DebugShadersMode, lightPosition: float3, cameraPosition: float3, viewProjectionMatrix: float4x4, @ElementBuilder content: () throws -> Content) throws {
        self.modelMatrix = modelMatrix
        self.normalMatrix = normalMatrix
        self.debugMode = debugMode
        self.lightPosition = lightPosition
        self.cameraPosition = cameraPosition
        self.viewProjectionMatrix = viewProjectionMatrix

        self.content = try content()

        let shaderBundle = Bundle.metalSprocketsExampleShaders()
        let shaderLibrary = try ShaderLibrary(bundle: shaderBundle).namespaced("DebugShader")
        self.vertexShader = try shaderLibrary.vertex_main
        self.fragmentShader = try shaderLibrary.fragment_main
    }

    var body: some Element {
        get throws {
            let debugShadersUniforms = DebugShadersUniforms(
                modelMatrix: modelMatrix,
                normalMatrix: normalMatrix,
                debugMode: debugMode.rawValue,
                lightPosition: lightPosition,
                cameraPosition: cameraPosition
            )
            let debugShadersAmplifiedUniforms = [DebugShadersAmplifiedUniforms(viewProjectionMatrix: viewProjectionMatrix)]
            return try RenderPipeline(label: "DebugRenderPipeline", vertexShader: vertexShader, fragmentShader: fragmentShader) {
                content
                    .parameter("uniforms", functionType: .vertex, value: debugShadersUniforms)
                    .parameter("uniforms", functionType: .fragment, value: debugShadersUniforms)
                    .parameter("amplifiedUniforms", values: debugShadersAmplifiedUniforms)
            }
        }
    }
}
