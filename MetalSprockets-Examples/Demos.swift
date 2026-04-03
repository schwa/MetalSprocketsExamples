import DemoKit
import MetalSprocketsExamples
import SwiftUI

@MainActor let allDemos: [any DemoView.Type] = {
    var demos: [any DemoView.Type] = [
        EmptyDemoView.self,
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
        DebugShadersDemoView.self,
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
        TileAverageDemoView.self
    ]

    #if os(macOS)
    demos += [
        OffscreenDemoView.self
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
            group: "Basic",
            keywords: ["animated", "configurable"]
        )
    }
}

extension GameOfLifeDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Game of Life",
            description: "GPU-driven cellular automaton",
            longDescription: "GPU-driven **cellular automaton** — a `ComputePass` updates a texture each frame, driving the entire simulation loop on the GPU.",
            group: "Basic",
            keywords: ["animated", "configurable"]
        )
    }
}

extension StencilDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Stencil Buffer",
            description: "Stencil-masked triangle",
            longDescription: "Stencil texture creation, **blit pass** to populate the stencil attachment, and `StencilState` configuration to clip rendered geometry.",
            group: "Basic",
            keywords: []
        )
    }
}

extension ComputeDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Compute",
            description: "Buffer-to-buffer copy via compute",
            longDescription: "Standalone `ComputePass` and `ComputeDispatch` without any rendering — just **buffer-to-buffer** data movement on the GPU.",
            group: "Basic",
            keywords: ["needs-work"]
        )
    }
}

extension DepthDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Depth Buffer",
            description: "Depth buffer visualization",
            longDescription: "Render-to-texture with separate **color** and **depth** outputs. Uses **stitchable visible functions** for post-processing the depth buffer.",
            group: "Complex",
            keywords: ["configurable"]
        )
    }
}

#if canImport(MetalFX)
extension MetalFXDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "MetalFX Upscaling",
            description: "MetalFX spatial upscaling",
            longDescription: "Integrating `MetalFXSpatial` upsampling into a MetalSprockets pipeline.",
            group: "Basic",
            keywords: ["metalfx", "needs-work", "configurable"]
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
            group: "Complex",
            keywords: ["metalfx", "animated", "multipass"]
        )
    }
}

extension BlinnPhongDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Blinn-Phong Lighting",
            description: "Blinn-Phong lit teapots with skybox",
            longDescription: "`BlinnPhongShader` element with multiple models, **animated lighting**, skybox, and `WorldView` camera controls.",
            group: "Basic",
            keywords: ["lighting", "multipass", "animated"]
        )
    }
}

extension HitTestDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Hit Test Demo",
            description: "GPU-based object picking",
            longDescription: "**Multi-pass** rendering with a parallel hit-test pass writing **geometry ID**, **instance ID**, **triangle ID**, **depth**, and **barycentric coordinates** to offscreen textures. Includes CPU readback of hit results.",
            group: "Complex",
            keywords: ["hit-test", "picking", "multipass", "configurable"]
        )
    }
}

extension SkyboxDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Skybox",
            description: "Cube-map skybox rendering",
            longDescription: "`SkyboxRenderPipeline` with a **cube texture** built from a cross-layout image. Also shows generating textures from SwiftUI views.",
            group: "Basic",
            keywords: ["configurable"]
        )
    }
}

extension AppleEventLogoDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Apple Event Logo",
            description: "Thermal-style video effect",
            longDescription: "Chaining multiple `ComputePass` stages — **heat simulation**, **color remap**, **video blend** — in a single frame.",
            group: "Complex",
            keywords: ["needs-work", "animated", "video"]
        )
    }
}

extension LUTDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "LUT Color Grading",
            description: "Image color grading via LUTs",
            longDescription: "Compute-based image processing with **LUT** texture loading (2D PNG and 3D `.cube` formats) and `TextureBillboardPipeline` for display.",
            group: "Basic",
            keywords: ["post-processing", "configurable"]
        )
    }
}

#if os(macOS)
extension OffscreenDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Offscreen Rendering",
            description: "Render to CGImage",
            longDescription: "Headless rendering with `OffscreenRenderer` — no `RenderView`, just render to a `CGImage`.",
            group: "Basic",
            keywords: ["needs-work"]
        )
    }
}
#endif

extension MixedDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Mixed Techniques",
            description: "Combined render and compute passes",
            longDescription: "Mixing **render** and **compute** passes in a single frame — geometry rendering followed by an edge-detection compute post-process that reads depth/color attachments.",
            group: "Complex",
            keywords: ["multipass", "animated"]
        )
    }
}

extension ColorAdjustDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Color Adjust",
            description: "Compute-based color adjustments",
            longDescription: "Multiple compute shader functions (**multiply**, **gamma**, **HSV**, **levels**, **temperature/tint**, **vignette**, etc.) applied to an image, showing how to swap between different `ComputeKernel`s at runtime.",
            group: "In-progress",
            keywords: ["configurable"]
        )
    }
}

extension DebugShadersDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Debug Shaders",
            description: "Shader debug visualizations",
            longDescription: "`DebugRenderPipeline` with switchable fragment shader modes for visualizing mesh attributes — **normals**, **tangents**, **UVs**, **depth**, **wireframe**, etc.",
            group: "Basic",
            keywords: []
        )
    }
}

extension PBRDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "PBR Rendering",
            description: "Physically based rendering",
            longDescription: "`PBRShader` with **Cook-Torrance BRDF**, HDR environment reflections, animated lighting, and configurable material properties.",
            group: "Complex",
            keywords: []
        )
    }
}

