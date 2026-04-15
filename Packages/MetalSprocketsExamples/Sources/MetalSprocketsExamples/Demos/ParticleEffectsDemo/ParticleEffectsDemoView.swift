import DemoKit
import GeometryLite3D
import Interaction3D
import Metal
import MetalSprockets
import MetalSprocketsExampleShaders
import MetalSprocketsSupport
import MetalSprocketsUI
import MetalSupport
import simd
import SwiftUI

public struct ParticleEffectsDemoView: View {
    @State private var projection: any ProjectionProtocol = PerspectiveProjection()
    @State private var cameraMatrix: simd_float4x4 = .init(translation: [0, 0, 8])
    @State private var drawableSize: CGSize = .zero

    // Particle system parameters
    @State private var particleCount: Int = 5_000
    @State private var particleSize: Float = 20.0
    @State private var gravity: SIMD3<Float> = [0, -2, 0]  // Lower gravity for portal
    @State private var emitterType: EmitterType = .magicPortal
    @State private var emissionRate: Float = 2_000

    // Particle buffers
    @State private var particleBuffer: MTLBuffer?
    @State private var emitterBuffer: MTLBuffer?

    enum EmitterType: String, CaseIterable {
        case fountain = "Fountain"
        case explosion = "Explosion"
        case rain = "Rain"
        case fireworks = "Fireworks"
        case tornado = "Tornado"
        case magicPortal = "Magic Portal"
    }

    public init() {
        // This line intentionally left blank.
    }

    public var body: some View {
        WorldView(projection: $projection, cameraMatrix: $cameraMatrix) {
            RenderView { context, drawableSize in
                let currentTime = context.frameUniforms.time

                if let particleBuffer, let emitterBuffer {
                    try Group {
                        // Update particles using compute shader
                        try ComputePass {
                            ParticleUpdateCompute(
                                particleBuffer: particleBuffer,
                                emitterBuffer: emitterBuffer,
                                particleCount: particleCount,
                                time: currentTime,
                                gravity: gravity,
                                emitterType: emitterType,
                                emissionRate: emissionRate
                            )
                        }

                        // Render particles
                        try RenderPass {
                            ParticleRenderPipeline(
                                particleBuffer: particleBuffer,
                                particleCount: particleCount,
                                viewMatrix: cameraMatrix.inverse,
                                projectionMatrix: projection.projectionMatrix(for: drawableSize),
                                time: currentTime,
                                gravity: gravity,
                                baseSize: particleSize
                            )
                            .depthCompare(function: .less, enabled: true)
                        }
                    }
                }
            }
            .metalDepthStencilPixelFormat(.depth32Float)
            .onDrawableSizeChange { drawableSize = $0 }
            .onAppear {
                initializeParticles()
            }
            .onChange(of: particleCount) {
                initializeParticles()
            }
            .onChange(of: emitterType) {
                // Adjust gravity based on emitter type
                switch emitterType {
                case .magicPortal:
                    gravity = [0, -2, 0]  // Less gravity for portal
                case .rain:
                    gravity = [0, -15, 0]  // More gravity for rain
                default:
                    gravity = [0, -9.8, 0]  // Normal gravity
                }
                initializeParticles()
            }
        }
        .demoConfiguration {
            Form {
                Picker("Emitter", selection: $emitterType) {
                    ForEach(EmitterType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.menu)

                LabeledContent("Particles") {
                    Slider(value: Binding(get: { Double(particleCount) }, set: { particleCount = Int($0) }), in: 1_000...20_000)
                        .accessibilityLabel("Particles")
                }
                LabeledContent("Size") {
                    Slider(value: $particleSize, in: 5...50)
                        .accessibilityLabel("Size")
                }
                LabeledContent("Gravity") {
                    Slider(value: $gravity.y, in: -10...10)
                        .accessibilityLabel("Gravity")
                }
                LabeledContent("Emission") {
                    Slider(value: $emissionRate, in: 100...2_000)
                        .accessibilityLabel("Emission")
                }
                Button("Reset") {
                    initializeParticles()
                }
            }
            .formStyle(.grouped)
        }
        #if os(macOS)
        #endif
    }

    private func initializeParticles() {
        let device = _MTLCreateSystemDefaultDevice()

        // Initialize all particles as dead (life = 0)
        var particles: [Particle] = []
        particles.reserveCapacity(particleCount)

        for _ in 0..<particleCount {
            particles.append(Particle(
                position: SIMD3<Float>(0, 0, 0),
                velocity: SIMD3<Float>(0, 0, 0),
                color: SIMD3<Float>(1, 1, 1),
                life: 0,  // Start dead
                size: 1.0
            ))
        }

        // Create particle buffer
        let bufferSize = particles.count * MemoryLayout<Particle>.stride
        particleBuffer = device.makeBuffer(bytes: particles, length: bufferSize, options: [.storageModeShared])
        particleBuffer?.label = "Particle Buffer"

        // Create emitter parameters buffer
        let emitterParams = ParticleEmitterParams(
            position: getEmitterPosition(for: emitterType),
            emitterType: Int32(emitterTypeIndex),
            emissionRate: emissionRate,
            time: 0
        )
        emitterBuffer = device.makeBuffer(bytes: [emitterParams], length: MemoryLayout<ParticleEmitterParams>.stride, options: [.storageModeShared])
        emitterBuffer?.label = "Emitter Buffer"
    }

    private var emitterTypeIndex: Int {
        EmitterType.allCases.firstIndex(of: emitterType) ?? 0
    }

    private func getEmitterPosition(for type: EmitterType) -> SIMD3<Float> {
        switch type {
        case .fountain: return SIMD3<Float>(0, -2, 0)
        case .explosion: return SIMD3<Float>(0, 0, 0)
        case .rain: return SIMD3<Float>(0, 5, 0)
        case .fireworks: return SIMD3<Float>(0, -3, 0)
        case .tornado: return SIMD3<Float>(0, 0, 0)
        case .magicPortal: return SIMD3<Float>(0, 0, 0)
        }
    }
}

// Use the structs from the Metal header
private struct ParticleUpdateCompute: Element {
    let particleBuffer: MTLBuffer
    let emitterBuffer: MTLBuffer
    let particleCount: Int
    let time: Float
    let gravity: SIMD3<Float>
    let emitterType: ParticleEffectsDemoView.EmitterType
    let emissionRate: Float

