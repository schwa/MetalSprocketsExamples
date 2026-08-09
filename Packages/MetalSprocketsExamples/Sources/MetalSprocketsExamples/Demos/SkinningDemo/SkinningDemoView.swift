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
import simd
import SwiftUI

// MARK: - Skinned Box Mesh Generation

/// A vertex with position, normal, bone indices, and bone weights for skeletal animation.
struct SkinnedVertex {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
    var boneIndices: SIMD2<UInt16> // Which two bones influence this vertex
    var boneWeights: SIMD2<Float>  // How much each bone influences this vertex
}

/// Generates a rectangular prism (box) along the Y axis with bone weight assignments.
///
/// The box is subdivided along Y so it can deform smoothly when skinned.
/// Two bones: bone 0 at bottom (y = -halfHeight), bone 1 at top (y = +halfHeight).
/// Weights blend linearly from bone 0 to bone 1 based on Y position.
private func generateSkinnedBox(
    width: Float = 0.4,
    depth: Float = 0.4,
    height: Float = 2.0,
    divisionsY: Int = 16
) -> (vertices: [SkinnedVertex], indices: [UInt32]) {
    var vertices: [SkinnedVertex] = []
    var indices: [UInt32] = []

    let halfW = width * 0.5
    let halfD = depth * 0.5
    let halfH = height * 0.5

    // Helper to add a subdivided quad face.
    // p0..p3 are the four corners; normal is the face normal.
    // uDiv/vDiv control subdivision along the two parametric axes.
    // The `yAt` closure returns the Y coordinate for a given (u,v) so we can compute bone weights.
    func addFace(
        p0: SIMD3<Float>,
        p1: SIMD3<Float>,
        p2: SIMD3<Float>,
        p3: SIMD3<Float>,
        normal: SIMD3<Float>,
        uDiv: Int,
        vDiv: Int,
        yAt: (Float, Float) -> Float
    ) {
        let baseIndex = UInt32(vertices.count)
        for vi in 0...vDiv {
            let v = Float(vi) / Float(vDiv)
            for ui in 0...uDiv {
                let u = Float(ui) / Float(uDiv)
                // Bilinear interpolation
                let pos = (1 - u) * (1 - v) * p0 + u * (1 - v) * p1 + (1 - u) * v * p2 + u * v * p3
                let y = yAt(u, v)
                // t=0 at bottom (-halfH), t=1 at top (+halfH)
                let t = (y + halfH) / height
                let clamped = max(0, min(1, t))
                vertices.append(SkinnedVertex(
                    position: pos,
                    normal: normal,
                    boneIndices: SIMD2<UInt16>(0, 1),
                    boneWeights: SIMD2<Float>(1.0 - clamped, clamped)
                ))
            }
        }
        // Triangulate the grid
        let cols = UInt32(uDiv + 1)
        for vi in 0..<UInt32(vDiv) {
            for ui in 0..<UInt32(uDiv) {
                let a = baseIndex + vi * cols + ui
                let b = a + cols
                let c = a + 1
                let d = b + 1
                indices.append(contentsOf: [a, b, c, b, d, c])
            }
        }
    }

    // Front face (+Z): subdivide along X (u) and Y (v)
    addFace(
        p0: SIMD3(-halfW, -halfH, halfD),
        p1: SIMD3(halfW, -halfH, halfD),
        p2: SIMD3(-halfW, halfH, halfD),
        p3: SIMD3(halfW, halfH, halfD),
        normal: SIMD3(0, 0, 1),
        uDiv: 1,
        vDiv: divisionsY
    ) { _, v in -halfH + v * height }
    // Back face (-Z)
    addFace(
        p0: SIMD3(halfW, -halfH, -halfD),
        p1: SIMD3(-halfW, -halfH, -halfD),
        p2: SIMD3(halfW, halfH, -halfD),
        p3: SIMD3(-halfW, halfH, -halfD),
        normal: SIMD3(0, 0, -1),
        uDiv: 1,
        vDiv: divisionsY
    ) { _, v in -halfH + v * height }
    // Right face (+X)
    addFace(
        p0: SIMD3(halfW, -halfH, halfD),
        p1: SIMD3(halfW, -halfH, -halfD),
        p2: SIMD3(halfW, halfH, halfD),
        p3: SIMD3(halfW, halfH, -halfD),
        normal: SIMD3(1, 0, 0),
        uDiv: 1,
        vDiv: divisionsY
    ) { _, v in -halfH + v * height }
    // Left face (-X)
    addFace(
        p0: SIMD3(-halfW, -halfH, -halfD),
        p1: SIMD3(-halfW, -halfH, halfD),
        p2: SIMD3(-halfW, halfH, -halfD),
        p3: SIMD3(-halfW, halfH, halfD),
        normal: SIMD3(-1, 0, 0),
        uDiv: 1,
        vDiv: divisionsY
    ) { _, v in -halfH + v * height }
    // Top face (+Y)
    addFace(
        p0: SIMD3(-halfW, halfH, halfD),
        p1: SIMD3(halfW, halfH, halfD),
        p2: SIMD3(-halfW, halfH, -halfD),
        p3: SIMD3(halfW, halfH, -halfD),
        normal: SIMD3(0, 1, 0),
        uDiv: 1,
        vDiv: 1
    ) { _, _ in halfH }
    // Bottom face (-Y)
    addFace(
        p0: SIMD3(-halfW, -halfH, -halfD),
        p1: SIMD3(halfW, -halfH, -halfD),
        p2: SIMD3(-halfW, -halfH, halfD),
        p3: SIMD3(halfW, -halfH, halfD),
        normal: SIMD3(0, -1, 0),
        uDiv: 1,
        vDiv: 1
    ) { _, _ in -halfH }

    return (vertices, indices)
}

