// Operators.swift
// Arithmetic operators and swizzle properties for Node types

import simd

// MARK: - ScalarValue Protocol

/// A protocol that allows both `Float` and `Node<Float>` in generic contexts.
public protocol ScalarValue: Sendable {
    func asNode(graph: ShaderGraph) -> Node<Float>
}

extension Float: ScalarValue {
    public func asNode(graph: ShaderGraph) -> Node<Float> {
        graph.constant(self)
    }
}

extension Double: ScalarValue {
    public func asNode(graph: ShaderGraph) -> Node<Float> {
        graph.constant(Float(self))
    }
}

extension Node: ScalarValue where T == Float {
    public func asNode(graph: ShaderGraph) -> Node<Float> {
        self
    }
}

// MARK: - Float4 Operators

/// Multiplies two float4 nodes.
public func * (lhs: Node<SIMD4<Float>>, rhs: Node<SIMD4<Float>>) -> Node<SIMD4<Float>> {
    let op = lhs.graph.function("shadergraph::mul_f4_f4", inputs: (SIMD4<Float>.self, SIMD4<Float>.self), output: SIMD4<Float>.self)
    return op(lhs, rhs)
}

/// Adds two float4 nodes.
public func + (lhs: Node<SIMD4<Float>>, rhs: Node<SIMD4<Float>>) -> Node<SIMD4<Float>> {
    let op = lhs.graph.function("shadergraph::add_f4_f4", inputs: (SIMD4<Float>.self, SIMD4<Float>.self), output: SIMD4<Float>.self)
    return op(lhs, rhs)
}

/// Subtracts two float4 nodes.
public func - (lhs: Node<SIMD4<Float>>, rhs: Node<SIMD4<Float>>) -> Node<SIMD4<Float>> {
    let op = lhs.graph.function("shadergraph::sub_f4_f4", inputs: (SIMD4<Float>.self, SIMD4<Float>.self), output: SIMD4<Float>.self)
    return op(lhs, rhs)
}

/// Divides two float4 nodes.
public func / (lhs: Node<SIMD4<Float>>, rhs: Node<SIMD4<Float>>) -> Node<SIMD4<Float>> {
    let op = lhs.graph.function("shadergraph::div_f4_f4", inputs: (SIMD4<Float>.self, SIMD4<Float>.self), output: SIMD4<Float>.self)
    return op(lhs, rhs)
}

// Float4 with scalar Node

/// Multiplies a float4 node by a scalar node.
public func * (lhs: Node<SIMD4<Float>>, rhs: Node<Float>) -> Node<SIMD4<Float>> {
    let op = lhs.graph.function("shadergraph::mul_f4_f", inputs: (SIMD4<Float>.self, Float.self), output: SIMD4<Float>.self)
    return op(lhs, rhs)
}

/// Adds a scalar node to a float4 node.
public func + (lhs: Node<SIMD4<Float>>, rhs: Node<Float>) -> Node<SIMD4<Float>> {
    let op = lhs.graph.function("shadergraph::add_f4_f", inputs: (SIMD4<Float>.self, Float.self), output: SIMD4<Float>.self)
    return op(lhs, rhs)
}

/// Subtracts a scalar node from a float4 node.
public func - (lhs: Node<SIMD4<Float>>, rhs: Node<Float>) -> Node<SIMD4<Float>> {
    let op = lhs.graph.function("shadergraph::sub_f4_f", inputs: (SIMD4<Float>.self, Float.self), output: SIMD4<Float>.self)
    return op(lhs, rhs)
}

/// Divides a float4 node by a scalar node.
public func / (lhs: Node<SIMD4<Float>>, rhs: Node<Float>) -> Node<SIMD4<Float>> {
    let op = lhs.graph.function("shadergraph::div_f4_f", inputs: (SIMD4<Float>.self, Float.self), output: SIMD4<Float>.self)
    return op(lhs, rhs)
}

// Float4 with scalar literal

