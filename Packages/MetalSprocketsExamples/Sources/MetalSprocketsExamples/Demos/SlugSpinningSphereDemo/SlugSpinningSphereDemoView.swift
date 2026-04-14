import Metal
import MetalSprockets
import MetalSprocketsAddOns
import MetalSprocketsUI
import simd
import SwiftUI

private struct TextChannel {
    let meshes: [SlugTextMesh]
    let rotationSpeed: Float
    let tilt: Float
    let ascendingNode: Float
    let phase: Float
    let latitude: Float
}

public struct SlugSpinningSphereDemoView: View {
    public init() { }

    @State private var channels: [TextChannel] = []
    @State private var scene: SlugScene?
    @State private var startTime = Date()
    private let sphereRadius: Float = 20.0

    public var body: some View {
        ZStack {
            if let scene, !channels.isEmpty {
                SpinningSphereRenderView(channels: channels, scene: scene, startTime: startTime, sphereRadius: sphereRadius)
            }
        }
        .ignoresSafeArea()
        .metalClearColor(MTLClearColor(red: 0.02, green: 0.02, blue: 0.02, alpha: 1.0))
        .frameTimingOverlay()
        .onAppear { initializeChannels() }
        .onDisappear {
            channels = []
            scene = nil
        }
    }

    // swiftlint:disable:next function_body_length
    private func initializeChannels() {
        guard channels.isEmpty
        else { return }
        guard let device = MTLCreateSystemDefaultDevice()
        else { fatalError("No Metal device") }
        let builder = SlugTextMeshBuilder(device: device)

        let helloWorlds = [
            "Hello, World", "Bonjour, le monde", "Hola, mundo", "Hallo, Welt",
            "Ciao, mondo", "Olá, mundo", "Hej, världen", "Hei, verden",
            "こんにちは、世界", "สวัสดีชาวโลก", "你好，世界", "مرحبًا بالعالم",
            "नमस्ते, दुनिया", "Привет, мир", "Γεια σου, κόσμε", "שלום, עולם",
            "안녕하세요, 세계", "ሰላም ልዑል", "გამარჯობა სამყარო", "Բարեւ, աշխարհ",
            "မင်္ဂလာပါ၊ ကမ္ဘာလောက", "හෙලෝ වර්ල්ඩ්", "សួស្តី​ពិភពលោក",
            "ᠰᠠᠶᠢᠨ ᠳᠡᠯᠡᠬᠡᠢ", "வணக்கம், உலகம்", "হ্যালো, বিশ্ব",
            "سلام دنیا", "హలో, ప్రపంచం"
        ]
        let ringCount = helloWorlds.count
        let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, 24, nil)
        let allStrings = helloWorlds.map { NSAttributedString(string: $0, attributes: [.font: font]) }
        builder.prepopulateGlyphs(from: allStrings)

        var channelConfigs: [(meshIndices: [Int], speed: Float, tilt: Float, ascendingNode: Float, phase: Float, latitude: Float)] = []

        for i in 0..<ringCount {
            let instanceCount = 8
            let speed: Float = 0.8
            let tiltBand = i % 5
            let baseTilt: Float = switch tiltBand {
            case 0: 0
            case 1: .pi / 8
            case 2: .pi / 4
            case 3: -.pi / 8
            case 4: -.pi / 4
            default: 0
            }
            let tilt = baseTilt + Float.random(in: -0.05...0.05)
            let ascendingNode = Float(i) / Float(ringCount) * 2 * .pi + Float.random(in: -0.2...0.2)
            let phase = Float.random(in: 0 ... 2 * .pi)
            let baseHue = Float(i) / Float(ringCount)

            var meshIndices: [Int] = []
            for j in 0..<instanceCount {
                let hue = baseHue + Float(j) / Float(instanceCount) * 0.5
                let attributedString = Self.makeColoredString(text: helloWorlds[i], hue: hue)
                let index = builder.buildMesh(attributedString: attributedString, font: font, maximumSize: CGSize(width: 500, height: 100))
                meshIndices.append(index)
            }

            channelConfigs.append((meshIndices, speed, tilt, ascendingNode, phase, 0))
        }

