import DemoKit
import Metal
import MetalSprockets
import MetalSprocketsSupport
import MetalSprocketsUI
import simd
import SwiftUI

/// 2001-style slit-scan "Stargate" effect, ported from the StargateEffect app.
/// Five shader variants evolve the look from a radial tunnel to the organic
/// vertical-vanishing-line shot from the film.
public struct StargateDemoView: View {
    @State private var isPaused = false
    @State private var pausedTime: Float = 0
    @State private var features: StargateFeatures = .all
    @State private var version: StargateVersion = .v5

    /// Most recent live frame time, so pausing freezes at the current frame.
    @State private var latestFrameTime: Float = 0

    public init() {
    }

    public var body: some View {
        RenderView { context, size in
            let time: Float = isPaused ? pausedTime : context.frameUniforms.time
            let resolution = SIMD2<Float>(Float(size.width), Float(size.height))
            try RenderPass {
                try StargateRenderPipeline(version: version, time: time, resolution: resolution, features: features)
            }
            .onWorkloadEnter { _ in
                if !isPaused {
                    latestFrameTime = context.frameUniforms.time
                }
            }
        }
        .background(.black)
        .demoConfiguration {
            Form {
                Section("Version") {
                    Picker("Version", selection: $version) {
                        ForEach(StargateVersion.allCases) { version in
                            Text(version.rawValue).tag(version)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section("Playback") {
                    Toggle("Pause", isOn: $isPaused)
                    if isPaused {
                        Button("Step Frame") {
                            pausedTime += 1.0 / 60.0
                        }
                    }
                }
                Section("Streak Layer") {
                    toggle("Streaks", .streaks)
                    toggle("Color Palette", .colorPalette)
                    toggle("Radial Bands", .radialBands)
                    toggle("Slice Fade", .sliceFade)
                }
                Section("Tunnel") {
                    toggle("Tunnel Grid", .tunnelGrid)
                }
                Section("Framing") {
                    toggle("Hot Core", .core)
                    toggle("Vignette", .vignette)
                }
                Section("Film") {
                    toggle("Flicker", .flicker)
                    toggle("Film Tone Curve", .filmTone)
                }
                Section {
                    Button("Enable All") {
                        features = .all
                    }
                    Button("Disable All") {
                        features = []
                    }
                }
            }
            .formStyle(.grouped)
        }
        .onChange(of: isPaused) {
            if isPaused {
                pausedTime = latestFrameTime
            }
        }
    }

    private func toggle(_ title: String, _ feature: StargateFeatures) -> some View {
        Toggle(title, isOn: Binding(
            get: { features.contains(feature) },
            set: { isOn in
                if isOn {
                    features.insert(feature)
                } else {
                    features.remove(feature)
                }
            }
        ))
    }
}

enum StargateVersion: String, CaseIterable, Identifiable, Sendable {
    case v1 = "V1 - Radial"
    case v2 = "V2 - Vertical Line"
    case v3 = "V3 - Tunnel"
    case v4 = "V4 - Diverging"
    case v5 = "V5 - Organic"

    var id: String { rawValue }

    var fragmentFunctionName: String {
        switch self {
        case .v1: "stargateFragment_v1"
        case .v2: "stargateFragment_v2"
        case .v3: "stargateFragment_v3"
        case .v4: "stargateFragment_v4"
        case .v5: "stargateFragment_v5"
        }
    }
}

// Must match the FEATURE_* bit flags in StargateShaders.metal.
struct StargateFeatures: OptionSet, Hashable, Sendable {
    let rawValue: UInt32

    static let streaks = StargateFeatures(rawValue: 1 << 0)
    static let sliceFade = StargateFeatures(rawValue: 1 << 1)
    static let radialBands = StargateFeatures(rawValue: 1 << 2)
    static let core = StargateFeatures(rawValue: 1 << 3)
    static let vignette = StargateFeatures(rawValue: 1 << 4)
    static let flicker = StargateFeatures(rawValue: 1 << 5)
    static let filmTone = StargateFeatures(rawValue: 1 << 6)
    static let colorPalette = StargateFeatures(rawValue: 1 << 7)
    static let tunnelGrid = StargateFeatures(rawValue: 1 << 8)

    static let all: StargateFeatures = [.streaks, .sliceFade, .radialBands, .core, .vignette, .flicker, .filmTone, .colorPalette, .tunnelGrid]
}

/// Full-screen slit-scan effect. No geometry - the vertex shader emits a
/// single oversized triangle covering the viewport and the fragment shader
/// does all the work. All five versions share the vertex shader and uniform
/// bindings; only the fragment function differs.
struct StargateRenderPipeline: Element {
    let time: Float
    let resolution: SIMD2<Float>
    let features: StargateFeatures

    @MSState
    private var vertexShader: VertexShader

    @MSState
    private var fragmentShader: FragmentShader

    init(version: StargateVersion, time: Float, resolution: SIMD2<Float>, features: StargateFeatures) throws {
        self.time = time
        self.resolution = resolution
        self.features = features
        let shaders = try ShaderNamespace.examples("Stargate")
        vertexShader = try shaders.stargateVertex
        fragmentShader = try shaders.function(named: version.fragmentFunctionName, type: FragmentShader.self)
    }

    var body: some Element {
        get throws {
            try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                Draw { encoder in
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                }
                .parameter("time", value: time)
                .parameter("resolution", value: resolution)
                .parameter("features", value: features.rawValue)
            }
            .depthCompare(function: .always, enabled: false)
        }
    }
}
