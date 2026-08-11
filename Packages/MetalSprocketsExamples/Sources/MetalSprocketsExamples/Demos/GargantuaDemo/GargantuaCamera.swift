import Foundation
import simd

private let d2r = Float.pi / 180

enum GargantuaPreset: String, CaseIterable, Identifiable {
    case poster, edge, polar, close

    var id: String { rawValue }

    var spec: (r: Float, inc: Float, az: Float) {
        switch self {
        case .poster: (24, 38, 30)
        case .edge: (26, 6, 10)
        case .polar: (28, 82, 0)
        case .close: (9, 14, 55)
        }
    }

    var position: SIMD3<Float> {
        let s = spec
        let inc = s.inc * d2r, az = s.az * d2r
        return SIMD3(s.r * cos(inc) * sin(az), s.r * sin(inc), s.r * cos(inc) * cos(az))
    }
}

/// Closed cinematic path: (radius, inclination°, azimuth°).
private let cineKeys: [(Float, Float, Float)] = [
    (58, 12, -30), (36, 6, 10), (26, 24, 55), (14, 14, 100),
    (20, 52, 150), (34, 80, 200), (46, 35, 270), (36, 8, 330)
]

private func catmullRom(_ p0: Float, _ p1: Float, _ p2: Float, _ p3: Float, _ t: Float) -> Float {
    let t2 = t * t, t3 = t2 * t
    return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
}

func easeCubic(_ k: Float) -> Float {
    k < 0.5 ? 4 * k * k * k : 1 - pow(-2 * k + 2, 3) / 2
}

/// Sample the closed cinematic camera path at `time` seconds.
func cinePath(time: Float, segment: Float) -> SIMD3<Float> {
    let n = cineKeys.count
    let seg = max(1, segment)
    let tt = time / seg
    let i = Int(floor(tt))
    let t = tt - floor(tt)
    func wrap(_ k: Int) -> Int { ((k % n) + n) % n }
    func radius(_ k: Int) -> Float { cineKeys[wrap(k)].0 }
    func incl(_ k: Int) -> Float { cineKeys[wrap(k)].1 * d2r }
    // azimuth ascends: unwrap by whole cycles so the path never rewinds
    func azim(_ k: Int) -> Float {
        cineKeys[wrap(k)].2 * d2r + 2 * .pi * Float(Int(floor(Double(k) / Double(n))))
    }
    let r = catmullRom(radius(i - 1), radius(i), radius(i + 1), radius(i + 2), t)
    let inc = catmullRom(incl(i - 1), incl(i), incl(i + 1), incl(i + 2), t)
    let a = catmullRom(azim(i - 1), azim(i), azim(i + 1), azim(i + 2), t)
    return SIMD3(r * cos(inc) * sin(a), r * sin(inc), r * cos(inc) * cos(a))
}

/// Damped orbit camera, modelled on three.js `OrbitControls`.
struct OrbitRig {
    var target = SIMD3<Float>(repeating: 0)
    var radius: Float = 26
    var theta: Float = 0.17    // azimuth
    var phi: Float = 1.46      // polar from +Y

    var deltaTheta: Float = 0
    var deltaPhi: Float = 0
    var zoomScale: Float = 1

    let dampingFactor: Float = 0.06
    let rotateSpeed: Float = 0.55
    let minDistance: Float = 1.62

    var position: SIMD3<Float> {
        target + SIMD3(
            radius * sin(phi) * sin(theta),
            radius * cos(phi),
            radius * sin(phi) * cos(theta)
        )
    }

    mutating func setPosition(_ p: SIMD3<Float>) {
        let v = p - target
        radius = max(1e-4, length(v))
        phi = acos(min(1, max(-1, v.y / radius)))
        theta = atan2(v.x, v.z)
        deltaTheta = 0
        deltaPhi = 0
        zoomScale = 1
    }

    mutating func drag(dx: Float, dy: Float, viewHeight: Float) {
        let h = max(1, viewHeight)
        deltaTheta -= 2 * .pi * dx / h * rotateSpeed
        deltaPhi -= 2 * .pi * dy / h * rotateSpeed
    }

    mutating func zoom(_ ticks: Float) {
        zoomScale *= pow(0.95, ticks * 0.7)
    }

    mutating func update(dt: Float, autoRotate: Bool, autoRotateSpeed: Float, maxDistance: Float) {
        if autoRotate {
            theta -= 2 * .pi / 60 * autoRotateSpeed * dt
        }
        theta += deltaTheta * dampingFactor
        phi += deltaPhi * dampingFactor
        deltaTheta *= 1 - dampingFactor
        deltaPhi *= 1 - dampingFactor
        phi = min(.pi - 0.0001, max(0.0001, phi))
        radius = min(maxDistance, max(minDistance, radius * pow(zoomScale, dampingFactor)))
        zoomScale = pow(zoomScale, 1 - dampingFactor)
    }
}

/// Owns the camera rig and its automation (cinematic path, preset flights,
/// auto-rotate). A plain reference type: SwiftUI gestures mutate it and the
/// pipeline advances it once per frame, without triggering view invalidation.
final class GargantuaSimulation {
    var rig = OrbitRig()
    var cineMode = true
    var autoRotate = false

    private var cineTime: Float = 0
    private var cineBlend: Float = 1
    private var cineFrom = SIMD3<Float>(repeating: 0)
    private var flight: (t: Float, dur: Float, from: SIMD3<Float>, to: SIMD3<Float>)?

    init() {
        rig.setPosition(GargantuaPreset.poster.position)
        cineFrom = rig.position
    }

    func drag(dx: Float, dy: Float, viewHeight: Float) {
        manualTakeover()
        flight = nil
        rig.drag(dx: dx, dy: dy, viewHeight: viewHeight)
    }

    func zoom(_ ticks: Float) {
        manualTakeover()
        flight = nil
        rig.zoom(ticks)
    }

    func flyTo(_ preset: GargantuaPreset) {
        cineMode = false
        flight = (t: 0, dur: 2.6, from: rig.position, to: preset.position)
    }

    func setCineMode(_ on: Bool) {
        guard on != cineMode else {
            return
        }
        cineMode = on
        if on {
            autoRotate = false
            flight = nil
            cineFrom = rig.position
            cineBlend = 0
        }
    }

    /// A manual gesture cancels any automation and hands the camera back over.
    private func manualTakeover() {
        cineMode = false
        flight = nil
    }

    func update(dt: Float, params: GargantuaParams) {
        if var f = flight {
            f.t += dt
            let k = easeCubic(min(1, f.t / f.dur))
            rig.setPosition(mix(f.from, f.to, t: k))
            flight = f.t >= f.dur ? nil : f
        } else if cineMode {
            cineTime += dt
            var target = cinePath(time: cineTime, segment: params.cineSegment)
            if cineBlend < 1 {
                cineBlend = min(1, cineBlend + dt / 2)
                target = mix(cineFrom, target, t: easeCubic(cineBlend))
            }
            rig.setPosition(target)
        } else {
            rig.update(dt: dt, autoRotate: autoRotate, autoRotateSpeed: params.orbitSpeed, maxDistance: params.maxDistance)
        }
    }
}

private func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, t: Float) -> SIMD3<Float> {
    a + (b - a) * t
}
