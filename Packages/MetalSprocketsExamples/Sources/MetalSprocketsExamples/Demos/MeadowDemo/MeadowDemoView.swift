import DemoKit
import Metal
import MetalSprockets
import MetalSprocketsAddOns
import MetalSprocketsUI
import simd
import SwiftUI

public struct MeadowDemoView: View {
    @State private var resources: MeadowResources?
    @State private var errorMessage: String?
    @State private var camera = MeadowCamera()
    @State private var settings = MeadowSettings()
    @State private var frameIndex: UInt32 = 0
    @State private var sampleCount: UInt32 = 0
    @State private var animatesClouds = false
    @State private var dragStart: CGSize?

    private let renderSize = MTLSize(width: 1_280, height: 720, depth: 1)

    public init() {
        // This line intentionally left blank.
    }

    public var body: some View {
        ZStack {
            Color.black
            if let resources, resources.outputTexture != nil {
                RenderView { _, _ in
                    try Group {
                        try resources.traceElement(camera: camera, settings: settings, frameIndex: frameIndex, sampleCount: sampleCount)
                            .onSubmissionCommitted { _ in
                                frameIndex &+= 1
                                sampleCount = min(sampleCount + 1, 4_095)
                                if animatesClouds {
                                    settings.cloudTime += 1 / 60
                                }
                            }
                        if let outputTexture = resources.outputTexture {
                            try RenderPass {
                                try TextureBillboardPipeline(specifier: .texture2D(outputTexture))
                            }
                        }
                    }
                    .useResourceCollection(resources.resourceCollection)
                }
                .aspectRatio(CGFloat(renderSize.width) / CGFloat(renderSize.height), contentMode: .fit)
                .gesture(lookGesture)
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(.white)
            } else {
                ProgressView("Growing the meadow…").foregroundStyle(.white)
            }
        }
        .focusable()
        .onKeyPress(characters: .init(charactersIn: "wasdr")) { press in
            walk(press.characters)
            return .handled
        }
        .task {
            do {
                let resources = try await MeadowResources.make()
                try resources.ensureTextures(size: renderSize)
                self.resources = resources
            } catch {
                errorMessage = "Meadow setup failed: \(error)"
            }
        }
        .onChange(of: camera) { sampleCount = 0 }
        .onChange(of: settings) { sampleCount = 0 }
        .demoConfiguration {
            configuration
        }
    }

    private var lookGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let previous = dragStart ?? .zero
                let delta = CGSize(width: value.translation.width - previous.width, height: value.translation.height - previous.height)
                dragStart = value.translation
                camera.look(horizontal: Float(delta.width) * 0.004, vertical: -Float(delta.height) * 0.004)
            }
            .onEnded { _ in dragStart = nil }
    }

    private func walk(_ characters: String) {
        switch characters {
        case "w": camera.walk(forward: 0.5, sideways: 0)
        case "s": camera.walk(forward: -0.5, sideways: 0)
        case "a": camera.walk(forward: 0, sideways: -0.5)
        case "d": camera.walk(forward: 0, sideways: 0.5)
        case "r": camera = MeadowCamera()
        default: break
        }
    }

    private var configuration: some View {
        Form {
            Section("Sunlight") {
                Slider(value: $settings.sunElevation, in: 0.08...1.3) { Text("Elevation") }
                Slider(value: $settings.sunAzimuth, in: -.pi ... .pi) { Text("Direction") }
                Slider(value: $settings.exposure, in: 0.4...2.5) { Text("Exposure") }
            }
            Section("Atmosphere") {
                Slider(value: $settings.haze, in: 0...0.025) { Text("Haze") }
                Slider(value: $settings.cloudCoverage, in: 0...1) { Text("Cloud Cover") }
                Toggle("Drifting Clouds", isOn: $animatesClouds)
            }
            Section("Rendering") {
                LabeledContent("Samples", value: sampleCount.formatted())
                if let resources {
                    LabeledContent("Triangles", value: resources.triangleCount.formatted())
                }
                Text("Drag to look · WASD to walk · R to reset")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
