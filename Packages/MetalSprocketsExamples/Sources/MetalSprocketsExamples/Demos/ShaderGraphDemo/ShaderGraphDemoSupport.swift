import Metal
import MetalSprockets

func makeVertexDescriptor() -> MTLVertexDescriptor {
    struct Vertex {
        var position: SIMD2<Float>
        var color: SIMD4<Float>
        var uv: SIMD2<Float>
    }

    let descriptor = MTLVertexDescriptor()

    // Position - float2
    descriptor.attributes[0].format = .float2
    descriptor.attributes[0].offset = MemoryLayout<Vertex>.offset(of: \.position) ?? 0
    descriptor.attributes[0].bufferIndex = 0

    // Color - float4
    descriptor.attributes[1].format = .float4
    descriptor.attributes[1].offset = MemoryLayout<Vertex>.offset(of: \.color) ?? MemoryLayout<SIMD2<Float>>.stride
    descriptor.attributes[1].bufferIndex = 0

    // UV - float2
    descriptor.attributes[2].format = .float2
    descriptor.attributes[2].offset = MemoryLayout<Vertex>.offset(of: \.uv) ?? (MemoryLayout<SIMD2<Float>>.stride + MemoryLayout<SIMD4<Float>>.stride)
    descriptor.attributes[2].bufferIndex = 0

    // Layout
    descriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
    descriptor.layouts[0].stepFunction = .perVertex

    return descriptor
}

