import GeometryLite3D
import Interaction3D
import Metal
import MetalKit
import MetalSprockets
import MetalSprocketsAddOns
import MetalSprocketsAddOnsShaders
import MetalSprocketsSupport
import MetalSprocketsUI
import simd
import SwiftUI

// MARK: - RayTracedShadowDemoView

/// Demonstrates ray-traced shadows using Metal ray tracing APIs.
/// Casts shadow rays from scene surfaces toward the light against an
/// acceleration structure built from the scene geometry.
public struct RayTracedShadowDemoView: View {
    public init() { }
    struct Model: Identifiable {
        var id: String
        var mesh: MTKMesh
        var modelMatrix: float4x4
        var material: BlinnPhongMaterial
    }

    // Camera
    @State private var cameraRotation = simd_quatf(angle: -.pi / 6, axis: [1, 0, 0])
    @State private var cameraDistance: Float = 14
    @State private var cameraTarget: SIMD3<Float> = [0, 1, 0]

    @State private var lighting: Lighting?
    @State private var accelManager: AccelerationStructureManager?
    @State private var lightPositions: [SIMD3<Float>] = Array(repeating: .zero, count: lightCount)
    @State private var renderOptions: RayTracedShadowDemoRenderPass.Options = .all
    @State private var showInspector = true

    @State private var shadowDebug: Bool = false
    @State private var shadowIntensity: Float = 1.0
    @State private var ambientLight: Float = 0.4
    @State private var lightIntensity: Float = 200
    @State private var paused: Bool = false
    @State private var startDate: Date?

    static let lightCount = 2
    static let lightColors: [SIMD3<Float>] = [
        [1, 0.9, 0.8],  // warm white
        [0.8, 0.9, 1]   // cool white
    ]

    private var cameraMatrix: simd_float4x4 {
        let rotation = float4x4(cameraRotation)
        let translation = float4x4.translation(cameraTarget.x, cameraTarget.y, cameraTarget.z)
        let distance = float4x4.translation(0, 0, cameraDistance)
        return translation * rotation * distance
    }

    // Scene geometry: two teapots + a ground plane
    private let teapots: [Model] = [
        .init(
            id: "teapot-1",
            mesh: MTKMesh.teapot().relabeled("teapot"),
            modelMatrix: .init(translation: [-2.5, 0, 0]),
            material: BlinnPhongMaterial(
                ambient: .color([0.1, 0.05, 0.05]),
                diffuse: .color([0.7, 0.25, 0.25]),
                specular: .color([0.8, 0.8, 0.8]),
                shininess: 64
            )
        ),
        .init(
            id: "teapot-2",
            mesh: MTKMesh.teapot().relabeled("teapot"),
            modelMatrix: .init(translation: [2.5, 0, 0]),
            material: BlinnPhongMaterial(
                ambient: .color([0.05, 0.05, 0.1]),
                diffuse: .color([0.25, 0.25, 0.7]),
                specular: .color([0.8, 0.8, 0.8]),
                shininess: 64
            )
        )
    ]

    // Ground plane
    private let groundMesh = MTKMesh.plane(width: 20, height: 20).relabeled("ground")

    private let groundModelMatrix: float4x4 = .init(simd_quatf(angle: .pi / 2, axis: [1, 0, 0]))

    @State private var groundColor: Color = .gray

