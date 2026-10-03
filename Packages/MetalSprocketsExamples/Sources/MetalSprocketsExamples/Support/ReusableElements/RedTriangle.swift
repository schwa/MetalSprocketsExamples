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
                        encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
                    }
                    .vertexValues([[0, 0.75], [-0.75, -0.75], [0.75, -0.75]] as [SIMD2<Float>], index: 0)
                    .parameter("color", value: SIMD4<Float>([1, 0, 0, 1]))
                }
                .vertexDescriptor(vertexShader.inferredVertexDescriptor())
            }
        }
    }
}
