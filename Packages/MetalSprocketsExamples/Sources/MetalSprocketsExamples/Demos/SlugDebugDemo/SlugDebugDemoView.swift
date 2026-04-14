import MetalSprockets
import MetalSprocketsAddOns
import MetalSprocketsUI
import simd
import SwiftUI

public struct SlugDebugDemoView: View {
    public init() { }

    @State private var scene: SlugScene?
    @State private var camera = SlugCamera()

    public var body: some View {
        ZStack {
            if let scene {
                SlugDebugRenderView(scene: scene, camera: $camera)
            }
        }
        .ignoresSafeArea()
        .metalClearColor(MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0))
        .frameTimingOverlay()
        .onAppear { initializeText() }
        #if os(macOS)
        .overlay {
            ScrollWheelCaptureView { delta in
                camera.scroll(delta: delta)
            }
        }
        #endif
        .slugCameraDragGesture(camera: $camera)
        .onDisappear { scene = nil }
    }

    private func initializeText() {
        guard scene == nil
        else { return }
        guard let device = MTLCreateSystemDefaultDevice()
        else { fatalError("No Metal device") }
        let builder = SlugTextMeshBuilder(device: device)

        let font = CTFontCreateWithName("HelveticaNeue" as CFString, 48, nil)

        var hello = AttributedString("HELLO")
        hello.foregroundColor = .red
        builder.buildMesh(attributedString: hello, font: font, maximumSize: CGSize(width: 1_000, height: 200))

        var world = AttributedString("WORLD")
        world.foregroundColor = .blue
        builder.buildMesh(attributedString: world, font: font, maximumSize: CGSize(width: 1_000, height: 200))

        guard let scene = try? builder.finalize()
        else { return }
        self.scene = scene

        let mesh = scene.meshes[0]
        let cx = Float(mesh.bounds.midX)
        let cy = Float(mesh.bounds.midY)
        let center = float4x4.translation(-cx, -cy, 0)
        scene.modelMatrices[0] = center * float4x4.translation(0, 15, 0)
        scene.modelMatrices[1] = center * float4x4.translation(0, -15, 0)

        camera.frameBounds(size: mesh.bounds.size, aspectRatio: 1.0)
    }
}

private struct SlugDebugRenderView: View {
    let scene: SlugScene
    @Binding var camera: SlugCamera

    public var body: some View {
        RenderView { _, size in
            let aspectRatio = size.height > 0 ? Float(size.width / size.height) : 1.0
            let vpMatrix = camera.projectionMatrix(aspectRatio: aspectRatio) * camera.viewMatrix()

            let frameConstants = SlugFrameConstants(
                viewProjectionMatrix: vpMatrix,
                viewportSize: size
            )

            try RenderPass(label: "Slug Debug") {
                try SlugTextRenderPipeline(scene: scene, frameConstants: frameConstants)
            }
        }
    }
}