// MARK: - Uniforms

private struct SkinningUniforms {
    var viewProjectionMatrix: float4x4
    var modelMatrix: float4x4
    var cameraPosition: SIMD3<Float>
}

// MARK: - View

public struct SkinningDemoView: View {
    // Held in state rather than looked up inside the RenderView closure, which runs every frame. See #386.
    @State
    private var skinningVertexShader = ShaderLibrary.examples.requiredFunction(type: VertexShader.self, named: "skinning_vertex")

    @State
    private var skinningFragmentShader = ShaderLibrary.examples.requiredFunction(type: FragmentShader.self, named: "skinning_fragment")

    @State
    private var boneVertexShader = ShaderLibrary.examples.requiredFunction(type: VertexShader.self, named: "bone_vertex")

    @State
    private var boneFragmentShader = ShaderLibrary.examples.requiredFunction(type: FragmentShader.self, named: "bone_fragment")

    @State
    private var projection: any ProjectionProtocol = PerspectiveProjection()

    @State
    private var cameraMatrix = simd_float4x4(translation: [0, 1.0, 4.0])

    @State
    private var bendAngle: Float = 0

    @State
    private var animating: Bool = true

    @State
    private var animationStartDate: Date = .now

    @State
    private var showWireframe: Bool = false

    @State
    private var rendererMode: RendererMode = .skinning

    @State
    private var debugMode: DebugShadersMode = .normal

    public init() {
        // Required public init
    }

