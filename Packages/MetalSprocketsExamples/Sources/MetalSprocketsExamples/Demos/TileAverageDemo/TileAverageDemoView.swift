import DemoKit
import Metal
import MetalKit
import MetalSprockets
import MetalSprocketsExampleShaders
import MetalSprocketsSupport
import MetalSprocketsUI
import MetalSupport
import simd
import SwiftUI

public struct TileAverageDemoView: View {
    @State
    private var tileSize: Int = 16

    @State
    private var drawableSize: CGSize = .zero

    @State
    private var time: Float = 0.0

    public init() {
        // Intentionally empty
    }

    public var body: some View {
        VStack(spacing: 0) {
            TimelineView(.animation) { timeline in
                renderContent()
                    .onChange(of: timeline.date) { _, _ in
                        time += 0.016
                    }
            }
            .onDrawableSizeChange { drawableSize = $0 }

            .demoConfiguration {
                controlPanel
            }
        }
    }

    @ViewBuilder
    private var controlPanel: some View {
        Form {
            if drawableSize != .zero {
                let tileCountX = Int(drawableSize.width) / tileSize
                let tileCountY = Int(drawableSize.height) / tileSize
                let totalTiles = tileCountX * tileCountY

                HStack {
                    Text("Tiles: \(totalTiles)")
                    Text("•")
                    Text("Tile size: \(tileSize)×\(tileSize)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            LabeledContent("Tile Size") {
                Picker("", selection: $tileSize) {
                    Text("16×16").tag(16)
                    Text("32×32").tag(32)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Tile Size")
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func renderContent() -> some View {
        RenderView { _, size in
            try TileAveragePipeline(
                drawableSize: size,
                tileSize: tileSize,
                time: time
            )
        }
    }
}

struct TileAveragePipeline: Element {
    let drawableSize: CGSize
    let tileSize: Int
    let time: Float

    @MSState
    var vertexShader: VertexShader

    @MSState
    var fragmentShader: FragmentShader

    @MSState
    var blitFragmentShader: FragmentShader

    let sourceTexture: MTLTexture
    let uniformsBuffer: MTLBuffer

    let width: Int
    let height: Int

    init(drawableSize: CGSize, tileSize: Int, time: Float) throws {
        self.drawableSize = drawableSize
        self.tileSize = tileSize
        self.time = time

        let shaderBundle = Bundle.metalSprocketsExampleShaders()
        let library = try ShaderLibrary(bundle: shaderBundle).namespaced("TileAverageShader")
        vertexShader = try library.function(named: "tileAverageVertex", type: VertexShader.self)
        fragmentShader = try library.function(named: "tileAverageFragment", type: FragmentShader.self)
        blitFragmentShader = try library.function(named: "tileAverageBlitFragment", type: FragmentShader.self)

        let device = _MTLCreateSystemDefaultDevice()

        // Load source texture
        let textureLoader = MTKTextureLoader(device: device)
        let url = Bundle.module.url(forResource: "DSC_2595", withExtension: "JPG")
            .orFatalError("Failed to find DSC_2595.JPG resource")

        sourceTexture = (try? textureLoader.newTexture(URL: url, options: [
            .textureUsage: MTLTextureUsage([.shaderRead]).rawValue,
            .SRGB: false
        ])).orFatalError("Failed to load source texture")

        // Calculate dimensions
        width = Int(drawableSize.width)
        height = Int(drawableSize.height)

        // Create rotation matrix
        let angle = time
        let cosA = cos(angle)
        let sinA = sin(angle)
        let rotationMatrix = simd_float3x3(
            SIMD3<Float>(cosA, sinA, 0),
            SIMD3<Float>(-sinA, cosA, 0),
            SIMD3<Float>(0, 0, 1)
        )

        // Create uniforms
        let uniforms = TileAverageUniforms(
            resolution: SIMD2<UInt32>(UInt32(width), UInt32(height)),
            tileSize: UInt32(tileSize),
            _padding: 0,
            transform: rotationMatrix
        )

        uniformsBuffer = try device.makeBuffer(
            view: .init(count: 1),
            values: [uniforms],
            options: .storageModeShared
        )
    }

    var body: some Element {
        get throws {
            try RenderPass {
                // Full-screen triangle vertices
                // swiftlint:disable comma
                let vertices: [SIMD2<Float>] = [
                    [-1, -1],
                    [ 3, -1],
                    [-1,  3]
                ]
                // swiftlint:enable comma

                // Step 1: Compute per-tile averages and write to imageblock
                try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                    Draw { encoder in
                        encoder.setVertexUnsafeBytes(of: vertices, index: 0)
                        encoder.setFragmentTexture(sourceTexture, index: 0)
                        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                    }
                    .parameter("uniforms", functionType: .vertex, buffer: uniformsBuffer, offset: 0)
                    .parameter("uniforms", functionType: .fragment, buffer: uniformsBuffer, offset: 0)
                }
                .vertexDescriptor(vertexShader.inferredVertexDescriptor())

                // Step 2: Blit imageblock to color attachment (framebuffer)
                try RenderPipeline(vertexShader: vertexShader, fragmentShader: blitFragmentShader) {
                    Draw { encoder in
                        encoder.setVertexUnsafeBytes(of: vertices, index: 0)
                        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                    }
                    .parameter("uniforms", functionType: .vertex, buffer: uniformsBuffer, offset: 0)
                }
                .vertexDescriptor(vertexShader.inferredVertexDescriptor())
            }
            .renderPassDescriptorModifier { descriptor in
                // Configure for imageblock usage
                descriptor.tileWidth = tileSize
                descriptor.tileHeight = tileSize
                // half4 = 4 * 2 bytes = 8 bytes, but needs to be aligned to 16 bytes
                descriptor.imageblockSampleLength = 16
            }
        }
    }
}

struct TileAverageUniforms {
    var resolution: SIMD2<UInt32>
    var tileSize: UInt32
    var _padding: UInt32
    var transform: simd_float3x3
}
