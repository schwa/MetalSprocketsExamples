// ShaderGraph+MetalSprockets.swift
// MetalSprockets integration for ShaderGraph

import ExamplesShaderGraph
import Metal
import MetalSprockets

extension ShaderGraph {
    /// Build a stitched visible function from a node.
    ///
    /// This is a convenience method that wraps the resulting `MTLFunction`
    /// in a MetalSprockets `VisibleFunction` for use with `RenderPipeline`.
    ///
    /// - Parameters:
    ///   - name: The name for the stitched function.
    ///   - node: The output node of the shader graph.
    /// - Returns: A `VisibleFunction` ready for use with MetalSprockets.
    public func makeVisibleFunction<T>(_ name: String, node: Node<T>) throws -> VisibleFunction {
        let library = try makeLibrary(name, node: node)
        return try VisibleFunction(ShaderFunction(library: library, name: name, type: .visible))
    }
}
