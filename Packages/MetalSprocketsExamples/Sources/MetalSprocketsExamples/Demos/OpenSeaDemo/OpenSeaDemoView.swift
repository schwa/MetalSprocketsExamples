import DemoKit
import MetalSprockets
import MetalSprocketsUI
import SwiftUI

/// Gerstner-wave ocean with an analytic sky, ported from a standalone
/// MTKView app ("OpenSea") to MetalSprockets elements.
public struct OpenSeaDemoView: View {
    @State private var camera = OpenSeaCamera()
    @State private var seaState: Double = 45
    @State private var timeOfDay: Double = 55
    @State private var drift = true

    @State private var lastTranslation: CGSize = .zero
    @State private var lastMagnification: CGFloat = 1

    public init() {
    }

    public var body: some View {
        RenderView { context, size in
            try RenderPass {
                try OpenSeaPipeline(
                    seaState: seaState,
                    timeOfDay: timeOfDay,
                    drift: drift,
                    camera: camera,
                    time: context.frameUniforms.time,
                    aspect: size.height > 0 ? Float(size.width / size.height) : 1
                )
            }
        }
        .metalDepthStencilPixelFormat(.depth32Float)
        .metalColorPixelFormat(.bgra8Unorm_srgb)
        .metalSampleCount(4)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let dx = value.translation.width - lastTranslation.width
                    let dy = value.translation.height - lastTranslation.height
                    lastTranslation = value.translation
                    camera.orbit(deltaX: Float(dx), deltaY: Float(dy))
                }
                .onEnded { _ in lastTranslation = .zero }
        )
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    let ratio = value.magnification / lastMagnification
                    lastMagnification = value.magnification
                    camera.zoom(delta: Float(-log(ratio) * 100))
                }
                .onEnded { _ in lastMagnification = 1 }
        )
        .demoConfiguration {
            Form {
                LabeledContent("Sea State") {
                    Slider(value: $seaState, in: 0...100)
                    Text("\(Int(seaState))")
                        .monospacedDigit()
                        .fixedSize()
                }
                LabeledContent("Time of Day") {
                    Slider(value: $timeOfDay, in: 0...100)
                    Text(timeOfDayLabel)
                        .fixedSize()
                }
                Toggle("Drift", isOn: $drift)
            }
            .formStyle(.grouped)
        }
    }

    private var timeOfDayLabel: String {
        switch timeOfDay / 100 {
        case ..<0.12:
            return "Dusk"
        case ..<0.3:
            return "Golden Hour"
        case ..<0.62:
            return "Afternoon"
        default:
            return "Midday"
        }
    }
}
