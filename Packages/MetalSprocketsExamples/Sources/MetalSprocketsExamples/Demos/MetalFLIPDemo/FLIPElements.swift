import Metal
import MetalSprockets
import MetalSprocketsExampleShaders
import simd

/// Encodes FLIP solver work into one compute pass: an optional reset, `steps` solver steps, then an optional surface
/// reconstruction for the ray-marched renderer.
public struct FLIPCompute: Element {
    let simulation: FLIPSimulation
    let reset: FLIPScene?
    let steps: Int
    let scene: FLIPScene
    let settings: FLIPSettings
    let reconstructsSurface: Bool

    public init(simulation: FLIPSimulation, reset: FLIPScene? = nil, steps: Int = 1, settings: FLIPSettings = FLIPSettings(), reconstructsSurface: Bool = true) {
        self.simulation = simulation
        self.reset = reset
        self.steps = steps
        self.scene = reset ?? .damBreak
        self.settings = settings
        self.reconstructsSurface = reconstructsSurface
    }

    public var body: some Element {
        get throws {
            let parameters = simulation.parameters(scene: scene, settings: settings)
            try ComputePass(label: "FLIP") {
                // The previous submission's solver and renderer read and write the same buffers.
                QueueBarrier(after: [.dispatch, .blit, .vertex, .fragment], before: [.dispatch, .blit])
                if reset != nil {
                    try resetWork(parameters: parameters)
                }
                ForEach(0..<steps, id: \.self) { _ in
                    try stepWork(parameters: parameters)
                }
                if reconstructsSurface {
                    try ordered {
                        try ComputePipeline(computeKernel: simulation.shaders.reconstructSurface) {
                            let width = simulation.surface.width
                            try ComputeDispatch(threadsPerGrid: MTLSize(width: width, height: width, depth: width), threadsPerThreadgroup: MTLSize(width: 4, height: 4, depth: 4))
                        }
                        .parameter("positions", buffer: simulation.positions)
                        .parameter("surface", texture: simulation.surface)
                        .parameter("parameters", value: parameters)
                    }
                }
            }
        }
    }

    @ElementBuilder
    private func resetWork(parameters: MetalFLIPParameters) throws -> some Element {
        let statistics = simulation.statisticsBuffer
        try ordered {
            ComputeCommand { encoder in
                encoder.fill(buffer: statistics, range: 0..<statistics.length, value: 0)
            }
            .useComputeResource(statistics, usage: .write)
        }
        try ordered {
            try dispatch(simulation.shaders.seedParticles, count: simulation.capacity)
                .parameter("positions", buffer: simulation.positions)
                .parameter("velocities", buffer: simulation.velocities)
                .parameter("parameters", value: parameters)
        }
        try measureWork(parameters: parameters)
    }

