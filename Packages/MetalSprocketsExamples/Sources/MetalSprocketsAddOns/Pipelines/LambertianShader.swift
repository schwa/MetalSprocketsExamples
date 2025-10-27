import CoreGraphics
import MetalSprockets
import simd

public struct LambertianShader <Content>: Element where Content: Element {
    var projectionMatrix: float4x4
    var cameraMatrix: float4x4
    var modelMatrix: float4x4
    var color: SIMD3<Float>
    var vertexShader: VertexShader
    var fragmentShader: FragmentShader
    var lightDirection: SIMD3<Float>
    var content: Content

    public init(projectionMatrix: float4x4, cameraMatrix: float4x4, modelMatrix: float4x4, color: SIMD3<Float>, lightDirection: SIMD3<Float>, content: () -> Content) throws {
        self.projectionMatrix = projectionMatrix
        self.cameraMatrix = cameraMatrix
        self.modelMatrix = modelMatrix
        self.color = color

        let library = try ShaderLibrary(bundle: .metalSprocketsAddOnsShaders(), namespace: "LambertianShader")
        self.vertexShader = try library.vertex_main
        self.fragmentShader = try library.fragment_main

        self.lightDirection = lightDirection
        self.content = content()
    }

    public var body: some Element {
        get throws {
            try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                content
                    .parameter("color", value: color)
                    .parameter("projectionMatrix", value: projectionMatrix)
                    .parameter("viewMatrix", value: cameraMatrix.inverse)
                    .parameter("cameraPosition", value: cameraMatrix.translation)
                    .parameter("modelMatrix", value: modelMatrix)
                    .parameter("lightDirection", value: lightDirection)
            }
        }
    }
}

public struct LambertianShaderInstanced <Content>: Element where Content: Element {
    var projectionMatrix: float4x4
    var cameraMatrix: float4x4
    var colors: [SIMD3<Float>]
    var modelMatrices: [simd_float4x4]
    var vertexShader: VertexShader
    var fragmentShader: FragmentShader
    var lightDirection: SIMD3<Float>
    var content: Content

    public init(projectionMatrix: float4x4, cameraMatrix: float4x4, colors: [SIMD3<Float>], modelMatrices: [simd_float4x4], lightDirection: SIMD3<Float>, @ElementBuilder content: () -> Content) throws {
        self.projectionMatrix = projectionMatrix
        self.cameraMatrix = cameraMatrix
        self.colors = colors
        self.modelMatrices = modelMatrices
        self.lightDirection = lightDirection

        let library = try ShaderLibrary(bundle: .metalSprocketsAddOnsShaders(), namespace: "LambertianShader")
        self.vertexShader = try library.vertex_instanced
        self.fragmentShader = try library.fragment_main
        self.content = content()
    }

    public var body: some Element {
        get throws {
            try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                content
                    .parameter("colors", values: colors)
                    .parameter("projectionMatrix", value: projectionMatrix)
                    .parameter("modelMatrices", values: modelMatrices)
                    .parameter("viewMatrix", value: cameraMatrix.inverse)
                    .parameter("lightDirection", value: lightDirection)
                    .parameter("cameraPosition", value: cameraMatrix.translation)
            }
        }
    }
}
