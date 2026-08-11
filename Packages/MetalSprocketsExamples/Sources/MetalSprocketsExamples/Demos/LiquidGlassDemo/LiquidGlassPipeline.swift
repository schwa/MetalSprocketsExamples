import Metal
import MetalSprockets
import MetalSprocketsSupport
import simd

// Layout must match Uniforms in LiquidGlassShaders.metal.
struct LiquidGlassUniforms {
    var resolution: SIMD2<Float> = .zero
    var time: Float = 0
    var pillCount: UInt32 = 0
    var ior: Float = 1.45
    var dispersion: Float = 0.04
    var bevelWidth: Float = 30
    var frost: Float = 1.5
    var blend: Float = 1
    var padding0: Float = 0
    var padding1: Float = 0
    var padding2: Float = 0
    var pills: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>) = (.zero, .zero, .zero, .zero, .zero, .zero, .zero, .zero)
}

struct LiquidGlassPipeline: Element {
    let parameters: GlassParameters
    let time: Float
    let resolution: SIMD2<Float>

    @MSState
    private var vertexShader: VertexShader

    @MSState
    private var fragmentShader: FragmentShader

    @MSState
    private var textTexture: MTLTexture?

    init(parameters: GlassParameters, time: Float, resolution: SIMD2<Float>) throws {
        self.parameters = parameters
        self.time = time
        self.resolution = resolution
        let shaders = try ShaderNamespace.examples("LiquidGlass")
        vertexShader = try shaders.fullscreenVertex
        fragmentShader = try shaders.liquidGlassFragment
    }

    var body: some Element {
        get throws {
            try Group {
                if let textTexture {
                    try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                        Draw { encoder in
                            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                        }
                        .parameter("uniforms", value: makeUniforms())
                        .parameter("textTexture", texture: textTexture)
                    }
                }
            }
            .onSetupEnter { environment in
                guard textTexture == nil, let device = environment.device else {
                    return
                }
                textTexture = try? makeLiquidGlassTextTexture(device: device)
            }
        }
    }

    private func makeUniforms() -> LiquidGlassUniforms {
        let pills = Array(parameters.pills.prefix(GlassParameters.maxPills))
        var uniforms = LiquidGlassUniforms()
        uniforms.resolution = resolution
        uniforms.time = time
        uniforms.pillCount = UInt32(pills.count)
        uniforms.ior = parameters.ior
        uniforms.dispersion = parameters.dispersion
        uniforms.frost = parameters.frost
        uniforms.blend = parameters.blend * resolution.y
        let smallestExtent = pills.map { min($0.halfSize.x, $0.halfSize.y) * resolution.y }.min() ?? 1
        uniforms.bevelWidth = min(parameters.bevel * resolution.y, smallestExtent * 0.95)
        withUnsafeMutableBytes(of: &uniforms.pills) { buffer in
            let slots = buffer.bindMemory(to: SIMD4<Float>.self)
            for (index, pill) in pills.enumerated() {
                let center = pill.center * resolution
                let halfSize = pill.halfSize * resolution.y
                slots[index] = SIMD4(center.x, center.y, halfSize.x, halfSize.y)
            }
        }
        return uniforms
    }
}
