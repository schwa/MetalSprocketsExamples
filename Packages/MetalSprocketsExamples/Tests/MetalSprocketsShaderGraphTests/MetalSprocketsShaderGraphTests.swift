import Testing
import Metal
@testable import MetalSprocketsShaderGraph

@Suite("MetalSprocketsShaderGraph Tests")
struct MetalSprocketsShaderGraphTests {

    @Test("makeVisibleFunction returns a VisibleFunction")
    func testMakeVisibleFunction() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw TestError.noDevice
        }

        let graph = ShaderGraph(
            device: device,
            inputs: [("color", .float4), ("brightness", .float)],
            output: .float4
        )
        graph.registerStdlib()

        let color = graph.input("color", type: SIMD4<Float>.self)
        let brightness = graph.input("brightness", type: Float.self)
        let result = color + brightness

        let visibleFunction = try graph.makeVisibleFunction("brighten", node: result)

        #expect(visibleFunction.function.name == "brighten")
        #expect(visibleFunction.function.functionType == .visible)
    }
}

enum TestError: Error {
    case noDevice
}
