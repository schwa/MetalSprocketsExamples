import Metal
import MetalKit
import SwiftUI

public extension SIMD4<Float> {
    init(color: Color) {
        let resolved = color.resolve(in: .init())
        self = [
            Float(resolved.linearRed),
            Float(resolved.linearGreen),
            Float(resolved.linearBlue),
            Float(resolved.opacity)
        ]
    }
}

extension MTLSize: @retroactive ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Int...) {
        switch elements.count {
        case 0:
            self = .init(width: 0, height: 0, depth: 0)
        case 1:
            self = .init(width: elements[0], height: 0, depth: 0)
        case 2:
            self = .init(width: elements[0], height: elements[1], depth: 0)
        case 3:
            self = .init(width: elements[0], height: elements[1], depth: elements[2])
        default:
            fatalError("Too many elements in array literal.")
        }
    }
}

public extension MTLLinkedFunctions {
    convenience init(functions: [MTLFunction]) {
        self.init()
        self.functions = functions
    }
}

public extension MTLTexture {
    var size: MTLSize {
        MTLSize(width: width, height: height, depth: depth)
    }
}

extension MTLSize: @retroactive Equatable {
    public static func == (lhs: MTLSize, rhs: MTLSize) -> Bool {
        lhs.width == rhs.width && lhs.height == rhs.height && lhs.depth == rhs.depth
    }
}
