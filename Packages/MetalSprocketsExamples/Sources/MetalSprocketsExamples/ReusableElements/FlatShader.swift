import CoreGraphics
import GeometryLite3D
import Metal
import MetalKit
import simd
import MetalSprockets
import MetalSprocketsExampleShaders
import MetalSprocketsSupport

struct FlatShader <Content>: Element where Content: Element {
    var content: Content

    @MSState
    var vertexShader: VertexShader

    @MSState
    var fragmentShader: FragmentShader

    var textureSpecifier: ColorSource

    // TODO: Remove texture specifier and use a parameter/element extension [FILE ME]
    init(textureSpecifier: ColorSource, @ElementBuilder content: () throws -> Content) throws {
        self.textureSpecifier = textureSpecifier
        self.content = try content()
        let shaderBundle = Bundle.metal-sprocketsExampleShaders().orFatalError("Failed to load metal-sprockets example shaders bundle")
        let shaderLibrary = try ShaderLibrary(bundle: shaderBundle, namespace: "FlatShader")
        self.vertexShader = try shaderLibrary.vertex_main
        self.fragmentShader = try shaderLibrary.fragment_main
    }

    var body: some Element {
        get throws {
            let textureSpecifierArgumentBuffer = textureSpecifier.toArgumentBuffer()

            try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                content
                    .parameter("specifier", value: textureSpecifierArgumentBuffer)
                    .useResource(textureSpecifier.texture2D, usage: .read, stages: .fragment)
                    .useResource(textureSpecifier.textureCube, usage: .read, stages: .fragment)
                    .useResource(textureSpecifier.depth2D, usage: .read, stages: .fragment)
            }
        }
    }
}
