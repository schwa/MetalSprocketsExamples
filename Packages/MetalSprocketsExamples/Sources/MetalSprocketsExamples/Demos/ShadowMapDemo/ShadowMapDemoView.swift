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

// MARK: - ShadowMapDemoView

/// Demonstrates shadow mapping: depth rendered from the light's POV is sampled
/// in the Blinn-Phong fragment shader to produce shadows on the ground plane and between objects.
public struct ShadowMapDemoView: View {
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
    @State private var shadowMap: ShadowMap?
    @State private var lightPositions: [SIMD3<Float>] = [[0, 5, 5], [0, 5, -5]]
    @State private var renderOptions: ShadowMapDemoRenderPass.Options = .all
    @State private var depthBias: Float = 2.0
    @State private var slopeScale: Float = 6.0
    @State private var shadowMapResolution: Int = 2_048
    @State private var useInverseZ: Bool = true

    @State private var shadowDebug: Bool = false
    @State private var ambientLight: Float = 0.4
    @State private var lightIntensity: Float = 200
    @State private var paused: Bool = false

    // Orbiting lights
    @State private var lightAnimator0 = TransformerAnimator(
        transformer: OrbitTransformer(center: [0, 5, 0], radius: 7, angle: .zero, normal: [0, 1, 0]),
        parameter: \OrbitTransformer.angle,
        from: AngleF.degrees(0),
        to: AngleF.degrees(360),
        duration: 10,
        timingTransformer: LoopTransformer(duration: 10)
    )
    @State private var lightAnimator1 = TransformerAnimator(
        transformer: OrbitTransformer(center: [0, 5, 0], radius: 7, angle: .zero, normal: [0, 1, 0]),
        parameter: \OrbitTransformer.angle,
        from: AngleF.degrees(180),
        to: AngleF.degrees(540),
        duration: 15,
        timingTransformer: LoopTransformer(duration: 15)
    )

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

