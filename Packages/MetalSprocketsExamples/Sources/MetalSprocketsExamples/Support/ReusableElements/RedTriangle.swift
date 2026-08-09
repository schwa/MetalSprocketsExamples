import CoreGraphics
import ImageIO
import Metal
import MetalSprockets
import simd
import UniformTypeIdentifiers

struct RedTriangle: Element {
    init() {
        // This line intentionally left blank.
    }

    @MSState
    private var vertexShader = ShaderLibrary.examples.namespaced("RedTriangle")
        .requiredFunction(named: "vertex_main", type: VertexShader.self)

    @MSState
    private var fragmentShader = ShaderLibrary.examples.namespaced("RedTriangle")
        .requiredFunction(named: "fragment_main", type: FragmentShader.self)

    var body: some Element {
        get throws {
            try RenderPass {
                try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                    Draw { encoder in
                        let vertices: [SIMD2<Float>] = [[0, 0.75], [-0.75, -0.75], [0.75, -0.75]]
                        encoder.setVertexBytes(vertices, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
                        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                    }
                    .parameter("color", value: SIMD4<Float>([1, 0, 0, 1]))
                }
                .vertexDescriptor(vertexShader.inferredVertexDescriptor())
            }
        }
    }
}
