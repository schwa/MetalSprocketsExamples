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

            return try Group {
                // Textures are allocated in onSetupEnter, which runs after the first body pass, so the
                // first frame draws nothing.
                if let currentTexture, let nextTexture {
                    // Update simulation if running
                    if isRunning {
                        try ComputePass {
                            try ComputePipeline(computeKernel: try shaderLibrary.updateGrid) {
                                try ComputeDispatch(threadsPerGrid: MTLSize(width: gridSize.width, height: gridSize.height, depth: 1))
                                .parameter("currentState", texture: currentTexture)
                                .parameter("nextState", texture: nextTexture)
                            }
                        }
                        .onCommandBufferCompleted { _ in
                            // Swap textures after compute pass completes
                            currentTextureIsA.toggle()
                        }
                    }

                    // Display the current state using billboard shader
                    try RenderPass {
                        try TextureBillboardPipeline(specifier: .texture2D(currentTexture))
                    }
                }
            }
            .onSetupEnter { _ in
                // Allocating and seeding belong in setup, not in body. See #385.
                setupTextures()
                guard !seeded else {
                    return
                }
                seeded = true
                initializeGrid()
            }
            .onChange(of: pattern) {
                initializeGrid()
            }
        }
    }

    private var currentTexture: MTLTexture? {
        currentTextureIsA ? textureA : textureB
    }

    private var nextTexture: MTLTexture? {
        currentTextureIsA ? textureB : textureA
    }

    private func setupTextures() {
        guard textureA == nil || textureB == nil, let device = self.device else {
            return
        }

        textureA = device.makeTexture2D(pixelFormat: .rgba8Unorm, width: gridSize.width, height: gridSize.height, storageMode: .private, label: "Game of Life A")
        textureB = device.makeTexture2D(pixelFormat: .rgba8Unorm, width: gridSize.width, height: gridSize.height, storageMode: .private, label: "Game of Life B")
    }

    private func initializeGrid() {
        guard let device = self.device, let textureA = self.textureA, let textureB = self.textureB else {
            return
        }

        guard let shaderLibrary = try? ShaderNamespace.examples("GameOfLifeShader") else {
            return
        }

        let initKernel: ComputeKernel
        var parameters: [(String, Any)] = []

        do {
            switch pattern {
            case .glider:
                initKernel = try shaderLibrary.initializeGlider
                // Place glider at center
                let offset = SIMD2<UInt32>(UInt32(gridSize.width / 2), UInt32(gridSize.height / 2))
                parameters.append(("offset", offset))
            case .random:
                initKernel = try shaderLibrary.initializeRandom
                let density: Float = 0.3
                let seed = UInt32.random(in: 0..<UInt32.max)
                parameters.append(("density", density))
                parameters.append(("seed", seed))
            case .clear:
                initKernel = try shaderLibrary.clearGrid
            case .blinker:
                initKernel = try shaderLibrary.clearGrid // Start with clear then add pattern manually
            case .toad:
                initKernel = try shaderLibrary.clearGrid // Start with clear then add pattern manually
            }
        } catch {
            return
        }

        // Initialize both textures
        for texture in [textureA, textureB] {
            let commandQueue = device.makeCommandQueue().orFatalError("Failed to create command queue")
            let commandBuffer = commandQueue.makeCommandBuffer().orFatalError("Failed to create command buffer")
            let computeEncoder = commandBuffer.makeComputeCommandEncoder().orFatalError("Failed to create compute encoder")

            guard let pipelineState = try? device.makeComputePipelineState(function: initKernel.function) else { continue }
            computeEncoder.setComputePipelineState(pipelineState)
            computeEncoder.setTexture(texture, index: 0)

            // Set parameters based on pattern
            for (index, (_, value)) in parameters.enumerated() {
                if let uint2Value = value as? SIMD2<UInt32> {
                    computeEncoder.setBytes([uint2Value], length: MemoryLayout<SIMD2<UInt32>>.size, index: index)
                } else if let floatValue = value as? Float {
                    computeEncoder.setBytes([floatValue], length: MemoryLayout<Float>.size, index: index)
                } else if let uintValue = value as? UInt32 {
                    computeEncoder.setBytes([uintValue], length: MemoryLayout<UInt32>.size, index: index)
                }
            }

            let threadsPerThreadgroup = MTLSize(width: 16, height: 16, depth: 1)
            let threadgroups = MTLSize(
                width: (gridSize.width + 15) / 16,
                height: (gridSize.height + 15) / 16,
                depth: 1
            )
            computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)

            computeEncoder.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
    }
}
