import Metal
import MetalSprockets
import MetalSprocketsExampleShaders
import MetalSprocketsSupport
import simd

/// Time-of-day palette endpoints, blended by sun elevation.
private struct Palette {
    var zenith: SIMD3<Float>
    var horizon: SIMD3<Float>
    var sun: SIMD3<Float>
    var intensity: Float
    var deep: SIMD3<Float>
    var shallow: SIMD3<Float>

    static let day = Self(
        zenith: [0.07, 0.2, 0.42],
        horizon: [0.52, 0.68, 0.82],
        sun: [1.0, 0.93, 0.8],
        intensity: 1.6,
        deep: [0.015, 0.09, 0.11],
        shallow: [0.06, 0.32, 0.36]
    )

    static let dusk = Self(
        zenith: [0.03, 0.05, 0.16],
        horizon: [0.85, 0.36, 0.16],
        sun: [1.0, 0.42, 0.14],
        intensity: 2.6,
        deep: [0.02, 0.045, 0.075],
        shallow: [0.09, 0.15, 0.2]
    )

    static func blend(_ a: Self, _ b: Self, _ t: Float) -> Self {
        Self(
            zenith: mix(a.zenith, b.zenith, t: t),
            horizon: mix(a.horizon, b.horizon, t: t),
            sun: mix(a.sun, b.sun, t: t),
            intensity: mix(a.intensity, b.intensity, t: t),
            deep: mix(a.deep, b.deep, t: t),
            shallow: mix(a.shallow, b.shallow, t: t)
        )
    }
}

/// Encodes one frame of ocean and sky.
///
/// The ocean mesh is a radial disc of concentric rings centred on the camera, with
/// no vertex buffer at all: the vertex shader derives each position from the vertex
/// ID. Only an index buffer exists, built once in `onSetupEnter`. The sky is a
/// fullscreen triangle at the far plane, drawn after the ocean so depth testing
/// rejects it wherever water covers the screen.
struct OpenSeaPipeline: Element {
    let seaState: Double
    let timeOfDay: Double
    let drift: Bool
    let camera: OpenSeaCamera
    let time: Float
    let aspect: Float

    // Radial grid: concentric rings whose spacing grows geometrically outwards, so
    // tessellation is roughly uniform in screen space instead of in world space.
    private static let ringSpokes = 128
    private static let ringCount = 110
    private static let ringInnerRadius: Float = 1
    private static let ringOuterRadius: Float = 297
    private static let ringGrowth = log(ringOuterRadius / ringInnerRadius) / Float(ringCount - 1)
    private static let indicesPerSpoke = 3 + (ringCount - 1) * 6

    @MSState
    private var oceanVertexShader: VertexShader

    @MSState
    private var oceanFragmentShader: FragmentShader

    @MSState
    private var skyVertexShader: VertexShader

    @MSState
    private var skyFragmentShader: FragmentShader

    @MSState
    private var indexBuffer: MTLBuffer?

    // Slow automatic orbit, accumulated so toggling drift never makes the camera jump.
    @MSState
    private var driftAngle: Float = 0

    @MSState
    private var lastTime: Float?

    init(seaState: Double, timeOfDay: Double, drift: Bool, camera: OpenSeaCamera, time: Float, aspect: Float) throws {
        self.seaState = seaState
        self.timeOfDay = timeOfDay
        self.drift = drift
        self.camera = camera
        self.time = time
        self.aspect = aspect
        let shaders = try ShaderNamespace.examples("OpenSea")
        oceanVertexShader = try shaders.ocean_vertex
        oceanFragmentShader = try shaders.ocean_fragment
        skyVertexShader = try shaders.sky_vertex
        skyFragmentShader = try shaders.sky_fragment
    }

    var body: some Element {
        get throws {
            let uniforms = makeUniforms()
            try Group {
                if let indexBuffer {
                    // Ocean first: it writes depth, so the sky's fullscreen triangle
                    // (at z = 1) is depth-rejected wherever water covers the screen.
                    try RenderPipeline(vertexShader: oceanVertexShader, fragmentShader: oceanFragmentShader) {
                        Draw { encoder in
                            for range in visibleSpokeRanges() {
                                encoder.drawIndexedPrimitives(
                                    type: .triangle,
                                    indexCount: range.count * Self.indicesPerSpoke,
                                    indexType: .uint16,
                                    indexBuffer: indexBuffer,
                                    indexBufferOffset: range.lowerBound * Self.indicesPerSpoke * MemoryLayout<UInt16>.stride
                                )
                            }
                        }
                        .parameter("uniforms", functionType: .vertex, value: uniforms)
                        .parameter("uniforms", functionType: .fragment, value: uniforms)
                    }
                    .depthCompare(function: .lessEqual, enabled: true)

                    try RenderPipeline(vertexShader: skyVertexShader, fragmentShader: skyFragmentShader) {
                        Draw { encoder in
                            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                        }
                        .parameter("uniforms", functionType: .vertex, value: uniforms)
                        .parameter("uniforms", functionType: .fragment, value: uniforms)
                    }
                    .depthCompare(function: .lessEqual, enabled: true)
                }
            }
            .onSetupEnter { environment in
                guard indexBuffer == nil, let device = environment.device else {
                    return
                }
                let indices = Self.makeRadialIndices(spokes: Self.ringSpokes, rings: Self.ringCount)
                indexBuffer = device.makeBuffer(bytes: indices, length: MemoryLayout<UInt16>.stride * indices.count)
            }
            .onWorkloadEnter { _ in
                let delta = min(max(time - (lastTime ?? time), 0), 0.1)
                lastTime = time
                if drift {
                    driftAngle -= delta * 0.0262
                }
            }
        }
    }

