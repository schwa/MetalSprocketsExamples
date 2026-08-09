import CoreGraphics
@testable import MetalSprocketsExamples
import Testing

@Suite
struct DrawableSizeTests {
    @Test("A normal drawable size is usable")
    func whenSizeIsPositive_thenUsable() {
        #expect(isUsableDrawableSize(CGSize(width: 1_920, height: 1_080)))
    }

    @Test("Sizes reported during layout are rejected")
    func whenSizeIsDegenerate_thenNotUsable() {
        #expect(!isUsableDrawableSize(.zero))
        #expect(!isUsableDrawableSize(CGSize(width: 1_920, height: 0)))
        #expect(!isUsableDrawableSize(CGSize(width: 0, height: 1_080)))
        #expect(!isUsableDrawableSize(CGSize(width: 0.5, height: 0.5)))
        #expect(!isUsableDrawableSize(CGSize(width: -10, height: -10)))
    }
}
