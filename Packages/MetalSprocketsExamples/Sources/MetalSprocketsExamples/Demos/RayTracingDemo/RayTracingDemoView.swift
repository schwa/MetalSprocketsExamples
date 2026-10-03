import DemoKit
import GeometryLite3D
import Interaction3D
import Metal
import MetalSprockets
import MetalSprocketsAddOns
import MetalSprocketsExampleShaders
import MetalSprocketsSupport
import MetalSprocketsUI
import MetalSupport
import simd
import SwiftUI

// MARK: - Cornell Box Geometry

/// Hardcoded Cornell box geometry from the classic dataset.
/// All quads are split into two triangles.
@MainActor
private enum CornellBox {
    // Materials indices
    static let materialFloor = 0      // white
    static let materialCeiling = 1    // white
    static let materialBackWall = 2   // white
    static let materialRightWall = 3  // green
    static let materialLeftWall = 4   // red
    static let materialShortBox = 5   // white
    static let materialTallBox = 6    // white
    static let materialLight = 7      // emissive

    static let materials: [TriangleMaterial] = [
        // 0: floor - white
        TriangleMaterial(color: SIMD3<Float>(0.725, 0.71, 0.68), emission: .zero),
        // 1: ceiling - white
        TriangleMaterial(color: SIMD3<Float>(0.725, 0.71, 0.68), emission: .zero),
        // 2: back wall - white
        TriangleMaterial(color: SIMD3<Float>(0.725, 0.71, 0.68), emission: .zero),
        // 3: right wall - green
        TriangleMaterial(color: SIMD3<Float>(0.14, 0.45, 0.091), emission: .zero),
        // 4: left wall - red
        TriangleMaterial(color: SIMD3<Float>(0.63, 0.065, 0.05), emission: .zero),
        // 5: short box - white
        TriangleMaterial(color: SIMD3<Float>(0.725, 0.71, 0.68), emission: .zero),
        // 6: tall box - white
        TriangleMaterial(color: SIMD3<Float>(0.725, 0.71, 0.68), emission: .zero),
        // 7: light - emissive
        TriangleMaterial(color: SIMD3<Float>(0.78, 0.78, 0.78), emission: SIMD3<Float>(17, 12, 4))
    ]

    struct GeometryData {
        var vertices: [SIMD3<Float>]
        var indices: [UInt32]
        var materialIndex: Int
    }

    /// Split a quad (4 vertices) into 2 triangles, returning 6 indices.
    private static func quadIndices(_ a: UInt32, _ b: UInt32, _ c: UInt32, _ d: UInt32) -> [UInt32] {
        [a, b, c, a, c, d]
    }

    // Offset to centre the box at the origin (box Y range is 0..~2)
    static let yOffset: Float = -1.0

