import Metal
import MetalSprockets
import MetalSprocketsSupport
import simd
import SwiftUI

struct MixedExample: Element {
    var projectionMatrix: float4x4
    var cameraMatrix: float4x4
    var modelMatrix: float4x4
    var color: SIMD3<Float>
    var lightDirection: SIMD3<Float>

    @MSEnvironment(\.renderPassDescriptor)
    var renderPassDescriptor

    init(projectionMatrix: float4x4, cameraMatrix: float4x4, modelMatrix: float4x4, color: SIMD3<Float>, lightDirection: SIMD3<Float>) {
        self.projectionMatrix = projectionMatrix
        self.cameraMatrix = cameraMatrix
        self.modelMatrix = modelMatrix
        self.color = color
        self.lightDirection = lightDirection
    }

    var body: some Element {
        get throws {
            let renderPassDescriptor = try renderPassDescriptor.orThrow(.missingEnvironment("renderPassDescriptor"))
            let colorTexture = try renderPassDescriptor.colorAttachments[0].texture.orThrow(.resourceCreationFailure("Missing color attachment texture"))
            let depthTexture = try renderPassDescriptor.depthAttachment.texture.orThrow(.resourceCreationFailure("Missing depth attachment texture"))

            try RenderPass {
                try TeapotDemo(projectionMatrix: projectionMatrix, cameraMatrix: cameraMatrix, modelMatrix: modelMatrix, color: color, lightDirection: lightDirection)
                    // TODO: #136 Next two lines are only needed for the offscreen examples?
                    .colorAttachment0(colorTexture, index: 0)
                    .depthAttachment(depthTexture)
            }
            .renderPassDescriptorModifier { renderPassDescriptor in
                renderPassDescriptor.depthAttachment.storeAction = .store
            }
            try ComputePass {
                try EdgeDetectionKernel(depthTexture: depthTexture, colorTexture: colorTexture)
            }
        }
    }
}
