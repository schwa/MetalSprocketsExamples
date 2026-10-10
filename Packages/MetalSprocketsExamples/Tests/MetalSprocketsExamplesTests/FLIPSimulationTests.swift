import CoreGraphics
import Metal
import MetalSprockets
@testable import MetalSprocketsExamples
import Testing

@Suite
struct FLIPSimulationTests {
    @Test("Each scene seeds particles, stays in the tank, and renders", arguments: FLIPScene.allCases)
    func whenSceneRuns_thenParticlesStayBoundedAndRender(scene: FLIPScene) throws {
        let renderer = try OffscreenRenderer(size: CGSize(width: 64, height: 48))
        let simulation = try FLIPSimulation(device: renderer.device, resolution: 12)

        _ = try renderer.render(FLIPCompute(simulation: simulation, reset: scene, steps: 0, reconstructsSurface: false))
        let seeded = simulation.statistics.particleCount
        #expect(seeded > 0)

        for showsParticles in [false, true] {
            let content = try Group {
                FLIPCompute(simulation: simulation, steps: 30, reconstructsSurface: !showsParticles)
                FLIPRender(simulation: simulation, showsParticles: showsParticles, viewportSize: [64, 48])
            }
            let rendering = try renderer.render(content)
            _ = try rendering.cgImage
        }

        let statistics = simulation.statistics
        #expect(statistics.simulatedTime > 0)
        #expect(statistics.maximumSpeed.isFinite)
        // Reseeding keeps 3–12 markers per occupied cell, so counts drift but must not collapse or explode.
        #expect(statistics.particleCount > seeded / 4)
        #expect(statistics.particleCount <= simulation.capacity)

        let positions = simulation.positions.contents().bindMemory(to: SIMD4<Float>.self, capacity: simulation.capacity)
        for index in 0..<simulation.capacity where positions[index].w > 0 {
            let position = SIMD3(positions[index].x, positions[index].y, positions[index].z)
            #expect(all(position .>= 0) && all(position .<= 1))
        }
    }

    @Test("Out-of-range resolutions are rejected")
    func whenResolutionIsOutOfRange_thenInitThrows() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        #expect(throws: (any Error).self) { try FLIPSimulation(device: device, resolution: 4) }
    }
}
