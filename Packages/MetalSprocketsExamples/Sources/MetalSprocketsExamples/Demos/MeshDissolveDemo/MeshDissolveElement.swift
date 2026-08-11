import Metal
import MetalSprockets
import MetalSprocketsExampleShaders
import MetalSprocketsSupport
import simd
import SwiftMesh

/// Mesh dissolve animation styles. Matches the effect IDs in MeshDissolveShaders.metal.
enum MeshDissolveEffect: Int32, CaseIterable, Identifiable, Sendable {
    case none = 0
    case noiseDissolve = 1
    case voronoiChunks = 4
    case cellShrink = 5
    case fracture = 6
    case checkerboardFlip = 7
    case ripple = 8
    case pixelWipe = 9
    case stripeWipe = 10
    case hexCells = 11
    case crumble = 12
    case inkblot = 13
    case voxelCollapse = 14

    var id: Int32 { rawValue }

    var displayName: String {
        switch self {
        case .none: "None"
        case .noiseDissolve: "Noise Dissolve"
        case .voronoiChunks: "Voronoi Chunks"
        case .cellShrink: "Cell Shrink"
        case .fracture: "Fracture"
        case .checkerboardFlip: "Checkerboard Flip"
        case .ripple: "Ripple"
        case .pixelWipe: "Pixel Wipe"
        case .stripeWipe: "Stripe Wipe"
        case .hexCells: "Hex Cells"
        case .crumble: "Crumble"
        case .inkblot: "Inkblot"
        case .voxelCollapse: "Voxel Collapse"
        }
    }
}

/// Renders a `MetalMesh` through the triplanar-grid dissolve shaders.
/// Alpha blending is enabled so the grid's transparent cell interiors
/// composite over the clear color.
struct MeshDissolveElement: Element {
    let metalMesh: MetalMesh
    let transform: float4x4
    let uniforms: MeshDissolveUniforms

    @MSState
    private var vertexShader: VertexShader

    @MSState
    private var fragmentShader: FragmentShader

    init(metalMesh: MetalMesh, transform: float4x4, uniforms: MeshDissolveUniforms) throws {
        self.metalMesh = metalMesh
        self.transform = transform
        self.uniforms = uniforms
        let shaders = try ShaderNamespace.examples("MeshDissolve")
        vertexShader = try shaders.vertexMain
        fragmentShader = try shaders.fragmentMain
    }

    var body: some Element {
        get throws {
            try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                Draw { encoder in
                    encoder.draw(metalMesh)
                }
                .parameter("transform", value: transform)
                .parameter("uniforms", functionType: .vertex, value: uniforms)
                .parameter("uniforms", functionType: .fragment, value: uniforms)
            }
            .vertexDescriptor(metalMesh.vertexDescriptor.mtlVertexDescriptor)
            .depthCompare(function: .less, enabled: true)
            .renderPipelineDescriptorTransformer { descriptor in
                descriptor.colorAttachments[0].isBlendingEnabled = true
                descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
                descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
                descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
                descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            }
        }
    }
}
