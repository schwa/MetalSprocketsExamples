import DemoKit
import MetalKit
import MetalSprockets
import MetalSprocketsShaderGraph
import MetalSprocketsUI
import MetalSupport
import ShaderGraphSupport
import simd
import SwiftUI

public struct ShaderGraphDemoView: DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Shader Graph",
            systemImage: "point.3.connected.trianglepath.dotted",
            description: "Build Metal shaders as Swift DSL graphs",
            longDescription: "A Swift DSL that generates Metal code via `MTLFunctionStitchingGraph`. Build fragment shader effects as a graph of nodes and stitch them into a `visible_function_table` at runtime.",
            group: "Complex"
        )
    }

    @State private var vertexShader: VertexShader?
    @State private var fragmentShader: FragmentShader?
    @State private var stitchedFunction: VisibleFunction?
    @State private var errorMessage: String?
    @State private var selectedEffect: ColorEffect = .plasmaWaveFlattened

    public init() {}

    public var body: some View {
        ZStack {
            Color.black
            if let errorMessage {
                ContentUnavailableView("Shader Error", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if let vertexShader, let fragmentShader, let stitchedFunction {
                ShaderGraphRenderView(
                    vertexShader: vertexShader,
                    fragmentShader: fragmentShader,
                    stitchedFunction: stitchedFunction
                )
                .id(selectedEffect)
                .aspectRatio(1.0, contentMode: .fit)
            } else {
                ProgressView("Setting up shaders...")
            }
        }
        .ignoresSafeArea()
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Effect", selection: $selectedEffect) {
                    ForEach(ColorEffect.allCases, id: \.self) { effect in
                        Text(effect.rawValue).tag(effect)
                    }
                }
            }
        }
        .task(id: selectedEffect) {
            do {
                let device = _MTLCreateSystemDefaultDevice()
                let library = try ShaderLibrary(bundle: .metalSprocketsExampleShaders()).namespaced("ShaderGraphDemo")
                vertexShader = try library.vertex_main
                fragmentShader = try library.fragment_main
                stitchedFunction = try selectedEffect.makeVisibleFunction(device: device)
            } catch {
                errorMessage = String(describing: error)
            }
        }
    }
}

struct ShaderGraphRenderView: View {
    let vertexShader: VertexShader
    let fragmentShader: FragmentShader
    let stitchedFunction: VisibleFunction

    var body: some View {
        RenderView { context, _ in
            let time = context.frameUniforms.time

            try RenderPass {
                try RenderPipeline(
                    vertexShader: vertexShader,
                    fragmentShader: fragmentShader
                ) {
                    Draw { encoder in
                        drawTriangle(encoder: encoder)
                    }
                    .visibleFunctionTable("colorFunction", function: stitchedFunction.function)
                    .parameter("time", value: time)
                    .parameter("contrastAmount", value: Float(1.5))
                }
                .vertexDescriptor(makeVertexDescriptor())
                .linkedFunctions([stitchedFunction.function])
            }
        }
        .metalDepthStencilPixelFormat(.depth32Float)
    }

    private func drawTriangle(encoder: MTLRenderCommandEncoder) {
        struct Vertex {
            var position: SIMD2<Float>
            var color: SIMD4<Float>
            var uv: SIMD2<Float>
        }

        let vertices: [Vertex] = [
            Vertex(position: [0, 0.75], color: [1, 0, 0, 1], uv: [0.5, 1.0]),
            Vertex(position: [-0.75, -0.75], color: [0, 1, 0, 1], uv: [0.0, 0.0]),
            Vertex(position: [0.75, -0.75], color: [0, 0, 1, 1], uv: [1.0, 0.0])
        ]

        encoder.setVertexBytes(vertices, length: MemoryLayout<Vertex>.stride * 3, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    }
}

enum ColorEffect: String, CaseIterable {
    case solidColor = "Solid Color"
    case vertexGradient = "Vertex Gradient"
    case psychedelicPulse = "Psychedelic Pulse"
    case plasmaWave = "Plasma Wave"
    case plasmaWaveFlattened = "Plasma Wave (Flattened)"