    /// Build all geometry groups. Each group = one primitive acceleration structure.
    static func buildGeometries() -> [GeometryData] {
        var geometries: [GeometryData] = []

        // Floor
        let floorVerts: [SIMD3<Float>] = [
            [-1.01, 0.00, 0.99],
            [1.00, 0.00, 0.99],
            [1.00, 0.00, -1.04],
            [-0.99, 0.00, -1.04]
        ]
        geometries.append(GeometryData(vertices: floorVerts, indices: quadIndices(0, 1, 2, 3), materialIndex: materialFloor))

        // Ceiling
        let ceilingVerts: [SIMD3<Float>] = [
            [-1.02, 1.99, 0.99],
            [-1.02, 1.99, -1.04],
            [1.00, 1.99, -1.04],
            [1.00, 1.99, 0.99]
        ]
        geometries.append(GeometryData(vertices: ceilingVerts, indices: quadIndices(0, 1, 2, 3), materialIndex: materialCeiling))

        // Back wall
        let backVerts: [SIMD3<Float>] = [
            [-0.99, 0.00, -1.04],
            [1.00, 0.00, -1.04],
            [1.00, 1.99, -1.04],
            [-1.02, 1.99, -1.04]
        ]
        geometries.append(GeometryData(vertices: backVerts, indices: quadIndices(0, 1, 2, 3), materialIndex: materialBackWall))

        // Right wall (green)
        let rightVerts: [SIMD3<Float>] = [
            [1.00, 0.00, -1.04],
            [1.00, 0.00, 0.99],
            [1.00, 1.99, 0.99],
            [1.00, 1.99, -1.04]
        ]
        geometries.append(GeometryData(vertices: rightVerts, indices: quadIndices(0, 1, 2, 3), materialIndex: materialRightWall))

        // Left wall (red)
        let leftVerts: [SIMD3<Float>] = [
            [-1.01, 0.00, 0.99],
            [-0.99, 0.00, -1.04],
            [-1.02, 1.99, -1.04],
            [-1.02, 1.99, 0.99]
        ]
        geometries.append(GeometryData(vertices: leftVerts, indices: quadIndices(0, 1, 2, 3), materialIndex: materialLeftWall))

        // Short box (5 visible faces)
        let shortBoxFaces: [[SIMD3<Float>]] = [
            // Top
            [[0.53, 0.60, 0.75], [0.70, 0.60, 0.17], [0.13, 0.60, 0.00], [-0.05, 0.60, 0.57]],
            // Left
            [[-0.05, 0.00, 0.57], [-0.05, 0.60, 0.57], [0.13, 0.60, 0.00], [0.13, 0.00, 0.00]],
            // Front
            [[0.53, 0.00, 0.75], [0.53, 0.60, 0.75], [-0.05, 0.60, 0.57], [-0.05, 0.00, 0.57]],
            // Right
            [[0.70, 0.00, 0.17], [0.70, 0.60, 0.17], [0.53, 0.60, 0.75], [0.53, 0.00, 0.75]],
            // Back
            [[0.13, 0.00, 0.00], [0.13, 0.60, 0.00], [0.70, 0.60, 0.17], [0.70, 0.00, 0.17]]
        ]
        for face in shortBoxFaces {
            geometries.append(GeometryData(vertices: face, indices: quadIndices(0, 1, 2, 3), materialIndex: materialShortBox))
        }

        // Tall box (5 visible faces)
        let tallBoxFaces: [[SIMD3<Float>]] = [
            // Top
            [[-0.53, 1.20, 0.09], [0.04, 1.20, -0.09], [-0.14, 1.20, -0.67], [-0.71, 1.20, -0.49]],
            // Left
            [[-0.53, 0.00, 0.09], [-0.53, 1.20, 0.09], [-0.71, 1.20, -0.49], [-0.71, 0.00, -0.49]],
            // Back
            [[-0.71, 0.00, -0.49], [-0.71, 1.20, -0.49], [-0.14, 1.20, -0.67], [-0.14, 0.00, -0.67]],
            // Right
            [[-0.14, 0.00, -0.67], [-0.14, 1.20, -0.67], [0.04, 1.20, -0.09], [0.04, 0.00, -0.09]],
            // Front
            [[0.04, 0.00, -0.09], [0.04, 1.20, -0.09], [-0.53, 1.20, 0.09], [-0.53, 0.00, 0.09]]
        ]
        for face in tallBoxFaces {
            geometries.append(GeometryData(vertices: face, indices: quadIndices(0, 1, 2, 3), materialIndex: materialTallBox))
        }

        // Light
        let lightVerts: [SIMD3<Float>] = [
            [-0.24, 1.98, 0.16],
            [-0.24, 1.98, -0.22],
            [0.23, 1.98, -0.22],
            [0.23, 1.98, 0.16]
        ]
        geometries.append(GeometryData(vertices: lightVerts, indices: quadIndices(0, 1, 2, 3), materialIndex: materialLight))

        return geometries
    }
}

// MARK: - Acceleration Structure Builder

@MainActor
private final class RayTracingResources {
    let device: MTLDevice
    // Only for the one-time acceleration structure build, which waits for completion before anything uses it.
    let commandQueue: MTLCommandQueue
    let kernel: ComputeKernel
    let resourceCollection: ResourceCollection

