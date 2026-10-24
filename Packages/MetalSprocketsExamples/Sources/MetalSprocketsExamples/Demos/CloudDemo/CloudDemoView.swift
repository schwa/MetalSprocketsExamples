import DemoKit
import GeometryLite3D
import Interaction3D
import MetalSprockets
import MetalSprocketsExampleShaders
import MetalSprocketsUI
import simd
import SwiftUI

public struct CloudDemoView: View {
    enum Mode: Int, CaseIterable {
        case emissive
        case lit
    }

    @State private var projection: any ProjectionProtocol = PerspectiveProjection()
    @State private var cameraMatrix: simd_float4x4 = .init(translation: [0, 0.2, 4.5])
    @State private var drawableSize: CGSize = .zero
    @State private var mode: Mode = .emissive
    @State private var split: Double = 0.5
    @State private var density: Double = 12
    @State private var samplesPerPixel: Double = 1
    @State private var maxBounces: Double = 8
    @State private var sunAngle: Double = 40
    @State private var animate = true

    public init() {
    }

    public var body: some View {
        WorldView(projection: $projection, cameraMatrix: $cameraMatrix) {
            RenderView { context, _ in
                try RenderPass {
                    try CloudPipeline(uniforms: uniforms(time: animate ? context.frameUniforms.time : 0))
                }
            }
            .metalColorPixelFormat(.bgra8Unorm_srgb)
            .onDrawableSizeChange { drawableSize = $0 }
        }
        .demoConfiguration {
            Form {
                Picker("Medium", selection: $mode) {
                    Text("Emissive").tag(Mode.emissive)
                    Text("Lit").tag(Mode.lit)
                }
                LabeledContent("Split") {
                    Slider(value: $split, in: 0...1)
                }
                LabeledContent("Density") {
                    Slider(value: $density, in: 1...40)
                    Text("\(Int(density))").monospacedDigit().fixedSize()
                }
                LabeledContent("Samples / Pixel") {
                    Slider(value: $samplesPerPixel, in: 1...16, step: 1)
                    Text("\(Int(samplesPerPixel))").monospacedDigit().fixedSize()
                }
                if mode == .lit {
                    LabeledContent("Max Bounces") {
                        Slider(value: $maxBounces, in: 0...32, step: 1)
                        Text("\(Int(maxBounces))").monospacedDigit().fixedSize()
                    }
                    LabeledContent("Sun Angle") {
                        Slider(value: $sunAngle, in: 0...180)
                    }
                }
                Toggle("Animate", isOn: $animate)
            }
            .formStyle(.grouped)
        }
    }

    private func uniforms(time: Float) -> CloudUniforms {
        let projectionMatrix = projection.projectionMatrix(for: drawableSize)
        let viewProjection = projectionMatrix * cameraMatrix.inverse
        let angle = Float(sunAngle) * .pi / 180
        let sunDirection = simd_normalize(SIMD3<Float>(cos(angle), 0.8, 0.3 * sin(angle)))
        // Fresh RNG seed every frame so path-traced noise doesn't freeze.
        let seed = UInt32.random(in: 0...UInt32.max)
        return CloudUniforms(
            inverseViewProjection: viewProjection.inverse,
            cameraPosition: cameraMatrix.columns.3.xyz,
            sunDirection: sunDirection,
            time: time,
            density: Float(density),
            split: Float(split),
            mode: Int32(mode.rawValue),
            samplesPerPixel: Int32(samplesPerPixel),
            maxBounces: Int32(maxBounces),
            frameIndex: seed
        )
    }
}

struct CloudPipeline: Element {
    let uniforms: CloudUniforms

    @MSState private var vertexShader: VertexShader
    @MSState private var fragmentShader: FragmentShader

    init(uniforms: CloudUniforms) throws {
        self.uniforms = uniforms
        let shaders = try ShaderNamespace.examples("CloudShaders")
        vertexShader = try shaders.vertex_main
        fragmentShader = try shaders.fragment_main
    }

    var body: some Element {
        get throws {
            try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                Draw { encoder in
                    encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
                }
                .parameter("uniforms", functionType: .fragment, value: uniforms)
            }
        }
    }
}
