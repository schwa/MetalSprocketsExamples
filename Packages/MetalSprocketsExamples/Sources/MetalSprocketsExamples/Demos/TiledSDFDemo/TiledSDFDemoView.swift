import DemoKit
import MetalKit
import MetalSprockets
import MetalSprocketsExampleShaders
import MetalSprocketsSupport
import MetalSprocketsUI
import MetalSupport
import simd
import SwiftUI

public struct TiledSDFDemoView: View {
    @State
    private var time: Float = 0.0

    @State
    private var drawableSize: CGSize = .zero

    @State
    private var primitiveCount: Int = 50

    @State
    private var tileSize: Int = 16

    @State
    private var visualMode: VisualizationMode = .normal

    @State
    private var animatePrimitives: Bool = true

    @State
    private var showStats: Bool = true

    private let maxPrimitives = 200

    public init() {
        // Intentionally empty
    }

    public var body: some View {
        VStack(spacing: 0) {
            TimelineView(.animation) { timeline in
                renderContent()
                    .onChange(of: timeline.date) { _, _ in
                        if animatePrimitives {
                            time += 0.016
                        }
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
            if showStats {
                let tileCountX = Int(drawableSize.width) / tileSize
                let tileCountY = Int(drawableSize.height) / tileSize
                let totalTiles = tileCountX * tileCountY

                HStack {
                    Text("Primitives: \(primitiveCount)")
                    Text("•")
                    Text("Tiles: \(totalTiles)")
                    Text("•")
                    Text("Tile size: \(tileSize)×\(tileSize)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            LabeledContent("Primitives") {
                HStack {
                    Slider(
                        value: Binding(
                            get: { Double(primitiveCount) },
                            set: { primitiveCount = Int($0) }
                        ),
                        in: 10...Double(maxPrimitives)
                    )
                    .accessibilityLabel("Primitives")
                    Text("\(primitiveCount)")
                        .monospacedDigit()
                        .frame(minWidth: 40)
                }
            }

            LabeledContent("Tile Size") {
                Picker("", selection: $tileSize) {
                    Text("16×16").tag(16)
                    Text("32×32").tag(32)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Tile Size")
            }

            LabeledContent("Visualization") {
                Picker("", selection: $visualMode) {
                    Text("Normal").tag(VisualizationMode.normal)
                    Text("Distance").tag(VisualizationMode.distance)
                    Text("Contours").tag(VisualizationMode.contours)
                    Text("Tiles").tag(VisualizationMode.tiles)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Visualization")
            }

            Toggle("Animate", isOn: $animatePrimitives)
            Toggle("Show Stats", isOn: $showStats)
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func renderContent() -> some View {
        RenderView { _, size in
            try TiledSDFPipeline(
                time: time,
                drawableSize: size,
                primitiveCount: primitiveCount,
                maxPrimitives: maxPrimitives,
                tileSize: tileSize,
                visualMode: visualMode
            )
        }
    }
}

enum VisualizationMode: Int {
    case normal = 0
    case distance = 1
    case contours = 2
    case tiles = 3
}

struct TiledSDFPipeline: Element {
    let time: Float
    let drawableSize: CGSize
    let primitiveCount: Int
    let maxPrimitives: Int
    let tileSize: Int
    let visualMode: VisualizationMode

    @MSState
    var cullKernel: ComputeKernel

    @MSState
    var vertexShader: VertexShader

    @MSState
    var fragmentShader: FragmentShader

    @MSState
    var blitFragmentShader: FragmentShader

    let primitivesBuffer: MTLBuffer
    let tilePrimitivesBuffer: MTLBuffer
    let tilePrimitiveCountsBuffer: MTLBuffer
    let uniformsBuffer: MTLBuffer

    let width: Int
    let height: Int
    let tilesX: Int
    let tilesY: Int
    let maxPrimitivesPerTile: Int

    init(time: Float, drawableSize: CGSize, primitiveCount: Int, maxPrimitives: Int, tileSize: Int, visualMode: VisualizationMode) throws {
        self.time = time
        self.drawableSize = drawableSize
        self.primitiveCount = primitiveCount
        self.maxPrimitives = maxPrimitives
        self.tileSize = tileSize
        self.visualMode = visualMode

        let library = try ShaderNamespace.examples("TiledSDFShader")
        cullKernel = try library.cullPrimitivesToTiles
        vertexShader = try library.function(named: "sdfVertex", type: VertexShader.self)
        fragmentShader = try library.function(named: "sdfFragment", type: FragmentShader.self)
        blitFragmentShader = try library.function(named: "sdfBlitFragment", type: FragmentShader.self)

        let device = _MTLCreateSystemDefaultDevice()

        // Calculate tile grid dimensions
        width = Int(drawableSize.width)
        height = Int(drawableSize.height)
        tilesX = (width + tileSize - 1) / tileSize
        tilesY = (height + tileSize - 1) / tileSize
        let totalTiles = tilesX * tilesY
        maxPrimitivesPerTile = 64

        // Generate primitives
        let primitives = Self.generatePrimitives(count: primitiveCount, maxPrimitives: maxPrimitives, time: time, size: drawableSize)

        // Create buffers
        primitivesBuffer = try device.makeBuffer(
            view: .init(count: maxPrimitives),
            values: primitives,
            options: .storageModeShared
        )

        // Tile primitive indices buffer
        tilePrimitivesBuffer = try device
            .makeBuffer(
                length: totalTiles * maxPrimitivesPerTile * MemoryLayout<UInt32>.size,
                options: .storageModeShared
            )
            .orThrow(.resourceCreationFailure("Failed to create tile primitives buffer"))

        // Tile primitive counts buffer
        tilePrimitiveCountsBuffer = try device.makeBuffer(length: totalTiles * MemoryLayout<UInt32>.size, options: .storageModeShared)
            .orThrow(.resourceCreationFailure("Failed to create tile counts buffer"))

        // Uniforms
        let uniforms = TiledSDFUniforms(
            resolution: SIMD2<UInt32>(UInt32(width), UInt32(height)),
            tileSize: UInt32(tileSize),
            tilesX: UInt32(tilesX),
            tilesY: UInt32(tilesY),
            primitiveCount: UInt32(primitiveCount),
            maxPrimitivesPerTile: UInt32(maxPrimitivesPerTile),
            visualMode: UInt32(visualMode.rawValue),
            time: time
        )

        uniformsBuffer = try device.makeBuffer(
            view: .init(count: 1),
            values: [uniforms],
            options: .storageModeShared
        )

        // Zero out tile counts
        _ = memset(tilePrimitiveCountsBuffer.contents(), 0, tilePrimitiveCountsBuffer.length)
    }

    var body: some Element {
        get throws {
            try Group {
                // Pass 1: Cull primitives to tiles (compute shader)
                try ComputePass {
                    try ComputePipeline(computeKernel: cullKernel) {
                        let threadsPerGrid = MTLSize(width: primitiveCount, height: 1, depth: 1)

                        try ComputeDispatch(threadsPerGrid: threadsPerGrid)
                            .parameter("primitives", buffer: primitivesBuffer)
                            .parameter("tilePrimitives", buffer: tilePrimitivesBuffer)
                            .parameter("tilePrimitiveCounts", buffer: tilePrimitiveCountsBuffer)
                            .parameter("uniforms", buffer: uniformsBuffer)
                    }
                }

                // Pass 2: Evaluate SDF and blit to screen (render pass with tile memory)
                try RenderPass {
                    // Full-screen triangle vertices (shared by both pipelines)
                    // swiftlint:disable comma
                    let vertices: [SIMD2<Float>] = [
                        [-1, -1],
                        [ 3, -1],
                        [-1,  3]
                    ]
                    // swiftlint:enable comma

                    // Step 1: Write SDF results to imageblock (tile memory)
                    try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                        Draw { encoder in
                            encoder.setVertexUnsafeBytes(of: vertices, index: 0)
                            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                        }
                        .parameter("uniforms", functionType: .vertex, buffer: uniformsBuffer, offset: 0)
                        .parameter("primitives", functionType: .fragment, buffer: primitivesBuffer, offset: 0)
                        .parameter("tilePrimitives", functionType: .fragment, buffer: tilePrimitivesBuffer, offset: 0)
                        .parameter("tilePrimitiveCounts", functionType: .fragment, buffer: tilePrimitiveCountsBuffer, offset: 0)
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

    static func generatePrimitives(count: Int, maxPrimitives: Int, time: Float, size: CGSize) -> [SDFPrimitive] {
        var primitives: [SDFPrimitive] = []
        primitives.reserveCapacity(maxPrimitives)

        // Use a seeded random for consistency
        var seed: UInt32 = 12_345

        func random() -> Float {
            seed = seed &* 1_103_515_245 &+ 12_345
            return Float(seed % 1_000) / 1_000.0
        }

        for i in 0..<count {
            let t = Float(i) / Float(max(count - 1, 1))

            // Determine primitive type
            let typeRand = random()
            let primitiveType: UInt32
            if typeRand < 0.5 {
                primitiveType = 0 // Circle
            } else if typeRand < 0.8 {
                primitiveType = 1 // Line segment
            } else {
                primitiveType = 2 // Quadratic Bezier
            }

            // Generate position with animation
            let baseX = random() * Float(size.width)
            let baseY = random() * Float(size.height)
            let offsetX = sin(time + t * .pi * 2) * 20
            let offsetY = cos(time + t * .pi * 3) * 20

            var primitive = SDFPrimitive()
            primitive.type = primitiveType

            switch primitiveType {
            case 0: // Circle
                primitive.p0 = SIMD2<Float>(baseX + offsetX, baseY + offsetY)
                primitive.p1 = SIMD2<Float>(10 + random() * 30, 0) // radius in x
                primitive.color = SIMD3<Float>(
                    0.5 + 0.5 * sin(t * .pi * 2),
                    0.5 + 0.5 * sin(t * .pi * 2 + 2.0),
                    0.5 + 0.5 * sin(t * .pi * 2 + 4.0)
                )

            case 1: // Line segment
                primitive.p0 = SIMD2<Float>(baseX + offsetX, baseY + offsetY)
                let angle = random() * .pi * 2
                let length = 30 + random() * 50
                primitive.p1 = primitive.p0 + SIMD2<Float>(cos(angle), sin(angle)) * length
                primitive.p2 = SIMD2<Float>(2 + random() * 4, 0) // width in x
                primitive.color = SIMD3<Float>(
                    0.5 + 0.5 * cos(t * .pi * 2),
                    0.5 + 0.5 * cos(t * .pi * 2 + 2.0),
                    0.5 + 0.5 * cos(t * .pi * 2 + 4.0)
                )

            case 2: // Quadratic Bezier
                primitive.p0 = SIMD2<Float>(baseX + offsetX, baseY + offsetY)
                let angle1 = random() * .pi * 2
                let length1 = 30 + random() * 40
                primitive.p1 = primitive.p0 + SIMD2<Float>(cos(angle1), sin(angle1)) * length1
                let angle2 = random() * .pi * 2
                let length2 = 30 + random() * 40
                primitive.p2 = primitive.p1 + SIMD2<Float>(cos(angle2), sin(angle2)) * length2
                primitive.color = SIMD3<Float>(
                    0.5 + 0.5 * sin(t * .pi * 3),
                    0.5 + 0.5 * cos(t * .pi * 3 + 1.0),
                    0.5 + 0.5 * sin(t * .pi * 3 + 2.0)
                )

            default:
                break
            }

            // Calculate bounding box
            var minX = primitive.p0.x
            var minY = primitive.p0.y
            var maxX = primitive.p0.x
            var maxY = primitive.p0.y

            if primitiveType == 0 { // Circle
                let radius = primitive.p1.x
                minX -= radius
                minY -= radius
                maxX += radius
                maxY += radius
            } else {
                minX = min(minX, primitive.p1.x)
                minY = min(minY, primitive.p1.y)
                maxX = max(maxX, primitive.p1.x)
                maxY = max(maxY, primitive.p1.y)

                if primitiveType == 2 { // Bezier
                    minX = min(minX, primitive.p2.x)
                    minY = min(minY, primitive.p2.y)
                    maxX = max(maxX, primitive.p2.x)
                    maxY = max(maxY, primitive.p2.y)
                }

                // Add margin for line width or curve thickness
                let margin: Float = primitiveType == 1 ? primitive.p2.x : 5.0
                minX -= margin
                minY -= margin
                maxX += margin
                maxY += margin
            }

            primitive.bbox = SIMD4<Float>(minX, minY, maxX, maxY)
            primitives.append(primitive)
        }

        // Pad with dummy primitives
        while primitives.count < maxPrimitives {
            var dummy = SDFPrimitive()
            dummy.type = 0
            // swiftlint:disable:next number_separator
            dummy.bbox = SIMD4<Float>(-1000, -1000, -1000, -1000)
            primitives.append(dummy)
        }

        return primitives
    }
}

struct SDFPrimitive {
    var type: UInt32 = 0          // 0 = circle, 1 = line, 2 = quadratic bezier
    var _padding0: UInt32 = 0
    var _padding1: UInt32 = 0
    var _padding2: UInt32 = 0
    var p0: SIMD2<Float> = .zero  // Circle: center, Line/Bezier: start point
    var p1: SIMD2<Float> = .zero  // Circle: (radius, 0), Line: end point, Bezier: control point
    var p2: SIMD2<Float> = .zero  // Circle: unused, Line: (width, 0), Bezier: end point
    var _padding3: SIMD2<Float> = .zero
    var color: SIMD3<Float> = .zero
    var _padding4: Float = 0
    var bbox: SIMD4<Float> = .zero // min_x, min_y, max_x, max_y
}

struct TiledSDFUniforms {
    var resolution: SIMD2<UInt32>
    var tileSize: UInt32
    var tilesX: UInt32
    var tilesY: UInt32
    var primitiveCount: UInt32
    var maxPrimitivesPerTile: UInt32
    var visualMode: UInt32
    var time: Float
    var _padding: SIMD3<Float> = .zero
}
