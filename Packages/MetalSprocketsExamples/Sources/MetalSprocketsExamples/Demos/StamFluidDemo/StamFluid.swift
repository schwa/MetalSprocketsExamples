import Foundation
import Metal
import MetalSprockets
import MetalSprocketsAddOns
import MetalSprocketsExampleShaders
import MetalSprocketsSupport
import simd

/// GPU implementation of Jos Stam's "Real-Time Fluid Dynamics for Games" (GDC 2003).
/// Full Navier-Stokes solver using MetalSprockets compute elements with red-black Gauss-Seidel.
struct StamFluid: Element {
    @MSEnvironment(\.device)
    var device

    @MSState private var bufU: MTLBuffer?
    @MSState private var bufV: MTLBuffer?
    @MSState private var bufUPrev: MTLBuffer?
    @MSState private var bufVPrev: MTLBuffer?
    @MSState private var bufDens: MTLBuffer?
    @MSState private var bufDensPrev: MTLBuffer?
    @MSState private var bufP: MTLBuffer?
    @MSState private var bufDiv: MTLBuffer?
    @MSState private var displayTexture: MTLTexture?
    @MSState private var initialized: Bool = false
    @MSState private var initializedN: Int = 0

    let gridN: Int
    let diffusion: Float
    let viscosity: Float
    let isRunning: Bool
    let showVelocity: Bool
    let interactionPoint: SIMD2<Float>?
    let interactionVelocity: SIMD2<Float>?
    let interactionActive: Bool

    struct FluidParams {
        var N: UInt32
        var dt: Float
        var diff: Float
        var visc: Float
    }

    init(gridN: Int = 128, diffusion: Float = 0.0001, viscosity: Float = 0.0, isRunning: Bool = true, showVelocity: Bool = false, interactionPoint: SIMD2<Float>? = nil, interactionVelocity: SIMD2<Float>? = nil, interactionActive: Bool = false) {
        self.gridN = gridN
        self.diffusion = diffusion
        self.viscosity = viscosity
        self.isRunning = isRunning
        self.showVelocity = showVelocity
        self.interactionPoint = interactionPoint
        self.interactionVelocity = interactionVelocity
        self.interactionActive = interactionActive
    }

