# Demos

*55 demos — generated from [`demos.yaml`](demos.yaml)*

## Ungrouped

### Empty

> An empty view.

---

## Basic

### Blinn-Phong

![Blinn-Phong](screenshots/BlinnPhong.png)

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

### Stencil

![Stencil](screenshots/Stencil.png)

> Stencil-masked triangle

Stencil texture creation, blit pass to populate the stencil attachment, and StencilState configuration to clip rendered geometry.

---

### LUT

![LUT](screenshots/LUT.png)

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

### Panorama

![Panorama](screenshots/Panorama.png)

> Equirectangular panorama viewer

Equirectangular-to-sphere texture mapping with WorldView camera controls and an optional gamma-correction compute post-pass.

**Tags:** `configurable`

---

### Wireframe

![Wireframe](screenshots/Wireframe.png)

> Wireframe mesh rendering

WireframeRenderPipeline for line-mode mesh rendering, combined with GridShader and AxisLinesRenderPipeline.

---

### MetalCanvas

![MetalCanvas](screenshots/MetalCanvas.png)

> 2D path rendering via mesh shaders

MetalCanvas and MetalCanvasRenderPipeline: GPU-accelerated 2D vector path stroking using mesh shaders, accepting standard SwiftUI Path objects.

**Tags:** `2d`  `path`  `canvas`  `mesh-shaders`  `configurable`

---

### Tile Average

![Tile Average](screenshots/TileAverage.png)

> Imageblock tile averaging

Metal imageblock APIs: tile memory allocation, imageblock_data load/store, and tile dispatch in the simplest possible example.

**Tags:** `imageblock`  `tile`  `2d`  `configurable`

---

### Offscreen

![Offscreen](screenshots/Offscreen.png)

> Render to CGImage

Headless rendering with OffscreenRenderer — no RenderView, just render to a CGImage.

**Tags:** `needs-work`  `macOS`

---

### MetalFX

![MetalFX](screenshots/MetalFX.png)

> MetalFX spatial upscaling

Integrating MetalFXSpatial upsampling into a MetalSprockets pipeline.

**Tags:** `metalfx`  `needs-work`  `configurable`  `macOS`

---

### Skinning

> Skeletal mesh deformation with bones

Skeletal animation with a 2-bone rig deforming a capsule mesh. Vertex shader applies per-vertex bone weights to blend between bone transforms, animating between straight and L-shaped poses.

**Tags:** `skinning`  `skeletal`  `animated`

---

### Liquid Glass

> Refractive liquid-glass pills over an animated background

SDF pills with a circular bevel refract an animated marquee background, with chromatic dispersion, fresnel rim glow, frost blur, and smooth-min blending so dragged pills merge like liquid.

**Tags:** `sdf`  `refraction`  `interactive`

---

### Mesh Dissolve

> Triplanar-grid dissolve effects

A cube shaded with a triplanar projected grid and a dozen dissolve effects, each a scalar field compared against an animated threshold, with discard_fragment and a leading-edge glow.

**Tags:** `dissolve`  `triplanar`  `animated`  `configurable`

---

### Stargate

> 2001-style slit-scan effect

Procedural recreation of the 2001: A Space Odyssey slit-scan sequence: a fullscreen fragment shader warps screen space into a tunnel with streaks stretched along its depth axis.

**Tags:** `fullscreen`  `procedural`  `animated`  `configurable`

---

## Complex

### Hit Test

![Hit Test](screenshots/HitTest.png)

> GPU-based object picking

Multi-pass rendering with a parallel hit-test pass writing geometry ID, instance ID, triangle ID, depth, and barycentric coordinates to offscreen textures. Includes CPU readback of hit results.

**Tags:** `hit-test`  `picking`  `multipass`  `configurable`

---

### Depth

![Depth](screenshots/Depth.png)

> Depth buffer visualization

Render-to-texture with separate color and depth outputs. Uses stitchable visible functions for post-processing the depth buffer.

**Tags:** `configurable`

---

### Mixed

![Mixed](screenshots/Mixed.png)

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

### SDF

![SDF](screenshots/SDF.png)

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

### Voxel

![Voxel](screenshots/Voxel.png)

> Compute-raymarched voxel volumes

3D texture creation and compute-pass raymarching of voxel volumes, with MagicaVoxel .vox file import support.

**Tags:** `configurable`

---

### Grass

![Grass](screenshots/Grass.png)

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

### Tiled SDF

![Tiled SDF](screenshots/TiledSDF.png)

> Tile-culled 2D SDF rendering

Tile-based compute dispatch with threadgroup-level primitive culling — primitives are binned per tile into threadgroup memory to reduce global memory traffic.

**Tags:** `compute`  `sdf`  `tiled`  `animated`  `2d`  `configurable`

---

### Ray Tracing

> Cornell box path tracer

Metal ray tracing APIs with hardware-accelerated AccelerationStructure intersection. Progressive path tracing of the classic Cornell box scene with diffuse global illumination.

**Tags:** `ray-tracing`  `path-tracing`  `acceleration-structure`

---

### Shader Graph

> Build Metal shaders as Swift DSL graphs

A Swift DSL that generates Metal code via MTLFunctionStitchingGraph. Build fragment shader effects as a graph of nodes and stitch them into a visible_function_table at runtime.

**Tags:** `dsl`  `stitching`  `visible-functions`  `configurable`

---

### Meadow

