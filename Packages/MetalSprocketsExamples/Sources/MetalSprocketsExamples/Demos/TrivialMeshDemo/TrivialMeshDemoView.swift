import DemoKit
import GeometryLite3D
import Interaction3D
import Metal
import MetalKit
import MetalSprockets
import MetalSprocketsAddOns
import MetalSprocketsAddOnsShaders
import MetalSprocketsSupport
import MetalSprocketsUI
import simd
import SwiftUI

public struct TrivialMeshDemoView: View {
    public init() { }

    @State private var models: [Model] = []
    @State private var lighting: Lighting?
    @State private var skyboxTexture: MTLTexture?
    @State private var showWireframe = false

    @State private var cameraRotation = simd_quatf(angle: -.pi / 8, axis: [1, 0, 0])
    @State private var cameraDistance: Float = 12
    @State private var cameraTarget: SIMD3<Float> = [0, 0.5, 0]

    private var cameraMatrix: simd_float4x4 {
        let rotation = float4x4(cameraRotation)
        let translation = float4x4.translation(cameraTarget.x, cameraTarget.y, cameraTarget.z)
        let distance = float4x4.translation(0, 0, cameraDistance)
        return translation * rotation * distance
    }

    public var body: some View {
        RenderView { _, drawableSize in
            let aspect = drawableSize.height > 0 ? Float(drawableSize.width / drawableSize.height) : 1.0
            let projectionMatrix = float4x4.perspective(fovY: .pi / 4, aspect: aspect, near: 0.1, far: 1_000.0)
            let viewMatrix = cameraMatrix.inverse

            try RenderPass(label: "TrivialMesh Demo") {
                if let skyboxTexture {
                    try SkyboxRenderPipeline(
                        projectionMatrix: projectionMatrix,
                        cameraMatrix: cameraMatrix,
                        rotation: simd_quatf(angle: .pi, axis: [0, 1, 0]),
                        texture: skyboxTexture
                    )
                }

                GridShader(
                    projectionMatrix: projectionMatrix,
                    cameraMatrix: cameraMatrix,
                    highlightedLines: [
                        .init(axis: .x, position: 0, width: 0.03, color: [1, 0.2, 0.2, 1]),
                        .init(axis: .y, position: 0, width: 0.03, color: [0.2, 0.4, 1, 1])
                    ],
                    backfaceColor: [1, 0, 1, 1]
                )

                if let lighting, let firstModel = models.first {
                    try BlinnPhongShader {
                        try ForEach(models) { model in
                            try Draw { encoder in
                                if showWireframe {
                                    encoder.setTriangleFillMode(.lines)
                                }
                                encoder.setVertexBuffers(of: model.mesh)
                                encoder.draw(mesh: model.mesh)
                            }
                            .blinnPhongMaterial(model.material)
                            .blinnPhongMatrices(
                                projectionMatrix: projectionMatrix,
                                viewMatrix: viewMatrix,
                                modelMatrix: model.modelMatrix,
                                cameraMatrix: cameraMatrix
                            )
                        }
                        .lighting(lighting)
                    }
                    .vertexDescriptor(MTLVertexDescriptor(firstModel.mesh.vertexDescriptor))
                    .depthCompare(function: .less, enabled: true)
                }
            }
        }
        .metalDepthStencilPixelFormat(.depth32Float)
        .interactiveCamera(rotation: $cameraRotation, distance: $cameraDistance, target: $cameraTarget)
        .frameTimingOverlay()
        .demoConfiguration {
            Form {
                Toggle("Wireframe", isOn: $showWireframe)
            }
            .formStyle(.grouped)
        }
        .task {
            do {
                let device = _MTLCreateSystemDefaultDevice()

                let tetrahedron = TrivialMesh.tetrahedron().scaled([1.8, 1.8, 1.8])
                let box = TrivialMesh.box()
                let octahedron = TrivialMesh.octahedron().scaled([1.3, 1.3, 1.3])
                let dodecahedron = TrivialMesh.dodecahedron().scaled([1.2, 1.2, 1.2])
                let icosahedron = TrivialMesh.icosahedron().scaled([1.4, 1.4, 1.4])
                let sphere = TrivialMesh.sphere()
                let torus = TrivialMesh.torus()
                let capsule = TrivialMesh.capsule()
                let cone = TrivialMesh.cone()
                let hemisphere = TrivialMesh.hemisphere()
                let icoSphere = TrivialMesh.icoSphere()
                let cubeSphere = TrivialMesh.cubeSphere()

                models = [
                    // Spheres — back row
                    .init(
                        id: "uvSphere",
                        mesh: Mesh(sphere, device: device),
                        modelMatrix: .init(translation: [-2, 1, -4]),
                        material: .init(ambient: .color([0.4, 0.3, 0.3]), diffuse: .color([0.7, 0.5, 0.5]), specular: .color([1, 1, 1]), shininess: 100)
                    ),
                    .init(
                        id: "icoSphere",
                        mesh: Mesh(icoSphere, device: device),
                        modelMatrix: .init(translation: [0, 1, -4]),
                        material: .init(ambient: .color([0.3, 0.4, 0.3]), diffuse: .color([0.5, 0.7, 0.5]), specular: .color([1, 1, 1]), shininess: 100)
                    ),
                    .init(
                        id: "cubeSphere",
                        mesh: Mesh(cubeSphere, device: device),
                        modelMatrix: .init(translation: [2, 1, -4]),
                        material: .init(ambient: .color([0.3, 0.3, 0.4]), diffuse: .color([0.5, 0.5, 0.7]), specular: .color([1, 1, 1]), shininess: 100)
                    ),
                    // Platonic solids — middle-back row
                    .init(
                        id: "tetrahedron",
                        mesh: Mesh(tetrahedron, device: device),
                        modelMatrix: .init(translation: [-4, 1, -2]),
                        material: .init(ambient: .color([0.5, 0.2, 0.2]), diffuse: .color([0.8, 0.2, 0.2]), specular: .color([1, 1, 1]), shininess: 64)
                    ),
                    .init(
                        id: "cube",
                        mesh: Mesh(box, device: device),
                        modelMatrix: .init(translation: [-2, 1, -2]),
                        material: .init(ambient: .color([0.2, 0.2, 0.5]), diffuse: .color([0.2, 0.2, 0.8]), specular: .color([1, 1, 1]), shininess: 32)
                    ),
                    .init(
                        id: "octahedron",
                        mesh: Mesh(octahedron, device: device),
                        modelMatrix: .init(translation: [0, 1, -2]),
                        material: .init(ambient: .color([0.2, 0.5, 0.2]), diffuse: .color([0.2, 0.8, 0.2]), specular: .color([1, 1, 1]), shininess: 128)
                    ),
                    .init(
                        id: "dodecahedron",
                        mesh: Mesh(dodecahedron, device: device),
                        modelMatrix: .init(translation: [2, 1, -2]),
                        material: .init(ambient: .color([0.5, 0.3, 0.5]), diffuse: .color([0.8, 0.4, 0.8]), specular: .color([1, 1, 1]), shininess: 96)
                    ),
                    .init(
                        id: "icosahedron",
                        mesh: Mesh(icosahedron, device: device),
                        modelMatrix: .init(translation: [4, 1, -2]),
                        material: .init(ambient: .color([0.3, 0.4, 0.5]), diffuse: .color([0.4, 0.6, 0.8]), specular: .color([1, 1, 1]), shininess: 80)
                    ),
                    // Curved shapes — middle row
                    .init(
                        id: "torus",
                        mesh: Mesh(torus, device: device),
                        modelMatrix: .init(translation: [-1, 1, 0]),
                        material: .init(ambient: .color([0.3, 0.3, 0.4]), diffuse: .color([0.5, 0.5, 0.7]), specular: .color([1, 1, 1]), shininess: 100)
                    ),
                    .init(
                        id: "capsule",
                        mesh: Mesh(capsule, device: device),
                        modelMatrix: .init(translation: [1, 1, 0]),
                        material: .init(ambient: .color([0.4, 0.4, 0.3]), diffuse: .color([0.7, 0.7, 0.5]), specular: .color([1, 1, 1]), shininess: 100)
                    ),
                    .init(
                        id: "cone",
                        mesh: Mesh(cone, device: device),
                        modelMatrix: .init(translation: [-4, 1, 0]),
                        material: .init(ambient: .color([0.3, 0.4, 0.3]), diffuse: .color([0.5, 0.7, 0.5]), specular: .color([1, 1, 1]), shininess: 100)
                    ),
                    .init(
                        id: "hemisphere",
                        mesh: Mesh(hemisphere, device: device),
                        modelMatrix: .init(translation: [4, 1, 0]),
                        material: .init(ambient: .color([0.4, 0.3, 0.4]), diffuse: .color([0.7, 0.5, 0.7]), specular: .color([1, 1, 1]), shininess: 100)
                    )
                ]

                lighting = try Lighting(
                    ambientLightColor: [0.3, 0.3, 0.3],
                    lights: [
                        ([2, 2, 3], Light(type: .spot, color: [1, 1, 1], intensity: 30))
                    ]
                )

                let crossTexture = try device.makeTexture(name: "Skybox", bundle: .main)
                skyboxTexture = try device.makeTextureCubeFromCrossTexture(texture: crossTexture)
            } catch {
                fatalError("Failed to initialize TrivialMesh demo: \(error)")
            }
        }
    }
}

private struct Model: Identifiable {
    var id: String
    var mesh: MetalSprocketsAddOns.Mesh
    var modelMatrix: float4x4
    var material: BlinnPhongMaterial
}
