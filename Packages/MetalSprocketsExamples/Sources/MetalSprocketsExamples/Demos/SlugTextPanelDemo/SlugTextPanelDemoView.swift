import Metal
import MetalSprockets
import MetalSprocketsAddOns
import MetalSprocketsSupport
import MetalSprocketsUI
import MetalSupport
import simd
import SwiftUI

public struct SlugTextPanelDemoView: View {
    public init() { }

    @State private var scene: SlugScene?
    @State private var camera = SlugCamera()
    @State private var showWireframe = false

    public var body: some View {
        ZStack {
            if let scene {
                SlugTextPanelRenderView(scene: scene, camera: $camera, wireframe: showWireframe)
            }
        }
        .ignoresSafeArea()
        .metalClearColor(MTLClearColor(red: 0.02, green: 0.02, blue: 0.02, alpha: 1.0))
        .frameTimingOverlay()
        .onAppear { initializeText() }
        .onDisappear { scene = nil }
        #if os(macOS)
        .overlay {
            ScrollWheelCaptureView { delta in
                camera.scroll(delta: delta)
            }
        }
        #endif
        .slugCameraDragGesture(camera: $camera)
        .toolbar {
            ToolbarItem {
                Toggle(isOn: $showWireframe) {
                    Label("Wireframe", systemImage: "square.dashed")
                }
                .help("Show glyph quad wireframes")
            }
        }
    }

    private func initializeText() {
        guard scene == nil else {
            return
        }
        let device = _MTLCreateSystemDefaultDevice()
        let builder = SlugTextMeshBuilder(device: device)
        builder.buildMesh(attributedString: DemoText.attributedString, maximumSize: defaultMaximumSize)
        guard let scene = try? builder.finalize()
        else { return }
        self.scene = scene

        let mesh = scene.meshes[0]
        scene.modelMatrices[0] = float4x4.translation(-Float(mesh.bounds.midX), -Float(mesh.bounds.midY), 0)
        camera.frameBounds(size: mesh.bounds.size, aspectRatio: 1.0)
    }
}

private struct SlugTextPanelRenderView: View {
    let scene: SlugScene
    @Binding var camera: SlugCamera
    let wireframe: Bool

    var body: some View {
        RenderView { _, size in
            let aspectRatio = size.height > 0 ? Float(size.width / size.height) : 1.0
            let vpMatrix = camera.projectionMatrix(aspectRatio: aspectRatio) * camera.viewMatrix()

            let frameConstants = SlugFrameConstants(
                viewProjectionMatrix: vpMatrix,
                viewportSize: size
            )

            try RenderPass(label: "Slug Text Panel") {
                try SlugTextRenderPipeline(scene: scene, frameConstants: frameConstants, wireframe: wireframe)
            }
        }
    }
}
