import DemoKit
import MetalSprocketsExamples
import SwiftUI

@MainActor let allDemos: [any DemoView.Type] = {
    var demos: [any DemoView.Type] = [
        EmptyDemoView.self,
        // TODO
        BlinnPhongDemoView.self,
        HitTestDemoView.self,
        SkyboxDemoView.self,
        TriangleDemoView.self,
        ComputeDemoView.self,
        DepthDemoView.self,
        MixedDemoView.self,
        BouncingTeapotsDemoView.self,
        StencilDemoView.self,
        LUTDemoView.self,
        GameOfLifeDemoView.self,
        AppleEventLogoDemoView.self,
        ColorAdjustDemoView.self,
        DebugShaderDemoView.self,
        PBRDemoView.self,
        SDFDemoView.self,
        PointCloudDemoView.self,
        ParticleEffectsDemoView.self,
        VideoPlaybackDemoView.self,
        PanoramaDemoView.self,
        WireframeDemoView.self,
        TrivialMeshDemoView.self,
        SceneGraphDemoView.self,
        GLTFDemoView.self,
        VoxelDemoView.self,
        GrassDemoView.self,
        SpiralParticlesDemoView.self,
        GraphicsContext3DDemoView.self,
        MetalCanvasDemoView.self,
        TiledSDFDemoView.self,
        TileAverageDemoView.self,
        RayTracingDemoView.self,
        GridDemoView.self,
        SkinningDemoView.self,
        RenderDemoView.self,
        ShadowMapDemoView.self,
        RayTracedShadowDemoView.self,
        SlugDebugDemoView.self,
        SlugMatrixRainDemoView.self,
        SlugSpinningSphereDemoView.self,
        SlugTextPanelDemoView.self,
        ShaderGraphDemoView.self,
        PhosphorDemoView.self,
        StamFluidDemoView.self
    ]

    #if os(macOS)
    demos += [
        OffscreenDemoView.self,
        SlugTerminalDemoView.self
    ]
    #endif

    #if os(iOS)
    demos += [
        MobileDemoView.self
    ]
    #endif

    #if os(visionOS)
    demos += [
        VisionOSDemoView.self,
        ImmersiveMatrixRainView.self
    ]
    #endif

    #if canImport(MetalFX)
    demos += [
        MetalFXDemoView.self
    ]
    #endif

    return demos
}()

struct EmptyDemoView: DemoView {
    static var metadata: DemoMetadata {
        DemoMetadata(name: "Empty", description: "An empty view.")
    }

    init() {
        // Empty initializer
    }

    var body: some View {
        Text("This view intentionally left blank")
    }
}

extension TriangleDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Triangle",
            description: "Colored triangle with GPU timing",
            longDescription: "The simplest MetalSprockets render pipeline: inline Metal source compiled at runtime into `VertexShader`/`FragmentShader`, wired up with `RenderView` and `Draw`.",
            group: "Basic"
        )
    }
}

extension GameOfLifeDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Game of Life",
            description: "GPU-driven cellular automaton",
            longDescription: "GPU-driven **cellular automaton** — a `ComputePass` updates a texture each frame, driving the entire simulation loop on the GPU.",
            group: "Basic"
        )
    }
}

extension StencilDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Stencil",
            description: "Stencil-masked triangle",
            longDescription: "Stencil texture creation, **blit pass** to populate the stencil attachment, and `StencilState` configuration to clip rendered geometry.",
            group: "Basic"
        )
    }
}

extension ComputeDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Compute",
            description: "Buffer-to-buffer copy via compute",
            longDescription: "Standalone `ComputePass` and `ComputeDispatch` without any rendering — just **buffer-to-buffer** data movement on the GPU.",
            group: "Basic"
        )
    }
}

extension DepthDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Depth",
            description: "Depth buffer visualization",
            longDescription: "Render-to-texture with separate **color** and **depth** outputs. Uses **stitchable visible functions** for post-processing the depth buffer.",
            group: "Complex"
        )
    }
}

