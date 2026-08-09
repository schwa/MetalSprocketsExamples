import CoreGraphics
import MetalSprocketsUI
import SwiftUI

/// Whether a reported drawable size can be used to allocate textures.
///
/// `MTKView` reports zero and sub-pixel sizes while SwiftUI settles the layout. Allocating from one
/// produces an invalid texture descriptor, so every demo that sizes textures from the drawable had to
/// guard by hand — and did so inconsistently.
func isUsableDrawableSize(_ size: CGSize) -> Bool {
    size.width >= 1 && size.height >= 1
}

extension View {
    /// Calls `action` when the drawable resizes, skipping the degenerate sizes reported during layout.
    ///
    /// Use this instead of ``MetalSprocketsUI/View/onDrawableSizeChange(perform:)`` whenever the
    /// callback allocates textures from the size.
    func onUsableDrawableSizeChange(perform action: @escaping (CGSize) -> Void) -> some View {
        onDrawableSizeChange { size in
            guard isUsableDrawableSize(size) else {
                return
            }
            action(size)
        }
    }
}
