# MetalSprockets Examples

A companion collection of examples and demos for [MetalSprockets](https://github.com/schwa/MetalSprockets).

<!-- BEGIN:DEMOS -->
## Examples

### Basic

| Example | Description | Screenshot |
|---------|-------------|------------|
| **Blinn-Phong** | Blinn-Phong lit teapots with skybox | [<img src="Documentation/screenshots/thumbnails/BlinnPhong.png" width="320" alt="Blinn-Phong">](Documentation/screenshots/BlinnPhong.png) |
| **Skybox** | Cube-map skybox rendering | [<img src="Documentation/screenshots/thumbnails/Skybox.png" width="320" alt="Skybox">](Documentation/screenshots/Skybox.png) |
| **Triangle** | Colored triangle with GPU timing | [<img src="Documentation/screenshots/thumbnails/Triangle.png" width="320" alt="Triangle">](Documentation/screenshots/Triangle.png) |
| **Compute** | Buffer-to-buffer copy via compute | [<img src="Documentation/screenshots/thumbnails/Compute.png" width="320" alt="Compute">](Documentation/screenshots/Compute.png) |
| **Stencil** | Stencil-masked triangle | [<img src="Documentation/screenshots/thumbnails/Stencil.png" width="320" alt="Stencil">](Documentation/screenshots/Stencil.png) |
| **LUT** | Image color grading via LUTs | [<img src="Documentation/screenshots/thumbnails/LUT.png" width="320" alt="LUT">](Documentation/screenshots/LUT.png) |
| **Game of Life** | GPU-driven cellular automaton | [<img src="Documentation/screenshots/thumbnails/GameOfLife.png" width="320" alt="Game of Life">](Documentation/screenshots/GameOfLife.png) |
| **Debug Shader** | Shader debug visualizations | [<img src="Documentation/screenshots/thumbnails/DebugShader.png" width="320" alt="Debug Shader">](Documentation/screenshots/DebugShader.png) |
| **Point Cloud** | Interactive torus point cloud | [<img src="Documentation/screenshots/thumbnails/PointCloud.png" width="320" alt="Point Cloud">](Documentation/screenshots/PointCloud.png) |
| **Video Playback** | Video with VCR distortion effect | [<img src="Documentation/screenshots/thumbnails/VideoPlayback.png" width="320" alt="Video Playback">](Documentation/screenshots/VideoPlayback.png) |
| **Panorama** | Equirectangular panorama viewer | [<img src="Documentation/screenshots/thumbnails/Panorama.png" width="320" alt="Panorama">](Documentation/screenshots/Panorama.png) |
| **Wireframe** | Wireframe mesh rendering | [<img src="Documentation/screenshots/thumbnails/Wireframe.png" width="320" alt="Wireframe">](Documentation/screenshots/Wireframe.png) |
| **Trivial Mesh** | Procedural geometry primitives | [<img src="Documentation/screenshots/thumbnails/TrivialMesh.png" width="320" alt="Trivial Mesh">](Documentation/screenshots/TrivialMesh.png) |
| **SceneGraph** | Hierarchical scene graph rendering | [<img src="Documentation/screenshots/thumbnails/SceneGraph.png" width="320" alt="SceneGraph">](Documentation/screenshots/SceneGraph.png) |
| **GraphicsContext3D** | Canvas-style 3D path drawing | [<img src="Documentation/screenshots/thumbnails/GraphicsContext3D.png" width="320" alt="GraphicsContext3D">](Documentation/screenshots/GraphicsContext3D.png) |
| **MetalCanvas** | 2D path rendering via mesh shaders | [<img src="Documentation/screenshots/thumbnails/MetalCanvas.png" width="320" alt="MetalCanvas">](Documentation/screenshots/MetalCanvas.png) |
| **Tile Average** | Imageblock tile averaging | [<img src="Documentation/screenshots/thumbnails/TileAverage.png" width="320" alt="Tile Average">](Documentation/screenshots/TileAverage.png) |
| **Offscreen *(macOS only)*** | Render to CGImage | [<img src="Documentation/screenshots/thumbnails/Offscreen.png" width="320" alt="Offscreen *(macOS only)*">](Documentation/screenshots/Offscreen.png) |
| **MetalFX *(macOS only)*** | MetalFX spatial upscaling | [<img src="Documentation/screenshots/thumbnails/MetalFX.png" width="320" alt="MetalFX *(macOS only)*">](Documentation/screenshots/MetalFX.png) |
| **Skinning** | Skeletal mesh deformation with bones | — |

### Complex

| Example | Description | Screenshot |
|---------|-------------|------------|
| **Hit Test** | GPU-based object picking | [<img src="Documentation/screenshots/thumbnails/HitTest.png" width="320" alt="Hit Test">](Documentation/screenshots/HitTest.png) |
| **Depth** | Depth buffer visualization | [<img src="Documentation/screenshots/thumbnails/Depth.png" width="320" alt="Depth">](Documentation/screenshots/Depth.png) |
| **Mixed** | Combined render and compute passes | [<img src="Documentation/screenshots/thumbnails/Mixed.png" width="320" alt="Mixed">](Documentation/screenshots/Mixed.png) |
| **Bouncing Teapots** | Physics-driven instanced teapots | [<img src="Documentation/screenshots/thumbnails/BouncingTeapots.png" width="320" alt="Bouncing Teapots">](Documentation/screenshots/BouncingTeapots.png) |
| **Apple Event Logo** | Thermal-style video effect | [<img src="Documentation/screenshots/thumbnails/AppleEventLogo.png" width="320" alt="Apple Event Logo">](Documentation/screenshots/AppleEventLogo.png) |
| **PBR** | Physically based rendering | [<img src="Documentation/screenshots/thumbnails/PBR.png" width="320" alt="PBR">](Documentation/screenshots/PBR.png) |
| **SDF** | 3D SDF raymarching | [<img src="Documentation/screenshots/thumbnails/SDF.png" width="320" alt="SDF">](Documentation/screenshots/SDF.png) |
| **Particle Effects** | GPU compute particle system | [<img src="Documentation/screenshots/thumbnails/ParticleEffects.png" width="320" alt="Particle Effects">](Documentation/screenshots/ParticleEffects.png) |
| **GLTF** | glTF/GLB model loader and viewer | [<img src="Documentation/screenshots/thumbnails/GLTF.png" width="320" alt="GLTF">](Documentation/screenshots/GLTF.png) |
| **Voxel** | Compute-raymarched voxel volumes | [<img src="Documentation/screenshots/thumbnails/Voxel.png" width="320" alt="Voxel">](Documentation/screenshots/Voxel.png) |
| **Grass** | Mesh-shader procedural grass | [<img src="Documentation/screenshots/thumbnails/Grass.png" width="320" alt="Grass">](Documentation/screenshots/Grass.png) |
| **Spiral Particles** | Mesh-shader spiral particles | [<img src="Documentation/screenshots/thumbnails/SpiralParticles.png" width="320" alt="Spiral Particles">](Documentation/screenshots/SpiralParticles.png) |
| **Tiled SDF** | Tile-culled 2D SDF rendering | [<img src="Documentation/screenshots/thumbnails/TiledSDF.png" width="320" alt="Tiled SDF">](Documentation/screenshots/TiledSDF.png) |
| **Ray Tracing** | Cornell box path tracer | — |
| **Shader Graph** | Build Metal shaders as Swift DSL graphs | — |
| **Phosphor** | Live-compile Metal shader snippets (shadertoy-style) | — |

### In-progress

| Example | Description | Screenshot |
|---------|-------------|------------|
| **Color Adjust** | Compute-based color adjustments | [<img src="Documentation/screenshots/thumbnails/ColorAdjust.png" width="320" alt="Color Adjust">](Documentation/screenshots/ColorAdjust.png) |

### Rendering

| Example | Description | Screenshot |
|---------|-------------|------------|
| **Infinite Grid** | An infinite ground plane grid with interactive camera | — |
| **Spinning Cube** | A rotating RGB cube with MSAA controls | — |
| **Shadow Map** | Multi-light shadow mapping with PCF and depth bias controls | — |
| **Ray Traced Shadows** | Hardware-accelerated ray-traced shadows with acceleration structures | — |

### Slug

| Example | Description | Screenshot |
|---------|-------------|------------|
| **Slug Debug** | Basic Slug text rendering test | — |
| **Matrix Rain** | Matrix-style falling text rendered with Slug | — |
| **Spinning Sphere** | Text mapped to a spinning sphere with Slug | — |
| **Text Panel** | Multi-language text rendered with Slug | — |
| **Terminal *(macOS only)*** | Live terminal output rendered with Slug | — |
| **Immersive Matrix Rain *(visionOS only)*** | Matrix rain in immersive visionOS space | — |

### Platform

| Example | Description | Screenshot |
|---------|-------------|------------|
| **Mobile *(iOS only)*** | AR-powered mobile rendering demo | — |
| **VisionOS *(visionOS only)*** | Immersive visionOS stereo rendering | — |
<!-- END:DEMOS -->

## Screenshots

Screenshots and thumbnails live under `Documentation/screenshots/`. The tables above are regenerated from [`Documentation/demos.yaml`](Documentation/demos.yaml); run:

```sh
uv run --with pyyaml Documentation/generate-docs.py --readme
```

to refresh them.

## License

See [LICENSE](LICENSE) for details.
