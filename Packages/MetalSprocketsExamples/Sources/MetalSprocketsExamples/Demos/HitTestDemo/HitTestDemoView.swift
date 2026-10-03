import DemoKit
import GeometryLite3D
import Interaction3D
import Metal
import MetalKit
import MetalSprockets
import MetalSprocketsAddOns
import MetalSprocketsExampleShaders
import MetalSprocketsSupport
import MetalSprocketsUI
import MetalSupport
import simd
import SwiftUI

enum HitTestVisualizationMode: String, CaseIterable {
    case none = "None"
    case geometryID = "Geometry ID"
    case instanceID = "Instance ID"
    case triangleID = "Triangle ID"
    case depth = "Depth"
    case triangleCoordinates = "Triangle Coords"
}

public struct HitTestDemoView: View {
    @State
    private var mesh = MTKMesh.teapot().relabeled("teapot")
    @State
    private var modelMatrix: float4x4 = .identity
    @State
    private var material = BlinnPhongMaterial(
        ambient: .color([0.2, 0.2, 0.2]),
        diffuse: .color([0.7, 0.3, 0.3]),
        specular: .color([1.0, 1.0, 1.0]),
        shininess: 32
    )
    @State
    private var lighting: Lighting
    @State
    private var skyboxTexture: MTLTexture
    @State
    private var projection: any ProjectionProtocol = PerspectiveProjection()
    @State
    private var cameraMatrix: simd_float4x4 = .init(translation: [0, 4, 8])
    @State
    private var hitTestTextures: HitTestTextures?
    @State
    private var lastHitResult: HitTestResult?
    @State
    private var drawableSize: CGSize = .zero
    @State
    private var visualizationMode: HitTestVisualizationMode = .none
    @State
    private var renderViewSize: CGSize = .zero
    /// Hit queries are answered from a copy made inside the frame, so the CPU never reads textures the GPU is writing.
    @State
    private var pendingHitLocation: SIMD2<Int>?
    @State
    private var pendingGridExport = false
    @State
    private var resourceCollection: ResourceCollection?

    private let device: MTLDevice

    public init() {
        self.lighting = (try? Lighting.demo()).orFatalError("Failed to load demo lighting")
        let device = _MTLCreateSystemDefaultDevice()
        self.device = device
        let skyboxCrossTexture = (try? device.makeTexture(name: "Skybox", bundle: .main))
            .orFatalError("Failed to load skybox cross texture")
        self.skyboxTexture = (try? device.makeTextureCubeFromCrossTexture(texture: skyboxCrossTexture))
            .orFatalError("Failed to build skybox cube texture")
    }