/// Multiplies a float4 node by a scalar, splatting the scalar to float4.
public func * (lhs: Node<SIMD4<Float>>, rhs: Float) -> Node<SIMD4<Float>> {
    let constant = lhs.graph.constant(rhs)
    return lhs * constant
}

/// Adds a scalar to a float4 node, splatting the scalar to float4.
public func + (lhs: Node<SIMD4<Float>>, rhs: Float) -> Node<SIMD4<Float>> {
    let constant = lhs.graph.constant(rhs)
    return lhs + constant
}

/// Subtracts a scalar from a float4 node, splatting the scalar to float4.
public func - (lhs: Node<SIMD4<Float>>, rhs: Float) -> Node<SIMD4<Float>> {
    let constant = lhs.graph.constant(rhs)
    return lhs - constant
}

/// Divides a float4 node by a scalar, splatting the scalar to float4.
public func / (lhs: Node<SIMD4<Float>>, rhs: Float) -> Node<SIMD4<Float>> {
    let constant = lhs.graph.constant(rhs)
    return lhs / constant
}

// Float4 with scalar literal on LHS

/// Multiplies a literal by a float4 node, splatting the scalar.
public func * (lhs: Float, rhs: Node<SIMD4<Float>>) -> Node<SIMD4<Float>> {
    rhs * lhs
}

/// Adds a literal to a float4 node, splatting the scalar.
public func + (lhs: Float, rhs: Node<SIMD4<Float>>) -> Node<SIMD4<Float>> {
    rhs + lhs
}

/// Subtracts a float4 node from a literal, splatting the scalar.
public func - (lhs: Float, rhs: Node<SIMD4<Float>>) -> Node<SIMD4<Float>> {
    let constant = rhs.graph.constant(SIMD4<Float>(repeating: lhs))
    return constant - rhs
}

/// Divides a literal by a float4 node, splatting the scalar.
public func / (lhs: Float, rhs: Node<SIMD4<Float>>) -> Node<SIMD4<Float>> {
    let constant = rhs.graph.constant(SIMD4<Float>(repeating: lhs))
    return constant / rhs
}

// MARK: - Float Operators

/// Multiplies two float nodes.
public func * (lhs: Node<Float>, rhs: Node<Float>) -> Node<Float> {
    let op = lhs.graph.function("shadergraph::mul_f_f", inputs: (Float.self, Float.self), output: Float.self)
    return op(lhs, rhs)
}

/// Adds two float nodes.
public func + (lhs: Node<Float>, rhs: Node<Float>) -> Node<Float> {
    let op = lhs.graph.function("shadergraph::add_f_f", inputs: (Float.self, Float.self), output: Float.self)
    return op(lhs, rhs)
}

/// Subtracts two float nodes.
public func - (lhs: Node<Float>, rhs: Node<Float>) -> Node<Float> {
    let op = lhs.graph.function("shadergraph::sub_f_f", inputs: (Float.self, Float.self), output: Float.self)
    return op(lhs, rhs)
}

/// Divides two float nodes.
public func / (lhs: Node<Float>, rhs: Node<Float>) -> Node<Float> {
    let op = lhs.graph.function("shadergraph::div_f_f", inputs: (Float.self, Float.self), output: Float.self)
    return op(lhs, rhs)
}

// Float with literal

/// Multiplies a float node by a literal.
public func * (lhs: Node<Float>, rhs: Float) -> Node<Float> {
    let constant = lhs.graph.constant(rhs)
    return lhs * constant
}

/// Adds a literal to a float node.
public func + (lhs: Node<Float>, rhs: Float) -> Node<Float> {
    let constant = lhs.graph.constant(rhs)
    return lhs + constant
}

/// Subtracts a literal from a float node.
public func - (lhs: Node<Float>, rhs: Float) -> Node<Float> {
    let constant = lhs.graph.constant(rhs)
    return lhs - constant
}

/// Divides a float node by a literal.
public func / (lhs: Node<Float>, rhs: Float) -> Node<Float> {
    let constant = lhs.graph.constant(rhs)
    return lhs / constant
}