#if canImport(MetalFX)
extension MetalFXDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "MetalFX",
            description: "MetalFX spatial upscaling",
            longDescription: "Integrating `MetalFXSpatial` upsampling into a MetalSprockets pipeline.",
            group: "Basic"
        )
    }
}
#endif

extension BouncingTeapotsDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Bouncing Teapots",
            description: "Physics-driven instanced teapots",
            longDescription: "**Instanced rendering** to an offscreen texture with optional `MetalFX` upscaling before presentation.",
            group: "Complex"
        )
    }
}

extension HitTestDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Hit Test",
            description: "GPU-based object picking",
            longDescription: "**Multi-pass** rendering with a parallel hit-test pass writing **geometry ID**, **instance ID**, **triangle ID**, **depth**, and **barycentric coordinates** to offscreen textures. Includes CPU readback of hit results.",
            group: "Complex"
        )
    }
}

extension SkyboxDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Skybox",
            description: "Cube-map skybox rendering",
            longDescription: "`SkyboxRenderPipeline` with a **cube texture** built from a cross-layout image. Also shows generating textures from SwiftUI views.",
            group: "Basic"
        )
    }
}

extension AppleEventLogoDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Apple Event Logo",
            description: "Thermal-style video effect",
            longDescription: "Chaining multiple `ComputePass` stages — **heat simulation**, **color remap**, **video blend** — in a single frame.",
            group: "Complex"
        )
    }
}

extension LUTDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "LUT",
            description: "Image color grading via LUTs",
            longDescription: "Compute-based image processing with **LUT** texture loading (2D PNG and 3D `.cube` formats) and `TextureBillboardPipeline` for display.",
            group: "Basic"
        )
    }
}

#if os(macOS)
extension OffscreenDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Offscreen",
            description: "Render to CGImage",
            longDescription: "Headless rendering with `OffscreenRenderer` — no `RenderView`, just render to a `CGImage`.",
            group: "Basic"
        )
    }
}
#endif

extension MixedDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Mixed",
            description: "Combined render and compute passes",
            longDescription: "Mixing **render** and **compute** passes in a single frame — geometry rendering followed by an edge-detection compute post-process that reads depth/color attachments.",
            group: "Complex"
        )
    }
}

extension ColorAdjustDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Color Adjust",
            description: "Compute-based color adjustments",
            longDescription: "Multiple compute shader functions (**multiply**, **gamma**, **HSV**, **levels**, **temperature/tint**, **vignette**, etc.) applied to an image, showing how to swap between different `ComputeKernel`s at runtime.",
            group: "In-progress"
        )
    }
}

extension DebugShaderDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Debug Shader",
            description: "Shader debug visualizations",
            longDescription: "`DebugRenderPipeline` with switchable fragment shader modes for visualizing mesh attributes — **normals**, **tangents**, **UVs**, **depth**, **wireframe**, etc.",
            group: "Rendering",
            keywords: ["MetalSprocketsAddOns"]
        )
    }
}

extension PBRDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "PBR",
            description: "Physically based rendering",
            longDescription: "`PBRShader` with **Cook-Torrance BRDF**, HDR environment reflections, animated lighting, and configurable material properties.",
            group: "Complex"
        )
    }
}

extension SDFDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "SDF",
            description: "3D SDF raymarching",
            longDescription: "Full-screen fragment shader **raymarching SDFs** with depth output, allowing integration with rasterized geometry via `WorldView`.",
            group: "Complex"
        )
    }
}

extension PointCloudDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Point Cloud",
            description: "Interactive torus point cloud",
            longDescription: "**Point primitive** rendering with depth testing from a CPU-generated `MTLBuffer`.",
            group: "Basic"
        )
    }
}

extension ParticleEffectsDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Particle Effects",
            description: "GPU compute particle system",
            longDescription: "**Compute-to-render buffer sharing**: a compute pass updates particle state each frame, then a render pass draws from the same `MTLBuffer`.",
            group: "Complex"
        )
    }
}