    var body: some Element {
        get throws {
            setupBuffersIfNeeded()

            // Inject interaction on CPU (shared buffers, written before GPU reads)
            if isRunning {
                clearSourceBuffers()
                if interactionActive, let point = interactionPoint, let vel = interactionVelocity {
                    writeInteraction(point: point, velocity: vel, N: gridN)
                }
            }

            let lib = try ShaderLibrary(bundle: Bundle.metalSprocketsExampleShaders()).namespaced("StamFluidShader")
            let N = UInt32(gridN)
            let params = FluidParams(N: N, dt: 0.1, diff: diffusion, visc: viscosity)
            let size = Int((N + 2) * (N + 2))
            let interior = MTLSize(width: Int(N), height: Int(N), depth: 1)
            let tg16 = MTLSize(width: 16, height: 16, depth: 1)
            let linear = MTLSize(width: size, height: 1, depth: 1)
            let tg256 = MTLSize(width: 256, height: 1, depth: 1)

            return try Group {
                if isRunning, let bufU, let bufV, let bufUPrev, let bufVPrev, let bufDens, let bufDensPrev, let bufP, let bufDiv {
                    let a_visc = params.dt * params.visc * Float(N) * Float(N)
                    let a_diff = params.dt * params.diff * Float(N) * Float(N)

                    // === Velocity step ===
                    // Add forces
                    try addSourcePass(lib: lib, x: bufU, s: bufUPrev, params: params, linear: linear, tg: tg256)
                    try addSourcePass(lib: lib, x: bufV, s: bufVPrev, params: params, linear: linear, tg: tg256)

                    // Diffuse U: blit u->uPrev, then Gauss-Seidel from uPrev into u
                    try blitCopy(from: bufU, to: bufUPrev)
                    try diffusePass(lib: lib, x: bufU, x0: bufUPrev, b: 1, a: a_visc, params: params, N: N, interior: interior, tg: tg16)

                    // Diffuse V
                    try blitCopy(from: bufV, to: bufVPrev)
                    try diffusePass(lib: lib, x: bufV, x0: bufVPrev, b: 2, a: a_visc, params: params, N: N, interior: interior, tg: tg16)

                    // Project
                    try projectPass(lib: lib, u: bufU, v: bufV, p: bufP, div: bufDiv, params: params, N: N, interior: interior, tg: tg16)

                    // Advect velocity: blit u->uPrev, v->vPrev, then advect
                    try blitCopy(from: bufU, to: bufUPrev)
                    try blitCopy(from: bufV, to: bufVPrev)
                    try advectPass(lib: lib, d: bufU, d0: bufUPrev, u: bufUPrev, v: bufVPrev, b: 1, params: params, N: N, interior: interior, tg: tg16)
                    try advectPass(lib: lib, d: bufV, d0: bufVPrev, u: bufUPrev, v: bufVPrev, b: 2, params: params, N: N, interior: interior, tg: tg16)

                    // Project again
                    try projectPass(lib: lib, u: bufU, v: bufV, p: bufP, div: bufDiv, params: params, N: N, interior: interior, tg: tg16)

                    // === Density step ===
                    // Add source
                    try addSourcePass(lib: lib, x: bufDens, s: bufDensPrev, params: params, linear: linear, tg: tg256)

                    // Diffuse density
                    try blitCopy(from: bufDens, to: bufDensPrev)
                    try diffusePass(lib: lib, x: bufDens, x0: bufDensPrev, b: 0, a: a_diff, params: params, N: N, interior: interior, tg: tg16)

                    // Advect density
                    try blitCopy(from: bufDens, to: bufDensPrev)
                    try advectPass(lib: lib, d: bufDens, d0: bufDensPrev, u: bufU, v: bufV, b: 0, params: params, N: N, interior: interior, tg: tg16)

                    // Decay density to prevent saturation
                    try decayPass(lib: lib, x: bufDens, params: params, linear: linear, tg: tg256)
                }

                // === Visualize ===
                if let displayTexture, let bufDens, let bufU, let bufV {
                    try ComputePass {
                        if showVelocity {
                            try ComputePipeline(computeKernel: try lib.visualizeVelocity) {
                                try ComputeDispatch(threadsPerGrid: interior, threadsPerThreadgroup: tg16)
                                    .parameter("u", buffer: bufU, offset: 0)
                                    .parameter("v", buffer: bufV, offset: 0)
                                    .parameter("output", texture: displayTexture)
                                    .parameter("params", value: params)
                            }
                        } else {
                            try ComputePipeline(computeKernel: try lib.visualizeDensity) {
                                try ComputeDispatch(threadsPerGrid: interior, threadsPerThreadgroup: tg16)
                                    .parameter("dens", buffer: bufDens, offset: 0)
                                    .parameter("output", texture: displayTexture)
                                    .parameter("params", value: params)
                            }
                        }
                    }

                    try RenderPass {
                        try TextureBillboardPipeline(specifier: .texture2D(displayTexture))
                    }
                }
            }
        }
    }

    // MARK: - Element builders for solver steps

    @ElementBuilder
    private func addSourcePass(lib: ShaderNamespace, x: MTLBuffer, s: MTLBuffer, params: FluidParams, linear: MTLSize, tg: MTLSize) throws -> some Element {
        try ComputePass {
            try ComputePipeline(computeKernel: try lib.addSource) {
                try ComputeDispatch(threadsPerGrid: linear, threadsPerThreadgroup: tg)
                    .parameter("x", buffer: x, offset: 0)
                    .parameter("s", buffer: s, offset: 0)
                    .parameter("params", value: params)
            }
        }
    }

    @ElementBuilder
    private func blitCopy(from src: MTLBuffer, to dst: MTLBuffer) throws -> some Element {
        try BlitPass {
            Blit { encoder in
                encoder.copy(from: src, sourceOffset: 0, to: dst, destinationOffset: 0, size: src.length)
            }
        }
    }

