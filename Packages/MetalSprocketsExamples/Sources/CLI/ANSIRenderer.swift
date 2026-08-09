import CoreGraphics
import Darwin
import Foundation
import Metal
import MetalSprockets
import MetalSprocketsExamples
import MetalSprocketsExampleShaders
import MetalSprocketsSupport
import MetalSprocketsUI
import MetalSupport
import simd

// MARK: - Character Ramps

enum CharacterRamp: String, CaseIterable {
    case bourke      // Paul Bourke's full 70-char ramp
    case short       // Short & punchy (10 chars)
    case geometric   // Geometric/detailed
    case minimal     // Box-like minimal

    var characters: [UInt8] {
        switch self {
        case .bourke:
            Array(" .:-=+*oahkbdpqwmZO0QLCJUYXzcvunxrjft/|()1{}[]?-_+~<>i!lI;:,\"^`'. ".utf8)
        case .short:
            Array(" .:-=+*#%@".utf8)
        case .geometric:
            Array(" .'`^\",:;Il!i~+_-?][}{1)(|/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$".utf8)
        case .minimal:
            Array(" ._-~:;=!*#$@".utf8)
        }
    }
}

// MARK: - Terminal

struct Terminal {
    /// Width in character cells
    let width: Int
    /// Height in character cells
    let height: Int
    /// Width in pixels (if available)
    let pixelWidth: Int
    /// Height in pixels (if available)
    let pixelHeight: Int

    var size: CGSize {
        CGSize(width: width, height: height)
    }

    var pixelSize: CGSize {
        CGSize(width: pixelWidth, height: pixelHeight)
    }

    static func current() -> Self {
        var ws = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0, ws.ws_col > 0, ws.ws_row > 0 {
            let cols = Int(ws.ws_col)
            let rows = Int(ws.ws_row) - 1  // Leave room for status

            // ws_xpixel and ws_ypixel may be 0 if terminal doesn't report them
            var pxWidth = Int(ws.ws_xpixel)
            var pxHeight = Int(ws.ws_ypixel)

            // Estimate if not reported (assume ~8x16 cell size)
            if pxWidth == 0 {
                pxWidth = cols * 8
            }
            if pxHeight == 0 {
                pxHeight = rows * 16
            }

            return Self(width: cols, height: rows, pixelWidth: pxWidth, pixelHeight: pxHeight)
        }
        // Fallback for non-TTY
        return Self(width: 160, height: 48, pixelWidth: 1_280, pixelHeight: 768)
    }

    func hideCursor() {
        print("\u{001B}[?25l", terminator: "")
    }

    func showCursor() {
        print("\u{001B}[?25h", terminator: "")
    }

    func moveCursorHome() {
        print("\u{001B}[H", terminator: "")
    }

    func resetColors() {
        print("\u{001B}[0m", terminator: "")
    }
}

// MARK: - Renderer

struct ANSIRenderer<Demo: DemoRenderPass> {
    let device: MTLDevice
    let terminal: Terminal
    let colorTexture: MTLTexture
    let depthTexture: MTLTexture
    let ansiBuffer: MTLBuffer
    let shadeCharsBuffer: MTLBuffer
    let shadeCount: UInt32
    let computeKernel: ComputeKernel
    let offscreenRenderer: OffscreenRenderer

    static var bytesPerCell: Int { 20 }  // "\x1b[38;2;RRR;GGG;BBBmX"

    init(terminal: Terminal, ramp: CharacterRamp, demoType: Demo.Type) throws {
        self.device = _MTLCreateSystemDefaultDevice()
        self.terminal = terminal

        // Color texture
        let colorDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm_srgb,
            width: terminal.width,
            height: terminal.height,
            mipmapped: false
        )
        colorDesc.usage = [.renderTarget, .shaderRead, .shaderWrite]
        guard let colorTexture = device.makeTexture(descriptor: colorDesc) else {
            fatalError("Failed to create color texture")
        }
        colorTexture.label = "Color Texture"
        self.colorTexture = colorTexture

        // Depth texture
        let depthDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float,
            width: terminal.width,
            height: terminal.height,
            mipmapped: false
        )
        depthDesc.usage = [.renderTarget, .shaderRead]
        guard let depthTexture = device.makeTexture(descriptor: depthDesc) else {
            fatalError("Failed to create depth texture")
        }
        depthTexture.label = "Depth Texture"
        self.depthTexture = depthTexture

        // ANSI output buffer
        let bufferSize = terminal.width * terminal.height * Self.bytesPerCell
        guard let ansiBuffer = device.makeBuffer(length: bufferSize, options: .storageModeShared) else {
            fatalError("Failed to create ANSI output buffer")
        }
        ansiBuffer.label = "ANSI Output Buffer"
        self.ansiBuffer = ansiBuffer

        // Character ramp buffer
        let shadeChars = ramp.characters
        self.shadeCount = UInt32(shadeChars.count)
        guard let shadeCharsBuffer = device.makeBuffer(bytes: shadeChars, length: shadeChars.count, options: .storageModeShared) else {
            fatalError("Failed to create shade chars buffer")
        }
        shadeCharsBuffer.label = "Shade Chars Buffer"
        self.shadeCharsBuffer = shadeCharsBuffer

        // Compute kernel
        let shaderLibrary = try ShaderLibrary(bundle: .metalSprocketsExampleShaders()).namespaced("TextToANSI")
        self.computeKernel = try shaderLibrary.colorToANSI

        // Offscreen renderer
        self.offscreenRenderer = try OffscreenRenderer(
            size: terminal.size,
            colorTexture: colorTexture,
            depthTexture: depthTexture
        )
    }

    func render(frameUniforms: MetalSprocketsUI.FrameUniforms, cameraMatrix: simd_float4x4) throws {
        let demoPass = try Demo(
            frameUniforms: frameUniforms,
            projectionMatrix: .identity,
            cameraMatrix: cameraMatrix
        )

        let element = try Group {
            demoPass

            try ComputePass {
                try ComputePipeline(computeKernel: computeKernel) {
                    try ComputeDispatch(threadsPerGrid: MTLSize(width: terminal.width, height: terminal.height, depth: 1))
                    .parameter("inputTexture", texture: colorTexture)
                    .parameter("outputBuffer", buffer: ansiBuffer)
                    .parameter("shadeChars", buffer: shadeCharsBuffer)
                    .parameter("shadeCount", value: shadeCount)
                }
            }
        }

        _ = try offscreenRenderer.render(element)
    }

    func printFrame() {
        let bufferSize = terminal.width * terminal.height * Self.bytesPerCell
        let bufferPointer = ansiBuffer.contents().bindMemory(to: CChar.self, capacity: bufferSize)

        terminal.moveCursorHome()

        for y in 0..<terminal.height {
            let rowStart = y * terminal.width * Self.bytesPerCell
            let rowData = Data(bytes: bufferPointer + rowStart, count: terminal.width * Self.bytesPerCell)
            if let rowString = String(data: rowData, encoding: .utf8) {
                print(rowString, terminator: "")
            }
            terminal.resetColors()
            print()
        }
    }
}
