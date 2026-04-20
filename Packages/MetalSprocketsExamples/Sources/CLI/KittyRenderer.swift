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

// Base64 lookup table (outside generic type)
private let _base64Table: [UInt8] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)

// MARK: - Kitty Terminal Graphics Renderer

/// Renders frames to terminal using Kitty's terminal graphics protocol.
/// Supports full 24-bit color via raw RGB/RGBA with base64 encoding.
/// Protocol docs: https://sw.kovidgoyal.net/kitty/graphics-protocol/
struct KittyRenderer<Demo: DemoRenderPass> {
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

    // Pre-allocated buffers
    var rgbBuffer: [UInt8]  // RGB pixel data (no alpha)
    var outputBuffer: [UInt8]  // Final output with escape sequences

    init(terminal: Terminal, demoType: Demo.Type) throws {
        self.device = _MTLCreateSystemDefaultDevice()
        self.terminal = terminal

        // Use actual terminal pixel dimensions
        self.imageWidth = terminal.pixelWidth
        self.imageHeight = terminal.pixelHeight

        // Pre-allocate pixel readback buffer (BGRA = 4 bytes per pixel)
        self.pixelBuffer = [UInt8](repeating: 0, count: imageWidth * imageHeight * 4)

        // Pre-allocate RGB buffer (3 bytes per pixel)
        self.rgbBuffer = [UInt8](repeating: 0, count: imageWidth * imageHeight * 3)

        // Estimate output size: base64 is ~4/3 of input, plus escape overhead
        let base64Size = (imageWidth * imageHeight * 3 * 4 + 2) / 3
        self.outputBuffer = [UInt8]()
        self.outputBuffer.reserveCapacity(base64Size + 1_024)

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
        colorTexture.label = "Kitty Color Texture"
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
        depthTexture.label = "Kitty Depth Texture"
        self.depthTexture = depthTexture

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

        // Convert BGRA to RGB
        let pixelCount = imageWidth * imageHeight
        for i in 0..<pixelCount {
            let srcOffset = i * 4
            let dstOffset = i * 3
            rgbBuffer[dstOffset] = pixelBuffer[srcOffset + 2]      // R (from BGRA position 2)
            rgbBuffer[dstOffset + 1] = pixelBuffer[srcOffset + 1]  // G (from BGRA position 1)
            rgbBuffer[dstOffset + 2] = pixelBuffer[srcOffset]      // B (from BGRA position 0)
        }

        encodeKittyGraphics()

        terminal.moveCursorHome()
        outputBuffer.withUnsafeBufferPointer { buffer in
            _ = fwrite(buffer.baseAddress, 1, buffer.count, stdout)
        }
        fflush(stdout)
    }

    // MARK: - Kitty Graphics Protocol Encoding

    private mutating func encodeKittyGraphics() {
        outputBuffer.removeAll(keepingCapacity: true)

        // Kitty graphics protocol uses APC (Application Program Command):
        // ESC _ G <control data> ; <payload> ESC \
        //
        // Control keys for transmission:
        // a=T  - action: transmit and display
        // f=24 - format: 24-bit RGB
        // s=<width> - source width in pixels
        // v=<height> - source height in pixels
        // m=1  - more data follows (for chunked transmission)
        // m=0  - final chunk
        // q=2  - quiet mode (suppress responses)
        //
        // For animation, we use direct placement without IDs

        let chunkSize = 4_096  // Base64 encoded chunk size (must be multiple of 4)
        let rawChunkSize = chunkSize * 3 / 4  // Raw bytes per chunk

        var offset = 0
        let totalBytes = rgbBuffer.count
        var isFirst = true

        while offset < totalBytes {
            let remaining = totalBytes - offset
            let bytesToEncode = min(rawChunkSize, remaining)
            let isLast = (offset + bytesToEncode >= totalBytes)

            // Start escape sequence: ESC _ G
            outputBuffer.append(0x1B)  // ESC
            outputBuffer.append(0x5F)  // _
            outputBuffer.append(0x47)  // G

            if isFirst {
                // First chunk includes image metadata
                // a=T,f=24,s=<width>,v=<height>,q=2,m=<0|1>
                outputBuffer.append(contentsOf: "a=T,f=24,q=2,s=\(imageWidth),v=\(imageHeight),m=\(isLast ? 0 : 1);".utf8)
                isFirst = false
            } else {
                // Continuation chunks just have m=<0|1>
                outputBuffer.append(contentsOf: "m=\(isLast ? 0 : 1);".utf8)
            }

            // Base64 encode this chunk directly to output
            rgbBuffer.withUnsafeBufferPointer { buffer in
                let slice = UnsafeBufferPointer(
                    // swiftlint:disable:next force_unwrapping
                    start: buffer.baseAddress! + offset,
                    count: bytesToEncode
                )
                base64Encode(slice, to: &outputBuffer)
            }

            // End escape sequence: ESC \
            outputBuffer.append(0x1B)  // ESC
            outputBuffer.append(0x5C)  // \

            offset += bytesToEncode
        }
    }

    // MARK: - Fast Base64 Encoding

    private func base64Encode(_ input: UnsafeBufferPointer<UInt8>, to output: inout [UInt8]) {
        let table = _base64Table
        var i = 0
        let count = input.count

        // Process 3 bytes at a time
        while i + 2 < count {
            let b0 = input[i]
            let b1 = input[i + 1]
            let b2 = input[i + 2]

            output.append(table[Int(b0 >> 2)])
            output.append(table[Int((b0 & 0x03) << 4 | (b1 >> 4))])
            output.append(table[Int((b1 & 0x0F) << 2 | (b2 >> 6))])
            output.append(table[Int(b2 & 0x3F)])

            i += 3
        }

        // Handle remaining bytes
        let remaining = count - i
        if remaining == 1 {
            let b0 = input[i]
            output.append(table[Int(b0 >> 2)])
            output.append(table[Int((b0 & 0x03) << 4)])
            output.append(0x3D)  // =
            output.append(0x3D)  // =
        } else if remaining == 2 {
            let b0 = input[i]
            let b1 = input[i + 1]
            output.append(table[Int(b0 >> 2)])
            output.append(table[Int((b0 & 0x03) << 4 | (b1 >> 4))])
            output.append(table[Int((b1 & 0x0F) << 2)])
            output.append(0x3D)  // =
        }
    }
}
