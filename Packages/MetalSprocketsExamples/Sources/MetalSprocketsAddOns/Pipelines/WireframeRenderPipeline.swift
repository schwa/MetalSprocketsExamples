import Metal
import MetalKit
import MetalSprockets
import MetalSprocketsAddOnsShaders

public struct WireframeRenderPipeline: Element {
    let vertexShader: VertexShader
    let fragmentShader: FragmentShader
    var mvpMatrix: float4x4
    var wireframeColor: SIMD4<Float>
    var mesh: MTKMesh

    public init(mvpMatrix: float4x4, wireframeColor: SIMD4<Float>, mesh: MTKMesh) throws {
        let shaderBundle = Bundle.metalSprocketsAddOnsShaders().orFatalError("Failed to load metal-sprockets example shaders bundle")
        let shaderLibrary = try ShaderLibrary(bundle: shaderBundle, namespace: "WireframeShader")
        self.vertexShader = try shaderLibrary.vertex_main
        self.fragmentShader = try shaderLibrary.fragment_main
        self.mvpMatrix = mvpMatrix
        self.wireframeColor = wireframeColor
        self.mesh = mesh
    }

    public var body: some Element {
        get throws {
            try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                let uniforms = WireframeUniforms(modelViewProjectionMatrix: mvpMatrix, wireframeColor: wireframeColor)
                Draw { encoder in
                    encoder.setTriangleFillMode(.lines)
                    encoder.setVertexBuffers(of: mesh)
                    encoder.draw(mesh)
                }
                .parameter("uniforms", functionType: .vertex, value: uniforms)
                .parameter("uniforms", functionType: .fragment, value: uniforms)
            }
            .vertexDescriptor(mesh.vertexDescriptor)
        }
    }
}
