import DemoKit
import GeometryLite3D
import Interaction3D
import Metal
import MetalSprockets
import MetalSprocketsExampleShaders
import MetalSprocketsSupport
import MetalSprocketsUI
import MetalSupport
import simd
import SwiftUI

public struct CloudDemoView: View {
    enum Mode: Int, CaseIterable {
        case emissive
        case lit
    }

    // Anything that changes the image. A change restarts accumulation.
    private struct AccumulationKey: Equatable {
        var cameraMatrix: simd_float4x4
        var drawableSize: CGSize
        var mode: Mode
        var density: Double
        var maxBounces: Double
        var sunAngle: Double
        var animate: Bool
    }

    @State private var projection: any ProjectionProtocol = PerspectiveProjection()
    @State private var cameraMatrix: simd_float4x4 = .init(translation: [0, 0.2, 4.5])
    @State private var drawableSize: CGSize = .zero
    @State private var mode: Mode = .emissive
    @State private var split: Double = 0.5
    @State private var density: Double = 12
    @State private var samplesPerPixel: Double = 1
    @State private var maxBounces: Double = 8
    @State private var sunAngle: Double = 40
    @State private var animate = false
    @State private var accumulatedFrames: UInt32 = 0
    @State private var resources: CloudResources?

    public init() {
    }

    public var body: some View {
        WorldView(projection: $projection, cameraMatrix: $cameraMatrix) {
            RenderView { context, _ in
                if let resources, let accumulationTexture = resources.accumulationTexture {
                    // While animating the volume changes every frame, so there is nothing to accumulate.
                    let frames = animate ? 0 : accumulatedFrames
                    if resources.needsBake {
                        try ComputePass(label: "Cloud Noise Bake") {
                            try ComputePipeline(computeKernel: resources.bakeKernel) {
                                try ComputeDispatch(
                                    threadsPerGrid: MTLSize(width: CloudResources.noiseSize, height: CloudResources.noiseSize, depth: CloudResources.noiseSize),
                                    threadsPerThreadgroup: MTLSize(width: 4, height: 4, depth: 4)
                                )
                                .parameter("noise", texture: resources.noiseTexture)
                            }
                        }
                        .barrierAfterPass(after: .dispatch, beforeQueueStages: .fragment)
                        .onSubmissionCommitted { _ in
                            resources.needsBake = false
                        }
                        .useResourceCollection(resources.resourceCollection)
                    }
                    try RenderPass {
                        // Reads and rewrites the accumulation texture the previous frame wrote.
                        QueueBarrier(after: .fragment, before: .fragment)
                        try CloudPipeline(
                            uniforms: uniforms(time: animate ? context.frameUniforms.time : 0, accumulatedFrames: frames),
                            accumulationTexture: accumulationTexture,
                            noiseTexture: resources.noiseTexture
                        )
                    }
                    .useResourceCollection(resources.resourceCollection)
                    .onSubmissionCommitted { _ in
                        // A setting change may have reset the count since this frame was built.
                        if accumulatedFrames == frames, !animate {
                            accumulatedFrames += 1
                        }
                    }
                }
            }
            .metalColorPixelFormat(.bgra8Unorm_srgb)
            .onDrawableSizeChange { size in
                drawableSize = size
                try? resources?.ensureTexture(size: size)
            }
        }
        .task {
            do {
                let resources = try CloudResources()
                try resources.ensureTexture(size: drawableSize)
                self.resources = resources
            } catch {
                print("Cloud setup failed: \(error)")
            }
        }
        .onChange(of: accumulationKey) {
            accumulatedFrames = 0
        }
        .demoConfiguration {
            Form {
                Picker("Medium", selection: $mode) {
                    Text("Emissive").tag(Mode.emissive)
                    Text("Lit").tag(Mode.lit)
                }
                LabeledContent("Split") {
                    Slider(value: $split, in: 0...1)
                }
                LabeledContent("Density") {
                    Slider(value: $density, in: 1...40)
                    Text("\(Int(density))").monospacedDigit().fixedSize()
                }
                LabeledContent("Samples / Pixel") {
                    Slider(value: $samplesPerPixel, in: 1...16, step: 1)
                    Text("\(Int(samplesPerPixel))").monospacedDigit().fixedSize()
                }
                if mode == .lit {
                    LabeledContent("Max Bounces") {
                        Slider(value: $maxBounces, in: 0...32, step: 1)
                        Text("\(Int(maxBounces))").monospacedDigit().fixedSize()
                    }
                    LabeledContent("Sun Angle") {
                        Slider(value: $sunAngle, in: 0...180)
                    }
                }
                Toggle("Animate", isOn: $animate)
                LabeledContent("Accumulated") {
                    Text(animate ? "–" : "\(accumulatedFrames)").monospacedDigit()
                }
            }
            .formStyle(.grouped)
        }
    }

