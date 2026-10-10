import ArgumentParser
import CoreGraphics
import Foundation
import ImageIO
import Metal
import MetalSprockets
import MetalSprocketsExamples
import UniformTypeIdentifiers

extension FLIPScene: ExpressibleByArgument {
    public init?(argument: String) {
        switch argument {
        case "dam-break":
            self = .damBreak
        case "falling-drop":
            self = .fallingDrop
        case "opposing-blocks":
            self = .opposingBlocks
        default:
            return nil
        }
    }

    public static var allValueStrings: [String] {
        ["dam-break", "falling-drop", "opposing-blocks"]
    }
}

struct FLIPCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "flip",
        abstract: "Run the PIC/FLIP fluid headlessly and write PNG frames"
    )

    @Option(help: "Initial scene: \(FLIPScene.allValueStrings.joined(separator: ", "))")
    var scene: FLIPScene = .damBreak

    @Option(help: "MAC grid cells per side (8-64)")
    var resolution: Int = 24

    @Option(help: "Solver steps to simulate")
    var steps: Int = 240

    @Option(help: "Write a frame every N steps. 0 writes only the final frame.")
    var every: Int = 0

    @Option(help: "Pressure sweeps per step")
    var pressureIterations: Int = 40

    @Flag(help: "Render velocity-colored particles instead of the surface")
    var particles = false

    @Option(help: "Image width in pixels")
    var width: Int = 960

    @Option(help: "Image height in pixels")
    var height: Int = 640

    @Option(help: "Output PNG path, or a directory when --every is set")
    var output: String = "/tmp/metalflip"

    func run() throws {
        let renderer = try OffscreenRenderer(size: CGSize(width: width, height: height))
        let simulation = try FLIPSimulation(device: renderer.device, resolution: resolution)
        var settings = FLIPSettings()
        settings.pressureIterations = pressureIterations

        let outputURL = URL(fileURLWithPath: output)
        if every > 0 {
            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        }

        let start = CFAbsoluteTimeGetCurrent()
        _ = try renderer.render(FLIPCompute(simulation: simulation, reset: scene, steps: 0, reconstructsSurface: false))
        report(step: 0, simulation: simulation, gpuTime: nil)

        let batch = every > 0 ? every : steps
        var step = 0
        var frame = 0
        while step < steps {
            let count = min(batch, steps - step)
            let isFrame = every > 0 || step + count == steps
            let viewportSize = SIMD2<Float>(Float(width), Float(height))
            let content = try Group {
                FLIPCompute(simulation: simulation, steps: count, settings: settings, reconstructsSurface: isFrame && !particles)
                if isFrame {
                    FLIPRender(simulation: simulation, showsParticles: particles, viewportSize: viewportSize)
                }
            }
            let rendering = try renderer.render(content)
            step += count
            report(step: step, simulation: simulation, gpuTime: rendering.gpuTime)
            if isFrame {
                let url = every > 0 ? outputURL.appendingPathComponent("frame-\(frame.formatted(.number.grouping(.never).precision(.integerLength(4)))).png") : outputURL.appendingPathExtension("png")
                try writePNG(rendering.cgImage, to: url)
                print("  wrote \(url.path)")
                frame += 1
            }
        }
        print("Done in \(fixed(CFAbsoluteTimeGetCurrent() - start, 2)) s")
    }

    private func fixed(_ value: some BinaryFloatingPoint, _ digits: Int) -> String {
        Double(value).formatted(.number.grouping(.never).precision(.fractionLength(digits)))
    }

    private func report(step: Int, simulation: FLIPSimulation, gpuTime: TimeInterval?) {
        let statistics = simulation.statistics
        var line = "step \(step)  t=\(fixed(statistics.simulatedTime, 3)) s  dt=\(fixed(statistics.timeStep * 1_000, 2)) ms  particles=\(statistics.particleCount)  max speed=\(fixed(statistics.maximumSpeed, 2)) m/s"
        if let gpuTime {
            line += "  gpu=\(fixed(gpuTime * 1_000, 1)) ms"
        }
        print(line)
    }

    private func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw ValidationError("Cannot create \(url.path)")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ValidationError("Cannot write \(url.path)")
        }
    }
}
