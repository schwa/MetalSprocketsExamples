import Foundation
import Metal
import MetalSprockets
import MetalSprocketsExampleShaders
import MetalSprocketsSupport
import simd

public enum FLIPScene: UInt32, CaseIterable, Identifiable, Sendable {
    case damBreak = 0
    case fallingDrop = 1
    case opposingBlocks = 2

    public var id: Self { self }

    public var title: String {
        switch self {
        case .damBreak:
            "Dam break"
        case .fallingDrop:
            "Falling drop"
        case .opposingBlocks:
            "Opposing blocks"
        }
    }
}

public struct FLIPSettings: Equatable, Sendable {
    public var flipRatio: Float = 0.95
    public var gravity: Float = 9.81
    public var pressureIterations: Int = 40
    public var timeScale: Float = 1

    public init() {
        // This line intentionally left blank.
    }
}

public struct FLIPStatistics: Equatable, Sendable {
    public var particleCount: Int = 0
    public var maximumSpeed: Float = 0
    public var timeStep: Float = 0
    public var simulatedTime: Float = 0

    public init() {
        // This line intentionally left blank.
    }
}

/// GPU state for the PIC/FLIP solver. The elements in `FLIPElements.swift` encode the work.
///
/// Each buffer has a fixed role. Kernels that would ping-pong write into a scratch buffer, and the result is copied
/// back, so no element has to track which buffer is current.
public final class FLIPSimulation {
    public let device: MTLDevice
    public let resolution: Int
    public let capacity: Int

    let shaders: FLIPShaders
    let positions: MTLBuffer
    let velocities: MTLBuffer
    let scratchPositions: MTLBuffer
    let scratchVelocities: MTLBuffer
    let grid: MTLBuffer
    let scratchGrid: MTLBuffer
    let oldGrid: MTLBuffer
    let pressure: MTLBuffer
    let divergence: MTLBuffer
    let heads: MTLBuffer
    let next: MTLBuffer
    let statisticsBuffer: MTLBuffer
    let surface: MTLTexture

    public static let resolutionRange = 8...64

    public init(device: MTLDevice, resolution: Int = 24) throws {
        guard Self.resolutionRange.contains(resolution) else {
            throw MetalSprocketsError.validationError("FLIP grid resolution must be in \(Self.resolutionRange), got \(resolution)")
        }
        self.device = device
        self.resolution = resolution
        capacity = resolution * resolution * resolution * 12
        shaders = try FLIPShaders()

        func buffer(_ count: Int, _ stride: Int, _ label: String) throws -> MTLBuffer {
            let buffer = try device.makeBuffer(length: count * stride, options: .storageModeShared).orThrow(.resourceCreationFailure(label))
            buffer.label = label
            return buffer
        }
        let cellCount = resolution * resolution * resolution
        let faceCount = (resolution + 1) * (resolution + 1) * (resolution + 1)
        let float4Stride = MemoryLayout<SIMD4<Float>>.stride
        positions = try buffer(capacity, float4Stride, "FLIP particle positions")
        velocities = try buffer(capacity, float4Stride, "FLIP particle velocities")
        scratchPositions = try buffer(capacity, float4Stride, "FLIP reseeded positions")
        scratchVelocities = try buffer(capacity, float4Stride, "FLIP reseeded velocities")
        grid = try buffer(faceCount, float4Stride, "FLIP MAC velocities")
        scratchGrid = try buffer(faceCount, float4Stride, "FLIP extrapolated velocities")
        oldGrid = try buffer(faceCount, float4Stride, "FLIP previous MAC velocities")
        pressure = try buffer(cellCount, MemoryLayout<Float>.stride, "FLIP scaled pressure")
        divergence = try buffer(cellCount, MemoryLayout<Float>.stride, "FLIP divergence")
        heads = try buffer(cellCount, MemoryLayout<Int32>.stride, "FLIP bin heads")
        next = try buffer(capacity, MemoryLayout<Int32>.stride, "FLIP bin links")
        statisticsBuffer = try buffer(1, MemoryLayout<MetalFLIPStatistics>.stride, "FLIP statistics")

        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type3D
        descriptor.pixelFormat = .r32Float
        descriptor.width = resolution * 2 + 1
        descriptor.height = descriptor.width
        descriptor.depth = descriptor.width
        descriptor.storageMode = .private
        descriptor.usage = [.shaderRead, .shaderWrite]
        surface = try device.makeTexture(descriptor: descriptor).orThrow(.resourceCreationFailure("FLIP surface field"))
        surface.label = "FLIP surface field"
    }

