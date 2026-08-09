import GeometryLite3D
@testable import MetalSprocketsExamples
import simd
import Testing

@Suite
struct PBRNormalMatrixTests {
    @Test("A rigid transform leaves normals alone apart from rotation")
    func whenTransformIsRotation_thenNormalMatrixIsTheSameRotation() {
        let rotation = float4x4(simd_quatf(angle: .pi / 3, axis: normalize([1, 2, 3])))
        let normalMatrix = pbrNormalMatrix(modelTransform: rotation)
        let upperLeft = float3x3(rotation[0].xyz, rotation[1].xyz, rotation[2].xyz)
        for column in 0..<3 {
            #expect(distance(normalMatrix[column], upperLeft[column]) < 1e-5)
        }
    }

    @Test("Non-uniform scale inverts on the normal")
    func whenTransformScalesNonUniformly_thenNormalMatrixScalesInversely() {
        let scale = float4x4(scale: [2, 4, 8])
        let normalMatrix = pbrNormalMatrix(modelTransform: scale)
        #expect(abs(normalMatrix[0][0] - 0.5) < 1e-5)
        #expect(abs(normalMatrix[1][1] - 0.25) < 1e-5)
        #expect(abs(normalMatrix[2][2] - 0.125) < 1e-5)
    }

    @Test("A normal stays perpendicular to a stretched surface")
    func whenSurfaceIsStretched_thenTransformedNormalStaysPerpendicular() {
        // A surface tangent along X and the matching +Y normal, stretched only in Y.
        let transform = float4x4(scale: [1, 4, 1])
        let tangent = SIMD3<Float>(1, 1, 0)
        let normal = SIMD3<Float>(-1, 1, 0)
        #expect(abs(dot(tangent, normal)) < 1e-6)

        let transformedTangent = (transform * SIMD4<Float>(tangent, 0)).xyz
        let transformedNormal = pbrNormalMatrix(modelTransform: transform) * normal
        #expect(abs(dot(normalize(transformedTangent), normalize(transformedNormal))) < 1e-5)
    }
}
