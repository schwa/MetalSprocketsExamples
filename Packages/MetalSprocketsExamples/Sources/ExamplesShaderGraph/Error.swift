// Error.swift
// Error types for ShaderGraph

import Foundation

/// Errors that can occur when building or validating shader graphs.
public enum ShaderGraphError: Error, LocalizedError {
    /// A function referenced in the graph was not registered.
    case unknownFunction(name: String)

    /// The stitched function's argument count doesn't match the declared signature.
    case signatureMismatch(expected: Int, actual: Int, functionName: String)

    /// An input was referenced that doesn't exist in the graph's signature.
    case unknownInput(name: String, available: [String])

    /// An input was accessed with the wrong type.
    case inputTypeMismatch(name: String, expected: ValueType, actual: ValueType)

    /// Failed to create the stitched function.
    case stitchingFailed(name: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case let .unknownFunction(name):
            return "Unknown function '\(name)' - did you forget to register it or call registerStdlib()?"
        case let .signatureMismatch(expected, actual, functionName):
            return "Function '\(functionName)' has \(actual) arguments but expected \(expected). This usually means an input is missing from the graph."
        case let .unknownInput(name, available):
            return "No input named '\(name)' in graph signature. Available: \(available.joined(separator: ", "))"
        case let .inputTypeMismatch(name, expected, actual):
            return "Input '\(name)' has type \(expected), but was accessed as \(actual)"
        case let .stitchingFailed(name, reason):
            return "Failed to create function '\(name)': \(reason)"
        }
    }
}
