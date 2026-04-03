import SwiftUI

public protocol TimingFunction {
    func solve(_ x: Float) -> Float
}

public extension TimingFunction {
    func value(time: TimeInterval, period: TimeInterval, offset: Float, in range: ClosedRange<Float>) -> Float {
        let t = Float(fmod(time, period) / period) + offset
        return range.lowerBound + solve(t) * (range.upperBound - range.lowerBound)
    }
    func value(time: TimeInterval, period: TimeInterval, in range: ClosedRange<Float>) -> Float {
        value(time: time, period: period, offset: 0, in: range)
    }
}

public struct LinearTimingFunction: TimingFunction {
    public init() {
        // This line intentionally left blank.
    }

    public func solve(_ x: Float) -> Float {
        x
    }
}

public struct SinusoidalTimingFunction: TimingFunction {
    public init() {
        // This line intentionally left blank.
    }

    public func solve(_ x: Float) -> Float {
        0.5 * (1 + sin(.pi * x - .pi / 2))
    }
}

public struct ForwardAndReverseTimingFunction<T>: TimingFunction where T: TimingFunction {
    let other: T

    public init(_ other: T) {
        self.other = other
    }

    public func solve(_ x: Float) -> Float {
        if x < 0.5 {
            return other.solve(2 * x)
        }
        return other.solve(2 - 2 * x)
    }
}