    public var body: some View {
        ZStack {
            Color.clear
            WorldView(projection: $projection, cameraMatrix: $cameraMatrix) {
                TimelineView(.animation) { _ in
                    // swiftlint:disable:next accessibility_trait_for_button
                    RenderView { _, drawableSize in
                        let projectionMatrix = projection.projectionMatrix(for: drawableSize)
                        let viewMatrix = cameraMatrix.inverse
                        // Main rendering pass
                        try RenderPass {
                            // Render teapot with Blinn-Phong shading
                            try BlinnPhongShader {
                                try Draw(mesh: mesh)
                                .vertexBuffers(of: mesh)
                                .blinnPhongMaterial(material)
                                .blinnPhongMatrices(projectionMatrix: projectionMatrix, viewMatrix: viewMatrix, modelMatrix: modelMatrix, cameraMatrix: cameraMatrix)
                                .lighting(lighting)
                            }
                            .vertexDescriptor(mesh.vertexDescriptor)
                            .depthCompare(function: .less, enabled: true)
                        }
                        // Covers the whole submission.
                        .useResourceCollection(resourceCollection ?? makeResourceCollection())

                        // Hit test rendering pass (to offscreen textures)
                        if let textures = hitTestTextures {
                            try RenderPass {
                                // The previous frame's readback copy and visualization may still read these targets.
                                QueueBarrier(after: [.blit, .fragment], before: .fragment)
                                try HitTestShader {
                                    Draw(mesh: mesh)
                                    .vertexBuffers(of: mesh)
                                    .hitTestMatrices(projectionMatrix: projectionMatrix, viewMatrix: viewMatrix, modelMatrix: modelMatrix)
                                    .geometryID(0)
                                }
                                .vertexDescriptor(mesh.vertexDescriptor)
                                .depthCompare(function: .less, enabled: true)
                            }
                            .renderPassDescriptorModifier { descriptor in
                                descriptor.colorAttachments[0].texture = textures.geometryIDTexture
                                descriptor.colorAttachments[0].loadAction = .clear
                                descriptor.colorAttachments[0].clearColor = MTLClearColor(red: -1, green: 0, blue: 0, alpha: 0)
                                descriptor.colorAttachments[0].storeAction = .store

                                descriptor.colorAttachments[1].texture = textures.instanceIDTexture
                                descriptor.colorAttachments[1].loadAction = .clear
                                descriptor.colorAttachments[1].clearColor = MTLClearColor(red: -1, green: 0, blue: 0, alpha: 0)
                                descriptor.colorAttachments[1].storeAction = .store

                                descriptor.colorAttachments[2].texture = textures.triangleIDTexture
                                descriptor.colorAttachments[2].loadAction = .clear
                                descriptor.colorAttachments[2].clearColor = MTLClearColor(red: -1, green: 0, blue: 0, alpha: 0)
                                descriptor.colorAttachments[2].storeAction = .store

                                descriptor.colorAttachments[3].texture = textures.depthTexture
                                descriptor.colorAttachments[3].loadAction = .clear
                                descriptor.colorAttachments[3].clearColor = MTLClearColor(red: 1.0, green: 0, blue: 0, alpha: 0)
                                descriptor.colorAttachments[3].storeAction = .store

                                descriptor.colorAttachments[4].texture = textures.triangleCoordinatesTexture
                                descriptor.colorAttachments[4].loadAction = .clear
                                descriptor.colorAttachments[4].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
                                descriptor.colorAttachments[4].storeAction = .store

                                descriptor.depthAttachment.texture = textures.depthStencilTexture
                                descriptor.depthAttachment.loadAction = .clear
                                descriptor.depthAttachment.clearDepth = 1.0
                                descriptor.depthAttachment.storeAction = .dontCare
                            }

                            if pendingHitLocation != nil || pendingGridExport {
                                try readbackPass(textures: textures)
                            }
                        }

                        // Visualize the selected hit test texture if requested
                        if visualizationMode != .none, let textures = hitTestTextures {
                            let (sourceTexture, colorTransformName): (MTLTexture, String) = switch visualizationMode {
                            case .none:
                                fatalError("Should not reach here")
                            case .geometryID:
                                (textures.geometryIDTexture, "colorTransformHitTestVisualize")
                            case .instanceID:
                                (textures.instanceIDTexture, "colorTransformHitTestVisualize")
                            case .triangleID:
                                (textures.triangleIDTexture, "colorTransformHitTestVisualize")
                            case .depth:
                                (textures.depthTexture, "colorTransformDepthVisualize")
                            case .triangleCoordinates:
                                (textures.triangleCoordinatesTexture, "colorTransformIdentity")
                            }

                            try RenderPass {
                                // Samples what the hit test pass just wrote.
                                QueueBarrier(after: .fragment, before: .fragment)
                                try TextureBillboardPipeline(specifierA: .texture2D(sourceTexture), specifierB: .color([0, 0, 0]), colorTransformFunctionName: colorTransformName)
                            }
                        }
                    }
                    .coordinateSpace(name: "RenderView")
                    .frame(width: 512, height: 512)
                    .metalDepthStencilPixelFormat(.depth32Float)
                    .onUsableDrawableSizeChange { size in
                        drawableSize = size
                        replaceHitTestTextures(HitTestTextures(device: device, size: size))
                    }
                    .onAppear {
                        if hitTestTextures == nil {
                            let size = CGSize(width: 1_920, height: 1_080) // Default size
                            drawableSize = size
                            replaceHitTestTextures(HitTestTextures(device: device, size: size))
                        }
                    }
                    .onTapGesture(coordinateSpace: .named("RenderView")) { location in
                        performHitTest(at: location)
                    }
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            performHitTest(at: location)
                        case .ended:
                            break
                        }
                    }
                    .onGeometryChange(for: CGSize.self) { geometry in
                        geometry.size
                    } action: { newSize in
                        renderViewSize = newSize
                    }
                }
            }
            .overlay(alignment: .topLeading) {
                Group {
                    if let result = lastHitResult, result.geometryID >= 0 {
                        let locationStr = "(\(Int(result.location.x)), \(Int(result.location.y)))"
                        let depthStr = result.depth.formatted(.number.precision(.fractionLength(3)))
                        let baryStr = "(\(result.triangleCoords.x.formatted(.number.precision(.fractionLength(2)))), \(result.triangleCoords.y.formatted(.number.precision(.fractionLength(2)))), \(result.triangleCoords.z.formatted(.number.precision(.fractionLength(2)))))"
                        VStack(alignment: .leading, spacing: 6) {
                            hitTestRow("Location", value: locationStr)
                            hitTestRow("Geometry ID", value: "\(result.geometryID)")
                            hitTestRow("Instance ID", value: "\(result.instanceID)")
                            hitTestRow("Triangle ID", value: "\(result.triangleID)")
                            hitTestRow("Depth", value: depthStr)
                            hitTestRow("Barycentric", value: baryStr)
                        }
                    } else {
                        Text("No Hit")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.green.opacity(0.6))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.6))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(12)
                .allowsHitTesting(false)
            }
        }
        .background(.black.opacity(0.8))
        .demoConfiguration {
            Form {
                Picker("Visualization", selection: $visualizationMode) {
                    ForEach(HitTestVisualizationMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(MenuPickerStyle())

                Button("Export Hit Grid") {
                    performFullGridHitTest()
                }
            }
            .formStyle(.grouped)
        }
    }

    @ViewBuilder
    func hitTestRow(_ label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.gray)
                .frame(width: 80, alignment: .trailing)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.green)
        }
    }

    func performHitTest(at location: CGPoint) {
        guard let textures = hitTestTextures else {
            return
        }
        guard renderViewSize.width > 0, renderViewSize.height > 0 else {
            return
        }

        // Convert location from view coordinates to normalized [0...1] range
        // The location is in the RenderView's coordinate space
        let normalizedX = location.x / renderViewSize.width
        let normalizedY = location.y / renderViewSize.height

        // Convert normalized coordinates to texture pixel coordinates
        let metalX = Int(normalizedX * textures.size.width)
        let metalY = Int(normalizedY * textures.size.height)

        // Ensure coordinates are within texture bounds
        guard metalX >= 0, metalX < Int(textures.size.width), metalY >= 0, metalY < Int(textures.size.height) else {
            return
        }

        pendingHitLocation = [metalX, metalY]
    }

    func performFullGridHitTest() {
        pendingGridExport = true
    }

    // Copies the requested pixels into a buffer that only this frame writes, after the hit test pass, and reads it on completion.
    @ElementBuilder
    private func readbackPass(textures: HitTestTextures) throws -> some Element {
        let readback = try HitTestReadback(device: device, textures: textures, location: pendingHitLocation, exportGrid: pendingGridExport)
        try ComputePass(label: "Hit Test Readback") {
            QueueBarrier(after: .fragment, before: .blit)
            ComputeCommand { encoder in
                readback.encode(encoder)
            }
            .useComputeResources(readback.resources, usage: [.read, .write])
        }
        .onSubmissionCommitted { _ in
            if pendingHitLocation == readback.location {
                pendingHitLocation = nil
            }
            if readback.gridBuffer != nil {
                pendingGridExport = false
            }
        }
        // The perform: label selects the isolated overload; a trailing closure resolves to the @Sendable one.
        // swiftlint:disable:next trailing_closure
        .onCommandBufferCompleted(perform: { result in
            guard result.outcome == .completed else {
                return
            }
            if let hit = readback.hitResult() {
                lastHitResult = hit
            }
            if let gridBuffer = readback.gridBuffer {
                exportGrid(from: gridBuffer, textures: textures)
            }
        })
    }

    private func makeResourceCollection() throws -> ResourceCollection {
        let collection = try ResourceCollection(device: device)
        try collection.register(mesh.buffers + lighting.argumentBufferResources + (hitTestTextures?.resources ?? []))
        resourceCollection = collection
        return collection
    }

    private func replaceHitTestTextures(_ newTextures: HitTestTextures) {
        do {
            try resourceCollection?.replace(hitTestTextures?.resources ?? [], with: newTextures.resources)
        } catch {
            assertionFailure("\(error)")
        }
        hitTestTextures = newTextures
    }

    private func exportGrid(from gridBuffer: MTLBuffer, textures: HitTestTextures) {
        let width = Int(textures.size.width)
        let height = Int(textures.size.height)
        let bytesPerRow = textures.bytesPerRow

        let geometryIDPtr = gridBuffer.contents().assumingMemoryBound(to: Int32.self)

        // Create a grid of hit/no-hit values
        var hitGrid = Array(repeating: Array(repeating: false, count: width), count: height)
        var hitCount = 0
        var minY = Int.max
        var maxY = Int.min
        var minX = Int.max
        var maxX = Int.min

        // Sample every pixel
        for y in 0..<height {
            for x in 0..<width {
                let pixelOffset = y * (bytesPerRow / 4) + x
                let geometryID = geometryIDPtr[pixelOffset]

                // Check if we hit geometry (geometryID >= 0 means hit)
                let hit = geometryID >= 0
                hitGrid[y][x] = hit

                if hit {
                    hitCount += 1
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                }
            }
        }

        // Write PGM file
        writePGMFile(grid: hitGrid, width: width, height: height)
    }

    func writePGMFile(grid: [[Bool]], width: Int, height: Int) {
        // Create PGM content
        var pgmContent = "P2\n"  // ASCII grayscale format
        pgmContent += "\(width) \(height)\n"
        pgmContent += "255\n"  // Max gray value

        // Write pixel values (255 for hit, 0 for no hit)
        for y in 0..<height {
            for x in 0..<width {
                let value = grid[y][x] ? 255 : 0
                pgmContent += "\(value) "
            }
            pgmContent += "\n"
        }

        // Write to temp directory
        let tempDir = FileManager.default.temporaryDirectory
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "hit_test_grid_\(timestamp).pgm"
        let filePath = tempDir.appendingPathComponent(filename).path

        do {
            try pgmContent.write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
            fatalError("Failed to write PGM file: \(error)")
        }
    }
}

