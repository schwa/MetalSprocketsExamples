# Demos

*34 demos — generated from [`demos.yaml`](demos.yaml)*

## Ungrouped

### Empty

> An empty view.

---

## Basic

### Blinn-Phong Lighting

![Blinn-Phong Lighting](screenshots/BlinnPhongLighting.png)

> Blinn-Phong lit teapots with skybox

BlinnPhongShader element with multiple models, animated lighting, skybox, and WorldView camera controls.

**Tags:** `lighting`  `multipass`  `animated`

---

### Skybox

![Skybox](screenshots/Skybox.png)

> Cube-map skybox rendering

SkyboxRenderPipeline with a cube texture built from a cross-layout image. Also shows generating textures from SwiftUI views.

**Tags:** `configurable`

---

### Triangle

![Triangle](screenshots/Triangle.png)

> Colored triangle with GPU timing

The simplest MetalSprockets render pipeline: inline Metal source compiled at runtime into VertexShader/FragmentShader, wired up with RenderView and Draw.

**Tags:** `animated`  `configurable`

---

### Compute

![Compute](screenshots/Compute.png)

> Buffer-to-buffer copy via compute

Standalone ComputePass and ComputeDispatch without any rendering — just buffer-to-buffer data movement on the GPU.

**Tags:** `needs-work`

---

### Stencil Buffer

![Stencil Buffer](screenshots/StencilBuffer.png)

> Stencil-masked triangle

Stencil texture creation, blit pass to populate the stencil attachment, and StencilState configuration to clip rendered geometry.

---

### LUT Color Grading

![LUT Color Grading](screenshots/LUTColorGrading.png)

> Image color grading via LUTs

Compute-based image processing with LUT texture loading (2D PNG and 3D .cube formats) and TextureBillboardPipeline for display.

**Tags:** `post-processing`  `configurable`

---

### Game of Life

![Game of Life](screenshots/GameOfLife.png)

> GPU-driven cellular automaton

GPU-driven cellular automaton — a ComputePass updates a texture each frame, driving the entire simulation loop on the GPU.

**Tags:** `animated`  `configurable`

---

### Debug Shaders

![Debug Shaders](screenshots/DebugShaders.png)

> Shader debug visualizations

DebugRenderPipeline with switchable fragment shader modes for visualizing mesh attributes — normals, tangents, UVs, depth, wireframe, etc.

---

### Point Cloud

![Point Cloud](screenshots/PointCloud.png)

> Interactive torus point cloud

Point primitive rendering with depth testing from a CPU-generated MTLBuffer.

**Tags:** `points`  `interactive`  `configurable`

---

### Video Playback

![Video Playback](screenshots/VideoPlayback.png)

> Video with VCR distortion effect

Streaming AVFoundation video frames into Metal textures, rendered via TextureBillboardPipeline with an optional VCR distortion compute pass.

**Tags:** `video`  `billboard`  `configurable`

---

### 360° Panorama

![360° Panorama](screenshots/Panorama.png)

> Equirectangular panorama viewer

Equirectangular-to-sphere texture mapping with WorldView camera controls and an optional gamma-correction compute post-pass.

**Tags:** `configurable`

---

### Wireframe Teapot

![Wireframe Teapot](screenshots/WireframeTeapot.png)

> Wireframe mesh rendering

WireframeRenderPipeline for line-mode mesh rendering, combined with GridShader and AxisLinesRenderPipeline.

---

### Trivial Mesh

![Trivial Mesh](screenshots/TrivialMesh.png)

> Procedural geometry primitives

TrivialMesh procedural geometry generation and conversion to renderable Mesh objects — platonic solids, 2D shapes, and curved surfaces.

**Tags:** `mesh`  `procedural`  `lighting`  `animated`  `configurable`

---

### Scene Graph

![Scene Graph](screenshots/SceneGraph.png)

> Hierarchical scene graph rendering

SceneGraph construction with recursive transform propagation, rendered via SceneGraphRenderPass with PBR shading.

**Tags:** `scene`  `graph`  `lighting`

---

### GraphicsContext3D

![GraphicsContext3D](screenshots/GraphicsContext3D.png)

> Canvas-style 3D path drawing

GraphicsContext3DRenderPipeline: a SwiftUI Canvas-like API for 3D path drawing with stroke/fill, backed by mesh-shader line rendering.

**Tags:** `3d`  `path`  `canvas`  `configurable`

---

### MetalCanvas

![MetalCanvas](screenshots/MetalCanvas.png)

> 2D path rendering via mesh shaders

MetalCanvas and MetalCanvasRenderPipeline: GPU-accelerated 2D vector path stroking using mesh shaders, accepting standard SwiftUI Path objects.

**Tags:** `2d`  `path`  `canvas`  `mesh-shaders`  `configurable`

---

### Hello Imageblock

![Hello Imageblock](screenshots/HelloImageblock.png)

> Imageblock tile averaging

