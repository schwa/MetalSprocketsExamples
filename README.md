# MetalSprockets Examples

A companion collection of examples and demos for [MetalSprockets](https://github.com/schwa/MetalSprockets).

## Examples

### Basic

| Example | Description | Screenshot |
|---------|-------------|------------|
| **Triangle** | Basic triangle rendering with animated colors and performance metrics | ![Screenshot](Documentation/Triangle.png) |
| **Blinn-Phong Lighting** | 3D lighting demonstration using the Blinn-Phong shading model with animated lights | ![Screenshot](Documentation/BlinnPhongLighting.png) |
| **Skybox** | Environment mapping demonstration using cube textures for 360-degree backgrounds | ![Screenshot](Documentation/Skybox.png) |
| **Stencil Buffer** | Stencil buffer masking demonstration with checkerboard pattern clipping | ![Screenshot](Documentation/StencilBuffer.png) |
| **Compute** | Simple compute shader that copies data between GPU buffers | ![Screenshot](Documentation/Compute.png) |
| **Depth Buffer** | Demonstrates rendering depth buffer to texture with customisable private functions | ![Screenshot](Documentation/DepthBuffer.png) |
| **LUT Color Grading** | Color grading and correction using Look-Up Tables (LUTs) for cinematic effects | ![Screenshot](Documentation/LUTColorGrading.png) |
| **Debug Shaders** | Shader debugging visualization with various modes including normals, depth, wireframe, and distance fields | ![Screenshot](Documentation/DebugShaders.png) |
| **Point Cloud** | Interactive point cloud visualization with thousands of colored points arranged in a torus shape | ![Screenshot](Documentation/PointCloud.png) |
| **Video Playback** | Full screen video playback with streaming textures rendered through billboard pipeline | ![Screenshot](Documentation/VideoPlayback.png) |
| **360° Panorama** | Interactive 360-degree panoramic photo viewer with spherical projection and WorldView rotation | ![Screenshot](Documentation/Panorama.png) |
| **Wireframe Teapot** | Wireframe rendering demo | ![Screenshot](Documentation/WireframeTeapot.png) |
| **Trivial Mesh** | Procedurally generated geometric primitives (box, tetrahedron, octahedron) with Blinn-Phong lighting | ![Screenshot](Documentation/TrivialMesh.png) |
| **Scene Graph** | Scene graph traversal demo showing stacked row/column transforms rendered as a 4×4 grid | ![Screenshot](Documentation/SceneGraph.png) |
| **GraphicsContext3D** | SwiftUI.Canvas-style API for rendering 3D geometry with Path3D and stroke/fill operations | ![Screenshot](Documentation/GraphicsContext3D.png) |
| **MetalCanvas** | 2D Canvas-style API for rendering SwiftUI Paths with stroke operations using mesh shaders | ![Screenshot](Documentation/MetalCanvas.png) |
| **Hello Imageblock** | The simplest imageblock demo: computes per-tile average color creating a pixelated/mosaic effect | ![Screenshot](Documentation/HelloImageblock.png) |
| **Offscreen Rendering** *(macOS only)* | Render-to-texture demonstration showing offscreen rendering capabilities | ![Screenshot](Documentation/OffscreenRendering.png) |
| **MetalFX Upscaling** *(MetalFX required)* | Image upscaling using MetalFX spatial upsampling for enhanced image quality | ![Screenshot](Documentation/MetalFXUpscaling.png) |

### Complex

| Example | Description | Screenshot |
|---------|-------------|------------|
| **Bouncing Teapots** | Physics simulation of animated teapots with MetalFX upscaling and instanced rendering | ![Screenshot](Documentation/BouncingTeapots.png) |
| **Hit Test Demo** | Teapot rendering with hit test pipeline that outputs geometry ID, instance ID, triangle ID, depth, and barycentric coordinates | ![Screenshot](Documentation/HitTestDemo.png) |
| **Mixed Techniques** | Combination of multiple rendering techniques including lighting and animation | ![Screenshot](Documentation/MixedTechniques.png) |
| **SDF Raymarching** | Real-time signed distance field raymarching with animated shapes, smooth blending, and dynamic lighting | ![Screenshot](Documentation/SDFRaymarching.png) |
| **Particle Effects** | GPU-accelerated particle system with compute shaders featuring various emitter types like fountains, explosions, and fireworks | ![Screenshot](Documentation/ParticleEffects.png) |
| **glTF Model Viewer** | glTF model loading and rendering | ![Screenshot](Documentation/GLTFModelViewer.png) |
| **Grass Sphere** | Procedural grass rendering on a sphere using Object and Mesh shaders with uniform point distribution | ![Screenshot](Documentation/GrassSphere.png) |
| **Spiral Particles** | Particle system where each particle generates a colorful spiral of triangles using Object and Mesh shaders | ![Screenshot](Documentation/SpiralParticles.png) |
| **Tiled SDF (2D)** | Tile-based culling for 2D signed distance fields with primitives culled to tiles and stored in threadgroup memory | ![Screenshot](Documentation/TiledSDF2D.png) |
| **Apple Event Logo** | Apple Event logo recreation | ![Screenshot](Documentation/AppleEventLogo.png) |

### Other

| Example | Description | Screenshot |
|---------|-------------|------------|
| **Game of Life** | Conway's Game of Life cellular automaton simulation using GPU compute shaders | ![Screenshot](Documentation/GameOfLife.png) |
| **Voxel Renderer** | Voxel-based rendering | ![Screenshot](Documentation/VoxelRenderer.png) |
| **PBR Rendering** *(broken)* | Physically Based Rendering with multiple material presets, environment reflections, and animated lighting | ![Screenshot](Documentation/PBRRendering.png) |
| **Color Adjust** | Color adjustment demo (in-progress) | ![Screenshot](Documentation/ColorAdjust.png) |

## Screenshots

Screenshots are stored in the `Documentation/` directory. To add a screenshot, save a PNG named to match the table above (e.g. `Documentation/Triangle.png`).

## License

See [LICENSE](LICENSE) for details.
