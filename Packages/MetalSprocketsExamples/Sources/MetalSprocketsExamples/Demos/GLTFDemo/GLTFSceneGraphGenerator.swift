#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import GeometryLite3D
import MetalKit
import MetalSprocketsAddOns
import MetalSprocketsExampleShaders
import MetalSprocketsSupport
import MetalSupport
import SwiftGLTF
import SwiftMesh

// swiftlint:disable discouraged_optional_collection

class GLTGSceneGraphGenerator {
    enum Error: Swift.Error {
        case missingRootScene
        case primitiveMissing
        case missingTextureSource
        case imageCreationFailed
        case missingIndicesAccessor
        case unsupportedComponentType
    }
    let container: Container
    let textureLoader: MTKTextureLoader

    init(container: Container) {
        self.container = container
        let device = _MTLCreateSystemDefaultDevice()
        textureLoader = MTKTextureLoader(device: device)
    }

    var document: Document {
        container.document
    }

    func generateSceneGraph() throws -> SceneGraph {
        let sceneGraph = SceneGraph(root: .init())
        let scene: SwiftGLTF.Scene
        if let resolvedScene = try document.scene?.resolve(in: document) {
            scene = resolvedScene
        }
        else if let fallbackScene = document.scenes.first {
            scene = fallbackScene
        }
        else {
            throw Error.missingRootScene
        }
        try scene.nodes
            .map { try $0.resolve(in: document) }
            .map { try generateSceneGraphNode(from: $0) }
            .forEach { node in
                node.parent = sceneGraph.root
                sceneGraph.root.children.append(node)
            }
        return sceneGraph
    }

    func generateSceneGraphNode(from node: Node) throws -> SceneGraph.Node {
        let uvNode = SceneGraph.Node()

        uvNode.transform = transform(for: node)
        uvNode.label = node.name

        if let mesh = try node.mesh?.resolve(in: document) {
            try update(node: uvNode, from: mesh)
        }
        try node.children.map { try $0.resolve(in: document) }.map { try generateSceneGraphNode(from: $0) }.forEach { node in
            node.parent = uvNode
            uvNode.children.append(node)
        }
        return uvNode
    }

    private func transform(for node: Node) -> float4x4 {
        if let matrix = node.matrix {
            return matrix
        }

        let translation = node.translation ?? SIMD3<Float>(repeating: 0)
        let rotationVector = node.rotation ?? SIMD4<Float>(0, 0, 0, 1)
        let scale = node.scale ?? SIMD3<Float>(repeating: 1)

        let translationMatrix = float4x4(translation: translation)
        let rotationQuaternion = simd_quatf(vector: rotationVector)
        let rotationMatrix = float4x4(rotationQuaternion)
        let scaleMatrix = float4x4(scale: scale)

        return translationMatrix * rotationMatrix * scaleMatrix
    }

