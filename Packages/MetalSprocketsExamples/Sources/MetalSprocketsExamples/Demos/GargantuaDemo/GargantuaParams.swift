import Foundation

struct GargantuaParams: Equatable {
    var steps: Float = 460
    var rayScale: Float = 0.75
    var din: Float = 2.75
    var dout: Float = 40
    var dopMax: Float = 1.85
    var opNear: Float = 0.90
    var opFar: Float = 0.80
    var diskBright: Float = 1
    var starBright: Float = 1
    var skyFloor: Float = 0.04
    var rotSpeed: Float = 1
    var bloomStrength: Float = 0.55
    var bloomRadius: Float = 0.35
    var bloomThreshold: Float = 0.55
    var vignette: Float = 1
    var grain: Float = 0.045
    var ca: Float = 0.0028
    var fov: Float = 44
    var maxDistance: Float = 150
    var orbitSpeed: Float = 0.12
    var cineSegment: Float = 11
    var debug: Float = 0
}

struct GargantuaParamDef: Identifiable {
    var id: String { label }
    let label: String
    let key: WritableKeyPath<GargantuaParams, Float>
    let range: ClosedRange<Float>
    let format: (Float) -> String

    static func f(_ digits: Int, _ suffix: String = "", scale: Float = 1) -> (Float) -> String {
        { ($0 * scale).formatted(.number.precision(.fractionLength(digits))) + suffix }
    }
}

@MainActor let gargantuaParamDefs: [GargantuaParamDef] = [
    .init(label: "Geodesic Steps", key: \.steps, range: 60...600, format: GargantuaParamDef.f(0)),
    .init(label: "Ray Resolution", key: \.rayScale, range: 0.5...1, format: GargantuaParamDef.f(0, "%", scale: 100)),
    .init(label: "Disk Inner Edge", key: \.din, range: 2...4, format: GargantuaParamDef.f(2, " RS")),
    .init(label: "Disk Outer Edge", key: \.dout, range: 10...80, format: GargantuaParamDef.f(0, " RS")),
    .init(label: "Doppler Cap", key: \.dopMax, range: 1...3, format: GargantuaParamDef.f(2)),
    .init(label: "Opacity Near", key: \.opNear, range: 0.5...1, format: GargantuaParamDef.f(2)),
    .init(label: "Opacity Far", key: \.opFar, range: 0.3...1, format: GargantuaParamDef.f(2)),
    .init(label: "Disk Brightness", key: \.diskBright, range: 0.2...3, format: GargantuaParamDef.f(2)),
    .init(label: "Star Brightness", key: \.starBright, range: 0.2...3, format: GargantuaParamDef.f(2)),
    .init(label: "Sky Floor", key: \.skyFloor, range: 0...0.15, format: GargantuaParamDef.f(3)),
    .init(label: "Disk Rotation", key: \.rotSpeed, range: 0...3, format: GargantuaParamDef.f(2)),
    .init(label: "Bloom Strength", key: \.bloomStrength, range: 0...1.5, format: GargantuaParamDef.f(2)),
    .init(label: "Bloom Radius", key: \.bloomRadius, range: 0...1, format: GargantuaParamDef.f(2)),
    .init(label: "Bloom Threshold", key: \.bloomThreshold, range: 0...1, format: GargantuaParamDef.f(2)),
    .init(label: "Vignette", key: \.vignette, range: 0...1.5, format: GargantuaParamDef.f(2)),
    .init(label: "Film Grain", key: \.grain, range: 0...0.15, format: GargantuaParamDef.f(3)),
    .init(label: "Chromatic Aberration", key: \.ca, range: 0...0.01, format: GargantuaParamDef.f(1, "e-3", scale: 1_000)),
    .init(label: "Field of View", key: \.fov, range: 25...80, format: GargantuaParamDef.f(0, "°")),
    .init(label: "Max Distance", key: \.maxDistance, range: 40...300, format: GargantuaParamDef.f(0, " RS")),
    .init(label: "Orbit Speed", key: \.orbitSpeed, range: 0...1, format: GargantuaParamDef.f(2)),
    .init(label: "Cine Segment", key: \.cineSegment, range: 4...30, format: GargantuaParamDef.f(0, " s")),
    .init(label: "Debug Mode", key: \.debug, range: 0...10, format: GargantuaParamDef.f(0))
]

enum GargantuaQuality: String, CaseIterable, Identifiable {
    case standard, high, cinematic

    var id: String { rawValue }

    /// Geodesic step budget.
    var steps: Float {
        switch self {
        case .standard: 200
        case .high: 320
        case .cinematic: 460
        }
    }

    /// Fraction of the drawable resolution the ray pass is traced at; the
    /// result is upscaled to full resolution before post-processing.
    var rayScale: Float {
        switch self {
        case .standard: 0.5
        case .high: 0.75
        case .cinematic: 1.0
        }
    }
}
