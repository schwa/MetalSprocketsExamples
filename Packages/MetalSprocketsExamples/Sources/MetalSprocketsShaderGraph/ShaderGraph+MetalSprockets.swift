// ShaderGraph+MetalSprockets.swift
// MetalSprockets integration for ShaderGraph

import Metal
import MetalSprockets
import ShaderGraph

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
        let function = try makeFunction(name, node: node)
        return VisibleFunction(function)
    }
}