    @ElementBuilder
    private func diffusePass(lib: ShaderNamespace, x: MTLBuffer, x0: MTLBuffer, b: Int, a: Float, params: FluidParams, N: UInt32, interior: MTLSize, tg: MTLSize) throws -> some Element {
        // 20 Gauss-Seidel iterations, each color in its own ComputePass for proper barriers
        ForEach(0..<20, id: \.self) { _ in
            try ComputePass {
                try ComputePipeline(computeKernel: try lib.diffuseRedBlack) {
                    try ComputeDispatch(threadsPerGrid: interior, threadsPerThreadgroup: tg)
                        .parameter("x", buffer: x, offset: 0)
                        .parameter("x0", buffer: x0, offset: 0)
                        .parameter("params", value: params)
                        .parameter("colorPass", value: Int32(0))
                        .parameter("a", value: a)
                }
            }
            try ComputePass {
                try ComputePipeline(computeKernel: try lib.diffuseRedBlack) {
                    try ComputeDispatch(threadsPerGrid: interior, threadsPerThreadgroup: tg)
                        .parameter("x", buffer: x, offset: 0)
                        .parameter("x0", buffer: x0, offset: 0)
                        .parameter("params", value: params)
                        .parameter("colorPass", value: Int32(1))
                        .parameter("a", value: a)
                }
            }
        }
        try boundaryPass(lib: lib, x: x, b: b, params: params, N: N)
    }

    @ElementBuilder
    private func advectPass(lib: ShaderNamespace, d: MTLBuffer, d0: MTLBuffer, u: MTLBuffer, v: MTLBuffer, b: Int, params: FluidParams, N: UInt32, interior: MTLSize, tg: MTLSize) throws -> some Element {
        try ComputePass {
            try ComputePipeline(computeKernel: try lib.advect) {
                try ComputeDispatch(threadsPerGrid: interior, threadsPerThreadgroup: tg)
                    .parameter("d", buffer: d, offset: 0)
                    .parameter("d0", buffer: d0, offset: 0)
                    .parameter("u", buffer: u, offset: 0)
                    .parameter("v", buffer: v, offset: 0)
                    .parameter("params", value: params)
            }
        }
        try boundaryPass(lib: lib, x: d, b: b, params: params, N: N)
    }

    @ElementBuilder
    private func projectPass(lib: ShaderNamespace, u: MTLBuffer, v: MTLBuffer, p: MTLBuffer, div: MTLBuffer, params: FluidParams, N: UInt32, interior: MTLSize, tg: MTLSize) throws -> some Element {
        // Compute divergence
        try ComputePass {
            try ComputePipeline(computeKernel: try lib.projectDivergence) {
                try ComputeDispatch(threadsPerGrid: interior, threadsPerThreadgroup: tg)
                    .parameter("div", buffer: div, offset: 0)
                    .parameter("p", buffer: p, offset: 0)
                    .parameter("u", buffer: u, offset: 0)
                    .parameter("v", buffer: v, offset: 0)
                    .parameter("params", value: params)
            }
        }
        try boundaryPass(lib: lib, x: div, b: 0, params: params, N: N)
        try boundaryPass(lib: lib, x: p, b: 0, params: params, N: N)

        // Pressure solve: 20 iterations
        ForEach(0..<20, id: \.self) { _ in
            try ComputePass {
                try ComputePipeline(computeKernel: try lib.projectPressureRedBlack) {
                    try ComputeDispatch(threadsPerGrid: interior, threadsPerThreadgroup: tg)
                        .parameter("p", buffer: p, offset: 0)
                        .parameter("div", buffer: div, offset: 0)
                        .parameter("params", value: params)
                        .parameter("colorPass", value: Int32(0))
                }
            }
            try ComputePass {
                try ComputePipeline(computeKernel: try lib.projectPressureRedBlack) {
                    try ComputeDispatch(threadsPerGrid: interior, threadsPerThreadgroup: tg)
                        .parameter("p", buffer: p, offset: 0)
                        .parameter("div", buffer: div, offset: 0)
                        .parameter("params", value: params)
                        .parameter("colorPass", value: Int32(1))
                }
            }
        }
        try boundaryPass(lib: lib, x: p, b: 0, params: params, N: N)

        // Subtract gradient
        try ComputePass {
            try ComputePipeline(computeKernel: try lib.projectGradientSubtract) {
                try ComputeDispatch(threadsPerGrid: interior, threadsPerThreadgroup: tg)
                    .parameter("u", buffer: u, offset: 0)
                    .parameter("v", buffer: v, offset: 0)
                    .parameter("p", buffer: p, offset: 0)
                    .parameter("params", value: params)
            }
        }
        try boundaryPass(lib: lib, x: u, b: 1, params: params, N: N)
        try boundaryPass(lib: lib, x: v, b: 2, params: params, N: N)
    }

