import DemoKit
import GeometryLite3D
import Interaction3D
import MetalKit
import MetalSprockets
import MetalSprocketsAddOns
import MetalSprocketsAddOnsShaders
import MetalSprocketsSupport
import MetalSprocketsUI
import simd
import SwiftUI

public struct DebugShaderDemoView: View {
    public init() { }

    @State private var cameraRotation = simd_quatf(angle: -.pi / 6, axis: [1, 0, 0])
    @State private var cameraDistance: Float = 6
    @State private var cameraTarget: SIMD3<Float> = [0, 1, 0]

    @State private var debugMode: DebugShadersMode = .normal

    let teapot = MTKMesh.teapot(options: [.generateTangentBasis, .generateTextureCoordinatesIfMissing, .useSimpleTextureCoordinates])

    private var cameraMatrix: simd_float4x4 {
        let rotation = float4x4(cameraRotation)
        let translation = float4x4.translation(cameraTarget.x, cameraTarget.y, cameraTarget.z)
        let distance = float4x4.translation(0, 0, cameraDistance)
        return translation * rotation * distance
    }

    public var body: some View {
        RenderView { _, drawableSize in
            let aspect = drawableSize.height > 0 ? Float(drawableSize.width / drawableSize.height) : 1.0
            let projectionMatrix = float4x4.perspective(fovY: .pi / 4, aspect: aspect, near: 0.1, far: 1_000.0)
            let viewMatrix = cameraMatrix.inverse
            let viewProjectionMatrix = projectionMatrix * viewMatrix

            try RenderPass(label: "Debug") {
                GridShader(
                    projectionMatrix: projectionMatrix,
                    cameraMatrix: cameraMatrix,
                    highlightedLines: [
                        .init(axis: .x, position: 0, width: 0.03, color: [1, 0.2, 0.2, 1]),
                        .init(axis: .y, position: 0, width: 0.03, color: [0.2, 0.4, 1, 1])
                    ],
                    backfaceColor: [1, 0, 1, 1]
                )

                try DebugRenderPipeline(
                    modelMatrix: .identity,
                    normalMatrix: .init(diagonal: [1, 1, 1]),
                    debugMode: debugMode,
                    lightPosition: [0, 10, 0],
                    cameraPosition: cameraMatrix.translation,
                    viewProjectionMatrix: viewProjectionMatrix
                ) {
                    Draw { encoder in
                        encoder.setVertexBuffers(of: teapot)
                        encoder.draw(teapot)
                    }
                }
                .vertexDescriptor(teapot.vertexDescriptor)
                .depthCompare(function: .less, enabled: true)
            }
        }
        .metalDepthStencilPixelFormat(.depth32Float)
        .interactiveCamera(rotation: $cameraRotation, distance: $cameraDistance, target: $cameraTarget)
        .frameTimingOverlay()
        .demoConfiguration {
            Form {
                DebugModePicker(debugMode: $debugMode)
            }
            .formStyle(.grouped)
        }
    }
}

private struct DebugModePicker: View {
    @Binding var debugMode: DebugShadersMode

    var body: some View {
        Picker("Debug Mode", selection: $debugMode) {
            ForEach(DebugShadersMode.allCases, id: \.self) { mode in
                Text(mode.description).tag(mode)
            }
        }
        .pickerStyle(.menu)
    }
}
