import MetalSprockets
import MetalSprocketsUI
import simd

/// A protocol for demo render passes that can be rendered offscreen.
public protocol DemoRenderPass: Element {
    static var name: String { get }
    init(frameUniforms: MetalSprocketsUI.FrameUniforms, projectionMatrix: simd_float4x4, cameraMatrix: simd_float4x4) throws
}

nonisolated(unsafe) public let allDemoRenderPasses: [any DemoRenderPass.Type] = [
    SDFRenderPass.self
]
