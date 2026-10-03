import Foundation
import Metal
import MetalSprockets
import MetalSprocketsAddOns
import MetalSprocketsExampleShaders
import MetalSprocketsSupport
import simd

/// A Game of Life simulation element that runs entirely on the GPU
struct GameOfLife: Element {
    @MSEnvironment(\.device)
    var device

    @MSState
    private var textureA: MTLTexture?

    @MSState
    private var textureB: MTLTexture?

    @MSState
    private var currentTextureIsA = true

    /// Setup can run more than once (a drawable resize invalidates it), and re-seeding there would
    /// silently restart the simulation. Seed once; ``pattern`` changes re-seed explicitly.
    @MSState
    private var seeded = false

    /// Seeding runs as a compute pass in the next frame, on the same queue, so it is ordered against in-flight frames.
    @MSState
    private var pendingSeed: InitialPattern?

    @MSState
    private var resourceCollection: ResourceCollection?

    let isRunning: Bool
    let pattern: InitialPattern

    private let gridSize = (width: 256, height: 256)

    enum InitialPattern: String, CaseIterable {
        case glider = "Glider"
        case random = "Random"
        case clear = "Clear"
        case blinker = "Blinker"
        case toad = "Toad"
    }

    init(
        isRunning: Bool = true,
        pattern: InitialPattern = .random
    ) {
        self.isRunning = isRunning
        self.pattern = pattern
    }

    var body: some Element {
        get throws {
            let shaderLibrary = try ShaderNamespace.examples("GameOfLifeShader")
            let resourceCollection = try self.resourceCollection ?? makeResourceCollection()

            return try Group {
                // Textures are allocated in onSetupEnter, which runs after the first body pass, so the
                // first frame draws nothing.
                if let currentTexture, let nextTexture {
                    if let pendingSeed {
                        try ComputePass(label: "Seed") {
                            // Overwrites what earlier frames may still be stepping or displaying.
                            QueueBarrier(after: [.dispatch, .fragment], before: .dispatch)
                            try seedPipeline(pattern: pendingSeed, texture: currentTexture, shaderLibrary: shaderLibrary)
                        }
                        .onSubmissionCommitted { _ in
                            if self.pendingSeed == pendingSeed {
                                self.pendingSeed = nil
                            }
                        }
                    }

                    // Update simulation if running
                    if isRunning {
                        try ComputePass {
                            // Reads the previous step's output and overwrites what the previous frame displayed.
                            QueueBarrier(after: [.dispatch, .fragment], before: .dispatch)
                            try ComputePipeline(computeKernel: try shaderLibrary.updateGrid) {
                                try ComputeDispatch(threadsPerGrid: MTLSize(width: gridSize.width, height: gridSize.height, depth: 1))
                                .parameter("currentState", texture: currentTexture)
                                .parameter("nextState", texture: nextTexture)
                            }
                        }
                        .onSubmissionCommitted { _ in
                            // Queue barriers order later frames after this step, so swap once it is committed.
                            currentTextureIsA.toggle()
                        }
                    }

                    // Display the current state using billboard shader
                    try RenderPass {
                        // currentTexture was written by the previous frame's step (or this frame's seed).
                        QueueBarrier(after: .dispatch, before: .fragment)
                        try TextureBillboardPipeline(specifier: .texture2D(currentTexture))
                    }
                }
            }
            .useResourceCollection(resourceCollection)
            .onSetupEnter { _ in
                // Allocating and seeding belong in setup, not in body. See #385.
                try setupTextures()
                guard !seeded else {
                    return
                }
                seeded = true
                pendingSeed = pattern
            }
            .onChange(of: pattern) {
                pendingSeed = pattern
            }
        }
    }

    private func makeResourceCollection() throws -> ResourceCollection {
        let collection = try ResourceCollection(device: device.orThrow(.missingEnvironment("device")))
        resourceCollection = collection
        return collection
    }

    private var currentTexture: MTLTexture? {
        currentTextureIsA ? textureA : textureB
    }

    private var nextTexture: MTLTexture? {
        currentTextureIsA ? textureB : textureA
    }

    private func setupTextures() throws {
        guard textureA == nil || textureB == nil, let device = self.device else {
            return
        }

        textureA = device.makeTexture2D(pixelFormat: .rgba8Unorm, width: gridSize.width, height: gridSize.height, storageMode: .private, label: "Game of Life A")
        textureB = device.makeTexture2D(pixelFormat: .rgba8Unorm, width: gridSize.width, height: gridSize.height, storageMode: .private, label: "Game of Life B")
        try resourceCollection?.register([textureA, textureB])
    }

    // Only the current texture needs seeding; the next step overwrites the other one.
    @ElementBuilder
    private func seedPipeline(pattern: InitialPattern, texture: MTLTexture, shaderLibrary: ShaderNamespace) throws -> some Element {
        let grid = MTLSize(width: gridSize.width, height: gridSize.height, depth: 1)
        switch pattern {
        case .glider:
            try ComputePipeline(computeKernel: try shaderLibrary.initializeGlider) {
                try ComputeDispatch(threadsPerGrid: grid)
                    .parameter("texture", texture: texture)
                    .parameter("offset", value: SIMD2<UInt32>(UInt32(gridSize.width / 2), UInt32(gridSize.height / 2)))
            }
        case .random:
            try ComputePipeline(computeKernel: try shaderLibrary.initializeRandom) {
                try ComputeDispatch(threadsPerGrid: grid)
                    .parameter("texture", texture: texture)
                    .parameter("density", value: Float(0.3))
                    .parameter("seed", value: UInt32.random(in: 0..<UInt32.max))
            }
        case .clear, .blinker, .toad:
            // Blinker and toad have no kernels yet; they start clear.
            try ComputePipeline(computeKernel: try shaderLibrary.clearGrid) {
                try ComputeDispatch(threadsPerGrid: grid)
                    .parameter("texture", texture: texture)
            }
        }
    }
}
