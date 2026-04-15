#if os(macOS)
import CoreText
import Metal
import MetalSprockets
import MetalSprocketsAddOns
import MetalSprocketsSupport
import MetalSprocketsUI
import MetalSupport
import simd
import SwiftUI

public struct SlugTerminalDemoView: View {
    @State private var scene: SlugScene?
    @State private var camera = SlugCamera()
    @State private var needsRebuild = false
    @State private var isRebuilding = false
    @State private var isRunning = false
    @State private var terminalBuffer = TerminalBuffer(maxRows: 50, maxColumns: 120)
    @State private var rebuildCount = 0
    @State private var terminalConfig: TerminalConfig?
    @State private var fontAtlasCache: FontAtlasCache?

    let command: String
    let arguments: [String]

    public init(command: String = "/bin/ls", arguments: [String] = ["-laR", "--color=always", NSHomeDirectory()]) {
        self.command = command
        self.arguments = arguments
    }

    public init() {
        self.init(command: "/bin/ls", arguments: ["-laR", "--color=always", NSHomeDirectory()])
    }

    public var body: some View {
        ZStack {
            if let scene {
                TerminalRenderView(scene: scene, camera: $camera)
                    .slugCameraDragGesture(camera: $camera)
            } else if isRunning {
                ProgressView("Running command...")
            } else {
                VStack(spacing: 16) {
                    Text("Terminal")
                        .font(.largeTitle)
                    Text("\(command) \(arguments.joined(separator: " "))")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Button("Run") { runCommand() }
                        .font(.title2)
                }
            }
        }
        .ignoresSafeArea()
        .metalClearColor(MTLClearColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0))
        .frameTimingOverlay()
        .onDisappear { scene = nil }
        .overlay {
            if scene != nil {
                ScrollWheelCaptureView { delta in camera.scroll(delta: delta) }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if scene != nil || isRunning {
                VStack(alignment: .trailing) {
                    Text("\(terminalBuffer.maxColumns)×\(terminalBuffer.maxRows)")
                    Text("\(terminalBuffer.totalLinesReceived) lines / \(rebuildCount) rebuilds")
                    Text(formattedBytes(terminalBuffer.totalBytesReceived))
                    if isRunning {
                        Text("running").foregroundStyle(.yellow)
                    }
                }
                .font(.caption.monospaced())
                .padding(4)
                .background(.black.opacity(0.7))
                .foregroundStyle(.green)
                .padding(8)
            }
        }
        .background {
            if needsRebuild {
                TimelineView(.periodic(from: .now, by: 1.0 / 120.0)) { timeline in
                    Color.clear
                        .onChange(of: timeline.date) {
                            if needsRebuild, !isRebuilding {
                                needsRebuild = false
                                rebuildSceneAsync()
                            }
                        }
                }
            }
        }
    }

    private func runCommand() {
        guard !isRunning
        else { return }
        isRunning = true

        Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: command)
            process.arguments = arguments
            var env = ProcessInfo.processInfo.environment
            env["CLICOLOR_FORCE"] = "1"
            env["TERM"] = "xterm-256color"
            process.environment = env

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            let handle = pipe.fileHandleForReading

            handle.readabilityHandler = { fileHandle in
                let data = fileHandle.availableData
                guard !data.isEmpty
                else { return }
                if let text = String(data: data, encoding: .utf8) {
                    Task { @MainActor in
                        terminalBuffer.append(text)
                        needsRebuild = true
                    }
                }
            }

