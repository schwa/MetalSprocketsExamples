import Foundation
import SwiftGLTF

extension Accessor {
    /// Asserts that decoded vector values match the element count and declared bounds of this accessor.
    ///
    /// glTF accessors optionally carry `min`/`max` per component. The values are only useful as a
    /// sanity check on our decoding, so this is debug-only: the closures never run in release builds.
    func assertConsistent<Vector>(with values: [Vector]) where Vector: SIMD, Vector.Scalar == Float {
        assert(values.count == count)
        guard let minValues = min, let maxValues = max, minValues.count == maxValues.count else {
            return
        }
        assert(values.allSatisfy { value in
            (0..<Swift.min(minValues.count, value.scalarCount)).allSatisfy { index in
                (Float(minValues[index])...Float(maxValues[index])).contains(value[index])
            }
        })
    }

    /// Asserts that decoded index values match the element count and declared bounds of this accessor.
    func assertConsistent<Index>(with values: [Index]) where Index: BinaryInteger {
        assert(values.count == count)
        guard let minValue = min?.first, let maxValue = max?.first else {
            return
        }
        let lowerBound = Index(minValue)
        let upperBound = Index(maxValue)
        assert(values.allSatisfy { (lowerBound...upperBound).contains($0) })
    }
}
