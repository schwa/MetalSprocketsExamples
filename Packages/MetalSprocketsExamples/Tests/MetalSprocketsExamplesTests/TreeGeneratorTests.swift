import CoreGraphics
import Foundation
import ImageIO
import MetalSprockets
@testable import MetalSprocketsExamples
import MetalSprocketsExampleShaders
import MetalSupport
import simd
import Testing
import UniformTypeIdentifiers

@Suite
struct TreeGeneratorTests {
    @Test("Each preset grows a connected skeleton with a trunk", arguments: TreePreset.allCases)
    func whenGeneratingPreset_thenSkeletonIsConnected(preset: TreePreset) {
        var parameters = TreeParameters()
        preset.apply(to: &parameters)
        let (skeleton, leaves) = SpaceColonization.generate(parameters)
        #expect(skeleton.positions.count > skeleton.trunkNodeCount + 10)
        #expect(skeleton.parents[0] == -1)
        #expect(skeleton.parents.dropFirst().allSatisfy { $0 >= 0 && $0 < skeleton.positions.count })
        #expect(parameters.useFoliage == !leaves.isEmpty)
    }

    @Test("Same seed reproduces the same tree")
    func whenSeedIsFixed_thenOutputIsDeterministic() {
        let parameters = TreeParameters()
        let first = SpaceColonization.generate(parameters).skeleton.positions
        let second = SpaceColonization.generate(parameters).skeleton.positions
        #expect(first == second)
    }

    /// Writes preview PNGs to $TMPDIR/TreeGenerator-<preset>.png.
    @Test("Render preset previews offscreen", arguments: TreePreset.allCases)
    func renderPreview(preset: TreePreset) throws {
        var parameters = TreeParameters()
        preset.apply(to: &parameters)
        let (skeleton, leaves) = SpaceColonization.generate(parameters)
        let mesh = TreeMesh.build(skeleton: skeleton, leaves: leaves, parameters: parameters)
        let device = _MTLCreateSystemDefaultDevice()
        let buffer = try #require(mesh.makeBuffer(device: device))

        let size = CGSize(width: 800, height: 800)
        let camera = float4x4.translation(0, 4, 0) * float4x4(simd_quatf(angle: -.pi / 12, axis: [1, 0, 0])) * float4x4.translation(0, 0, 11)
        let projection = float4x4.perspective(fovY: .pi / 4, aspect: 1, near: 0.1, far: 500)
        let uniforms = TreeGeneratorUniforms(
            viewProjection: projection * camera.inverse,
            lightDirection: normalize(SIMD3<Float>(0.5, 1, 0.4)),
            cameraPosition: SIMD3(camera.columns.3.x, camera.columns.3.y, camera.columns.3.z)
        )
        let renderer = try OffscreenRenderer(size: size)
        let image = try renderer.render(
            try RenderPass {
                try TreeGeneratorElement(vertexBuffer: buffer, vertexCount: mesh.vertices.count, uniforms: uniforms)
            }
        ).cgImage

        let url = FileManager.default.temporaryDirectory.appending(path: "TreeGenerator-\(preset.rawValue).png")
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        print("Preview: \(url.path) — \(mesh.nodeCount) nodes, \(mesh.leafCount) leaves")
    }
}
