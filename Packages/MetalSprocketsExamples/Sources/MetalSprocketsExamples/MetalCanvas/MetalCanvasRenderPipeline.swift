import Metal
import MetalSprockets
import MetalSprocketsExampleShaders
import MetalSprocketsSupport
import SwiftUI

struct MetalCanvasRenderPipeline: Element {
    let canvas: MetalCanvas
    let viewport: SIMD2<Float>

    @MSState
    var objectShader: ObjectShader

    @MSState
    var meshShader: MeshShader

    @MSState
    var fragmentShader: FragmentShader

    @MSState
    var operations: MetalCanvasOperations

    @MSState
    var previousCanvas: MetalCanvas?

    @MSState
    var previousViewport: SIMD2<Float>?

    @MSState
    var operationCount: Int = 0

    init(canvas: MetalCanvas, viewport: SIMD2<Float>, limits: MetalCanvasOperations.Limits = MetalCanvasOperations.Limits()) throws {
        self.canvas = canvas
        self.viewport = viewport

        let device = _MTLCreateSystemDefaultDevice()

        let library = try ShaderLibrary(bundle: .metalSprocketsExampleShaders(), namespace: "MetalCanvas")
        objectShader = try library.function(named: "metalCanvasObjectShader", type: ObjectShader.self)
        meshShader = try library.function(named: "metalCanvasMeshShader", type: MeshShader.self)
        fragmentShader = try library.function(named: "metalCanvasFragmentShader", type: FragmentShader.self)

        operations = try MetalCanvasOperations(device: device, limits: limits)
    }

    var body: some Element {
        get throws {
            let needsRegeneration = previousCanvas != canvas || previousViewport != viewport

            if needsRegeneration {
                operationCount = try operations.expand(canvas: canvas)
                previousCanvas = canvas
                previousViewport = viewport
            }

            return try MeshRenderPipeline(objectShader: objectShader, meshShader: meshShader, fragmentShader: fragmentShader) {
                // TODO: pipelineState.maxTotalThreadsPerThreadgroup
                Draw { encoder in
                    encoder.label = "MetalCanvas Mesh Encoder"
                    guard operationCount > 0 else {
                        return
                    }
                    encoder.setCullMode(.none)
                    print("Drawing \(operationCount) object threadgroups")
                    encoder.drawMeshThreadgroups(MTLSize(width: operationCount, height: 1, depth: 1), threadsPerObjectThreadgroup: MTLSize(width: 32, height: 1, depth: 1), threadsPerMeshThreadgroup: MTLSize(width: 32, height: 1, depth: 1))
                }
                .parameter("drawOperations", functionType: .object, buffer: operations.drawOperationsBuffer, offset: 0)
                .parameter("segmentOffsets", functionType: .object, buffer: operations.segmentOffsetsBuffer, offset: 0)
                .parameter("drawOperations", functionType: .mesh, buffer: operations.drawOperationsBuffer, offset: 0)
                .parameter("segmentOffsets", functionType: .mesh, buffer: operations.segmentOffsetsBuffer, offset: 0)
                .parameter("segments", functionType: .mesh, buffer: operations.segmentsBuffer, offset: 0)
                .parameter("viewport", functionType: .mesh, value: viewport)
            }
        }
    }
}
