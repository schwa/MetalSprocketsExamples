import MetalSprockets
import MetalSprocketsExampleShaders

extension ShaderLibrary {
    /// The examples' shader library, without the `throws`.
    ///
    /// `@MSState` initialisers cannot throw, so holding a shader in state — which is how elements are
    /// supposed to keep them, rather than looking them up every frame — needs a non-throwing entry
    /// point. A missing shader library is a build error rather than something to recover from, so
    /// trapping here matches ``MetalSprocketsAddOns``' `ShaderLibrary.module`.
    ///
    /// ```swift
    /// @MSState
    /// private var vertexShader = ShaderLibrary.examples.namespaced("Panorama")
    ///     .requiredFunction(named: "vertex_main", type: VertexShader.self)
    /// ```
    static var examples: ShaderLibrary {
        // swiftlint:disable:next force_try
        try! ShaderLibrary(bundle: .metalSprocketsExampleShaders())
    }
}

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