// Float with literal on LHS

/// Multiplies a literal by a float node.
public func * (lhs: Float, rhs: Node<Float>) -> Node<Float> {
    rhs * lhs
}

/// Adds a float node to a literal.
public func + (lhs: Float, rhs: Node<Float>) -> Node<Float> {
    rhs + lhs
}

/// Subtracts a float node from a literal.
public func - (lhs: Float, rhs: Node<Float>) -> Node<Float> {
    let constant = rhs.graph.constant(lhs)
    return constant - rhs
}

/// Divides a literal by a float node.
public func / (lhs: Float, rhs: Node<Float>) -> Node<Float> {
    let constant = rhs.graph.constant(lhs)
    return constant / rhs
}

// MARK: - Float4 Swizzle Properties

public extension Node where T == SIMD4<Float> {
    /// Extracts the x component.
    var x: Node<Float> {
        let op = graph.function("shadergraph::swizzle_x_f4", inputs: (SIMD4<Float>.self, ), output: Float.self)
        return op(self)
    }

    /// Extracts the y component.
    var y: Node<Float> {
        let op = graph.function("shadergraph::swizzle_y_f4", inputs: (SIMD4<Float>.self, ), output: Float.self)
        return op(self)
    }

    /// Extracts the z component.
    var z: Node<Float> {
        let op = graph.function("shadergraph::swizzle_z_f4", inputs: (SIMD4<Float>.self, ), output: Float.self)
        return op(self)
    }

    /// Extracts the w component.
    var w: Node<Float> {
        let op = graph.function("shadergraph::swizzle_w_f4", inputs: (SIMD4<Float>.self, ), output: Float.self)
        return op(self)
    }

    /// Alias for x (red channel).
    var r: Node<Float> { x }

    /// Alias for y (green channel).
    var g: Node<Float> { y }

    /// Alias for z (blue channel).
    var b: Node<Float> { z }

    /// Alias for w (alpha channel).
    var a: Node<Float> { w }
}

// MARK: - Float2 Swizzle Properties

public extension Node where T == SIMD2<Float> {
    /// Extracts the x component.
    var x: Node<Float> {
        let op = graph.function("shadergraph::swizzle_x_f2", inputs: (SIMD2<Float>.self, ), output: Float.self)
        return op(self)
    }

    /// Extracts the y component.
    var y: Node<Float> {
        let op = graph.function("shadergraph::swizzle_y_f2", inputs: (SIMD2<Float>.self, ), output: Float.self)
        return op(self)
    }
}

// MARK: - Float4 Construction

public extension ShaderGraph {
    /// Creates a float4 from four float nodes.
    func float4(_ x: Node<Float>, _ y: Node<Float>, _ z: Node<Float>, _ w: Node<Float>) -> Node<SIMD4<Float>> {
        let op = function("shadergraph::make_f4", inputs: (Float.self, Float.self, Float.self, Float.self), output: SIMD4<Float>.self)
        return op(x, y, z, w)
    }

    /// Creates a float4 from a float2 and two floats.
    func float4(_ xy: Node<SIMD2<Float>>, _ z: Node<Float>, _ w: Node<Float>) -> Node<SIMD4<Float>> {
        let op = function("shadergraph::make_f4_f2_f_f", inputs: (SIMD2<Float>.self, Float.self, Float.self), output: SIMD4<Float>.self)
        return op(xy, z, w)
    }

    /// Creates a float4 from a float2, a float literal, and a float literal.
    func float4(_ xy: Node<SIMD2<Float>>, _ z: Float, _ w: Float) -> Node<SIMD4<Float>> {
        let zNode = constant(z)
        let wNode = constant(w)
        return float4(xy, zNode, wNode)
    }

