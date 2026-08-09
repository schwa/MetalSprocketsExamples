import simd
import SwiftMesh

// swiftlint:disable discouraged_optional_collection

/// Maps glTF per-vertex mesh attributes onto a ``SwiftMesh/Mesh``'s per-corner attribute arrays.
///
/// glTF stores attributes per vertex; SwiftMesh stores them per half-edge (mesh corner), so every
/// attribute is scattered through the topology. Tangents also change representation: glTF encodes
/// them as `(x, y, z, w)` where `w` is the handedness of the tangent space, while SwiftMesh keeps
/// separate tangent and bitangent vectors.
enum GLTFMeshAttributes {
    /// Applies the supplied per-vertex attributes to `mesh`, then generates whatever is still missing.
    ///
    /// - Parameters:
    ///   - mesh: The mesh to populate. Its positions and faces must already be set.
    ///   - perVertexNormals: glTF `NORMAL` values, or `nil` to generate smooth normals.
    ///   - perVertexTangents: glTF `TANGENT` values as `(x, y, z, handedness)`, or `nil` to generate tangents.
    ///   - perVertexUVs: glTF `TEXCOORD_0` values, or `nil` to generate spherical UVs.
    static func apply(
        to mesh: inout SwiftMesh.Mesh,
        perVertexNormals: [SIMD3<Float>]?,
        perVertexTangents: [SIMD4<Float>]?,
        perVertexUVs: [SIMD2<Float>]?
    ) {
        let corners = mesh.topology.halfEdges

        if let perVertexNormals {
            mesh.normals = corners.map { perVertexNormals[$0.origin.raw] }
        }
        if let perVertexUVs {
            mesh.textureCoordinates = corners.map { perVertexUVs[$0.origin.raw] }
        }

        let cornerTangents = perVertexTangents.map { tangents in
            corners.map { tangents[$0.origin.raw] }
        }
        if let cornerTangents {
            mesh.tangents = cornerTangents.map(\.xyz)
        }

        if mesh.textureCoordinates == nil {
            mesh = mesh.withSphericalUVs()
        }
        if mesh.normals == nil {
            mesh = mesh.withSmoothNormals()
        }
        if mesh.tangents == nil {
            mesh = mesh.withTangents()
        }

        // Deliberately after normal generation: glTF bitangents are derived from the normal, so a mesh
        // that supplies TANGENT without NORMAL can only be completed once smooth normals exist. Doing
        // this earlier left such meshes with tangents but no bitangents.
        if let cornerTangents, mesh.bitangents == nil, let normals = mesh.normals {
            mesh.bitangents = bitangents(normals: normals, tangents: cornerTangents)
        }
    }

    /// Derives per-corner bitangents from normals and glTF `(x, y, z, w)` tangents.
    ///
    /// Per the glTF specification the bitangent is `cross(normal, tangent.xyz) * tangent.w`, where `w`
    /// is `+1` or `-1` and encodes the handedness of the tangent basis.
    ///
    /// - Returns: The bitangents, or `nil` if the two arrays disagree on length.
    static func bitangents(normals: [SIMD3<Float>], tangents: [SIMD4<Float>]) -> [SIMD3<Float>]? {
        guard normals.count == tangents.count else {
            return nil
        }
        return zip(normals, tangents).map { normal, tangent in
            cross(normal, tangent.xyz) * tangent.w
        }
    }
}
