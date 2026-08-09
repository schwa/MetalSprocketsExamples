import DemoKit
import GeometryLite3D
import Interaction3D
import Metal
import MetalSprockets
import MetalSprocketsAddOns
import MetalSprocketsExamplesSupport
import MetalSprocketsSupport
import MetalSprocketsUI
import MetalSupport
import simd
import SwiftUI
import UniformTypeIdentifiers

public struct VoxelDemoView: View {
    @State
    private var projection: any ProjectionProtocol = PerspectiveProjection()

    @State
    private var cameraMatrix: float4x4 = float4x4(yRotation: .degrees(30)) * float4x4(xRotation: .degrees(20)) * .init(translation: [0, 0, 3])

    @State
    private var voxelTexture: MTLTexture?

    @State
    private var colorTexture: MTLTexture?

    @State
    private var voxelSize = MTLSize(width: 32, height: 32, depth: 32)

    /// Slider position for ``voxelSize``, as a power-of-two exponent.
    ///
    /// This is stored rather than computed from `voxelSize` on purpose. A computed `Binding` has to
    /// capture `self`, and DemoKit snapshots the `demoConfiguration` content into an `AnyView` once,
    /// so the capture freezes: writes reach the live `@State` box but reads come back from the frozen
    /// copy, and the slider springs back to its starting position. A projected binding writes and reads
    /// through the same box. See #389.
    @State
    private var voxelSizeExponent = VoxelResolution.exponent(forDimension: 32)

    @State
    private var voxelScale: SIMD3<Float> = [0.125, 0.125, 0.125]

    @State
    private var magicaVoxelURL: URL?

    public init() {
        // This line intentionally left blank.
    }

    public var body: some View {
        WorldView(projection: $projection, cameraMatrix: $cameraMatrix) {
            RenderView { _, drawableSize in
                try ComputePass(label: "VoxelToTexture") {
                    if let voxelTexture, let colorTexture {
                        try VoxelToTextureComputePipeline(projection: projection, aspectRatio: Float(drawableSize.width / drawableSize.height), cameraMatrix: cameraMatrix, voxelTexture: voxelTexture, outputTexture: colorTexture, voxelScale: voxelScale)
                    }
                }
                try RenderPass {
                    if let colorTexture {
                        try TextureBillboardPipeline(specifier: .texture2D(colorTexture))
                    }
                }
                .onChange(of: drawableSize, initial: true) { _, _ in
                    colorTexture = makeRenderTexture(size: MTLSize(drawableSize))
                }
            }
        }
        .onChange(of: voxelSizeExponent) { _, new in
            applyVoxelSizeExponent(new)
        }
        .onChange(of: voxelSize, initial: true) {
            generateDefaultVoxelTexture()
        }
        .onChange(of: magicaVoxelURL, initial: true) {
            guard let magicaVoxelURL else {
                generateDefaultVoxelTexture()
                return
            }
            do {
                let model = try MagicaVoxelModel(contentsOf: magicaVoxelURL)
                let texture = try model.makeTexture()
                voxelTexture = texture
                voxelScale = SIMD3<Float>(0.01, 0.01, 0.01)
            }
            catch {
                assertionFailure("Failed to load MagicaVoxel model: \(error)")
            }
        }

        .demoConfiguration {
            Form {
                Text("Voxel Size: \(voxelSize.width) x \(voxelSize.height) x \(voxelSize.depth)")

                let memory = Measurement(value: Double(voxelSize.width * voxelSize.height * voxelSize.depth * MemoryLayout<SIMD3<Float>>.size), unit: UnitInformationStorage.bytes)

                Text("# voxels: \(voxelSize.width * voxelSize.height * voxelSize.depth) (\(memory.formatted(.byteCount(style: .memory))) )")
                Text("Voxel Scale: \(voxelScale.x) x \(voxelScale.y) x \(voxelScale.z)")
                LabeledContent("Resolution") {
                    Slider(
                        value: $voxelSizeExponent,
                        in: Double(VoxelResolution.minimumExponent)...Double(VoxelResolution.maximumExponent),
                        step: 1
                    )
                    .accessibilityLabel("Voxel Resolution")
                    .accessibilityValue("\(voxelSize.width) cubed")
                }

                SuperImportWidget(url: $magicaVoxelURL, identifier: "magica-voxel", allowedContentTypes: [.magicaVoxel])
            }
            .formStyle(.grouped)
        }
    }

