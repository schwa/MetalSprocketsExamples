import Metal
import MetalSprockets

struct EdgeDetectionKernel: Element {
    var kernel: ComputeKernel
    var depthTexture: MTLTexture
    var colorTexture: MTLTexture

    init(depthTexture: MTLTexture, colorTexture: MTLTexture) throws {
        kernel = try ShaderLibrary(bundle: .metalSprocketsExampleShaders()).EdgeDetectionKernel
        self.depthTexture = depthTexture
        self.colorTexture = colorTexture
    }

    var body: some Element {
        get throws {
            try ComputePipeline(computeKernel: kernel) {
                // TODO: #52 Compute threads per threadgroup
                try ComputeDispatch(threadsPerGrid: .init(width: depthTexture.width, height: depthTexture.height, depth: 1), threadsPerThreadgroup: .init(width: 32, height: 32, depth: 1))
                    .parameter("depthTexture", texture: depthTexture)
                    .parameter("colorTexture", texture: colorTexture)
            }
        }
    }
}