    // Acceleration structures
    var instanceAccelerationStructure: MTLAccelerationStructure?
    var primitiveAccelerationStructures: [MTLAccelerationStructure] = []

    // Buffers
    var materialBuffer: MTLBuffer?
    var vertexBuffer: MTLBuffer?
    var indexBuffer: MTLBuffer?
    var materialIndexBuffer: MTLBuffer?
    var normalBuffer: MTLBuffer?
    var instanceBuffer: MTLBuffer?

    // Textures
    var accumTexture: MTLTexture?
    var outputTexture: MTLTexture?

    var currentSize: MTLSize = .init()

    init() throws {
        device = _MTLCreateSystemDefaultDevice()
        guard let queue = device.makeCommandQueue() else {
            throw MetalSprocketsError.resourceCreationFailure("Failed to create command queue")
        }
        commandQueue = queue

        let shaderBundle = Bundle.metalSprocketsExampleShaders()
        let library = try ShaderLibrary(bundle: shaderBundle)
        let namespacedLibrary = library.namespaced("RayTracingShaders")
        kernel = try namespacedLibrary.raytrace_kernel
        resourceCollection = try ResourceCollection(device: device)
    }

    func buildAccelerationStructures() throws {
        let geometries = CornellBox.buildGeometries()

        // Collect all vertices and indices into flat buffers
        var allVertices: [SIMD3<Float>] = []
        var allIndices: [UInt32] = []
        var allMaterialIndices: [UInt32] = []
        var allNormals: [SIMD3<Float>] = []

        // Per-geometry vertex/index offsets for building prim accel structures
        struct GeometryRange {
            var vertexOffset: Int
            var indexOffset: Int
            var indexCount: Int
        }
        var ranges: [GeometryRange] = []

        for geo in geometries {
            let vOffset = allVertices.count
            let iOffset = allIndices.count
            allVertices.append(contentsOf: geo.vertices.map { SIMD3<Float>($0.x, $0.y + CornellBox.yOffset, $0.z) })
            // Indices are local to each geometry's vertex array, offset them to global
            allIndices.append(contentsOf: geo.indices.map { $0 + UInt32(vOffset) })
            allMaterialIndices.append(UInt32(geo.materialIndex))
            // Compute quad normal from first 3 vertices (both triangles share the same normal)
            let v0 = geo.vertices[0]
            let v1 = geo.vertices[1]
            let v2 = geo.vertices[2]
            let edge1 = v1 - v0
            let edge2 = v2 - v0
            let normal = simd_normalize(simd_cross(edge1, edge2))
            allNormals.append(normal)
            ranges.append(GeometryRange(vertexOffset: vOffset, indexOffset: iOffset, indexCount: geo.indices.count))
        }

        // Create vertex buffer
        vertexBuffer = device.makeBuffer(bytes: allVertices, length: MemoryLayout<SIMD3<Float>>.stride * allVertices.count, options: .storageModeShared)
        vertexBuffer?.label = "RT Vertex Buffer"

        // Create index buffer
        indexBuffer = device.makeBuffer(bytes: allIndices, length: MemoryLayout<UInt32>.stride * allIndices.count, options: .storageModeShared)
        indexBuffer?.label = "RT Index Buffer"

        // Create material buffer
        materialBuffer = device.makeBuffer(bytes: CornellBox.materials, length: MemoryLayout<TriangleMaterial>.stride * CornellBox.materials.count, options: .storageModeShared)
        materialBuffer?.label = "RT Material Buffer"

        // Create material index buffer (per-geometry)
        materialIndexBuffer = device.makeBuffer(bytes: allMaterialIndices, length: MemoryLayout<UInt32>.stride * allMaterialIndices.count, options: .storageModeShared)
        materialIndexBuffer?.label = "RT Material Index Buffer"

        // Create per-geometry normal buffer
        normalBuffer = device.makeBuffer(bytes: allNormals, length: MemoryLayout<SIMD3<Float>>.stride * allNormals.count, options: .storageModeShared)
        normalBuffer?.label = "RT Normal Buffer"

        // Build one primitive acceleration structure per geometry
        primitiveAccelerationStructures = []

        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw MetalSprocketsError.resourceCreationFailure("Failed to create command buffer")
        }

