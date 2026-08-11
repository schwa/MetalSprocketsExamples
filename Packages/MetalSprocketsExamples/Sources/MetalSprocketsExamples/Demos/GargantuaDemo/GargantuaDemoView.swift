#if canImport(MetalFX)
import DemoKit
import MetalSprockets
import MetalSprocketsUI
import SwiftUI

/// Schwarzschild black hole renderer ("Gargantua"), ported from a standalone
/// MTKView app to MetalSprockets elements.
public struct GargantuaDemoView: View {
    @State private var params = GargantuaParams()
    @State private var quality: GargantuaQuality = .cinematic
    @State private var cineMode = true
    @State private var autoRotate = false
    @State private var simulation = GargantuaSimulation()

    @State private var lastTranslation: CGSize = .zero
    @State private var lastMagnification: CGFloat = 1

    public init() {
    }

    public var body: some View {
        GeometryReader { proxy in
            RenderView { context, size in
                try GargantuaPipeline(
                    params: params,
                    simulation: simulation,
                    time: context.frameUniforms.time,
                    drawableSize: size
                )
            }
            .metalColorPixelFormat(.bgra8Unorm)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let dx = Float(value.translation.width - lastTranslation.width)
                        let dy = Float(value.translation.height - lastTranslation.height)
                        lastTranslation = value.translation
                        simulation.drag(dx: dx, dy: dy, viewHeight: Float(proxy.size.height))
                        cineMode = false
                    }
                    .onEnded { _ in lastTranslation = .zero }
            )
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        let ratio = value.magnification / lastMagnification
                        lastMagnification = value.magnification
                        simulation.zoom(Float(-log(ratio) * 12))
                        cineMode = false
                    }
                    .onEnded { _ in lastMagnification = 1 }
            )
        }
        .demoConfiguration {
            Form {
                Section("Camera") {
                    Toggle("Cinematic Path", isOn: $cineMode)
                    Toggle("Auto-Rotate", isOn: $autoRotate)
                    LabeledContent("Fly To") {
                        HStack {
                            ForEach(GargantuaPreset.allCases) { preset in
                                Button(preset.rawValue.capitalized) {
                                    cineMode = false
                                    simulation.flyTo(preset)
                                }
                            }
                        }
                    }
                }
                Section("Quality") {
                    Picker("Quality", selection: $quality) {
                        ForEach(GargantuaQuality.allCases) { quality in
                            Text(quality.rawValue.capitalized).tag(quality)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Parameters") {
                    ForEach(gargantuaParamDefs) { def in
                        LabeledContent(def.label) {
                            Slider(value: Binding(
                                get: { params[keyPath: def.key] },
                                set: { params[keyPath: def.key] = $0 }
                            ), in: def.range)
                            Text(def.format(params[keyPath: def.key]))
                                .monospacedDigit()
                                .fixedSize()
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .onChange(of: quality, initial: true) {
            params.steps = quality.steps
            params.rayScale = quality.rayScale
        }
        .onChange(of: cineMode) {
            simulation.setCineMode(cineMode)
            if cineMode {
                autoRotate = false
            }
        }
        .onChange(of: autoRotate) {
            if autoRotate {
                cineMode = false
            }
            simulation.autoRotate = autoRotate
        }
    }
}
#endif