    init(particleBuffer: MTLBuffer, emitterBuffer: MTLBuffer, particleCount: Int, time: Float, gravity: SIMD3<Float>, emitterType: ParticleEffectsDemoView.EmitterType, emissionRate: Float) {
        self.particleBuffer = particleBuffer
        self.emitterBuffer = emitterBuffer
        self.particleCount = particleCount
        self.time = time
        self.gravity = gravity
        self.emitterType = emitterType
        self.emissionRate = emissionRate

        // Update emitter parameters before compute pass
        let emitterParams = ParticleEmitterParams(
            position: getEmitterPosition(for: emitterType),
            emitterType: Int32(ParticleEffectsDemoView.EmitterType.allCases.firstIndex(of: emitterType) ?? 0),
            emissionRate: emissionRate,
            time: time
        )
        memcpy(emitterBuffer.contents(), [emitterParams], MemoryLayout<ParticleEmitterParams>.stride)
    }

    var body: some Element {
        get throws {
            let bundle = Bundle.metalSprocketsExampleShaders()
            let library = try ShaderLibrary(bundle: bundle)
            let updateKernel = try library.function(type: ComputeKernel.self, named: "updateParticles")

            let uniforms = ParticleUniforms(
                viewMatrix: .identity,
                projectionMatrix: .identity,
                time: self.time,
                _padding1: (0, 0, 0),
                gravity: gravity,
                baseSize: 1.0
            )

            try ComputePipeline(computeKernel: updateKernel) {
                try ComputeDispatch(
                    threadsPerGrid: MTLSize(width: particleCount, height: 1, depth: 1),
                    threadsPerThreadgroup: MTLSize(width: 64, height: 1, depth: 1)
                )
                .parameter("particles", buffer: particleBuffer)
                .parameter("uniforms", value: uniforms)
                .parameter("emitter", buffer: emitterBuffer)
                .parameter("particleCount", value: UInt32(particleCount))
            }
        }
    }

    private func getEmitterPosition(for type: ParticleEffectsDemoView.EmitterType) -> SIMD3<Float> {
        switch type {
        case .fountain: return SIMD3<Float>(0, -2, 0)
        case .explosion: return SIMD3<Float>(0, 0, 0)
        case .rain: return SIMD3<Float>(0, 5, 0)
        case .fireworks: return SIMD3<Float>(0, -3, 0)
        case .tornado: return SIMD3<Float>(0, 0, 0)
        case .magicPortal: return SIMD3<Float>(0, 0, 0)
        }
    }
}

// Render pipeline for particles
private struct ParticleRenderPipeline: Element {
    let particleBuffer: MTLBuffer
    let particleCount: Int
    let viewMatrix: simd_float4x4
    let projectionMatrix: simd_float4x4
    let time: Float
    let gravity: SIMD3<Float>
    let baseSize: Float

    private var vertexDescriptor: MTLVertexDescriptor {
        MTLVertexDescriptor()  // Using buffer directly, no vertex descriptor needed
    }

    var body: some Element {
        get throws {
            let bundle = Bundle.metalSprocketsExampleShaders()
            let library = try ShaderLibrary(bundle: bundle)

            let vertexShader = try library.function(type: VertexShader.self, named: "particleEffectsVertex")
            let fragmentShader = try library.function(type: FragmentShader.self, named: "particleEffectsFragment")

            try RenderPipeline(
                vertexShader: vertexShader,
                fragmentShader: fragmentShader
            ) {
                Draw { encoder in
                    let uniforms = ParticleUniforms(
                        viewMatrix: viewMatrix,
                        projectionMatrix: projectionMatrix,
                        time: time,
                        _padding1: (0, 0, 0),
                        gravity: gravity,
                        baseSize: baseSize
                    )
                    encoder.setVertexBuffer(particleBuffer, offset: 0, index: 0)
                    encoder.setVertexBytes([uniforms], length: MemoryLayout<ParticleUniforms>.stride, index: 1)
                    encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particleCount)
                }
            }
            .vertexDescriptor(vertexDescriptor)
            .renderPipelineDescriptorModifier { renderPipelineDescriptor in
                // Simple additive blending for glow effect (optional)
                renderPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
                renderPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
                renderPipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
                renderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
                renderPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
                renderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
                renderPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
            }
        }
    }
}
