#if canImport(MetalFX)
import Metal
import MetalSprockets
import MetalSprocketsExampleShaders
import MetalSprocketsSupport
import simd

private let bloomLevels = 5

/// Encodes one frame of the black hole.
///
/// Frame graph: bake LUTs (first frame only) → geodesic ray march into a
/// reduced-resolution target → MetalFX spatial upscale to full resolution →
/// compute bloom pyramid → composite (tone map, grain, vignette) into the
/// drawable.
struct GargantuaPipeline: Element {
    let params: GargantuaParams
    let simulation: GargantuaSimulation
    let time: Float
    let drawableSize: CGSize

    @MSEnvironment(\.device)
    private var device

    @MSState private var rayVertexShader: VertexShader
    @MSState private var rayFragmentShader: FragmentShader
    @MSState private var compositeFragmentShader: FragmentShader
    @MSState private var prefilterKernel: ComputeKernel
    @MSState private var downsampleKernel: ComputeKernel
    @MSState private var upsampleKernel: ComputeKernel
    @MSState private var bakeMilkywayKernel: ComputeKernel
    @MSState private var bakeDiskNoiseKernel: ComputeKernel
    @MSState private var bakeDiskStreakKernel: ComputeKernel

    @MSState private var sceneTexture: MTLTexture?
    @MSState private var rayTexture: MTLTexture?
    @MSState private var bloomTextures: [MTLTexture] = []
    @MSState private var milkywayMap: MTLTexture?
    @MSState private var diskNoiseMap: MTLTexture?
    @MSState private var diskStreakMap: MTLTexture?
    @MSState private var baked = false

    @MSState private var simTime: Float = 0
    @MSState private var lastTime: Float?

    /// Everything that forces the offscreen targets to be rebuilt.
    private struct AllocationKey: Equatable {
        var width: Int
        var height: Int
        var rayScale: Float
    }

    private var allocationKey: AllocationKey {
        AllocationKey(
            width: max(1, Int(drawableSize.width)),
            height: max(1, Int(drawableSize.height)),
            rayScale: params.rayScale
        )
    }

    init(params: GargantuaParams, simulation: GargantuaSimulation, time: Float, drawableSize: CGSize) throws {
        self.params = params
        self.simulation = simulation
        self.time = time
        self.drawableSize = drawableSize
        let shaders = try ShaderNamespace.examples("Gargantua")
        rayVertexShader = try shaders.fullscreenVertex
        rayFragmentShader = try shaders.rayFragment
        compositeFragmentShader = try shaders.compositeFragment
        prefilterKernel = try shaders.bloomPrefilter
        downsampleKernel = try shaders.bloomDownsample
        upsampleKernel = try shaders.bloomUpsample
        bakeMilkywayKernel = try shaders.bakeMilkyway
        bakeDiskNoiseKernel = try shaders.bakeDiskNoise
        bakeDiskStreakKernel = try shaders.bakeDiskStreak
    }

    var body: some Element {
        get throws {
            try Group {
                if let scene = sceneTexture, let milkywayMap, let diskNoiseMap, let diskStreakMap,
                   bloomTextures.count == bloomLevels {
                    if !baked {
                        try bakePass(milkyway: milkywayMap, diskNoise: diskNoiseMap, diskStreak: diskStreakMap)
                    }
                    try rayPass(into: rayTexture ?? scene, milkyway: milkywayMap, diskNoise: diskNoiseMap, diskStreak: diskStreakMap)
                    if let rayTexture {
                        MetalFXSpatial(inputTexture: rayTexture, outputTexture: scene)
                    }
                    if bloomEnabled {
                        try ComputePass(label: "bloom") {
                            try bloomPass(scene: scene)
                        }
                    }
                    try compositePass(scene: scene)
                }
            }
            .onChange(of: allocationKey, initial: true) { _, _ in
                allocateTargets()
            }
            .onWorkloadEnter { _ in
                let delta = min(max(time - (lastTime ?? time), 0.0005), 0.1)
                lastTime = time
                simTime += delta
                simulation.update(dt: delta, params: params)
            }
        }
    }

    /// Bloom is meaningless for the raw debug views.
    private var bloomEnabled: Bool {
        Int(params.debug) <= 2
    }

    // MARK: - Passes