    // One PIC/FLIP step. Every dispatch reads what the previous one wrote, so each is fenced with an encoder barrier.
    @ElementBuilder
    private func stepWork(parameters: MetalFLIPParameters) throws -> some Element {
        let simulation = simulation
        let shaders = simulation.shaders
        try measureWork(parameters: parameters)
        try ordered {
            try dispatch(shaders.chooseTimeStep, count: 1)
                .parameter("statistics", buffer: simulation.statisticsBuffer)
                .parameter("parameters", value: parameters)
        }
        try ordered {
            try dispatch(shaders.particleToGrid, count: simulation.faceCount)
                .parameter("positions", buffer: simulation.positions)
                .parameter("velocities", buffer: simulation.velocities)
                .parameter("grid", buffer: simulation.grid)
                .parameter("parameters", value: parameters)
        }
        try extrapolateWork(parameters: parameters)
        try ordered {
            copy(simulation.grid, to: simulation.oldGrid)
        }
        try ordered {
            try dispatch(shaders.applyGravity, count: simulation.faceCount)
                .parameter("grid", buffer: simulation.grid)
                .parameter("statistics", buffer: simulation.statisticsBuffer)
                .parameter("parameters", value: parameters)
        }
        try ordered {
            try dispatch(shaders.computeDivergence, count: simulation.cellCount)
                .parameter("positions", buffer: simulation.positions)
                .parameter("grid", buffer: simulation.grid)
                .parameter("divergence", buffer: simulation.divergence)
                .parameter("pressure", buffer: simulation.pressure)
                .parameter("parameters", value: parameters)
        }
        let iterations = min(max(settings.pressureIterations, 1), 200)
        ForEach(0..<(iterations * 2), id: \.self) { sweep in
            try ordered {
                try dispatch(shaders.solvePressure, count: simulation.cellCount)
                    .parameter("positions", buffer: simulation.positions)
                    .parameter("divergence", buffer: simulation.divergence)
                    .parameter("pressure", buffer: simulation.pressure)
                    .parameter("parity", value: UInt32(sweep % 2))
                    .parameter("parameters", value: parameters)
            }
        }
        try ordered {
            try dispatch(shaders.projectVelocity, count: simulation.faceCount)
                .parameter("positions", buffer: simulation.positions)
                .parameter("pressure", buffer: simulation.pressure)
                .parameter("grid", buffer: simulation.grid)
                .parameter("parameters", value: parameters)
        }
        try extrapolateWork(parameters: parameters)
        try ordered {
            try dispatch(shaders.gridToParticle, count: simulation.capacity)
                .parameter("positions", buffer: simulation.positions)
                .parameter("velocities", buffer: simulation.velocities)
                .parameter("grid", buffer: simulation.grid)
                .parameter("oldGrid", buffer: simulation.oldGrid)
                .parameter("statistics", buffer: simulation.statisticsBuffer)
                .parameter("parameters", value: parameters)
        }
        try ordered {
            try dispatch(shaders.clearBins, count: simulation.cellCount)
                .parameter("heads", buffer: simulation.heads)
                .parameter("parameters", value: parameters)
        }
        try ordered {
            try dispatch(shaders.binParticles, count: simulation.capacity)
                .parameter("positions", buffer: simulation.positions)
                .parameter("heads", buffer: simulation.heads)
                .parameter("next", buffer: simulation.next)
                .parameter("parameters", value: parameters)
        }
        try ordered {
            try dispatch(shaders.reseedParticles, count: simulation.cellCount)
                .parameter("positions", buffer: simulation.positions)
                .parameter("velocities", buffer: simulation.velocities)
                .parameter("heads", buffer: simulation.heads)
                .parameter("next", buffer: simulation.next)
                .parameter("outputPositions", buffer: simulation.scratchPositions)
                .parameter("outputVelocities", buffer: simulation.scratchVelocities)
                .parameter("parameters", value: parameters)
        }
        try ordered {
            copy(simulation.scratchPositions, to: simulation.positions)
            copy(simulation.scratchVelocities, to: simulation.velocities)
        }
    }

    @ElementBuilder
    private func measureWork(parameters: MetalFLIPParameters) throws -> some Element {
        try ordered {
            try dispatch(simulation.shaders.clearStatistics, count: 1)
                .parameter("statistics", buffer: simulation.statisticsBuffer)
        }
        try ordered {
            try dispatch(simulation.shaders.measureParticles, count: simulation.capacity)
                .parameter("positions", buffer: simulation.positions)
                .parameter("velocities", buffer: simulation.velocities)
                .parameter("statistics", buffer: simulation.statisticsBuffer)
                .parameter("parameters", value: parameters)
        }
    }

    // Three layers of extrapolation into air: grid -> scratch -> grid -> scratch, then copy back into grid.
    @ElementBuilder
    private func extrapolateWork(parameters: MetalFLIPParameters) throws -> some Element {
        let simulation = simulation
        let passes = [(simulation.grid, simulation.scratchGrid), (simulation.scratchGrid, simulation.grid), (simulation.grid, simulation.scratchGrid)]
        ForEach(0..<passes.count, id: \.self) { index in
            try ordered {
                try dispatch(simulation.shaders.extrapolateVelocity, count: simulation.faceCount)
                    .parameter("input", buffer: passes[index].0)
                    .parameter("output", buffer: passes[index].1)
                    .parameter("parameters", value: parameters)
            }
        }
        try ordered {
            copy(simulation.scratchGrid, to: simulation.grid)
        }
    }