        var primStructures: [MTLAccelerationStructure] = []

        for (index, range) in ranges.enumerated() {
            let geometryDescriptor = MTLAccelerationStructureTriangleGeometryDescriptor()
            geometryDescriptor.vertexBuffer = vertexBuffer
            geometryDescriptor.vertexBufferOffset = 0
            geometryDescriptor.vertexStride = MemoryLayout<SIMD3<Float>>.stride
            geometryDescriptor.indexBuffer = indexBuffer
            geometryDescriptor.indexBufferOffset = range.indexOffset * MemoryLayout<UInt32>.stride
            geometryDescriptor.indexType = .uint32
            geometryDescriptor.triangleCount = range.indexCount / 3
            geometryDescriptor.opaque = true

            let primDescriptor = MTLPrimitiveAccelerationStructureDescriptor()
            primDescriptor.geometryDescriptors = [geometryDescriptor]

            let sizes = device.accelerationStructureSizes(descriptor: primDescriptor)
            guard let accelStructure = device.makeAccelerationStructure(size: sizes.accelerationStructureSize) else {
                throw MetalSprocketsError.resourceCreationFailure("Failed to create primitive acceleration structure \(index)")
            }
            accelStructure.label = "Primitive AS \(index)"

            guard let scratchBuffer = device.makeBuffer(length: sizes.buildScratchBufferSize, options: .storageModePrivate) else {
                throw MetalSprocketsError.resourceCreationFailure("Failed to create scratch buffer")
            }

            guard let encoder = commandBuffer.makeAccelerationStructureCommandEncoder() else {
                throw MetalSprocketsError.resourceCreationFailure("Failed to create acceleration structure encoder")
            }
            encoder.build(accelerationStructure: accelStructure, descriptor: primDescriptor, scratchBuffer: scratchBuffer, scratchBufferOffset: 0)
            encoder.endEncoding()

            primStructures.append(accelStructure)
        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        primitiveAccelerationStructures = primStructures

        // Build instance acceleration structure
        try buildInstanceAccelerationStructure()
    }

    private func buildInstanceAccelerationStructure() throws {
        let instanceCount = primitiveAccelerationStructures.count

        // Create instance descriptor buffer
        let instanceDescriptorSize = MemoryLayout<MTLAccelerationStructureInstanceDescriptor>.stride
        guard let instBuffer = device.makeBuffer(length: instanceDescriptorSize * instanceCount, options: .storageModeShared) else {
            throw MetalSprocketsError.resourceCreationFailure("Failed to create instance buffer")
        }
        instBuffer.label = "Instance Descriptor Buffer"

        let instanceDescriptors = instBuffer.contents().bindMemory(to: MTLAccelerationStructureInstanceDescriptor.self, capacity: instanceCount)
        for i in 0..<instanceCount {
            instanceDescriptors[i].accelerationStructureIndex = UInt32(i)
            instanceDescriptors[i].options = .opaque
            instanceDescriptors[i].mask = 0xFF
            instanceDescriptors[i].intersectionFunctionTableOffset = 0
            // Identity transform
            var transform = MTLPackedFloat4x3()
            transform.columns.0 = MTLPackedFloat3(1, 0, 0)
            transform.columns.1 = MTLPackedFloat3(0, 1, 0)
            transform.columns.2 = MTLPackedFloat3(0, 0, 1)
            transform.columns.3 = MTLPackedFloat3(0, 0, 0)
            instanceDescriptors[i].transformationMatrix = transform
        }

        instanceBuffer = instBuffer

        let instanceDescriptor = MTLInstanceAccelerationStructureDescriptor()
        instanceDescriptor.instanceDescriptorBuffer = instBuffer
        instanceDescriptor.instanceCount = instanceCount
        instanceDescriptor.instancedAccelerationStructures = primitiveAccelerationStructures

        let sizes = device.accelerationStructureSizes(descriptor: instanceDescriptor)
        guard let accelStructure = device.makeAccelerationStructure(size: sizes.accelerationStructureSize) else {
            throw MetalSprocketsError.resourceCreationFailure("Failed to create instance acceleration structure")
        }
        accelStructure.label = "Instance AS"

        guard let scratchBuffer = device.makeBuffer(length: sizes.buildScratchBufferSize, options: .storageModePrivate) else {
            throw MetalSprocketsError.resourceCreationFailure("Failed to create scratch buffer")
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw MetalSprocketsError.resourceCreationFailure("Failed to create command buffer")
        }

        guard let encoder = commandBuffer.makeAccelerationStructureCommandEncoder() else {
            throw MetalSprocketsError.resourceCreationFailure("Failed to create acceleration structure encoder")
        }
        encoder.build(accelerationStructure: accelStructure, descriptor: instanceDescriptor, scratchBuffer: scratchBuffer, scratchBufferOffset: 0)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        instanceAccelerationStructure = accelStructure
        try resourceCollection.register(
            [vertexBuffer, indexBuffer, materialBuffer, materialIndexBuffer, normalBuffer, instanceBuffer, accelStructure] + primitiveAccelerationStructures
        )
    }

