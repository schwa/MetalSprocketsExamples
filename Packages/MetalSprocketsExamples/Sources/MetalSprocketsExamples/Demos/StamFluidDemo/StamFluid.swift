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
    // Double-buffered source inputs to avoid CPU/GPU races
    @MSState private var srcU: [MTLBuffer?] = [nil, nil]
    @MSState private var srcV: [MTLBuffer?] = [nil, nil]
    @MSState private var srcDens: [MTLBuffer?] = [nil, nil]
    @MSState private var srcIndex: Int = 0
    @MSState private var displayTexture: MTLTexture?
    @MSState private var initialized: Bool = false
    @MSState private var initializedN: Int = 0

    let gridN: Int
    let diffusion: Float
    let viscosity: Float
    let isRunning: Bool
    let visualization: Visualization
    let interactionPoint: SIMD2<Float>?
    let interactionVelocity: SIMD2<Float>?
    let interactionActive: Bool
    let colormap: Colormap

    struct FluidParams {
        var N: UInt32
        var dt: Float
        var diff: Float
        var visc: Float
    }

    init(gridN: Int = 128, diffusion: Float = 0.0001, viscosity: Float = 0.0, isRunning: Bool = true, visualization: Visualization = .density, interactionPoint: SIMD2<Float>? = nil, interactionVelocity: SIMD2<Float>? = nil, interactionActive: Bool = false, colormap: Colormap = .fire) {
        self.gridN = gridN
        self.diffusion = diffusion
        self.viscosity = viscosity
        self.isRunning = isRunning
        self.visualization = visualization
        self.interactionPoint = interactionPoint
        self.interactionVelocity = interactionVelocity
        self.interactionActive = interactionActive
        self.colormap = colormap
    }

    @MSState private var colormapTexture: MTLTexture?
    @MSState private var activeColormap: Colormap = .fire

    var body: some Element {
        get throws {
            setupBuffersIfNeeded()

            // Flip source buffer index and write interaction into the new one
            if isRunning {
                srcIndex = 1 - srcIndex
                clearSourceBuffers()
                if interactionActive, let point = interactionPoint, let vel = interactionVelocity {
                    writeInteraction(point: point, velocity: vel, N: gridN)
                }
            }

            let lib = try ShaderLibrary(bundle: Bundle.metalSprocketsExampleShaders()).namespaced("StamFluidShader")
            let N = UInt32(gridN)
            // Rebuild colormap texture if needed
            if colormapTexture == nil || activeColormap != colormap {
                colormapTexture = buildColormapTexture(colormap)
                activeColormap = colormap
            }

            let params = FluidParams(N: N, dt: 0.1, diff: diffusion, visc: viscosity)
            let size = Int((N + 2) * (N + 2))
            let interior = MTLSize(width: Int(N), height: Int(N), depth: 1)
            let tg16 = MTLSize(width: 16, height: 16, depth: 1)
            let linear = MTLSize(width: size, height: 1, depth: 1)
            let tg256 = MTLSize(width: 256, height: 1, depth: 1)

            return try Group {
                // swiftlint:disable:next line_length
                if isRunning, let bufU, let bufV, let bufUPrev, let bufVPrev, let bufDens, let bufDensPrev, let bufP, let bufDiv, let curSrcU = srcU[srcIndex], let curSrcV = srcV[srcIndex], let curSrcDens = srcDens[srcIndex] {
                    let a_visc = params.dt * params.visc * Float(N) * Float(N)
                    let a_diff = params.dt * params.diff * Float(N) * Float(N)

                    // === Velocity step ===
                    // Add forces from double-buffered source inputs
                    try addSourcePass(lib: lib, x: bufU, s: curSrcU, params: params, linear: linear, tg: tg256)
                    try addSourcePass(lib: lib, x: bufV, s: curSrcV, params: params, linear: linear, tg: tg256)

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
                    // Add source from double-buffered input
                    try addSourcePass(lib: lib, x: bufDens, s: curSrcDens, params: params, linear: linear, tg: tg256)

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
                if let displayTexture, let bufDens, let bufU, let bufV, let bufDiv, let bufP, let colormapTexture {
                    try visualizePass(lib: lib, interior: interior, tg: tg16, params: params, displayTexture: displayTexture, colormapTexture: colormapTexture, bufDens: bufDens, bufU: bufU, bufV: bufV, bufDiv: bufDiv, bufP: bufP)

                    try RenderPass {
                        try TextureBillboardPipeline(specifier: .texture2D(displayTexture))
                    }
                }
            }
        }
    }

    // MARK: - Visualization

    @ElementBuilder
    // swiftlint:disable:next function_parameter_count
    private func visualizePass(lib: ShaderNamespace, interior: MTLSize, tg: MTLSize, params: FluidParams, displayTexture: MTLTexture, colormapTexture: MTLTexture, bufDens: MTLBuffer, bufU: MTLBuffer, bufV: MTLBuffer, bufDiv: MTLBuffer, bufP: MTLBuffer) throws -> some Element {
        try ComputePass {
            switch visualization {
            case .density:
                try ComputePipeline(computeKernel: try lib.visualizeDensity) {
                    try ComputeDispatch(threadsPerGrid: interior, threadsPerThreadgroup: tg)
                        .parameter("dens", buffer: bufDens, offset: 0)
                        .parameter("output", texture: displayTexture)
                        .parameter("params", value: params)
                        .parameter("colormapTex", texture: colormapTexture)
                }
            case .velocity:
                try ComputePipeline(computeKernel: try lib.visualizeVelocity) {
                    try ComputeDispatch(threadsPerGrid: interior, threadsPerThreadgroup: tg)
                        .parameter("u", buffer: bufU, offset: 0)
                        .parameter("v", buffer: bufV, offset: 0)
                        .parameter("output", texture: displayTexture)
                        .parameter("params", value: params)
                }
            case .speed:
                try ComputePipeline(computeKernel: try lib.visualizeSpeed) {
                    try ComputeDispatch(threadsPerGrid: interior, threadsPerThreadgroup: tg)
                        .parameter("u", buffer: bufU, offset: 0)
                        .parameter("v", buffer: bufV, offset: 0)
                        .parameter("output", texture: displayTexture)
                        .parameter("params", value: params)
                        .parameter("colormapTex", texture: colormapTexture)
                }
            case .vorticity:
                try ComputePipeline(computeKernel: try lib.visualizeVorticity) {
                    try ComputeDispatch(threadsPerGrid: interior, threadsPerThreadgroup: tg)
                        .parameter("u", buffer: bufU, offset: 0)
                        .parameter("v", buffer: bufV, offset: 0)
                        .parameter("output", texture: displayTexture)
                        .parameter("params", value: params)
                        .parameter("colormapTex", texture: colormapTexture)
                }
            case .divergence:
                try ComputePipeline(computeKernel: try lib.visualizeDivergence) {
                    try ComputeDispatch(threadsPerGrid: interior, threadsPerThreadgroup: tg)
                        .parameter("div", buffer: bufDiv, offset: 0)
                        .parameter("output", texture: displayTexture)
                        .parameter("params", value: params)
                        .parameter("colormapTex", texture: colormapTexture)
                }
            case .pressure:
                try ComputePipeline(computeKernel: try lib.visualizePressure) {
                    try ComputeDispatch(threadsPerGrid: interior, threadsPerThreadgroup: tg)
                        .parameter("p", buffer: bufP, offset: 0)
                        .parameter("output", texture: displayTexture)
                        .parameter("params", value: params)
                        .parameter("colormapTex", texture: colormapTexture)
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
                    .parameter("factor", value: Float(0.99))
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
        guard !initialized || initializedN != gridN, let device else {
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

        // Double-buffered source inputs
        let srcA = device.makeBuffer(length: byteCount, options: .storageModeShared)
        let srcB = device.makeBuffer(length: byteCount, options: .storageModeShared)
        srcU = [srcA, srcB]
        let srcC = device.makeBuffer(length: byteCount, options: .storageModeShared)
        let srcD = device.makeBuffer(length: byteCount, options: .storageModeShared)
        srcV = [srcC, srcD]
        let srcE = device.makeBuffer(length: byteCount, options: .storageModeShared)
        let srcF = device.makeBuffer(length: byteCount, options: .storageModeShared)
        srcDens = [srcE, srcF]
        srcIndex = 0

        let allBuffers: [MTLBuffer?] = [
            bufU, bufV, bufUPrev, bufVPrev, bufDens, bufDensPrev, bufP, bufDiv,
            srcA, srcB, srcC, srcD, srcE, srcF
        ]
        for buf in allBuffers {
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
        guard let su = srcU[srcIndex], let sv = srcV[srcIndex], let sd = srcDens[srcIndex] else {
            return
        }
        let size = (gridN + 2) * (gridN + 2) * MemoryLayout<Float>.stride
        memset(su.contents(), 0, size)
        memset(sv.contents(), 0, size)
        memset(sd.contents(), 0, size)
    }

    private func writeInteraction(point: SIMD2<Float>, velocity: SIMD2<Float>, N: Int) {
        guard let su = srcU[srcIndex], let sv = srcV[srcIndex], let sd = srcDens[srcIndex] else {
            return
        }

        let densPtr = sd.contents().bindMemory(to: Float.self, capacity: (N + 2) * (N + 2))
        let uPtr = su.contents().bindMemory(to: Float.self, capacity: (N + 2) * (N + 2))
        let vPtr = sv.contents().bindMemory(to: Float.self, capacity: (N + 2) * (N + 2))

        let gi = Int(point.x * Float(N)) + 1
        let gj = Int(point.y * Float(N)) + 1
        let radius = max(2, N / 32)
        let force: Float = 20.0
        let densityAmount: Float = 10.0

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

    // MARK: - Colormap texture generation

    private func buildColormapTexture(_ map: Colormap) -> MTLTexture? {
        guard let device else {
            return nil
        }
        let width = 256
        let desc = MTLTextureDescriptor()
        desc.textureType = .type1D
        desc.pixelFormat = .rgba8Unorm
        desc.width = width
        desc.usage = [.shaderRead]
        desc.storageMode = .shared

        guard let texture = device.makeTexture(descriptor: desc) else {
            return nil
        }

        let stops = map.colorStops
        var pixels = [UInt8](repeating: 0, count: width * 4)
        for i in 0..<width {
            let t = Float(i) / Float(width - 1)
            let (r, g, b) = interpolateStops(stops, at: t)
            pixels[i * 4 + 0] = UInt8(clamping: Int(r * 255))
            pixels[i * 4 + 1] = UInt8(clamping: Int(g * 255))
            pixels[i * 4 + 2] = UInt8(clamping: Int(b * 255))
            pixels[i * 4 + 3] = 255
        }
        texture.replace(
            region: MTLRegionMake1D(0, width),
            mipmapLevel: 0,
            withBytes: pixels,
            bytesPerRow: width * 4
        )
        return texture
    }

    private func interpolateStops(_ stops: [(Float, Float, Float, Float)], at t: Float) -> (Float, Float, Float) {
        guard let first = stops.first else {
            return (0, 0, 0)
        }
        if t <= first.0 {
            return (first.1, first.2, first.3)
        }
        guard let last = stops.last else {
            return (0, 0, 0)
        }
        if t >= last.0 {
            return (last.1, last.2, last.3)
        }
        for i in 0..<(stops.count - 1) {
            let a = stops[i]
            let b = stops[i + 1]
            if t >= a.0, t <= b.0 {
                let f = (t - a.0) / (b.0 - a.0)
                return (
                    a.1 + (b.1 - a.1) * f,
                    a.2 + (b.2 - a.2) * f,
                    a.3 + (b.3 - a.3) * f
                )
            }
        }
        return (last.1, last.2, last.3)
    }
}

// MARK: - Colormap definitions

enum Visualization: String, CaseIterable, Identifiable {
    case density = "Density"
    case velocity = "Velocity"
    case speed = "Speed"
    case vorticity = "Vorticity"
    case divergence = "Divergence"
    case pressure = "Pressure"

    var id: String { rawValue }
}

enum Colormap: String, CaseIterable, Identifiable {
    case fire = "Fire"
    case smoke = "Smoke"
    case ocean = "Ocean"
    case viridis = "Viridis"
    case inferno = "Inferno"
    case magma = "Magma"
    case plasma = "Plasma"

    var id: String { rawValue }

    // Returns (position, r, g, b) stops for the colormap
    // swiftlint:disable function_body_length
    var colorStops: [(Float, Float, Float, Float)] {
        switch self {
        case .fire:
            return [
                (0.00, 0.00, 0.00, 0.00),
                (0.25, 0.50, 0.00, 0.00),
                (0.50, 1.00, 0.30, 0.00),
                (0.75, 1.00, 0.80, 0.10),
                (1.00, 1.00, 1.00, 0.90)
            ]
        case .smoke:
            return [
                (0.00, 0.00, 0.00, 0.00),
                (0.50, 0.40, 0.42, 0.45),
                (1.00, 1.00, 1.00, 1.00)
            ]
        case .ocean:
            return [
                (0.00, 0.00, 0.02, 0.10),
                (0.33, 0.00, 0.20, 0.50),
                (0.66, 0.10, 0.55, 0.85),
                (1.00, 0.80, 0.95, 1.00)
            ]
        case .viridis:
            // 9-stop approximation of matplotlib viridis
            return [
                (0.000, 0.267, 0.004, 0.329),
                (0.125, 0.282, 0.141, 0.458),
                (0.250, 0.245, 0.267, 0.530),
                (0.375, 0.192, 0.407, 0.556),
                (0.500, 0.128, 0.567, 0.551),
                (0.625, 0.153, 0.718, 0.492),
                (0.750, 0.360, 0.837, 0.373),
                (0.875, 0.667, 0.930, 0.180),
                (1.000, 0.993, 0.906, 0.144)
            ]
        case .inferno:
            return [
                (0.000, 0.001, 0.000, 0.014),
                (0.125, 0.090, 0.045, 0.225),
                (0.250, 0.258, 0.039, 0.406),
                (0.375, 0.434, 0.065, 0.418),
                (0.500, 0.610, 0.147, 0.340),
                (0.625, 0.776, 0.278, 0.208),
                (0.750, 0.910, 0.444, 0.074),
                (0.875, 0.978, 0.668, 0.053),
                (1.000, 0.988, 0.998, 0.645)
            ]
        case .magma:
            return [
                (0.000, 0.001, 0.000, 0.014),
                (0.125, 0.082, 0.048, 0.220),
                (0.250, 0.232, 0.060, 0.438),
                (0.375, 0.410, 0.057, 0.492),
                (0.500, 0.576, 0.148, 0.506),
                (0.625, 0.751, 0.267, 0.476),
                (0.750, 0.928, 0.412, 0.427),
                (0.875, 0.994, 0.624, 0.427),
                (1.000, 0.987, 0.991, 0.750)
            ]
        case .plasma:
            return [
                (0.000, 0.050, 0.030, 0.528),
                (0.125, 0.254, 0.014, 0.615),
                (0.250, 0.417, 0.001, 0.658),
                (0.375, 0.578, 0.015, 0.633),
                (0.500, 0.717, 0.135, 0.528),
                (0.625, 0.835, 0.278, 0.382),
                (0.750, 0.929, 0.441, 0.226),
                (0.875, 0.983, 0.637, 0.066),
                (1.000, 0.940, 0.975, 0.131)
            ]
        }
    }
    // swiftlint:enable function_body_length
}