            try? process.run()
            process.waitUntilExit()
            handle.readabilityHandler = nil
            let remaining = handle.readDataToEndOfFile()
            if let text = String(data: remaining, encoding: .utf8), !text.isEmpty {
                await MainActor.run {
                    terminalBuffer.append(text)
                    needsRebuild = true
                }
            }
            await MainActor.run { isRunning = false }
        }
    }

    private func formattedBytes(_ bytes: Int) -> String {
        if bytes < 1_024 {
            return "\(bytes) B"
        }
        if bytes < 1_024 * 1_024 {
            return "\((Double(bytes) / 1_024).formatted(.number.precision(.fractionLength(1)))) KB"
        }
        return "\((Double(bytes) / (1_024 * 1_024)).formatted(.number.precision(.fractionLength(1)))) MB"
    }

    private func getTerminalConfig() -> TerminalConfig {
        if let config = terminalConfig {
            return config
        }
        let device = _MTLCreateSystemDefaultDevice()
        let config = TerminalConfig(device: device, fontName: "Menlo", fontSize: 14)
        terminalConfig = config
        return config
    }

    private func rebuildSceneAsync() {
        let grid = terminalBuffer.visibleGrid()
        guard !grid.isEmpty
        else { return }
        let config = getTerminalConfig()
        let cachedAtlas = fontAtlasCache
        let columns = terminalBuffer.maxColumns
        let isFirstBuild = scene == nil
        let font = config.font
        let device = config.device
        let cellSize = config.cellSize
        isRebuilding = true

        Task {
            let builder: SlugTextMeshBuilder
            if let cachedAtlas {
                builder = SlugTextMeshBuilder(device: device, fontAtlasCache: cachedAtlas)
            } else {
                builder = SlugTextMeshBuilder(device: device)
                let asciiString = String((32...126).map { Character(UnicodeScalar($0)) })
                let nsAttr = NSAttributedString(string: asciiString, attributes: [.font: font])
                builder.prepopulateGlyphs(from: [nsAttr])
            }

            builder.buildMesh(characters: grid, font: font, cellSize: cellSize, columns: columns)
            let atlasCache = builder.sharedFontAtlasCache
            let scene = try? builder.finalize()

            await MainActor.run {
                if let scene {
                    let mesh = scene.meshes[0]
                    scene.modelMatrices[0] = float4x4.translation(-Float(mesh.bounds.midX), -Float(mesh.bounds.midY), 0)
                    self.scene = scene
                    rebuildCount += 1
                    if isFirstBuild {
                        camera.frameBounds(size: mesh.bounds.size, aspectRatio: 1.0)
                    }
                }
                fontAtlasCache = atlasCache
                isRebuilding = false
            }
        }
    }
}

private struct TerminalConfig: @unchecked Sendable {
    let device: MTLDevice
    let font: CTFont
    let cellSize: CGSize

    init(device: MTLDevice, fontName: String, fontSize: CGFloat) {
        self.device = device
        self.font = CTFontCreateWithName(fontName as CFString, fontSize, nil)
        var spaceGlyph = CGGlyph(0)
        var space: UniChar = 0x20
        CTFontGetGlyphsForCharacters(font, &space, &spaceGlyph, 1)
        var advance = CGSize.zero
        CTFontGetAdvancesForGlyphs(font, .horizontal, &spaceGlyph, &advance, 1)
        let cellHeight = CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font)
        self.cellSize = CGSize(width: advance.width, height: cellHeight)
    }
}

private struct TerminalBuffer {
    let maxRows: Int
    let maxColumns: Int
    private(set) var totalLinesReceived: Int = 0
    private(set) var totalBytesReceived: Int = 0

    private var lines: [[ColoredCharacter]] = [[]]
    private var currentColor = SIMD4<Float>(1, 1, 1, 1)
    private var bold = false
    private var escapeBuffer: String = ""
    private var inEscape = false
    private var expectingBracket = false

