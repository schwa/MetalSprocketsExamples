import ArgumentParser
import CoreGraphics
import Darwin
import Foundation
import Metal
import MetalSprockets
import MetalSprocketsExamples
import MetalSprocketsExampleShaders
import MetalSprocketsSupport
import simd

enum CharacterRamp: String, CaseIterable, ExpressibleByArgument {
    case bourke      // Paul Bourke's full 70-char ramp
    case short       // Short & punchy (10 chars)
    case geometric   // Geometric/detailed
    case minimal     // Box-like minimal
    case binary      // Two-tone

    var characters: [UInt8] {
        switch self {
        case .bourke:
            return Array(" .:-=+*oahkbdpqwmZO0QLCJUYXzcvunxrjft/|()1{}[]?-_+~<>i!lI;:,\"^`'. ".utf8)
        case .short:
            return Array(" .:-=+*#%@".utf8)
        case .geometric:
            return Array(" .'`^\",:;Il!i~+_-?][}{1)(|/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$".utf8)
        case .minimal:
            return Array(" ._-~:;=!*#$@".utf8)
        case .binary:
            return Array(" 1".utf8)
        }
    }

    static var defaultValue: CharacterRamp { .short }
}

@main
struct CLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cli",
        abstract: "Render SDF demo to terminal using ASCII art"
    )

    @Option(name: .shortAndLong, help: "Character ramp to use: \(CharacterRamp.allCases.map(\.rawValue).joined(separator: ", "))")
    var ramp: CharacterRamp = .short

    @Option(name: .shortAndLong, help: "Target frames per second")
    var fps: Float = 30.0

    @Option(name: .shortAndLong, help: "Animation speed multiplier")
    var speed: Float = 2.0

    func run() throws {
        var winsize = winsize()
        let termWidth: Int
        let termHeight: Int
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &winsize) == 0, winsize.ws_col > 0, winsize.ws_row > 0 {
            termWidth = Int(winsize.ws_col)
            termHeight = Int(winsize.ws_row) - 1  // Leave room for status line
        } else {
            // Fallback for non-TTY (e.g., piped output)
            termWidth = 160
            termHeight = 48
        }
        let size = CGSize(width: termWidth, height: termHeight)

        let bytesPerCell = 20  // "\x1b[38;2;RRR;GGG;BBBmX"

        // Create the Metal device
        let device = _MTLCreateSystemDefaultDevice()

        // Create color texture
        let colorTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: termWidth, height: termHeight, mipmapped: false)
        colorTextureDescriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        guard let colorTexture = device.makeTexture(descriptor: colorTextureDescriptor) else {
            fatalError("Failed to create color texture")
        }
        colorTexture.label = "Color Texture"

        // Create depth texture
        let depthTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float,
            width: termWidth,
            height: termHeight,
            mipmapped: false
        )
        depthTextureDescriptor.usage = [.renderTarget, .shaderRead]
        guard let depthTexture = device.makeTexture(descriptor: depthTextureDescriptor) else {
            fatalError("Failed to create depth texture")
        }
        depthTexture.label = "Depth Texture"

        let bufferSize = termWidth * termHeight * bytesPerCell
        guard let ansiBuffer = device.makeBuffer(length: bufferSize, options: .storageModeShared) else {
            fatalError("Failed to create ANSI output buffer")
        }
        ansiBuffer.label = "ANSI Output Buffer"

        // Character ramp from command line option
        let shadeChars = ramp.characters
        let shadeCount = UInt32(shadeChars.count)
        guard let shadeCharsBuffer = device.makeBuffer(bytes: shadeChars, length: shadeChars.count, options: .storageModeShared) else {
            fatalError("Failed to create shade chars buffer")
        }
        shadeCharsBuffer.label = "Shade Chars Buffer"

        // Load the compute kernel
        let shaderLibrary = try ShaderLibrary(bundle: .metalSprocketsExampleShaders()).namespaced("TextToANSI")
        let computeKernel: ComputeKernel = try shaderLibrary.colorToANSI

        // Create the OffscreenRenderer with our textures
        let offscreenRenderer = try OffscreenRenderer(
            size: size,
            colorTexture: colorTexture,
            depthTexture: depthTexture
        )

        let cameraMatrix = simd_float4x4(translation: [0, 0, 3.5])

        // Hide cursor
        print("\u{001B}[?25l", terminator: "")

        var frame = 0
        while true {
            try autoreleasepool {
                let time = Float(frame) / fps * speed

                // Create the render + compute element for this frame
                let element = try Group {
                    // First: render the SDF scene
                    try RenderPass {
                        try SDFRenderPipeline(
                            time: time,
                            projectionMatrix: .identity,
                            cameraMatrix: cameraMatrix,
                            drawableSize: size,
                            showDepth: false
                        )
                    }

                    // Second: convert to ANSI using compute shader
                    try ComputePass {
                        try ComputePipeline(computeKernel: computeKernel) {
                            try ComputeDispatch(
                                threadsPerGrid: MTLSize(width: termWidth, height: termHeight, depth: 1),
                                threadsPerThreadgroup: MTLSize(width: 16, height: 16, depth: 1)
                            )
                            .parameter("inputTexture", texture: colorTexture)
                            .parameter("outputBuffer", buffer: ansiBuffer)
                            .parameter("shadeChars", buffer: shadeCharsBuffer)
                            .parameter("shadeCount", value: shadeCount)
                        }
                    }
                }

                // Render
                _ = try offscreenRenderer.render(element)

                // Move cursor to top-left
                print("\u{001B}[H", terminator: "")

                // Read buffer and print to terminal
                let bufferPointer = ansiBuffer.contents().bindMemory(to: CChar.self, capacity: bufferSize)

                for y in 0..<termHeight {
                    let rowStart = y * termWidth * bytesPerCell
                    let rowData = Data(bytes: bufferPointer + rowStart, count: termWidth * bytesPerCell)
                    if let rowString = String(data: rowData, encoding: .utf8) {
                        print(rowString, terminator: "")
                    }
                    print("\u{001B}[0m")  // Reset colors at end of line
                }

                // Shhhhh, just sleep.
                Thread.sleep(forTimeInterval: 1.0 / Double(fps))
                frame += 1
            }
        }
    }
}
