import Foundation
import MetalSprocketsExampleShaders
import simd

public struct MeadowCamera: Equatable, Sendable {
    public var position: SIMD3<Float>
    public var yaw: Float = 0.15
    public var pitch: Float = 0.06

    public init() {
        position = SIMD3(0, MeadowSceneGeometry.height(x: 0, z: 0) + 1.7, 0)
    }

    var forward: SIMD3<Float> {
        SIMD3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))
    }

    var right: SIMD3<Float> {
        SIMD3(cos(yaw), 0, sin(yaw))
    }

    public mutating func look(horizontal: Float, vertical: Float) {
        yaw += horizontal
        pitch = min(1.4, max(-1.4, pitch + vertical))
    }

    public mutating func walk(forward distance: Float, sideways: Float) {
        position += SIMD3(sin(yaw), 0, -cos(yaw)) * distance + right * sideways
        position.x = min(260, max(-260, position.x))
        position.z = min(260, max(-260, position.z))
        position.y = MeadowSceneGeometry.height(x: position.x, z: position.z) + 1.7
    }
}

public struct MeadowSettings: Equatable, Sendable {
    public var sunElevation: Float = 0.30
    public var sunAzimuth: Float = -0.38
    public var haze: Float = 0.0025
    public var cloudCoverage: Float = 0.43
    public var exposure: Float = 1.0
    public var cloudTime: Float = 0

    public init() {
        // This line intentionally left blank.
    }
}

extension MeadowUniforms {
    init(camera: MeadowCamera, settings: MeadowSettings, frameIndex: UInt32, sampleCount: UInt32) {
        let elevation = max(0.05, settings.sunElevation)
        self.init(
            origin: SIMD4(camera.position, 0),
            forward: SIMD4(camera.forward, 0),
            right: SIMD4(camera.right, 0),
            up: SIMD4(simd_cross(camera.right, camera.forward), 0),
            sun: SIMD4(sin(settings.sunAzimuth) * cos(elevation), sin(elevation), -cos(settings.sunAzimuth) * cos(elevation), 3.5),
            atmosphere: SIMD4(settings.haze, settings.cloudCoverage, settings.cloudTime, settings.exposure),
            frame: SIMD4(frameIndex, sampleCount, 0, 0)
        )
    }
}

/// Unindexed triangle soup: three vertices and one material (albedo, foliage) per triangle.
struct MeadowSceneGeometry: Sendable {
    var vertices: [SIMD3<Float>] = []
    var materials: [SIMD4<Float>] = []

    static func height(x: Float, z: Float) -> Float {
        let distance = sqrt(x * x + z * z)
        let foothills = min(1, max(0, (distance - 80) / 120))
        let ridge = 20 + 15 * sin(x * 0.021 + z * 0.009) + 12 * cos(z * 0.026 - x * 0.013)
        return 2.8 * sin(x * 0.027) * cos(z * 0.032) + 0.55 * sin(z * 0.095 + x * 0.041)
            + 0.18 * cos(x * 0.17 - z * 0.12) + foothills * foothills * ridge
    }

    mutating func triangle(_ first: SIMD3<Float>, _ second: SIMD3<Float>, _ third: SIMD3<Float>, color: SIMD3<Float>, foliage: Float) {
        vertices.append(contentsOf: [first, second, third])
        materials.append(SIMD4(color, foliage))
    }

    static func make(seed: UInt64 = 73, grassCount: Int = 290_000, treeCount: Int = 125) -> Self {
        var scene = Self()
        var random = MeadowRandom(state: seed)
        addTerrain(to: &scene)
        addGrass(to: &scene, count: grassCount, random: &random)
        addTrees(to: &scene, count: treeCount, random: &random)
        return scene
    }

    private static func addTerrain(to scene: inout Self) {
        let ground = SIMD3<Float>(0.19, 0.25, 0.055)
        for z in -100..<100 {
            for x in -100..<100 {
                let left = terrainCoordinate(x)
                let right = terrainCoordinate(x + 1)
                let back = terrainCoordinate(z)
                let front = terrainCoordinate(z + 1)
                let first = SIMD3(left, height(x: left, z: back), back)
                let second = SIMD3(right, height(x: right, z: back), back)
                let third = SIMD3(left, height(x: left, z: front), front)
                let fourth = SIMD3(right, height(x: right, z: front), front)
                scene.triangle(first, third, second, color: ground, foliage: 0)
                scene.triangle(second, third, fourth, color: ground, foliage: 0)
            }
        }
    }

