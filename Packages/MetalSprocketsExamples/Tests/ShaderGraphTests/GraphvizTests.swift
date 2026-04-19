import Testing
import Metal
import ShaderGraph
import ShaderGraphSupport

@Suite
struct GraphvizTests {
    let device: MTLDevice

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw TestError.noDevice
        }
        self.device = device
    }

    @Test
    func simpleGraph() throws {
        let graph = ShaderGraph(
            device: device,
            inputs: [("a", .float), ("b", .float)],
            output: .float
        )
        graph.registerStdlib()

        let a = graph.input("a", type: Float.self)
        let b = graph.input("b", type: Float.self)
        let result = a + b

        let dot = result.graphviz(name: "Addition")

        #expect(dot.contains("digraph Addition"))
        #expect(dot.contains("input[0]"))
        #expect(dot.contains("input[1]"))
        #expect(dot.contains("add_f_f"))

        print("=== Simple Graph ===")
        print(dot)
    }

    @Test
    func complexGraph() throws {
        let graph = ShaderGraph(
            device: device,
            inputs: [("color", .float4), ("uv", .float2), ("time", .float)],
            output: .float4
        )
        graph.registerStdlib()

        let color = graph.input("color", type: SIMD4<Float>.self)
        let uv = graph.input("uv", type: SIMD2<Float>.self)
        let time = graph.input("time", type: Float.self)

        // Animated UV-based color
        let r = (sin(uv.x * 10.0 + time) + 1.0) * 0.5
        let g = (sin(uv.y * 10.0 + time) + 1.0) * 0.5
        let b = color.b
        let result = float4(r, g, b, color.a)

        let dot = result.graphviz(name: "AnimatedColor")

        #expect(dot.contains("digraph AnimatedColor"))
        #expect(dot.contains("sin_f"))
        #expect(dot.contains("make_f4"))
        #expect(dot.contains("swizzle"))

        print("=== Complex Graph ===")
        print(dot)
    }

    @Test
    func constantGraph() throws {
        let graph = ShaderGraph(
            device: device,
            inputs: [("unused", .float)],
            output: .float4
        )
        graph.registerStdlib()

        let result = graph.constant(SIMD4<Float>(1, 0, 0, 1))

        let dot = result.graphviz(name: "Constant")

        #expect(dot.contains("digraph Constant"))
        #expect(dot.contains("_const_f4_"))

        print("=== Constant Graph ===")
        print(dot)
    }
}

enum TestError: Error {
    case noDevice
}