    public var body: some View {
        WorldView(projection: $projection, cameraMatrix: $cameraMatrix) {
            TimelineView(.animation) { timeline in
                RenderView { _, drawableSize in
                    let projectionMatrix = projection.projectionMatrix(for: drawableSize)
                    let viewMatrix = cameraMatrix.inverse
                    let viewProjectionMatrix = projectionMatrix * viewMatrix

                    try RenderPass {
                        // Grid for spatial reference
                        GridShader(projectionMatrix: projectionMatrix, cameraMatrix: cameraMatrix)

                        let (vertices, meshIndices) = generateSkinnedBox()
                        let boneMatrices = computeBoneMatrices(bendAngle: bendAngle)

                        let modelMatrix = simd_float4x4(translation: [0, 1.0, 0])
                        let cameraPosition = SIMD3<Float>(cameraMatrix.columns.3.x, cameraMatrix.columns.3.y, cameraMatrix.columns.3.z)

                        let indexBufferLength = MemoryLayout<UInt32>.stride * meshIndices.count

                        switch rendererMode {
                        case .skinning:
                            let vertexShader = skinningVertexShader
                            let fragmentShader = skinningFragmentShader

                            var uniforms = SkinningUniforms(
                                viewProjectionMatrix: viewProjectionMatrix,
                                modelMatrix: modelMatrix,
                                cameraPosition: cameraPosition
                            )

                            let vertexBufferLength = MemoryLayout<SkinnedVertex>.stride * vertices.count

                            try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                                Draw { encoder in
                                    encoder.setCullMode(.back)
                                    if showWireframe {
                                        encoder.setTriangleFillMode(.lines)
                                    }

                                    guard let vertexBuffer = encoder.device.makeBuffer(bytes: vertices, length: vertexBufferLength, options: []) else {
                                        return
                                    }
                                    encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)

                                    encoder.setVertexBytes(&uniforms, length: MemoryLayout<SkinningUniforms>.stride, index: 1)
                                    encoder.setFragmentBytes(&uniforms, length: MemoryLayout<SkinningUniforms>.stride, index: 1)

                                    var bones = boneMatrices
                                    encoder.setVertexBytes(&bones, length: MemoryLayout<BoneMatricesData>.stride, index: 2)

                                    guard let indexBuffer = encoder.device.makeBuffer(bytes: meshIndices, length: indexBufferLength, options: []) else {
                                        return
                                    }
                                    encoder.drawIndexedPrimitives(
                                        type: .triangle,
                                        indexCount: meshIndices.count,
                                        indexType: .uint32,
                                        indexBuffer: indexBuffer,
                                        indexBufferOffset: 0
                                    )
                                }
                            }
                            .vertexDescriptor(skinnedVertexDescriptor())
                            .depthCompare(function: .less, enabled: true)

                        case .debug:
                            let skinnedVertices = cpuSkinVertices(vertices, boneMatrices: boneMatrices)
                            let vertexBufferLength = MemoryLayout<DebugVertex>.stride * skinnedVertices.count

                            try DebugRenderPipeline(
                                modelMatrix: modelMatrix,
                                normalMatrix: simd_float3x3(columns: (modelMatrix.columns.0.xyz, modelMatrix.columns.1.xyz, modelMatrix.columns.2.xyz)),
                                debugMode: debugMode,
                                lightPosition: [0, 10, 0],
                                cameraPosition: cameraPosition,
                                viewProjectionMatrix: viewProjectionMatrix
                            ) {
                                Draw { encoder in
                                    encoder.setCullMode(.back)
                                    if showWireframe {
                                        encoder.setTriangleFillMode(.lines)
                                    }

                                    guard let vertexBuffer = encoder.device.makeBuffer(bytes: skinnedVertices, length: vertexBufferLength, options: []) else {
                                        return
                                    }
                                    encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)

                                    guard let indexBuffer = encoder.device.makeBuffer(bytes: meshIndices, length: indexBufferLength, options: []) else {
                                        return
                                    }
                                    encoder.drawIndexedPrimitives(
                                        type: .triangle,
                                        indexCount: meshIndices.count,
                                        indexType: .uint32,
                                        indexBuffer: indexBuffer,
                                        indexBufferOffset: 0
                                    )
                                }
                            }
                            .vertexDescriptor(debugVertexDescriptor())
                            .depthCompare(function: .less, enabled: true)
                        }

                        // Draw bone visualization
                        try drawBoneVisualization(
                            boneMatrices: boneMatrices,
                            modelMatrix: modelMatrix,
                            viewProjectionMatrix: viewProjectionMatrix,
                            vertexShader: boneVertexShader,
                            fragmentShader: boneFragmentShader
                        )
                    }
                }
                .metalDepthStencilPixelFormat(.depth32Float)
                .onChange(of: timeline.date) { _, newDate in
                    guard animating else {
                        return
                    }
                    let t = Float(newDate.timeIntervalSince(animationStartDate))
                    // Oscillate between 0 (|) and -90° (L)
                    bendAngle = -Float.pi / 4.0 * (1.0 - cos(t * 1.5))
                }
            }
        }
        .demoConfiguration {
            Form {
                Picker("Renderer", selection: $rendererMode) {
                    Text("Skinning").tag(RendererMode.skinning)
                    Text("Debug").tag(RendererMode.debug)
                }
                .pickerStyle(.segmented)

                if rendererMode == .debug {
                    SkinningDebugModePicker(debugMode: $debugMode)
                }

                Toggle("Animate", isOn: $animating)
                Toggle("Wireframe", isOn: $showWireframe)

                VStack(alignment: .leading) {
                    Text("Bend Angle: \(Angle(radians: Double(bendAngle)).degrees.formatted(.number.precision(.fractionLength(1))))°")
                    Slider(value: $bendAngle, in: -Float.pi...Float.pi)
                        .disabled(animating)
                        .accessibilityLabel("Bend Angle")
                }
            }
            .fixedSize()
        }
    }
}

