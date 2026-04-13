import Metal
import MetalKit
import MetalSprockets
import MetalSprocketsAddOns
import MetalSprocketsAddOnsShaders
import MetalSprocketsExamplesSupport
import MetalSprocketsSupport
import SwiftUI

enum LightingAnimator {
    static func run(date: Date, lighting: inout Lighting) {
        let date = date.timeIntervalSinceReferenceDate
        let angle = LinearTimingFunction().value(time: date, period: 1, in: 0 ... 2 * .pi)
        lighting.lights[Light.self, 0].color = [
            ForwardAndReverseTimingFunction(SinusoidalTimingFunction()).value(time: date, period: 1.0, offset: 0.0, in: 0.5 ... 1.0),
            ForwardAndReverseTimingFunction(SinusoidalTimingFunction()).value(time: date, period: 1.2, offset: 0.2, in: 0.5 ... 1.0),
            ForwardAndReverseTimingFunction(SinusoidalTimingFunction()).value(time: date, period: 1.4, offset: 0.6, in: 0.5 ... 1.0)
        ]
        lighting.lightPositions[SIMD3<Float>.self, 0] = simd_quatf(angle: angle, axis: [0, 1, 0]).act([1, 5, 0])
    }
}

extension Lighting {
    static func demo() throws -> Lighting {
        try Lighting(
            ambientLightColor: [0, 0, 0],
            lights: [
                ([1, 5, 0], Light(type: .point, color: [1, 1, 1], intensity: 50))
            ]
        )
    }
}

struct LightingVisualizer: Element {
    let cameraMatrix: float4x4
    let projectionMatrix: float4x4
    let lighting: Lighting
    let lightMarker = MTKMesh.sphere(extent: [0.1, 0.1, 0.1])
    var body: some Element {
        get throws {
            ForEach(Array(0 ..< lighting.count), id: \.self) { index in
                let lightPosition = lighting.lightPositions[SIMD3<Float>.self, index]
                let modelViewProjection = projectionMatrix * cameraMatrix.inverse * float4x4(translation: lightPosition)
                try FlatShader(modelViewProjection: modelViewProjection, textureSpecifier: .color([1, 1, 1])) {
                    Draw { encoder in
                        encoder.setVertexBuffers(of: lightMarker)
                        encoder.draw(lightMarker)
                    }
                }
                .vertexDescriptor(lightMarker.vertexDescriptor)
                .depthCompare(function: .less, enabled: true)
            }
        }
    }
}
