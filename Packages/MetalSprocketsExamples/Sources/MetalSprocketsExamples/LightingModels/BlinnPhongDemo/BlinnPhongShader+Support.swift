import Metal
import MetalSprockets
import MetalSprocketsAddOns
import MetalSprocketsAddOnsShaders
import MetalSprocketsExampleShaders
import MetalSprocketsSupport

struct BlinnPhongMaterial {
    var ambient: ColorSource
    var diffuse: ColorSource
    var specular: ColorSource
    var shininess: Float
}

extension BlinnPhongMaterial {
    func toArgumentBuffer() throws -> BlinnPhongMaterialArgumentBuffer {
        var result = BlinnPhongMaterialArgumentBuffer()
        result.ambient = ambient.toArgumentBuffer()
        result.diffuse = diffuse.toArgumentBuffer()
        result.specular = specular.toArgumentBuffer()
        result.shininess = shininess
        return result
    }
}

extension Element {
    func blinnPhongMaterial(_ material: BlinnPhongMaterial) throws -> some Element {
        self
            .parameter("material", value: try material.toArgumentBuffer())
            // TODO: We have to expand this
            .useResource(material.ambient.texture2D, usage: .read, stages: .fragment)
            .useResource(material.diffuse.texture2D, usage: .read, stages: .fragment)
            .useResource(material.specular.texture2D, usage: .read, stages: .fragment)
    }

    func blinnPhongMatrices(projectionMatrix: simd_float4x4, viewMatrix: simd_float4x4, modelMatrix: simd_float4x4, cameraMatrix: simd_float4x4) -> some Element {
        // Pre-compute matrix products on CPU to avoid per-vertex computation
        let modelViewMatrix = viewMatrix * modelMatrix
        let modelViewProjectionMatrix = projectionMatrix * modelViewMatrix

        return self
            .parameter("modelViewMatrix", functionType: .vertex, value: modelViewMatrix)
            .parameter("modelViewProjectionMatrix", functionType: .vertex, value: modelViewProjectionMatrix)
            .parameter("modelMatrix", functionType: .vertex, value: modelMatrix)
            .parameter("cameraMatrix", functionType: .fragment, value: cameraMatrix)
    }
}
