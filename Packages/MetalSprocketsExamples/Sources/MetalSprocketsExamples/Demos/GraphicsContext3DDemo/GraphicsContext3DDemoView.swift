import DemoKit
import Interaction3D
import MetalSprockets
import MetalSprocketsAddOns
import MetalSprocketsSupport
import MetalSprocketsUI
import MetalSupport
import simd
import SwiftUI

public struct GraphicsContext3DDemoView: View {
    public init() { }

    @State private var cameraRotation = simd_quatf(angle: -.pi / 6, axis: [1, 0, 0])
    @State private var cameraDistance: Float = 8
    @State private var cameraTarget: SIMD3<Float> = .zero
    @State private var lineWidth: Float = 3.0
    @State private var showWireframe = false
    @State private var capStyleIndex = 0
    @State private var joinStyleIndex = 0
    @State private var slugScene: SlugScene?

    private var cameraMatrix: simd_float4x4 {
        let rotation = float4x4(cameraRotation)
        let translation = float4x4.translation(cameraTarget.x, cameraTarget.y, cameraTarget.z)
        let distance = float4x4.translation(0, 0, cameraDistance)
        return translation * rotation * distance
    }

    private var lineCap: CGLineCap {
        [.butt, .round, .square][capStyleIndex]
    }

    private var lineJoin: CGLineJoin {
        [.miter, .round, .bevel][joinStyleIndex]
    }

