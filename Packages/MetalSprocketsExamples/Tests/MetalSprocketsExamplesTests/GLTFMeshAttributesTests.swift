@testable import MetalSprocketsExamples
import simd
import SwiftMesh
import Testing

@Suite
struct GLTFMeshAttributesTests {
    /// A single triangle in the XY plane, so the generated smooth normals all point along +Z.
    private static func triangleMesh() -> SwiftMesh.Mesh {
        SwiftMesh.Mesh(
            positions: [[0, 0, 0], [1, 0, 0], [0, 1, 0]],
            faces: [[0, 1, 2]]
        )
    }

    private static let tangentsAlongX: [SIMD4<Float>] = [
        [1, 0, 0, 1], [1, 0, 0, 1], [1, 0, 0, 1]
    ]

    @Test("Bitangents follow the glTF handedness convention")
    func whenHandednessIsPositive_thenBitangentIsCrossOfNormalAndTangent() {
        let normals: [SIMD3<Float>] = [[0, 0, 1]]
        let tangents: [SIMD4<Float>] = [[1, 0, 0, 1]]
        let result = GLTFMeshAttributes.bitangents(normals: normals, tangents: tangents)
        #expect(result == [cross(SIMD3<Float>(0, 0, 1), SIMD3<Float>(1, 0, 0))])
    }

    @Test("Negative handedness flips the bitangent")
    func whenHandednessIsNegative_thenBitangentIsFlipped() {
        let normals: [SIMD3<Float>] = [[0, 0, 1]]
        let positive = GLTFMeshAttributes.bitangents(normals: normals, tangents: [[1, 0, 0, 1]])
        let negative = GLTFMeshAttributes.bitangents(normals: normals, tangents: [[1, 0, 0, -1]])
        #expect(negative == positive?.map { -$0 })
    }

    @Test("Mismatched attribute counts produce no bitangents")
    func whenCountsDisagree_thenBitangentsAreNil() {
        let result = GLTFMeshAttributes.bitangents(normals: [[0, 0, 1]], tangents: [])
        #expect(result == nil)
    }

    @Test("Tangents supplied without normals still yield bitangents")
    func whenTangentsSuppliedWithoutNormals_thenBitangentsAreGenerated() {
        var mesh = Self.triangleMesh()
        GLTFMeshAttributes.apply(
            to: &mesh,
            perVertexNormals: nil,
            perVertexTangents: Self.tangentsAlongX,
            perVertexUVs: nil
        )
        #expect(mesh.tangents != nil)
        #expect(mesh.bitangents != nil, "glTF TANGENT without NORMAL must still produce bitangents")
        #expect(mesh.bitangents?.count == mesh.tangents?.count)
    }

    @Test("Supplied normals and tangents are combined into bitangents")
    func whenNormalsAndTangentsSupplied_thenBitangentsUseBoth() throws {
        var mesh = Self.triangleMesh()
        GLTFMeshAttributes.apply(
            to: &mesh,
            perVertexNormals: [[0, 0, 1], [0, 0, 1], [0, 0, 1]],
            perVertexTangents: Self.tangentsAlongX,
            perVertexUVs: nil
        )
        let expected = cross(SIMD3<Float>(0, 0, 1), SIMD3<Float>(1, 0, 0))
        let bitangents = try #require(mesh.bitangents)
        #expect(bitangents.allSatisfy { distance($0, expected) < 1e-6 })
    }
}
