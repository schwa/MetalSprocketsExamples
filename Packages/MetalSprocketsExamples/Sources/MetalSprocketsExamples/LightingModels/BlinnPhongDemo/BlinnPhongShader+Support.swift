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
}