struct HitTestResult {
    let location: CGPoint
    let geometryID: Int32
    let instanceID: Int32
    let triangleID: Int32
    let depth: Float
    let triangleCoords: SIMD3<Float>
}

/// One frame's readback: single pixels for a hit query, and the whole geometry ID texture for an export.
struct HitTestReadback {
    let textures: HitTestTextures
    let location: SIMD2<Int>?
    let pixelBuffer: MTLBuffer?
    let gridBuffer: MTLBuffer?

    // Byte offsets in pixelBuffer.
    private static let geometryIDOffset = 0
    private static let instanceIDOffset = 4
    private static let triangleIDOffset = 8
    private static let depthOffset = 12
    private static let triangleCoordinatesOffset = 16
    private static let pixelBufferLength = 32

    init(device: MTLDevice, textures: HitTestTextures, location: SIMD2<Int>?, exportGrid: Bool) throws {
        self.textures = textures
        self.location = location
        pixelBuffer = try location.map { _ in
            try device.makeBuffer(length: Self.pixelBufferLength, options: .storageModeShared).orThrow(.resourceCreationFailure("Hit test pixel readback"))
        }
        gridBuffer = try exportGrid ? device.makeBuffer(length: textures.geometryIDBuffer.length, options: .storageModeShared).orThrow(.resourceCreationFailure("Hit test grid readback")) : nil
    }

