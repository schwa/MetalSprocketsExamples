import MetalSprockets
import MetalSprocketsSupport
import MetalSprocketsUI
import MetalSupport
import SwiftUI

/// A demo that shows the use of a stencil texture.
/// This view creates a texture, the size of the output drawable, containing a checkerboard pattern, and copies it into a linear staging buffer. Both are regenerated when the drawable size changes.
/// A compute kernel cannot write directly to a `.stencil8` texture and blits between textures require identical pixel formats, so the checkerboard goes via a byte buffer.
/// During the render loop it blits the staging buffer into the stencil attachment of the render pass descriptor. A better way would be to just set the stencil attachment storeAction to .store but that is too easy for this demo.
/// It then enables the stencil test and draws a triangle. The resulting triangle should be clipped by the stencil texture.
public struct StencilDemoView: View {
    let source = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn {
        float2 position [[attribute(0)]];
    };

    struct VertexOut {
        float4 position [[position]];
    };

    [[vertex]] VertexOut vertex_main(
        const VertexIn in [[stage_in]]
    ) {
        VertexOut out;
        out.position = float4(in.position, 0.0, 1.0);
        return out;
    }

    [[fragment]] float4 fragment_main(
        VertexOut in [[stage_in]],
        constant float4 &color [[buffer(0)]]
    ) {
        return color;
    }
    """

    @State
    private var stencilBuffer: MTLBuffer?

    @State
    private var stencilBufferSize: MTLSize = .init(width: 0, height: 0, depth: 1)

    @State
    private var stencilBufferBytesPerRow: Int = 0

    let depthStencilDescriptor: MTLDepthStencilDescriptor = {
        let stencilDescriptor = MTLStencilDescriptor(compareFunction: .equal, readMask: 0xFF, writeMask: 0x00)
        return MTLDepthStencilDescriptor(depthCompareFunction: .always, isDepthWriteEnabled: false, frontFaceStencil: stencilDescriptor, backFaceStencil: stencilDescriptor)
    }()

    public init() {
        // This line intentionally left blank.
    }

    public var body: some View {
        ZStack {
            Color.clear
            RenderView { _, _ in
                try BlitPass {
                    EnvironmentReader(keyPath: \.renderPassDescriptor) { renderPassDescriptor in
                        if let descriptor = renderPassDescriptor, let stencilAttachmentTexture = descriptor.stencilAttachment.texture, let stencilBuffer {
                            let width = min(stencilBufferSize.width, stencilAttachmentTexture.width)
                            let height = min(stencilBufferSize.height, stencilAttachmentTexture.height)
                            if width > 0, height > 0 {
                                Blit { encoder in
                                    encoder.copy(
                                        from: stencilBuffer,
                                        sourceOffset: 0,
                                        sourceBytesPerRow: stencilBufferBytesPerRow,
                                        sourceBytesPerImage: stencilBufferBytesPerRow * height,
                                        sourceSize: .init(width: width, height: height, depth: 1),
                                        to: stencilAttachmentTexture,
                                        destinationSlice: 0,
                                        destinationLevel: 0,
                                        destinationOrigin: .init(x: 0, y: 0, z: 0)
                                    )
                                }
                            }
                        }
                    }
                }
                try RenderPass {
                    let vertexShader = try VertexShader(source: source)
                    let fragmentShader = try FragmentShader(source: source)
                    try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                        Draw { encoder in
                            // 5-pointed star as triangle fan from center
                            let points = 5
                            let center = SIMD2<Float>(0, 0)
                            var vertices: [SIMD2<Float>] = []
                            for i in 0..<points {
                                let outerAngle = Float.pi / 2 + Float(i) * 2 * .pi / Float(points)
                                let innerAngle = outerAngle + .pi / Float(points)
                                let outer = SIMD2<Float>(cos(outerAngle) * 0.8, sin(outerAngle) * 0.8)
                                let inner = SIMD2<Float>(cos(innerAngle) * 0.35, sin(innerAngle) * 0.35)
                                let nextOuter = SIMD2<Float>(cos(outerAngle + 2 * .pi / Float(points)) * 0.8, sin(outerAngle + 2 * .pi / Float(points)) * 0.8)
                                vertices.append(contentsOf: [center, outer, inner])
                                vertices.append(contentsOf: [center, inner, nextOuter])
                            }
                            encoder.setVertexBytes(vertices, length: MemoryLayout<SIMD2<Float>>.stride * vertices.count, index: 0)
                            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
                        }
                        .parameter("color", value: SIMD4<Float>([0.5, 1, 0.5, 1]))
                    }
                    .vertexDescriptor(vertexShader.inferredVertexDescriptor())
                    .depthStencilDescriptor(depthStencilDescriptor)
                }
                .renderPassDescriptorModifier { renderPassDescriptor in
                    renderPassDescriptor.stencilAttachment.loadAction = .load
                }
            }
            .aspectRatio(1.0, contentMode: .fit)
            .metalDepthStencilPixelFormat(.stencil8)
            .metalDepthStencilAttachmentTextureUsage([.shaderWrite, .renderTarget])
            .onUsableDrawableSizeChange { size in
                do {
                    let width = Int(size.width)
                    let height = Int(size.height)
                    let device = _MTLCreateSystemDefaultDevice()
                    let texture = device.makeTexture2D(pixelFormat: .r8Uint, width: width, height: height, label: "Faux Stencil Texture")

                    // Buffer-texture blits want a 256 byte aligned row pitch.
                    let bytesPerRow = (width + 255) / 256 * 256
                    let buffer = device.makeBuffer(length: bytesPerRow * height, options: .storageModePrivate)
                        .orFatalError("Failed to create stencil staging buffer")
                    buffer.label = "Faux Stencil Buffer"

                    try Group {
                        try ComputePass {
                            try CheckerboardKernel_ushort(outputTexture: texture, checkerSize: [100, 100], foregroundColor: 0xFFFF)
                        }
                        try BlitPass {
                            Blit { encoder in
                                encoder.copy(
                                    from: texture,
                                    sourceSlice: 0,
                                    sourceLevel: 0,
                                    sourceOrigin: .init(x: 0, y: 0, z: 0),
                                    sourceSize: .init(width: width, height: height, depth: 1),
                                    to: buffer,
                                    destinationOffset: 0,
                                    destinationBytesPerRow: bytesPerRow,
                                    destinationBytesPerImage: bytesPerRow * height
                                )
                            }
                        }
                    }
                    .run()

                    stencilBufferBytesPerRow = bytesPerRow
                    stencilBufferSize = .init(width: width, height: height, depth: 1)
                    stencilBuffer = buffer
                }
                catch {
                    debugPrint("Stencil texture update failed: \(error)")
                    stencilBuffer = nil
                }
            }
        }
        .background(.black)
    }
}
