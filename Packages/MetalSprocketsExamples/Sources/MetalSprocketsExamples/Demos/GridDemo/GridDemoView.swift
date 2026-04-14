import DemoKit
import Interaction3D
import MetalSprockets
import MetalSprocketsAddOns
import MetalSprocketsSupport
import MetalSprocketsUI
import simd
import SwiftUI

public struct GridDemoView: View {
    @State private var cameraRotation = simd_quatf(angle: -.pi / 6, axis: [1, 0, 0])
    @State private var cameraDistance: Float = 10
    @State private var cameraTarget: SIMD3<Float> = .zero

    // Grid parameters
    @State private var minorLineWidth: Float = 0.01
    @State private var gridScale: Float = 1.0
    @State private var gridBrightness: Float = 1.0

    // Major division
    @State private var majorEnabled: Bool = false
    @State private var majorInterval: Int = 10
    @State private var majorLineWidth: Float = 0.02
    @State private var majorBrightness: Float = 1.0

    // Axis lines
    @State private var axisLinesEnabled: Bool = true
    @State private var axisLineWidth: Float = 0.03

    public init() {
    }

    private var cameraMatrix: simd_float4x4 {
        let rotation = float4x4(cameraRotation)
        let translation = float4x4.translation(cameraTarget.x, cameraTarget.y, cameraTarget.z)
        let distance = float4x4.translation(0, 0, cameraDistance)
        return translation * rotation * distance
    }

    public var body: some View {
        RenderView { _, drawableSize in
            let aspect = drawableSize.height > 0 ? Float(drawableSize.width / drawableSize.height) : 1.0
            let projectionMatrix = float4x4.perspective(fovY: .pi / 4, aspect: aspect, near: 0.1, far: 1_000.0)

            try RenderPass(label: "Infinite Grid") {
                GridShader(
                    projectionMatrix: projectionMatrix,
                    cameraMatrix: cameraMatrix,
                    lineWidth: SIMD2<Float>(repeating: minorLineWidth),
                    gridColor: SIMD4<Float>(gridBrightness, gridBrightness, gridBrightness, 1),
                    gridScale: SIMD2<Float>(repeating: gridScale),
                    highlightedLines: axisLinesEnabled ? [
                        .init(axis: .x, position: 0, width: axisLineWidth, color: [1, 0.2, 0.2, 1]),
                        .init(axis: .y, position: 0, width: axisLineWidth, color: [0.2, 0.4, 1, 1])
                    ] : [],
                    majorDivision: majorEnabled ? .init(
                        interval: majorInterval,
                        lineWidth: SIMD2<Float>(repeating: majorLineWidth),
                        color: SIMD4<Float>(majorBrightness, majorBrightness, majorBrightness, 1)
                    ) : nil,
                    backfaceColor: [1, 0, 1, 1]
                )
            }
        }
        .metalDepthStencilPixelFormat(.depth32Float)
        .frameTimingOverlay()
        .interactiveCamera(rotation: $cameraRotation, distance: $cameraDistance, target: $cameraTarget)
        .demoConfiguration {
            Form {
                Section("Minor Grid") {
                    LabeledContent("Line Width") {
                        Slider(value: $minorLineWidth, in: 0.001...0.1)
                    }
                    LabeledContent("Scale") {
                        Slider(value: $gridScale, in: 0.1...10)
                    }
                    LabeledContent("Brightness") {
                        Slider(value: $gridBrightness, in: 0...1)
                    }
                }

                Section("Major Grid") {
                    Toggle("Enabled", isOn: $majorEnabled)
                    if majorEnabled {
                        Picker("Interval", selection: $majorInterval) {
                            Text("5").tag(5)
                            Text("10").tag(10)
                            Text("20").tag(20)
                        }
                        LabeledContent("Line Width") {
                            Slider(value: $majorLineWidth, in: 0.005...0.2)
                        }
                        LabeledContent("Brightness") {
                            Slider(value: $majorBrightness, in: 0...1)
                        }
                    }
                }

                Section("Axis Lines") {
                    Toggle("Enabled", isOn: $axisLinesEnabled)
                    if axisLinesEnabled {
                        LabeledContent("Width") {
                            Slider(value: $axisLineWidth, in: 0.005...0.1)
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
    }
}
