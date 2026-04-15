import Metal
import MetalSprockets
import MetalSprocketsAddOns
import MetalSprocketsExampleShaders
import MetalSprocketsSupport
import MetalSprocketsUI
import MetalSupport
import SwiftUI

/// A SwiftUI view that displays a depth texture as a grayscale image.
struct DepthTextureView: View {
    let depthTexture: MTLTexture

    @State private var vertexShader: VertexShader?
    @State private var fragmentShader: FragmentShader?
    @State private var sampler: MTLSamplerState?

    init(depthTexture: MTLTexture) {
        self.depthTexture = depthTexture
    }

    var body: some View {
        RenderView { _, _ in
            if let vertexShader, let fragmentShader, let sampler {
                try RenderPass(label: "Depth Texture View") {
                    try RenderPipeline(label: "Depth Texture View", vertexShader: vertexShader, fragmentShader: fragmentShader) {
                        Draw { encoder in
                            encoder.setFragmentTexture(depthTexture, index: 0)
                            encoder.setFragmentSamplerState(sampler, index: 0)
                            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                        }
                    }
                }
            }
        }
        .task {
            do {
                let shaderLibrary = try ShaderLibrary(bundle: .metalSprocketsExampleShaders()).namespaced("DepthTextureView")
                vertexShader = try shaderLibrary.vertex_main
                fragmentShader = try shaderLibrary.fragment_main

                let device = _MTLCreateSystemDefaultDevice()
                let samplerDescriptor = MTLSamplerDescriptor()
                samplerDescriptor.minFilter = .nearest
                samplerDescriptor.magFilter = .nearest
                sampler = device.makeSamplerState(descriptor: samplerDescriptor)
            } catch {
                fatalError("Failed to initialize DepthTextureView: \(error)")
            }
        }
    }
}
