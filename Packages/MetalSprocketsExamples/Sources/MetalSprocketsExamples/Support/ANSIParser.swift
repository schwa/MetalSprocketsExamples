import MetalSprocketsAddOns
import simd

/// Parses a string containing ANSI escape codes into an array of ColoredCharacter.
enum ANSIParser {
    /// Standard ANSI 8-color palette (normal intensity).
    private static let standardColors: [SIMD4<Float>] = [
        SIMD4(0.0, 0.0, 0.0, 1.0),       // 0: black
        SIMD4(0.8, 0.0, 0.0, 1.0),       // 1: red
        SIMD4(0.0, 0.8, 0.0, 1.0),       // 2: green
        SIMD4(0.8, 0.8, 0.0, 1.0),       // 3: yellow
        SIMD4(0.0, 0.0, 0.8, 1.0),       // 4: blue
        SIMD4(0.8, 0.0, 0.8, 1.0),       // 5: magenta
        SIMD4(0.0, 0.8, 0.8, 1.0),       // 6: cyan
        SIMD4(0.75, 0.75, 0.75, 1.0)     // 7: white
    ]

    /// Bright ANSI colors.
    private static let brightColors: [SIMD4<Float>] = [
        SIMD4(0.5, 0.5, 0.5, 1.0),       // 0: bright black (gray)
        SIMD4(1.0, 0.0, 0.0, 1.0),       // 1: bright red
        SIMD4(0.0, 1.0, 0.0, 1.0),       // 2: bright green
        SIMD4(1.0, 1.0, 0.0, 1.0),       // 3: bright yellow
        SIMD4(0.0, 0.0, 1.0, 1.0),       // 4: bright blue
        SIMD4(1.0, 0.0, 1.0, 1.0),       // 5: bright magenta
        SIMD4(0.0, 1.0, 1.0, 1.0),       // 6: bright cyan
        SIMD4(1.0, 1.0, 1.0, 1.0)        // 7: bright white
    ]

    /// Parses ANSI-colored text into ColoredCharacters.
    /// Supports SGR codes: reset (0), bold (1), standard fg (30-37), bright fg (90-97),
    /// 256-color fg (38;5;n), and 24-bit fg (38;2;r;g;b).
    static func parse(_ input: String) -> [ColoredCharacter] {
        var result: [ColoredCharacter] = []
        var currentColor = SIMD4<Float>(1, 1, 1, 1)  // default white
        var bold = false

        var iterator = input.unicodeScalars.makeIterator()

        while let scalar = iterator.next() {
            if scalar == "\u{1B}" {
                // Check for CSI sequence: ESC [
                guard let next = iterator.next(), next == "[" else { continue }

                // Read parameters until we hit a letter
                var paramString = ""
                while let ch = iterator.next() {
                    if ch.value >= 0x40, ch.value <= 0x7E {
                        // Final byte
                        if ch == "m" {
                            // SGR sequence
                            let params = paramString.isEmpty ? [0] : paramString.split(separator: ";").compactMap { Int($0) }
                            var i = 0
                            while i < params.count {
                                let code = params[i]
                                switch code {
                                case 0:
                                    currentColor = SIMD4(1, 1, 1, 1)
                                    bold = false
                                case 1:
                                    bold = true
                                case 22:
                                    bold = false
                                case 30...37:
                                    currentColor = bold ? brightColors[code - 30] : standardColors[code - 30]
                                case 38:
                                    // Extended color
                                    if i + 1 < params.count, params[i + 1] == 5, i + 2 < params.count {
                                        // 256-color: 38;5;n
                                        currentColor = color256(params[i + 2])
                                        i += 2
                                    } else if i + 1 < params.count, params[i + 1] == 2, i + 4 < params.count {
                                        // 24-bit: 38;2;r;g;b
                                        currentColor = SIMD4(
                                            Float(params[i + 2]) / 255.0,
                                            Float(params[i + 3]) / 255.0,
                                            Float(params[i + 4]) / 255.0,
                                            1.0
                                        )
                                        i += 4
                                    }
                                case 39:
                                    currentColor = SIMD4(1, 1, 1, 1)
                                case 90...97:
                                    currentColor = brightColors[code - 90]
                                default:
                                    break
                                }
                                i += 1
                            }
                        }
                        break
                    }
                    paramString.append(Character(ch))
                }
            } else {
                result.append(ColoredCharacter(Character(scalar), color: currentColor))
            }
        }
        return result
    }

    /// Convert 256-color index to RGBA.
    private static func color256(_ index: Int) -> SIMD4<Float> {
        if index < 8 {
            return standardColors[index]
        }
        if index < 16 {
            return brightColors[index - 8]
        }
        if index < 232 {
            // 6x6x6 color cube
            let i = index - 16
            let r = Float((i / 36) % 6) / 5.0
            let g = Float((i / 6) % 6) / 5.0
            let b = Float(i % 6) / 5.0
            return SIMD4(r, g, b, 1.0)
        }
        // Grayscale ramp
        let gray = Float(index - 232) / 23.0
        return SIMD4(gray, gray, gray, 1.0)
    }
}