        guard let scene = try? builder.finalize()
        else { return }
        self.scene = scene
        let allMeshes = scene.meshes

        for config in channelConfigs {
            let meshes = config.meshIndices.map { allMeshes[$0] }
            channels.append(TextChannel(
                meshes: meshes,
                rotationSpeed: config.speed,
                tilt: config.tilt,
                ascendingNode: config.ascendingNode,
                phase: config.phase,
                latitude: config.latitude
            ))
        }
    }

    private static func makeColoredString(text: String, hue: Float) -> AttributedString {
        let rgb = rgbFromHue(hue)
        var str = AttributedString(text)
        str.foregroundColor = Color(red: Double(rgb.x), green: Double(rgb.y), blue: Double(rgb.z))
        return str
    }
}

// MARK: - Render Views

private struct SpinningSphereRenderView: View {
    let channels: [TextChannel]
    let scene: SlugScene
    let startTime: Date
    let sphereRadius: Float

    public var body: some View {
        TimelineView(.animation) { timeline in
            SpinningSphereContent(scene: scene)
                .onChange(of: timeline.date) {
                    let elapsed = Float(timeline.date.timeIntervalSince(startTime))
                    let computed = Self.computeModelMatrices(channels: channels, elapsed: elapsed, sphereRadius: sphereRadius)
                    let matrices = scene.modelMatrices
                    for i in 0..<min(computed.count, matrices.count) {
                        matrices[i] = computed[i]
                    }
                }
        }
    }

    static func computeModelMatrices(channels: [TextChannel], elapsed: Float, sphereRadius: Float) -> [float4x4] {
        var matrices: [float4x4] = []
        for channel in channels {
            let rotation = elapsed * channel.rotationSpeed + channel.phase
            let tiltMatrix = float4x4.rotation(angle: channel.tilt, axis: SIMD3<Float>(0, 0, 1))
            let nodeMatrix = float4x4.rotation(angle: channel.ascendingNode, axis: SIMD3<Float>(0, 1, 0))
            let orbitalTransform = nodeMatrix * tiltMatrix

            for (index, mesh) in channel.meshes.enumerated() {
                let angle = rotation + Float(index) * (2 * .pi / Float(channel.meshes.count))
                let basePos = SIMD4<Float>(cos(angle), 0, sin(angle), 1)
                let transformedPos = orbitalTransform * basePos
                let x = transformedPos.x * sphereRadius
                let y = transformedPos.y * sphereRadius
                let z = transformedPos.z * sphereRadius

                let yaw = atan2(x, z) + .pi
                let horizontalDist = sqrt(x * x + z * z)
                let pitch = atan2(y, horizontalDist)
                let roll = channel.tilt * cos(angle - channel.ascendingNode)

                let scale: Float = 0.04
                let scaleMatrix = float4x4.scale(scale, scale, scale)
                let centerX = Float(mesh.bounds.midX)
                let centerY = Float(mesh.bounds.midY)
                let centeringMatrix = float4x4.translation(-centerX, -centerY, 0)

                let rotateY = float4x4.rotation(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
                let rotateX = float4x4.rotation(angle: -pitch, axis: SIMD3<Float>(1, 0, 0))
                let rotateZ = float4x4.rotation(angle: roll, axis: SIMD3<Float>(0, 0, 1))
                let translateMatrix = float4x4.translation(x, y, z)

                matrices.append(translateMatrix * rotateY * rotateX * rotateZ * scaleMatrix * centeringMatrix)
            }
        }
        return matrices
    }
}

private struct SpinningSphereContent: View {
    let scene: SlugScene

    public var body: some View {
        RenderView { _, size in
            let aspectRatio = size.height > 0 ? Float(size.width / size.height) : 1.0
            let vpMatrix = float4x4.perspectiveReverseZInfinite(fovY: .pi / 2, aspect: aspectRatio, near: 0.01)
            let frameConstants = SlugFrameConstants(viewProjectionMatrix: vpMatrix, viewportSize: size)
            try RenderPass(label: "Slug Spinning Sphere") {
                try SlugTextRenderPipeline(scene: scene, frameConstants: frameConstants)
            }
        }
    }
}