    var cellCount: Int { resolution * resolution * resolution }
    var faceCount: Int { (resolution + 1) * (resolution + 1) * (resolution + 1) }

    /// Reads the counters written by the last completed submission. Values from a frame still in flight may be torn.
    public var statistics: FLIPStatistics {
        let raw = statisticsBuffer.contents().load(as: MetalFLIPStatistics.self)
        var result = FLIPStatistics()
        result.particleCount = Int(raw.particleCount)
        result.maximumSpeed = Float(bitPattern: raw.maximumSpeedBits)
        result.timeStep = raw.timeStep
        result.simulatedTime = raw.simulatedTime
        return result
    }

    func parameters(scene: FLIPScene, settings: FLIPSettings) -> MetalFLIPParameters {
        MetalFLIPParameters(
            resolution: UInt32(resolution),
            capacity: UInt32(capacity),
            scene: scene.rawValue,
            spacing: 1 / Float(resolution),
            maximumTimeStep: min(max(settings.timeScale, 0), 2) / 60,
            flipRatio: min(max(settings.flipRatio, 0), 1),
            gravity: min(max(settings.gravity, 0), 30)
        )
    }
}

struct FLIPShaders {
    let seedParticles: ComputeKernel
    let clearStatistics: ComputeKernel
    let measureParticles: ComputeKernel
    let chooseTimeStep: ComputeKernel
    let particleToGrid: ComputeKernel
    let extrapolateVelocity: ComputeKernel
    let applyGravity: ComputeKernel
    let computeDivergence: ComputeKernel
    let solvePressure: ComputeKernel
    let projectVelocity: ComputeKernel
    let gridToParticle: ComputeKernel
    let clearBins: ComputeKernel
    let binParticles: ComputeKernel
    let reseedParticles: ComputeKernel
    let reconstructSurface: ComputeKernel
    let screenVertex: VertexShader
    let surfaceFragment: FragmentShader
    let particleVertex: VertexShader
    let particleFragment: FragmentShader

    init() throws {
        let shaders = try ShaderNamespace.examples("MetalFLIP")
        seedParticles = try shaders.seedParticles
        clearStatistics = try shaders.clearStatistics
        measureParticles = try shaders.measureParticles
        chooseTimeStep = try shaders.chooseTimeStep
        particleToGrid = try shaders.particleToGrid
        extrapolateVelocity = try shaders.extrapolateVelocity
        applyGravity = try shaders.applyGravity
        computeDivergence = try shaders.computeDivergence
        solvePressure = try shaders.solvePressure
        projectVelocity = try shaders.projectVelocity
        gridToParticle = try shaders.gridToParticle
        clearBins = try shaders.clearBins
        binParticles = try shaders.binParticles
        reseedParticles = try shaders.reseedParticles
        reconstructSurface = try shaders.reconstructSurface
        screenVertex = try shaders.screenVertex
        surfaceFragment = try shaders.surfaceFragment
        particleVertex = try shaders.particleVertex
        particleFragment = try shaders.particleFragment
    }
}

public struct FLIPOrbitCamera: Equatable, Sendable {
    public var azimuth: Float = 0.65
    public var elevation: Float = 0.32
    public var distance: Float = 2.65

    public static let elevationRange: ClosedRange<Float> = -0.1...1.35
    public static let distanceRange: ClosedRange<Float> = 1.6...5

    public init() {
        // This line intentionally left blank.
    }

    func uniforms(viewportSize: SIMD2<Float>, spacing: Float, particles: Bool) -> MetalFLIPCamera {
        let target = SIMD3<Float>(0.5, 0.42, 0.5)
        let direction = SIMD3<Float>(sin(azimuth) * cos(elevation), sin(elevation), cos(azimuth) * cos(elevation))
        let origin = target + direction * distance
        let forward = normalize(target - origin)
        let right = normalize(cross(forward, SIMD3<Float>(0, 1, 0)))
        let up = cross(right, forward)
        return MetalFLIPCamera(
            origin: SIMD4(origin, 1),
            right: SIMD4(right, 0),
            up: SIMD4(up, 0),
            forward: SIMD4(forward, 0),
            viewport: SIMD4(max(viewportSize.x, 1), max(viewportSize.y, 1), tan(Float.pi / 8), particles ? 1 : 0),
            fluid: SIMD4(spacing, 0, 0, 0)
        )
    }
}
