import DemoKit
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

/// Combines four render pipelines (skybox, grid, GraphicsContext3D, Blinn-Phong)
/// with animated lighting driven by Interaction3D's transformer system.
public struct BlinnPhongDemoView: DemoView {
    struct Model: Identifiable {
        var id: String
        var mesh: MTKMesh
        var modelMatrix: float4x4
        var material: BlinnPhongMaterial
    }

    public static let metadata = DemoMetadata(
        name: "Blinn-Phong",
        systemImage: "light.max",
        description: "Blinn-Phong shading with orbiting light, skybox, and grid",
        group: "Rendering"
    )

    // Camera — driven by `.interactiveCamera()` (turntable orbit + zoom + pan)
    @State private var cameraRotation = simd_quatf(angle: -.pi / 6, axis: [1, 0, 0])
    @State private var cameraDistance: Float = 10
    @State private var cameraTarget: SIMD3<Float> = [0, 1, 0]

    @State private var lighting: Lighting?
    @State private var skyboxTexture: MTLTexture?
    @State private var lightPosition0: SIMD3<Float> = [0, 3, 5]
    @State private var lightPosition1: SIMD3<Float> = [0, 1.5, -5]
    @State private var renderOptions: BlinnPhongDemoRenderPass.Options = .all
    @State private var showInspector = true
    @State private var showWireframe = false
    @State private var useDebugShading = false
    @State private var debugMode: DebugShadersMode = .normal

    // Light 0: slow white orbit at height 3
    @State private var lightAnimator0 = TransformerAnimator(
        transformer: OrbitTransformer(center: [0, 3, 0], radius: 5, angle: .zero, normal: [0, 1, 0]),
        parameter: \OrbitTransformer.angle,
        from: AngleF.degrees(0),
        to: AngleF.degrees(360),
        duration: 8,
        timingTransformer: LoopTransformer(duration: 8)
    )

    // Light 1: fast colored orbit at height 1.5, opposite direction
    @State private var lightAnimator1 = TransformerAnimator(
        transformer: OrbitTransformer(center: [0, 1.5, 0], radius: 4, angle: .zero, normal: [0, 1, 0]),
        parameter: \OrbitTransformer.angle,
        from: AngleF.degrees(360),
        to: AngleF.degrees(0),
        duration: 2,
        timingTransformer: LoopTransformer(duration: 2)
    )

    private var cameraMatrix: simd_float4x4 {
        let rotation = float4x4(cameraRotation)
        let translation = float4x4.translation(cameraTarget.x, cameraTarget.y, cameraTarget.z)
        let distance = float4x4.translation(0, 0, cameraDistance)
        return translation * rotation * distance
    }

    // Two teapots with distinct Blinn-Phong materials sharing one render pipeline
    private let models: [Model] = [
        .init(
            id: "teapot-1",
            mesh: MTKMesh.teapot(options: [.generateTangentBasis, .generateTextureCoordinatesIfMissing, .useSimpleTextureCoordinates]).relabeled("teapot"),
            modelMatrix: .init(translation: [-2.5, 0, 0]),
            material: BlinnPhongMaterial(
                ambient: .color([0.1, 0.05, 0.05]),
                diffuse: .color([0.6, 0.2, 0.2]),
                specular: .color([0.8, 0.8, 0.8]),
                shininess: 64
            )
        ),
        .init(
            id: "teapot-2",
            mesh: MTKMesh.teapot(options: [.generateTangentBasis, .generateTextureCoordinatesIfMissing, .useSimpleTextureCoordinates]).relabeled("teapot"),
            modelMatrix: .init(translation: [2.5, 0, 0]),
            material: BlinnPhongMaterial(
                ambient: .color([0.05, 0.05, 0.1]),
                diffuse: .color([0.2, 0.2, 0.6]),
                specular: .color([0.8, 0.8, 0.8]),
                shininess: 64
            )
        )
    ]

    public init() {
    }

