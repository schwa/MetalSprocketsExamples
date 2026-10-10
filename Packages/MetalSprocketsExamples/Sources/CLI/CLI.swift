import ArgumentParser
import Foundation
import ImageIO
import UniformTypeIdentifiers
import MetalSprocketsExamples
import MetalSprocketsUI
import simd

extension CharacterRamp: ExpressibleByArgument {
}

enum RenderMode: String, CaseIterable, ExpressibleByArgument {
    case ansi   // ANSI true-color ASCII art
    case sixel  // Sixel graphics (requires compatible terminal)
    case iterm  // iTerm2 inline images (requires iTerm2)
    case kitty  // Kitty graphics protocol (requires Kitty terminal)
}

@main
struct CLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cli",
        abstract: "Render MetalSprockets demos from the command line",
        subcommands: [TerminalCommand.self, MeadowCommand.self],
        defaultSubcommand: TerminalCommand.self
    )
}

struct MeadowCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "meadow",
        abstract: "Ray trace the Meadow demo to a PNG"
    )

    @Option(name: .shortAndLong, help: "Output PNG path")
    var output: String = "meadow.png"

    @Option(help: "Image width")
    var width: Int = 1_280

    @Option(help: "Image height")
    var height: Int = 720

    @Option(name: .shortAndLong, help: "Accumulated samples per pixel")
    var samples: Int = 64

    @Option(help: "Sun elevation in radians")
    var sunElevation: Float?

    @Option(help: "Cloud coverage, 0-1")
    var clouds: Float?

    @MainActor
    func run() async throws {
        var settings = MeadowSettings()
        if let sunElevation { settings.sunElevation = sunElevation }
        if let clouds { settings.cloudCoverage = clouds }
        let start = CFAbsoluteTimeGetCurrent()
        let (image, triangleCount) = try await MeadowOffscreen.render(width: width, height: height, samples: samples, settings: settings)
        let url = URL(fileURLWithPath: output)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw ValidationError("Cannot write \(output)")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ValidationError("Cannot write \(output)")
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        print("Wrote \(url.path) (\(width)×\(height), \(samples) samples, \(triangleCount.formatted()) triangles, \(String(format: "%.1f", elapsed)) s)")
    }
}

