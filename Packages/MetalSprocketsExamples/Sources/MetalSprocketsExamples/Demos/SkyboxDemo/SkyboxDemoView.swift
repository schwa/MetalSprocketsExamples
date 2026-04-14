import DemoKit
import GeometryLite3D
import Interaction3D
import MetalKit
import MetalSprockets
import MetalSprocketsAddOns
import MetalSprocketsSupport
import MetalSprocketsUI
import SwiftUI

public struct SkyboxDemoView: View {
    @State
    private var texture: MTLTexture?

    @State
    private var projection: any ProjectionProtocol = PerspectiveProjection()

    @State
    private var cameraMatrix: simd_float4x4 = .init(translation: [0, 0, 1])

    @State
    private var showFaceLabels = false

    public init() {
        // This line intentionally left blank.
    }

    public var body: some View {
        WorldView(projection: $projection, cameraMatrix: $cameraMatrix) {
            RenderView { _, drawableSize in
                try RenderPass {
                    if let texture {
                        try SkyboxRenderPipeline(projectionMatrix: projection.projectionMatrix(for: drawableSize), cameraMatrix: cameraMatrix, texture: texture)
                    }
                }
            }
        }
        .demoConfiguration {
            Form {
                Toggle("Face Labels", isOn: $showFaceLabels)
            }
            .formStyle(.grouped)
        }
        .task(id: showFaceLabels) {
            do {
                texture = try testTexture(showFaceLabels: showFaceLabels)
            }
            catch {
                fatalError("Failed to create skybox texture: \(error)")
            }
        }
    }

    func testTexture(showFaceLabels: Bool) throws -> MTLTexture {
        let testView = ZStack {
            Image("Skybox")
                .resizable()
                .accessibilityHidden(true)

            if showFaceLabels {
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        Spacer()
                            .frame(width: 1_024, height: 1_024)
                        Color.green.opacity(0.2)
                            .overlay(Text("+Y").scaleEffect(10))
                            .frame(width: 1_024, height: 1_024)
                    }
                    GridRow {
                        Color.blue.opacity(0.2)
                            .overlay(Text("+X").scaleEffect(10))
                            .frame(width: 1_024, height: 1_024)

                        Color.red.opacity(0.2)
                            .overlay(Text("+Z").scaleEffect(10))
                            .frame(width: 1_024, height: 1_024)

                        Color.blue.opacity(0.2)
                            .overlay(Text("-X").scaleEffect(10))
                            .frame(width: 1_024, height: 1_024)

                        Color.red.opacity(0.2)
                            .overlay(Text("-Z").scaleEffect(10))
                            .frame(width: 1_024, height: 1_024)
                    }
                    GridRow {
                        Spacer()
                            .frame(width: 1_024, height: 1_024)
                        Color.green.opacity(0.2)
                            .overlay(Text("-Y").scaleEffect(10))
                            .frame(width: 1_024, height: 1_024)
                    }
                }
            }
        }
        .frame(width: 1_024 * 4, height: 1_024 * 3)
        let device = _MTLCreateSystemDefaultDevice()
        let texture2D = try device.makeTexture(content: testView)
        return try device.makeTextureCubeFromCrossTexture(texture: texture2D)
    }
}