extension VideoPlaybackDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Video Playback",
            description: "Video with VCR distortion effect",
            longDescription: "Streaming `AVFoundation` video frames into Metal textures, rendered via `TextureBillboardPipeline` with an optional **VCR distortion** compute pass.",
            group: "Basic"
        )
    }
}

extension PanoramaDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Panorama",
            description: "Equirectangular panorama viewer",
            longDescription: "**Equirectangular-to-sphere** texture mapping with `WorldView` camera controls and an optional gamma-correction compute post-pass.",
            group: "Basic"
        )
    }
}

extension WireframeDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Wireframe",
            description: "Wireframe mesh rendering",
            longDescription: "`WireframeRenderPipeline` for **line-mode** mesh rendering, combined with `GridShader` and `AxisLinesRenderPipeline`.",
            group: "Basic"
        )
    }
}

extension TrivialMeshDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Trivial Mesh",
            description: "Procedural geometry primitives",
            longDescription: "`TrivialMesh` **procedural geometry** generation and conversion to renderable `Mesh` objects — platonic solids, 2D shapes, and curved surfaces.",
            group: "Rendering",
            keywords: ["MetalSprocketsAddOns"]
        )
    }
}

extension SceneGraphDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "SceneGraph",
            description: "Hierarchical scene graph rendering",
            longDescription: "`SceneGraph` construction with **recursive transform propagation**, rendered via `SceneGraphRenderPass` with PBR shading.",
            group: "Basic"
        )
    }
}

extension GLTFDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "GLTF",
            description: "glTF/GLB model loader and viewer",
            longDescription: "Loading **glTF/GLB** files, converting them to a `SceneGraph` via `GLTFSceneGraphGenerator`, and rendering with `SceneGraphRenderPass`.",
            group: "Complex"
        )
    }
}

extension VoxelDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Voxel",
            description: "Compute-raymarched voxel volumes",
            longDescription: "**3D texture** creation and compute-pass **raymarching** of voxel volumes, with MagicaVoxel `.vox` file import support.",
            group: "Complex"
        )
    }
}

extension GrassDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Grass",
            description: "Mesh-shader procedural grass",
            longDescription: "Metal **object and mesh shader** pipeline with per-point amplification — each input point generates multiple segmented grass blade geometry instances.",
            group: "Complex"
        )
    }
}

extension SpiralParticlesDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Spiral Particles",
            description: "Mesh-shader spiral particles",
            longDescription: "**Mesh shader geometry amplification** with fully procedural vertex generation — no vertex buffers, all geometry created in the `object`/`mesh` shader stages.",
            group: "Complex"
        )
    }
}

extension GraphicsContext3DDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "GraphicsContext3D",
            description: "3D stroked and filled paths with pixel-perfect line widths",
            longDescription: "`GraphicsContext3DRenderPipeline`: a SwiftUI `Canvas`-like API for **3D path drawing** with stroke/fill, backed by mesh-shader line rendering.",
            group: "Rendering",
            keywords: ["MetalSprocketsAddOns"]
        )
    }
}

extension MetalCanvasDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "MetalCanvas",
            description: "2D path rendering via mesh shaders",
            longDescription: "`MetalCanvas` and `MetalCanvasRenderPipeline`: GPU-accelerated **2D vector path stroking** using mesh shaders, accepting standard SwiftUI `Path` objects.",
            group: "Basic"
        )
    }
}

extension TiledSDFDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Tiled SDF",
            description: "Tile-culled 2D SDF rendering",
            longDescription: "**Tile-based compute dispatch** with threadgroup-level primitive culling — primitives are binned per tile into **threadgroup memory** to reduce global memory traffic.",
            group: "Complex"
        )
    }
}

extension RayTracingDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Ray Tracing",
            description: "Cornell box path tracer",
            longDescription: "Metal **ray tracing** APIs with hardware-accelerated `AccelerationStructure` intersection. Progressive path tracing of the classic Cornell box scene with diffuse global illumination.",
            group: "Complex"
        )
    }
}

