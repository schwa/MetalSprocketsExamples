// ValueType.swift
// Types that can flow through shader graphs

import Metal
import simd

// MARK: - ValueType

/// The data types that can flow through a shader graph.
///
/// These correspond to Metal shader language types and are used to define
/// function signatures and validate graph connections.
public enum ValueType: Sendable {
    /// A single-precision floating-point scalar (`float` in Metal).
    case float
    /// A 2-component floating-point vector (`float2` in Metal).
    case float2
    /// A 3-component floating-point vector (`float3` in Metal).
    case float3
    /// A 4-component floating-point vector (`float4` in Metal).
    case float4
    /// A 2D texture (`texture2d<float>` in Metal).
    case texture2D

    /// The Metal type name for this value type.
    public var metalTypeName: String {
        switch self {
        case .float: return "float"
        case .float2: return "float2"
        case .float3: return "float3"
        case .float4: return "float4"
        case .texture2D: return "texture2d<float>"
        }
    }
}

// MARK: - ShaderType Protocol

/// A protocol for Swift types that map to shader graph value types.
///
/// Conforming types can be used as compile-time type parameters for
/// ``BoundNode`` and ``GraphFunction``, providing type safety when
/// building shader graphs.
///
/// Built-in conformances:
/// - `Float` → ``ValueType/float``
/// - `SIMD2<Float>` → ``ValueType/float2``
/// - `SIMD3<Float>` → ``ValueType/float3``
/// - `SIMD4<Float>` → ``ValueType/float4``
/// - ``Texture2D`` → ``ValueType/texture2D``
public protocol ShaderType {
    /// The corresponding ``ValueType`` for this Swift type.
    static var valueType: ValueType { get }
}

extension Float: ShaderType {
    public static var valueType: ValueType { .float }
}

extension SIMD2<Float>: ShaderType {
    public static var valueType: ValueType { .float2 }
}

extension SIMD3<Float>: ShaderType {
    public static var valueType: ValueType { .float3 }
}

extension SIMD4<Float>: ShaderType {
    public static var valueType: ValueType { .float4 }
}

/// A marker type representing a 2D texture in shader graphs.
///
/// This type exists only to provide compile-time type information.
/// It has no runtime representation.
public struct Texture2D: ShaderType {
    public static var valueType: ValueType { .texture2D }
}

// MARK: - FunctionSignature

/// Describes the input and output types of a stitchable function.
///
/// Function signatures are used to register primitives and validate
/// graph connections at stitch time.
public struct FunctionSignature: Sendable {
    /// The types of the function's input parameters, in order.
    public var inputs: [ValueType]
    /// The type of the function's return value.
    public var output: ValueType

    /// Creates a function signature.
    /// - Parameters:
    ///   - inputs: The input parameter types.
    ///   - output: The return type.
    public init(inputs: [ValueType], output: ValueType) {
        self.inputs = inputs
        self.output = output
    }
}
