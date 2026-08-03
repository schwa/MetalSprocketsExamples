// Node.swift
// Node type for shader graphs

import Metal

// MARK: - Node

/// A node in a shader graph with compile-time type information.
///
/// Nodes represent either inputs to the graph or function calls.
/// The graph is built by connecting nodes together via operators
/// and functions, then compiled into a stitched Metal function.
///
/// You don't create `Node` instances directly. Instead, use
/// ``ShaderGraph/input(_:type:)`` or arithmetic operators.
///
/// ```swift
/// let color: Node<SIMD4<Float>> = graph.input("color", type: SIMD4<Float>.self)
/// let time: Node<Float> = graph.input("time", type: Float.self)
///
/// // Type-safe operations
/// let result = color * sin(time)
/// ```
public struct Node<T: ShaderType>: Sendable {
    /// The graph this node belongs to.
    public let graph: ShaderGraph

    /// The kind of node (input or function call).
    public let kind: Kind
}

// MARK: - Kind

/// The different kinds of nodes in a shader graph.
public enum Kind: Sendable {
    /// An input argument to the stitched function.
    case input(name: String, index: Int)

    /// A call to a registered stitchable function.
    case function(name: String, inputs: [Self])
}
