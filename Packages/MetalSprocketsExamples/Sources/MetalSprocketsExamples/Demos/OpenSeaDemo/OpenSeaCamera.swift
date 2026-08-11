import simd

/// Orbiting camera locked above the sea surface, matching the OrbitControls setup
/// of the original WebGPU sketch.
struct OpenSeaCamera: Equatable {
    /// Drag sensitivity: how far one point of pointer movement rotates the camera.
    static let radiansPerPoint: Float = 0.006

    var target = SIMD3<Float>(0, 1.5, 0)
    var distance: Float = 17
    var azimuth: Float = 0
    /// Polar angle from +Y. Clamped so the camera never dips below the sea.
    var polar: Float = .pi / 2 * 0.85

    private static let minDistance: Float = 4
    private static let maxDistance: Float = 120
    private static let minPolar: Float = 0.15
    private static let maxPolar: Float = .pi * 0.495

    var position: SIMD3<Float> {
        let sp = sin(polar)
        return target + distance * SIMD3(sp * sin(azimuth), cos(polar), sp * cos(azimuth))
    }

    var viewMatrix: float4x4 {
        float4x4(lookAt: position, target: target, up: [0, 1, 0])
    }

    mutating func orbit(deltaX: Float, deltaY: Float) {
        azimuth -= deltaX * Self.radiansPerPoint
        polar = min(max(polar + deltaY * Self.radiansPerPoint, Self.minPolar), Self.maxPolar)
    }

    mutating func zoom(delta: Float) {
        distance = min(max(distance * exp(delta * 0.01), Self.minDistance), Self.maxDistance)
    }
}

// MARK: - Matrix helpers

extension float4x4 {
    init(perspectiveFOV fov: Float, aspect: Float, near: Float, far: Float) {
        let y = 1 / tan(fov * 0.5)
        let x = y / aspect
        let z = far / (near - far)
        self.init(
            SIMD4(x, 0, 0, 0),
            SIMD4(0, y, 0, 0),
            SIMD4(0, 0, z, -1),
            SIMD4(0, 0, z * near, 0)
        )
    }

    init(lookAt eye: SIMD3<Float>, target: SIMD3<Float>, up: SIMD3<Float>) {
        let f = normalize(target - eye)
        let s = normalize(cross(f, up))
        let u = cross(s, f)
        self.init(
            SIMD4(s.x, u.x, -f.x, 0),
            SIMD4(s.y, u.y, -f.y, 0),
            SIMD4(s.z, u.z, -f.z, 0),
            SIMD4(-dot(s, eye), -dot(u, eye), dot(f, eye), 1)
        )
    }
}
