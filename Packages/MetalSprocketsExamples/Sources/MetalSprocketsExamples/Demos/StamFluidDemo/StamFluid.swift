import Foundation
import Metal
import MetalSprockets
import MetalSprocketsAddOns
import MetalSprocketsExampleShaders
import MetalSprocketsSupport
import simd

/// GPU implementation of Jos Stam's "Real-Time Fluid Dynamics for Games" (GDC 2003).
/// Full Navier-Stokes solver using 2D textures and MetalSprockets compute elements.
struct StamFluid: Element {
    @MSEnvironment(\.device)
    var device

    // Simulation textures (r32Float, (N+2)×(N+2))
    @MSState private var texU: MTLTexture?
    @MSState private var texV: MTLTexture?
    @MSState private var texUPrev: MTLTexture?
    @MSState private var texVPrev: MTLTexture?
    @MSState private var texDens: MTLTexture?
    @MSState private var texDensPrev: MTLTexture?
    @MSState private var texP: MTLTexture?
    @MSState private var texDiv: MTLTexture?

    @MSState private var displayTexture: MTLTexture?
    @MSState private var colormapTexture: MTLTexture?
    @MSState private var activeColormap: Colormap = .fire
    @MSState private var initialized: Bool = false
    @MSState private var initializedN: Int = 0
    @MSState private var resourceCollection: ResourceCollection?

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

    struct Splat {
        var center: SIMD2<Int32>
        var radius: Int32
        var amount: Float
    }

    struct VisualizeParams {
        var scale: Float
        var bias: Float
        var mode: Int32
    }

    // swiftlint:disable:next line_length
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

    @MSState
    private var lib = ShaderLibrary.examples.namespaced("StamFluidShader")

    var body: some Element {
        get throws {
            let N = UInt32(gridN)

            let params = FluidParams(N: N, dt: 0.1, diff: diffusion, visc: viscosity)
            let interior = MTLSize(width: Int(N), height: Int(N), depth: 1)
            let fullGrid = MTLSize(width: Int(N) + 2, height: Int(N) + 2, depth: 1)
            let tg16 = MTLSize(width: 16, height: 16, depth: 1)
            let resourceCollection = try self.resourceCollection ?? makeResourceCollection()

            return try Group {
                // One encoder for the whole solver: steps are ordered with cheap EncoderBarriers, not a pass and a
                // queue-wide barrier per dispatch (that was ~230 encoders per frame).
                try ComputePass(label: "Stam Fluid") {
                    // Waits for the previous frame's solver, and for its render pass to finish sampling the display.
                    QueueBarrier(after: [.dispatch, .blit, .fragment], before: [.dispatch, .blit])

                    if isRunning, let texU, let texV, let texUPrev, let texVPrev, let texDens, let texDensPrev, let texP, let texDiv {
                        let a_visc = params.dt * params.visc * Float(N) * Float(N)
                        let a_diff = params.dt * params.diff * Float(N) * Float(N)
                        let splats = interactionSplats()

                        // === Velocity step ===
                        if let splats {
                            try addSourcePass(lib: lib, x: texU, splat: splats.u, params: params, fullGrid: fullGrid, tg: tg16)
                            try addSourcePass(lib: lib, x: texV, splat: splats.v, params: params, fullGrid: fullGrid, tg: tg16)
                        }

                        try blitCopyTex(from: texU, to: texUPrev)
                        try diffusePass(lib: lib, x: texU, x0: texUPrev, b: 1, a: a_visc, params: params, N: N, interior: interior, tg: tg16)

                        try blitCopyTex(from: texV, to: texVPrev)
                        try diffusePass(lib: lib, x: texV, x0: texVPrev, b: 2, a: a_visc, params: params, N: N, interior: interior, tg: tg16)

                        try projectPass(lib: lib, u: texU, v: texV, p: texP, div: texDiv, params: params, N: N, interior: interior, tg: tg16)

                        try blitCopyTex(from: texU, to: texUPrev)
                        try blitCopyTex(from: texV, to: texVPrev)
                        try advectPass(lib: lib, d: texU, d0: texUPrev, u: texUPrev, v: texVPrev, b: 1, params: params, N: N, interior: interior, tg: tg16)
                        try advectPass(lib: lib, d: texV, d0: texVPrev, u: texUPrev, v: texVPrev, b: 2, params: params, N: N, interior: interior, tg: tg16)

                        try projectPass(lib: lib, u: texU, v: texV, p: texP, div: texDiv, params: params, N: N, interior: interior, tg: tg16)

                        // === Density step ===
                        if let splats {
                            try addSourcePass(lib: lib, x: texDens, splat: splats.density, params: params, fullGrid: fullGrid, tg: tg16)
                        }

                        try blitCopyTex(from: texDens, to: texDensPrev)
                        try diffusePass(lib: lib, x: texDens, x0: texDensPrev, b: 0, a: a_diff, params: params, N: N, interior: interior, tg: tg16)

                        try blitCopyTex(from: texDens, to: texDensPrev)
                        try advectPass(lib: lib, d: texDens, d0: texDensPrev, u: texU, v: texV, b: 0, params: params, N: N, interior: interior, tg: tg16)

                        try decayPass(lib: lib, x: texDens, fullGrid: fullGrid, tg: tg16)
                    }

                    // === Visualize ===
                    if let displayTexture, let texDens, let texU, let texV, let texDiv, let texP, let colormapTexture {
                        try visualizePass(lib: lib, interior: interior, tg: tg16, params: params, display: displayTexture, cmap: colormapTexture, dens: texDens, u: texU, v: texV, div: texDiv, p: texP)
                    }
                }

                if let displayTexture {
                    try RenderPass {
                        QueueBarrier(after: .dispatch, before: .fragment)
                        try TextureBillboardPipeline(specifier: .texture2D(displayTexture))
                    }
                }
            }
            .useResourceCollection(resourceCollection)
            // Allocation and colormap rebuilds used to happen inline at the top of body. See #385.
            // The guards above cover the first frame, which runs before setup.
            .onSetupEnter { _ in
                try setupTexturesIfNeeded()
                try rebuildColormapTextureIfNeeded()
            }
            .onChange(of: gridN) {
                do { try setupTexturesIfNeeded() } catch { assertionFailure("\(error)") }
            }
            .onChange(of: colormap) {
                do { try rebuildColormapTextureIfNeeded() } catch { assertionFailure("\(error)") }
            }
        }
    }