    init(maxRows: Int, maxColumns: Int) {
        self.maxRows = maxRows
        self.maxColumns = maxColumns
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    mutating func append(_ text: String) {
        totalBytesReceived += text.utf8.count
        for scalar in text.unicodeScalars {
            if inEscape {
                if expectingBracket {
                    expectingBracket = false
                    if scalar == "[" { escapeBuffer.append(Character(scalar)) }
                    else { inEscape = false }
                } else {
                    escapeBuffer.append(Character(scalar))
                    if scalar.value >= 0x40, scalar.value <= 0x7E {
                        processEscape(escapeBuffer)
                        escapeBuffer = ""
                        inEscape = false
                    }
                }
            } else if scalar == "\u{1B}" {
                inEscape = true; expectingBracket = true; escapeBuffer = ""
            } else if scalar == "\n" {
                newLine()
            } else if scalar == "\r" {
                if !lines.isEmpty { lines[lines.count - 1].removeAll() }
            } else if scalar == "\t" {
                let col = lines.last?.count ?? 0
                let tabStop = ((col / 8) + 1) * 8
                let spaces = min(tabStop, maxColumns) - col
                for _ in 0..<spaces { appendChar(ColoredCharacter(" ", color: currentColor)) }
            } else {
                appendChar(ColoredCharacter(Character(scalar), color: currentColor))
            }
        }
    }

    private mutating func appendChar(_ cc: ColoredCharacter) {
        guard (lines.last?.count ?? 0) < maxColumns
        else { return }
        lines[lines.count - 1].append(cc)
    }

    private mutating func newLine() {
        totalLinesReceived += 1
        lines.append([])
        if lines.count > maxRows {
            lines.removeFirst(lines.count - maxRows)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private mutating func processEscape(_ seq: String) {
        guard seq.first == "["
        else { return }
        let body = seq.dropFirst()
        guard let finalChar = body.last, finalChar == "m"
        else { return }
        let paramString = String(body.dropLast())
        let params = paramString.isEmpty ? [0] : paramString.split(separator: ";").compactMap { Int($0) }

        var i = 0
        while i < params.count {
            let code = params[i]
            switch code {
            case 0: currentColor = SIMD4(1, 1, 1, 1); bold = false
            case 1: bold = true
            case 22: bold = false
            case 30...37: currentColor = bold ? ANSIColors.bright[code - 30] : ANSIColors.standard[code - 30]
            case 38:
                if i + 1 < params.count, params[i + 1] == 5, i + 2 < params.count {
                    currentColor = ANSIColors.color256(params[i + 2]); i += 2
                } else if i + 1 < params.count, params[i + 1] == 2, i + 4 < params.count {
                    currentColor = SIMD4(Float(params[i + 2]) / 255.0, Float(params[i + 3]) / 255.0, Float(params[i + 4]) / 255.0, 1.0); i += 4
                }
            case 39: currentColor = SIMD4(1, 1, 1, 1)
            case 90...97: currentColor = ANSIColors.bright[code - 90]
            default: break
            }
            i += 1
        }
    }

    func visibleGrid() -> [ColoredCharacter] {
        var grid: [ColoredCharacter] = []
        grid.reserveCapacity(maxRows * maxColumns)
        let space = ColoredCharacter(" ")
        for line in lines {
            let count = min(line.count, maxColumns)
            grid.append(contentsOf: line.prefix(count))
            for _ in count..<maxColumns { grid.append(space) }
        }
        return grid
    }
}

private enum ANSIColors {
    static let standard: [SIMD4<Float>] = [
        SIMD4(0.0, 0.0, 0.0, 1.0), SIMD4(0.8, 0.0, 0.0, 1.0), SIMD4(0.0, 0.8, 0.0, 1.0), SIMD4(0.8, 0.8, 0.0, 1.0),
        SIMD4(0.0, 0.0, 0.8, 1.0), SIMD4(0.8, 0.0, 0.8, 1.0), SIMD4(0.0, 0.8, 0.8, 1.0), SIMD4(0.75, 0.75, 0.75, 1.0)
    ]
    static let bright: [SIMD4<Float>] = [
        SIMD4(0.5, 0.5, 0.5, 1.0), SIMD4(1.0, 0.0, 0.0, 1.0), SIMD4(0.0, 1.0, 0.0, 1.0), SIMD4(1.0, 1.0, 0.0, 1.0),
        SIMD4(0.0, 0.0, 1.0, 1.0), SIMD4(1.0, 0.0, 1.0, 1.0), SIMD4(0.0, 1.0, 1.0, 1.0), SIMD4(1.0, 1.0, 1.0, 1.0)
    ]
    static func color256(_ index: Int) -> SIMD4<Float> {
        if index < 8 {
            return standard[index]
        }
        if index < 16 {
            return bright[index - 8]
        }
        if index < 232 {
            let i = index - 16
            return SIMD4(Float((i / 36) % 6) / 5.0, Float((i / 6) % 6) / 5.0, Float(i % 6) / 5.0, 1.0)
        }
        let gray = Float(index - 232) / 23.0
        return SIMD4(gray, gray, gray, 1.0)
    }
}

private struct TerminalRenderView: View {
    let scene: SlugScene
    @Binding var camera: SlugCamera

    var body: some View {
        RenderView { _, size in
            let aspectRatio = size.height > 0 ? Float(size.width / size.height) : 1.0
            let vpMatrix = camera.projectionMatrix(aspectRatio: aspectRatio) * camera.viewMatrix()
            let frameConstants = SlugFrameConstants(viewProjectionMatrix: vpMatrix, viewportSize: size)
            try RenderPass(label: "Slug Terminal") {
                try SlugTextRenderPipeline(scene: scene, frameConstants: frameConstants)
            }
        }
    }
}
#endif