    func update(node: SceneGraph.Node, from mesh: SwiftGLTF.Mesh) throws {
        guard let primitive = mesh.primitives.first else {
            throw Error.primitiveMissing
        }

        let positions = try primitive.value(semantic: .POSITION, type: SIMD3<Float>.self, in: container) ?? []
        let perVertexNormals = try primitive.value(semantic: .NORMAL, type: SIMD3<Float>.self, in: container)
        let perVertexTangents = try primitive.value(semantic: .TANGENT, type: SIMD4<Float>.self, in: container)
        let perVertexUVs = try primitive.value(semantic: .TEXCOORD_0, type: SIMD2<Float>.self, in: container)
        let indices = try primitive.indices(type: UInt32.self, in: container)

        // Build triangle faces from indices
        var faces: [[Int]] = []
        if let indices {
            assert(primitive.mode == .TRIANGLES)
            let count = indices.count
            faces.reserveCapacity(count / 3)
            var i = 0
            while i < count {
                faces.append([Int(indices[i]), Int(indices[i + 1]), Int(indices[i + 2])])
                i += 3
            }
        } else {
            let count = positions.count
            faces.reserveCapacity(count / 3)
            var i = 0
            while i < count {
                faces.append([i, i + 1, i + 2])
                i += 3
            }
        }

        var swiftMesh = SwiftMesh.Mesh(positions: positions, faces: faces)

        // Map per-vertex attributes to per-corner (half-edge) arrays
        if let perVertexNormals {
            swiftMesh.normals = swiftMesh.topology.halfEdges.map { he in
                perVertexNormals[he.origin.raw]
            }
        }
        if let perVertexUVs {
            swiftMesh.textureCoordinates = swiftMesh.topology.halfEdges.map { he in
                perVertexUVs[he.origin.raw]
            }
        }
        if let perVertexTangents {
            // GLTF tangents are (x, y, z, w)
            swiftMesh.tangents = swiftMesh.topology.halfEdges.map { he in
                perVertexTangents[he.origin.raw].xyz
            }
            if let perVertexNormals {
                swiftMesh.bitangents = swiftMesh.topology.halfEdges.map { he in
                    let normal = perVertexNormals[he.origin.raw]
                    let tangent = perVertexTangents[he.origin.raw]
                    return cross(normal, tangent.xyz) * tangent.w
                }
            }
        }

        // Generate missing attributes
        if swiftMesh.textureCoordinates == nil {
            swiftMesh = swiftMesh.withSphericalUVs()
        }
        if swiftMesh.normals == nil {
            swiftMesh = swiftMesh.withSmoothNormals()
        }
        if swiftMesh.tangents == nil {
            swiftMesh = swiftMesh.withTangents()
        }

        let device = _MTLCreateSystemDefaultDevice()
        node.mesh = MetalMesh(mesh: swiftMesh, device: device)

        if let material = try primitive.material?.resolve(in: document) {
            let uvMaterial = try makeMaterial(from: material)
            node.material = .pbr(uvMaterial)
        }
    }

    func makeMaterial(from material: SwiftGLTF.Material) throws -> PBRMaterialNew {
        var uvMaterial = PBRMaterialNew()
        if let pbrMetallicRoughness = material.pbrMetallicRoughness {
            uvMaterial.albedo = .color(pbrMetallicRoughness.baseColorFactor.xyz)
            uvMaterial.metallic = .color(pbrMetallicRoughness.metallicFactor)
            uvMaterial.roughness = .color(pbrMetallicRoughness.roughnessFactor)
            if let textureInfo = pbrMetallicRoughness.baseColorTexture {
                let mtlTexture = try mtlTexture(for: textureInfo)
                uvMaterial.albedo = .texture2D(mtlTexture.labeled("Albedo"))
            }
            if let textureInfo = pbrMetallicRoughness.metallicRoughnessTexture {
                let mtlTexture = try mtlTexture(for: textureInfo)

                uvMaterial.metallic = .texture2D(mtlTexture.redChannel().labeled("Metallic"))
                uvMaterial.roughness = .texture2D(mtlTexture.greenChannel().labeled("Roughness"))
            }
        }

        return uvMaterial
    }
}

extension GLTGSceneGraphGenerator {
    func mtlTexture(for textureInfo: TextureInfo) throws -> MTLTexture {
        let texture = try textureInfo.index.resolve(in: document)
        guard let textureSourceIndex = texture.source else {
            throw Error.missingTextureSource
        }
        let source = try textureSourceIndex.resolve(in: document)
        let data = try container.data(for: source)
        let image = try CGImage.image(with: data)
        return try textureLoader.newTexture(cgImage: image, options: [:])
    }
}

extension Container {
    func data(for image: Image) throws -> Data {
        if let uri = image.uri {
            return try data(for: uri)
        }
        if let bufferView = try image.bufferView?.resolve(in: document) {
            return try data(for: bufferView)
        }
        throw GLTGSceneGraphGenerator.Error.imageCreationFailed
    }
}

