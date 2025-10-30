import Metal
import MetalKit
import MetalSprockets
import MetalSprocketsSupport
import SwiftUI

public extension Draw {
    init(mtkMesh: MTKMesh) {
        self.init { encoder in
            encoder.setVertexBuffers(of: mtkMesh)
            encoder.draw(mtkMesh)
        }
    }
}