    private var renderView: some View {
        RenderView { _, drawableSize in
            let aspect = drawableSize.height > 0 ? Float(drawableSize.width / drawableSize.height) : 1.0
            let projectionMatrix = float4x4.perspective(fovY: .pi / 4, aspect: aspect, near: 0.1, far: 1_000.0)
            let viewProjection = projectionMatrix * cameraMatrix.inverse
            let viewport = SIMD2<Float>(Float(drawableSize.width), Float(drawableSize.height))

            let style = StrokeStyle(lineWidth: CGFloat(lineWidth), lineCap: lineCap, lineJoin: lineJoin)

            let context = GraphicsContext3D { ctx in
                // A star shape on the XZ ground plane
                let starPath = Self.starPath(points: 5, outerRadius: 2.0, innerRadius: 0.8, y: 0.1)
                ctx.fill(starPath, with: .yellow.opacity(0.3))
                ctx.stroke(starPath, with: .yellow, style: style)

                // A triangle floating above
                let triPath = Path3D { p in
                    p.move(to: [-1.5, 2, -1])
                    p.addLine(to: [1.5, 2, -1])
                    p.addLine(to: [0, 2, 1.5])
                    p.closeSubpath()
                }
                ctx.fill(triPath, with: .cyan.opacity(0.3))
                ctx.stroke(triPath, with: .cyan, style: style)

                // An open zigzag path
                let zigzag = Path3D { p in
                    p.move(to: [-3, 1, 0])
                    p.addLine(to: [-2, 3, 0.5])
                    p.addLine(to: [-1, 1, -0.5])
                    p.addLine(to: [0, 3, 0])
                    p.addLine(to: [1, 1, 0.5])
                    p.addLine(to: [2, 3, -0.5])
                    p.addLine(to: [3, 1, 0])
                }
                ctx.stroke(zigzag, with: .red, style: style)

                // A square floating behind
                let square = Path3D { p in
                    p.move(to: [-1, 0.5, -2])
                    p.addLine(to: [1, 0.5, -2])
                    p.addLine(to: [1, 2.5, -2])
                    p.addLine(to: [-1, 2.5, -2])
                    p.closeSubpath()
                }
                ctx.fill(square, with: Color(red: 0.0, green: 0.8, blue: 0.6))
                ctx.stroke(square, with: Color(red: 0.0, green: 0.8, blue: 0.6), style: style)

                // Wireframe cube
                Self.strokeCube(ctx: &ctx, center: [4, 1, 0], size: 2, color: .orange, style: style)

                // Wireframe pyramid
                Self.strokePyramid(ctx: &ctx, center: [-4, 0.1, 0], base: 2, height: 2.5, color: .purple, style: style)

                // Hexagon on the ground
                let hexagon = Path3D { p in
                    for i in 0..<6 {
                        let angle: Float = Float(i) / 6.0 * 2 * Float.pi
                        let pt = SIMD3<Float>(cos(angle) * 1.5 + 6, 0.1, sin(angle) * 1.5 - 3)
                        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                    }
                    p.closeSubpath()
                }
                ctx.fill(hexagon, with: Color(red: 0.6, green: 0.3, blue: 0.8))

                // Arrow shape on the XY plane
                let arrow = Path3D { p in
                    p.move(to: [-6, 1, -3])
                    p.addLine(to: [-4.5, 1, -3])
                    p.addLine(to: [-4.5, 0.5, -3])
                    p.addLine(to: [-3.5, 1.5, -3])
                    p.addLine(to: [-4.5, 2.5, -3])
                    p.addLine(to: [-4.5, 2, -3])
                    p.addLine(to: [-6, 2, -3])
                    p.closeSubpath()
                }
                ctx.fill(arrow, with: Color(red: 0.2, green: 0.6, blue: 1.0))

                // L-shape on the XY plane
                let lShape = Path3D { p in
                    p.move(to: [5, 0.5, -3])
                    p.addLine(to: [7, 0.5, -3])
                    p.addLine(to: [7, 1.5, -3])
                    p.addLine(to: [6, 1.5, -3])
                    p.addLine(to: [6, 3, -3])
                    p.addLine(to: [5, 3, -3])
                    p.closeSubpath()
                }
                ctx.fill(lShape, with: Color(red: 1.0, green: 0.5, blue: 0.0))

                // Cross / plus shape on the XY plane
                let cross = Path3D { p in
                    let cx: Float = 0, cy: Float = 1.5, cz: Float = -4
                    let arm: Float = 0.8, half: Float = 0.3
                    p.move(to: [cx - half, cy + arm, cz])
                    p.addLine(to: [cx + half, cy + arm, cz])
                    p.addLine(to: [cx + half, cy + half, cz])
                    p.addLine(to: [cx + arm, cy + half, cz])
                    p.addLine(to: [cx + arm, cy - half, cz])
                    p.addLine(to: [cx + half, cy - half, cz])
                    p.addLine(to: [cx + half, cy - arm, cz])
                    p.addLine(to: [cx - half, cy - arm, cz])
                    p.addLine(to: [cx - half, cy - half, cz])
                    p.addLine(to: [cx - arm, cy - half, cz])
                    p.addLine(to: [cx - arm, cy + half, cz])
                    p.addLine(to: [cx - half, cy + half, cz])
                    p.closeSubpath()
                }
                ctx.fill(cross, with: Color(red: 0.9, green: 0.2, blue: 0.2))

                // Spiral corkscrew
                let spiral = Path3D { p in
                    let turns: Float = 3
                    let segments = 120
                    let radius: Float = 1.2
                    let height: Float = 3.0
                    let cx: Float = 0
                    let cz: Float = 3
                    for i in 0...segments {
                        let t = Float(i) / Float(segments)
                        let angle: Float = t * turns * 2 * Float.pi
                        let x = cx + cos(angle) * radius
                        let y = t * height
                        let z = cz + sin(angle) * radius
                        if i == 0 { p.move(to: [x, y, z]) }
                        else { p.addLine(to: [x, y, z]) }
                    }
                }
                ctx.stroke(spiral, with: Color(red: 1, green: 0.4, blue: 0.7), style: style)
            }

            try RenderPass(label: "GraphicsContext3D Demo") {
                GridShader(
                    projectionMatrix: projectionMatrix,
                    cameraMatrix: cameraMatrix,
                    highlightedLines: [
                        .init(axis: .x, position: 0, width: 0.03, color: [1, 0.2, 0.2, 0.5]),
                        .init(axis: .y, position: 0, width: 0.03, color: [0.2, 0.4, 1, 0.5])
                    ],
                    backfaceColor: [1, 0, 1, 1]
                )

                GraphicsContext3DRenderPipeline(
                    context: context,
                    viewProjection: viewProjection,
                    viewport: viewport,
                    debugWireframe: showWireframe
                )

                if let slugScene {
                    try SlugTextRenderPipeline(
                        scene: slugScene,
                        frameConstants: SlugFrameConstants(
                            viewProjectionMatrix: viewProjection,
                            viewportSize: drawableSize
                        )
                    )
                }
            }
        }
        .metalDepthStencilPixelFormat(.depth32Float)
    }

    public var body: some View {
        renderView
        .frameTimingOverlay()
        .interactiveCamera(rotation: $cameraRotation, distance: $cameraDistance, target: $cameraTarget)
        .onAppear { initializeSlugText() }
        .demoConfiguration {
            Form {
                Section("Stroke") {
                    LabeledContent("Line Width") {
                        Slider(value: $lineWidth, in: 0.5...20)
                    }
                    Picker("Cap", selection: $capStyleIndex) {
                        Text("Butt").tag(0)
                        Text("Round").tag(1)
                        Text("Square").tag(2)
                    }
                    Picker("Join", selection: $joinStyleIndex) {
                        Text("Miter").tag(0)
                        Text("Round").tag(1)
                        Text("Bevel").tag(2)
                    }
                }
                Section("Debug") {
                    Toggle("Wireframe", isOn: $showWireframe)
                }
            }
            .formStyle(.grouped)
        }
    }

