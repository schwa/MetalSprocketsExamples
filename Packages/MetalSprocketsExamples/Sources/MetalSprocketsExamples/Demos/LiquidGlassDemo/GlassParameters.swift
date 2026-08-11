import Foundation

struct Pill: Equatable {
    /// Center in normalized view coordinates (0...1, y down).
    var center: SIMD2<Float>
    /// Half-extents as fractions of view height.
    var halfSize: SIMD2<Float>
}

struct GlassParameters: Equatable {
    static let maxPills = 8

    var pills: [Pill] = [
        Pill(center: [0.38, 0.42], halfSize: [0.24, 0.11]),
        Pill(center: [0.68, 0.60], halfSize: [0.12, 0.12])
    ]
    var ior: Float = 1.45
    var dispersion: Float = 0.04
    /// Bevel width as a fraction of view height.
    var bevel: Float = 0.055
    /// Frost blur radius in pixels.
    var frost: Float = 1.5
    /// Smooth-min blend radius as a fraction of view height.
    var blend: Float = 0.06
}