struct TerminalCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "terminal",
        abstract: "Render demo to terminal using ASCII art or Sixel graphics",
        subcommands: [FLIPCommand.self]
    )

    static var availableDemos: String {
        // Avoid keypath syntax on existential types to work around Swift compiler crash
        allDemoRenderPasses.map { $0.name }.joined(separator: ", ") // swiftlint:disable:this prefer_key_path
    }

    static var defaultDemo: String {
        // swiftlint:disable:next force_unwrapping
        allDemoRenderPasses.first!.name
    }

    @Option(name: .shortAndLong, help: "Demo to run (available: \(Self.availableDemos))")
    var demo: String?

    @Option(name: .shortAndLong, help: "Render mode: \(RenderMode.allCases.map(\.rawValue).joined(separator: ", "))")
    var mode: RenderMode = .ansi

    @Option(name: .shortAndLong, help: "Character ramp (ANSI mode): \(CharacterRamp.allCases.map(\.rawValue).joined(separator: ", "))")
    var ramp: CharacterRamp = .short

    @Option(name: .shortAndLong, help: "Color levels per channel for Sixel (2-6, 6³=216 max due to Sixel 256 color limit)")
    var colors: Int = 6

    @Option(name: .shortAndLong, help: "Target frames per second")
    var fps: Float = 30.0

    @Option(name: .shortAndLong, help: "Animation speed multiplier")
    var speed: Float = 2.0

    func run() throws {
        let demoName = demo ?? Self.defaultDemo
        let terminal = Terminal.current()

        // Match demo by name and run with concrete type
        for demoType in allDemoRenderPasses where demoType.name == demoName {
            switch mode {
            case .ansi:
                try runANSIRenderLoop(demoType, terminal: terminal)
            case .sixel:
                try runSixelRenderLoop(demoType, terminal: terminal)
            case .iterm:
                try runITermRenderLoop(demoType, terminal: terminal)
            case .kitty:
                try runKittyRenderLoop(demoType, terminal: terminal)
            }
            return
        }

        throw ValidationError("Unknown demo '\(demoName)'. Available: \(Self.availableDemos)")
    }

    private func runANSIRenderLoop<Demo: DemoRenderPass>(_ demoType: Demo.Type, terminal: Terminal) throws {
        let renderer = try ANSIRenderer(terminal: terminal, ramp: ramp, demoType: demoType)
        let cameraMatrix = simd_float4x4(translation: [0, 0, 3.5])

        terminal.hideCursor()
        defer {
            terminal.showCursor()
            terminal.resetColors()
        }

        var frame: UInt32 = 0
        var lastTime = CFAbsoluteTimeGetCurrent()
        while true {
            try autoreleasepool {
                let currentTime = CFAbsoluteTimeGetCurrent()
                let deltaTime = Float(currentTime - lastTime)
                lastTime = currentTime

                let frameUniforms = MetalSprocketsUI.FrameUniforms(
                    index: frame,
                    time: Float(frame) / fps * speed,
                    deltaTime: deltaTime,
                    viewportSize: SIMD2<UInt32>(UInt32(terminal.width), UInt32(terminal.height))
                )

                try renderer.render(frameUniforms: frameUniforms, cameraMatrix: cameraMatrix)
                renderer.printFrame()

                Thread.sleep(forTimeInterval: 1.0 / Double(fps))
                frame += 1
            }
        }
    }

    private func runSixelRenderLoop<Demo: DemoRenderPass>(_ demoType: Demo.Type, terminal: Terminal) throws {
        let colorLevels = max(2, min(6, colors))
        var renderer = try SixelRenderer(terminal: terminal, colorLevels: colorLevels, demoType: demoType)
        let cameraMatrix = simd_float4x4(translation: [0, 0, 3.5])

        terminal.hideCursor()
        defer {
            terminal.showCursor()
            terminal.resetColors()
            // Clear sixel graphics
            print("\u{1B}[2J", terminator: "")
        }

        var frame: UInt32 = 0
        var lastTime = CFAbsoluteTimeGetCurrent()
        while true {
            try autoreleasepool {
                let currentTime = CFAbsoluteTimeGetCurrent()
                let deltaTime = Float(currentTime - lastTime)
                lastTime = currentTime

                let frameUniforms = MetalSprocketsUI.FrameUniforms(
                    index: frame,
                    time: Float(frame) / fps * speed,
                    deltaTime: deltaTime,
                    viewportSize: SIMD2<UInt32>(UInt32(renderer.imageWidth), UInt32(renderer.imageHeight))
                )

                try renderer.render(frameUniforms: frameUniforms, cameraMatrix: cameraMatrix)
                renderer.printFrame()

                Thread.sleep(forTimeInterval: 1.0 / Double(fps))
                frame += 1
            }
        }
    }

    private func runITermRenderLoop<Demo: DemoRenderPass>(_ demoType: Demo.Type, terminal: Terminal) throws {
        var renderer = try ITermRenderer(terminal: terminal, demoType: demoType)
        let cameraMatrix = simd_float4x4(translation: [0, 0, 3.5])

        terminal.hideCursor()
        defer {
            terminal.showCursor()
            terminal.resetColors()
            // Clear screen
            print("\u{1B}[2J", terminator: "")
        }

        var frame: UInt32 = 0
        var lastTime = CFAbsoluteTimeGetCurrent()
        while true {
            try autoreleasepool {
                let currentTime = CFAbsoluteTimeGetCurrent()
                let deltaTime = Float(currentTime - lastTime)
                lastTime = currentTime

                let frameUniforms = MetalSprocketsUI.FrameUniforms(
                    index: frame,
                    time: Float(frame) / fps * speed,
                    deltaTime: deltaTime,
                    viewportSize: SIMD2<UInt32>(UInt32(renderer.imageWidth), UInt32(renderer.imageHeight))
                )

                try renderer.render(frameUniforms: frameUniforms, cameraMatrix: cameraMatrix)
                renderer.printFrame()

                Thread.sleep(forTimeInterval: 1.0 / Double(fps))
                frame += 1
            }
        }
    }

    private func runKittyRenderLoop<Demo: DemoRenderPass>(_ demoType: Demo.Type, terminal: Terminal) throws {
        var renderer = try KittyRenderer(terminal: terminal, demoType: demoType)
        let cameraMatrix = simd_float4x4(translation: [0, 0, 3.5])

        terminal.hideCursor()
        defer {
            terminal.showCursor()
            terminal.resetColors()
            // Clear screen and any kitty graphics
            print("\u{1B}[2J", terminator: "")
            // Delete all kitty graphics: ESC _ G a=d ; ESC \
            print("\u{1B}_Ga=d;\u{1B}\\", terminator: "")
        }

        var frame: UInt32 = 0
        var lastTime = CFAbsoluteTimeGetCurrent()
        while true {
            try autoreleasepool {
                let currentTime = CFAbsoluteTimeGetCurrent()
                let deltaTime = Float(currentTime - lastTime)
                lastTime = currentTime

                let frameUniforms = MetalSprocketsUI.FrameUniforms(
                    index: frame,
                    time: Float(frame) / fps * speed,
                    deltaTime: deltaTime,
                    viewportSize: SIMD2<UInt32>(UInt32(renderer.imageWidth), UInt32(renderer.imageHeight))
                )

                try renderer.render(frameUniforms: frameUniforms, cameraMatrix: cameraMatrix)
                renderer.printFrame()

                Thread.sleep(forTimeInterval: 1.0 / Double(fps))
                frame += 1
            }
        }
    }
}