    var resources: [any MTLResource] {
        textures.resources + [pixelBuffer, gridBuffer].compactMap(\.self)
    }

    func encode(_ encoder: any MTL4ComputeCommandEncoder) {
        if let location, let pixelBuffer {
            let pixels: [(MTLTexture, Int, Int)] = [
                (textures.geometryIDTexture, Self.geometryIDOffset, 4),
                (textures.instanceIDTexture, Self.instanceIDOffset, 4),
                (textures.triangleIDTexture, Self.triangleIDOffset, 4),
                (textures.depthTexture, Self.depthOffset, 4),
                (textures.triangleCoordinatesTexture, Self.triangleCoordinatesOffset, 16)
            ]
            for (texture, offset, bytesPerPixel) in pixels {
                encoder.copy(
                    sourceTexture: texture,
                    sourceSlice: 0,
                    sourceLevel: 0,
                    sourceOrigin: MTLOrigin(x: location.x, y: location.y, z: 0),
                    sourceSize: MTLSize(width: 1, height: 1, depth: 1),
                    destinationBuffer: pixelBuffer,
                    destinationOffset: offset,
                    destinationBytesPerRow: bytesPerPixel,
                    destinationBytesPerImage: bytesPerPixel
                )
            }
        }
        if let gridBuffer {
            let size = MTLSize(width: Int(textures.size.width), height: Int(textures.size.height), depth: 1)
            encoder.copy(
                sourceTexture: textures.geometryIDTexture,
                sourceSlice: 0,
                sourceLevel: 0,
                sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                sourceSize: size,
                destinationBuffer: gridBuffer,
                destinationOffset: 0,
                destinationBytesPerRow: textures.bytesPerRow,
                destinationBytesPerImage: textures.bytesPerRow * size.height
            )
        }
    }

