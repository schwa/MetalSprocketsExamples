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
import SwiftUI

public struct SpiralParticlesDemoView: View {
    @State
    private var projection: any ProjectionProtocol = PerspectiveProjection()

    @State
    private var cameraMatrix: simd_float4x4 = .init(translation: [0, 0, 8])

    @State
    private var time: Float = 0.0

    @State
    private var particleCount: Int = 32

    @State
    private var rotationSpeed: Double = 1.0

    @State
    private var orbitRadius: Double = 3.0

    @State
    private var spiralSize: Double = 0.5

    @State
    private var trianglesPerSpiral: Int = 30

    private let maxParticles = 32
    private let maxTriangles = 64

    public init() {
        // Intentionally empty
    }

    public var body: some View {
        WorldView(projection: $projection, cameraMatrix: $cameraMatrix) {
            TimelineView(.animation) { timeline in
                renderContent()
                    .onChange(of: timeline.date) { _, _ in
                        time += Float(0.016 * rotationSpeed)
                    }
            }
        }
        .demoConfiguration {
            Form {
                let totalTriangles = particleCount * trianglesPerSpiral
                let totalVertices = totalTriangles * 3

                HStack {
                    Text("Particles: \(particleCount)")
                    Text("•")
                    Text("Triangles: \(totalTriangles)")
                    Text("•")
                    Text("Vertices: \(totalVertices)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                LabeledContent("Particles") {
                    HStack {
                        Slider(
                            value: Binding(
                                get: { Double(particleCount) },
                                set: { particleCount = Int($0) }
                            ),
                            in: 1...Double(maxParticles)
                        )
                        .accessibilityLabel("Particles")
                        Text("\(particleCount)")
                            .monospacedDigit()
                            .frame(minWidth: 30)
                    }
                }

                LabeledContent("Triangles") {
                    HStack {
                        Slider(
                            value: Binding(
                                get: { Double(trianglesPerSpiral) },
                                set: { trianglesPerSpiral = Int($0) }
                            ),
                            in: 3...Double(maxTriangles)
                        )
                        .accessibilityLabel("Triangles")
                        Text("\(trianglesPerSpiral)")
                            .monospacedDigit()
                            .frame(minWidth: 30)
                    }
                }

                LabeledContent("Speed") {
                    HStack {
                        Slider(value: $rotationSpeed, in: 0.0...3.0)
                            .accessibilityLabel("Speed")
                        Text(rotationSpeed, format: .number.precision(.fractionLength(2)))
                            .frame(minWidth: 40)
                    }
                }

                LabeledContent("Orbit") {
                    HStack {
                        Slider(value: $orbitRadius, in: 0.0...5.0)
                            .accessibilityLabel("Orbit")
                        Text(orbitRadius, format: .number.precision(.fractionLength(2)))
                            .frame(minWidth: 40)
                    }
                }

                LabeledContent("Size") {
                    HStack {
                        Slider(value: $spiralSize, in: 0.1...2.0)
                            .accessibilityLabel("Size")
                        Text(spiralSize, format: .number.precision(.fractionLength(2)))
                            .frame(minWidth: 40)
                    }
                }

                Button("Reset") {
                    cameraMatrix = .init(translation: [0, 0, 8])
                    time = 0.0
                }
            }
            .formStyle(.grouped)
        }
    }

    @ViewBuilder
    private func renderContent() -> some View {
        RenderView { _, drawableSize in
            let projectionMatrix = projection.projectionMatrix(for: drawableSize)
            let viewMatrix = cameraMatrix.inverse
            let viewProjectionMatrix = projectionMatrix * viewMatrix

            try RenderPass {
                try renderParticles(viewProjectionMatrix: viewProjectionMatrix)
            }
        }
        .metalDepthStencilPixelFormat(.depth32Float)
    }

    // Held in state rather than looked up in renderParticles, which runs every frame. See #386.
    @State
    private var objectShader = ShaderLibrary.examples.requiredFunction(type: ObjectShader.self, named: "spiralParticleObjectShader")

    @State
    private var meshShader = ShaderLibrary.examples.requiredFunction(type: MeshShader.self, named: "spiralParticleMeshShader")

    @State
    private var fragmentShader = ShaderLibrary.examples.requiredFunction(type: FragmentShader.self, named: "spiralParticleFragmentShader")

    private func renderParticles(viewProjectionMatrix: float4x4) throws -> some Element {
        // Generate particle data on CPU - positions rotate around center
        // Always allocate for max particles to avoid flickering when count changes
        var particles: [SpiralParticleData] = []
        particles.reserveCapacity(maxParticles)

        for i in 0..<particleCount {
            let angle = Float(i) * (2.0 * .pi / Float(particleCount)) + time * 0.5
            let radius = Float(orbitRadius)

            // Particles orbit in a circle
            let x = cos(angle) * radius
            let y = sin(Float(i) * 0.5 + time * 0.3) * 1.5
            let z = sin(angle) * radius

            let position = SIMD3<Float>(x, y, z)

            // Different colors for each particle
            let hue = Float(i) / Float(particleCount)
            let color = SIMD3<Float>(
                abs(sin(hue * .pi * 2.0)),
                abs(sin((hue + 0.333) * .pi * 2.0)),
                abs(sin((hue + 0.666) * .pi * 2.0))
            )

            particles.append(SpiralParticleData(
                position: position,
                color: color,
                size: Float(spiralSize),
                rotation: Float(i) * 0.5 + time * 0.2
            ))
        }

        // Pad with dummy particles to maintain consistent buffer size
        while particles.count < maxParticles {
            particles.append(SpiralParticleData(
                position: SIMD3<Float>(0, 0, 0),
                color: SIMD3<Float>(0, 0, 0),
                size: 0,
                rotation: 0
            ))
        }

        let uniforms = SpiralParticleUniforms(
            viewProjectionMatrix: viewProjectionMatrix,
            time: time,
            trianglesPerSpiral: UInt32(trianglesPerSpiral)
        )

        let device = _MTLCreateSystemDefaultDevice()
        let particleBuffer = try device.makeBuffer(
            view: .init(count: maxParticles),
            values: particles,
            options: .storageModeShared
        )
        let uniformsBuffer = try device.makeBuffer(
            view: .init(count: 1),
            values: [uniforms],
            options: .storageModeShared
        )

        return try MeshRenderPipeline(
            objectShader: objectShader,
            meshShader: meshShader,
            fragmentShader: fragmentShader
        ) {
            Draw { encoder in
                // One object threadgroup per particle
                // 1 thread per object threadgroup (each handles one particle)
                // 32 threads per mesh threadgroup (to parallelize spiral generation)
                encoder.drawMeshThreadgroups(
                    MTLSize(width: particleCount, height: 1, depth: 1),
                    threadsPerObjectThreadgroup: MTLSize(width: 1, height: 1, depth: 1),
                    threadsPerMeshThreadgroup: MTLSize(width: 32, height: 1, depth: 1)
                )
            }
            .parameter("particleData", functionType: .object, buffer: particleBuffer, offset: 0)
            .parameter("uniforms", functionType: .object, buffer: uniformsBuffer, offset: 0)
            .parameter("particleData", functionType: .mesh, buffer: particleBuffer, offset: 0)
            .parameter("uniforms", functionType: .mesh, buffer: uniformsBuffer, offset: 0)
        }
        .depthCompare(function: .less, enabled: true)
    }
}

struct SpiralParticleData {
    var position: SIMD3<Float>
    var color: SIMD3<Float>
    var size: Float
    var rotation: Float
}

struct SpiralParticleUniforms {
    var viewProjectionMatrix: float4x4
    var time: Float
    var trianglesPerSpiral: UInt32
}