extension SDFDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "SDF Raymarching",
            description: "3D SDF raymarching",
            longDescription: "Full-screen fragment shader **raymarching SDFs** with depth output, allowing integration with rasterized geometry via `WorldView`.",
            group: "Complex",
            keywords: ["animated", "raymarching", "configurable"]
        )
    }
}

extension PointCloudDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Point Cloud",
            description: "Interactive torus point cloud",
            longDescription: "**Point primitive** rendering with depth testing from a CPU-generated `MTLBuffer`.",
            group: "Basic",
            keywords: ["points", "interactive", "configurable"]
        )
    }
}

extension ParticleEffectsDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Particle Effects",
            description: "GPU compute particle system",
            longDescription: "**Compute-to-render buffer sharing**: a compute pass updates particle state each frame, then a render pass draws from the same `MTLBuffer`.",
            group: "Complex",
            keywords: ["compute", "animated", "configurable"]
        )
    }
}

extension VideoPlaybackDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Video Playback",
            description: "Video with VCR distortion effect",
            longDescription: "Streaming `AVFoundation` video frames into Metal textures, rendered via `TextureBillboardPipeline` with an optional **VCR distortion** compute pass.",
            group: "Basic",
            keywords: ["video", "billboard", "configurable"]
        )
    }
}

extension PanoramaDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "360° Panorama",
            description: "Equirectangular panorama viewer",
            longDescription: "**Equirectangular-to-sphere** texture mapping with `WorldView` camera controls and an optional gamma-correction compute post-pass.",
            group: "Basic",
            keywords: ["configurable"]
        )
    }
}

extension WireframeDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Wireframe Teapot",
            description: "Wireframe mesh rendering",
            longDescription: "`WireframeRenderPipeline` for **line-mode** mesh rendering, combined with `GridShader` and `AxisLinesRenderPipeline`.",
            group: "Basic",
            keywords: []
        )
    }
}

extension TrivialMeshDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Trivial Mesh",
            description: "Procedural geometry primitives",
            longDescription: "`TrivialMesh` **procedural geometry** generation and conversion to renderable `Mesh` objects — platonic solids, 2D shapes, and curved surfaces.",
            group: "Basic",
            keywords: ["mesh", "procedural", "lighting", "animated", "configurable"]
        )
    }
}

extension SceneGraphDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Scene Graph",
            description: "Hierarchical scene graph rendering",
            longDescription: "`SceneGraph` construction with **recursive transform propagation**, rendered via `SceneGraphRenderPass` with PBR shading.",
            group: "Basic",
            keywords: ["scene", "graph", "lighting"]
        )
    }
}

extension GLTFDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "glTF Model Viewer",
            description: "glTF/GLB model loader and viewer",
            longDescription: "Loading **glTF/GLB** files, converting them to a `SceneGraph` via `GLTFSceneGraphGenerator`, and rendering with `SceneGraphRenderPass`.",
            group: "Complex",
            keywords: []
        )
    }
}

extension VoxelDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Voxel Renderer",
            description: "Compute-raymarched voxel volumes",
            longDescription: "**3D texture** creation and compute-pass **raymarching** of voxel volumes, with MagicaVoxel `.vox` file import support.",
            group: "Complex",
            keywords: ["configurable"]
        )
    }
}

extension GrassDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Grass Sphere",
            description: "Mesh-shader procedural grass",
            longDescription: "Metal **object and mesh shader** pipeline with per-point amplification — each input point generates multiple segmented grass blade geometry instances.",
            group: "Complex",
            keywords: ["mesh-shaders", "procedural", "animated", "configurable"]
        )
    }
}

extension SpiralParticlesDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Spiral Particles",
            description: "Mesh-shader spiral particles",
            longDescription: "**Mesh shader geometry amplification** with fully procedural vertex generation — no vertex buffers, all geometry created in the `object`/`mesh` shader stages.",
            group: "Complex",
            keywords: ["mesh-shaders", "particles", "animated", "procedural", "configurable"]
        )
    }
}

extension GraphicsContext3DDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "GraphicsContext3D",
            description: "Canvas-style 3D path drawing",
            longDescription: "`GraphicsContext3DRenderPipeline`: a SwiftUI `Canvas`-like API for **3D path drawing** with stroke/fill, backed by mesh-shader line rendering.",
            group: "Basic",
            keywords: ["3d", "path", "canvas", "configurable"]
        )
    }
}

extension MetalCanvasDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "MetalCanvas",
            description: "2D path rendering via mesh shaders",
            longDescription: "`MetalCanvas` and `MetalCanvasRenderPipeline`: GPU-accelerated **2D vector path stroking** using mesh shaders, accepting standard SwiftUI `Path` objects.",
            group: "Basic",
            keywords: ["2d", "path", "canvas", "mesh-shaders", "configurable"]
        )
    }
}

extension TiledSDFDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Tiled SDF (2D)",
            description: "Tile-culled 2D SDF rendering",
            longDescription: "**Tile-based compute dispatch** with threadgroup-level primitive culling — primitives are binned per tile into **threadgroup memory** to reduce global memory traffic.",
            group: "Complex",
            keywords: ["compute", "sdf", "tiled", "animated", "2d", "configurable"]
        )
    }
}

extension TileAverageDemoView: @retroactive DemoView {
    public static var metadata: DemoMetadata {
        DemoMetadata(
            name: "Hello Imageblock",
            description: "Imageblock tile averaging",
            longDescription: "Metal **imageblock** APIs: tile memory allocation, `imageblock_data` load/store, and tile dispatch in the simplest possible example.",
            group: "Basic",
            keywords: ["imageblock", "tile", "2d", "configurable"]
        )
    }
}