    func hitResult() -> HitTestResult? {
        guard let location, let pixelBuffer else {
            return nil
        }
        let bytes = UnsafeRawPointer(pixelBuffer.contents())
        let coordinates = bytes.load(fromByteOffset: Self.triangleCoordinatesOffset, as: SIMD4<Float>.self)
        return HitTestResult(
            location: CGPoint(x: location.x, y: location.y),
            geometryID: bytes.load(fromByteOffset: Self.geometryIDOffset, as: Int32.self),
            instanceID: bytes.load(fromByteOffset: Self.instanceIDOffset, as: Int32.self),
            triangleID: bytes.load(fromByteOffset: Self.triangleIDOffset, as: Int32.self),
            depth: bytes.load(fromByteOffset: Self.depthOffset, as: Float.self),
            triangleCoords: SIMD3<Float>(coordinates.x, coordinates.y, coordinates.z)
        )
    }
}

struct HitTestTextures {
    let geometryIDTexture: MTLTexture
    let instanceIDTexture: MTLTexture
    let triangleIDTexture: MTLTexture
    let depthTexture: MTLTexture
    let triangleCoordinatesTexture: MTLTexture
    let depthStencilTexture: MTLTexture
    let geometryIDBuffer: MTLBuffer
    let instanceIDBuffer: MTLBuffer
    let triangleIDBuffer: MTLBuffer
    let depthBuffer: MTLBuffer
    let triangleCoordinatesBuffer: MTLBuffer
    let size: CGSize
    let bytesPerRow: Int

