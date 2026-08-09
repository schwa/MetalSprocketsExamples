import MetalSprockets
import MetalSprocketsExampleShaders

extension ShaderNamespace {
    /// The namespace `name` inside the examples' shader library.
    ///
    /// Every demo needs its own namespace out of the same bundle, so the library lookup was written out
    /// in full at nearly forty call sites.
    ///
    /// ```swift
    /// let shaders = try ShaderNamespace.examples("ColorAdjust")
    /// let kernel: ComputeKernel = try shaders.colorAdjust
    /// ```
    static func examples(_ name: String) throws -> ShaderNamespace {
        try ShaderLibrary(bundle: .metalSprocketsExampleShaders()).namespaced(name)
    }
}