// MARK: - Bone Math

/// Packed bone matrix data matching the Metal struct layout.
private struct BoneMatricesData {
    var bones: (float4x4, float4x4)
    var boneNormals: (float4x4, float4x4)
}

/// Compute the two bone matrices for the current bend angle.
///
/// Bone 0 (root): identity — the lower half stays fixed.
/// Bone 1 (tip): rotated around the joint point (y=0) by `bendAngle` on the Z axis.
///
/// Since the mesh is authored in bind pose (both bones at identity),
/// the final bone matrix = worldTransform * inverseBindPose.
/// With identity bind poses, final = worldTransform.
private func computeBoneMatrices(bendAngle: Float) -> BoneMatricesData {
    // Root bone: stays at identity
    let bone0 = float4x4.identity

    // Tip bone: rotate around the joint (y=0) on the Z axis
    // 1. Translate joint to origin (already at origin for our mesh)
    // 2. Rotate
    // 3. Translate back
    let rotation = float4x4(simd_quatf(angle: bendAngle, axis: [0, 0, 1]))
    let bone1 = rotation

    // Normal matrices: inverse transpose of upper-left 3x3
    // For a pure rotation, inverse transpose = the rotation itself
    let bone0Normal = bone0
    let bone1Normal = rotation

    return BoneMatricesData(
        bones: (bone0, bone1),
        boneNormals: (bone0Normal, bone1Normal)
    )
}

// MARK: - Vertex Descriptor

private func skinnedVertexDescriptor() -> MTLVertexDescriptor {
    let descriptor = MTLVertexDescriptor()

    // swiftlint:disable force_unwrapping
    // Position: float3
    descriptor.attributes[0].format = .float3
    descriptor.attributes[0].offset = MemoryLayout<SkinnedVertex>.offset(of: \.position)!
    descriptor.attributes[0].bufferIndex = 0

    // Normal: float3
    descriptor.attributes[1].format = .float3
    descriptor.attributes[1].offset = MemoryLayout<SkinnedVertex>.offset(of: \.normal)!
    descriptor.attributes[1].bufferIndex = 0

    // Bone indices: ushort2
    descriptor.attributes[2].format = .ushort2
    descriptor.attributes[2].offset = MemoryLayout<SkinnedVertex>.offset(of: \.boneIndices)!
    descriptor.attributes[2].bufferIndex = 0

    // Bone weights: float2
    descriptor.attributes[3].format = .float2
    descriptor.attributes[3].offset = MemoryLayout<SkinnedVertex>.offset(of: \.boneWeights)!
    descriptor.attributes[3].bufferIndex = 0
    // swiftlint:enable force_unwrapping

    // Layout
    descriptor.layouts[0].stride = MemoryLayout<SkinnedVertex>.stride
    descriptor.layouts[0].stepFunction = .perVertex

    return descriptor
}