    private var groundMaterial: BlinnPhongMaterial {
        let resolved = groundColor.resolve(in: .init())
        let rgb = SIMD3<Float>(Float(resolved.linearRed), Float(resolved.linearGreen), Float(resolved.linearBlue))
        return BlinnPhongMaterial(
            ambient: .color(rgb * 0.4),
            diffuse: .color(rgb),
            specular: .color([0.2, 0.2, 0.2]),
            shininess: 16
        )
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            RenderView { _, drawableSize in
                if let lighting, let accelManager {
                    let aspect = drawableSize.height > 0 ? Float(drawableSize.width / drawableSize.height) : 1.0
                    let projectionMatrix = float4x4.perspective(fovY: .pi / 4, aspect: aspect, near: 0.1, far: 1_000.0)

                    RayTracedShadowDemoRenderPass(
                        projectionMatrix: projectionMatrix,
                        cameraMatrix: cameraMatrix,
                        drawableSize: drawableSize,
                        lighting: lighting,
                        lightPositions: lightPositions,
                        lightColors: Self.lightColors,
                        accelerationStructureManager: accelManager,
                        teapots: teapots,
                        groundMesh: groundMesh,
                        groundModelMatrix: groundModelMatrix,
                        groundMaterial: groundMaterial,
                        options: renderOptions,
                        shadowDebug: shadowDebug,
                        shadowIntensity: shadowIntensity
                    )
                }
            }
            .id("\(shadowDebug)")
            .metalFramebufferOnly(false)
            .metalDepthStencilPixelFormat(.depth32Float)
            .metalDepthStencilAttachmentTextureUsage([.renderTarget, .shaderRead])
            .metalClearColor(MTLClearColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1))
            .onChange(of: timeline.date) {
                if startDate == nil {
                    startDate = timeline.date
                }
                if !paused {
                    let time = Float(timeline.date.timeIntervalSince(startDate ?? timeline.date))
                    for i in 0..<Self.lightCount {
                        let fi = Float(i)
                        let speed: Float = 0.5 + fi * 0.3
                        let radius: Float = 6 + fi * 2
                        let height: Float = 4 + fi * 2
                        let angle = time * speed + fi * .pi
                        let pos = SIMD3<Float>(
                            cos(angle) * radius,
                            height,
                            sin(angle) * radius
                        )
                        lighting?.setLightPosition(pos, at: i)
                    }
                    // Update tracked positions for markers
                    if let lighting {
                        let ptr = lighting.lightPositions.contents()
                            .assumingMemoryBound(to: SIMD3<Float>.self)
                        lightPositions = (0..<Self.lightCount).map { ptr[$0] }
                    }
                }
            }
        }
        .onChange(of: ambientLight) {
            lighting?.ambientLightColor = [ambientLight, ambientLight, ambientLight]
        }
        .onChange(of: lightIntensity) {
            for i in 0..<Self.lightCount {
                lighting?.setLight(
                    Light(type: .point, color: Self.lightColors[i], intensity: lightIntensity),
                    at: i
                )
            }
        }
        .interactiveCamera(rotation: $cameraRotation, distance: $cameraDistance, target: $cameraTarget)
        .frameTimingOverlay()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showInspector.toggle() } label: {
                    Label("Inspector", systemImage: "sidebar.trailing")
                }
            }
        }
        .inspector(isPresented: $showInspector) {
            Form {
                Section("Pipelines") {
                    Toggle("Grid", isOn: $renderOptions.bound(.grid))
                    Toggle("Light Marker", isOn: $renderOptions.bound(.lightMarker))
                    Toggle("Models", isOn: $renderOptions.bound(.models))
                    Toggle("Shadows", isOn: $renderOptions.bound(.shadows))
                    Toggle("Pause", isOn: $paused)
                }
                Section("Ground") {
                    ColorPicker("Color", selection: $groundColor)
                }
                Section("Lighting") {
                    HStack {
                        Text("Ambient")
                        Slider(value: $ambientLight, in: 0...1)
                    }
                    Text(String(format: "%.2f", ambientLight))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("Intensity")
                        Slider(value: $lightIntensity, in: 1...1_000)
                    }
                    Text(String(format: "%.0f", lightIntensity))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Section("Ray Traced Shadows") {
                    HStack {
                        Text("Intensity")
                        Slider(value: $shadowIntensity, in: 0...1)
                    }
                    Text(String(format: "%.2f", shadowIntensity))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Toggle("Debug", isOn: $shadowDebug)
                }
            }
            .inspectorColumnWidth(min: 250, ideal: 300, max: 400)
        }
        .task {
            do {
                let lightData: [(SIMD3<Float>, Light)] = (0..<Self.lightCount).map { i in
                    let fi = Float(i)
                    let angle = fi * (.pi * 2 / Float(Self.lightCount))
                    let radius: Float = 5 + fi * 0.3
                    let height: Float = 3 + sin(fi * 1.3) * 2
                    let pos = SIMD3<Float>(cos(angle) * radius, height, sin(angle) * radius)
                    let color = Self.lightColors[i]
                    return (pos, Light(type: .point, color: color, intensity: lightIntensity))
                }
                lighting = try Lighting(
                    ambientLightColor: [ambientLight, ambientLight, ambientLight],
                    lights: lightData
                )

                // Build acceleration structures from scene geometry
                var manager = try AccelerationStructureManager()
                // Use both teapot meshes (they're the same mesh) + ground
                let uniqueMeshes = [teapots[0].mesh, groundMesh]
                var instances: [AccelerationStructureManager.Instance] = []
                for teapot in teapots {
                    instances.append(.init(meshIndex: 0, transform: teapot.modelMatrix))
                }
                instances.append(.init(meshIndex: 1, transform: groundModelMatrix))
                try manager.build(meshes: uniqueMeshes, instances: instances)
                accelManager = manager
            } catch {
                fatalError("Failed to initialize Ray Traced Shadow demo: \(error)")
            }
        }
    }
}

// MARK: - RayTracedShadowDemoRenderPass

struct RayTracedShadowDemoRenderPass: Element {
    struct Options: OptionSet {
        let rawValue: Int
        static let grid = Self(rawValue: 1 << 1)
        static let lightMarker = Self(rawValue: 1 << 2)
        static let models = Self(rawValue: 1 << 3)
        static let shadows = Self(rawValue: 1 << 4)
        static let all: Self = [.lightMarker, .models, .shadows]
    }

