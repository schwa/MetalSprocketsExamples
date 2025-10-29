import Metal
import MetalSprockets
import MetalSprocketsExampleShaders
import MetalSprocketsSupport

struct HitTestShader<Content>: Element where Content: Element {
    var vertexShader: VertexShader
    var fragmentShader: FragmentShader
    var content: Content

    init(@ElementBuilder content: () throws -> Content) throws {
        let device = _MTLCreateSystemDefaultDevice()
        assert(device.argumentBuffersSupport == .tier2)
        let shaderBundle = Bundle.metalSprocketsExampleShaders().orFatalError("Failed to load metal-sprockets example shaders bundle")
        let shaderLibrary = try ShaderLibrary(bundle: shaderBundle, namespace: "HitTest")
        vertexShader = try shaderLibrary.vertex_main
        fragmentShader = try shaderLibrary.fragment_main
        self.content = try content()
    }

    var body: some Element {
        get throws {
            try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                content
            }
            .renderPipelineDescriptorModifier { descriptor in
                descriptor.colorAttachments[0].pixelFormat = .r32Sint
                descriptor.colorAttachments[1].pixelFormat = .r32Sint
                descriptor.colorAttachments[2].pixelFormat = .r32Sint
                descriptor.colorAttachments[3].pixelFormat = .r32Float
                descriptor.colorAttachments[4].pixelFormat = .rgba32Float
            }
        }
    }
}

extension Element {
    func geometryID(_ id: Int32) -> some Element {
        self.parameter("geometryID", value: id)
    }

    func hitTestMatrices(projectionMatrix: simd_float4x4, viewMatrix: simd_float4x4, modelMatrix: simd_float4x4) -> some Element {
        // Pre-compute matrix products on CPU to avoid per-vertex computation
        let modelViewMatrix = viewMatrix * modelMatrix
        let modelViewProjectionMatrix = projectionMatrix * modelViewMatrix

        return self
            .parameter("modelViewMatrix", functionType: .vertex, value: modelViewMatrix)
            .parameter("modelViewProjectionMatrix", functionType: .vertex, value: modelViewProjectionMatrix)
    }
}