    private static func addGrass(to scene: inout Self, count: Int, random: inout MeadowRandom) {
        for _ in 0..<count {
            let angle = random.value() * 2 * .pi
            let radius = (0.025 + random.value() * 0.975) * 78
            let x = cos(angle) * radius
            let z = sin(angle) * radius
            let root = SIMD3(x, height(x: x, z: z), z)
            let bladeHeight = 0.16 + random.value() * 0.48
            let direction = random.value() * 2 * .pi
            let side = SIMD3<Float>(cos(direction), 0, sin(direction)) * (0.008 + random.value() * 0.014)
            let bend = SIMD3<Float>(0.18 + cos(direction) * 0.18, 0, sin(direction) * 0.18) * bladeHeight
            let middle = root + SIMD3<Float>(0, bladeHeight * 0.55, 0) + bend * 0.3
            let tip = root + SIMD3<Float>(0, bladeHeight, 0) + bend
            let color = simd_mix(SIMD3<Float>(0.055, 0.15, 0.018), SIMD3<Float>(0.38, 0.43, 0.075), SIMD3(repeating: random.value()))
            for blade in 0..<4 {
                let angle = Float(blade) * 2.39996
                let spread = SIMD3<Float>(cos(angle), 0, sin(angle)) * 0.065
                let lean = spread * (2 + random.value() * 2)
                scene.triangle(root + spread - side, root + spread + side, middle + lean + side * 0.55, color: color * 0.65, foliage: 1)
                scene.triangle(root + spread - side, middle + lean + side * 0.55, middle + lean - side * 0.55, color: color, foliage: 1)
                scene.triangle(middle + lean - side * 0.55, middle + lean + side * 0.55, tip + lean * 2, color: color, foliage: 1)
            }
            if random.value() < 0.013 {
                let flowerColor = random.value() < 0.7 ? SIMD3<Float>(0.85, 0.72, 0.22) : SIMD3<Float>(0.52, 0.24, 0.61)
                let flower = tip + SIMD3<Float>(0, 0.04, 0)
                for petal in 0..<5 {
                    let angle = Float(petal) * 2 * .pi / 5
                    let offset = SIMD3<Float>(cos(angle), 0.1, sin(angle)) * 0.07
                    let side = SIMD3<Float>(-sin(angle), 0, cos(angle)) * 0.035
                    scene.triangle(flower, flower + offset + side, flower + offset - side, color: flowerColor, foliage: 1)
                }
            }
        }
    }

    private static func addTrees(to scene: inout Self, count: Int, random: inout MeadowRandom) {
        for index in 0..<count {
            let angle = Float(index) * 2.39996 + random.value() * 0.3
            let radius = 24 + random.value() * 150
            let x = cos(angle) * radius
            let z = sin(angle) * radius
            let root = SIMD3(x, height(x: x, z: z), z)
            let size = 7 + random.value() * 8
            let crown = root + SIMD3<Float>(0, size * 0.75, 0)
            scene.branch(from: root, to: crown, radius: size * 0.035)
            for branchIndex in 0..<18 {
                let angle = Float(branchIndex) * 2.39996
                let start = root + SIMD3<Float>(0, size * (0.32 + Float(branchIndex) * 0.022), 0)
                let spread = 0.15 + random.value() * 0.2
                let end = crown + SIMD3<Float>(cos(angle) * size * spread, (random.value() - 0.5) * size * 0.35, sin(angle) * size * spread)
                scene.branch(from: start, to: end, radius: size * 0.009)
                for _ in 0..<420 {
                    let azimuth = random.value() * 2 * .pi
                    let elevation = random.value() * 2 - 1
                    let spread = pow(random.value(), 1 / Float(3)) * size * 0.16
                    let horizontal = sqrt(1 - elevation * elevation)
                    let center = end + SIMD3(cos(azimuth) * horizontal, elevation * 0.85, sin(azimuth) * horizontal) * spread
                    let leafSize = 0.045 + random.value() * 0.085
                    let side = SIMD3<Float>(cos(azimuth), 0.2, sin(azimuth)) * leafSize
                    let up = SIMD3<Float>(-sin(azimuth) * 0.4, 1, cos(azimuth) * 0.4) * leafSize
                    let green = simd_mix(SIMD3<Float>(0.035, 0.10, 0.012), SIMD3<Float>(0.29, 0.38, 0.045), SIMD3(repeating: random.value()))
                    scene.triangle(center - side, center + up, center + side, color: green, foliage: 1)
                    scene.triangle(center - side, center + side, center - up, color: green, foliage: 1)
                }
            }
        }
    }

    private static func terrainCoordinate(_ index: Int) -> Float {
        let magnitude = Float(abs(index))
        let distance = magnitude * 3 + pow(max(0, magnitude - 60), 2) * 0.6
        return index < 0 ? -distance : distance
    }

    private mutating func branch(from start: SIMD3<Float>, to end: SIMD3<Float>, radius: Float) {
        let axis = simd_normalize(end - start)
        let reference = abs(axis.y) > 0.95 ? SIMD3<Float>(1, 0, 0) : SIMD3<Float>(0, 1, 0)
        let side = simd_normalize(simd_cross(axis, reference))
        let up = simd_cross(axis, side)
        for index in 0..<7 {
            let firstAngle = Float(index) * 2 * .pi / 7
            let secondAngle = Float(index + 1) * 2 * .pi / 7
            let first = (cos(firstAngle) * side + sin(firstAngle) * up) * radius
            let second = (cos(secondAngle) * side + sin(secondAngle) * up) * radius
            let bark = SIMD3<Float>(0.16, 0.09, 0.04)
            triangle(start + first, end + first * 0.4, start + second, color: bark, foliage: 0)
            triangle(start + second, end + first * 0.4, end + second * 0.4, color: bark, foliage: 0)
        }
    }
}

private struct MeadowRandom {
    var state: UInt64

    mutating func value() -> Float {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Float(state >> 40) / Float(1 << 24)
    }
}