    private func makeResourceCollection() throws -> ResourceCollection {
        let collection = try ResourceCollection(device: device.orThrow(.missingEnvironment("device")))
        resourceCollection = collection
        return collection
    }

    private var allTextures: [MTLTexture?] {
        [texU, texV, texUPrev, texVPrev, texDens, texDensPrev, texP, texDiv, displayTexture]
    }

    // Sources are computed on the GPU from these values, so no CPU-written texture can be in flight.
    private func interactionSplats() -> (u: Splat, v: Splat, density: Splat)? {
        guard interactionActive, let point = interactionPoint, let velocity = interactionVelocity else {
            return nil
        }
        let center = SIMD2<Int32>(Int32(point.x * Float(gridN)) + 1, Int32(point.y * Float(gridN)) + 1)
        let radius = Int32(max(2, gridN / 32))
        let force: Float = 20.0
        let densityAmount: Float = 10.0
        return (
            u: Splat(center: center, radius: radius, amount: force * velocity.x),
            v: Splat(center: center, radius: radius, amount: force * velocity.y),
            density: Splat(center: center, radius: radius, amount: densityAmount)
        )
    }

    /// Rebuilds the colormap texture when the selected colormap changes.
    private func rebuildColormapTextureIfNeeded() throws {
        guard colormapTexture == nil || activeColormap != colormap else {
            return
        }
        let old = colormapTexture
        colormapTexture = buildColormapTexture(colormap)
        activeColormap = colormap
        try resourceCollection?.replace([old], with: [colormapTexture])
    }

    // MARK: - Visualization

    @ElementBuilder
    // swiftlint:disable:next function_parameter_count
    private func visualizePass(lib: ShaderNamespace, interior: MTLSize, tg: MTLSize, params: FluidParams, display: MTLTexture, cmap: MTLTexture, dens: MTLTexture, u: MTLTexture, v: MTLTexture, div: MTLTexture, p: MTLTexture) throws -> some Element {
        try orderedPass {
            switch visualization {
            case .velocity:
                try ComputePipeline(computeKernel: try lib.visualizeVelocity) {
                    try ComputeDispatch(threadsPerGrid: interior, threadsPerThreadgroup: tg)
                        .parameter("u", texture: u)
                        .parameter("v", texture: v)
                        .parameter("output", texture: display)
                        .parameter("params", value: params)
                }
            default:
                try colormapDispatch(lib: lib, interior: interior, tg: tg, params: params, display: display, cmap: cmap, dens: dens, u: u, v: v, div: div, p: p)
            }
        }
    }

