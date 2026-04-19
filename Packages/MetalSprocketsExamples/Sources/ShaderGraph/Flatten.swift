// Flatten.swift
// Collapse subgraphs into single generated Metal functions

import Metal

extension ShaderGraph {
    // MARK: - Flatten

    /// Flatten a node's subgraph into a single generated Metal function.
    ///
    /// This collapses an entire expression tree into one compiled function,
    /// reducing the number of stitched function calls at runtime.
    ///
    /// ```swift
    /// let plasma = sin(uv.x * 10.0 + time) + sin(uv.y * 10.0 + time * 1.5)
    /// let plasmaFlat = graph.flatten(plasma)  // One function instead of many
    /// ```
    ///
    /// - Parameter node: The node whose subgraph should be flattened.
    /// - Returns: A new node that calls the generated function.
    public func flatten<T: ShaderType>(_ node: Node<T>) -> Node<T> {
        // Collect all inputs used in this subgraph
        var inputsUsed: [(name: String, index: Int, type: ValueType)] = []
        collectFlattenInputs(kind: node.kind, into: &inputsUsed)

        // Deduplicate and sort by index
        var seenIndices = Set<Int>()
        inputsUsed = inputsUsed.filter { seenIndices.insert($0.index).inserted }
        inputsUsed.sort { $0.index < $1.index }

        // Generate Metal source
        let funcName = nextFlattenName()

        let outputType = T.valueType
        let params = inputsUsed.map { "\($0.type.metalTypeName) in\($0.index)" }.joined(separator: ", ")
        let body = emitMetalExpression(kind: node.kind)

        let source = """
        #include <metal_stdlib>
        using namespace metal;
        [[stitchable]] \(outputType.metalTypeName) \(funcName)(\(params)) {
            return \(body);
        }
        """

        #if DEBUG
        print("=== Flattened function \(funcName) ===")
        print(source)
        #endif

        // Compile and register
        let inputTypes = inputsUsed.map(\.type)
        registerFunction(named: funcName, source: source, inputs: inputTypes, output: outputType)

        // Cache the original kind for inlining in nested flattens
        storeFlattenedKind(name: funcName, kind: node.kind)

        // Build the new node that calls the flattened function with the inputs
        let inputKinds = inputsUsed.map { Kind.input(name: $0.name, index: $0.index) }
        return Node<T>(graph: self, kind: .function(name: funcName, inputs: inputKinds))
    }

    /// Emit a Metal expression string for a Kind tree
    internal func emitMetalExpression(kind: Kind) -> String {
        switch kind {
        case .input(_, let index):
            return "in\(index)"

        case .function(let name, let inputs):
            // If this is a previously flattened function, inline its original expression
            if let originalKind = getFlattenedKind(name: name) {
                return emitMetalExpression(kind: originalKind)
            }

            let args = inputs.map { emitMetalExpression(kind: $0) }

            // Map function names to Metal expressions
            return mapToMetalExpression(name: name, args: args)
        }
    }

    /// Map a registered function name to a Metal expression
    private func mapToMetalExpression(name: String, args: [String]) -> String {
        // Handle constants (generated functions that return a value)
        if name.hasPrefix("_const_f_") {
            if let value = getFloatConstant(name: name) {
                return "\(value)"
            }
        }
        if name.hasPrefix("_const_f4_") {
            if let value = getFloat4Constant(name: name) {
                return "float4(\(value.x), \(value.y), \(value.z), \(value.w))"
            }
        }

        // Handle stdlib functions
        let baseName = name.replacingOccurrences(of: "shadergraph::", with: "")

        // Binary operators
        if baseName.hasPrefix("add_") { return "(\(args[0]) + \(args[1]))" }
        if baseName.hasPrefix("sub_") { return "(\(args[0]) - \(args[1]))" }
        if baseName.hasPrefix("mul_") { return "(\(args[0]) * \(args[1]))" }
        if baseName.hasPrefix("div_") { return "(\(args[0]) / \(args[1]))" }

        // Math functions
        if baseName == "sin_f" { return "sin(\(args[0]))" }
        if baseName == "cos_f" { return "cos(\(args[0]))" }
        if baseName == "mix_f" || baseName == "mix_f4" { return "mix(\(args[0]), \(args[1]), \(args[2]))" }
        if baseName.hasPrefix("fma_") { return "fma(\(args[0]), \(args[1]), \(args[2]))" }

        // Swizzles
        if baseName.hasPrefix("swizzle_x") { return "(\(args[0])).x" }
        if baseName.hasPrefix("swizzle_y") { return "(\(args[0])).y" }
        if baseName.hasPrefix("swizzle_z") { return "(\(args[0])).z" }
        if baseName.hasPrefix("swizzle_w") { return "(\(args[0])).w" }

        // Construction
        if baseName == "make_f4" { return "float4(\(args.joined(separator: ", ")))" }
        if baseName == "make_f4_f2_f_f" { return "float4(\(args[0]), \(args[1]), \(args[2]))" }

        // Identity/select (these shouldn't appear in flattened code normally)
        if baseName.hasPrefix("identity_") { return args[0] }
        if baseName.hasPrefix("select_") { return args[0] }  // Return the first arg (the actual value)

        // Fallback: call as function (shouldn't happen for stdlib)
        return "\(baseName)(\(args.joined(separator: ", ")))"
    }
}
