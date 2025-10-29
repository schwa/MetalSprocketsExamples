import Metal
import MetalKit
import MetalSprockets
import MetalSprocketsSupport

public struct Quad: Equatable, Sendable {
    public var min: SIMD2<Float>
    public var max: SIMD2<Float>

    public init(min: SIMD2<Float>, max: SIMD2<Float>) {
        self.min = min
        self.max = max
    }
}

public extension Quad {
    var minXMinY: SIMD2<Float> {
        SIMD2<Float>(min.x, min.y)
    }
    var minXMaxY: SIMD2<Float> {
        SIMD2<Float>(min.x, max.y)
    }
    var maxXMinY: SIMD2<Float> {
        SIMD2<Float>(max.x, min.y)
    }
    var maxXMaxY: SIMD2<Float> {
        SIMD2<Float>(max.x, max.y)
    }
}

public extension Quad {
    static let unit = Quad(min: [0, 0], max: [1, 1])

    /// Clip space quad from (-1, -1) to (1, 1)
    static let clip = Quad(min: [-1, -1], max: [1, 1])
}

public struct TextureBillboardPipeline: Element {
    let vertexShader: VertexShader
    let fragmentShader: FragmentShader

    let specifierA: ColorSource
    let specifierB: ColorSource
    let positions: [SIMD2<Float>]
    let textureCoordinates: [SIMD2<Float>]
    let colorTransformGraph: SimpleStitchedFunctionGraph

    // TODO: #138 Get rid of flippedY
    public init(specifierA: ColorSource, specifierB: ColorSource, positions: Quad = .clip, textureCoordinates: Quad = .unit, colorTransform: VisibleFunction? = nil) throws {
        let device = _MTLCreateSystemDefaultDevice()
        #if os(iOS)
        assert(device.supportsFamily(.apple4)) // For argument buffers tier
        #endif
        assert(device.argumentBuffersSupport == .tier2)
        let shaderBundle = Bundle.metalSprocketsAddOnsShaders().orFatalError("Failed to load metal-sprockets example shaders bundle")
        let shaderLibrary = try ShaderLibrary(bundle: shaderBundle, namespace: "TextureBillboard")
        self.vertexShader = try shaderLibrary.vertex_main
        self.fragmentShader = try shaderLibrary.fragment_main

        self.specifierA = specifierA
        self.specifierB = specifierB

        self.positions = [
            positions.minXMinY, // bottom-left
            positions.maxXMinY, // bottom-right
            positions.minXMaxY, // top-left
            positions.maxXMaxY  // top-right
        ]
        self.textureCoordinates = [textureCoordinates.minXMaxY, textureCoordinates.maxXMaxY, textureCoordinates.minXMinY, textureCoordinates.maxXMinY]

        let colorTransform = try colorTransform ?? shaderLibrary.function(named: "colorTransformIdentity", type: VisibleFunction.self)
        colorTransformGraph = try SimpleStitchedFunctionGraph(name: "TextureBillboard::colorTransform", function: colorTransform, inputs: 4)
    }

    public var body: some Element {
        get throws {
            try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                Draw { encoder in
                    encoder.setVertexBytes(positions, length: MemoryLayout<SIMD2<Float>>.stride * positions.count, index: 0)
                    encoder.setVertexBytes(textureCoordinates, length: MemoryLayout<SIMD2<Float>>.stride * textureCoordinates.count, index: 1)
                    encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: positions.count)
                }
                // TODO: We really need an argument buffer abstraction.
                .parameter("specifierA", value: specifierA.toArgumentBuffer())
                .parameter("specifierB", value: specifierB.toArgumentBuffer())
                .parameter("transformColorParameters", value: Int32(0)) // TODO: Placeholder
                .useResource(specifierA.texture2D, usage: .read, stages: .fragment)
                .useResource(specifierA.textureCube, usage: .read, stages: .fragment)
                .useResource(specifierA.depth2D, usage: .read, stages: .fragment)
                .useResource(specifierB.texture2D, usage: .read, stages: .fragment)
                .useResource(specifierB.textureCube, usage: .read, stages: .fragment)
                .useResource(specifierB.depth2D, usage: .read, stages: .fragment)
            }
            .vertexDescriptor(try vertexShader.inferredVertexDescriptor())
            .environment(\.linkedFunctions, colorTransformGraph.linkedFunctions)
        }
    }
}

public extension TextureBillboardPipeline {
    init(specifierA: ColorSource, specifierB: ColorSource, positions: Quad = .clip, textureCoordinates: Quad = .unit, colorTransformFunctionName: String) throws {
        let shaderBundle = Bundle.metalSprocketsAddOnsShaders().orFatalError("Failed to load metal-sprockets example shaders bundle")
        let shaderLibrary = try ShaderLibrary(bundle: shaderBundle, namespace: "TextureBillboard")
        let colorTransform = try shaderLibrary.function(named: colorTransformFunctionName, type: VisibleFunction.self)
        try self.init(specifierA: specifierA, specifierB: specifierB, positions: positions, textureCoordinates: textureCoordinates, colorTransform: colorTransform)
    }

    init(specifierA: ColorSource, specifierB: ColorSource, positions: Quad = .clip, textureCoordinatesArray: [SIMD2<Float>], colorTransformFunctionName: String) throws {
        let device = _MTLCreateSystemDefaultDevice()
        #if os(iOS)
        assert(device.supportsFamily(.apple4))
        #endif
        assert(device.argumentBuffersSupport == .tier2)
        let shaderBundle = Bundle.metalSprocketsAddOnsShaders().orFatalError("Failed to load metal-sprockets example shaders bundle")
        let shaderLibrary = try ShaderLibrary(bundle: shaderBundle, namespace: "TextureBillboard")
        self.vertexShader = try shaderLibrary.vertex_main
        self.fragmentShader = try shaderLibrary.fragment_main
        self.specifierA = specifierA
        self.specifierB = specifierB
        self.positions = [positions.minXMinY, positions.maxXMinY, positions.minXMaxY, positions.maxXMaxY]
        self.textureCoordinates = textureCoordinatesArray
        let colorTransform = try shaderLibrary.function(named: colorTransformFunctionName, type: VisibleFunction.self)
        colorTransformGraph = try SimpleStitchedFunctionGraph(name: "TextureBillboard::colorTransform", function: colorTransform, inputs: 4)
    }

    init(specifier: ColorSource, positions: Quad = .clip, textureCoordinates: Quad = .unit, colorTransform: VisibleFunction? = nil) throws {
        try self.init(specifierA: specifier, specifierB: .color([0, 0, 0]), positions: positions, textureCoordinates: textureCoordinates, colorTransform: colorTransform)
    }
}

// TODO: Move - shared with ColorAdjust
