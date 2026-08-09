import Foundation

/// Power-of-two voxel grid resolutions, expressed as the exponent so a slider can move between them.
enum VoxelResolution {
    /// 4³ voxels.
    static let minimumExponent = 2
    /// 512³ voxels.
    static let maximumExponent = 9

    /// The grid dimension for a slider position, clamped to the supported range.
    static func dimension(forExponent exponent: Double) -> Int {
        let rounded = Int(exponent.rounded())
        return 1 << min(max(rounded, minimumExponent), maximumExponent)
    }

    /// The slider position for a grid dimension.
    static func exponent(forDimension dimension: Int) -> Double {
        guard dimension > 0 else {
            return Double(minimumExponent)
        }
        return min(max(log2(Double(dimension)), Double(minimumExponent)), Double(maximumExponent))
    }
}