// MARK: - Bone Visualization

/// Draws simple lines representing the bone skeleton for debugging.
private func drawBoneVisualization(
    boneMatrices: BoneMatricesData,
    modelMatrix: float4x4,
    viewProjectionMatrix: float4x4,
    vertexShader: VertexShader,
    fragmentShader: FragmentShader
) throws -> some Element {
    // Bone 0: root at (0, -1, 0), joint at (0, 0, 0) — matches box with height=2, centered on Y
    // Bone 1: joint at (0, 0, 0), tip at (0, 1, 0) transformed by bone1 matrix
    let m = modelMatrix
    let joint = (m * SIMD4<Float>(0, 0, 0, 1)).xyz
    let root = (m * SIMD4<Float>(0, -1, 0, 1)).xyz
    let tipLocal = SIMD4<Float>(0, 1, 0, 1)
    let tip = (m * boneMatrices.bones.1 * tipLocal).xyz

    // Joint spheres as small diamonds
    let jointSize: Float = 0.05

    // Line vertices for bones + joint markers
    var lineVertices: [SIMD3<Float>] = [
        // Bone 0: root -> joint
        root, joint,
        // Bone 1: joint -> tip
        joint, tip
    ]

    // Diamond markers at each joint point
    for point in [root, joint, tip] {
        lineVertices.append(contentsOf: [
            point + SIMD3<Float>(-jointSize, 0, 0), point + SIMD3<Float>(jointSize, 0, 0),
            point + SIMD3<Float>(0, -jointSize, 0), point + SIMD3<Float>(0, jointSize, 0),
            point + SIMD3<Float>(0, 0, -jointSize), point + SIMD3<Float>(0, 0, jointSize)
        ])
    }

    struct BoneUniforms {
        var viewProjectionMatrix: float4x4
    }

    var uniforms = BoneUniforms(viewProjectionMatrix: viewProjectionMatrix)

    let descriptor = MTLVertexDescriptor()
    descriptor.attributes[0].format = .float3
    descriptor.attributes[0].offset = 0
    descriptor.attributes[0].bufferIndex = 0
    descriptor.layouts[0].stride = MemoryLayout<SIMD3<Float>>.stride
    descriptor.layouts[0].stepFunction = .perVertex

    return try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
        Draw { encoder in
            encoder.setVertexBytes(lineVertices, length: MemoryLayout<SIMD3<Float>>.stride * lineVertices.count, index: 0)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<BoneUniforms>.stride, index: 1)

            // Draw bone lines in yellow
            var boneColor = SIMD4<Float>(1, 0.9, 0.2, 1)
            encoder.setVertexBytes(&boneColor, length: MemoryLayout<SIMD4<Float>>.stride, index: 2)
            encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: 4)

            // Draw joint markers in red
            var jointColor = SIMD4<Float>(1, 0.2, 0.2, 1)
            encoder.setVertexBytes(&jointColor, length: MemoryLayout<SIMD4<Float>>.stride, index: 2)
            encoder.drawPrimitives(type: .line, vertexStart: 4, vertexCount: lineVertices.count - 4)
        }
    }
    .vertexDescriptor(descriptor)
    .depthCompare(function: .always, enabled: false)
}

private extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> {
        SIMD3<Float>(x, y, z)
    }
}

// MARK: - Renderer Mode

private enum RendererMode {
    case skinning
    case debug
}

// MARK: - Debug Renderer Support

/// Vertex layout matching the debug shader's VertexIn (attributes 0-4).
private struct DebugVertex {
    var position: SIMD3<Float>  // attribute(0)
    var normal: SIMD3<Float>    // attribute(1)
    var texCoord: SIMD2<Float>  // attribute(2)
    var tangent: SIMD3<Float>   // attribute(3)
    var bitangent: SIMD3<Float> // attribute(4)
}