    func ensureTextures(size: MTLSize) throws {
        guard size.width != currentSize.width || size.height != currentSize.height else {
            return
        }
        currentSize = size
        let oldTextures = [accumTexture, outputTexture]
        accumTexture = device.makeTexture2D(pixelFormat: .rgba32Float, width: size.width, height: size.height, storageMode: .private, label: "RT Accumulation")
        outputTexture = device.makeTexture2D(pixelFormat: .rgba8Unorm, width: size.width, height: size.height, label: "RT Output")
        try resourceCollection.replace(oldTextures, with: [accumTexture, outputTexture])
    }
}

// MARK: - Demo View

public struct RayTracingDemoView: View {
    @State private var resources: RayTracingResources?
    @State private var samplesPerPixel: UInt32 = 1
    @State private var maxBounces: UInt32 = 5
    @State private var frameIndex: UInt32 = 0
    @State private var isPaused = false
    @State private var renderSize = CGSize(width: 512, height: 512)
    @State private var cameraMatrix: simd_float4x4 = .init(translation: [0, 0, 3.2])
    @State private var projection: any ProjectionProtocol = PerspectiveProjection()

    public init() {
        // This line intentionally left blank.
    }

    public var body: some View {
        WorldView(projection: $projection, cameraMatrix: $cameraMatrix, tools: [.turntable]) {
            ZStack {
                Color.black
                RenderView { _, _ in
                    if let resources, let outputTexture = resources.outputTexture {
                        try Group {
                            if !isPaused {
                                try traceElement(resources: resources)
                            }
                            try RenderPass {
                                try TextureBillboardPipeline(specifier: .texture2D(outputTexture))
                            }
                        }
                        .useResourceCollection(resources.resourceCollection)
                    }
                }
                .aspectRatio(1.0, contentMode: .fit)
            }
        }
        .task {
            do {
                let res = try RayTracingResources()
                try res.buildAccelerationStructures()
                try res.ensureTextures(size: MTLSize(width: Int(renderSize.width), height: Int(renderSize.height), depth: 1))
                resources = res
            } catch {
                print("Ray tracing setup failed: \(error)")
            }
        }
        .onChange(of: maxBounces) { _, _ in
            frameIndex = 0
        }
        .onChange(of: cameraMatrix) { _, _ in
            frameIndex = 0
        }
        .demoConfiguration {
            Form {
                LabeledContent("Samples") {
                    Text("\(frameIndex)")
                }
                Stepper("Max Bounces: \(maxBounces)", value: $maxBounces, in: 1...10)
                Button(isPaused ? "Resume" : "Pause") {
                    isPaused.toggle()
                }
                Button("Reset") {
                    frameIndex = 0
                }
            }
            .formStyle(.grouped)
        }
    }