    @ElementBuilder
    // swiftlint:disable:next function_parameter_count
    private func colormapDispatch(lib: ShaderNamespace, interior: MTLSize, tg: MTLSize, params: FluidParams, display: MTLTexture, cmap: MTLTexture, dens: MTLTexture, u: MTLTexture, v: MTLTexture, div: MTLTexture, p: MTLTexture) throws -> some Element {
        let (texA, texB, vizParams) = visualizationConfig(dens: dens, u: u, v: v, div: div, p: p)
        try ComputePipeline(computeKernel: try lib.visualizeColormap) {
            try ComputeDispatch(threadsPerGrid: interior, threadsPerThreadgroup: tg)
                .parameter("texA", texture: texA)
                .parameter("texB", texture: texB)
                .parameter("output", texture: display)
                .parameter("colormapTex", texture: cmap)
                .parameter("params", value: params)
                .parameter("vizParams", value: vizParams)
        }
    }

    private func visualizationConfig(dens: MTLTexture, u: MTLTexture, v: MTLTexture, div: MTLTexture, p: MTLTexture) -> (MTLTexture, MTLTexture, VisualizeParams) {
        switch visualization {
        case .density:
            return (dens, dens, VisualizeParams(scale: 1.0, bias: 0.0, mode: 0))
        case .speed:
            return (u, v, VisualizeParams(scale: 5.0, bias: 0.0, mode: 1))
        case .vorticity:
            return (u, v, VisualizeParams(scale: 0.5, bias: 0.5, mode: 2))
        case .divergence:
            return (div, div, VisualizeParams(scale: Float(gridN) * 10.0, bias: 0.5, mode: 0))
        case .pressure:
            return (p, p, VisualizeParams(scale: Float(gridN) * 10.0, bias: 0.5, mode: 0))
        case .velocity:
            return (u, v, VisualizeParams(scale: 1.0, bias: 0.0, mode: 0))
        }
    }

    // MARK: - Solver element builders

    @ElementBuilder
    private func addSourcePass(lib: ShaderNamespace, x: MTLTexture, splat: Splat, params: FluidParams, fullGrid: MTLSize, tg: MTLSize) throws -> some Element {
        try orderedPass {
            try ComputePipeline(computeKernel: try lib.addSplat) {
                try ComputeDispatch(threadsPerGrid: fullGrid, threadsPerThreadgroup: tg)
                    .parameter("x", texture: x)
                    .parameter("params", value: params)
                    .parameter("splat", value: splat)
            }
        }
    }

    // Every solver step reads what the previous one wrote. Metal 4 does not track hazards inside an encoder either.
    @ElementBuilder
    private func orderedPass<Content: Element>(@ElementBuilder content: () throws -> Content) throws -> some Element {
        EncoderBarrier(after: [.dispatch, .blit], before: [.dispatch, .blit])
        try content()
    }

    @ElementBuilder
    private func blitCopyTex(from src: MTLTexture, to dst: MTLTexture) throws -> some Element {
        try orderedPass {
            ComputeCommand { encoder in
                encoder.copy(sourceTexture: src, destinationTexture: dst)
            }
            .useComputeResources([src, dst], usage: [.read, .write])
        }
    }

    @ElementBuilder
    private func diffusePass(lib: ShaderNamespace, x: MTLTexture, x0: MTLTexture, b: Int, a: Float, params: FluidParams, N: UInt32, interior: MTLSize, tg: MTLSize) throws -> some Element {
        ForEach(0..<20, id: \.self) { _ in
            try orderedPass {
                try ComputePipeline(computeKernel: try lib.diffuseRedBlack) {
                    try ComputeDispatch(threadsPerGrid: interior, threadsPerThreadgroup: tg)
                        .parameter("x", texture: x)
                        .parameter("x0", texture: x0)
                        .parameter("params", value: params)
                        .parameter("colorPass", value: Int32(0))
                        .parameter("a", value: a)
                }
            }
            try orderedPass {
                try ComputePipeline(computeKernel: try lib.diffuseRedBlack) {
                    try ComputeDispatch(threadsPerGrid: interior, threadsPerThreadgroup: tg)
                        .parameter("x", texture: x)
                        .parameter("x0", texture: x0)
                        .parameter("params", value: params)
                        .parameter("colorPass", value: Int32(1))
                        .parameter("a", value: a)
                }
            }
        }
        try boundaryPass(lib: lib, x: x, b: b, params: params, N: N)
    }

