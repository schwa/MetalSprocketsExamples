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

// MARK: - Sixel Renderer

/// Renders frames to terminal using Sixel graphics protocol (CPU-based encoding).
/// Sixel encodes 6 vertical pixels per character, with palette-based colors and RLE compression.
struct SixelRenderer<Demo: DemoRenderPass> {
    let device: MTLDevice
    let terminal: Terminal
    let colorLevels: Int  // 6 = 216 colors (web-safe)

    // Textures
    let colorTexture: MTLTexture
    let depthTexture: MTLTexture

    let offscreenRenderer: OffscreenRenderer

    // Pixel readback buffer (reused across frames)
    var pixelBuffer: [UInt8]

    // Image dimensions
    let imageWidth: Int
    let imageHeight: Int

    // Pre-computed lookup tables
    let quantizeLUT: [UInt8]  // 256 entries per channel -> quantized value
    let paletteHeader: [UInt8]  // Pre-built palette definition

    // Pre-allocated encoding buffers
    let maxColors: Int
    var colorBandData: [[UInt8]]  // [colorIndex][x] = sixel char
    var colorBandUsed: [Bool]     // Which colors are used in current band
    var outputBuffer: [UInt8]     // Final output buffer

    init(terminal: Terminal, colorLevels: Int = 6, demoType: Demo.Type) throws {
        self.device = _MTLCreateSystemDefaultDevice()
        self.terminal = terminal
        self.colorLevels = colorLevels
        self.maxColors = colorLevels * colorLevels * colorLevels

        // Sixel is pixel-based, use actual terminal pixel dimensions
        self.imageWidth = terminal.pixelWidth
        self.imageHeight = terminal.pixelHeight

        // Build quantization LUT - maps 0-255 to 0-(colorLevels-1)
        var lut = [UInt8](repeating: 0, count: 256)
        for i in 0..<256 {
            lut[i] = UInt8(i * (colorLevels - 1) / 255)
        }
        self.quantizeLUT = lut

        // Pre-build palette header
        var header = [UInt8]()
        header.reserveCapacity(maxColors * 20)
        // DCS introducer
        header.append(contentsOf: [0x1B, 0x50, 0x71])  // ESC P q
        for i in 0..<maxColors {
            let r = i / (colorLevels * colorLevels)
            let g = (i / colorLevels) % colorLevels
            let b = i % colorLevels
            let r100 = r * 100 / (colorLevels - 1)
            let g100 = g * 100 / (colorLevels - 1)
            let b100 = b * 100 / (colorLevels - 1)
            // #<index>;2;<r>;<g>;<b>
            header.append(0x23)  // #
            header.append(contentsOf: Self.intToASCII(i))
            header.append(0x3B)  // ;
            header.append(0x32)  // 2
            header.append(0x3B)  // ;
            header.append(contentsOf: Self.intToASCII(r100))
            header.append(0x3B)  // ;
            header.append(contentsOf: Self.intToASCII(g100))
            header.append(0x3B)  // ;
            header.append(contentsOf: Self.intToASCII(b100))
        }
        self.paletteHeader = header

        // Pre-allocate band buffers
        self.colorBandData = [[UInt8]](repeating: [UInt8](repeating: 63, count: imageWidth), count: maxColors)
        self.colorBandUsed = [Bool](repeating: false, count: maxColors)

        // Estimate output size: header + (bands * colors * width * ~1.5 for RLE)
        let numBands = (imageHeight + 5) / 6
        let estimatedSize = header.count + numBands * maxColors * imageWidth * 2
        self.outputBuffer = [UInt8]()
        self.outputBuffer.reserveCapacity(estimatedSize)

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
        colorTexture.label = "Sixel Color Texture"
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
        depthTexture.label = "Sixel Depth Texture"
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

    // Convert int to ASCII digits
    private static func intToASCII(_ value: Int) -> [UInt8] {
        if value == 0 {
            return [0x30]
        }
        var digits = [UInt8]()
        var v = value
        while v > 0 {
            digits.append(UInt8(0x30 + v % 10))
            v /= 10
        }
        return digits.reversed()
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

        pixelBuffer.withUnsafeBufferPointer { pixels in
            // swiftlint:disable:next force_unwrapping
            encodeSixel(pixels: pixels.baseAddress!)
        }

        terminal.moveCursorHome()
        outputBuffer.withUnsafeBufferPointer { buffer in
            _ = fwrite(buffer.baseAddress, 1, buffer.count, stdout)
        }
        fflush(stdout)
    }

    // MARK: - Optimized Sixel Encoding

    private mutating func encodeSixel(pixels: UnsafePointer<UInt8>) {
        let width = imageWidth
        let height = imageHeight
        let colorLevels2 = colorLevels * colorLevels

        outputBuffer.removeAll(keepingCapacity: true)
        outputBuffer.append(contentsOf: paletteHeader)

        let numBands = (height + 5) / 6

        for band in 0..<numBands {
            let bandStartY = band * 6
            let rowsInBand = min(6, height - bandStartY)

            // Reset band state
            for i in 0..<maxColors {
                colorBandUsed[i] = false
            }

            // Process all pixels in this band
            for x in 0..<width {
                // Collect colors for this column's 6 pixels
                var columnBits = [UInt8](repeating: 0, count: maxColors)

                for row in 0..<rowsInBand {
                    let y = bandStartY + row
                    let pixelOffset = (y * width + x) * 4
                    let b = pixels[pixelOffset]
                    let g = pixels[pixelOffset + 1]
                    let r = pixels[pixelOffset + 2]

                    let rq = Int(quantizeLUT[Int(r)])
                    let gq = Int(quantizeLUT[Int(g)])
                    let bq = Int(quantizeLUT[Int(b)])
                    let colorIndex = rq * colorLevels2 + gq * colorLevels + bq

                    columnBits[colorIndex] |= UInt8(1 << row)
                }

                // Update band data for colors that have bits set
                for colorIndex in 0..<maxColors {
                    let bits = columnBits[colorIndex]
                    if bits != 0 {
                        if !colorBandUsed[colorIndex] {
                            // First use of this color in band - reset its row
                            for i in 0..<width {
                                colorBandData[colorIndex][i] = 63  // '?'
                            }
                            colorBandUsed[colorIndex] = true
                        }
                        colorBandData[colorIndex][x] = 63 + bits
                    }
                }
            }

            // Output band data for used colors
            var firstColor = true
            for colorIndex in 0..<maxColors {
                guard colorBandUsed[colorIndex] else { continue }

                // Carriage return between colors (not before first)
                if !firstColor {
                    outputBuffer.append(0x24)  // $
                }
                firstColor = false

                // Color selection: #<index>
                outputBuffer.append(0x23)  // #
                outputBuffer.append(contentsOf: Self.intToASCII(colorIndex))

                // RLE encode directly to output buffer
                rleEncodeTo(&outputBuffer, data: colorBandData[colorIndex])
            }

            // Line feed (move to next sixel band) - except for last band
            if band < numBands - 1 {
                outputBuffer.append(0x2D)  // -
            }
        }

        // String Terminator: ESC \
        outputBuffer.append(0x1B)
        outputBuffer.append(0x5C)
    }

    private func rleEncodeTo(_ output: inout [UInt8], data: [UInt8]) {
        let count = data.count
        guard count > 0 else {
            return
        }

        var i = 0
        while i < count {
            let char = data[i]
            var runLength = 1

            // Count consecutive identical characters (max 255)
            while i + runLength < count, data[i + runLength] == char, runLength < 255 {
                runLength += 1
            }

            if runLength >= 4 {
                // Use RLE: !<count><char>
                output.append(0x21)  // !
                output.append(contentsOf: Self.intToASCII(runLength))
                output.append(char)
            } else {
                // Output characters directly
                for _ in 0..<runLength {
                    output.append(char)
                }
            }

            i += runLength
        }
    }
}

// Helper for init
private func intToASCII(_ value: Int) -> [UInt8] {
    if value == 0 {
        return [0x30]
    }
    var digits = [UInt8]()
    var v = value
    while v > 0 {
        digits.append(UInt8(0x30 + v % 10))
        v /= 10
    }
    return digits.reversed()
}
