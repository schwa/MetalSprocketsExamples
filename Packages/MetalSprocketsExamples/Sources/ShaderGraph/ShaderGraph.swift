// ShaderGraph.swift
// Main shader graph type for building stitched Metal functions

import Metal

// MARK: - ShaderGraph

/// A graph that composes `[[stitchable]]` Metal functions at runtime.
///
/// ShaderGraph leverages Metal's function stitching to build optimized shader functions
/// from smaller composable pieces.
///
/// ## Example
///
/// ```swift
/// let graph = ShaderGraph(
///     device: device,
///     inputs: [
///         ("color", .float4),
///         ("uv", .float2),
///         ("time", .float),
///         ("contrastAmount", .float)
///     ],
///     output: .float4
/// )
/// graph.registerStdlib()
///
/// // Access inputs by name
/// let color = graph.input("color", type: SIMD4<Float>.self)
/// let time = graph.input("time", type: Float.self)
///
/// // Build the graph
/// let result = color * sin(time)
///
/// // Create the stitched function
/// let stitchedFunction = try graph.makeFunction("myEffect", node: result)
/// ```
public class ShaderGraph: @unchecked Sendable {
    /// The Metal device used for compilation
    public let device: MTLDevice

    /// The input signature (name, type, index)
    private let inputSignature: [(name: String, type: ValueType, index: Int)]

    /// The output type
    public let outputType: ValueType

    /// Primitive functions from Metal libraries
    private var primitives: [String: MTLFunction] = [:]

    /// Function signatures for primitives
    private var signatures: [String: FunctionSignature] = [:]

    /// Counter for generating unique constant function names
    private var nextConstantIndex: Int = 0

    /// Counter for generating unique flattened function names
    private var nextFlattenIndex: Int = 0

    /// Cache of constant functions by value
    private var floatConstants: [Float: String] = [:]
    private var float4Constants: [SIMD4<Float>: String] = [:]

    /// Cache of original Kind for flattened functions (for inlining)
    private var flattenedKinds: [String: Kind] = [:]

    // MARK: - Internal Accessors for Flatten

    internal func nextFlattenName() -> String {
        let name = "_flatten_\(nextFlattenIndex)"
        nextFlattenIndex += 1
        return name
    }

    internal func storeFlattenedKind(name: String, kind: Kind) {
        flattenedKinds[name] = kind
    }

    internal func getFlattenedKind(name: String) -> Kind? {
        flattenedKinds[name]
    }

    internal func getFloatConstant(name: String) -> Float? {
        floatConstants.first { $0.value == name }?.key
    }

    internal func getFloat4Constant(name: String) -> SIMD4<Float>? {
        float4Constants.first { $0.value == name }?.key
    }

    internal func collectFlattenInputs(kind: Kind, into inputs: inout [(name: String, index: Int, type: ValueType)]) {
        switch kind {
        case let .input(name, index):
            if let sig = inputSignature.first(where: { $0.index == index }) {
                inputs.append((name: name, index: index, type: sig.type))
            }
        case let .function(_, children):
            for child in children {
                collectFlattenInputs(kind: child, into: &inputs)
            }
        }
    }

    /// Creates a shader graph with a defined input/output signature.
    ///
    /// - Parameters:
    ///   - device: The Metal device used for compilation.
    ///   - inputs: The input parameters as (name, type) pairs. Order determines argument index.
    ///   - output: The output type of the stitched function.
    public init(device: MTLDevice, inputs: [(String, ValueType)], output: ValueType) {
        self.device = device
        self.inputSignature = inputs.enumerated().map { index, pair in
            (name: pair.0, type: pair.1, index: index)
        }
        self.outputType = output
    }

    // MARK: - Function Registration

    /// Register a stitchable function from a library with its signature
    public func registerFunction(named name: String, library: MTLLibrary, inputs: [ValueType], output: ValueType) {
        guard let function = library.makeFunction(name: name) else {
            fatalError("Function '\(name)' not found in library")
        }
        if primitives[name] != nil {
            fatalError("Function '\(name)' already registered")
        }
        primitives[name] = function
        signatures[name] = FunctionSignature(inputs: inputs, output: output)
    }

    /// Register a stitchable function from Metal source code
    public func registerFunction(named name: String, source: String, inputs: [ValueType], output: ValueType) {
        // swiftlint:disable:next force_try
        let library = try! device.makeLibrary(source: source, options: nil)
        registerFunction(named: name, library: library, inputs: inputs, output: output)
    }

    // MARK: - Input Access

    /// Access an input by name with type checking.
    public func input<T: ShaderType>(_ name: String, type: T.Type) -> Node<T> {
        guard let input = inputSignature.first(where: { $0.name == name }) else {
            fatalError("No input named '\(name)' in graph signature. Available: \(inputSignature.map(\.name))")
        }
        guard input.type == T.valueType else {
            fatalError("Input '\(name)' has type \(input.type), not \(T.valueType)")
        }
        return Node<T>(graph: self, kind: .input(name: name, index: input.index))
    }

    // MARK: - Constants

