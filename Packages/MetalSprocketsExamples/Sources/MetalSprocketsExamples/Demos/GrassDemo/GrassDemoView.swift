import DemoKit
import GeometryLite3D
import Interaction3D
import MetalKit
import MetalSprockets
import MetalSprocketsAddOns
import MetalSprocketsExampleShaders
import MetalSprocketsSupport
import MetalSprocketsUI
import MetalSupport
import simd
import SwiftMesh
import SwiftUI

public struct GrassDemoView: View {
    @State
    private var projection: any ProjectionProtocol = PerspectiveProjection()

    @State
    private var cameraMatrix: simd_float4x4 = .init(translation: [0, 0, 4])

    @State
    private var rotation: Float = 0.0

    @State
    private var isPlaying: Bool = false

    @State
    private var grassDensity: Double = 500

    private let maxGrassPoints = 2_000

    @State
    private var grassLength: Double = 0.5

    @State
    private var bladeWidthMultiplier: Double = 1.0

    @State
    private var bladesPerPoint: Double = 8

    @State
    private var showSphere: Bool = true

    @State
    private var droopEnabled: Bool = false

    @State
    private var sphereMesh: MetalMesh

    @State
    private var precomputedGrassPoints: [SIMD3<Float>] = []

    public init() {
        let device = _MTLCreateSystemDefaultDevice()
        var mesh = SwiftMesh.Mesh.sphere(latitudeSegments: 24, longitudeSegments: 48)
        mesh.positions = mesh.positions.map { $0 * 3 }
        mesh = mesh.withSmoothNormals()
        self.sphereMesh = MetalMesh(mesh: mesh, device: device)
        print(self.sphereMesh)
    }

    private func ensurePrecomputedPoints() {
        if precomputedGrassPoints.isEmpty || precomputedGrassPoints.count < maxGrassPoints {
            precomputedGrassPoints = generateUniformSpherePoints(count: maxGrassPoints, radius: 1.5)
        }
    }