    /// Applies a new slider position to ``voxelSize``, keeping the rendered model the same size on screen.
    ///
    /// The old pair of "/2" and "x2" buttons scaled ``voxelScale`` inversely so the voxel grid kept its
    /// physical extent; the slider preserves that coupling.
    private func applyVoxelSizeExponent(_ exponent: Double) {
        let dimension = VoxelResolution.dimension(forExponent: exponent)
        guard dimension != voxelSize.width else {
            return
        }
        voxelScale *= Float(voxelSize.width) / Float(dimension)
        voxelSize = MTLSize(width: dimension, height: dimension, depth: dimension)
    }

    func generateDefaultVoxelTexture() {
        let device = _MTLCreateSystemDefaultDevice()
        do {
            voxelTexture = try makeSphereVoxelTexture(device: device, size: voxelSize)
            if voxelScale == SIMD3<Float>(0, 0, 0) {
                voxelScale = SIMD3<Float>(1, 1, 1)
            }
        }
        catch {
            assertionFailure("Failed to create voxel texture: \(error)")
        }
    }

    func makeRenderTexture(size: MTLSize) -> MTLTexture {
        let device = _MTLCreateSystemDefaultDevice()
        return device.makeTexture2D(pixelFormat: .rgba8Unorm, width: size.width, height: size.height, label: "Color Texture")
    }

    func makeSphereVoxelTexture(device: MTLDevice?, size: MTLSize) throws -> MTLTexture {
        guard let device else {
            throw MetalSprocketsError.resourceCreationFailure("Metal device unavailable.")
        }

        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type3D
        descriptor.pixelFormat = .rgba8Unorm
        descriptor.width = size.width
        descriptor.height = size.height
        descriptor.depth = size.depth
        descriptor.usage = [.shaderRead, .shaderWrite]

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw MetalSprocketsError.resourceCreationFailure("Failed to create voxel texture.")
        }
        texture.label = "Voxel Texture"

        let shaderLibrary = try ShaderNamespace.examples("VoxelShaders")
        let kernel: ComputeKernel = try shaderLibrary.voxel_generateSphere

        let computePass = try ComputePass(label: "GenerateVoxelSphere") {
            try ComputePipeline(computeKernel: kernel) {
                try ComputeDispatch(threadsPerGrid: size)
                .parameter("voxelTexture", texture: texture)
            }
        }

        try computePass.run()

        return texture
    }
}

extension UTType {
    static let magicaVoxel = UTType(filenameExtension: "vox").orFatalError("Failed to create magicaVoxel UTType")
}

extension MagicaVoxelModel {
    func makeTexture() throws -> MTLTexture {
        let device = _MTLCreateSystemDefaultDevice()
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type3D
        descriptor.pixelFormat = .rgba8Unorm
        descriptor.width = Int(size.x)
        descriptor.height = Int(size.y)
        descriptor.depth = Int(size.z)
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw MetalSprocketsError.resourceCreationFailure("Failed to create voxel texture.")
        }
        texture.label = "MagicaVoxel Texture"

        for voxel in voxels {
            let position = voxel.0
            let color = colors[Int(voxel.1)]
            let colorData: [UInt8] = [color.x, color.y, color.z, 255]
            texture.replace(region: MTLRegionMake3D(Int(position.x), Int(position.y), Int(position.z), 1, 1, 1), mipmapLevel: 0, slice: 0, withBytes: colorData, bytesPerRow: 4, bytesPerImage: 4)
        }

        return texture
    }
}
