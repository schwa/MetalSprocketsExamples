import Metal
import MetalKit
import SwiftUI
import MetalSprockets
import MetalSprocketsSupport

public extension Draw {
    init(mtkMesh: MTKMesh) {
        self.init { encoder in
            encoder.setVertexBuffers(of: mtkMesh)
            encoder.draw(mtkMesh)
        }
    }
}
