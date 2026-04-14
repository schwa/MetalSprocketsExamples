import Metal
import MetalSprockets
import MetalSprocketsAddOns
import MetalSprocketsUI
import simd
import SwiftUI

private struct MatrixColumn {
    let x: Float
    let speed: Float
    let length: Int
    let phase: Float
    let modelIndexStart: Int
}

public struct SlugMatrixRainDemoView: View {
    public init() { }

    @State private var scene: SlugScene?
    @State private var columns: [MatrixColumn] = []
    @State private var zoom: Float = 1.0
    @State private var startTime = Date()

    private let charSize: Float = 12.0
    private let columnSpacing: Float = 12.0
    private let maxColumnLength = 80

    public var body: some View {
        ZStack {
            if let scene {
                MatrixRainRenderView(columns: columns, scene: scene, zoom: zoom, startTime: startTime)
            }
        }
        .ignoresSafeArea()
        .metalClearColor(MTLClearColor(red: 0.051, green: 0.008, blue: 0.031, alpha: 1.0))
        .frameTimingOverlay()
        .onAppear { initialize() }
        #if os(macOS)
        .overlay {
            ScrollWheelCaptureView { delta in
                zoom = max(0.1, zoom * Float(1.0 + delta * 0.01))
            }
        }
        #endif
        .onDisappear {
            scene = nil
            columns = []
        }
    }

    // swiftlint:disable:next function_body_length
    private func initialize() {
        guard scene == nil
        else { return }
        guard let device = MTLCreateSystemDefaultDevice()
        else { fatalError("No Metal device") }
        let builder = SlugTextMeshBuilder(device: device)

        let matrixChars: [Character] = Array("アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン0123456789@#$%&*+=<>")
        let font = CTFontCreateWithName("Hiragino Kaku Gothic ProN" as CFString, CGFloat(charSize), nil)
        let allCharStrings = matrixChars.map { NSAttributedString(string: String($0), attributes: [.font: font]) }
        builder.prepopulateGlyphs(from: allCharStrings)

        let charCount = matrixChars.count
        let estimatedWidth: Float = 4_800
        let columnCount = Int(estimatedWidth / columnSpacing)
        let streamsPerColumn = 3
        var meshIndex = 0

        for i in 0..<columnCount {
            for _ in 0..<streamsPerColumn {
                let x = Float(i) * columnSpacing
                let speed = Float.random(in: 40...220)
                let length = Int.random(in: 25...maxColumnLength)
                let phase = Float.random(in: 0...2_000)
                let modelIndexStart = meshIndex

                for charSlot in 0..<length {
                    let charIdx = Int.random(in: 0..<charCount)
                    let brightness: Float = charSlot == 0 ? 1.0 : 0.7
                    let str = makeGreenString(String(matrixChars[charIdx]), brightness: brightness)
                    builder.buildMesh(attributedString: str, font: font, maximumSize: CGSize(width: 100, height: 100))
                    meshIndex += 1
                }

                columns.append(MatrixColumn(x: x, speed: speed, length: length, phase: phase, modelIndexStart: modelIndexStart))
            }
        }

        scene = try? builder.finalize()
    }

    private func makeGreenString(_ text: String, brightness: Float) -> AttributedString {
        let r: Double
        let g: Double
        let b: Double
        if brightness > 0.9 {
            r = Double(brightness * 0.8)
            g = Double(brightness)
            b = Double(brightness * 0.8)
        } else {
            r = Double(brightness * 0.0)
            g = Double(brightness)
            b = Double(brightness * 0.25)
        }
        var str = AttributedString(text)
        str.foregroundColor = Color(red: r, green: g, blue: b)
        return str
    }
}

// MARK: - Render Views

private struct MatrixRainRenderView: View {
    let columns: [MatrixColumn]
    let scene: SlugScene
    let zoom: Float
    let startTime: Date

    @State private var size: CGSize = .zero

    public var body: some View {
        TimelineView(.animation) { timeline in
            MatrixRainContent(scene: scene, zoom: zoom)
                .onGeometryChange(for: CGSize.self, of: \.size) { size = $0 }
                .onChange(of: timeline.date) {
                    let elapsed = Float(timeline.date.timeIntervalSince(startTime))
                    let charHeight: Float = 14.0
                    scene.withModelMatrices { matrices in
                        for column in columns {
                            let streamLength = Float(column.length) * charHeight
                            let wrapRange = Float(size.height) + streamLength * 2
                            let headY = (elapsed * column.speed + column.phase)
                                .truncatingRemainder(dividingBy: wrapRange) - streamLength
                            for charIdx in 0..<column.length {
                                let modelIdx = column.modelIndexStart + charIdx
                                guard modelIdx < matrices.count else { continue }
                                let y = headY - Float(charIdx) * charHeight
                                matrices[modelIdx].columns.3.x = column.x
                                matrices[modelIdx].columns.3.y = Float(size.height) - y
                            }
                        }
                    }
                }
        }
    }
}

private struct MatrixRainContent: View {
    let scene: SlugScene
    let zoom: Float

    public var body: some View {
        RenderView { _, size in
            let hw = Float(size.width) * 0.5
            let hh = Float(size.height) * 0.5
            let z = 1.0 / zoom
            let vpMatrix = float4x4.orthographic(
                left: hw - hw * z,
                right: hw + hw * z,
                bottom: hh - hh * z,
                top: hh + hh * z,
                near: -1,
                far: 1
            )
            let frameConstants = SlugFrameConstants(viewProjectionMatrix: vpMatrix, viewportSize: size)
            try RenderPass(label: "Slug Matrix Rain") {
                try SlugTextRenderPipeline(scene: scene, frameConstants: frameConstants)
            }
        }
    }
}
