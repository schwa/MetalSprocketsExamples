import Metal
import MetalSprockets
import SwiftMesh

extension MTL4RenderCommandEncoder {
    // Pair with `.metalMeshResources(_:)` so vertex buffers are bound and index buffers stay resident.
    func draw(_ metalMesh: MetalMesh, instanceCount: Int = 1) {
        for submesh in metalMesh.submeshes {
            drawIndexedPrimitives(
                primitiveType: .triangle,
                indexCount: submesh.indexCount,
                indexType: .uint32,
                indexBuffer: submesh.indexBuffer.gpuAddress,
                indexBufferLength: submesh.indexCount * MemoryLayout<UInt32>.stride,
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