Metal imageblock APIs: tile memory allocation, imageblock_data load/store, and tile dispatch in the simplest possible example.

**Tags:** `imageblock`  `tile`  `2d`  `configurable`

---

### Offscreen Rendering

![Offscreen Rendering](screenshots/OffscreenRendering.png)

> Render to CGImage

Headless rendering with OffscreenRenderer — no RenderView, just render to a CGImage.

**Tags:** `needs-work`  `macOS`

---

### MetalFX Upscaling

![MetalFX Upscaling](screenshots/MetalFXUpscaling.png)

> MetalFX spatial upscaling

Integrating MetalFXSpatial upsampling into a MetalSprockets pipeline.

**Tags:** `metalfx`  `needs-work`  `configurable`  `macOS`

---

## Complex

### Hit Test Demo

![Hit Test Demo](screenshots/HitTestDemo.png)

> GPU-based object picking

Multi-pass rendering with a parallel hit-test pass writing geometry ID, instance ID, triangle ID, depth, and barycentric coordinates to offscreen textures. Includes CPU readback of hit results.

**Tags:** `hit-test`  `picking`  `multipass`  `configurable`

---

### Depth Buffer

![Depth Buffer](screenshots/DepthBuffer.png)

> Depth buffer visualization

Render-to-texture with separate color and depth outputs. Uses stitchable visible functions for post-processing the depth buffer.

**Tags:** `configurable`

---

### Mixed Techniques

![Mixed Techniques](screenshots/MixedTechniques.png)

> Combined render and compute passes

Mixing render and compute passes in a single frame — geometry rendering followed by an edge-detection compute post-process that reads depth/color attachments.

**Tags:** `multipass`  `animated`

---

### Bouncing Teapots

![Bouncing Teapots](screenshots/BouncingTeapots.png)

> Physics-driven instanced teapots

Instanced rendering to an offscreen texture with optional MetalFX upscaling before presentation.

**Tags:** `metalfx`  `animated`  `multipass`

---

### Apple Event Logo

![Apple Event Logo](screenshots/AppleEventLogo.png)

> Thermal-style video effect

Chaining multiple ComputePass stages — heat simulation, color remap, video blend — in a single frame.

**Tags:** `needs-work`  `animated`  `video`

---

### PBR Rendering

![PBR Rendering](screenshots/PBRRendering.png)

> Physically based rendering

PBRShader with Cook-Torrance BRDF, HDR environment reflections, animated lighting, and configurable material properties.

---

### SDF Raymarching

![SDF Raymarching](screenshots/SDFRaymarching.png)

> 3D SDF raymarching

Full-screen fragment shader raymarching SDFs with depth output, allowing integration with rasterized geometry via WorldView.

**Tags:** `animated`  `raymarching`  `configurable`

---

### Particle Effects

![Particle Effects](screenshots/ParticleEffects.png)

> GPU compute particle system

Compute-to-render buffer sharing: a compute pass updates particle state each frame, then a render pass draws from the same MTLBuffer.

**Tags:** `compute`  `animated`  `configurable`

---

### glTF Model Viewer

![glTF Model Viewer](screenshots/GLTFModelViewer.png)

> glTF/GLB model loader and viewer

Loading glTF/GLB files, converting them to a SceneGraph via GLTFSceneGraphGenerator, and rendering with SceneGraphRenderPass.

---

### Voxel Renderer

![Voxel Renderer](screenshots/VoxelRenderer.png)

> Compute-raymarched voxel volumes

3D texture creation and compute-pass raymarching of voxel volumes, with MagicaVoxel .vox file import support.

**Tags:** `configurable`

---

### Grass Sphere

![Grass Sphere](screenshots/GrassSphere.png)

> Mesh-shader procedural grass

Metal object and mesh shader pipeline with per-point amplification — each input point generates multiple segmented grass blade geometry instances.

**Tags:** `mesh-shaders`  `procedural`  `animated`  `configurable`

---

### Spiral Particles

![Spiral Particles](screenshots/SpiralParticles.png)

> Mesh-shader spiral particles

Mesh shader geometry amplification with fully procedural vertex generation — no vertex buffers, all geometry created in the object/mesh shader stages.

**Tags:** `mesh-shaders`  `particles`  `animated`  `procedural`  `configurable`

---

### Tiled SDF (2D)

![Tiled SDF (2D)](screenshots/TiledSDF2D.png)

> Tile-culled 2D SDF rendering

Tile-based compute dispatch with threadgroup-level primitive culling — primitives are binned per tile into threadgroup memory to reduce global memory traffic.

**Tags:** `compute`  `sdf`  `tiled`  `animated`  `2d`  `configurable`

---

## In-progress

### Color Adjust

![Color Adjust](screenshots/ColorAdjust.png)

> Compute-based color adjustments

Multiple compute shader functions (multiply, gamma, HSV, levels, temperature/tint, vignette, etc.) applied to an image, showing how to swap between different ComputeKernels at runtime.

**Tags:** `configurable`

---