> Ray-traced procedural meadow

Hardware ray tracing over ~5M procedural triangles of grass, flowers and trees. Progressive accumulation with sun shadows, one diffuse bounce, volumetric haze and clouds.

**Tags:** `ray-tracing`  `acceleration-structure`  `procedural`

---

### Stam Fluid

> Interactive 2D Navier-Stokes fluid

GPU implementation of Jos Stam's "Real-Time Fluid Dynamics for Games" (GDC 2003). Diffusion, advection, and pressure projection via red-black Gauss-Seidel relaxation. Drag to inject smoke and apply forces.

**Tags:** `fluid`  `simulation`  `compute`  `interactive`

---

### FLIP Fluid

> 3D PIC/FLIP fluid simulation

A 3D PIC/FLIP fluid in a tank. All solver passes run in one compute pass; the surface is a Zhu-Bridson field ray-marched in a fragment shader. Drag to orbit, pinch to zoom.

**Tags:** `fluid`  `simulation`  `compute`  `raymarching`

---

### Open Sea

> Gerstner-wave ocean with analytic sky

Five Gerstner wave components displace a camera-centred radial grid generated from vertex IDs, with analytic normals, fresnel sky reflection, sun glitter, crest foam, and a time-of-day palette.

**Tags:** `ocean`  `procedural`  `animated`

---

### Gargantua

> Black hole with geodesic ray marching

A Schwarzschild black hole: null geodesics marched per pixel, with a Novikov-Thorne accretion disk, MetalFX spatial upscaling, a compute bloom pyramid, and a cinematic camera path.

**Tags:** `raymarching`  `metalfx`  `bloom`  `animated`

---

### Tree Generator

> Space-colonization procedural trees

Port of hugomarques13/TreeGenerator: space colonization grows a branching skeleton toward attraction points, then builds tapered bark tubes and leaf quads. Oak, Pine, Willow and Dead presets.

**Tags:** `procedural`  `mesh`  `configurable`

---

## In-progress

### Color Adjust

![Color Adjust](screenshots/ColorAdjust.png)

> Compute-based color adjustments

Multiple compute shader functions (multiply, gamma, HSV, levels, temperature/tint, vignette, etc.) applied to an image, showing how to swap between different ComputeKernels at runtime.

**Tags:** `configurable`

---

## Rendering

### Debug Shader

![Debug Shader](screenshots/DebugShader.png)

> Shader debug visualizations

DebugRenderPipeline with switchable fragment shader modes for visualizing mesh attributes — normals, tangents, UVs, depth, wireframe, etc.

**Tags:** `MetalSprocketsAddOns`

---

### Trivial Mesh

![Trivial Mesh](screenshots/TrivialMesh.png)

> Procedural geometry primitives

TrivialMesh procedural geometry generation and conversion to renderable Mesh objects — platonic solids, 2D shapes, and curved surfaces.

**Tags:** `MetalSprocketsAddOns`  `mesh`  `procedural`  `lighting`  `animated`  `configurable`

---

### GraphicsContext3D

![GraphicsContext3D](screenshots/GraphicsContext3D.png)

> 3D stroked and filled paths with pixel-perfect line widths

GraphicsContext3DRenderPipeline: a SwiftUI Canvas-like API for 3D path drawing with stroke/fill, backed by mesh-shader line rendering.

**Tags:** `MetalSprocketsAddOns`  `3d`  `path`  `canvas`  `configurable`

---

### Infinite Grid

> An infinite ground plane grid with interactive camera

**Tags:** `MetalSprocketsAddOns`  `grid`  `camera`

---

### Spinning Cube

> A rotating RGB cube with MSAA controls

**Tags:** `MetalSprocketsAddOns`  `msaa`  `animated`

---

### Shadow Map

> Multi-light shadow mapping with PCF and depth bias controls

**Tags:** `MetalSprocketsAddOns`  `shadows`  `pcf`  `configurable`

---

### Ray Traced Shadows

> Hardware-accelerated ray-traced shadows with acceleration structures

**Tags:** `MetalSprocketsAddOns`  `ray-tracing`  `shadows`

---

## Slug

### Slug Debug

> Basic Slug text rendering test

**Tags:** `MetalSprocketsAddOns`  `slug`  `text`

---

### Matrix Rain

> Matrix-style falling text rendered with Slug

**Tags:** `MetalSprocketsAddOns`  `slug`  `text`  `animated`

---

### Spinning Sphere

> Text mapped to a spinning sphere with Slug

**Tags:** `MetalSprocketsAddOns`  `slug`  `text`  `animated`

---

### Text Panel

> Multi-language text rendered with Slug

**Tags:** `MetalSprocketsAddOns`  `slug`  `text`  `i18n`

---

### Terminal

> Live terminal output rendered with Slug

**Tags:** `MetalSprocketsAddOns`  `slug`  `text`  `terminal`  `macOS`

---

### Immersive Matrix Rain

> Matrix rain in immersive visionOS space

**Tags:** `MetalSprocketsAddOns`  `slug`  `visionos`  `animated`  `visionOS`

---

## Platform

### Mobile

> AR-powered mobile rendering demo

**Tags:** `MetalSprocketsAddOns`  `ar`  `ios`  `iOS`

---

### VisionOS

> Immersive visionOS stereo rendering

**Tags:** `MetalSprocketsAddOns`  `visionos`  `stereo`  `visionOS`

---