    @ViewBuilder
    private var renderContent: some View {
        RenderView { _, drawableSize in
            if let lighting, let shadowMap {
                // Update shadow map from current light positions
                let updatedShadowMap: ShadowMap = {
                    var sm = shadowMap
                    sm.depthBias = depthBias
                    sm.slopeScale = slopeScale
                    for i in 0..<lightPositions.count {
                        sm.updateDirectionalLight(
                            at: i,
                            position: lightPositions[i],
                            target: [0, 0, 0],
                            orthoSize: 15,
                            near: 0.1,
                            far: 30
                        )
                    }
                    return sm
                }()

                let aspect = drawableSize.height > 0 ? Float(drawableSize.width / drawableSize.height) : 1.0
                let projectionMatrix = float4x4.perspective(fovY: .pi / 4, aspect: aspect, near: 0.1, far: 1_000.0)

                ShadowMapDemoRenderPass(
                    projectionMatrix: projectionMatrix,
                    cameraMatrix: cameraMatrix,
                    drawableSize: drawableSize,
                    lighting: lighting,
                    lightPositions: lightPositions,
                    shadowMap: updatedShadowMap,
                    teapots: teapots,
                    groundMesh: groundMesh,
                    groundModelMatrix: groundModelMatrix,
                    groundMaterial: groundMaterial,
                    options: renderOptions,
                    shadowDebug: shadowDebug
                )
            }
        }
        .id("\(useInverseZ)-\(shadowDebug)") // Workaround: force RenderView recreation to clear cached state (MetalSprockets#314)
        .metalDepthStencilPixelFormat(.depth32Float)
        .metalDepthStencilAttachmentTextureUsage([.renderTarget, .shaderRead])
        // The shadow mask compute pass writes into the drawable.
        .metalFramebufferOnly(false)
        .metalClearColor(MTLClearColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1))
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            renderContent
                .onChange(of: timeline.date) {
                    if !paused {
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        lightAnimator0.update(at: t)
                        lightAnimator1.update(at: t)
                        lightPositions[0] = lightAnimator0.transformer.transform(.zero)
                        lightPositions[1] = lightAnimator1.transformer.transform(.zero)
                        lighting?.setLightPosition(lightPositions[0], at: 0)
                        lighting?.setLightPosition(lightPositions[1], at: 1)
                    }
                }
        }
        .onChange(of: ambientLight) {
            lighting?.ambientLightColor = [ambientLight, ambientLight, ambientLight]
        }
        .onChange(of: lightIntensity) {
            lighting?.setLight(Light(type: .point, color: [1, 1, 1], intensity: lightIntensity), at: 0)
        }
        .onChange(of: shadowMapResolution) {
            shadowMap = try? ShadowMap(resolution: shadowMapResolution, lightCount: 2, useInverseZ: useInverseZ)
        }
        .onChange(of: useInverseZ) {
            shadowMap = try? ShadowMap(resolution: shadowMapResolution, lightCount: 2, useInverseZ: useInverseZ)
        }
        .interactiveCamera(rotation: $cameraRotation, distance: $cameraDistance, target: $cameraTarget)
        .frameTimingOverlay()
        .demoConfiguration {
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
                    LabeledContent("Ambient") {
                        Slider(value: $ambientLight, in: 0...1)
                            .accessibilityLabel("Ambient Light")
                    }
                    LabeledContent("Intensity") {
                        Slider(value: $lightIntensity, in: 1...1_000)
                            .accessibilityLabel("Light Intensity")
                    }
                }
                Section("Shadow Map") {
                    LabeledContent("Depth Bias") {
                        Slider(value: $depthBias, in: 0...10)
                            .accessibilityLabel("Shadow Map Depth Bias")
                    }
                    LabeledContent("Slope Scale") {
                        Slider(value: $slopeScale, in: 0...10)
                            .accessibilityLabel("Shadow Map Slope Scale")
                    }
                    Picker("Resolution", selection: $shadowMapResolution) {
                        Text("128").tag(128)
                        Text("256").tag(256)
                        Text("512").tag(512)
                        Text("1024").tag(1_024)
                        Text("2048").tag(2_048)
                        Text("4096").tag(4_096)
                    }
                    Toggle("Inverse Z", isOn: $useInverseZ)
                    Toggle("Debug", isOn: $shadowDebug)

                    if let shadowMap {
                        ForEach(0..<shadowMap.lightCount, id: \.self) { i in
                            if let sliceView = shadowMap.depthTexture.makeTextureView(
                                pixelFormat: .depth32Float,
                                textureType: .type2D,
                                levels: 0..<1,
                                slices: i..<(i + 1)
                            ) {
                                DepthTextureView(depthTexture: sliceView)
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .task {
            do {
                lighting = try Lighting(
                    ambientLightColor: [ambientLight, ambientLight, ambientLight],
                    lights: [
                        ([0, 5, 5], Light(type: .point, color: [1, 0.9, 0.8], intensity: lightIntensity)),
                        ([0, 5, -5], Light(type: .point, color: [0.8, 0.9, 1], intensity: lightIntensity))
                    ]
                )
                shadowMap = try ShadowMap(resolution: shadowMapResolution, lightCount: 2, useInverseZ: useInverseZ)
            } catch {
                fatalError("Failed to initialize ShadowMap demo: \(error)")
            }
        }
    }
}

// MARK: - ShadowMapDemoRenderPass

struct ShadowMapDemoRenderPass: Element {
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
    var shadowMap: ShadowMap
    var teapots: [ShadowMapDemoView.Model]
    var groundMesh: MTKMesh
    var groundModelMatrix: simd_float4x4
    var groundMaterial: BlinnPhongMaterial
    var options: Options = .all
    var shadowDebug: Bool = false

    @MSEnvironment(\.renderPassDescriptor)
    var renderPassDescriptor

    var body: some Element {
        get throws {
            let shadowsEnabled = options.contains(.shadows)

            // Pass 1: Shadow map depth pass — render all shadow casters from light's POV
            if shadowsEnabled {
                // swiftlint:disable:next force_unwrapping
                try ShadowMapDepthPass(shadowMap: shadowMap, vertexDescriptor: teapots.first!.mesh.vertexDescriptor) {
                    // Teapots as shadow casters
                    ForEach(teapots) { model in
                        Draw { encoder in
                            encoder.setVertexBuffers(of: model.mesh)
                            encoder.draw(model.mesh)
                        }
                        .parameter("modelMatrix", functionType: .vertex, value: model.modelMatrix)
                    }
                    // Ground plane as shadow caster (it self-shadows)
                    Draw { encoder in
                        encoder.setVertexBuffers(of: groundMesh)
                        encoder.draw(groundMesh)
                    }
                    .parameter("modelMatrix", functionType: .vertex, value: groundModelMatrix)
                }
            }

            // Pass 2: Main scene render pass
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
                    let lightMarker = GraphicsContext3D { ctx in
                        let s: Float = 0.3
                        for pos in lightPositions {
                            for axis in [SIMD3<Float>(1, 0, 0), SIMD3<Float>(0, 1, 0), SIMD3<Float>(0, 0, 1)] {
                                ctx.stroke(
                                    Path3D { path in
                                        path.move(to: pos - axis * s)
                                        path.addLine(to: pos + axis * s)
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

                // Lit models (teapots + ground) — NO shadow awareness
                if options.contains(.models), let firstTeapot = teapots.first {
                    try BlinnPhongShader {
                        try Group {
                            // Teapots
                            ForEach(teapots) { model in
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

            // Pass 3: Shadow mask overlay — reads scene depth + shadow map, darkens shadowed areas
            // ShadowMaskPass opens its own compute encoder, so it is a sibling of the scene pass.
            if shadowsEnabled,
               let sceneDepthTexture = renderPassDescriptor?.depthAttachment.texture,
               let colorTexture = renderPassDescriptor?.colorAttachments[0].texture {
                let viewMatrix = cameraMatrix.inverse
                let viewProjection = projectionMatrix * viewMatrix
                let inverseVP = viewProjection.inverse

                try ShadowMaskPass(
                    sceneDepthTexture: sceneDepthTexture,
                    outputTexture: colorTexture,
                    shadowMap: shadowMap,
                    inverseViewProjection: inverseVP,
                    debug: shadowDebug
                )
            }
        }
    }
}
