import DemoKit
import GeometryLite3D
import Interaction3D
import MetalKit
import MetalSprockets
import MetalSprocketsAddOns
import MetalSprocketsSupport
import MetalSprocketsUI
import MetalSupport
import simd
import SwiftUI

public struct BouncingTeapotsDemoView: View {
    @State
    private var simulation = TeapotSimulation(count: 60)

    @State
    private var lastUpdate: Date?

    @State
    private var checkerboardColor: Color = .white

    @State
    private var offscreenTexture: MTLTexture?

    @State
    private var offscreenDepthTexture: MTLTexture?

    @State
    private var upscaledTexture: MTLTexture?

    @State
    private var drawableSize: CGSize = .zero

    @State
    private var scaleFactor = 1.0

    @State
    private var projection: any ProjectionProtocol = PerspectiveProjection()

    @State
    private var cameraMatrix: simd_float4x4 = .init(translation: [0, 4, 10])

    public init() {
        // This line intentionally left blank.
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            renderView()
                .onChange(of: timeline.date) {
                    let now = timeline.date
                    if let lastUpdate {
                        simulation.step(duration: now.timeIntervalSince(lastUpdate))
                    }
                    lastUpdate = now
                }
                .demoConfiguration {
                    Form {
                        ColorPicker("Checkerboard Color", selection: $checkerboardColor)
                        LabeledContent("MetalFX") {
                            Text("Upsampled Size: \(drawableSize.width, format: .number) x \(drawableSize.height, format: .number)")
                            Text("Render Size: \(scaleFactor * drawableSize.width, format: .number) x \(scaleFactor * drawableSize.height, format: .number)")
                            Text("Scale Factor: \(scaleFactor)")
                            Slider(value: $scaleFactor, in: 0.0125...1.0)
                                .accessibilityLabel("Scale Factor")
                        }
                    }
                    .formStyle(.grouped)
                }
        }
    }

    @ViewBuilder
    func renderView() -> some View {
        WorldView(projection: $projection, cameraMatrix: $cameraMatrix) {
            let projectionMatrix = projection.projectionMatrix(for: drawableSize)
            RenderView { _, _ in
                if let offscreenTexture, let offscreenDepthTexture, let upscaledTexture {
                    FlyingTeapotsRenderPass(projectionMatrix: projectionMatrix, cameraMatrix: cameraMatrix, simulation: simulation, checkerboardColor: checkerboardColor, offscreenTexture: offscreenTexture, offscreenDepthTexture: offscreenDepthTexture, upscaledTexture: upscaledTexture)
                }
            }
            .metalDepthStencilPixelFormat(.depth32Float)
            .onDrawableSizeChange { size in
                drawableSize = size
            }
            .onChange(of: drawableSize) {
                regenerateTextures()
            }
            .onChange(of: scaleFactor) {
                regenerateTextures()
            }
        }
    }

    func regenerateTextures() {
        let device = _MTLCreateSystemDefaultDevice()
        let offscreenSize = MTLSize(width: Int(scaleFactor * drawableSize.width), height: Int(scaleFactor * drawableSize.height), depth: 1)

        offscreenTexture = device.makeTexture2D(pixelFormat: .bgra8Unorm, width: offscreenSize.width, height: offscreenSize.height, usage: [.shaderRead, .shaderWrite, .renderTarget], label: "Offscreen Texture")
        offscreenDepthTexture = device.makeTexture2D(pixelFormat: .depth32Float, width: offscreenSize.width, height: offscreenSize.height, usage: [.shaderRead, .shaderWrite, .renderTarget], storageMode: .private, label: "Offscreen Depth Texture")
        upscaledTexture = device.makeTexture2D(pixelFormat: .bgra8Unorm, width: Int(drawableSize.width), height: Int(drawableSize.height), usage: [.shaderRead, .shaderWrite, .renderTarget], storageMode: .private, label: "Upscaled Texture")
    }
}

