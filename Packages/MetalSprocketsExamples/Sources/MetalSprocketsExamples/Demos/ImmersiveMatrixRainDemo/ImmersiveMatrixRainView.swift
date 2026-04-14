#if os(visionOS)
import CoreText
import Metal
import MetalSprockets
import MetalSprocketsAddOns
import MetalSprocketsUI
import simd
import SwiftUI

// MARK: - Shared State

/// Thread-safe lazy holder for the immersive matrix rain state.
final class ImmersiveMatrixRainStateHolder: @unchecked Sendable {
    static let shared = ImmersiveMatrixRainStateHolder()
    private var state: ImmersiveMatrixRainState?
    private let lock = NSLock()

    func getOrCreate(device: MTLDevice) throws -> ImmersiveMatrixRainState {
        lock.lock()
        defer { lock.unlock() }
        if let state {
            return state
        }
        let newState = try ImmersiveMatrixRainState(device: device)
        state = newState
        return newState
    }
}

/// Shared scene data for the immersive matrix rain.
final class ImmersiveMatrixRainState: @unchecked Sendable {
    let scene: SlugScene
    let columns: [MatrixColumn]

    struct MatrixColumn: Sendable {
        let angle: Float
        let radius: Float
        let speed: Float
        let length: Int
        let phase: Float
        let modelIndexStart: Int
    }

    init(device: MTLDevice) throws {
        let charSize: Float = 12.0
        let builder = SlugTextMeshBuilder(device: device)

        let matrixChars: [Character] = Array("アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン0123456789@#$%&*+=<>")
        let font = CTFontCreateWithName("Hiragino Kaku Gothic ProN" as CFString, CGFloat(charSize), nil)
        let allCharStrings = matrixChars.map { NSAttributedString(string: String($0), attributes: [.font: font]) }
        builder.prepopulateGlyphs(from: allCharStrings)

        let charCount = matrixChars.count
        let bands: [(radius: Float, count: Int, streams: Int)] = [
            (1.5, 40, 2),
            (3.0, 60, 2),
            (5.0, 80, 2),
            (8.0, 100, 1)
        ]

        var columns: [MatrixColumn] = []
        var meshIndex = 0

        for band in bands {
            for i in 0..<band.count {
                for _ in 0..<band.streams {
                    let angle = Float(i) / Float(band.count) * 2.0 * .pi + Float.random(in: 0...0.05)
                    let speed = Float.random(in: 0.3...1.5)
                    let length = Int.random(in: 10...40)
                    let phase = Float.random(in: 0...20)
                    let modelIndexStart = meshIndex

                    for charSlot in 0..<length {
                        let charIdx = Int.random(in: 0..<charCount)
                        let brightness: Float = charSlot == 0 ? 1.0 : 0.7
                        let str = Self.makeGreenString(String(matrixChars[charIdx]), brightness: brightness)
                        builder.buildMesh(attributedString: str, font: font, maximumSize: CGSize(width: 100, height: 100))
                        meshIndex += 1
                    }

                    columns.append(MatrixColumn(
                        angle: angle,
                        radius: band.radius,
                        speed: speed,
                        length: length,
                        phase: phase,
                        modelIndexStart: modelIndexStart
                    ))
                }
            }
        }

        self.scene = try builder.finalize()
        self.columns = columns
    }

    func updateModelMatrices(elapsed: Float) {
        let scale: Float = 0.005
        let charHeight: Float = 14.0 * scale
        let cylinderHeight: Float = 2.5
        let eyeHeight: Float = 1.5

        scene.withModelMatrices { matrices in
            for column in columns {
                let streamLength = Float(column.length) * charHeight
                let wrapRange = cylinderHeight + streamLength * 2
                let headY = (elapsed * column.speed + column.phase)
                    .truncatingRemainder(dividingBy: wrapRange) - streamLength

                let x = sin(column.angle) * column.radius
                let z = -cos(column.angle) * column.radius
                let faceInward = float4x4.rotation(angle: column.angle + .pi, axis: SIMD3(0, 1, 0))

                for charIdx in 0..<column.length {
                    let modelIdx = column.modelIndexStart + charIdx
                    guard modelIdx < matrices.count else { continue }
                    let y = eyeHeight + (cylinderHeight * 0.5) - (headY - Float(charIdx) * charHeight)
                    matrices[modelIdx] = float4x4.translation(x, y, z) * faceInward * float4x4.scale(scale, scale, scale)
                }
            }
        }
    }

    private static func makeGreenString(_ text: String, brightness: Float) -> AttributedString {
        let r = brightness > 0.9 ? Double(brightness * 0.8) : 0.0
        let g = Double(brightness)
        let b = brightness > 0.9 ? Double(brightness * 0.8) : Double(brightness * 0.25)
        var str = AttributedString(text)
        str.foregroundColor = Color(red: r, green: g, blue: b)
        return str
    }
}

// MARK: - Immersive Element

struct ImmersiveMatrixRainElement: Element, @unchecked Sendable {
    let context: ImmersiveContext
    let state: ImmersiveMatrixRainState

    nonisolated var body: some Element {
        get throws {
            let viewConstants = (0..<context.viewCount).map { eye in
                let vp = context.projectionMatrix(eye: eye) * context.viewMatrix(eye: eye)
                let viewport = context.viewports[eye]
                return SlugFrameConstants(
                    viewProjectionMatrix: vp,
                    viewportSize: SIMD2<Float>(Float(viewport.width), Float(viewport.height))
                )
            }

            try SlugTextRenderPipeline(
                scene: state.scene,
                viewConstants: viewConstants,
                viewports: context.viewports,
                colorPixelFormat: context.drawable.colorTextures[0].pixelFormat,
                depthPixelFormat: context.drawable.depthTextures[0].pixelFormat,
                reverseZ: true
            )
        }
    }
}

// MARK: - Immersive Space Content

struct ImmersiveMatrixRainContent: ImmersiveSpaceContent {
    var body: some ImmersiveSpaceContent {
        ImmersiveRenderContent { context in
            let state = try ImmersiveMatrixRainStateHolder.shared.getOrCreate(device: context.device)
            state.updateModelMatrices(elapsed: Float(context.time))

            return try ImmersiveRenderPass(context: context, label: "Matrix Rain") {
                ImmersiveMatrixRainElement(context: context, state: state)
            }
        }
    }
}

// MARK: - SwiftUI Entry Point

public struct ImmersiveMatrixRainView: View {
    public init() { }
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var isImmersive = false
    @State private var statusMessage = "Ready"

    public var body: some View {
        VStack(spacing: 20) {
            Text("Matrix Rain")
                .font(.largeTitle)

            Text(statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(isImmersive ? "Exit Immersive" : "Enter Immersive") {
                Task {
                    if isImmersive {
                        await dismissImmersiveSpace()
                        isImmersive = false
                        statusMessage = "Dismissed"
                    } else {
                        statusMessage = "Opening..."
                        let result = await openImmersiveSpace(id: "ImmersiveMatrixRain")
                        switch result {
                        case .opened:
                            isImmersive = true
                            statusMessage = "Opened"
                        case .userCancelled:
                            statusMessage = "User cancelled"
                        case .error:
                            statusMessage = "Error opening immersive space"
                        @unknown default:
                            statusMessage = "Unknown result"
                        }
                    }
                }
            }
            .font(.title2)
        }
        .padding()
    }
}
#endif
