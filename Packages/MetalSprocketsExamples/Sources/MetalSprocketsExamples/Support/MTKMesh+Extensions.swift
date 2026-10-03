import MetalKit
import MetalSprocketsSupport
import MetalSupport

public extension MTKMesh {
    static func teapot(options: MTKMesh.Options = []) -> MTKMesh {
        do {
            return try MTKMesh(name: "teapot", bundle: .module, options: options)
        }
        catch {
            fatalError("\(error)")
        }
    }

    /// Vertex and index buffers, for registering in a `ResourceCollection`.
    var buffers: [any MTLBuffer] {
        vertexBuffers.map(\.buffer) + submeshes.map(\.indexBuffer.buffer)
    }
}