    /// Create a float constant node by generating a stitchable function that returns the value
    public func constant(_ value: Float) -> Node<Float> {
        // Reuse existing constant function if we've seen this value before
        if let name = floatConstants[value] {
            return Node<Float>(graph: self, kind: .function(name: name, inputs: []))
        }

        let name = "_const_f_\(nextConstantIndex)"
        nextConstantIndex += 1
        floatConstants[value] = name

        let source = """
        #include <metal_stdlib>
        using namespace metal;
        [[stitchable]] float \(name)() { return \(value); }
        """
        registerFunction(named: name, source: source, inputs: [], output: .float)

        return Node<Float>(graph: self, kind: .function(name: name, inputs: []))
    }

    /// Create a float4 constant node by generating a stitchable function that returns the value
    public func constant(_ value: SIMD4<Float>) -> Node<SIMD4<Float>> {
        // Reuse existing constant function if we've seen this value before
        if let name = float4Constants[value] {
            return Node<SIMD4<Float>>(graph: self, kind: .function(name: name, inputs: []))
        }

        let name = "_const_f4_\(nextConstantIndex)"
        nextConstantIndex += 1
        float4Constants[value] = name

        let source = """
        #include <metal_stdlib>
        using namespace metal;
        [[stitchable]] float4 \(name)() { return float4(\(value.x), \(value.y), \(value.z), \(value.w)); }
        """
        registerFunction(named: name, source: source, inputs: [], output: .float4)

        return Node<SIMD4<Float>>(graph: self, kind: .function(name: name, inputs: []))
    }

    // MARK: - Function References

    /// Get a typed function reference for calling registered primitives
    public func function<each Input: ShaderType, Output: ShaderType>(
        _ name: String,
        inputs: (repeat (each Input).Type),
        output: Output.Type
    ) -> GraphFunction<repeat each Input, Output> {
        GraphFunction(graph: self, name: name)
    }

    // MARK: - Internal

    /// Create a function node that calls a primitive
    internal func makeNode<T: ShaderType>(_ name: String, inputs: [Kind], outputType: ValueType) -> Node<T> {
        guard primitives[name] != nil else {
            fatalError("Unknown primitive '\(name)'")
        }
        return Node<T>(graph: self, kind: .function(name: name, inputs: inputs))
    }

    // MARK: - Stitched Function Creation

    /// Optimize a node's graph (e.g., fuse mul+add into fma)
    public func optimized<T>(_ node: Node<T>) -> Node<T> {
        Node<T>(graph: self, kind: optimize(kind: node.kind))
    }

    /// Build a stitched MTLFunction from a node
    public func makeFunction<T>(_ name: String, node: Node<T>) throws -> MTLFunction {
        // Validate all functions in the graph exist
        try validateGraph(kind: node.kind)

        // Optimize the graph (e.g., fuse mul+add into fma)
        let optimizedKind = optimize(kind: node.kind)

        // Wrap output to ensure all signature inputs are included
        let wrappedKind = wrapUnusedInputs(output: optimizedKind)

        // Collect all primitive functions used in the graph
        var functions: [MTLFunction] = []
        collectFunctions(kind: wrappedKind, into: &functions)

        // Build stitching nodes
        let (outputStitchNode, functionNodes) = makeStitchingNode(for: wrappedKind)

        guard let outputFunctionNode = outputStitchNode as? MTLFunctionStitchingFunctionNode else {
            throw ShaderGraphError.stitchingFailed(name: name, reason: "Output must be a function node")
        }

        // Create the stitching graph
        let stitchingGraph = MTLFunctionStitchingGraph(
            functionName: name,
            nodes: functionNodes,
            outputNode: outputFunctionNode,
            attributes: []
        )

        // Create stitched library
        let descriptor = MTLStitchedLibraryDescriptor()
        descriptor.functions = functions
        descriptor.functionGraphs = [stitchingGraph]

        let library = try device.makeLibrary(stitchedDescriptor: descriptor)

        guard let function = library.makeFunction(name: name) else {
            throw ShaderGraphError.stitchingFailed(name: name, reason: "Function not found in stitched library")
        }

        // Validate input indices after wrapping
        try validateInputIndices(kind: wrappedKind, name: name)

        return function
    }

    /// Validate that all functions referenced in the graph are registered
    private func validateGraph(kind: Kind) throws {
        switch kind {
        case .input:
            break
        case let .function(name, inputs):
            if primitives[name] == nil {
                throw ShaderGraphError.unknownFunction(name: name)
            }
            for input in inputs {
                try validateGraph(kind: input)
            }
        }
    }

    /// Validate that the graph uses the expected input indices
    private func validateInputIndices(kind: Kind, name: String) throws {
        // After wrapping, all inputs should be used
        // Verify no out-of-range indices
        var usedIndices = Set<Int>()
        collectUsedInputIndices(kind: kind, into: &usedIndices)

        let maxValidIndex = inputSignature.count - 1
        for index in usedIndices {
            if index < 0 || index > maxValidIndex {
                throw ShaderGraphError.signatureMismatch(
                    expected: inputSignature.count,
                    actual: index + 1,
                    functionName: name
                )
            }
        }
    }

