// Stdlib.swift
// Standard library of built-in primitives for operators and common operations

import Foundation
import Metal
import ShaderGraphShaders

// MARK: - ShaderGraph Stdlib Extension

extension ShaderGraph {
    /// Registers the standard library of arithmetic primitives.
    ///
    /// Call this method to enable arithmetic operators (`+`, `-`, `*`, `/`)
    /// on ``BoundNode`` instances.
    ///
    /// ```swift
    /// let graph = ShaderGraph(device: device)
    /// graph.registerStdlib()
    ///
    /// let a = graph.input("a", type: SIMD4<Float>.self)
    /// let b = graph.input("b", type: SIMD4<Float>.self)
    ///
    /// let result = a * b + a  // Operators now work!
    /// ```
    public func registerStdlib() {
        let bundle = Bundle.shaderGraphShaders()
        guard let libraryURL = bundle.url(forResource: "default", withExtension: "metallib") else {
            fatalError("Could not find default.metallib in ShaderGraphShaders bundle")
        }

        let library: MTLLibrary
        do {
            library = try device.makeLibrary(URL: libraryURL)
        } catch {
            fatalError("Failed to load stdlib metallib: \(error)")
        }

        // Register generated arithmetic ops and swizzles
        registerGeneratedStdlib(library: library)

        // Math functions (not yet generated)
        registerFunction(named: "shadergraph::sin_f", library: library, inputs: [.float], output: .float)
        registerFunction(named: "shadergraph::cos_f", library: library, inputs: [.float], output: .float)
        registerFunction(named: "shadergraph::mix_f", library: library, inputs: [.float, .float, .float], output: .float)
        registerFunction(named: "shadergraph::mix_f4", library: library, inputs: [.float4, .float4, .float], output: .float4)
        registerFunction(named: "shadergraph::fma_f", library: library, inputs: [.float, .float, .float], output: .float)
        registerFunction(named: "shadergraph::fma_f4", library: library, inputs: [.float4, .float4, .float4], output: .float4)
        registerFunction(named: "shadergraph::fma_f4_f", library: library, inputs: [.float4, .float, .float4], output: .float4)

        // Float4 construction
        registerFunction(named: "shadergraph::make_f4", library: library, inputs: [.float, .float, .float, .float], output: .float4)
        registerFunction(named: "shadergraph::make_f4_f2_f_f", library: library, inputs: [.float2, .float, .float], output: .float4)

        // Identity/select functions
        registerFunction(named: "shadergraph::identity_f", library: library, inputs: [.float], output: .float)
        registerFunction(named: "shadergraph::identity_f4", library: library, inputs: [.float4], output: .float4)
        registerFunction(named: "shadergraph::select_f4_f4", library: library, inputs: [.float4, .float4], output: .float4)
        registerFunction(named: "shadergraph::select_f4_f2", library: library, inputs: [.float4, .float2], output: .float4)
        registerFunction(named: "shadergraph::select_f4_f", library: library, inputs: [.float4, .float], output: .float4)
    }
}
