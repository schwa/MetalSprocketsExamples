#if os(iOS)
import ARKit
import MetalSprockets
import MetalSprocketsAddOns
import simd
import SwiftUI

struct ARAnchorsRenderPipeline: Element {
    var cameraMatrix: float4x4
    var projectionMatrix: float4x4
    var viewport: SIMD2<Float>
    var meshAnchors: [(anchor: ARMeshAnchor, meshWithEdges: MeshWithEdges)]
    var planeAnchors: [ARPlaneAnchor]
    var showMeshes: Bool
    var showPlanes: Bool
    var limitAnchors: Bool

    var body: some Element {
        get throws {
            let limitedMeshAnchors = limitAnchors ? Array(meshAnchors.prefix(1)) : meshAnchors
            let limitedPlaneAnchors = limitAnchors ? Array(planeAnchors.prefix(1)) : planeAnchors
            let viewProjectionMatrix = projectionMatrix * cameraMatrix

            try Group {
                if showMeshes {
                    ForEach(Array(limitedMeshAnchors.enumerated()), id: \.offset) { _, element in
                        let (anchor, meshWithEdges) = element
                        try EdgeLinesRenderPipeline(
                            meshWithEdges: meshWithEdges,
                            viewProjection: projectionMatrix * cameraMatrix.inverse,
                            viewport: viewport,
                        )
                    }
                }

                if showPlanes {
                    ForEach(Array(limitedPlaneAnchors.enumerated()), id: \.offset) { _, planeAnchor in
                        let localToWorld = planeAnchor.transform
                        let mvp = viewProjectionMatrix * localToWorld
                        try ARPlaneRenderPipeline(mvpMatrix: mvp, planeAnchor: planeAnchor, color: [0, 1, 0, 1])
                    }
                }
            }
        }
    }
}
#endif
