import CoreGraphics
import ImageIO
import Metal
import MetalKit
import ModelIO
internal import os
import simd
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Logging

internal let logger: Logger? = {
    guard ProcessInfo.processInfo.environment["LOGGING"] != nil else {
        return nil
    }
    return Logger(subsystem: "io.schwa.metal-sprockets-addons", category: "default")
}()

extension Color {
    // TODO: Not linear
    var float4: SIMD4<Float> {
        get {
            let resolved = self.resolve(in: .init())
            return [Float(resolved.red), Float(resolved.green), Float(resolved.blue), Float(resolved.opacity)]
        }
        set {
            self = Color(red: Double(newValue[0]), green: Double(newValue[1]), blue: Double(newValue[2]), opacity: Double(newValue[3]))
        }
    }
}