    private var accumulationKey: AccumulationKey {
        AccumulationKey(cameraMatrix: cameraMatrix, drawableSize: drawableSize, mode: mode, density: density, maxBounces: maxBounces, sunAngle: sunAngle, animate: animate)
    }

    private func uniforms(time: Float, accumulatedFrames: UInt32) -> CloudUniforms {
        let projectionMatrix = projection.projectionMatrix(for: drawableSize)
        let viewProjection = projectionMatrix * cameraMatrix.inverse
        let angle = Float(sunAngle) * .pi / 180
        let sunDirection = simd_normalize(SIMD3<Float>(cos(angle), 0.8, 0.3 * sin(angle)))
        // Fresh RNG seed every frame so each accumulated sample is independent.
        let seed = UInt32.random(in: 0...UInt32.max)
        return CloudUniforms(
            inverseViewProjection: viewProjection.inverse,
            cameraPosition: cameraMatrix.columns.3.xyz,
            sunDirection: sunDirection,
            time: time,
            density: Float(density),
            split: Float(split),
            mode: Int32(mode.rawValue),
            samplesPerPixel: Int32(samplesPerPixel),
            maxBounces: Int32(maxBounces),
            frameIndex: seed,
            accumulatedFrames: accumulatedFrames
        )
    }
}

@MainActor
private final class CloudResources {
    static let noiseSize = 128

    let device: MTLDevice
    let resourceCollection: ResourceCollection
    let bakeKernel: ComputeKernel
    let noiseTexture: MTLTexture
    var needsBake = true
    var accumulationTexture: MTLTexture?

    init() throws {
        device = _MTLCreateSystemDefaultDevice()
        resourceCollection = try ResourceCollection(device: device)
        bakeKernel = try ShaderNamespace.examples("CloudShaders").bake_noise

        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type3D
        descriptor.pixelFormat = .rg8Unorm
        descriptor.width = Self.noiseSize
        descriptor.height = Self.noiseSize
        descriptor.depth = Self.noiseSize
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .private
        noiseTexture = try device.makeTexture(descriptor: descriptor).orThrow(.resourceCreationFailure("Cloud noise texture"))
        noiseTexture.label = "Cloud Noise"
        try resourceCollection.register([noiseTexture])
    }

    func ensureTexture(size: CGSize) throws {
        let width = max(Int(size.width), 1)
        let height = max(Int(size.height), 1)
        if let accumulationTexture, accumulationTexture.width == width, accumulationTexture.height == height {
            return
        }
        let old = accumulationTexture
        accumulationTexture = device.makeTexture2D(pixelFormat: .rgba32Float, width: width, height: height, storageMode: .private, label: "Cloud Accumulation")
        try resourceCollection.replace([old], with: [accumulationTexture])
    }
}

struct CloudPipeline: Element {
    let uniforms: CloudUniforms
    let accumulationTexture: MTLTexture
    let noiseTexture: MTLTexture

    @MSState private var vertexShader: VertexShader
    @MSState private var fragmentShader: FragmentShader

    init(uniforms: CloudUniforms, accumulationTexture: MTLTexture, noiseTexture: MTLTexture) throws {
        self.uniforms = uniforms
        self.accumulationTexture = accumulationTexture
        self.noiseTexture = noiseTexture
        let shaders = try ShaderNamespace.examples("CloudShaders")
        vertexShader = try shaders.vertex_main
        fragmentShader = try shaders.fragment_main
    }

    var body: some Element {
        get throws {
            try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                Draw { encoder in
                    encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
                }
                .parameter("uniforms", functionType: .fragment, value: uniforms)
                .parameter("accumulation", functionType: .fragment, texture: accumulationTexture)
                .parameter("noise", functionType: .fragment, texture: noiseTexture)
            }
        }
    }
}
