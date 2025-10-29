#if canImport(AppKit)
import AppKit
#endif
import CoreGraphics
import ImageIO
import Metal
import MetalKit
import MetalSprockets
import MetalSprocketsAddOns
import MetalSprocketsSupport
import ModelIO
import simd
import UniformTypeIdentifiers

struct TeapotDemo: Element {
    @MSState
    var mesh: MTKMesh
    var color: SIMD3<Float>
    var projectionMatrix: float4x4
    var cameraMatrix: float4x4
    var modelMatrix: float4x4
    var lightDirection: SIMD3<Float>

    init(projectionMatrix: float4x4, cameraMatrix: float4x4, modelMatrix: float4x4, color: SIMD3<Float>, lightDirection: SIMD3<Float>) throws {
        mesh = MTKMesh.teapot()
        self.projectionMatrix = projectionMatrix
        self.cameraMatrix = cameraMatrix
        self.modelMatrix = modelMatrix
        self.color = color
        self.lightDirection = lightDirection
    }

    var body: some Element {
        get throws {
            try LambertianShader(projectionMatrix: projectionMatrix, cameraMatrix: cameraMatrix, modelMatrix: modelMatrix, color: color, lightDirection: lightDirection) {
                Draw { encoder in
                    encoder.setVertexBuffers(of: mesh)
                    encoder.draw(mesh)
                }
            }
            .vertexDescriptor(MTLVertexDescriptor(mesh.vertexDescriptor))
            .depthCompare(function: .less, enabled: true)
        }
    }
}