    // One progressive sample per frame, on the RenderView's queue, so it is ordered against the frames that display it.
    @ElementBuilder
    private func traceElement(resources: RayTracingResources) throws -> some Element {
        if let instanceAccelerationStructure = resources.instanceAccelerationStructure,
           let materialBuffer = resources.materialBuffer,
           let vertexBuffer = resources.vertexBuffer,
           let indexBuffer = resources.indexBuffer,
           let materialIndexBuffer = resources.materialIndexBuffer,
           let normalBuffer = resources.normalBuffer,
           let accumTexture = resources.accumTexture,
           let outputTexture = resources.outputTexture {
            let size = resources.currentSize
            let tracedFrameIndex = frameIndex
            try ComputePass(label: "Ray Trace") {
                // Accumulates into the previous sample, and overwrites the output the previous frame sampled.
                QueueBarrier(after: [.dispatch, .fragment], before: .dispatch)
                try ComputePipeline(computeKernel: resources.kernel) {
                    try ComputeDispatch(threadsPerGrid: size, threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
                        .parameter("uniforms", value: uniforms(size: size, frameIndex: tracedFrameIndex))
                        .parameter("accelerationStructure", accelerationStructure: instanceAccelerationStructure)
                        .parameter("materials", buffer: materialBuffer)
                        .parameter("vertices", buffer: vertexBuffer)
                        .parameter("indices", buffer: indexBuffer)
                        .parameter("materialIndices", buffer: materialIndexBuffer)
                        .parameter("normals", buffer: normalBuffer)
                        .parameter("accumTexture", texture: accumTexture)
                        .parameter("outputTexture", texture: outputTexture)
                }
            }
            .barrierAfterPass(after: .dispatch, beforeQueueStages: .fragment)
            .onSubmissionCommitted { _ in
                // A camera or setting change may have reset the count since this frame was built.
                if frameIndex == tracedFrameIndex {
                    frameIndex += 1
                }
            }
        }
    }

    private func uniforms(size: MTLSize, frameIndex: UInt32) -> RayTracingUniforms {
        // Derive camera vectors from cameraMatrix
        let camMatrix = cameraMatrix
        let cameraPosition = SIMD3<Float>(camMatrix.columns.3.x, camMatrix.columns.3.y, camMatrix.columns.3.z)
        let cameraForward = -normalize(SIMD3<Float>(camMatrix.columns.2.x, camMatrix.columns.2.y, camMatrix.columns.2.z))
        let cameraRight = normalize(SIMD3<Float>(camMatrix.columns.0.x, camMatrix.columns.0.y, camMatrix.columns.0.z))
        let cameraUp = normalize(SIMD3<Float>(camMatrix.columns.1.x, camMatrix.columns.1.y, camMatrix.columns.1.z))

        // Light quad corners (from CornellBox geometry)
        let lightCorner = SIMD3<Float>(-0.24, 1.98 + CornellBox.yOffset, 0.16)
        let lightEdge1  = SIMD3<Float>(0.23 - (-0.24), 0, 0)  // along X
        let lightEdge2  = SIMD3<Float>(0, 0, -0.22 - 0.16)    // along Z
        return RayTracingUniforms(
            cameraPosition: cameraPosition,
            cameraForward: cameraForward,
            cameraRight: cameraRight,
            cameraUp: cameraUp,
            resolution: SIMD2<Float>(Float(size.width), Float(size.height)),
            frameIndex: frameIndex,
            samplesPerPixel: samplesPerPixel,
            maxBounces: maxBounces,
            lightCorner: lightCorner,
            lightEdge1: lightEdge1,
            lightEdge2: lightEdge2,
            lightEmission: SIMD3<Float>(17, 12, 4)
        )
    }
}