    @ElementBuilder
    private func advectPass(lib: ShaderNamespace, d: MTLTexture, d0: MTLTexture, u: MTLTexture, v: MTLTexture, b: Int, params: FluidParams, N: UInt32, interior: MTLSize, tg: MTLSize) throws -> some Element {
        try orderedPass {
            try ComputePipeline(computeKernel: try lib.advect) {
                try ComputeDispatch(threadsPerGrid: interior, threadsPerThreadgroup: tg)
                    .parameter("d", texture: d)
                    .parameter("d0", texture: d0)
                    .parameter("u", texture: u)
                    .parameter("v", texture: v)
                    .parameter("params", value: params)
            }
        }
        try boundaryPass(lib: lib, x: d, b: b, params: params, N: N)
    }

    @ElementBuilder
    private func projectPass(lib: ShaderNamespace, u: MTLTexture, v: MTLTexture, p: MTLTexture, div: MTLTexture, params: FluidParams, N: UInt32, interior: MTLSize, tg: MTLSize) throws -> some Element {
        try orderedPass {
            try ComputePipeline(computeKernel: try lib.projectDivergence) {
                try ComputeDispatch(threadsPerGrid: interior, threadsPerThreadgroup: tg)
                    .parameter("div", texture: div)
                    .parameter("p", texture: p)
                    .parameter("u", texture: u)
                    .parameter("v", texture: v)
                    .parameter("params", value: params)
            }
        }
        try boundaryPass(lib: lib, x: div, b: 0, params: params, N: N)
        try boundaryPass(lib: lib, x: p, b: 0, params: params, N: N)

        ForEach(0..<20, id: \.self) { _ in
            try orderedPass {
                try ComputePipeline(computeKernel: try lib.projectPressureRedBlack) {
                    try ComputeDispatch(threadsPerGrid: interior, threadsPerThreadgroup: tg)
                        .parameter("p", texture: p)
                        .parameter("div", texture: div)
                        .parameter("params", value: params)
                        .parameter("colorPass", value: Int32(0))
                }
            }
            try orderedPass {
                try ComputePipeline(computeKernel: try lib.projectPressureRedBlack) {
                    try ComputeDispatch(threadsPerGrid: interior, threadsPerThreadgroup: tg)
                        .parameter("p", texture: p)
                        .parameter("div", texture: div)
                        .parameter("params", value: params)
                        .parameter("colorPass", value: Int32(1))
                }
            }
        }
        try boundaryPass(lib: lib, x: p, b: 0, params: params, N: N)

        try orderedPass {
            try ComputePipeline(computeKernel: try lib.projectGradientSubtract) {
                try ComputeDispatch(threadsPerGrid: interior, threadsPerThreadgroup: tg)
                    .parameter("u", texture: u)
                    .parameter("v", texture: v)
                    .parameter("p", texture: p)
                    .parameter("params", value: params)
            }
        }
        try boundaryPass(lib: lib, x: u, b: 1, params: params, N: N)
        try boundaryPass(lib: lib, x: v, b: 2, params: params, N: N)
    }

    @ElementBuilder
    private func decayPass(lib: ShaderNamespace, x: MTLTexture, fullGrid: MTLSize, tg: MTLSize) throws -> some Element {
        try orderedPass {
            try ComputePipeline(computeKernel: try lib.decay) {
                try ComputeDispatch(threadsPerGrid: fullGrid, threadsPerThreadgroup: tg)
                    .parameter("x", texture: x)
                    .parameter("factor", value: Float(0.99))
            }
        }
    }

    @ElementBuilder
    private func boundaryPass(lib: ShaderNamespace, x: MTLTexture, b: Int, params: FluidParams, N: UInt32) throws -> some Element {
        try orderedPass {
            try ComputePipeline(computeKernel: try lib.setBoundary) {
                try ComputeDispatch(threadsPerGrid: MTLSize(width: Int(N) + 1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: min(256, Int(N) + 1), height: 1, depth: 1))
                    .parameter("x", texture: x)
                    .parameter("params", value: params)
                    .parameter("b", value: Int32(b))
            }
        }
    }

    // MARK: - Texture setup