    @ViewBuilder
    private var renderView: some View {
        if let lighting, let skyboxTexture {
            RenderView { _, drawableSize in
                let aspect = drawableSize.height > 0 ? Float(drawableSize.width / drawableSize.height) : 1.0
                let projectionMatrix = float4x4.perspective(fovY: .pi / 4, aspect: aspect, near: 0.1, far: 1_000.0)
                BlinnPhongDemoRenderPass(
                    projectionMatrix: projectionMatrix,
                    cameraMatrix: cameraMatrix,
                    drawableSize: drawableSize,
                    skyboxTexture: skyboxTexture,
                    lighting: lighting,
                    lightPositions: [lightPosition0, lightPosition1],
                    models: models,
                    wireframe: showWireframe,
                    debugMode: useDebugShading ? debugMode : nil,
                    options: renderOptions
                )
            }
        }
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            renderView
                .metalDepthStencilPixelFormat(.depth32Float)
                .onChange(of: timeline.date) {
                    let t = timeline.date.timeIntervalSinceReferenceDate

                    // Light 0: white orbit
                    lightAnimator0.update(at: t)
                    lightPosition0 = lightAnimator0.transformer.transform(.zero)
                    lighting?.setLightPosition(lightPosition0, at: 0)

                    // Light 1: colored orbit with hue cycling
                    lightAnimator1.update(at: t)
                    lightPosition1 = lightAnimator1.transformer.transform(.zero)
                    lighting?.setLightPosition(lightPosition1, at: 1)
                    let hue = Float(t.truncatingRemainder(dividingBy: 6) / 6)
                    let color = hueToRGB(hue)
                    lighting?.setLight(Light(type: .point, color: color, intensity: 15), at: 1)
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
                    Toggle("Skybox", isOn: $renderOptions.bound(.skybox))
                    Toggle("Grid", isOn: $renderOptions.bound(.grid))
                    Toggle("Light Marker", isOn: $renderOptions.bound(.lightMarker))
                    Toggle("Models", isOn: $renderOptions.bound(.models))
                }
                Section("Display") {
                    Toggle("Wireframe", isOn: $showWireframe)
                }
                Section("Shading") {
                    Picker("Mode", selection: $useDebugShading) {
                        Text("Blinn-Phong").tag(false)
                        Text("Debug").tag(true)
                    }
                    Picker("Debug Mode", selection: $debugMode) {
                        ForEach(DebugShadersMode.allCases, id: \.self) { mode in
                            Text(mode.description).tag(mode)
                        }
                    }
                    .disabled(!useDebugShading)
                }
            }
            .inspectorColumnWidth(min: 250, ideal: 300, max: 400)
        }
        .task {
            do {
                lighting = try Lighting(
                    ambientLightColor: [0.15, 0.15, 0.2],
                    lights: [
                        ([0, 3, 5], Light(type: .point, color: [1, 1, 1], intensity: 20)),
                        ([0, 1.5, -5], Light(type: .point, color: [1, 0.5, 0.2], intensity: 15))
                    ]
                )
                let device = _MTLCreateSystemDefaultDevice()
                let crossTexture = try device.makeTexture(name: "Skybox", bundle: .main)
                skyboxTexture = try device.makeTextureCubeFromCrossTexture(texture: crossTexture)
            } catch {
                fatalError("Failed to initialize BlinnPhong demo: \(error)")
            }
        }
    }
}

/// Composable render pass combining skybox, grid, light marker, and Blinn-Phong lit geometry.
struct BlinnPhongDemoRenderPass: Element {
    struct Options: OptionSet {
        let rawValue: Int
        static let skybox = Self(rawValue: 1 << 0)
        static let grid = Self(rawValue: 1 << 1)
        static let lightMarker = Self(rawValue: 1 << 2)
        static let models = Self(rawValue: 1 << 3)
        static let all: Self = [.skybox, .grid, .lightMarker, .models]
    }

    var projectionMatrix: simd_float4x4
    var cameraMatrix: simd_float4x4
    var drawableSize: CGSize
    var skyboxTexture: MTLTexture
    var lighting: Lighting
    var lightPositions: [SIMD3<Float>]
    var models: [BlinnPhongDemoView.Model]
    var wireframe: Bool = false
    var debugMode: DebugShadersMode?
    var options: Options = .all

    var body: some Element {
        get throws {
            try RenderPass(label: "Blinn-Phong Demo") {
                let viewMatrix = cameraMatrix.inverse
                let viewProjection = projectionMatrix * viewMatrix

                // 1. Skybox — fullscreen cubemap background
                if options.contains(.skybox) {
                    try SkyboxRenderPipeline(
                        projectionMatrix: projectionMatrix,
                        cameraMatrix: cameraMatrix,
                        rotation: simd_quatf(angle: .pi, axis: [0, 1, 0]),
                        texture: skyboxTexture
                    )
                }

                // 2. Grid — infinite ground plane with colored axis lines
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

                // 3. Light markers — yellow crosses via GraphicsContext3D
                if options.contains(.lightMarker) {
                    let lightMarker = GraphicsContext3D { ctx in
                        let s: Float = 0.2
                        for p in lightPositions {
                            for axis in [SIMD3<Float>(1, 0, 0), SIMD3<Float>(0, 1, 0), SIMD3<Float>(0, 0, 1)] {
                                ctx.stroke(
                                    Path3D { path in
                                        path.move(to: p - axis * s)
                                        path.addLine(to: p + axis * s)
                                    },
                                    with: .yellow,
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

                // 4. Models — Blinn-Phong or debug visualization
                if options.contains(.models), let firstModel = models.first {
                    if let debugMode {
                        // Debug shader replaces Blinn-Phong
                        ForEach(models) { model in
                            let normalMatrix = float3x3(
                                model.modelMatrix.columns.0.xyz,
                                model.modelMatrix.columns.1.xyz,
                                model.modelMatrix.columns.2.xyz
                            )
                            try DebugRenderPipeline(
                                modelMatrix: model.modelMatrix,
                                normalMatrix: normalMatrix,
                                debugMode: debugMode,
                                lightPosition: lightPositions.first ?? .zero,
                                cameraPosition: cameraMatrix.translation,
                                viewProjectionMatrix: viewProjection
                            ) {
                                Draw { encoder in
                                    if wireframe { encoder.setTriangleFillMode(.lines) }
                                    encoder.setVertexBuffers(of: model.mesh)
                                    encoder.draw(model.mesh)
                                }
                            }
                            .vertexDescriptor(model.mesh.vertexDescriptor)
                            .depthCompare(function: .less, enabled: true)
                        }
                    } else {
                        // Blinn-Phong shading
                        try BlinnPhongShader {
                            try ForEach(models) { model in
                                try Draw { encoder in
                                    if wireframe { encoder.setTriangleFillMode(.lines) }
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
                            .lighting(lighting)
                        }
                        .vertexDescriptor(firstModel.mesh.vertexDescriptor)
                        .depthCompare(function: .less, enabled: true)
                    }
                }
            }
        }
    }
}

#Preview {
    BlinnPhongDemoView()
}
