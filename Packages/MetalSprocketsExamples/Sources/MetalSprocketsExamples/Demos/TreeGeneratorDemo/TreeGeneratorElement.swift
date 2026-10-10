import Metal
import MetalSprockets
import MetalSprocketsExampleShaders
import simd

/// Draws a `TreeMesh` vertex buffer (bark + leaves) as one non-indexed triangle list.
struct TreeGeneratorElement: Element {
    let vertexBuffer: MTLBuffer
    let vertexCount: Int
    let uniforms: TreeGeneratorUniforms

    @MSState
    private var vertexShader: VertexShader

    @MSState
    private var fragmentShader: FragmentShader

    init(vertexBuffer: MTLBuffer, vertexCount: Int, uniforms: TreeGeneratorUniforms) throws {
        self.vertexBuffer = vertexBuffer
        self.vertexCount = vertexCount
        self.uniforms = uniforms
        let shaders = try ShaderNamespace.examples("TreeGenerator")
        vertexShader = try shaders.vertexMain
        fragmentShader = try shaders.fragmentMain
    }

    var body: some Element {
        get throws {
            try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                Draw { encoder in
                    encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: vertexCount)
                }
                .vertexBuffer(vertexBuffer, index: 0)
                .parameter("uniforms", value: uniforms)
            }
            .vertexDescriptor(Self.vertexDescriptor)
            .depthCompare(function: .less, enabled: true)
        }
    }

    static var vertexDescriptor: MTLVertexDescriptor {
        let descriptor = MTLVertexDescriptor()
        let attributeOffsets = [
            MemoryLayout<TreeVertex>.offset(of: \.position),
            MemoryLayout<TreeVertex>.offset(of: \.normal),
            MemoryLayout<TreeVertex>.offset(of: \.color)
        ]
        for (index, offset) in attributeOffsets.enumerated() {
            // swiftlint:disable:next force_unwrapping
            descriptor.attributes[index].offset = offset!
            descriptor.attributes[index].format = .float3
            descriptor.attributes[index].bufferIndex = 0
        }
        descriptor.layouts[0].stride = MemoryLayout<TreeVertex>.stride
        return descriptor
    }
}

extension TreeMesh {
    func makeBuffer(device: MTLDevice) -> MTLBuffer? {
        guard !vertices.isEmpty else {
            return nil
        }
        let buffer = vertices.withUnsafeBytes { device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared) } // swiftlint:disable:this force_unwrapping
        buffer?.label = "Tree Vertices"
        return buffer
    }
}
