import DemoKit
import MetalSprockets
import MetalSprocketsUI
import simd
import SwiftUI

/// Apple-style "liquid glass" pills refracting an animated background.
/// Drag pills around; they merge like liquid when they touch.
public struct LiquidGlassDemoView: View {
    @State private var parameters = GlassParameters()
    @State private var draggedIndex: Int?

    public init() {
    }

    public var body: some View {
        GeometryReader { proxy in
            RenderView { context, size in
                try RenderPass {
                    try LiquidGlassPipeline(
                        parameters: parameters,
                        time: context.frameUniforms.time,
                        resolution: SIMD2<Float>(Float(size.width), Float(size.height))
                    )
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let location = SIMD2<Float>(
                            Float(value.location.x / max(proxy.size.width, 1)),
                            Float(value.location.y / max(proxy.size.height, 1))
                        )
                        if draggedIndex == nil {
                            draggedIndex = nearestPillIndex(to: location, viewSize: proxy.size)
                        }
                        if let index = draggedIndex {
                            parameters.pills[index].center = location
                        }
                    }
                    .onEnded { _ in
                        draggedIndex = nil
                    }
            )
        }
        .demoConfiguration {
            Form {
                LabeledContent("IOR") {
                    Slider(value: $parameters.ior, in: 1.0...1.8)
                    Text(parameters.ior.formatted(.number.precision(.fractionLength(2))))
                        .monospacedDigit()
                }
                LabeledContent("Dispersion") {
                    Slider(value: $parameters.dispersion, in: 0...0.15)
                    Text(parameters.dispersion.formatted(.number.precision(.fractionLength(2))))
                        .monospacedDigit()
                }
                LabeledContent("Bevel") {
                    Slider(value: $parameters.bevel, in: 0.01...0.13)
                    Text(parameters.bevel.formatted(.number.precision(.fractionLength(2))))
                        .monospacedDigit()
                }
                LabeledContent("Frost") {
                    Slider(value: $parameters.frost, in: 0...12)
                    Text(parameters.frost.formatted(.number.precision(.fractionLength(1))))
                        .monospacedDigit()
                }
                LabeledContent("Blend") {
                    Slider(value: $parameters.blend, in: 0.001...0.15)
                    Text(parameters.blend.formatted(.number.precision(.fractionLength(2))))
                        .monospacedDigit()
                }
                LabeledContent("Pills") {
                    HStack {
                        Button("−") {
                            if parameters.pills.count > 1 {
                                parameters.pills.removeLast()
                            }
                        }
                        .disabled(parameters.pills.count <= 1)
                        Button("+") {
                            addPill()
                        }
                        .disabled(parameters.pills.count >= GlassParameters.maxPills)
                    }
                    Text("\(parameters.pills.count)")
                        .monospacedDigit()
                }
            }
            .formStyle(.grouped)
        }
    }

    private func nearestPillIndex(to location: SIMD2<Float>, viewSize: CGSize) -> Int? {
        let aspect = SIMD2<Float>(Float(viewSize.width / max(viewSize.height, 1)), 1)
        return parameters.pills.indices.min { a, b in
            let da = (parameters.pills[a].center - location) * aspect
            let db = (parameters.pills[b].center - location) * aspect
            return simd_length_squared(da) < simd_length_squared(db)
        }
    }

    private func addPill() {
        guard parameters.pills.count < GlassParameters.maxPills else {
            return
        }
        let pill = Pill(
            center: [Float.random(in: 0.2...0.8), Float.random(in: 0.2...0.8)],
            halfSize: [Float.random(in: 0.08...0.24), Float.random(in: 0.07...0.13)]
        )
        parameters.pills.append(pill)
    }
}
