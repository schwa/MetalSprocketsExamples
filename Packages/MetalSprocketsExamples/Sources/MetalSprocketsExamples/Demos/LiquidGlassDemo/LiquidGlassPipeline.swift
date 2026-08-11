import Metal
import MetalSprockets
import MetalSprocketsExampleShaders
import MetalSprocketsSupport
import simd

/// Draws a fullscreen triangle whose fragment shader does all the work:
/// SDF pills refracting a procedurally generated background.
///
/// The uniforms struct (`LiquidGlassUniforms`) lives in a C header compiled
/// into both this module and the Metal shaders, so CPU and GPU always agree
/// on its memory layout.
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
                // Texture creation needs a device, which is only available once
                // the element is set up; the guard makes this a one-time cost.
                guard textTexture == nil, let device = environment.device else {
                    return
                }
                textTexture = try? makeLiquidGlassTextTexture(device: device)
            }
        }
    }

    /// Converts the view-space `GlassParameters` (normalized 0...1 coordinates,
    /// fractions of view height) into the pixel-space values the shader expects.
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
        // The bevel cannot be wider than the smallest pill's half-extent, or the
        // height profile would fold over itself.
        let smallestExtent = pills.map { min($0.halfSize.x, $0.halfSize.y) * resolution.y }.min() ?? 1
        uniforms.bevelWidth = min(parameters.bevel * resolution.y, smallestExtent * 0.95)
        // C fixed-size arrays import into Swift as tuples; write through raw
        // bytes to index them.
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
