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
            longDescription: "Renders a single triangle from inline Metal shader source. Displays GPU and kernel timing metrics. Demonstrates the simplest possible MetalSprockets render pipeline with RenderView, VertexShader, FragmentShader, and Draw.",
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
            longDescription: "Runs Conway's Game of Life entirely on the GPU using compute shaders. Supports multiple initial patterns (glider, random, clear) and play/pause control. Shows how to use a compute pass to update a texture each frame.",
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
            longDescription: "Blits a checkerboard pattern into the stencil attachment, then draws a star clipped by the stencil test. Demonstrates stencil texture creation, blit passes, and stencil state configuration.",
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
            longDescription: "Copies 1 MB of data between GPU buffers using an inline compute kernel, then validates the result on the CPU. Demonstrates standalone ComputePass and ComputeDispatch without any rendering.",
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
            longDescription: "Renders a teapot scene to offscreen color and depth textures, then visualizes the depth buffer with a configurable power curve. Demonstrates render-to-texture, stitchable visible functions for post-processing, and side-by-side texture display.",
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
            longDescription: "Loads a source image and upscales it using MetalFX spatial upsampling at a configurable scale factor. Shows the original and upscaled images side by side for quality comparison.",
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
            longDescription: "Simulates 60 teapots bouncing on a checkerboard floor with simple physics. Renders to an offscreen texture, optionally upscales with MetalFX, then presents. Demonstrates instanced rendering, offscreen render targets, and MetalFX integration.",
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
            longDescription: "Renders multiple teapots and a floor plane with Blinn-Phong shading, animated point lights, a skybox backdrop, and axis/grid overlays. Demonstrates the BlinnPhongShader element, light visualization, and WorldView camera controls.",
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
            longDescription: "Renders a teapot with Blinn-Phong shading and a parallel hit-test pass that writes geometry ID, instance ID, triangle ID, depth, and barycentric coordinates to offscreen textures. Supports visualization modes for each channel and click-to-query readback.",
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
            longDescription: "Renders a cube texture as a 360° skybox background with interactive camera rotation. Optionally overlays face labels (+X, -X, etc.) on the cube map. Demonstrates SkyboxRenderPipeline and SwiftUI-to-texture generation for the cube map cross image.",
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
            longDescription: "Applies a heat-diffusion simulation and color remap to video frames, masked by the Apple logo. Chains multiple compute passes (heat update, color remap, video blend) to produce a thermal-camera aesthetic in real time.",
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
            longDescription: "Applies look-up table color grading to a source photo using a compute shader. Supports both 2D PNG LUTs and 3D .cube files with adjustable blend strength. Demonstrates LUT texture loading, compute-based image processing, and billboard display.",
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
            longDescription: "Renders a red triangle offscreen using OffscreenRenderer and converts the result to a CGImage displayed as a static NSImage. Demonstrates headless rendering without a RenderView.",
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
            longDescription: "Renders a rotating teapot with directional lighting, combining render passes for geometry with an edge-detection compute post-process. Demonstrates mixing render and compute passes in a single frame and reading depth/color attachments.",
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
            longDescription: "Applies a selection of color adjustment functions (multiply, gamma, HSV, levels, temperature/tint, vignette, etc.) to a source photo via compute shaders. Each mode exposes its own parameter controls for interactive tuning.",
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
            longDescription: "Renders a teapot with a switchable debug fragment shader. Visualization modes include normals, tangents, texture coordinates, depth, wireframe overlay, face normals, UV distortion, checkerboard, and more. Useful for inspecting mesh attributes.",
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
            longDescription: "Renders a teapot with a cook-torrance PBR shader, HDR environment reflections, and animated point lights. Includes material presets (gold, copper, plastic, etc.) and custom roughness/metallic sliders. Demonstrates PBRShader, environment mapping, and light visualization.",
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
            longDescription: "Raymarches animated signed distance field shapes on a full-screen quad with smooth blending and dynamic lighting. Supports depth output for integration with rasterized geometry. Demonstrates full-screen fragment shaders with WorldView camera controls.",
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
            longDescription: "Generates up to 200K colored points distributed on a torus and renders them as sized points with depth testing. Configurable point count, point size, and torus radii with live regeneration.",
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
            longDescription: "Updates and renders thousands of particles using a compute shader for simulation and a render pass for display. Emitter types include fountain, explosion, rain, fireworks, tornado, and magic portal. Demonstrates compute-to-render buffer sharing and per-frame GPU simulation.",
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
            longDescription: "Streams video frames to Metal textures via AVFoundation and renders them through a billboard pipeline. Optionally applies a VCR distortion compute pass with configurable scanlines, noise, and tracking artifacts.",
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
            longDescription: "Maps an equirectangular HDR image onto a sphere (or box) for interactive 360° viewing with WorldView camera controls. Supports drag-and-drop image loading, optional gamma correction via a compute post-pass, and a minimap overlay.",
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
            longDescription: "Renders the Utah teapot as a green wireframe with a ground grid and axis lines. Demonstrates WireframeRenderPipeline, GridShader, and AxisLinesRenderPipeline.",
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
            longDescription: "Displays a gallery of procedurally generated shapes — platonic solids (tetrahedron, cube, octahedron, dodecahedron, icosahedron), 2D shapes (circle, quad, triangle), and curved surfaces (sphere, torus, capsule, cone, hemisphere, ico-sphere, cube-sphere) — lit with Blinn-Phong shading. Demonstrates TrivialMesh generation and conversion to renderable Mesh objects.",
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
            longDescription: "Traverses a tree of nodes with nested transforms to render a grid of meshes with PBR shading and environment lighting. Includes an interactive scene graph editor panel. Demonstrates SceneGraph construction, recursive transform propagation, and SceneGraphRenderPass.",
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
            longDescription: "Loads glTF and GLB files (including a bundled VirtualCity model), converts them to a SceneGraph, and renders with PBR shading. Supports drag-and-drop import and downloading the Khronos glTF sample asset library.",
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
            longDescription: "Raymarches a 3D voxel texture in a compute pass and renders the result as a billboard. Generates a default procedural volume or loads MagicaVoxel .vox files via drag-and-drop. Demonstrates 3D texture creation, compute raymarching, and file import.",
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
            longDescription: "Generates grass blades on the surface of a sphere using Metal object and mesh shaders. Points are uniformly distributed; each spawns multiple segmented blades with configurable density, length, and width. Demonstrates mesh shader pipelines with per-point amplification.",
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
            longDescription: "Each particle emits a spiral of colored triangles generated entirely in object and mesh shaders — no vertex buffers needed. Configurable particle count, orbit radius, spiral size, and triangles per spiral. Demonstrates mesh shader geometry amplification and procedural vertex generation.",
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
            longDescription: "Provides a SwiftUI Canvas-like API for 3D: build Path3D objects and stroke/fill them in 3D space. Samples include axis lines, line caps/joins, miter limits, Bézier curves, and random line stress tests. Demonstrates GraphicsContext3DRenderPipeline with mesh-shader line rendering.",
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
            longDescription: "Strokes SwiftUI Path objects on the GPU using a mesh-shader pipeline. Includes rectangle, circle, triangle, and random-line demos with configurable line width. Demonstrates MetalCanvas and MetalCanvasRenderPipeline for GPU-accelerated 2D vector drawing.",
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
            longDescription: "Culls 2D SDF primitives per tile using threadgroup memory to minimize global memory reads. Supports configurable primitive count, tile size, and visualization modes (normal, tile heat map, tile boundaries). Demonstrates tile-based compute dispatch with threadgroup-level culling.",
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
            longDescription: "The simplest imageblock demo: renders an animated scene, then averages each tile's pixels to produce a pixelated mosaic effect. Configurable tile size (16×16 or 32×32). Demonstrates Metal imageblock APIs — tile memory allocation, imageblock load/store, and tile dispatch.",
            group: "Basic",
            keywords: ["imageblock", "tile", "2d", "configurable"]
        )
    }
}
