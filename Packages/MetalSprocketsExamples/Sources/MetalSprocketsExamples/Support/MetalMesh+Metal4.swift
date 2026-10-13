import Metal
import MetalSprockets
import SwiftMesh

extension MTL4RenderCommandEncoder {
    // Pair with `.metalMeshResources(_:)` so vertex buffers are bound and index buffers stay resident.
    func draw(_ metalMesh: MetalMesh, instanceCount: Int = 1) {
        for submesh in metalMesh.submeshes {
            let indexStride = submesh.indexType == .uint16 ? MemoryLayout<UInt16>.stride : MemoryLayout<UInt32>.stride
            drawIndexedPrimitives(
                primitiveType: submesh.primitiveType,
                indexCount: submesh.indexCount,
                indexType: submesh.indexType,
                indexBuffer: submesh.indexBuffer.gpuAddress + UInt64(submesh.indexBufferOffset),
                indexBufferLength: submesh.indexCount * indexStride,
                instanceCount: instanceCount
            )
        }
    }
}

extension MetalMesh {
    /// Vertex and index buffers, for registering in a `ResourceCollection`.
    var buffers: [any MTLBuffer] {
        vertexBuffers.map(\.value) + submeshes.map(\.indexBuffer)
    }
}

extension Element {
    func metalMeshResources(_ metalMesh: MetalMesh) -> some Element {
        var content: any Element = self
        for (index, buffer) in metalMesh.vertexBuffers {
            content = content.vertexBuffer(buffer, index: index)
        }
        return AnyElement(content)
            .useResources(metalMesh.submeshes.map(\.indexBuffer), usage: .read, stages: .vertex)
    }
}