    public var body: some View {
        WorldView(projection: $projection, cameraMatrix: $cameraMatrix) {
            Group {
                if isPlaying {
                    TimelineView(.animation) { timeline in
                        renderContent(animating: true)
                            .onChange(of: timeline.date) { _, _ in
                                rotation += 0.01
                            }
                    }
                } else {
                    renderContent(animating: false)
                }
            }
        }
        .demoConfiguration {
            let segmentsPerBlade = 4
            let totalBlades = Int(grassDensity) * Int(bladesPerPoint)
            let verticesPerBlade = (segmentsPerBlade + 1) * 2
            let totalVertices = totalBlades * verticesPerBlade

            Form {
                Section {
                    Text("Blades: \(totalBlades.formatted()) • Vertices: \(totalVertices.formatted())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Blade") {
                    LabeledContent("Length") {
                        Slider(value: $grassLength, in: 0.05...10.0)
                            .accessibilityLabel("Length")
                    }
                    LabeledContent("Width") {
                        Slider(value: $bladeWidthMultiplier, in: 0.1...3.0)
                            .accessibilityLabel("Width")
                    }
                    LabeledContent("Blades/Pt") {
                        Slider(value: $bladesPerPoint, in: 1...16)
                            .accessibilityLabel("Blades per Point")
                    }
                    LabeledContent("Points") {
                        Slider(value: $grassDensity, in: 100...Double(maxGrassPoints))
                            .accessibilityLabel("Points")
                    }
                }
                Section("Options") {
                    Toggle("Droop", isOn: $droopEnabled)
                    Toggle("Animate", isOn: $isPlaying)
                    Toggle("Sphere", isOn: $showSphere)
                }
                Section {
                    Button("Reset Camera") {
                        cameraMatrix = .init(translation: [0, 0, 4])
                        rotation = 0.0
                    }
                }
            }
            .formStyle(.grouped)
        }
    }

    @ViewBuilder
    private func renderContent(animating: Bool) -> some View {
        RenderView { _, drawableSize in
            let projectionMatrix = projection.projectionMatrix(for: drawableSize)
            let viewMatrix = cameraMatrix.inverse
            let rotationMatrix = animating ? float4x4(yRotation: .radians(rotation)) : .identity
            let modelMatrix = rotationMatrix
            let mvp = projectionMatrix * viewMatrix * modelMatrix

            try RenderPass {
                if showSphere {
                    try renderSphere(modelMatrix: modelMatrix, viewMatrix: viewMatrix, projectionMatrix: projectionMatrix)
                }

                try renderGrass(mvp: mvp, modelMatrix: modelMatrix, viewMatrix: viewMatrix, projectionMatrix: projectionMatrix)
            }
        }
        .metalDepthStencilPixelFormat(.depth32Float)
    }

    private func renderSphere(modelMatrix: float4x4, viewMatrix: float4x4, projectionMatrix: float4x4) throws -> some Element {
        let modelViewProjectionMatrix = projectionMatrix * viewMatrix * modelMatrix
        return try FlatShader(modelViewProjection: modelViewProjectionMatrix, textureSpecifier: .color([0.15, 0.4, 0.2])) {
            Draw { encoder in
                encoder.draw(sphereMesh)
            }
        }
        .vertexDescriptor(MTLVertexDescriptor(sphereMesh.vertexDescriptor))
        .depthCompare(function: .less, enabled: true)
    }

    private func renderGrass(mvp: float4x4, modelMatrix: float4x4, viewMatrix: float4x4, projectionMatrix: float4x4) throws -> some Element {
        ensurePrecomputedPoints()

        let pointCount = Int(grassDensity)
        let grassBladeLength = Float(grassLength)

        let spherePoints = Array(precomputedGrassPoints.prefix(pointCount))

        var grassData: [GrassPointData] = []
        for point in spherePoints {
            let normal = normalize(point)
            let tangent = normalize(cross(normal, [0, 1, 0]))
            let bitangent = normalize(cross(normal, tangent))

            grassData.append(GrassPointData(position: point, normal: normal, tangent: tangent, bitangent: bitangent, bladeLength: grassBladeLength, droopEnabled: droopEnabled ? 1 : 0, bladeWidthMultiplier: Float(bladeWidthMultiplier), bladesPerPoint: Int32(bladesPerPoint)))
        }

        let uniforms = GrassUniforms(modelViewProjection: mvp, modelMatrix: modelMatrix, viewMatrix: viewMatrix, projectionMatrix: projectionMatrix)

        let device = _MTLCreateSystemDefaultDevice()
        let grassDataBuffer = try device.makeBuffer(view: .init(count: grassData.count), values: grassData, options: .storageModeShared)
        let uniformsBuffer = try device.makeBuffer(view: .init(count: 1), values: [uniforms], options: .storageModeShared)

        let shaderBundle = Bundle.metalSprocketsExampleShaders()
        let library = try ShaderLibrary(bundle: shaderBundle)
        let objectShader = try library.function(type: ObjectShader.self, named: "grassObjectShader")
        let meshShader = try library.function(type: MeshShader.self, named: "grassMeshShader")
        let fragmentShader = try library.function(type: FragmentShader.self, named: "grassFragmentShader")

        return try MeshRenderPipeline(objectShader: objectShader, meshShader: meshShader, fragmentShader: fragmentShader) {
            Draw { encoder in
                encoder.drawMeshThreadgroups(MTLSize(width: pointCount, height: 1, depth: 1), threadsPerObjectThreadgroup: MTLSize(width: 1, height: 1, depth: 1), threadsPerMeshThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
            }
            .parameter("pointData", functionType: .object, buffer: grassDataBuffer, offset: 0)
            .parameter("uniforms", functionType: .object, buffer: uniformsBuffer, offset: 0)
            .parameter("pointData", functionType: .mesh, buffer: grassDataBuffer, offset: 0)
            .parameter("uniforms", functionType: .mesh, buffer: uniformsBuffer, offset: 0)
        }
        .depthCompare(function: .less, enabled: true)
    }

    private func generateUniformSpherePoints(count: Int, radius: Float) -> [SIMD3<Float>] {
        var points: [SIMD3<Float>] = []
        let goldenRatio = (1.0 + sqrt(5.0)) / 2.0
        let angleIncrement = Float.pi * 2.0 * Float(goldenRatio)

        for i in 0..<count {
            let t = Float(i) / Float(count)
            let inclination = acos(1.0 - 2.0 * t)
            let azimuth = angleIncrement * Float(i)

            let x = sin(inclination) * cos(azimuth)
            let y = sin(inclination) * sin(azimuth)
            let z = cos(inclination)

            points.append(SIMD3<Float>(x, y, z) * radius)
        }

        return points.shuffled()
    }
}

struct GrassPointData {
    // periphery:ignore - used in Metal shader
    var position: SIMD3<Float>
    // periphery:ignore - used in Metal shader
    var normal: SIMD3<Float>
    // periphery:ignore - used in Metal shader
    var tangent: SIMD3<Float>
    // periphery:ignore - used in Metal shader
    var bitangent: SIMD3<Float>
    // periphery:ignore - used in Metal shader
    var bladeLength: Float
    // periphery:ignore - used in Metal shader
    var droopEnabled: Int32
    // periphery:ignore - used in Metal shader
    var bladeWidthMultiplier: Float
    // periphery:ignore - used in Metal shader
    var bladesPerPoint: Int32
}

struct GrassUniforms {
    // periphery:ignore - used in Metal shader
    var modelViewProjection: float4x4
    // periphery:ignore - used in Metal shader
    var modelMatrix: float4x4
    // periphery:ignore - used in Metal shader
    var viewMatrix: float4x4
    // periphery:ignore - used in Metal shader
    var projectionMatrix: float4x4
}