/// CPU-skin vertices and convert to DebugVertex format.
private func cpuSkinVertices(_ vertices: [SkinnedVertex], boneMatrices: BoneMatricesData) -> [DebugVertex] {
    let bones = [boneMatrices.bones.0, boneMatrices.bones.1]
    let boneNormals = [boneMatrices.boneNormals.0, boneMatrices.boneNormals.1]

    return vertices.map { v in
        let idx0 = Int(v.boneIndices.x)
        let idx1 = Int(v.boneIndices.y)
        let w0 = v.boneWeights.x
        let w1 = v.boneWeights.y

        let pos = SIMD4<Float>(v.position, 1.0)
        let skinnedPos = w0 * (bones[idx0] * pos) + w1 * (bones[idx1] * pos)

        let norm = SIMD4<Float>(v.normal, 0.0)
        let skinnedNorm = w0 * (boneNormals[idx0] * norm) + w1 * (boneNormals[idx1] * norm)

        return DebugVertex(
            position: skinnedPos.xyz,
            normal: normalize(skinnedNorm.xyz),
            texCoord: .zero,
            tangent: .zero,
            bitangent: .zero
        )
    }
}

private func debugVertexDescriptor() -> MTLVertexDescriptor {
    let descriptor = MTLVertexDescriptor()

    // swiftlint:disable force_unwrapping
    descriptor.attributes[0].format = .float3
    descriptor.attributes[0].offset = MemoryLayout<DebugVertex>.offset(of: \.position)!
    descriptor.attributes[0].bufferIndex = 0

    descriptor.attributes[1].format = .float3
    descriptor.attributes[1].offset = MemoryLayout<DebugVertex>.offset(of: \.normal)!
    descriptor.attributes[1].bufferIndex = 0

    descriptor.attributes[2].format = .float2
    descriptor.attributes[2].offset = MemoryLayout<DebugVertex>.offset(of: \.texCoord)!
    descriptor.attributes[2].bufferIndex = 0

    descriptor.attributes[3].format = .float3
    descriptor.attributes[3].offset = MemoryLayout<DebugVertex>.offset(of: \.tangent)!
    descriptor.attributes[3].bufferIndex = 0

    descriptor.attributes[4].format = .float3
    descriptor.attributes[4].offset = MemoryLayout<DebugVertex>.offset(of: \.bitangent)!
    descriptor.attributes[4].bufferIndex = 0
    // swiftlint:enable force_unwrapping

    descriptor.layouts[0].stride = MemoryLayout<DebugVertex>.stride
    descriptor.layouts[0].stepFunction = .perVertex

    return descriptor
}

// MARK: - Debug Mode Picker

// TODO: Move to AddOns & make public
private struct SkinningDebugModePicker: View {
    @Binding var debugMode: DebugShadersMode

    private let debugModes: [(DebugShadersMode, String)] = [
        (.normal, "Normal"),
        (.texCoord, "Texture Coordinates"),
        (.tangent, "Tangent"),
        (.bitangent, "Bitangent"),
        (.worldPosition, "World Position"),
        (.localPosition, "Local Position"),
        (.uvDistortion, "UV Distortion"),
        (.tbnMatrix, "TBN Matrix"),
        (.vertexID, "Vertex ID"),
        (.faceNormal, "Face Normal"),
        (.uvDerivatives, "UV Derivatives"),
        (.checkerboard, "Checkerboard"),
        (.uvGrid, "UV Grid"),
        (.depth, "Depth"),
        (.wireframeOverlay, "Wireframe Overlay"),
        (.normalDeviation, "Normal Deviation"),
        (.barycentricCoord, "Barycentric Coord"),
        (.frontFacing, "Front Facing"),
        (.distanceToLight, "Distance to Light"),
        (.distanceToOrigin, "Distance to Origin"),
        (.distanceToCamera, "Distance to Camera")
    ]

    var body: some View {
        Picker("Debug Mode", selection: $debugMode) {
            ForEach(debugModes, id: \.0) { mode, label in
                Text(label).tag(mode)
            }
        }
        .pickerStyle(.menu)
    }
}