    func makeVisibleFunction(device: MTLDevice) throws -> VisibleFunction {
        switch self {
        case .solidColor:
            // A constant color - ignores all inputs
            let graph = ShaderGraph(
                device: device,
                inputs: [("color", .float4), ("uv", .float2), ("time", .float), ("contrastAmount", .float)],
                output: .float4
            )
            graph.registerStdlib()

            let final = graph.constant(SIMD4<Float>(0.2, 0.4, 0.8, 1.0))
            print(graph.optimized(final).graphviz(name: "solidColor"))
            return try graph.makeVisibleFunction("solidColor", node: final)

        case .vertexGradient:
            // Pass through interpolated vertex colors
            let graph = ShaderGraph(
                device: device,
                inputs: [("color", .float4), ("uv", .float2), ("time", .float), ("contrastAmount", .float)],
                output: .float4
            )
            graph.registerStdlib()

            let vertexColor = graph.input("color", type: SIMD4<Float>.self)
            print(graph.optimized(vertexColor).graphviz(name: "vertexGradient"))
            return try graph.makeVisibleFunction("vertexGradient", node: vertexColor)

        case .psychedelicPulse:
            // Animated blend of pulsing vertex colors and UV gradient
            let graph = ShaderGraph(
                device: device,
                inputs: [("color", .float4), ("uv", .float2), ("time", .float), ("contrastAmount", .float)],
                output: .float4
            )
            graph.registerStdlib()

            let vertexColor = graph.input("color", type: SIMD4<Float>.self)
            let uv = graph.input("uv", type: SIMD2<Float>.self)
            let time = graph.input("time", type: Float.self)
            let contrastAmount = graph.input("contrastAmount", type: Float.self)

            let pulse = (sin(time * 3.0) + 1.0) * 0.5
            let pulseFactor = pulse * 0.5 + 0.5
            let pulsedColor = float4(
                vertexColor.r * pulseFactor,
                vertexColor.g * pulseFactor,
                vertexColor.b * pulseFactor,
                vertexColor.a
            )
            let gradient = float4(uv.x, uv.y, 1.0 - uv.x, 1.0)
            let mixT = (sin(time * 2.0) + 1.0) * 0.5
            let mixed = mix(pulsedColor, gradient, mixT)
            let adjusted = (mixed - 0.5) * contrastAmount + 0.5
            let final = float4(adjusted.r, adjusted.g, adjusted.b, mixed.a)
            print(graph.optimized(final).graphviz(name: "psychedelicPulse"))
            return try graph.makeVisibleFunction("psychedelicPulse", node: final)

        case .plasmaWave:
            // Classic plasma effect using layered sine waves
            let graph = ShaderGraph(
                device: device,
                inputs: [("color", .float4), ("uv", .float2), ("time", .float), ("contrastAmount", .float)],
                output: .float4
            )
            graph.registerStdlib()

            let vertexColor = graph.input("color", type: SIMD4<Float>.self)
            let uv = graph.input("uv", type: SIMD2<Float>.self)
            let time = graph.input("time", type: Float.self)

            // Sum of sine waves at different frequencies and phases
            let v1 = sin(uv.x * 10.0 + time)
            let v2 = sin(uv.y * 10.0 + time * 1.5)
            let v3 = sin((uv.x + uv.y) * 5.0 + time * 0.5)
            let v4 = sin(((uv.x - 0.5) * (uv.x - 0.5) + (uv.y - 0.5) * (uv.y - 0.5)) * 10.0 + time * 2.0)

            let plasma = (v1 + v2 + v3 + v4) * 0.25

            // Map plasma value to RGB using phase-shifted sines
            let r = (sin(plasma * 3.14159 + time) + 1.0) * 0.5
            let g = (sin(plasma * 3.14159 + time + 2.094) + 1.0) * 0.5  // +2π/3
            let b = (sin(plasma * 3.14159 + time + 4.189) + 1.0) * 0.5  // +4π/3

            let plasmaColor = float4(r, g, b, 1.0)

            // Blend with vertex color
            let blendT = (sin(time * 0.5) + 1.0) * 0.5
            let final = mix(vertexColor, plasmaColor, blendT)
            print(graph.optimized(final).graphviz(name: "plasmaWave"))
            return try graph.makeVisibleFunction("plasmaWave", node: final)

        case .plasmaWaveFlattened:
            // Same as plasmaWave but flattened into fewer functions
            let graph = ShaderGraph(
                device: device,
                inputs: [("color", .float4), ("uv", .float2), ("time", .float), ("contrastAmount", .float)],
                output: .float4
            )
            graph.registerStdlib()

            let vertexColor = graph.input("color", type: SIMD4<Float>.self)
            let uv = graph.input("uv", type: SIMD2<Float>.self)
            let time = graph.input("time", type: Float.self)

            // Sum of sine waves at different frequencies and phases
            let v1 = sin(uv.x * 10.0 + time)
            let v2 = sin(uv.y * 10.0 + time * 1.5)
            let v3 = sin((uv.x + uv.y) * 5.0 + time * 0.5)
            let v4 = sin(((uv.x - 0.5) * (uv.x - 0.5) + (uv.y - 0.5) * (uv.y - 0.5)) * 10.0 + time * 2.0)

            // Flatten the plasma calculation into one function
            let plasma = graph.flatten((v1 + v2 + v3 + v4) * 0.25)

            // Map plasma value to RGB using phase-shifted sines - flatten each channel
            let r = graph.flatten((sin(plasma * 3.14159 + time) + 1.0) * 0.5)
            let g = graph.flatten((sin(plasma * 3.14159 + time + 2.094) + 1.0) * 0.5)
            let b = graph.flatten((sin(plasma * 3.14159 + time + 4.189) + 1.0) * 0.5)

            let plasmaColor = float4(r, g, b, 1.0)

            // Blend with vertex color
            let blendT = graph.flatten((sin(time * 0.5) + 1.0) * 0.5)
            let final = mix(vertexColor, plasmaColor, blendT)
            print(graph.optimized(final).graphviz(name: "plasmaWaveFlattened"))
            return try graph.makeVisibleFunction("plasmaWaveFlattened", node: final)
        }
    }
}
