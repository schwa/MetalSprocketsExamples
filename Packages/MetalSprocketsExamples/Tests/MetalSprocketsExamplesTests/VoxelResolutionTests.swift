@testable import MetalSprocketsExamples
import Testing

@Suite
struct VoxelResolutionTests {
    @Test("Exponents map to power-of-two dimensions")
    func whenConvertingExponent_thenDimensionIsPowerOfTwo() {
        #expect(VoxelResolution.dimension(forExponent: 2) == 4)
        #expect(VoxelResolution.dimension(forExponent: 5) == 32)
        #expect(VoxelResolution.dimension(forExponent: 9) == 512)
    }

    @Test("Out-of-range exponents clamp to the supported grid sizes")
    func whenExponentIsOutOfRange_thenDimensionClamps() {
        #expect(VoxelResolution.dimension(forExponent: -3) == 4)
        #expect(VoxelResolution.dimension(forExponent: 42) == 512)
    }

    @Test("Fractional slider positions snap to the nearest resolution")
    func whenExponentIsFractional_thenDimensionRounds() {
        #expect(VoxelResolution.dimension(forExponent: 4.4) == 16)
        #expect(VoxelResolution.dimension(forExponent: 4.6) == 32)
    }

    @Test("Dimensions round-trip back to their exponent")
    func whenConvertingDimension_thenExponentRoundTrips() {
        for exponent in VoxelResolution.minimumExponent...VoxelResolution.maximumExponent {
            let dimension = VoxelResolution.dimension(forExponent: Double(exponent))
            #expect(VoxelResolution.exponent(forDimension: dimension) == Double(exponent))
        }
    }

    @Test("Degenerate dimensions fall back to the smallest resolution")
    func whenDimensionIsZero_thenExponentIsMinimum() {
        #expect(VoxelResolution.exponent(forDimension: 0) == Double(VoxelResolution.minimumExponent))
    }
}