    /// Creates a float4 from mixed Node<Float> and Float literals.
    func float4<X: ScalarValue, Y: ScalarValue, Z: ScalarValue, W: ScalarValue>(
        _ x: X, _ y: Y, _ z: Z, _ w: W
    ) -> Node<SIMD4<Float>> {
        let xNode = x.asNode(graph: self)
        let yNode = y.asNode(graph: self)
        let zNode = z.asNode(graph: self)
        let wNode = w.asNode(graph: self)
        return float4(xNode, yNode, zNode, wNode)
    }

    // MARK: - Math Functions

    /// Sine function.
    func sin(_ x: Node<Float>) -> Node<Float> {
        let op = function("shadergraph::sin_f", inputs: (Float.self, ), output: Float.self)
        return op(x)
    }

    /// Cosine function.
    func cos(_ x: Node<Float>) -> Node<Float> {
        let op = function("shadergraph::cos_f", inputs: (Float.self, ), output: Float.self)
        return op(x)
    }

    /// Linear interpolation between two float values.
    func mix(_ a: Node<Float>, _ b: Node<Float>, _ t: Node<Float>) -> Node<Float> {
        let op = function("shadergraph::mix_f", inputs: (Float.self, Float.self, Float.self), output: Float.self)
        return op(a, b, t)
    }

    /// Linear interpolation between two float4 values.
    func mix(_ a: Node<SIMD4<Float>>, _ b: Node<SIMD4<Float>>, _ t: Node<Float>) -> Node<SIMD4<Float>> {
        let op = function("shadergraph::mix_f4", inputs: (SIMD4<Float>.self, SIMD4<Float>.self, Float.self), output: SIMD4<Float>.self)
        return op(a, b, t)
    }
}

// MARK: - Free Math Functions

/// Sine function.
public func sin(_ x: Node<Float>) -> Node<Float> {
    x.graph.sin(x)
}

/// Cosine function.
public func cos(_ x: Node<Float>) -> Node<Float> {
    x.graph.cos(x)
}

/// Linear interpolation between two float values.
public func mix(_ a: Node<Float>, _ b: Node<Float>, _ t: Node<Float>) -> Node<Float> {
    a.graph.mix(a, b, t)
}

/// Linear interpolation between two float4 values.
public func mix(_ a: Node<SIMD4<Float>>, _ b: Node<SIMD4<Float>>, _ t: Node<Float>) -> Node<SIMD4<Float>> {
    a.graph.mix(a, b, t)
}

/// Creates a float4 from four float nodes.
public func float4(_ x: Node<Float>, _ y: Node<Float>, _ z: Node<Float>, _ w: Node<Float>) -> Node<SIMD4<Float>> {
    x.graph.float4(x, y, z, w)
}

/// Creates a float4 from mixed Node<Float> and Float literals.
/// At least the first argument must be a Node to infer the graph.
public func float4<Y: ScalarValue, Z: ScalarValue, W: ScalarValue>(
    _ x: Node<Float>, _ y: Y, _ z: Z, _ w: W
) -> Node<SIMD4<Float>> {
    x.graph.float4(x, y, z, w)
}

// MARK: - GraphFunction

/// A typed reference to a registered shader function.
///
/// `GraphFunction` wraps a function name and provides a type-safe
/// `callAsFunction` that creates function nodes.
///
/// You obtain `GraphFunction` instances via ``ShaderGraph/function(_:inputs:output:)``:
///
/// ```swift
/// let adjustBrightness = graph.function(
///     "adjustBrightness",
///     inputs: (SIMD4<Float>.self, Float.self),
///     output: SIMD4<Float>.self
/// )
///
/// // Call it like a function
/// let result = adjustBrightness(color, brightness)
/// ```
public struct GraphFunction<each Input: ShaderType, Output: ShaderType>: Sendable {
    let graph: ShaderGraph
    let name: String

    /// Calls the function with the given inputs, returning a new node.
    public func callAsFunction(_ input: repeat Node<each Input>) -> Node<Output> {
        var kinds: [Kind] = []
        func append<U: ShaderType>(_ node: Node<U>) {
            kinds.append(node.kind)
        }
        repeat append(each input)
        return graph.makeNode(name, inputs: kinds, outputType: Output.valueType)
    }
}