    @ElementBuilder
    private func ordered<Content: Element>(@ElementBuilder _ content: () throws -> Content) throws -> some Element {
        EncoderBarrier(after: [.dispatch, .blit], before: [.dispatch, .blit])
        try content()
    }

    private func dispatch(_ kernel: ComputeKernel, count: Int) throws -> some Element {
        try ComputePipeline(computeKernel: kernel) {
            try ComputeDispatch(threadsPerGrid: MTLSize(width: count, height: 1, depth: 1))
        }
    }

    private func copy(_ source: MTLBuffer, to destination: MTLBuffer) -> some Element {
        ComputeCommand { encoder in
            encoder.copy(sourceBuffer: source, sourceOffset: 0, destinationBuffer: destination, destinationOffset: 0, size: source.length)
        }
        .useComputeResource(source, usage: .read)
        .useComputeResource(destination, usage: .write)
    }
}

/// Draws the ray-marched fluid surface, or velocity-colored particle impostors over an empty tank.
public struct FLIPRender: Element {
    let simulation: FLIPSimulation
    let camera: FLIPOrbitCamera
    let showsParticles: Bool
    let viewportSize: SIMD2<Float>

    public init(simulation: FLIPSimulation, camera: FLIPOrbitCamera = FLIPOrbitCamera(), showsParticles: Bool = false, viewportSize: SIMD2<Float>) {
        self.simulation = simulation
        self.camera = camera
        self.showsParticles = showsParticles
        self.viewportSize = viewportSize
    }

    public var body: some Element {
        get throws {
            let shaders = simulation.shaders
            let uniforms = camera.uniforms(viewportSize: viewportSize, spacing: 1 / Float(simulation.resolution), particles: showsParticles)
            let capacity = simulation.capacity
            try RenderPass(label: "FLIP render") {
                QueueBarrier(after: [.dispatch, .blit], before: [.vertex, .fragment])
                try RenderPipeline(label: "FLIP surface", vertexShader: shaders.screenVertex, fragmentShader: shaders.surfaceFragment) {
                    Draw { encoder in
                        encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)
                    }
                }
                .parameter("camera", value: uniforms)
                .parameter("field", texture: simulation.surface)
                .depthCompare(function: .lessEqual, enabled: true)
                if showsParticles {
                    try RenderPipeline(label: "FLIP particles", vertexShader: shaders.particleVertex, fragmentShader: shaders.particleFragment) {
                        Draw { encoder in
                            encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: capacity)
                        }
                    }
                    .parameter("positions", buffer: simulation.positions)
                    .parameter("velocities", buffer: simulation.velocities)
                    .parameter("camera", value: uniforms)
                    .depthCompare(function: .lessEqual, enabled: true)
                }
            }
        }
    }
}

/// One interactive frame: resets when `resetGeneration` or the simulation changes, otherwise steps while running.
struct FLIPFrame: Element {
    struct ResetKey: Equatable {
        var simulation: ObjectIdentifier
        var generation: Int
    }

    let simulation: FLIPSimulation
    let scene: FLIPScene
    let resetGeneration: Int
    let isRunning: Bool
    let settings: FLIPSettings
    let camera: FLIPOrbitCamera
    let showsParticles: Bool
    let viewportSize: SIMD2<Float>

    @MSState
    private var appliedReset: ResetKey?

    var body: some Element {
        get throws {
            let key = ResetKey(simulation: ObjectIdentifier(simulation), generation: resetGeneration)
            let needsReset = appliedReset != key
            try Group {
                FLIPCompute(simulation: simulation, reset: needsReset ? scene : nil, steps: isRunning && !needsReset ? 1 : 0, settings: settings, reconstructsSurface: !showsParticles)
                FLIPRender(simulation: simulation, camera: camera, showsParticles: showsParticles, viewportSize: viewportSize)
            }
            // Only mark the reset applied once it is actually encoded; a skipped frame must not lose it.
            .onWorkloadEnter { _ in
                appliedReset = key
            }
        }
    }
}
