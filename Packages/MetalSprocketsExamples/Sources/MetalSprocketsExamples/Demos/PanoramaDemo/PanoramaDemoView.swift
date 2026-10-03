import DemoKit
import GeometryLite3D
import Interaction3D
@preconcurrency import Metal
import MetalKit
import MetalSprockets
import MetalSprocketsAddOns
import MetalSprocketsExampleShaders
import MetalSprocketsExamplesSupport
import MetalSprocketsSupport
import MetalSprocketsUI
import MetalSupport
import SwiftUI
import UniformTypeIdentifiers

public struct PanoramaDemoView: View {
    enum MeshType: String, CaseIterable {
        case sphere = "Sphere"
        case box = "Box"
    }

    @State private var panoramaURL: URL? = Bundle.module.url(forResource: "IndoorEnvironmentHDRI013_1K-HDR", withExtension: "exr")
    @State private var panoramaTexture: MTLTexture?
    @State private var projection: any ProjectionProtocol = PerspectiveProjection()
    @State private var cameraMatrix: simd_float4x4 = .init(translation: [0, 0, 1])
    @State private var mesh: MTKMesh?
    @State private var meshType: MeshType = .sphere
    @State private var showMS = false
    @State private var applyGammaCorrection = false
    @State private var intermediateTexture: MTLTexture?
    @State private var outputTexture: MTLTexture?
    @State private var loadTask: Task<Void, Never>?
    @State private var resourceCollection: ResourceCollection?

    public init() {
        // This line intentionally left blank.
    }

    public var body: some View {
        ZStack {
            SuperImportWell(url: $panoramaURL, identifier: "panorama", allowedContentTypes: [.image]) { _ in
                WorldView(projection: $projection, cameraMatrix: $cameraMatrix) {
                    if let panoramaTexture, let mesh, let resourceCollection {
                        RenderView { _, drawableSize in
                            try Group {
                                if applyGammaCorrection, let intermediateTexture, let outputTexture {
                                    // Render panorama to intermediate texture
                                    try RenderPass {
                                        // The previous frame's gamma pass may still be reading the intermediate texture.
                                        QueueBarrier(after: .dispatch, before: .fragment)
                                        try PanoramaElement(projectionMatrix: projection.projectionMatrix(for: drawableSize), cameraMatrix: cameraMatrix, panoramaTexture: panoramaTexture, mesh: mesh, showMS: showMS)
                                    }
                                    .renderPassDescriptorModifier { descriptor in
                                        descriptor.colorAttachments[0].texture = intermediateTexture
                                        descriptor.colorAttachments[0].loadAction = .clear
                                        descriptor.colorAttachments[0].storeAction = .store
                                    }

                                    // Apply gamma correction using ColorAdjustComputePipeline
                                    try ComputePass(label: "GammaCorrection") {
                                        // Reads the intermediate texture, and overwrites the output the previous frame sampled.
                                        QueueBarrier(after: .fragment, before: .dispatch)
                                        try ColorAdjustComputePipeline.gammaAdjustPipeline(inputSpecifier: .texture2D(intermediateTexture), inputParameters: 2.2, outputTexture: outputTexture)
                                    }
                                    .barrierAfterPass(after: .dispatch, beforeQueueStages: .fragment)

                                    // Render gamma-corrected result to screen
                                    try RenderPass {
                                        try TextureBillboardPipeline(specifier: .texture2D(outputTexture))
                                    }
                                } else {
                                    // Render directly without gamma correction
                                    try RenderPass {
                                        try PanoramaElement(projectionMatrix: projection.projectionMatrix(for: drawableSize), cameraMatrix: cameraMatrix, panoramaTexture: panoramaTexture, mesh: mesh, showMS: showMS)
                                    }
                                }
                            }
                            .useResourceCollection(resourceCollection)
                        }
                        .onUsableDrawableSizeChange { size in
                            let device = _MTLCreateSystemDefaultDevice()
                            let width = Int(size.width)
                            let height = Int(size.height)
                            let oldTargets = [intermediateTexture, outputTexture]
                            defer {
                                updateResidency(removing: oldTargets, adding: [intermediateTexture, outputTexture])
                            }

                            intermediateTexture = device.makeTexture2D(
                                pixelFormat: .rgba8Unorm,
                                width: width,
                                height: height,
                                usage: [.renderTarget, .shaderRead],
                                storageMode: .private,
                                label: "Panorama Intermediate Texture"
                            )
                            outputTexture = device.makeTexture2D(
                                pixelFormat: .rgba8Unorm,
                                width: width,
                                height: height,
                                storageMode: .private,
                                label: "Panorama Gamma Output Texture"
                            )
                        }
                    } else {
                        Text("Use 'Load Panorama' to load a 360° image")
                            .foregroundColor(.secondary)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if let panoramaTexture, let resourceCollection {
                        ZStack {
                            PanoramaMiniMapView(panoramaTexture: panoramaTexture, cameraMatrix: cameraMatrix, resourceCollection: resourceCollection)
                        }
                        .frame(width: 320, height: 320)
                        .padding(8)
                        .background(.thinMaterial, in: Circle())
                        .padding()
                        .allowsHitTesting(false)
                    }
                }
            }
        }
        .demoConfiguration {
            Form {
                Picker("Mesh", selection: $meshType) {
                    ForEach(MeshType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }

                Toggle("Show MS", isOn: $showMS)

                Toggle("Gamma Correction", isOn: $applyGammaCorrection)

                SuperImportWidget(url: $panoramaURL, identifier: "panorama", allowedContentTypes: [.image])
            }
            .formStyle(.grouped)
        }
        .onChange(of: panoramaURL, initial: true) {
            if let panoramaURL {
                loadPanoramaFromURL(panoramaURL)
            }
        }
        .onChange(of: meshType, initial: true) {
            let oldBuffers = mesh?.buffers ?? []
            switch meshType {
            case .sphere:
                mesh = MTKMesh.sphere(extent: [50, 50, 50], inwardNormals: true)
            case .box:
                mesh = MTKMesh.box(extent: [50, 50, 50], inwardNormals: true)
            }
            updateResidency(removing: oldBuffers, adding: mesh?.buffers ?? [])
        }
    }

    private func updateResidency(removing old: [(any MTLAllocation)?], adding new: [(any MTLAllocation)?]) {
        do {
            let collection = try resourceCollection ?? ResourceCollection(device: _MTLCreateSystemDefaultDevice())
            try collection.replace(old, with: new)
            resourceCollection = collection
        } catch {
            assertionFailure("\(error)")
        }
    }

    func loadPanoramaFromURL(_ url: URL) {
        loadTask?.cancel()
        loadTask = Task {
            do {
                let device = _MTLCreateSystemDefaultDevice()
                let textureLoader = MTKTextureLoader(device: device)
                let texture = try await textureLoader.newTexture(URL: url, options: [.textureUsage: MTLTextureUsage.shaderRead.rawValue, .textureStorageMode: MTLStorageMode.private.rawValue])
                guard !Task.isCancelled else {
                    return
                }
                await MainActor.run {
                    updateResidency(removing: [panoramaTexture], adding: [texture])
                    panoramaTexture = texture
                }
            } catch {
                if !Task.isCancelled {
                    fatalError("Failed to load panorama: \(error)")
                }
            }
        }
    }
}