    @ElementBuilder
    private func decayPass(lib: ShaderNamespace, x: MTLBuffer, params: FluidParams, linear: MTLSize, tg: MTLSize) throws -> some Element {
        try ComputePass {
            try ComputePipeline(computeKernel: try lib.decay) {
                try ComputeDispatch(threadsPerGrid: linear, threadsPerThreadgroup: tg)
                    .parameter("x", buffer: x, offset: 0)
                    .parameter("params", value: params)
                    .parameter("factor", value: Float(0.995))
            }
        }
    }

    @ElementBuilder
    private func boundaryPass(lib: ShaderNamespace, x: MTLBuffer, b: Int, params: FluidParams, N: UInt32) throws -> some Element {
        try ComputePass {
            try ComputePipeline(computeKernel: try lib.setBoundary) {
                try ComputeDispatch(threadsPerGrid: MTLSize(width: Int(N), height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: min(256, Int(N)), height: 1, depth: 1))
                    .parameter("x", buffer: x, offset: 0)
                    .parameter("params", value: params)
                    .parameter("b", value: Int32(b))
            }
            try ComputePipeline(computeKernel: try lib.setBoundaryCorners) {
                try ComputeDispatch(threadsPerGrid: MTLSize(width: 1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
                    .parameter("x", buffer: x, offset: 0)
                    .parameter("params", value: params)
            }
        }
    }

    // MARK: - Buffer setup (called from body, before GPU work)

    private func setupBuffersIfNeeded() {
        guard (!initialized || initializedN != gridN), let device else {
            return
        }

        let N = gridN
        let size = (N + 2) * (N + 2)
        let byteCount = size * MemoryLayout<Float>.stride

        bufU = device.makeBuffer(length: byteCount, options: .storageModeShared)
        bufV = device.makeBuffer(length: byteCount, options: .storageModeShared)
        bufUPrev = device.makeBuffer(length: byteCount, options: .storageModeShared)
        bufVPrev = device.makeBuffer(length: byteCount, options: .storageModeShared)
        bufDens = device.makeBuffer(length: byteCount, options: .storageModeShared)
        bufDensPrev = device.makeBuffer(length: byteCount, options: .storageModeShared)
        bufP = device.makeBuffer(length: byteCount, options: .storageModeShared)
        bufDiv = device.makeBuffer(length: byteCount, options: .storageModeShared)

        for buf in [bufU, bufV, bufUPrev, bufVPrev, bufDens, bufDensPrev, bufP, bufDiv] {
            if let buf {
                memset(buf.contents(), 0, byteCount)
            }
        }

        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: N, height: N, mipmapped: false)
        desc.usage = [.shaderRead, .shaderWrite]
        desc.storageMode = .private
        displayTexture = device.makeTexture(descriptor: desc)

        initialized = true
        initializedN = gridN
    }

    // MARK: - CPU-side source buffer management

    private func clearSourceBuffers() {
        guard let bufUPrev, let bufVPrev, let bufDensPrev else {
            return
        }
        let size = (gridN + 2) * (gridN + 2) * MemoryLayout<Float>.stride
        memset(bufUPrev.contents(), 0, size)
        memset(bufVPrev.contents(), 0, size)
        memset(bufDensPrev.contents(), 0, size)
    }

    private func writeInteraction(point: SIMD2<Float>, velocity: SIMD2<Float>, N: Int) {
        guard let densPrev = bufDensPrev, let uPrev = bufUPrev, let vPrev = bufVPrev else {
            return
        }

        let densPtr = densPrev.contents().bindMemory(to: Float.self, capacity: (N + 2) * (N + 2))
        let uPtr = uPrev.contents().bindMemory(to: Float.self, capacity: (N + 2) * (N + 2))
        let vPtr = vPrev.contents().bindMemory(to: Float.self, capacity: (N + 2) * (N + 2))

        let gi = Int(point.x * Float(N)) + 1
        let gj = Int(point.y * Float(N)) + 1
        let radius = max(2, N / 32)
        let force: Float = 100.0
        let densityAmount: Float = 50.0

        for di in -radius...radius {
            for dj in -radius...radius {
                let ii = gi + di
                let jj = gj + dj
                guard ii >= 1, ii <= N, jj >= 1, jj <= N else {
                    continue
                }
                let dist = sqrt(Float(di * di + dj * dj))
                guard dist <= Float(radius) else {
                    continue
                }
                let falloff = 1.0 - dist / Float(radius)
                let idx = ii + (N + 2) * jj
                densPtr[idx] += densityAmount * falloff
                uPtr[idx] += force * velocity.x * falloff
                vPtr[idx] += force * velocity.y * falloff
            }
        }
    }
}
