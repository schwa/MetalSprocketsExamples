import CoreGraphics
import Metal
import MetalSprockets
import MetalSprocketsExampleShaders
import MetalSprocketsSupport
import MetalSupport
import simd

@MainActor
final class MeadowResources {
    let device: MTLDevice
    let kernel: ComputeKernel
    let resourceCollection: ResourceCollection
    let triangleCount: Int
    let vertexBuffer: MTLBuffer
    let materialBuffer: MTLBuffer
    let accelerationStructure: MTLAccelerationStructure
    private(set) var historyTexture: MTLTexture?
    private(set) var outputTexture: MTLTexture?
    private(set) var currentSize = MTLSize()

    static func make() async throws -> MeadowResources {
        let scene = await Task.detached(priority: .userInitiated) { MeadowSceneGeometry.make() }.value
        return try MeadowResources(scene: scene)
    }

    init(scene: MeadowSceneGeometry) throws {
        device = _MTLCreateSystemDefaultDevice()
        guard device.supportsRaytracing else {
            throw MetalSprocketsError.resourceCreationFailure("Meadow requires hardware ray tracing")
        }
        kernel = try ShaderLibrary(bundle: .metalSprocketsExampleShaders()).namespaced("MeadowShaders").traceMeadow
        resourceCollection = try ResourceCollection(device: device)
        triangleCount = scene.materials.count

        vertexBuffer = try device.makeBuffer(bytes: scene.vertices, length: scene.vertices.count * MemoryLayout<SIMD3<Float>>.stride, options: .storageModeShared)
            .orThrow(.resourceCreationFailure("Meadow vertex buffer"))
        vertexBuffer.label = "Meadow Vertices"
        materialBuffer = try device.makeBuffer(bytes: scene.materials, length: scene.materials.count * MemoryLayout<SIMD4<Float>>.stride, options: .storageModeShared)
            .orThrow(.resourceCreationFailure("Meadow material buffer"))
        materialBuffer.label = "Meadow Materials"

        let geometry = MTLAccelerationStructureTriangleGeometryDescriptor()
        geometry.vertexBuffer = vertexBuffer
        geometry.vertexStride = MemoryLayout<SIMD3<Float>>.stride
        geometry.vertexFormat = .float3
        geometry.triangleCount = triangleCount
        geometry.opaque = true
        let descriptor = MTLPrimitiveAccelerationStructureDescriptor()
        descriptor.geometryDescriptors = [geometry]
        let sizes = device.accelerationStructureSizes(descriptor: descriptor)
        accelerationStructure = try device.makeAccelerationStructure(size: sizes.accelerationStructureSize)
            .orThrow(.resourceCreationFailure("Meadow acceleration structure"))
        accelerationStructure.label = "Meadow AS"
        let scratch = try device.makeBuffer(length: sizes.buildScratchBufferSize, options: .storageModePrivate)
            .orThrow(.resourceCreationFailure("Meadow scratch buffer"))

        // One-time build; waits so nothing else needs to order against it.
        let queue = try device.makeCommandQueue().orThrow(.resourceCreationFailure("Meadow command queue"))
        let commandBuffer = try queue.makeCommandBuffer().orThrow(.resourceCreationFailure("Meadow command buffer"))
        let encoder = try commandBuffer.makeAccelerationStructureCommandEncoder().orThrow(.resourceCreationFailure("Meadow AS encoder"))
        encoder.build(accelerationStructure: accelerationStructure, descriptor: descriptor, scratchBuffer: scratch, scratchBufferOffset: 0)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        try resourceCollection.register([vertexBuffer, materialBuffer, accelerationStructure])
    }

    /// Creates the accumulation texture, and an output texture unless `output` is given.
    func ensureTextures(size: MTLSize, output: MTLTexture? = nil) throws {
        guard size.width != currentSize.width || size.height != currentSize.height || (output != nil && output !== outputTexture) else {
            return
        }
        currentSize = size
        let oldTextures = [historyTexture, outputTexture]
        historyTexture = device.makeTexture2D(pixelFormat: .rgba32Float, width: size.width, height: size.height, storageMode: .private, label: "Meadow History")
        outputTexture = output ?? device.makeTexture2D(pixelFormat: .rgba8Unorm, width: size.width, height: size.height, label: "Meadow Output")
        try resourceCollection.replace(oldTextures, with: [historyTexture, outputTexture])
    }

    @ElementBuilder
    func traceElement(camera: MeadowCamera, settings: MeadowSettings, frameIndex: UInt32, sampleCount: UInt32) throws -> some Element {
        if let historyTexture, let outputTexture {
            try ComputePass(label: "Meadow Trace") {
                // Accumulates into the previous sample and overwrites the output the previous frame sampled.
                QueueBarrier(after: [.dispatch, .fragment], before: .dispatch)
                try ComputePipeline(computeKernel: kernel) {
                    try ComputeDispatch(threadsPerGrid: currentSize, threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
                        .parameter("uniforms", value: MeadowUniforms(camera: camera, settings: settings, frameIndex: frameIndex, sampleCount: sampleCount))
                        .parameter("vertices", buffer: vertexBuffer)
                        .parameter("materials", buffer: materialBuffer)
                        .parameter("scene", accelerationStructure: accelerationStructure)
                        .parameter("output", texture: outputTexture)
                        .parameter("history", texture: historyTexture)
                }
            }
            .barrierAfterPass(after: .dispatch, beforeQueueStages: .fragment)
        }
    }
}

/// Headless Meadow renderer: accumulates `samples` progressive passes and returns the image.
@MainActor
public enum MeadowOffscreen {
    public static func render(width: Int, height: Int, samples: Int, camera: MeadowCamera = .init(), settings: MeadowSettings = .init()) async throws -> (image: CGImage, triangleCount: Int) {
        let resources = try await MeadowResources.make()
        let device = resources.device
        // Compute-only: the depth texture only satisfies OffscreenRenderer.
        // BGRA because toCGImage assumes it.
        let output = device.makeTexture2D(pixelFormat: .bgra8Unorm, width: width, height: height, label: "Meadow Offscreen Output")
        let depth = device.makeTexture2D(pixelFormat: .depth32Float, width: width, height: height, storageMode: .private, label: "Meadow Offscreen Depth")
        try resources.ensureTextures(size: MTLSize(width: width, height: height, depth: 1), output: output)
        let renderer = try OffscreenRenderer(size: CGSize(width: width, height: height), colorTexture: output, depthTexture: depth)
        var rendering: OffscreenRenderer.Rendering?
        for sample in 0..<max(1, samples) {
            let element = try resources.traceElement(camera: camera, settings: settings, frameIndex: UInt32(sample), sampleCount: UInt32(min(sample, 4_095)))
            rendering = try renderer.render(element.useResourceCollection(resources.resourceCollection))
        }
        // swiftlint:disable:next force_unwrapping
        return (try rendering!.cgImage, resources.triangleCount)
    }
}
