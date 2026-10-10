import AsyncAlgorithms
import DemoKit
import MetalSprocketsUI
import MetalSupport
import SwiftUI

/// 3D PIC/FLIP fluid in a tank, ported from the MetalFLIP app.
/// Drag to orbit, pinch to zoom.
public struct MetalFLIPDemoView: View {
    @State private var simulation: FLIPSimulation?
    @State private var errorMessage: String?
    @State private var resolution = 24
    @State private var scene: FLIPScene = .damBreak
    @State private var settings = FLIPSettings()
    @State private var camera = FLIPOrbitCamera()
    @State private var isRunning = true
    @State private var showsParticles = false
    @State private var resetGeneration = 0
    @State private var statistics = FLIPStatistics()
    @State private var dragOrigin: FLIPOrbitCamera?
    @State private var zoomOrigin: Float?

    public init() {
        // This line intentionally left blank.
    }

    public var body: some View {
        ZStack {
            Color.black
            if let simulation {
                viewport(simulation: simulation)
            } else if let errorMessage {
                ContentUnavailableView("FLIP unavailable", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            }
        }
        .task(id: resolution) {
            do {
                simulation = try FLIPSimulation(device: _MTLCreateSystemDefaultDevice(), resolution: resolution)
                errorMessage = nil
            } catch {
                simulation = nil
                errorMessage = error.localizedDescription
            }
        }
        .demoConfiguration {
            configuration
        }
    }

    private func viewport(simulation: FLIPSimulation) -> some View {
        RenderView(colorPixelFormat: .bgra8Unorm_srgb, depthStencilPixelFormat: .depth32Float) { _, size in
            FLIPFrame(
                simulation: simulation,
                scene: scene,
                resetGeneration: resetGeneration,
                isRunning: isRunning,
                settings: settings,
                camera: camera,
                showsParticles: showsParticles,
                viewportSize: SIMD2(Float(size.width), Float(size.height))
            )
        }
        .gesture(orbitGesture)
        .simultaneousGesture(zoomGesture)
        .accessibilityLabel("Three-dimensional fluid simulation")
        .accessibilityHint("Drag to orbit. Pinch to zoom.")
        .overlay(alignment: .bottomLeading) {
            statisticsOverlay
                .padding()
                .allowsHitTesting(false)
        }
        .task(id: ObjectIdentifier(simulation)) {
            for await _ in AsyncTimerSequence(interval: .milliseconds(250), clock: .continuous) {
                statistics = simulation.statistics
            }
        }
    }

    private var orbitGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let origin = dragOrigin ?? camera
                dragOrigin = origin
                camera.azimuth = (origin.azimuth - Float(value.translation.width) * 0.008).remainder(dividingBy: .pi * 2)
                camera.elevation = (origin.elevation + Float(value.translation.height) * 0.008).clamped(to: FLIPOrbitCamera.elevationRange)
            }
            .onEnded { _ in dragOrigin = nil }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let origin = zoomOrigin ?? camera.distance
                zoomOrigin = origin
                camera.distance = (origin / Float(value.magnification)).clamped(to: FLIPOrbitCamera.distanceRange)
            }
            .onEnded { _ in zoomOrigin = nil }
    }

    private var statisticsOverlay: some View {
        VStack(alignment: .leading) {
            Text("PIC / FLIP · \(resolution)³ MAC grid")
                .font(.headline)
            Text("\(statistics.particleCount.formatted()) particles · \(statistics.simulatedTime.formatted(.number.precision(.fractionLength(2)))) s")
            Text("Δt \((statistics.timeStep * 1_000).formatted(.number.precision(.fractionLength(2)))) ms · max speed \(statistics.maximumSpeed.formatted(.number.precision(.fractionLength(2)))) m/s")
                .foregroundStyle(.secondary)
        }
        .font(.caption.monospacedDigit())
        .padding()
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
    }

    private var configuration: some View {
        Form {
            Section("Scene") {
                Picker("Initial state", selection: $scene) {
                    ForEach(FLIPScene.allCases) { scene in
                        Text(scene.title).tag(scene)
                    }
                }
                .onChange(of: scene) { resetGeneration += 1 }
                Toggle("Running", isOn: $isRunning)
                Toggle("Show particles", isOn: $showsParticles)
                Button("Reset", systemImage: "arrow.counterclockwise") { resetGeneration += 1 }
            }
            Section("Solver") {
                Picker("Grid", selection: $resolution) {
                    ForEach([16, 24, 32, 48], id: \.self) { value in
                        Text("\(value)³").tag(value)
                    }
                }
                LabeledContent("FLIP blend \(settings.flipRatio.formatted(.percent.precision(.fractionLength(0))))") {
                    Slider(value: $settings.flipRatio, in: 0...1)
                        .accessibilityLabel("FLIP blend")
                }
                LabeledContent("Gravity \(settings.gravity.formatted(.number.precision(.fractionLength(1)))) m/s²") {
                    Slider(value: $settings.gravity, in: 0...20)
                        .accessibilityLabel("Gravity")
                }
                Stepper("Pressure sweeps: \(settings.pressureIterations)", value: $settings.pressureIterations, in: 10...120, step: 10)
                LabeledContent("Time scale \(settings.timeScale.formatted(.number.precision(.fractionLength(2))))") {
                    Slider(value: $settings.timeScale, in: 0.1...2)
                        .accessibilityLabel("Time scale")
                }
            }
            Section("Camera") {
                LabeledContent("Orbit") {
                    Slider(value: $camera.azimuth, in: -Float.pi...Float.pi)
                        .accessibilityLabel("Orbit")
                }
                LabeledContent("Elevation") {
                    Slider(value: $camera.elevation, in: FLIPOrbitCamera.elevationRange)
                        .accessibilityLabel("Elevation")
                }
                LabeledContent("Distance") {
                    Slider(value: $camera.distance, in: FLIPOrbitCamera.distanceRange)
                        .accessibilityLabel("Distance")
                }
                Button("Reset camera", systemImage: "viewfinder") { camera = FLIPOrbitCamera() }
            }
            Section {
                Text("Based on \"Fluid Implicit Particle Simulation for CPU and GPU\" (Centeno & Pereira, 2024). Red-black Gauss–Seidel pressure projection and a ray-marched Zhu–Bridson surface.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