extension GridDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Infinite Grid",
            systemImage: "grid",
            description: "An infinite ground plane grid with interactive camera",
            group: "Rendering",
            keywords: ["MetalSprocketsAddOns"]
        )
    }
}

extension RenderDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Spinning Cube",
            systemImage: "cube",
            description: "A rotating RGB cube with MSAA controls",
            group: "Rendering",
            keywords: ["MetalSprocketsAddOns"]
        )
    }
}

extension ShadowMapDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Shadow Map",
            systemImage: "shadow",
            description: "Multi-light shadow mapping with PCF and depth bias controls",
            group: "Rendering",
            keywords: ["MetalSprocketsAddOns"]
        )
    }
}

extension RayTracedShadowDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Ray Traced Shadows",
            systemImage: "rays",
            description: "Hardware-accelerated ray-traced shadows with acceleration structures",
            group: "Rendering",
            keywords: ["MetalSprocketsAddOns"]
        )
    }
}

extension SlugDebugDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Slug Debug",
            systemImage: "textformat",
            description: "Basic Slug text rendering test",
            group: "Slug",
            keywords: ["MetalSprocketsAddOns"]
        )
    }
}

extension SlugMatrixRainDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Matrix Rain",
            systemImage: "chevron.left.forwardslash.chevron.right",
            description: "Matrix-style falling text rendered with Slug",
            group: "Slug",
            keywords: ["MetalSprocketsAddOns"]
        )
    }
}

extension SlugSpinningSphereDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Spinning Sphere",
            systemImage: "globe",
            description: "Text mapped to a spinning sphere with Slug",
            group: "Slug",
            keywords: ["MetalSprocketsAddOns"]
        )
    }
}

extension SlugTextPanelDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Text Panel",
            systemImage: "text.alignleft",
            description: "Multi-language text rendered with Slug",
            group: "Slug",
            keywords: ["MetalSprocketsAddOns"]
        )
    }
}

#if os(macOS)
extension SlugTerminalDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Terminal",
            systemImage: "terminal",
            description: "Live terminal output rendered with Slug",
            group: "Slug",
            keywords: ["MetalSprocketsAddOns"]
        )
    }
}
#endif

#if os(iOS)
extension MobileDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Mobile",
            systemImage: "iphone",
            description: "AR-powered mobile rendering demo",
            group: "Platform",
            keywords: ["MetalSprocketsAddOns"]
        )
    }
}
#endif

#if os(visionOS)
extension VisionOSDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "VisionOS",
            systemImage: "visionpro",
            description: "Immersive visionOS stereo rendering",
            group: "Platform",
            keywords: ["MetalSprocketsAddOns"]
        )
    }
}

extension ImmersiveMatrixRainView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Immersive Matrix Rain",
            systemImage: "visionpro",
            description: "Matrix rain in immersive visionOS space",
            group: "Slug",
            keywords: ["MetalSprocketsAddOns"]
        )
    }
}
#endif

extension StamFluidDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Stam Fluid",
            description: "Interactive 2D Navier-Stokes fluid",
            longDescription: "GPU implementation of Jos Stam's \"Real-Time Fluid Dynamics for Games\" (GDC 2003). Full Navier-Stokes solver with diffusion, advection, and pressure projection via red-black Gauss-Seidel relaxation. Drag to inject smoke and apply forces.",
            group: "Complex"
        )
    }
}

extension TileAverageDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Tile Average",
            description: "Imageblock tile averaging",
            longDescription: "Metal **imageblock** APIs: tile memory allocation, `imageblock_data` load/store, and tile dispatch in the simplest possible example.",
            group: "Basic"
        )
    }
}

extension SkinningDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Skinning",
            description: "Skeletal mesh deformation with bones",
            longDescription: "**Skeletal animation** with a 2-bone rig deforming a capsule mesh. Vertex shader applies per-vertex bone weights to blend between bone transforms, animating between straight and L-shaped poses.",
            group: "Basic"
        )
    }
}
