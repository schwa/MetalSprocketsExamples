import Metal
import MetalSprockets
import MetalSprocketsSupport

public struct SimpleStitchedFunctionGraph {
    public var stitchedFunctions: [MTLFunction]

    public init(name: String, function: VisibleFunction, inputs: Int) throws {
        let function = function.function
        let device = _MTLCreateSystemDefaultDevice()
        let inputs = (0..<inputs).map { MTLFunctionStitchingInputNode(argumentIndex: $0) }
        let node = MTLFunctionStitchingFunctionNode(name: function.name, arguments: inputs, controlDependencies: [])
        let graph = MTLFunctionStitchingGraph(functionName: name, nodes: [node], outputNode: node, attributes: [])
        let stitchedLibraryDescriptor = MTLStitchedLibraryDescriptor(functions: [function], functionGraphs: [graph])
        let stitchedLibrary = try device.makeLibrary(stitchedDescriptor: stitchedLibraryDescriptor)
        stitchedFunctions = [
            try stitchedLibrary.makeFunction(name: name).orThrow(.resourceCreationFailure("Failed to create stitched function"))
        ]
    }

    public var linkedFunctions: MTLLinkedFunctions {
        MTLLinkedFunctions(functions: stitchedFunctions)
    }
}

private extension MTLStitchedLibraryDescriptor {
    convenience init(functions: [MTLFunction], functionGraphs: [MTLFunctionStitchingGraph]) {
        self.init()
        self.functions = functions
        self.functionGraphs = functionGraphs
    }
}

private extension MTLLinkedFunctions {
    convenience init(functions: [MTLFunction]) {
        self.init()
        self.functions = functions
    }
}
