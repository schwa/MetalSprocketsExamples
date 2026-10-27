import DemoKit
import GeometryLite3D
import Interaction3D
@preconcurrency import Metal
import MetalSprockets
import MetalSprocketsExampleShaders
import MetalSprocketsSupport
import MetalSprocketsUI
import MetalSupport
import os
import simd
import SwiftUI

public struct CloudDemoView: View {
    enum Mode: Int, CaseIterable {
        case emissive
        case lit
    }

    // Anything that changes the image. A change restarts accumulation (as does a resize).
    private struct AccumulationKey: Equatable {
        var cameraMatrix: simd_float4x4
        var mode: Mode
        var density: Double
        var maxBounces: Double
        var sunAzimuth: Double
        var sunElevation: Double
        var chromatic: Bool
        var tricubic: Bool
        var animate: Bool
        var seed: Double
        var scale: Double
    }

    @State private var projection: any ProjectionProtocol = PerspectiveProjection()
    @State private var cameraMatrix: simd_float4x4 = .init(translation: [0, 0.2, 4.5])
    @State private var mode: Mode = .lit
    @State private var split: Double = 0.5
    @State private var density: Double = 12
    @State private var samplesPerPixel: Double = 1
    @State private var maxBounces: Double = 2
    // Azimuth 0 puts the sun behind the cloud as seen from the default camera.
    @State private var sunAzimuth: Double = 25
    @State private var sunElevation: Double = 18
    @State private var chromatic = true
    @State private var tricubic = false
    @State private var animate = false
    @State private var seed: Double = 0
    @State private var animationSpeed: Double = 1
    @State private var scale: Double = 1
    @State private var accumulatedFrames = 0
    @State private var accumulationResetPending = true
    @State private var resources: CloudResources?
    // TEMP SceneSprockets #242 bisect: do not commit.
    @State private var bisectNoCounterUpdates = false
    @State private var bisectAlwaysReset = false
    @State private var maximumInFlightSubmissions = 3
    @State private var bisectFullBarrier = false
    @State private var bisectFramebufferOnly = true
    @State private var bisectPlainPixelFormat = false

    public init() {
    }