extension CGImage {
    static func image(with data: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw GLTGSceneGraphGenerator.Error.imageCreationFailed
        }
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw GLTGSceneGraphGenerator.Error.imageCreationFailed
        }
        return image
    }
}

extension SwiftGLTF.Mesh.Primitive {
    func value(semantic: SwiftGLTF.Mesh.Primitive.Semantic, type: SIMD2<Float>.Type, in container: Container) throws -> [SIMD2<Float>]? {
        guard let accessor = try attributes[semantic]?.resolve(in: container.document) else {
            return nil
        }
        assert(accessor.componentType == .FLOAT)
        let values = [SIMD2<Float>](withUnsafeData: try container.data(for: accessor))
        assert(values.count == accessor.count)
        if let minValues = accessor.min, let maxValues = accessor.max, minValues.count == maxValues.count {
            assert(values.allSatisfy { value in
                (0..<min(minValues.count, value.scalarCount)).allSatisfy { index in
                    let minimum = Float(minValues[index])
                    let maximum = Float(maxValues[index])
                    return (minimum...maximum).contains(value[index])
                }
            })
        }
        return values
    }

    func value(semantic: SwiftGLTF.Mesh.Primitive.Semantic, type: SIMD3<Float>.Type, in container: Container) throws -> [SIMD3<Float>]? {
        guard let accessor = try attributes[semantic]?.resolve(in: container.document) else {
            return nil
        }
        let values: [SIMD3<Float>]
        switch accessor.componentType {
        case .FLOAT:
            values = [Packed3<Float>](withUnsafeData: try container.data(for: accessor)).map { SIMD3<Float>($0.x, $0.y, $0.z) }
        default:
            throw GLTGSceneGraphGenerator.Error.unsupportedComponentType
        }

        assert(values.count == accessor.count)
        if let minValues = accessor.min, let maxValues = accessor.max, minValues.count == maxValues.count {
            assert(values.allSatisfy { value in
                (0..<min(minValues.count, value.scalarCount)).allSatisfy { index in
                    let minimum = Float(minValues[index])
                    let maximum = Float(maxValues[index])
                    return (minimum...maximum).contains(value[index])
                }
            })
        }
        return values
    }

    func value(semantic: SwiftGLTF.Mesh.Primitive.Semantic, type: SIMD4<Float>.Type, in container: Container) throws -> [SIMD4<Float>]? {
        guard let accessor = try attributes[semantic]?.resolve(in: container.document) else {
            return nil
        }
        assert(accessor.componentType == .FLOAT)
        let values = [SIMD4<Float>](withUnsafeData: try container.data(for: accessor))
        assert(values.count == accessor.count)
        if let minValues = accessor.min, let maxValues = accessor.max, minValues.count == maxValues.count {
            assert(values.allSatisfy { value in
                (0..<min(minValues.count, value.scalarCount)).allSatisfy { index in
                    let minimum = Float(minValues[index])
                    let maximum = Float(maxValues[index])
                    return (minimum...maximum).contains(value[index])
                }
            })
        }
        return values
    }