    var projectionMatrix: simd_float4x4
    var cameraMatrix: simd_float4x4
    var drawableSize: CGSize
    var lighting: Lighting
    var lightPositions: [SIMD3<Float>]
    var lightColors: [SIMD3<Float>]
    var accelerationStructureManager: AccelerationStructureManager
    var teapots: [RayTracedShadowDemoView.Model]
    var groundMesh: MTKMesh
    var groundModelMatrix: simd_float4x4
    var groundMaterial: BlinnPhongMaterial
    var options: Options = .all
    var shadowDebug: Bool = false
    var shadowIntensity: Float = 1.0

    @MSEnvironment(\.renderPassDescriptor)
    var renderPassDescriptor

    @MSEnvironment(\.currentDrawable)
    var currentDrawable

    var body: some Element {
        get throws {
            let shadowsEnabled = options.contains(.shadows)

            // Pass 1: Main scene render pass
            try RenderPass(label: "Main Scene") {
                let viewMatrix = cameraMatrix.inverse
                let viewProjection = projectionMatrix * viewMatrix

                // Grid
                if options.contains(.grid) {
                    GridShader(
                        projectionMatrix: projectionMatrix,
                        cameraMatrix: cameraMatrix,
                        highlightedLines: [
                            .init(axis: .x, position: 0, width: 0.03, color: [1, 0.2, 0.2, 1]),
                            .init(axis: .y, position: 0, width: 0.03, color: [0.2, 0.4, 1, 1])
                        ],
                        backfaceColor: [1, 0, 1, 1]
                    )
                }

                // Light markers
                if options.contains(.lightMarker) {
                    let positions = lightPositions
                    let colors = lightColors
                    let lightMarker = GraphicsContext3D { ctx in
                        let s: Float = 0.3
                        for (pos, rgb) in zip(positions, colors) {
                            let color = Color(
                                red: Double(rgb.x),
                                green: Double(rgb.y),
                                blue: Double(rgb.z)
                            )
                            for axis in [SIMD3<Float>(1, 0, 0), SIMD3<Float>(0, 1, 0), SIMD3<Float>(0, 0, 1)] {
                                ctx.stroke(
                                    Path3D { path in
                                        path.move(to: pos - axis * s)
                                        path.addLine(to: pos + axis * s)
                                    },
                                    with: color,
                                    lineWidth: 2
                                )
                            }
                        }
                    }
                    let viewport = SIMD2<Float>(Float(drawableSize.width), Float(drawableSize.height))
                    GraphicsContext3DRenderPipeline(
                        context: lightMarker,
                        viewProjection: viewProjection,
                        viewport: viewport
                    )
                }

                // Lit models (teapots + ground) — no shadow awareness needed
                if options.contains(.models), let firstTeapot = teapots.first {
                    let viewMatrix = cameraMatrix.inverse
                    try BlinnPhongShader {
                        try Group {
                            // Teapots
                            try ForEach(teapots) { model in
                                try Draw { encoder in
                                    encoder.setVertexBuffers(of: model.mesh)
                                    encoder.draw(model.mesh)
                                }
                                .blinnPhongMaterial(model.material)
                                .blinnPhongMatrices(
                                    projectionMatrix: projectionMatrix,
                                    viewMatrix: viewMatrix,
                                    modelMatrix: model.modelMatrix,
                                    cameraMatrix: cameraMatrix
                                )
                            }

                            // Ground plane
                            try Draw { encoder in
                                encoder.setVertexBuffers(of: groundMesh)
                                encoder.draw(groundMesh)
                            }
                            .blinnPhongMaterial(groundMaterial)
                            .blinnPhongMatrices(
                                projectionMatrix: projectionMatrix,
                                viewMatrix: viewMatrix,
                                modelMatrix: groundModelMatrix,
                                cameraMatrix: cameraMatrix
                            )
                        }
                        .lighting(lighting)
                    }
                    .vertexDescriptor(firstTeapot.mesh.vertexDescriptor)
                    .depthCompare(function: .less, enabled: true)
                }
            }
            .renderPassDescriptorModifier { descriptor in
                // Ensure depth is stored so shadow mask pass can read it
                descriptor.depthAttachment.storeAction = .store
            }

            // Pass 2: Ray-traced shadow compute pass
            if shadowsEnabled,
                let sceneDepthTexture = renderPassDescriptor?.depthAttachment.texture,
                let outputTexture = currentDrawable?.texture {
                let viewMatrix = cameraMatrix.inverse
                let viewProjection = projectionMatrix * viewMatrix
                let inverseVP = viewProjection.inverse

                try RayTracedShadowComputePass(
                    sceneDepthTexture: sceneDepthTexture,
                    outputTexture: outputTexture,
                    accelerationStructureManager: accelerationStructureManager,
                    lighting: lighting,
                    inverseViewProjection: inverseVP,
                    shadowIntensity: shadowIntensity,
                    debug: shadowDebug
                )
            }
        }
    }
}

