import Metal
import MetalSprockets
import MetalSprocketsExampleShaders
import MetalSprocketsSupport
import MetalSupport
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

    let limits: MetalCanvasOperations.Limits

    // A new set of buffers per regeneration: earlier frames may still be reading the previous ones.
    @MSState
    var operations: MetalCanvasOperations?

    @MSState
    var resourceCollection: ResourceCollection?

    @MSState
    var previousCanvas: MetalCanvas?

    @MSState
    var previousViewport: SIMD2<Float>?

    @MSState
    var operationCount: Int = 0

    init(canvas: MetalCanvas, viewport: SIMD2<Float>, limits: MetalCanvasOperations.Limits = MetalCanvasOperations.Limits()) throws {
        self.canvas = canvas
        self.viewport = viewport
        self.limits = limits

        let library = try ShaderNamespace.examples("MetalCanvas")
        objectShader = try library.function(named: "metalCanvasObjectShader", type: ObjectShader.self)
        meshShader = try library.function(named: "metalCanvasMeshShader", type: MeshShader.self)
        fragmentShader = try library.function(named: "metalCanvasFragmentShader", type: FragmentShader.self)
    }

    var body: some Element {
        get throws {
            let device = _MTLCreateSystemDefaultDevice()
            let resourceCollection = try self.resourceCollection ?? ResourceCollection(device: device)
            self.resourceCollection = resourceCollection

            let operations: MetalCanvasOperations
            if let current = self.operations, previousCanvas == canvas, previousViewport == viewport {
                operations = current
            } else {
                operations = try MetalCanvasOperations(device: device, limits: limits)
                operationCount = try operations.expand(canvas: canvas)
                try resourceCollection.replace(self.operations?.buffers ?? [], with: operations.buffers)
                self.operations = operations
                previousCanvas = canvas
                previousViewport = viewport
            }

            return try MeshRenderPipeline(objectShader: objectShader, meshShader: meshShader, fragmentShader: fragmentShader) {
                // TODO: #354 pipelineState.maxTotalThreadsPerThreadgroup
                Draw { encoder in
                    encoder.label = "MetalCanvas Mesh Encoder"
                    guard operationCount > 0 else {
                        return
                    }
                    encoder.setCullMode(.none)
                    encoder.drawMeshThreadgroups(threadgroupsPerGrid: MTLSize(width: operationCount, height: 1, depth: 1), threadsPerObjectThreadgroup: MTLSize(width: 32, height: 1, depth: 1), threadsPerMeshThreadgroup: MTLSize(width: 32, height: 1, depth: 1))
                }
                .parameter("drawOperations", functionType: .object, buffer: operations.drawOperationsBuffer, offset: 0)
                .parameter("segmentOffsets", functionType: .object, buffer: operations.segmentOffsetsBuffer, offset: 0)
                .parameter("drawOperations", functionType: .mesh, buffer: operations.drawOperationsBuffer, offset: 0)
                .parameter("segmentOffsets", functionType: .mesh, buffer: operations.segmentOffsetsBuffer, offset: 0)
                .parameter("segments", functionType: .mesh, buffer: operations.segmentsBuffer, offset: 0)
                .parameter("viewport", functionType: .mesh, value: viewport)
            }
            .useResourceCollection(resourceCollection)
        }
    }
}