// MARK: -

struct FlyingTeapotsRenderPass: Element {
    @MSState
    var mesh: MTKMesh = .teapot()
    @MSState
    var sphere: MTKMesh = .sphere(extent: [100, 100, 100], inwardNormals: true)
    @MSState
    var skyboxSampler: MTLSamplerState
    @MSState
    var skyboxTexture: MTLTexture

    var projectionMatrix: float4x4
    var cameraMatrix: float4x4

    let simulation: TeapotSimulation
    let checkerboardColor: Color
    let offscreenTexture: MTLTexture
    let offscreenDepthTexture: MTLTexture
    let upscaledTexture: MTLTexture

    init(projectionMatrix: float4x4, cameraMatrix: float4x4, simulation: TeapotSimulation, checkerboardColor: Color, offscreenTexture: MTLTexture, offscreenDepthTexture: MTLTexture, upscaledTexture: MTLTexture) {
        let device = _MTLCreateSystemDefaultDevice()
        skyboxTexture = device.makeTexture2D(pixelFormat: .bgra8Unorm, width: 2_048, height: 2_048, label: "Skybox Texture")
        let samplerDescriptor = MTLSamplerDescriptor(supportArgumentBuffers: true)
        skyboxSampler = device.makeSamplerState(descriptor: samplerDescriptor).orFatalError("Failed to create skybox sampler")
        self.checkerboardColor = checkerboardColor
        self.simulation = simulation
        self.offscreenTexture = offscreenTexture
        self.offscreenDepthTexture = offscreenDepthTexture
        self.upscaledTexture = upscaledTexture
        self.projectionMatrix = projectionMatrix
        self.cameraMatrix = cameraMatrix
    }

    var body: some Element {
        get throws {
            let colors = simulation.teapots.map(\.color)
            let modelMatrices = simulation.teapots.map(\.matrix)

            try ComputePass {
                // Render a checkerboard pattern into a texture
                try CheckerboardKernel(outputTexture: skyboxTexture, checkerSize: [20, 20], foregroundColor: [1, 1, 1, 1])
                // And some circles
                try CircleGridKernel(outputTexture: skyboxTexture, spacing: [128, 128], radius: 32, foregroundColor: .init(color: checkerboardColor))
            }
            try RenderPass {
                // Draw the checkerboard texture into a skybox
                let modelViewProjectionMatrix = projectionMatrix * cameraMatrix.inverse
                try FlatShader(modelViewProjection: modelViewProjectionMatrix, textureSpecifier: .texture2D(skyboxTexture, skyboxSampler)) {
                    Draw { encoder in
                        encoder.setVertexBuffers(of: sphere)
                        encoder.draw(sphere)
                    }
                }
                .vertexDescriptor(MTLVertexDescriptor(sphere.vertexDescriptor))

                // Teapot party.
                LambertianShaderInstanced(projectionMatrix: projectionMatrix, cameraMatrix: cameraMatrix, colors: colors, modelMatrices: modelMatrices, lightDirection: [-1, -2, -1]) {
                    Draw { encoder in
                        encoder.setVertexBuffers(of: mesh)
                        encoder.draw(mesh, instanceCount: simulation.teapots.count)
                    }
                }
                .vertexDescriptor(MTLVertexDescriptor(mesh.vertexDescriptor))
            }
            .depthCompare(function: .less, enabled: true)
            #if canImport(MetalFX)
            .renderPassDescriptorModifier { descriptor in
                descriptor.colorAttachments[0].texture = offscreenTexture
                descriptor.depthAttachment.texture = offscreenDepthTexture
            }
            #endif

            #if canImport(MetalFX)
            MetalFXSpatial(inputTexture: offscreenTexture, outputTexture: upscaledTexture)
            try RenderPass {
                try TextureBillboardPipeline(specifier: .texture2D(upscaledTexture))
            }
            .depthCompare(function: .always, enabled: false)
            #endif
        }
    }
}