    public var body: some View {
        WorldView(projection: $projection, cameraMatrix: $cameraMatrix) {
            RenderView(maximumInFlightSubmissions: maximumInFlightSubmissions) { context, _ in
                let viewportSize = CGSize(width: CGFloat(context.frameUniforms.viewportSize.x), height: CGFloat(context.frameUniforms.viewportSize.y))
                if let resources, let accumulationTexture = try resources.accumulationTexture(size: viewportSize) {
                    // While animating the volume changes every frame, so there is nothing to accumulate.
                    let reset = bisectAlwaysReset || animate || accumulationResetPending || resources.textureWasReallocated
                    if resources.needsBake {
                        try ComputePass(label: "Cloud Noise Bake") {
                            try ComputePipeline(computeKernel: resources.bakeKernel) {
                                try ComputeDispatch(
                                    threadsPerGrid: MTLSize(width: CloudResources.noiseSize, height: CloudResources.noiseSize, depth: CloudResources.noiseSize),
                                    threadsPerThreadgroup: MTLSize(width: 4, height: 4, depth: 4)
                                )
                                .parameter("noise", texture: resources.noiseTexture)
                                .parameter("seed", value: UInt32(seed))
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
                        if bisectFullBarrier {
                            QueueBarrier(after: .all, before: .all)
                        } else {
                            QueueBarrier(after: .fragment, before: .fragment)
                        }
                        try CloudPipeline(
                            uniforms: uniforms(time: resources.advanceAnimation(to: context.frameUniforms.time, speed: Float(animationSpeed), animating: animate), viewportSize: viewportSize, reset: reset),
                            accumulationTexture: accumulationTexture,
                            noiseTexture: resources.noiseTexture
                        )
                    }
                    .useResourceCollection(resources.resourceCollection)
                    .barrierAfterPass(after: .fragment, beforeQueueStages: .dispatch)
                    // TEMP #242: count pink pixels in the drawable we actually rendered.
                    EnvironmentReader(keyPath: \.currentDrawable) { drawable in
                        if let drawable, !bisectFramebufferOnly {
                            let (frame, buffer) = resources.nextPinkBuffer()
                            try ComputePass(label: "Pink Scan") {
                                try ComputePipeline(computeKernel: resources.pinkKernel) {
                                    try ComputeDispatch(
                                        threadsPerGrid: MTLSize(width: drawable.texture.width, height: drawable.texture.height, depth: 1),
                                        threadsPerThreadgroup: MTLSize(width: 16, height: 16, depth: 1)
                                    )
                                    .parameter("drawable", texture: drawable.texture)
                                    .parameter("count", buffer: buffer)
                                }
                            }
                            .useResourceCollection(resources.resourceCollection)
                            .onSubmissionFinished {
                                let count = buffer.contents().load(as: UInt32.self)
                                pinkScanLogger.log("PINK242 scan frame=\(frame) pinkPixels=\(count)")
                            }
                        }
                    }
                    .onSubmissionCommitted { _ in
                        if bisectNoCounterUpdates {
                            if reset {
                                accumulationResetPending = false
                                resources.textureWasReallocated = false
                            }
                            return
                        }
                        // The GPU keeps the real sample count in the texture's alpha; this only mirrors it for the UI.
                        if reset {
                            accumulationResetPending = false
                            resources.textureWasReallocated = false
                            accumulatedFrames = 1
                        } else {
                            accumulatedFrames += 1
                        }
                    }
                }
            }
            .metalColorPixelFormat(bisectPlainPixelFormat ? .bgra8Unorm : .bgra8Unorm_srgb)
            .metalFramebufferOnly(bisectFramebufferOnly) // TEMP #242: pink scan needs false
        }
        .task {
            do {
                resources = try CloudResources()
            } catch {
                print("Cloud setup failed: \(error)")
            }
        }
        .onChange(of: seed) {
            resources?.needsBake = true
        }
        .onChange(of: accumulationKey) {
            accumulationResetPending = true
        }
        .demoConfiguration {
            Form {
                Section {
                    LabeledContent("Split") {
                        Slider(value: $split, in: 0...1)
                    }
                } header: {
                    Text("View")
                } footer: {
                    Text("Left: ray marched. Right: path traced.")
                }
                Section("Cloud (both halves)") {
                    LabeledContent("Seed") {
                        Slider(value: $seed, in: 0...100, step: 1)
                        Text("\(Int(seed))").monospacedDigit().fixedSize()
                    }
                    LabeledContent("Density") {
                        Slider(value: $density, in: 1...40)
                        Text("\(Int(density))").monospacedDigit().fixedSize()
                    }
                    Toggle("Tricubic Filtering", isOn: $tricubic)
                    LabeledContent("Size") {
                        Slider(value: $scale, in: 0.5...3)
                        Text(scale, format: .number.precision(.fractionLength(1))).monospacedDigit().fixedSize()
                    }
                    Toggle("Animate", isOn: $animate)
                    if animate {
                        LabeledContent("Animation Speed") {
                            Slider(value: $animationSpeed, in: 0...10)
                            Text(animationSpeed, format: .number.precision(.fractionLength(1))).monospacedDigit().fixedSize()
                        }
                    }
                }
                Section("Lighting (both halves)") {
                    Picker("Medium", selection: $mode) {
                        Text("Emissive").tag(Mode.emissive)
                        Text("Lit").tag(Mode.lit)
                    }
                    if mode == .lit {
                        LabeledContent("Sun Azimuth") {
                            Slider(value: $sunAzimuth, in: -180...180)
                        }
                        LabeledContent("Sun Elevation") {
                            Slider(value: $sunElevation, in: 2...90)
                        }
                        Toggle("Wavelength-Dependent", isOn: $chromatic)
                    }
                }
                Section("Path Tracer (right half)") {
                    LabeledContent("Samples / Pixel") {
                        Slider(value: $samplesPerPixel, in: 1...16, step: 1)
                        Text("\(Int(samplesPerPixel))").monospacedDigit().fixedSize()
                    }
                    if mode == .lit {
                        LabeledContent("Max Bounces") {
                            Slider(value: $maxBounces, in: 0...32, step: 1)
                            Text("\(Int(maxBounces))").monospacedDigit().fixedSize()
                        }
                    }
                    LabeledContent("Accumulated") {
                        Text(animate ? "–" : "\(accumulatedFrames)").monospacedDigit()
                    }
                }
                Section("Pink Bisect (temporary)") {
                    Toggle("No per-frame SwiftUI counter", isOn: $bisectNoCounterUpdates)
                    Toggle("Always reset accumulation (no read)", isOn: $bisectAlwaysReset)
                    Toggle("framebufferOnly (disables pink scan)", isOn: $bisectFramebufferOnly)
                    Toggle("Full queue barrier (.all → .all)", isOn: $bisectFullBarrier)
                    Picker("In-Flight Submissions", selection: $maximumInFlightSubmissions) {
                        ForEach(1...3, id: \.self) { Text("\($0)").tag($0) }
                    }
                    Toggle("Plain bgra8Unorm drawable", isOn: $bisectPlainPixelFormat)
                }
            }
            .formStyle(.grouped)
        }
    }

    private var accumulationKey: AccumulationKey {
        AccumulationKey(cameraMatrix: cameraMatrix, mode: mode, density: density, maxBounces: maxBounces, sunAzimuth: sunAzimuth, sunElevation: sunElevation, chromatic: chromatic, tricubic: tricubic, animate: animate, seed: seed, scale: scale)
    }

    private func uniforms(time: Float, viewportSize: CGSize, reset: Bool) -> CloudUniforms {
        let projectionMatrix = projection.projectionMatrix(for: viewportSize)
        let viewProjection = projectionMatrix * cameraMatrix.inverse
        let azimuth = Float(sunAzimuth) * .pi / 180
        let elevation = Float(sunElevation) * .pi / 180
        let sunDirection = SIMD3<Float>(cos(elevation) * sin(azimuth), sin(elevation), -cos(elevation) * cos(azimuth))
        // Fresh RNG seed every frame so each accumulated sample is independent.
        let frameSeed = UInt32.random(in: 0...UInt32.max)
        // Golden-ratio fractions spread consecutive seeds evenly over [0, 1).
        let seedValue = Float(seed)
        let scaledSeed = SIMD3<Float>(seedValue * 0.618034, seedValue * 0.754878, seedValue * 0.569840)
        let seedOffset = scaledSeed - scaledSeed.rounded(.down)
        return CloudUniforms(
            inverseViewProjection: viewProjection.inverse,
            cameraPosition: cameraMatrix.columns.3.xyz,
            sunDirection: sunDirection,
            seedOffset: seedOffset,
            time: time,
            scale: Float(scale),
            density: Float(density),
            split: Float(split),
            mode: Int32(mode.rawValue),
            samplesPerPixel: Int32(samplesPerPixel),
            maxBounces: Int32(maxBounces),
            tricubic: tricubic ? 1 : 0,
            chromatic: chromatic ? 1 : 0,
            frameIndex: frameSeed,
            resetAccumulation: reset ? 1 : 0
        )
    }
}

nonisolated private let pinkScanLogger = Logger(subsystem: "io.schwa.metal-sprockets.pink242", category: "scan")

private final class CloudResources {
    static let noiseSize = 128

    let device: MTLDevice
    let resourceCollection: ResourceCollection
    let bakeKernel: ComputeKernel
    let noiseTexture: MTLTexture
    var needsBake = true
    private var animationTime: Float = 0
    private var lastFrameTime: Float?

    // Integrates frame deltas so changing the speed doesn't jump the animation.
    func advanceAnimation(to frameTime: Float, speed: Float, animating: Bool) -> Float {
        if animating, let lastFrameTime {
            animationTime += (frameTime - lastFrameTime) * speed
        }
        lastFrameTime = frameTime
        return animationTime
    }
    var textureWasReallocated = false
    let pinkKernel: ComputeKernel
    private let pinkBuffers: [MTLBuffer]
    private var pinkFrame = 0

    func nextPinkBuffer() -> (Int, MTLBuffer) {
        pinkFrame += 1
        let buffer = pinkBuffers[pinkFrame % pinkBuffers.count]
        buffer.contents().storeBytes(of: UInt32(0), as: UInt32.self)
        return (pinkFrame, buffer)
    }
    private var accumulationTexture: MTLTexture?

    init() throws {
        device = _MTLCreateSystemDefaultDevice()
        resourceCollection = try ResourceCollection(device: device)
        bakeKernel = try ShaderNamespace.examples("CloudShaders").bake_noise
        pinkKernel = try ShaderNamespace.examples("CloudShaders").pink_scan
        let pinkDevice = device
        pinkBuffers = try (0..<8).map { _ in try pinkDevice.makeBuffer(length: 4, options: .storageModeShared).orThrow(.resourceCreationFailure("Pink scan buffer")) }

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
        try resourceCollection.register(pinkBuffers)
    }

    // Returns the accumulation texture, reallocating it (and flagging a reset) when the viewport size changes.
    func accumulationTexture(size: CGSize) throws -> MTLTexture? {
        let width = max(Int(size.width), 1)
        let height = max(Int(size.height), 1)
        if let accumulationTexture, accumulationTexture.width == width, accumulationTexture.height == height {
            return accumulationTexture
        }
        let old = accumulationTexture
        accumulationTexture = device.makeTexture2D(pixelFormat: .rgba32Float, width: width, height: height, storageMode: .private, label: "Cloud Accumulation")
        textureWasReallocated = true
        try resourceCollection.replace([old], with: [accumulationTexture])
        return accumulationTexture
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
