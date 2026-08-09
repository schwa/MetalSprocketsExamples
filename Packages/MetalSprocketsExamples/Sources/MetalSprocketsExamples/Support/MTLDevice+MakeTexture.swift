import Metal
import MetalSupport

extension MTLDevice {
    /// Creates a 2D texture in one call.
    ///
    /// Almost every demo needs the same four lines: build a `texture2DDescriptor`, set `usage`, make
    /// the texture, then label it. This collapses that into a single expression.
    ///
    /// - Parameters:
    ///   - pixelFormat: The texture's pixel format.
    ///   - width: Width in pixels.
    ///   - height: Height in pixels.
    ///   - usage: How the texture will be used. Defaults to `[.shaderRead, .shaderWrite]`.
    ///   - storageMode: The storage mode, or `nil` (the default) to keep Metal's choice.
    ///   - mipmapped: Whether to allocate a mipmap chain. Defaults to `false`.
    ///   - label: A debug label for the texture.
    ///
    /// Calls `fatalError` if allocation fails, matching the `orFatalError` idiom the demos already use:
    /// a demo that cannot allocate its render targets has nothing to fall back to.
    func makeTexture2D(
        pixelFormat: MTLPixelFormat,
        width: Int,
        height: Int,
        usage: MTLTextureUsage = [.shaderRead, .shaderWrite],
        storageMode: MTLStorageMode? = nil,
        mipmapped: Bool = false,
        label: String? = nil
    ) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: mipmapped
        )
        descriptor.usage = usage
        if let storageMode {
            descriptor.storageMode = storageMode
        }
        let texture = makeTexture(descriptor: descriptor)
            .orFatalError("Failed to create texture \(label ?? "<unlabelled>") (\(width)x\(height), \(pixelFormat))")
        texture.label = label
        return texture
    }
}
