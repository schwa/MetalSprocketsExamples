import Metal
import MetalSprockets
import MetalSprocketsAddOns
import MetalSprocketsSupport
import MetalSprocketsUI
import MetalSupport
import PhosphorShaders
import simd

struct PhosphorUniforms {
    var time: Float
    var frame: Float
    var resolution: SIMD2<Float>
    var mouse: SIMD2<Float>
}

/// Runs the Phosphor compute pass (backbuffer ping-pong + snippet visible function table)
/// and presents the latest texture via a texture billboard.
struct PhosphorPipeline: Element {
    @MSEnvironment(\.device)
    var device

    @MSState
    private var textureA: MTLTexture?

    @MSState
    private var textureB: MTLTexture?

    @MSState
    private var currentTextureIsA = true

    let uniforms: PhosphorUniforms
    let snippetFunction: MTLFunction?

    var body: some Element {
        get throws {
            let width = max(1, Int(uniforms.resolution.x))
            let height = max(1, Int(uniforms.resolution.y))
            setupTexturesIfNeeded(width: width, height: height)

            let writeTexture = currentTextureIsA ? textureA : textureB
            let readTexture = currentTextureIsA ? textureB : textureA

            let shaderLibrary = try ShaderLibrary(bundle: .phosphorShaders()).namespaced("Phosphor")
            let kernel: ComputeKernel = try shaderLibrary.computeMain

            let linkedFunctions: MTLLinkedFunctions? = snippetFunction.map { function in
                let lf = MTLLinkedFunctions()
                lf.functions = [function]
                return lf
            }

            return try Group {
                if let writeTexture, let readTexture, let snippetFunction, let linkedFunctions {
                    try ComputePass {
                        try ComputePipeline(computeKernel: kernel) {
                            try ComputeDispatch(threadsPerGrid: MTLSize(width: width, height: height, depth: 1))
                            .parameter("uniforms", value: uniforms)
                            .parameter("outTexture", texture: writeTexture)
                            .parameter("previousTexture", texture: readTexture)
                            .visibleFunctionTable("snippetFunctions", function: snippetFunction)
                        }
                        .environment(\.linkedFunctions, linkedFunctions)
                    }
                    .onCommandBufferCompleted { _ in
                        currentTextureIsA.toggle()
                    }
                }

                if let writeTexture {
                    try RenderPass {
                        try TextureBillboardPipeline(specifier: .texture2D(writeTexture))
                    }
                }
            }
        }
    }

    private func setupTexturesIfNeeded(width: Int, height: Int) {
        guard let device else {
            return
        }
        if let existing = textureA, existing.width == width, existing.height == height,
            textureB?.width == width, textureB?.height == height {
            return
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba32Float,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .private

        let newTextureA = device.makeTexture(descriptor: descriptor)
        let newTextureB = device.makeTexture(descriptor: descriptor)

        // Explicitly zero the ping-pong textures. Not all Apple GPUs clear
        // freshly-allocated texture memory, and the compute kernel reads the
        // previous texture as feedback on frame 0.
        if let queue = device.makeCommandQueue() {
            queue.label = "PhosphorPipeline.clear"
            let zero = SIMD4<Float>(repeating: 0)
            try? newTextureA?.fill(with: zero, using: queue)
            try? newTextureB?.fill(with: zero, using: queue)
        }

        textureA = newTextureA
        textureB = newTextureB
    }
}
