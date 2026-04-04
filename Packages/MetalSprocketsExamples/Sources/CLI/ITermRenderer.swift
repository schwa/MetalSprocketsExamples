import CoreGraphics
import Darwin
import Foundation
import ImageIO
import Metal
import MetalSprockets
import MetalSprocketsExamples
import MetalSprocketsExampleShaders
import MetalSprocketsSupport
import MetalSprocketsUI
import simd
import UniformTypeIdentifiers

// MARK: - iTerm2 Inline Image Renderer

/// Renders frames to terminal using iTerm2's inline image protocol.
/// Supports full 24-bit color via PNG encoding.
struct ITermRenderer<Demo: DemoRenderPass> {
    let device: MTLDevice
    let terminal: Terminal

    // Textures
    let colorTexture: MTLTexture
    let depthTexture: MTLTexture

    let offscreenRenderer: OffscreenRenderer

    // Pixel readback buffer (reused across frames)
    var pixelBuffer: [UInt8]

    // Image dimensions
    let imageWidth: Int
    let imageHeight: Int

    init(terminal: Terminal, demoType: Demo.Type) throws {
        self.device = _MTLCreateSystemDefaultDevice()
        self.terminal = terminal

        // Use actual terminal pixel dimensions
        self.imageWidth = terminal.pixelWidth
        self.imageHeight = terminal.pixelHeight

        // Color texture
        let colorDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: imageWidth,
            height: imageHeight,
            mipmapped: false
        )
        colorDesc.usage = [.renderTarget, .shaderRead, .shaderWrite]
        guard let colorTexture = device.makeTexture(descriptor: colorDesc) else {
            fatalError("Failed to create color texture")
        }
        colorTexture.label = "iTerm Color Texture"
        self.colorTexture = colorTexture

        // Depth texture
        let depthDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float,
            width: imageWidth,
            height: imageHeight,
            mipmapped: false
        )
        depthDesc.usage = [.renderTarget, .shaderRead]
        guard let depthTexture = device.makeTexture(descriptor: depthDesc) else {
            fatalError("Failed to create depth texture")
        }
        depthTexture.label = "iTerm Depth Texture"
        self.depthTexture = depthTexture

        // Pre-allocate pixel readback buffer
        self.pixelBuffer = [UInt8](repeating: 0, count: imageWidth * imageHeight * 4)

        // Offscreen renderer
        self.offscreenRenderer = try OffscreenRenderer(
            size: CGSize(width: imageWidth, height: imageHeight),
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

        _ = try offscreenRenderer.render(demoPass)
    }

    mutating func printFrame() {
        // Read pixels directly from texture
        colorTexture.getBytes(
            &pixelBuffer,
            bytesPerRow: imageWidth * 4,
            from: MTLRegion(
                origin: MTLOrigin(x: 0, y: 0, z: 0),
                size: MTLSize(width: imageWidth, height: imageHeight, depth: 1)
            ),
            mipmapLevel: 0
        )

        // Encode as PNG
        guard let pngData = pixelBuffer.withUnsafeBufferPointer({ buffer in
            // swiftlint:disable:next force_unwrapping
            encodePNG(pixels: buffer.baseAddress!, width: imageWidth, height: imageHeight)
        }) else {
            return
        }

        // Base64 encode
        let base64 = pngData.base64EncodedString()

        // iTerm2 inline image protocol:
        // ESC ] 1337 ; File = [arguments] : base64data BEL
        // Arguments: name=<base64>, size=<bytes>, width=<cols/px>, height=<rows/px>, inline=1
        terminal.moveCursorHome()
        print("\u{1B}]1337;File=inline=1;width=\(terminal.width);height=\(terminal.height):\(base64)\u{07}", terminator: "")
        fflush(stdout)
    }

    // MARK: - PNG Encoding

    private func encodePNG(pixels: UnsafePointer<UInt8>, width: Int, height: Int) -> Data? {
        // Create a CGImage from the pixel data
        let bitsPerComponent = 8
        let bytesPerRow = width * 4

        // BGRA -> need to specify the right byte order
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB), let context = CGContext( data: UnsafeMutableRawPointer(mutating: pixels), width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue), let cgImage = context.makeImage() else {
            return nil
        }

        // Encode to PNG using ImageIO
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }

        // Use faster compression for animation
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.8
        ]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return data as Data
    }
}
