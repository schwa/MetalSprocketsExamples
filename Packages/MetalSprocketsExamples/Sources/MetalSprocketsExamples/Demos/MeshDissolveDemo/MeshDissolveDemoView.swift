import DemoKit
import GeometryLite3D
import Interaction3D
import Metal
import MetalSprockets
import MetalSprocketsExampleShaders
import MetalSprocketsUI
import MetalSupport
import simd
import SwiftMesh
import SwiftUI

/// Triplanar-grid dissolve effects on a cube, ported from the MeshDissolveTestbed
/// app (grid render mode only).
public struct MeshDissolveDemoView: View {
    @State private var effect: MeshDissolveEffect = .noiseDissolve
    /// When nil: idle. When set: the frame-time at which Animate was pressed.
    @State private var animationStart: Float?
    @State private var animationDuration: Float = 2.0
    /// Manual scrub (0…1) used when no animation is running.
    @State private var manualProgress: Float = 0

    @State private var gridCellSize: Float = 0.25
    @State private var gridLineWidth: Float = 0.08
    @State private var foregroundColor = Color(red: 0.85, green: 0.95, blue: 1.00)
    @State private var backgroundColor = Color.black.opacity(0)
    @State private var edgeColor = Color(red: 1.00, green: 0.55, blue: 0.10)

    @State private var cameraMatrix: float4x4 = .init(translation: [0, 0, 6])

    @State private var metalMesh: MetalMesh

    /// Most recent frame time, captured by the render closure; read on button press.
    @State private var latestFrameTime: Float = 0

    public init() {
        let device = _MTLCreateSystemDefaultDevice()
        let mesh = Mesh.cube(extents: [2, 2, 2], attributes: [.flatNormals])
        metalMesh = MetalMesh(mesh: mesh, device: device, label: "DissolveCube")
    }

    public var body: some View {
        RenderView { context, size in
            let time = context.frameUniforms.time
            let aspect = size.height > 0 ? Float(size.width / size.height) : 1
            let projection = float4x4.perspective(aspectRatio: aspect, fovy: .pi / 4, near: 0.1, far: 100)
            try RenderPass {
                try MeshDissolveElement(
                    metalMesh: metalMesh,
                    transform: projection * cameraMatrix.inverse,
                    uniforms: makeUniforms(time: time)
                )
            }
            .onWorkloadEnter { _ in
                latestFrameTime = time
                if let start = animationStart, time - start >= animationDuration {
                    animationStart = nil
                    manualProgress = 1
                }
            }
        }
        .interactiveCamera(cameraMatrix: $cameraMatrix, mode: .turntable())
        .metalDepthStencilPixelFormat(.depth32Float)
        .metalClearColor(.init(red: 0, green: 0, blue: 0, alpha: 1))
        .demoConfiguration {
            Form {
                Section("Grid") {
                    LabeledContent("Cell Size") {
                        Slider(value: $gridCellSize, in: 0.05...1.0)
                        Text(gridCellSize.formatted(.number.precision(.fractionLength(2))))
                            .monospacedDigit()
                    }
                    LabeledContent("Line Width") {
                        Slider(value: $gridLineWidth, in: 0.0...0.45)
                        Text(gridLineWidth.formatted(.number.precision(.fractionLength(2))))
                            .monospacedDigit()
                    }
                    ColorPicker("Foreground", selection: $foregroundColor, supportsOpacity: true)
                    ColorPicker("Background", selection: $backgroundColor, supportsOpacity: true)
                }
                Section("Effect") {
                    Picker("Effect", selection: $effect) {
                        ForEach(MeshDissolveEffect.allCases) { effect in
                            Text(effect.displayName).tag(effect)
                        }
                    }
                    ColorPicker("Edge / Burn Color", selection: $edgeColor, supportsOpacity: false)
                }
                Section("Animation") {
                    Button {
                        manualProgress = 0
                        animationStart = latestFrameTime
                    } label: {
                        Label("Animate", systemImage: "play.fill")
                    }
                    .disabled(animationStart != nil)
                    LabeledContent("Progress") {
                        Slider(value: $manualProgress, in: 0...1)
                            .disabled(animationStart != nil)
                        Text(manualProgress.formatted(.number.precision(.fractionLength(2))))
                            .monospacedDigit()
                    }
                    LabeledContent("Duration") {
                        Slider(value: $animationDuration, in: 0.25...5.0)
                        Text(animationDuration.formatted(.number.precision(.fractionLength(2))) + "s")
                            .monospacedDigit()
                    }
                }
            }
            .formStyle(.grouped)
        }
        .onChange(of: effect) {
            animationStart = nil
        }
    }

    private func makeUniforms(time: Float) -> MeshDissolveUniforms {
        // When idle, back-date the start so the shader's derived progress
        // equals the manual scrub position.
        let start = animationStart ?? (time - manualProgress * animationDuration)
        var uniforms = MeshDissolveUniforms()
        uniforms.time = time
        uniforms.animationStart = start
        uniforms.animationDuration = animationDuration
        uniforms.effect = effect.rawValue
        uniforms.gridCellSize = gridCellSize
        uniforms.gridLineWidth = gridLineWidth
        uniforms.backgroundColor = backgroundColor.linearRGBA
        uniforms.foregroundColor = foregroundColor.linearRGBA
        uniforms.edgeColor = edgeColor.linearRGBA
        uniforms.edgeWidth = 0.05
        return uniforms
    }
}

private extension Color {
    /// Linear-space RGBA, suitable for direct upload to Metal.
    var linearRGBA: SIMD4<Float> {
        let resolved = resolve(in: EnvironmentValues())
        return SIMD4(resolved.linearRed, resolved.linearGreen, resolved.linearBlue, resolved.opacity)
    }
}