    var resources: [any MTLResource] {
        [
            geometryIDTexture, instanceIDTexture, triangleIDTexture, depthTexture, triangleCoordinatesTexture, depthStencilTexture,
            geometryIDBuffer, instanceIDBuffer, triangleIDBuffer, depthBuffer, triangleCoordinatesBuffer
        ]
    }

    init(device: MTLDevice, size: CGSize) {
        self.size = size
        let width = Int(size.width)
        let height = Int(size.height)

        // Calculate bytes per row with proper alignment (256 byte alignment is typical)
        let alignment = 256
        let bytesPerPixelR32 = 4 // r32Sint/r32Float
        let bytesPerPixelRGBA32F = 16 // rgba32Float
        self.bytesPerRow = ((width * bytesPerPixelR32 + alignment - 1) / alignment) * alignment
        let bytesPerRowRGBA = ((width * bytesPerPixelRGBA32F + alignment - 1) / alignment) * alignment

        // Create buffers for each texture
        let bufferLength = bytesPerRow * height
        let bufferLengthRGBA = bytesPerRowRGBA * height

        self.geometryIDBuffer = device.makeBuffer(length: bufferLength, options: []).orFatalError("Failed to create geometryID buffer")
        self.instanceIDBuffer = device.makeBuffer(length: bufferLength, options: []).orFatalError("Failed to create instanceID buffer")
        self.triangleIDBuffer = device.makeBuffer(length: bufferLength, options: []).orFatalError("Failed to create triangleID buffer")
        self.depthBuffer = device.makeBuffer(length: bufferLength, options: []).orFatalError("Failed to create depth buffer")
        self.triangleCoordinatesBuffer = device.makeBuffer(length: bufferLengthRGBA, options: []).orFatalError("Failed to create triangleCoordinates buffer")

        // Create texture descriptors
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.width = width
        textureDescriptor.height = height
        textureDescriptor.storageMode = .shared
        textureDescriptor.usage = [.renderTarget, .shaderRead]

        // Create buffer-backed textures for r32Sint format
        textureDescriptor.pixelFormat = .r32Sint
        self.geometryIDTexture = geometryIDBuffer.makeTexture(descriptor: textureDescriptor, offset: 0, bytesPerRow: bytesPerRow).orFatalError("Failed to create geometryID texture")
        self.instanceIDTexture = instanceIDBuffer.makeTexture(descriptor: textureDescriptor, offset: 0, bytesPerRow: bytesPerRow).orFatalError("Failed to create instanceID texture")
        self.triangleIDTexture = triangleIDBuffer.makeTexture(descriptor: textureDescriptor, offset: 0, bytesPerRow: bytesPerRow).orFatalError("Failed to create triangleID texture")

        // Create buffer-backed texture for r32Float format
        textureDescriptor.pixelFormat = .r32Float
        self.depthTexture = depthBuffer.makeTexture(descriptor: textureDescriptor, offset: 0, bytesPerRow: bytesPerRow).orFatalError("Failed to create depth texture")

        // Create buffer-backed texture for rgba32Float format
        textureDescriptor.pixelFormat = .rgba32Float
        self.triangleCoordinatesTexture = triangleCoordinatesBuffer.makeTexture(descriptor: textureDescriptor, offset: 0, bytesPerRow: bytesPerRowRGBA).orFatalError("Failed to create triangleCoordinates texture")

        // Depth stencil texture cannot be buffer-backed, create normally
        textureDescriptor.pixelFormat = .depth32Float
        textureDescriptor.usage = .renderTarget
        self.depthStencilTexture = device.makeTexture(descriptor: textureDescriptor).orFatalError("Failed to create depthStencil texture")
    }
}