    /// The LUT bakes run once, on the first frame: the milky way is a pure
    /// function of direction and the disk noise fields are static in the
    /// disk's rotating frame, so none of them ever need re-evaluating.
    @ElementBuilder
    private func bakePass(milkyway: MTLTexture, diskNoise: MTLTexture, diskStreak: MTLTexture) throws -> some Element {
        try ComputePass(label: "bake") {
            try ComputePipeline(computeKernel: bakeMilkywayKernel) {
                try ComputeDispatch(
                    threadsPerGrid: MTLSize(width: milkyway.width, height: milkyway.height, depth: 6),
                    threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1)
                )
                .parameter("dst", texture: milkyway)
            }
            try ComputePipeline(computeKernel: bakeDiskNoiseKernel) {
                try ComputeDispatch(
                    threadsPerGrid: MTLSize(width: diskNoise.width, height: diskNoise.height, depth: 1),
                    threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1)
                )
                .parameter("dst", texture: diskNoise)
            }
            try ComputePipeline(computeKernel: bakeDiskStreakKernel) {
                try ComputeDispatch(
                    threadsPerGrid: MTLSize(width: diskStreak.width, height: diskStreak.height, depth: 1),
                    threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1)
                )
                .parameter("dst", texture: diskStreak)
            }
        }
        .onCommandBufferCompleted { _ in
            baked = true
        }
    }

    @ElementBuilder
    private func rayPass(into target: MTLTexture, milkyway: MTLTexture, diskNoise: MTLTexture, diskStreak: MTLTexture) throws -> some Element {
        let uniforms = makeRayUniforms(target: target)
        try RenderPass(label: "raymarch") {
            try RenderPipeline(vertexShader: rayVertexShader, fragmentShader: rayFragmentShader) {
                Draw { encoder in
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                }
                .parameter("uniforms", value: uniforms)
                .parameter("milkywayMap", texture: milkyway)
                .parameter("diskNoise", texture: diskNoise)
                .parameter("diskStreak", texture: diskStreak)
            }
            .renderPipelineDescriptorTransformer { descriptor in
                descriptor.colorAttachments[0].pixelFormat = .rgba16Float
            }
        }
        .renderPassDescriptorModifier { descriptor in
            descriptor.colorAttachments[0].texture = target
            descriptor.colorAttachments[0].loadAction = .dontCare
            descriptor.colorAttachments[0].storeAction = .store
        }
    }

    /// Progressive dual-filter bloom: prefilter into mip 0, downsample chain,
    /// then a tent upsample chain accumulating back into mip 0. One compute
    /// pass; Metal's serial encoder ordering handles the mip dependencies.
    /// (Unrolled: `ElementBuilder`, like `ViewBuilder`, has no `for` loops.)
    @ElementBuilder
    private func bloomPass(scene: MTLTexture) throws -> some Element {
        let radius = 1 + params.bloomRadius * 3
        try bloomDispatch(kernel: prefilterKernel, src: scene, dst: bloomTextures[0], uniforms: bloomUniforms(source: scene, z: params.bloomThreshold, w: 0))
        try downsample(1)
        try downsample(2)
        try downsample(3)
        try downsample(4)
        try upsample(3, radius: radius)
        try upsample(2, radius: radius)
        try upsample(1, radius: radius)
        try upsample(0, radius: radius)
    }

    @ElementBuilder
    private func downsample(_ level: Int) throws -> some Element {
        let src = bloomTextures[level - 1]
        try bloomDispatch(kernel: downsampleKernel, src: src, dst: bloomTextures[level], uniforms: bloomUniforms(source: src, z: 0, w: 0))
    }

    @ElementBuilder
    private func upsample(_ level: Int, radius: Float) throws -> some Element {
        let src = bloomTextures[level + 1]
        try bloomDispatch(kernel: upsampleKernel, src: src, dst: bloomTextures[level], uniforms: bloomUniforms(source: src, z: 0, w: radius))
    }

    @ElementBuilder
    private func bloomDispatch(kernel: ComputeKernel, src: MTLTexture, dst: MTLTexture, uniforms: GargantuaBloomUniforms) throws -> some Element {
        try ComputePipeline(computeKernel: kernel) {
            try ComputeDispatch(
                threadsPerGrid: MTLSize(width: dst.width, height: dst.height, depth: 1),
                threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1)
            )
            .parameter("src", texture: src)
            .parameter("dst", texture: dst)
            .parameter("uniforms", value: uniforms)
        }
    }

    @ElementBuilder
    private func compositePass(scene: MTLTexture) throws -> some Element {
        let res = SIMD2<Float>(Float(scene.width), Float(scene.height))
        let uniforms = GargantuaCompositeUniforms(
            a: SIMD4(res.x, res.y, simTime, params.vignette),
            b: SIMD4(params.grain, params.ca, bloomEnabled ? params.bloomStrength : 0, params.bloomRadius)
        )
        try RenderPass(label: "composite") {
            try RenderPipeline(vertexShader: rayVertexShader, fragmentShader: compositeFragmentShader) {
                Draw { encoder in
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                }
                .parameter("scene", texture: scene)
                .parameter("bloomTex", texture: bloomTextures[0])
                .parameter("uniforms", value: uniforms)
            }
        }
    }

    // MARK: - Uniforms

    private func makeRayUniforms(target: MTLTexture) -> GargantuaRayUniforms {
        let position = simulation.rig.position
        let target3 = simulation.rig.target
        return GargantuaRayUniforms(
            resTimeFov: SIMD4(Float(target.width), Float(target.height), simTime, 1 / tan(params.fov * .pi / 180 / 2)),
            camPos: SIMD4(position, 0),
            camTarget: SIMD4(target3, 0),
            p0: SIMD4(params.din, params.dout, params.dopMax, params.opNear),
            p1: SIMD4(params.opFar, params.diskBright, params.starBright, params.skyFloor),
            p2: SIMD4(params.rotSpeed, 1, params.steps.rounded(), params.debug.rounded())
        )
    }

    // MARK: - Targets

    private func bloomUniforms(source: MTLTexture, z: Float, w: Float) -> GargantuaBloomUniforms {
        GargantuaBloomUniforms(a: SIMD4(1 / Float(source.width), 1 / Float(source.height), z, w))
    }

    private func allocateTargets() {
        guard let device else {
            return
        }
        let key = allocationKey
        let width = key.width
        let height = key.height

        func make(_ width: Int, _ height: Int, usage: MTLTextureUsage, label: String) -> MTLTexture? {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba16Float, width: max(1, width), height: max(1, height), mipmapped: false)
            descriptor.usage = usage
            descriptor.storageMode = .private
            let texture = device.makeTexture(descriptor: descriptor)
            texture?.label = label
            return texture
        }

        // .shaderWrite only when MetalFX writes into it: it costs the texture
        // its lossless compression, so don't ask for it at full render scale.
        let scaled = key.rayScale < 0.999
        var sceneUsage: MTLTextureUsage = [.renderTarget, .shaderRead]
        if scaled {
            sceneUsage.insert(.shaderWrite)
        }
        sceneTexture = make(width, height, usage: sceneUsage, label: "scene")

        // Traces at a fraction of the drawable resolution and lets MetalFX
        // bring the result back up, so the geodesic march (the bulk of the
        // frame) scales with the render scale rather than the display's pixel
        // count.
        if scaled {
            let rayWidth = max(1, Int((Float(width) * key.rayScale).rounded()))
            let rayHeight = max(1, Int((Float(height) * key.rayScale).rounded()))
            rayTexture = make(rayWidth, rayHeight, usage: [.renderTarget, .shaderRead], label: "rayTarget")
        } else {
            rayTexture = nil
        }

        bloomTextures = (0..<bloomLevels).compactMap { level in
            let scale = 1 << (level + 1)
            // read/write because the upsample chain accumulates in place
            return make(width / scale, height / scale, usage: [.shaderRead, .shaderWrite], label: "bloom.mip\(level)")
        }

        allocateLUTs(device: device)
    }

    /// Fixed-size lookup textures, allocated once and filled by `bakePass`.
    private func allocateLUTs(device: MTLDevice) {
        guard milkywayMap == nil else {
            return
        }
        let cubeDescriptor = MTLTextureDescriptor.textureCubeDescriptor(pixelFormat: .rgba16Float, size: 512, mipmapped: false)
        cubeDescriptor.usage = [.shaderRead, .shaderWrite]
        cubeDescriptor.storageMode = .private
        milkywayMap = device.makeTexture(descriptor: cubeDescriptor)
        milkywayMap?.label = "milkyway.cube"

        let noiseDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg16Float, width: 2_048, height: 2_048, mipmapped: false)
        noiseDescriptor.usage = [.shaderRead, .shaderWrite]
        noiseDescriptor.storageMode = .private
        diskNoiseMap = device.makeTexture(descriptor: noiseDescriptor)
        diskNoiseMap?.label = "disk.noise"

        // The streak term needs 8k of angular resolution but little radial, so
        // it lives in its own texture rather than inflating the one above.
        let streakDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r16Float, width: 8_192, height: 1_024, mipmapped: false)
        streakDescriptor.usage = [.shaderRead, .shaderWrite]
        streakDescriptor.storageMode = .private
        diskStreakMap = device.makeTexture(descriptor: streakDescriptor)
        diskStreakMap?.label = "disk.streak"
    }
}
#endif