    static func strokeCube(ctx: inout GraphicsContext3D, center: SIMD3<Float>, size: Float, color: Color, style: MetalSprocketsAddOns.StrokeStyle) {
        let h = size * 0.5
        let c = center
        // 8 vertices
        let v: [SIMD3<Float>] = [
            c + [-h, -h, -h], c + [h, -h, -h], c + [h, h, -h], c + [-h, h, -h],  // back face
            c + [-h, -h, h], c + [h, -h, h], c + [h, h, h], c + [-h, h, h]       // front face
        ]
        // 6 faces as closed paths
        let faces: [[Int]] = [
            [0, 1, 2, 3], [4, 5, 6, 7],  // back, front
            [0, 1, 5, 4], [2, 3, 7, 6],  // bottom, top
            [0, 3, 7, 4], [1, 2, 6, 5]   // left, right
        ]
        for face in faces {
            let path = Path3D { p in
                p.move(to: v[face[0]])
                for i in 1..<face.count { p.addLine(to: v[face[i]]) }
                p.closeSubpath()
            }
            ctx.stroke(path, with: color, style: style)
        }
    }

    static func strokePyramid(ctx: inout GraphicsContext3D, center: SIMD3<Float>, base: Float, height: Float, color: Color, style: MetalSprocketsAddOns.StrokeStyle) {
        let h = base * 0.5
        let apex = center + [0, height, 0]
        let v: [SIMD3<Float>] = [
            center + [-h, 0, -h], center + [h, 0, -h],
            center + [h, 0, h], center + [-h, 0, h]
        ]
        // Base
        let basePath = Path3D { p in
            p.move(to: v[0])
            for i in 1..<4 { p.addLine(to: v[i]) }
            p.closeSubpath()
        }
        ctx.stroke(basePath, with: color, style: style)
        // 4 triangular faces
        for i in 0..<4 {
            let path = Path3D { p in
                p.move(to: v[i])
                p.addLine(to: v[(i + 1) % 4])
                p.addLine(to: apex)
                p.closeSubpath()
            }
            ctx.stroke(path, with: color, style: style)
        }
    }

    private func initializeSlugText() {
        guard slugScene == nil else {
            return
        }
        let device = _MTLCreateSystemDefaultDevice()
        let builder = SlugTextMeshBuilder(device: device)
        let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, 24, nil)

        struct Label {
            var text: String
            var position: SIMD3<Float>
            var color: Color
        }

        let labels: [Label] = [
            .init(text: "Star", position: [0, 0.5, 0], color: .yellow),
            .init(text: "Triangle", position: [-1.5, 3.2, -1], color: .cyan),
            .init(text: "Zigzag", position: [-3, 3.5, 0], color: .red),
            .init(text: "Square", position: [-1, 3, -2], color: Color(red: 0, green: 0.8, blue: 0.6)),
            .init(text: "Cube", position: [4, 2.5, 0], color: .orange),
            .init(text: "Pyramid", position: [-4, 3, 0], color: .purple),
            .init(text: "Spiral", position: [0, 3.5, 3], color: Color(red: 1, green: 0.4, blue: 0.7)),
            .init(text: "Hexagon", position: [6, 0.5, -3], color: .purple),
            .init(text: "Arrow", position: [-5, 3, -3], color: Color(red: 0.2, green: 0.6, blue: 1.0)),
            .init(text: "L-Shape", position: [5.5, 3.5, -3], color: .orange),
            .init(text: "Cross", position: [0, 3, -4], color: .red)
        ]

        for label in labels {
            var str = AttributedString(label.text)
            str.foregroundColor = label.color
            builder.buildMesh(attributedString: str, font: font, maximumSize: CGSize(width: 500, height: 100))
        }

        guard let scene = try? builder.finalize()
        else { return }

        let scale: Float = 0.01
        for (i, label) in labels.enumerated() {
            let mesh = scene.meshes[i]
            let centering = float4x4.translation(-Float(mesh.bounds.midX), -Float(mesh.bounds.midY), 0)
            scene.withModelMatrices { matrices in
                matrices[i] = float4x4.translation(label.position.x, label.position.y, label.position.z)
                    * float4x4.scale(scale, scale, scale)
                    * centering
            }
        }

        slugScene = scene
    }

    /// Creates a star path on the XZ plane at the given Y height.
    static func starPath(points: Int, outerRadius: Float, innerRadius: Float, y: Float) -> Path3D {
        Path3D { p in
            let totalPoints = points * 2
            for i in 0..<totalPoints {
                let angle: Float = Float(i) / Float(totalPoints) * 2 * Float.pi - Float.pi / 2
                let radius: Float = i.isMultiple(of: 2) ? outerRadius : innerRadius
                let point = SIMD3<Float>(cos(angle) * radius, y, sin(angle) * radius)
                if i == 0 {
                    p.move(to: point)
                } else {
                    p.addLine(to: point)
                }
            }
            p.closeSubpath()
        }
    }
}
