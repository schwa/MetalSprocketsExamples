import Metal
import MetalSprockets
import MetalSprocketsSupport

struct ColorRemapComputePipeline: Element {
    let inputTexture: MTLTexture
    let outputTexture: MTLTexture
    let gradientTexture: MTLTexture
    let maskTexture: MTLTexture
    let videoTexture: MTLTexture
    let power: Float

    init(
        inputTexture: MTLTexture,
        outputTexture: MTLTexture,
        gradientTexture: MTLTexture,
        maskTexture: MTLTexture,
        videoTexture: MTLTexture,
        power: Float = 1.0
    ) {
        self.inputTexture = inputTexture
        self.outputTexture = outputTexture
        self.gradientTexture = gradientTexture
        self.maskTexture = maskTexture
        self.videoTexture = videoTexture
        self.power = power
    }

    var body: some Element {
        get throws {
            let shaderLibrary = try ShaderLibrary(
                bundle: .metalSprocketsExampleShaders().orFatalError("Failed to load metal-sprockets example shaders bundle"),
                namespace: "ColorRemap"
            )

            try ComputePipeline(
                computeKernel: try shaderLibrary.colorRemap
            ) {
                try ComputeDispatch(
                    threadsPerGrid: MTLSize(
                        width: outputTexture.width,
                        height: outputTexture.height,
                        depth: 1
                    ),
                    threadsPerThreadgroup: MTLSize(width: 16, height: 16, depth: 1)
                )
                .parameter("inputTexture", texture: inputTexture)
                .parameter("outputTexture", texture: outputTexture)
                .parameter("gradientTexture", texture: gradientTexture)
                .parameter("maskTexture", texture: maskTexture)
                .parameter("videoTexture", texture: videoTexture)
                .parameter("power", value: power)
            }
        }
    }
}