    /// The camera the frame is actually rendered with: user orbit plus accumulated drift.
    private var effectiveCamera: OpenSeaCamera {
        var camera = camera
        camera.azimuth += driftAngle
        return camera
    }

    // MARK: - Mesh

    /// Indices for the radial grid: a fan around the centre vertex plus quads between
    /// successive rings. Vertex positions are derived from the vertex ID in the shader.
    private static func makeRadialIndices(spokes: Int, rings: Int) -> [UInt16] {
        var indices: [UInt16] = []
        indices.reserveCapacity(spokes * 3 + (rings - 1) * spokes * 6)
        // Spoke-major order: every wedge's triangles are contiguous, so a range of
        // spokes can be drawn on its own for frustum culling.
        let spokeCount = UInt16(spokes)
        for s in 0..<spokeCount {
            let next = (s + 1) % spokeCount
            indices.append(contentsOf: [0, 1 + s, 1 + next])
            for ring in 0..<UInt16(rings - 1) {
                let inner = 1 + ring * spokeCount
                let outer = inner + spokeCount
                indices.append(contentsOf: [
                    inner + s, outer + s, inner + next,
                    inner + next, outer + s, outer + next
                ])
            }
        }
        return indices
    }

    // MARK: - Uniforms

    private func makeUniforms() -> OpenSeaUniforms {
        let camera = effectiveCamera
        let elevation = mix(-0.05 as Float, 0.62, t: Float(timeOfDay / 100))
        let azimuth = mix(-0.9 as Float, 0.9, t: Float(timeOfDay / 100))
        let ce = cos(elevation)
        let sunDirection = SIMD3<Float>(
            ce * sin(azimuth),
            sin(elevation),
            -ce * cos(azimuth)
        )

        // Daylight blend: 0 at or below the horizon, 1 once the sun is high.
        let palette = Palette.blend(.dusk, .day, smoothstep(0, 0.42, elevation))

        let view = camera.viewMatrix
        let projection = float4x4(
            perspectiveFOV: 55 * .pi / 180,
            aspect: aspect,
            near: 0.5,
            far: 8_000
        )
        let viewProjection = projection * view

        return OpenSeaUniforms(
            viewProjection: viewProjection,
            inverseViewProjection: viewProjection.inverse,
            cameraPosition: camera.position,
            sunDirection: sunDirection,
            sunColor: palette.sun * palette.intensity,
            horizonColor: palette.horizon,
            zenithColor: palette.zenith,
            deepColor: palette.deep,
            shallowColor: palette.shallow,
            time: time,
            sea: 0.25 + Float(seaState / 100) * 1.5,
            ringSpokes: UInt32(Self.ringSpokes),
            ringInnerRadius: Self.ringInnerRadius,
            ringGrowth: Self.ringGrowth,
            gridCenter: SIMD2(camera.position.x, camera.position.z)
        )
    }

    // MARK: - Culling

    /// Spoke ranges covering the horizontal frustum. The grid is centred on the camera,
    /// so only a wedge around the view azimuth can project on screen — unless the view
    /// tilts far enough down that the frustum straddles the point below the eye, in
    /// which case every azimuth is visible and the whole disc is drawn.
    private func visibleSpokeRanges() -> [Range<Int>] {
        let camera = effectiveCamera
        let spokes = Float(Self.ringSpokes)
        let forward = normalize(camera.target - camera.position)
        let right = normalize(cross(forward, SIMD3<Float>(0, 1, 0)))
        let up = cross(right, forward)
        let tanY: Float = tan(0.5 * 55 * .pi / 180)
        let tanX: Float = aspect * tanY

        // Azimuth spread of the four frustum corner rays around the view direction.
        var maxDeviation: Float = 0
        let viewAzimuth = atan2(forward.z, forward.x)
        for sx in [-1, 1] as [Float] {
            for sy in [-1, 1] as [Float] {
                let horizontalOffset: SIMD3<Float> = right * (sx * tanX)
                let verticalOffset: SIMD3<Float> = up * (sy * tanY)
                let ray: SIMD3<Float> = forward + horizontalOffset + verticalOffset
                let horizontal = simd_length(SIMD2(ray.x, ray.z))
                // A corner ray pointing near-vertically means the wedge is unbounded.
                guard horizontal > 0.25 * simd_length(ray) else {
                    return [0..<Self.ringSpokes]
                }
                var delta = atan2(ray.z, ray.x) - viewAzimuth
                delta = atan2(sin(delta), cos(delta))
                maxDeviation = max(maxDeviation, abs(delta))
            }
        }

        // Margin: vertices on the innermost rings sit only a metre from the grid centre,
        // where wave displacement can swing them tens of degrees.
        let halfWedge = maxDeviation + 0.8
        guard halfWedge < .pi else {
            return [0..<Self.ringSpokes]
        }

        let centre = viewAzimuth * spokes / (2 * .pi)
        let half = halfWedge * spokes / (2 * .pi)
        let first = Int(floor(centre - half))
        let count = min(Self.ringSpokes, Int(ceil(centre + half)) - first + 1)
        let start = ((first % Self.ringSpokes) + Self.ringSpokes) % Self.ringSpokes

        if start + count <= Self.ringSpokes {
            return [start..<(start + count)]
        }
        return [start..<Self.ringSpokes, 0..<(start + count - Self.ringSpokes)]
    }
}

// MARK: - Math helpers

private func mix(_ a: Float, _ b: Float, t: Float) -> Float {
    a + (b - a) * t
}

private func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, t: Float) -> SIMD3<Float> {
    a + (b - a) * t
}

private func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
    let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
    return t * t * (3 - 2 * t)
}
