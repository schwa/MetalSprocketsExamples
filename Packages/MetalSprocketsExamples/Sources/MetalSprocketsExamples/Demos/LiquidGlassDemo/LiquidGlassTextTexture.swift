import CoreGraphics
import CoreText
import Foundation
import Metal

enum TextTextureError: Error {
    case contextCreationFailed
    case textureCreationFailed
}

/// Renders marquee rows of text into a horizontally tileable grayscale texture.
/// Each row repeats its phrase an exact integer number of times so the
/// repeat-addressed sampler never cuts a word at the wrap seam.
func makeLiquidGlassTextTexture(device: MTLDevice, width: Int = 2_048, height: Int = 1_024, rows: Int = 8) throws -> MTLTexture {
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
        throw TextTextureError.contextCreationFailed
    }

    let phrases = ["LIQUID GLASS", "REFRACTION", "CHROMATIC DISPERSION", "FRESNEL", "SPECULAR", "DIFFRACTION", "METAL", "CAUSTICS"]
    let rowHeight = CGFloat(height) / CGFloat(rows)

    for row in 0..<rows {
        let phrase = phrases[row % phrases.count]
        let fontSize = rowHeight * (row.isMultiple(of: 2) ? 0.62 : 0.42)
        let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, fontSize, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 1, alpha: 1)
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: phrase, attributes: attributes))
        let phraseWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        guard phraseWidth > 0 else {
            continue
        }

        let minGap = rowHeight * 0.6
        let copies = max(1, Int(CGFloat(width) / (phraseWidth + minGap)))
        let period = CGFloat(width) / CGFloat(copies)
        let baseline = rowHeight * CGFloat(row) + (rowHeight - CTFontGetCapHeight(font)) / 2

        for copy in 0..<copies {
            context.textPosition = CGPoint(x: period * CGFloat(copy), y: baseline)
            CTLineDraw(line, context)
        }
    }

    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: width, height: height, mipmapped: false)
    descriptor.usage = .shaderRead
    guard let texture = device.makeTexture(descriptor: descriptor), let data = context.data else {
        throw TextTextureError.textureCreationFailed
    }
    texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: data, bytesPerRow: width)
    return texture
}