    private func setupTexturesIfNeeded() throws {
        guard !initialized || initializedN != gridN, let device else {
            return
        }
        let oldTextures = allTextures

        let texSize = gridN + 2

        func makeField() -> MTLTexture? {
            device.makeTexture2D(pixelFormat: .r32Float, width: texSize, height: texSize, storageMode: .shared, label: "Fluid Field")
        }

        texU = makeField()
        texV = makeField()
        texUPrev = makeField()
        texVPrev = makeField()
        texDens = makeField()
        texDensPrev = makeField()
        texP = makeField()
        texDiv = makeField()

        // Clear all textures
        let zeros = [Float](repeating: 0, count: texSize * texSize)
        let bytesPerRow = texSize * MemoryLayout<Float>.stride
        let region = MTLRegionMake2D(0, 0, texSize, texSize)
        let fieldTextures: [MTLTexture?] = [texU, texV, texUPrev, texVPrev, texDens, texDensPrev, texP, texDiv]
        for tex in fieldTextures {
            tex?.replace(region: region, mipmapLevel: 0, withBytes: zeros, bytesPerRow: bytesPerRow)
        }

        // Display texture (rgba8, N×N interior only)
        displayTexture = device.makeTexture2D(pixelFormat: .rgba8Unorm, width: gridN, height: gridN, storageMode: .private, label: "Fluid Display")

        initialized = true
        initializedN = gridN
        try resourceCollection?.replace(oldTextures, with: allTextures)
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
        texture.replace(region: MTLRegionMake1D(0, width), mipmapLevel: 0, withBytes: pixels, bytesPerRow: width * 4)
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

// MARK: - Supporting types

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

    // swiftlint:disable function_body_length
    var colorStops: [(Float, Float, Float, Float)] {
        switch self {
        case .fire:
            return [
                (0.00, 0.00, 0.00, 0.00), (0.25, 0.50, 0.00, 0.00),
                (0.50, 1.00, 0.30, 0.00), (0.75, 1.00, 0.80, 0.10),
                (1.00, 1.00, 1.00, 0.90)
            ]
        case .smoke:
            return [
                (0.00, 0.00, 0.00, 0.00), (0.50, 0.40, 0.42, 0.45),
                (1.00, 1.00, 1.00, 1.00)
            ]
        case .ocean:
            return [
                (0.00, 0.00, 0.02, 0.10), (0.33, 0.00, 0.20, 0.50),
                (0.66, 0.10, 0.55, 0.85), (1.00, 0.80, 0.95, 1.00)
            ]
        case .viridis:
            return [
                (0.000, 0.267, 0.004, 0.329), (0.125, 0.282, 0.141, 0.458),
                (0.250, 0.245, 0.267, 0.530), (0.375, 0.192, 0.407, 0.556),
                (0.500, 0.128, 0.567, 0.551), (0.625, 0.153, 0.718, 0.492),
                (0.750, 0.360, 0.837, 0.373), (0.875, 0.667, 0.930, 0.180),
                (1.000, 0.993, 0.906, 0.144)
            ]
        case .inferno:
            return [
                (0.000, 0.001, 0.000, 0.014), (0.125, 0.090, 0.045, 0.225),
                (0.250, 0.258, 0.039, 0.406), (0.375, 0.434, 0.065, 0.418),
                (0.500, 0.610, 0.147, 0.340), (0.625, 0.776, 0.278, 0.208),
                (0.750, 0.910, 0.444, 0.074), (0.875, 0.978, 0.668, 0.053),
                (1.000, 0.988, 0.998, 0.645)
            ]
        case .magma:
            return [
                (0.000, 0.001, 0.000, 0.014), (0.125, 0.082, 0.048, 0.220),
                (0.250, 0.232, 0.060, 0.438), (0.375, 0.410, 0.057, 0.492),
                (0.500, 0.576, 0.148, 0.506), (0.625, 0.751, 0.267, 0.476),
                (0.750, 0.928, 0.412, 0.427), (0.875, 0.994, 0.624, 0.427),
                (1.000, 0.987, 0.991, 0.750)
            ]
        case .plasma:
            return [
                (0.000, 0.050, 0.030, 0.528), (0.125, 0.254, 0.014, 0.615),
                (0.250, 0.417, 0.001, 0.658), (0.375, 0.578, 0.015, 0.633),
                (0.500, 0.717, 0.135, 0.528), (0.625, 0.835, 0.278, 0.382),
                (0.750, 0.929, 0.441, 0.226), (0.875, 0.983, 0.637, 0.066),
                (1.000, 0.940, 0.975, 0.131)
            ]
        }
    }
    // swiftlint:enable function_body_length
}