    private func collectFunctions(kind: Kind, into functions: inout [MTLFunction]) {
        switch kind {
        case .input:
            break
        case let .function(name, inputs):
            // Safe to force unwrap - we validated in validateGraph
            if let primitive = primitives[name], !functions.contains(where: { $0 === primitive }) {
                functions.append(primitive)
            }
            for input in inputs {
                collectFunctions(kind: input, into: &functions)
            }
        }
    }

    private func makeStitchingNode(for kind: Kind) -> (MTLFunctionStitchingNode, [MTLFunctionStitchingFunctionNode]) {
        switch kind {
        case let .input(_, index):
            let stitchNode = MTLFunctionStitchingInputNode(argumentIndex: index)
            return (stitchNode, [])

        case let .function(name, inputs):
            var allFunctionNodes: [MTLFunctionStitchingFunctionNode] = []
            var inputStitchNodes: [MTLFunctionStitchingNode] = []

            for input in inputs {
                let (stitchNode, childFuncNodes) = makeStitchingNode(for: input)
                inputStitchNodes.append(stitchNode)
                allFunctionNodes.append(contentsOf: childFuncNodes)
            }

            let stitchNode = MTLFunctionStitchingFunctionNode(
                name: name,
                arguments: inputStitchNodes,
                controlDependencies: []
            )
            allFunctionNodes.append(stitchNode)

            return (stitchNode, allFunctionNodes)
        }
    }

    // MARK: - Graph Optimization

    /// Optimize the graph by fusing operations where possible
    private func optimize(kind: Kind) -> Kind {
        switch kind {
        case .input:
            return kind

        case let .function(name, inputs):
            // First optimize children
            let optimizedInputs = inputs.map { optimize(kind: $0) }

            // Look for add(mul(a, b), c) -> fma(a, b, c)
            if name == "shadergraph::add_f_f", optimizedInputs.count == 2 {
                if case let .function(mulName, mulInputs) = optimizedInputs[0],
                    mulName == "shadergraph::mul_f_f", mulInputs.count == 2 {
                    // add(mul(a, b), c) -> fma(a, b, c)
                    return .function(name: "shadergraph::fma_f", inputs: [mulInputs[0], mulInputs[1], optimizedInputs[1]])
                }
                if case let .function(mulName, mulInputs) = optimizedInputs[1],
                    mulName == "shadergraph::mul_f_f", mulInputs.count == 2 {
                    // add(c, mul(a, b)) -> fma(a, b, c)
                    return .function(name: "shadergraph::fma_f", inputs: [mulInputs[0], mulInputs[1], optimizedInputs[0]])
                }
            }

            // Look for add(mul(a, b), c) for float4 -> fma(a, b, c)
            if name == "shadergraph::add_f4_f4", optimizedInputs.count == 2 {
                if case let .function(mulName, mulInputs) = optimizedInputs[0],
                    mulName == "shadergraph::mul_f4_f4", mulInputs.count == 2 {
                    return .function(name: "shadergraph::fma_f4", inputs: [mulInputs[0], mulInputs[1], optimizedInputs[1]])
                }
                if case let .function(mulName, mulInputs) = optimizedInputs[1],
                    mulName == "shadergraph::mul_f4_f4", mulInputs.count == 2 {
                    return .function(name: "shadergraph::fma_f4", inputs: [mulInputs[0], mulInputs[1], optimizedInputs[0]])
                }
            }

            return .function(name: name, inputs: optimizedInputs)
        }
    }

    /// Find which input indices are actually used in the graph
    private func collectUsedInputIndices(kind: Kind, into indices: inout Set<Int>) {
        switch kind {
        case let .input(_, index):
            indices.insert(index)
        case let .function(_, inputs):
            for input in inputs {
                collectUsedInputIndices(kind: input, into: &indices)
            }
        }
    }

    /// Wrap the output node to ensure all signature inputs are part of the stitched function
    private func wrapUnusedInputs(output: Kind) -> Kind {
        // Find which inputs are used
        var usedIndices = Set<Int>()
        collectUsedInputIndices(kind: output, into: &usedIndices)

        // Find unused signature inputs
        let unusedInputs = inputSignature.filter { !usedIndices.contains($0.index) }

        if unusedInputs.isEmpty {
            return output
        }

        // Chain select functions to consume unused inputs while preserving the output
        var currentOutput = output
        for unused in unusedInputs {
            let inputKind: Kind = .input(name: unused.name, index: unused.index)
            let selectName: String
            switch unused.type {
            case .float:
                selectName = "shadergraph::select_f4_f"
            case .float2:
                selectName = "shadergraph::select_f4_f2"
            case .float4:
                selectName = "shadergraph::select_f4_f4"
            default:
                fatalError("Unsupported input type for unused input: \(unused.type)")
            }
            currentOutput = .function(name: selectName, inputs: [currentOutput, inputKind])
        }

        return currentOutput
    }
}
