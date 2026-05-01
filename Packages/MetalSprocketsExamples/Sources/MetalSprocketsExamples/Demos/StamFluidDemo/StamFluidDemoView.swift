import DemoKit
import MetalSprocketsUI
import SwiftUI

/// Interactive 2D fluid simulation based on Jos Stam's "Real-Time Fluid Dynamics for Games" (GDC 2003).
/// Drag to inject density and apply forces. The fluid follows the Navier-Stokes equations.
public struct StamFluidDemoView: View {
    @State private var isRunning = true
    @State private var visualization: Visualization = .density
    @State private var diffusion: Float = 0.0001
    @State private var viscosity: Float = 0.0
    @State private var gridN: Int = 128
    @State private var colormap: Colormap = .fire

    // Interaction state
    @State private var interactionPoint: SIMD2<Float>?
    @State private var interactionVelocity: SIMD2<Float>?
    @State private var interactionActive = false
    @State private var lastDragLocation: CGPoint?

    public init() {
    }

    public var body: some View {
        GeometryReader { geometry in
            RenderView { _, _ in
                StamFluid(gridN: gridN, diffusion: diffusion, viscosity: viscosity, isRunning: isRunning, visualization: visualization, interactionPoint: interactionPoint, interactionVelocity: interactionVelocity, interactionActive: interactionActive, colormap: colormap)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let size = geometry.size
                        let nx = Float(value.location.x / size.width)
                        let ny = Float(value.location.y / size.height)
                        interactionPoint = SIMD2<Float>(min(max(nx, 0), 1), min(max(ny, 0), 1))

                        if let last = lastDragLocation {
                            let dx = Float((value.location.x - last.x) / size.width)
                            let dy = Float((value.location.y - last.y) / size.height)
                            interactionVelocity = SIMD2<Float>(dx, dy)
                        } else {
                            interactionVelocity = SIMD2<Float>(0, 0)
                        }
                        lastDragLocation = value.location
                        interactionActive = true
                    }
                    .onEnded { _ in
                        interactionActive = false
                        lastDragLocation = nil
                    }
            )
        }
        .demoConfiguration {
            Form {
                Toggle("Animate", isOn: $isRunning)

                Section("Visualization") {
                    Picker("Field", selection: $visualization) {
                        ForEach(Visualization.allCases) { vis in
                            Text(vis.rawValue).tag(vis)
                        }
                    }
                }

                Section("Parameters") {
                    LabeledContent("Diffusion \(diffusion, specifier: "%.4f")") {
                        Slider(value: $diffusion, in: 0...0.01)
                    }
                    LabeledContent("Viscosity \(viscosity, specifier: "%.4f")") {
                        Slider(value: $viscosity, in: 0...0.01)
                    }
                }

                Section("Colors") {
                    Picker("Colormap", selection: $colormap) {
                        ForEach(Colormap.allCases) { map in
                            Text(map.rawValue).tag(map)
                        }
                    }
                }

                Section("Grid") {
                    Picker("Resolution", selection: $gridN) {
                        Text("64").tag(64)
                        Text("128").tag(128)
                        Text("256").tag(256)
                        Text("512").tag(512)
                        Text("1024").tag(1_024)
                        Text("2048").tag(2_048)
                        Text("4096").tag(4_096)
                    }
                }

                Section {
                    Text("Drag to inject smoke and apply forces")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
    }
}