    func indices(type: UInt32.Type, in container: Container) throws -> [UInt32]? {
        guard let indicesAccessor = try indices?.resolve(in: container.document) else {
            throw GLTGSceneGraphGenerator.Error.missingIndicesAccessor
        }
        switch indicesAccessor.componentType {
        case .UNSIGNED_BYTE:
            let indices = [UInt8](try container.data(for: indicesAccessor))
            if let minValues = indicesAccessor.min, let maxValues = indicesAccessor.max, let minValue = minValues.first, let maxValue = maxValues.first {
                let minByte = UInt8(minValue)
                let maxByte = UInt8(maxValue)
                assert(indices.allSatisfy { (minByte...maxByte).contains($0) })
            }
            assert(indices.count == indicesAccessor.count)
            return indices.map { UInt32($0) }
        case .UNSIGNED_SHORT:
            let indices = [UInt16](withUnsafeData: try container.data(for: indicesAccessor))
            if let minValues = indicesAccessor.min, let maxValues = indicesAccessor.max, let minValue = minValues.first, let maxValue = maxValues.first {
                let minShort = UInt16(minValue)
                let maxShort = UInt16(maxValue)
                assert(indices.allSatisfy { (minShort...maxShort).contains($0) })
            }
            assert(indices.count == indicesAccessor.count)
            return indices.map { UInt32($0) }
        case .UNSIGNED_INT:
            let indices = [UInt32](withUnsafeData: try container.data(for: indicesAccessor))
            if let minValues = indicesAccessor.min, let maxValues = indicesAccessor.max, let minValue = minValues.first, let maxValue = maxValues.first {
                let minInt = UInt32(minValue)
                let maxInt = UInt32(maxValue)
                assert(indices.allSatisfy { (minInt...maxInt).contains($0) })
            }
            assert(indices.count == indicesAccessor.count)
            return indices
        default:
            throw GLTGSceneGraphGenerator.Error.unsupportedComponentType
        }
    }
}

extension Array {
    init(withUnsafeData data: Data) {
        self = data.withUnsafeBytes { buffer in
            let buffer = buffer.bindMemory(to: Element.self)
            return Array(buffer)
        }
    }
}

extension MTLTexture {
    func redChannel() -> MTLTexture {
        let ciImage = CIImage(mtlTexture: self)
            .orFatalError("Failed to create CIImage for red channel")
        let filter = CIFilter.colorMatrix()
        filter.inputImage = ciImage
        filter.rVector = CIVector(x: 1, y: 0, z: 0, w: 0)
        filter.gVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        filter.bVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        filter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)

        let outputImage = filter.outputImage
            .orFatalError("Failed to generate red channel image")
        let device = _MTLCreateSystemDefaultDevice()
        let context = CIContext(mtlDevice: device)
        let outputTextDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: self.width, height: self.height, mipmapped: false)
        outputTextDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        let outputTexture = device.makeTexture(descriptor: outputTextDescriptor)
            .orFatalError("Failed to create red channel texture")

        let commandQueue = device.makeCommandQueue()
            .orFatalError("Failed to create command queue for red channel")
        let commandBuffer = commandQueue.makeCommandBuffer()
            .orFatalError("Failed to create command buffer for red channel")

        let colorSpace = CGColorSpaceCreateDeviceGray()
        context.render(outputImage, to: outputTexture, commandBuffer: commandBuffer, bounds: CGRect(x: 0, y: 0, width: self.width, height: self.height), colorSpace: colorSpace)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        return outputTexture
    }

    func greenChannel() -> MTLTexture {
        let ciImage = CIImage(mtlTexture: self)
            .orFatalError("Failed to create CIImage for green channel")
        let filter = CIFilter.colorMatrix()
        filter.inputImage = ciImage
        filter.rVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        filter.gVector = CIVector(x: 0, y: 1, z: 0, w: 0)
        filter.bVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        filter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)

        let outputImage = filter.outputImage
            .orFatalError("Failed to generate green channel image")
        let device = _MTLCreateSystemDefaultDevice()
        let context = CIContext(mtlDevice: device)
        let outputTextDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: self.width, height: self.height, mipmapped: false)
        outputTextDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        let outputTexture = device.makeTexture(descriptor: outputTextDescriptor)
            .orFatalError("Failed to create green channel texture")

        let commandQueue = device.makeCommandQueue()
            .orFatalError("Failed to create command queue for green channel")
        let commandBuffer = commandQueue.makeCommandBuffer()
            .orFatalError("Failed to create command buffer for green channel")

        let colorSpace = CGColorSpaceCreateDeviceGray()
        context.render(outputImage, to: outputTexture, commandBuffer: commandBuffer, bounds: CGRect(x: 0, y: 0, width: self.width, height: self.height), colorSpace: colorSpace)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        return outputTexture
    }
}
