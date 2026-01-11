## 1: Hit testing demo
status: closed
priority: none
kind: none
created: 2025-10-22
updated: 2025-10-23
closed: 2025-10-23

Create a demo that demonstrates hit testing capabilities.

Origin: GitHub issue #273

---

## 2: Fix up names of shaders vs demos vs demo views vs elements
status: new
priority: none
kind: none
created: 2025-10-22
updated: 2025-10-23

e.g. TextureBillboard vs BillboardShader etc

Need to standardize naming conventions across the examples project.

Origin: GitHub issue #250

---

## 3: Code Reuse Pass
status: new
priority: none
kind: none
created: 2025-10-22
updated: 2025-10-23

Go through all demo code and look for code reuse opportunities.

Lots of shaders are doing very similar things now and the demos are bloating a little.

Also look for chances to make these part of Batteries Included.

Origin: GitHub issue #246

---

## 4: Add a MetalPaint demo
status: new
priority: none
kind: none
created: 2025-10-22
updated: 2025-10-23

It's MacPaint but Metal!

Create a painting/drawing demo using Metal.

Origin: GitHub issue #235

---

## 5: Make more demos runable in offscreen(video)renderer
status: new
priority: none
kind: none
created: 2025-10-22
updated: 2025-10-23

Enable additional demos to work with the offscreen video renderer.

Origin: GitHub issue #215

---

## 6: Move demos back into own repo
status: closed
priority: none
kind: none
created: 2025-10-22
updated: 2025-10-23
closed: 2025-10-23

Separate the demos into their own repository.

Origin: GitHub issue #213

---

## 7: Standalone demo
status: new
priority: none
kind: none
created: 2025-10-22
updated: 2025-10-23

Create the simplest possible demo that can run independently.

Origin: GitHub issue #212

---

## 8: AxisLines should extend to screen edges instead of fixed world-space length
status: closed
priority: none
kind: none
created: 2025-10-22
updated: 2025-10-24
closed: 2025-10-24

## Current Behavior
The AxisLines element currently uses a fixed scale parameter to set the length of axis lines in world space. This means the lines have a fixed length regardless of camera position or zoom level.

## Desired Behavior
The axis lines should extend all the way to the edges of the screen/viewport, similar to how 3D modeling applications display axis lines. This would require:

1. Computing the axis lines in clip space or screen space rather than world space
2. Projecting the axis directions to find where they intersect with the screen boundaries
3. Drawing lines from the origin to these intersection points

## Implementation Notes
- May need to pass viewport dimensions to the shader
- Could compute line endpoints in vertex shader using inverse projection
- Alternatively, could use a geometry shader or compute shader to calculate proper endpoints
- Need to handle cases where origin is off-screen

## Workaround
For now, using a very large scale value (e.g., 10000.0) provides adequate coverage for most camera positions.

Origin: GitHub issue #262

---

## 9: Make .metal-sprocketsExampleShaders() into property
status: new
priority: none
kind: none
created: 2025-10-22
updated: 2025-10-23

Convert the .metal-sprocketsExampleShaders() method into a property for cleaner API.

Origin: GitHub issue #261

---

## 10: Sanitize vertex descriptors
status: new
priority: none
kind: none
created: 2025-10-22
updated: 2025-10-23

Clean up and standardize vertex descriptors across the examples project.

Origin: GitHub issue #259

---

## 11: Link all all issues from metal-sprockets
status: closed
priority: none
kind: none
created: 2025-10-22
updated: 2025-10-24
closed: 2025-10-24

{"id":"uv-eg-20","title":"Make sure all compute examples are using good sizes","description":"Review all compute shader examples to ensure they're using appropriate thread group sizes and dispatch sizes for optimal performance.\n\nOrigin: GitHub issue #252","status":"open","priority":2,"issue_type":"task","created_at":"2025-10-20T19:42:22.465146-07:00","updated_at":"2025-10-21T13:08:41.019653-07:00"}

---

## 23: Implement texture pooling/reuse strategy
status: new
priority: none
kind: none
created: 2025-10-22
updated: 2025-10-23

Currently each demo creates textures on-demand in init/onChange handlers with no reuse strategy. Issues: potential resource leaks in long-running demos, no centralized lifecycle management, repeated allocation/deallocation overhead. Should implement texture pooling for common sizes/formats to improve performance and resource management.

---

## 24: Extract common UI controls into reusable components
status: new
priority: none
kind: none
created: 2025-10-22
updated: 2025-10-23

Many demos duplicate similar UI patterns: slider controls for parameters, color pickers, dropdown menus, reset/download buttons. Should create reusable SwiftUI components in Support/ or new UI/ directory: ParameterSlider, DemoColorPicker, DemoOptionPicker, etc. This will reduce code duplication and ensure consistent UI across demos.

---

## 25: Add inline documentation to complex demos
status: new
priority: none
kind: none
created: 2025-10-22
updated: 2025-10-23

Complex demos lack sufficient inline documentation: PBR shader calculations, scene graph traversal logic, compute shader algorithms (Game of Life, particle systems), GLTF parsing. Should add: doc comments explaining what each demo demonstrates, inline comments for complex algorithms, references to graphics programming concepts, links to relevant papers/resources. This makes the examples more educational.

---

## 26: Standardize shader management approach
status: new
priority: none
kind: none
created: 2025-10-22
updated: 2025-10-23

Currently have inconsistent shader source management: some demos embed Metal shader code as strings (TriangleDemoView), others use external shader bundles via MetalCompilerPlugin, no shader validation at compile time for string-embedded shaders. Should establish standard approach, document when to use each method, prefer external shaders for complex code, add compile-time validation where possible, standardize namespace usage.

---

## 27: Add Metal validation layer checks for development builds
status: new
priority: none
kind: none
created: 2025-10-22
updated: 2025-10-23

Should enable Metal API validation and shader validation in development builds to catch: incorrect resource usage, memory leaks, invalid render state, shader compilation warnings, performance issues. Add conditional compilation to enable validation layers in debug builds while keeping release builds optimized.

---

## 28: Add proper assertions for Texture2DSpecifier values
status: new
priority: none
kind: none
created: 2025-10-22
updated: 2025-10-23

Found in Sources/MetalSprocketsExamples/Support/Texture2DSpecifier.swift:20, :28, :36

Need to add proper assertions to verify that values are correct in Texture2DSpecifier methods.

Origin: GitHub issue #287

---

## 29: Use Mesh instead of MTKMesh more
status: new
priority: none
kind: none
created: 2025-10-22
updated: 2025-10-23

{"id":"uv-eg-41","title":"Flesh out Mesh","description":"","status":"open","priority":2,"issue_type":"task","created_at":"2025-10-20T19:42:22.465146-07:00","updated_at":"2025-10-21T13:08:41.02548-07:00"}

---

## 30: Make Mesh Codable
status: closed
priority: high
kind: task
created: 2025-10-23
closed: 2025-10-23

- 2025-10-23: Implemented Codable conformance for Mesh and all nested types. MTLBuffer contents are encoded/decoded as Data. Metal enums (MTLPrimitiveType, MTLVertexFormat, MTLVertexStepFunction) use raw UInt values. Codable implementations are in extensions. MTLVertexFormat and MTLVertexStepFunction extensions moved to Support.swift.

---

## 31: Make Network demo use Mesh
status: closed
priority: high
kind: task
created: 2025-10-23
closed: 2025-10-23

- 2025-10-23: Implemented in NetworkListenerDemoView. The demo now converts AR mesh geometries to Mesh objects and renders them using EdgeLinesRenderPass.

---

## 32: Make Edge demo use Mesh
status: closed
priority: high
kind: task
created: 2025-10-23
closed: 2025-10-23

- 2025-10-23: Converted EdgeRenderingDemo (now EdgeLinesDemoView) to use built-in Mesh type instead of MTKMesh. Primitive shapes (plane, cube, sphere) now use TrivialMesh factory methods. Teapot still loads via ModelIO but converts to Mesh. Also moved MeshWithEdges into EdgeLinesRenderPass and renamed EdgeRenderingElement to EdgeLinesRenderPass.

---

## 33: Make Network demo use Edge Renderer
status: closed
priority: high
kind: task
created: 2025-10-23
closed: 2025-10-23

- 2025-10-23: Integrated EdgeLinesRenderPass into Network demo. AR mesh geometries from anchors are now converted to Mesh with edge extraction and rendered using EdgeLinesRenderPass instead of GraphicsContext3D triangle-by-triangle rendering. Meshes rendered in purple with 2.0 line width.

---

## 34: Make the ARKit demo generate Meshes
status: closed
priority: high
kind: task
created: 2025-10-23
closed: 2025-10-23


---

## 35: EdgeLinesRenderPass requires 32-byte stride but ARKit meshes only have 12-byte position data
status: closed
priority: medium
kind: bug
created: 2025-10-23
closed: 2025-10-23

EdgeLinesRenderPass validates 32-byte vertex stride (position+normal+texCoord) but ARKit meshes only have 12-byte position data. Need to either relax validation or pad ARKit vertices.

---

## 36: REname ARKitDemoView to CaptureDemo
status: closed
priority: high
kind: task
created: 2025-10-23
updated: 2025-10-24
closed: 2025-10-24


---

## 37: Make GraphicsContext3D use MetalCanvas.
status: open
priority: high
kind: task
created: 2025-10-24


---

## 38: Finish MetalCanvas (fill, depth)
status: open
priority: high
kind: task
created: 2025-10-24


---

## 39: Look for code that needs to go into GeometryLite3D
status: new
priority: none
kind: task
created: 2025-10-24


---

## 40: Clean up dead code
status: new
priority: none
kind: task
created: 2025-10-24


---

## 41: Clean up duplicate code
status: new
priority: none
kind: task
created: 2025-10-24


---

## 65: Finish World Controller
status: open
priority: none
kind: none
labels: effort:l, MetalSprocketExamples
created: 2025-10-26

We need some way to make controlling the camera and/or a model generic.

**`WorldControllerProtocol`** ("world" is bit too generic)

With implementations:

- FPV (use WASD keys and mouse or GameController)
- RTS (WASD/cursors + mouse)
- Turntable
- Orbit
- Arcball
- Trackball
- Pan & Zoom/CAD
- Flythrough/Drone mode

Common (optional) properties might be:

- cameraMatrix
- modelMatrix
- floor plane
- world volume

Some implementations will need min/max values for various properties and stuff like distance from camera etc.

---
*Imported from #57*

---

## 72: Make demo app use all examples
status: open
priority: none
kind: none
labels: effort:m, MetalSprocketExamples
created: 2025-10-26

We have DemoView (via DemoKit) and Examples in UltraviolenceExamples/ExampleElements.

---
*Imported from #64*

---

## 74: VisionOS demo
status: open
priority: none
kind: none
labels: effort:l, MetalSprocketExamples
created: 2025-10-26

*Imported from #66*

---

## 75: Gooch shader
status: open
priority: none
kind: none
labels: effort:l, MetalSprocketExamples
created: 2025-10-26

*Imported from #67*

---

## 78: Ray Tracing
status: open
priority: none
kind: none
labels: effort:xl, MetalSprocketExamples
created: 2025-10-26

*Imported from #70*

---

## 80: Toon shader
status: open
priority: none
kind: none
labels: effort:l, MetalSprocketExamples
created: 2025-10-26

*Imported from #72*

---

## 114: Handle file extensions properly when loading textures
status: open
priority: none
kind: none
labels: effort:xs, source:todo, MetalSprocketExamples
created: 2025-10-26

Found in Sources/UltraviolenceSupport/MetalSupport.swift at line 790

---
*Imported from #106*

---

## 120: Add unit tests for TypedMTLBuffer
status: open
priority: none
kind: none
labels: effort:s, source:todo, testing, MetalSprocketExamples
created: 2025-10-26

Found in Demo/Packages/UltraviolenceExamples/Sources/UltraviolenceExamples/Support/TypedMTLBuffer.swift at line 3

---
*Imported from #112*

---

## 124: Compute pitch and yaw from camera transform matrix
status: open
priority: none
kind: none
labels: effort:s, source:todo, MetalSprocketExamples
created: 2025-10-26

Found in Demo/Packages/UltraviolenceExamples/Sources/UltraviolenceExamples/Interaction/TurntableCameraController.swift at line 14

---
*Imported from #116*

---

## 136: Pre-calculate matrices in LambertianShader instead of computing in shader
status: closed
priority: none
kind: none
labels: effort:s, source:todo, MetalSprocketExamples
created: 2025-10-26
updated: 2025-10-29
closed: 2025-10-29

Found in Demo/Packages/UltraviolenceExamples/Sources/UltraviolenceExamples/ReuseableElements/LambertianShader.metal at line 32

---
*Imported from #128*

- 2025-10-29: Pre-calculated matrices on CPU side to avoid per-vertex computation:
- Added normalMatrix parameter (float3x3) to both vertex_main and vertex_instanced
- CPU now pre-computes normal matrix (upper-left 3x3 of model matrix)
- For instanced rendering, CPU now pre-computes all MVP matrices and normal matrices per instance
- Removed per-vertex matrix extraction and multiplication from shaders

Performance improvement: Reduces per-vertex computation, especially beneficial for high-poly meshes.

---

## 157: Demo: GPU Text Rendering Pipeline
status: open
priority: none
kind: enhancement
labels: enhancement, demo, MetalSprocketExamples
created: 2025-10-26

## Summary
Implement GPU-accelerated text rendering using signed distance fields or glyph atlases.

## Description
Create a text rendering system that renders text entirely on the GPU for high-performance UI overlays and debug information display.

## Key Features
- SDF (Signed Distance Field) or atlas-based rendering
- Multiple font support
- Dynamic text updates
- Subpixel antialiasing
- Text effects (outline, shadow, glow)
- Unicode support

## Implementation Notes
- Create TextElement for declarative text rendering
- Font atlas generation or SDF texture creation
- Efficient batching for multiple text elements
- Integration with UI overlay system

## Acceptance Criteria
- [ ] Clear, antialiased text rendering
- [ ] Dynamic text updates without CPU overhead
- [ ] Multiple fonts and sizes
- [ ] Basic text effects
- [ ] Good performance with many text elements

---
*Imported from #149*

---

## 169: Demo: VisionOS Immersive Features
status: open
priority: none
kind: enhancement
labels: enhancement, demo, MetalSprocketExamples
created: 2025-10-26

## Summary
Port VisionOS-specific immersive and spatial computing features for Apple Vision Pro.

## Description
Implement spatial computing demos leveraging VisionOS capabilities like immersive spaces, volumes, and hand tracking.

## Key Features
- Immersive space rendering
- Volume-based 3D content
- Compositor Services integration
- Hand tracking interaction
- Spatial audio integration
- Portal effects
- Mixed reality overlays

## Implementation Notes
- Create VisionOSElement for spatial features
- Use RealityKit integration where appropriate
- Implement proper depth handling
- Support immersive and windowed modes

## Acceptance Criteria
- [ ] Basic immersive space working
- [ ] Volume rendering support
- [ ] Hand tracking integration
- [ ] Proper depth and occlusion
- [ ] Example spatial experiences

## Platform Requirements
- VisionOS 2.0+
- Apple Vision Pro hardware or simulator

---
*Imported from #161*

---

## 181: Foil Stickers
status: open
priority: none
kind: none
labels: demo, MetalSprocketExamples
created: 2025-10-26

Implement https://www.4rknova.com/blog/2025/08/30/foil-sticker

---
*Imported from #173*

---

## 226: Break out the video code from the OffscreenVideoRecorder
status: open
priority: none
kind: enhancement
labels: enhancement, MetalSprocketExamples
created: 2025-10-26

It's really just as simple as the offscreen renderer but doing extra work every frame.

---
*Imported from #218*

---

## 227: Add a MetalPaint demo
status: closed
priority: none
kind: feature
labels: feature, MetalSprocketExamples
created: 2025-10-26
closed: 2025-10-26

It's MacPaint but Metal!


---
*Imported from #219*

---

## 253: Make .ultraviolenceExampleShaders() into property
status: closed
priority: none
kind: none
labels: MetalSprocketExamples
created: 2025-10-26
closed: 2025-10-26

*Imported from #245*

---

## 261: Make a generic distort (vertex) shader that we can provide functions to
status: closed
priority: none
kind: feature
labels: feature, MetalSprocketExamples
created: 2025-10-26
closed: 2025-10-26

*Imported from #253*

---

## 262: Make a gamma texture shader
status: closed
priority: none
kind: none
labels: MetalSprocketExamples
created: 2025-10-26
closed: 2025-10-26

*Imported from #254*

---

## 263: Improve CachingImportWell
status: open
priority: none
kind: enhancement
labels: enhancement, MetalSprocketExamples
created: 2025-10-26

*Imported from #255*

---

## 264: Wireframe shader
status: closed
priority: none
kind: none
labels: MetalSprocketExamples
created: 2025-10-26
closed: 2025-10-26

*Imported from #256*

---

## 265: hit testing demo
status: closed
priority: none
kind: none
labels: MetalSprocketExamples
created: 2025-10-26
closed: 2025-10-26

*Imported from #257*

---

## 266: Depth buffer demo is broken
status: closed
priority: none
kind: none
labels: MetalSprocketExamples
created: 2025-10-26
closed: 2025-10-26

*Imported from #258*

---

## 270: Use Ultraviolence's normal shader loading capabilities in ColorAdjustDemoView
status: closed
priority: none
kind: none
labels: MetalSprocketExamples
created: 2025-10-26
closed: 2025-10-26

Found in Sources/UltraviolenceExamples/Demos/ColorAdjustDemo/ColorAdjustDemoView.swift:39

The ColorAdjustDemoView should use Ultraviolence's standard shader loading mechanism instead of custom loading code.

---
*Imported from #262*

---

## 271: Use proper Metal function loading in ColorAdjustDemoView
status: closed
priority: none
kind: none
labels: MetalSprocketExamples
created: 2025-10-26
closed: 2025-10-26

Found in Sources/UltraviolenceExamples/Demos/ColorAdjustDemo/ColorAdjustDemoView.swift:40

The demo currently requires all functions to be named the same. Should use proper Metal function loading instead.

---
*Imported from #263*

---

## 272: Better solution for argument buffer in ColorAdjustComputePipeline
status: closed
priority: none
kind: none
labels: MetalSprocketExamples
created: 2025-10-26
closed: 2025-10-26

Found in Sources/UltraviolenceExamples/Demos/ColorAdjustDemo/ColorAdjustComputePipeline.swift:25

Consider using .argumentBuffer() as a better solution for handling parameters.

---
*Imported from #264*

---

## 273: Move ColorAdjustComputePipeline code to proper location
status: closed
priority: none
kind: none
labels: MetalSprocketExamples
created: 2025-10-26
closed: 2025-10-26

Found in Sources/UltraviolenceExamples/Demos/ColorAdjustDemo/ColorAdjustComputePipeline.swift:37

This code needs to be moved to a more appropriate location in the codebase.

---
*Imported from #265*

---

## 275: Use Ultraviolence's normal shader loading capabilities in DepthDemoView
status: closed
priority: none
kind: none
labels: MetalSprocketExamples
created: 2025-10-26
closed: 2025-10-26

Found in Sources/UltraviolenceExamples/Demos/DepthDemo/DepthDemoView.swift:58

The DepthDemoView should use Ultraviolence's standard shader loading mechanism instead of custom loading code.

---
*Imported from #267*

---

## 276: Use proper Metal function loading in DepthDemoView
status: closed
priority: none
kind: none
labels: MetalSprocketExamples
created: 2025-10-26
closed: 2025-10-26

Found in Sources/UltraviolenceExamples/Demos/DepthDemo/DepthDemoView.swift:59

The demo currently requires all functions to be named the same. Should use proper Metal function loading instead.

---
*Imported from #268*

---

## 277: Improve stitchable functions example in DepthDemoView
status: closed
priority: none
kind: none
labels: MetalSprocketExamples
created: 2025-10-26
closed: 2025-10-26

Found in Sources/UltraviolenceExamples/Demos/DepthDemo/DepthDemoView.swift:60

The current implementation is a terrible example of stitchable functions and needs improvement.

---
*Imported from #269*

---

## 278: Rename Texture2DSpecifier to more descriptive name
status: closed
priority: none
kind: none
labels: MetalSprocketExamples
created: 2025-10-26
closed: 2025-10-26

Found in Sources/UltraviolenceExamples/Support/Texture2DSpecifier.swift:5

The Texture2DSpecifier class should be renamed to TextureSpecifier or something more descriptive.

---
*Imported from #270*

---

## 279: Add proper assertions for Texture2DSpecifier values
status: closed
priority: none
kind: none
labels: MetalSprocketExamples
created: 2025-10-26
closed: 2025-10-26

Found in Sources/UltraviolenceExamples/Support/Texture2DSpecifier.swift:20, :28, :36

Need to add proper assertions to verify that values are correct in Texture2DSpecifier methods.

---
*Imported from #271*

---

## 281: First class visible function support
status: open
priority: high
kind: feature
labels: effort:m, priority:high, feature, MetalSprocketExamples
created: 2025-10-26

We really need to support visible functions. This would unlock/enable a lot of cool "CoreImage-lite" effects where you provide a mini function to (say) convert a color or manipulate a vertex and then the main kernel/shader uses it to manipulate a texture or a mesh.

See https://gist.github.com/schwa/ef6158e8813bc49a14a31ec930b89a0f for how to do it with a simple Compute hello world.

It would be usable from all of these:

#160: Demo: Gamma Correction Pipeline
#154: Demo: Barrel Distortion Post-Processing Effect
#156: Demo: Color Transform Filters
#261: Make a generic distort (vertex) shader that we can provide functions to

---
*Imported from #273*

---

## 282: Replace deprecated Transforms type with separate matrices
status: closed
priority: medium
kind: none
labels: refactor,cleanup
created: 2025-10-29
closed: 2025-10-29

Replace all uses of the deprecated Transforms struct with separate matrices (projectionMatrix, cameraMatrix, viewMatrix, modelMatrix, modelViewMatrix, modelViewProjectionMatrix). Pass the richest matrix needed to shaders. viewMatrix = cameraMatrix.inverse, modelViewMatrix = viewMatrix * modelMatrix, modelViewProjectionMatrix = projectionMatrix * viewMatrix * modelMatrix

---

## 283: Replace Transforms in BlinnPhongShaders.metal (EXAMPLE)
status: closed
priority: medium
kind: none
labels: refactor,shader
depends: MetalSprocketsExamples#282
created: 2025-10-29
closed: 2025-10-29

Replace Transforms buffer parameter with separate matrices (projectionMatrix, cameraMatrix, modelMatrix). Calculate viewMatrix, modelViewMatrix, and modelViewProjectionMatrix in shader. This is the FIRST example to fix.

- 2025-10-29: Replaced Transforms buffer with separate projectionMatrix, viewMatrix, and modelMatrix buffers in vertex shader. Fragment shader now only receives cameraMatrix. viewMatrix is passed from Swift (cameraMatrix.inverse) instead of being calculated in shader. Matrices calculated: modelViewMatrix = viewMatrix * modelMatrix, modelViewProjectionMatrix = projectionMatrix * viewMatrix * modelMatrix.

---

## 284: Replace Transforms in BlinnPhongDemoView.swift
status: closed
priority: medium
kind: none
labels: refactor,swift
depends: MetalSprocketsExamples#282
created: 2025-10-29
closed: 2025-10-29

Update BlinnPhongDemoView to pass separate matrices instead of Transforms struct. Uses .transforms() modifier at line 62.

- 2025-10-29: Replaced .transforms() modifier with separate .parameter() calls: projectionMatrix (vertex), viewMatrix (vertex), modelMatrix (vertex), and cameraMatrix (fragment). Build succeeds.

---

## 285: Replace Transforms in Panorama.metal
status: closed
priority: medium
kind: none
labels: refactor,shader
depends: MetalSprocketsExamples#282
created: 2025-10-29
closed: 2025-10-29

Replace Transforms buffer parameter with separate matrices in Panorama shader (line 21).

- 2025-10-29: Updated Panorama.metal to use separate matrices (projectionMatrix, viewMatrix, modelMatrix) at buffers 1, 2, 3. Removed Transforms dependency.

---

## 286: Replace Transforms in HitTestShaders.metal
status: closed
priority: medium
kind: none
labels: refactor,shader
depends: MetalSprocketsExamples#282
created: 2025-10-29
closed: 2025-10-29

Replace Transforms buffer parameter with separate matrices in HitTest shader (line 34).

---

## 287: Replace Transforms in DepthShader.metal
status: closed
priority: medium
kind: none
labels: refactor,shader
depends: MetalSprocketsExamples#282
created: 2025-10-29
closed: 2025-10-29

Replace Transforms buffer parameter with separate matrices in Depth shader (line 16).

---

## 288: Replace Transforms in SkyboxShader.metal
status: closed
priority: medium
kind: none
labels: refactor,shader
depends: MetalSprocketsExamples#282
created: 2025-10-29
closed: 2025-10-29

Replace Transforms buffer parameter with separate matrices in Skybox shader (line 16).

- 2025-10-29: Updated SkyboxShader.metal to use separate matrices (projectionMatrix, viewMatrix, modelMatrix) at buffers 1, 2, 3. Removed Transforms dependency.

---

## 289: Replace Transforms in BouncingTeapotsDemoView.swift
status: closed
priority: medium
kind: none
labels: refactor,swift
depends: MetalSprocketsExamples#282
created: 2025-10-29
closed: 2025-10-29

Update BouncingTeapotsDemoView to pass separate matrices instead of Transforms struct (lines 73, 127, 147).

---

## 290: Replace Transforms in TeapotDemo.swift
status: closed
priority: medium
kind: none
labels: refactor,swift
depends: MetalSprocketsExamples#282
created: 2025-10-29
closed: 2025-10-29

Update TeapotDemo to use separate matrices instead of storing Transforms (lines 19, 22, 24, 31).

---

## 291: Replace Transforms in SceneGraphRenderPass.swift
status: closed
priority: medium
kind: none
labels: refactor,swift
depends: MetalSprocketsExamples#282
created: 2025-10-29
closed: 2025-10-29

Update SceneGraphRenderPass to pass separate matrices instead of Transforms (line 75).

- 2025-10-29: Updated SceneGraphRenderPass to use .blinnPhongMatrices() instead of .transforms(). Added viewMatrix calculation at line 59. BlinnPhong shader now fully migrated in SceneGraph.

---

## 292: Replace .transforms() modifier in HitTestDemoView.swift
status: closed
priority: medium
kind: none
labels: refactor,swift
depends: MetalSprocketsExamples#282
created: 2025-10-29
closed: 2025-10-29

Update HitTestDemoView to use new matrix parameters instead of .transforms() modifier.

- 2025-10-29: Fixed BlinnPhong shader usage in HitTestDemoView. Replaced .transforms() with .blinnPhongMatrices() at line 84. Note: HitTestShader (line 99) still uses .transforms() - will be updated when HitTest shader is migrated (issue #286).

---

## 293: Replace .transforms() modifier in TrivialMeshDemoView.swift
status: closed
priority: medium
kind: none
labels: refactor,swift
depends: MetalSprocketsExamples#282
created: 2025-10-29
closed: 2025-10-29

Update TrivialMeshDemoView to use new matrix parameters instead of .transforms() modifier.

- 2025-10-29: Updated TrivialMeshDemoView to use .blinnPhongMatrices() instead of .transforms() at line 312. viewMatrix was already available at line 293.

---

## 294: Replace .transforms() modifier in PanoramaElements.swift
status: closed
priority: medium
kind: none
labels: refactor,swift
depends: MetalSprocketsExamples#282
created: 2025-10-29
closed: 2025-10-29

Update PanoramaElements to use new matrix parameters instead of .transforms() modifier.

- 2025-10-29: Updated PanoramaElements.swift to pass separate matrices using .parameter() calls. Calculates viewMatrix = cameraMatrix.inverse, passes modelMatrix as .identity. Build succeeds.

---

## 295: Replace .transforms() modifier in SkyboxDemoView.swift
status: closed
priority: medium
kind: none
labels: refactor,swift
depends: MetalSprocketsExamples#282
created: 2025-10-29
closed: 2025-10-29

Update SkyboxDemoView to use new matrix parameters instead of .transforms() modifier.

- 2025-10-29: Updated SkyboxDemoView.swift to pass separate matrices using .parameter() calls. Calculates viewMatrix = cameraMatrix.inverse, passes modelMatrix as .identity. Build succeeds.

---

## 296: Remove .transforms() Element extension
status: closed
priority: medium
kind: none
labels: refactor,cleanup
depends: MetalSprocketsExamples#282
created: 2025-10-29
closed: 2025-10-29

Remove the deprecated .transforms() extension from Transforms.swift (lines 26-34) after all usages are replaced.

---

## 297: Remove Transforms struct from Support.h
status: closed
priority: medium
kind: none
labels: refactor,cleanup
depends: MetalSprocketsExamples#282
created: 2025-10-29
closed: 2025-10-29

Remove the Transforms struct definition from Support.h (lines 69-80) after all usages are replaced.

---

## 298: Remove Transforms.swift file
status: closed
priority: medium
kind: none
labels: refactor,cleanup
depends: MetalSprocketsExamples#282
created: 2025-10-29
closed: 2025-10-29

Remove Transforms.swift file entirely after all usages are replaced and the struct is removed from Support.h.

---

## 299: Shaders should try not to do MVP concat in GPU - do in CPU
status: closed
priority: none
kind: task
created: 2025-10-29
closed: 2025-10-29


---

## 300: Include a default panorama image.
status: new
priority: none
kind: task
created: 2025-10-29


---

## 301: Use 4x3 matrices instead of 4x4
status: new
priority: medium
kind: enhancement
created: 2025-10-29

Use 4x3 matrixes instead of 4x4 where possible. This incurs some ceremony on both the CPU and GPU

---

## 302: Fix #import vs #include in shader code
status: closed
priority: medium
kind: none
created: 2025-10-29
closed: 2025-10-29

- 2025-10-29: Fixed all shader files in MetalSprocketsAddOnsShaders to use #import instead of #include for consistency with MetalSprocketsExampleShaders. This ensures headers are only included once, preventing potential multiple definition errors.
- 2025-10-29: Standardized all 37 shader files to use #include instead of #import. Both header files (MetalSprocketsAddOnsShaders.h and MetalSprocketsExampleShaders.h) have #pragma once to prevent multiple inclusion issues. Using #include with #pragma once is the consistent approach across the codebase.

---

## 303: Move MetalSprocketsAddOns targets from Examples to AddOns project
status: closed
priority: medium
kind: none
created: 2025-10-29
closed: 2025-10-29

Move the MetalSprocketsAddOns and MetalSprocketsAddOnsShaders targets from MetalSprocketsExamples to the MetalSprocketsAddOns companion project.

## Targets to Move
- **MetalSprocketsAddOns** - Main addon library code (Sources/MetalSprocketsAddOns)
- **MetalSprocketsAddOnsShaders** - Shader code (Sources/MetalSprocketsAddOnsShaders)

Note: MikkTSpace is identical in both projects and can be ignored.

## Source Locations
- **Examples project**: /Users/schwa/Shared/Projects/MetalSprocketsExamples/Packages/MetalSprocketsExamples
- **AddOns project**: /Users/schwa/Shared/Projects/MetalSprocketsAddOns

## Tasks
1. **Move source directories** (don't copy, move):
   - Move Sources/MetalSprocketsAddOns from Examples to AddOns (overwrite existing)
   - Move Sources/MetalSprocketsAddOnsShaders from Examples to AddOns (overwrite existing)
   - When conflicts exist, Examples version always wins

2. **Update Examples Package.swift**:
   - Remove MetalSprocketsAddOns target definition (lines 88-101)
   - Remove MetalSprocketsAddOnsShaders target definition (lines 102-109)
   - Remove MetalSprocketsAddOns from products list (line 14)
   - Uncomment the AddOns package dependency (lines 27-28)
   - Update target dependencies to use external package:
     - MetalSprocketsExamples target: change "MetalSprocketsAddOns" to .product(name: "MetalSprocketsAddOns", package: "MetalSprocketsAddOns")
     - CaptureExample target: same change for MetalSprocketsAddOns dependency
   - Add earcut-swift dependency to AddOns package dependencies if not present

3. **Verify builds** (in order):
   - Build the AddOns project first to ensure it compiles with the moved code
   - Then build the Examples project to ensure it correctly references the AddOns external package

## Expected Outcome
- AddOns project contains the latest code from Examples
- AddOns project builds successfully
- Examples project depends on AddOns as an external package
- Examples project builds successfully
- No duplication of AddOns code between projects

- 2025-10-29: Migration complete. MetalSprocketsAddOns and MetalSprocketsAddOnsShaders targets successfully moved from Examples to AddOns. Both projects build successfully. Hard-coded paths in metal-compiler-plugin.json tracked separately in #304.

---

## 304: Remove hard-coded paths from metal-compiler-plugin.json files
status: closed
priority: medium
kind: none
created: 2025-10-29
closed: 2025-10-29

Both MetalSprocketsExamples and MetalSprocketsAddOns have hard-coded absolute paths in their metal-compiler-plugin.json files.

## Affected Files

1. **Examples**: `/Users/schwa/Shared/Projects/MetalSprocketsExamples/Packages/MetalSprocketsExamples/Sources/MetalSprocketsExampleShaders/metal-compiler-plugin.json`
   - Line 6: `"-I", "/Users/schwa/Shared/Projects/MetalSprocketsExamples/Packages/MetalSprocketsExamples/Sources/MetalSprocketsExampleShaders/include"`

2. **AddOns**: `/Users/schwa/Shared/Projects/MetalSprocketsAddOns/Sources/MetalSprocketsAddOnsShaders/metal-compiler-plugin.json`
   - Line 6: `"-I", "/Users/schwa/Shared/Projects/MetalSprocketsAddOns/Sources/MetalSprocketsAddOnsShaders/include"`

## Problem

Hard-coded absolute paths make the project non-portable and cause issues when:
- Building on different machines
- Using different directory structures
- Working in CI/CD environments

## Possible Solutions

1. Remove the `-I` flags and rely on `dependency-path-suffix` (already set to "include")
2. Use relative paths instead of absolute paths
3. Update MetalCompilerPlugin to auto-detect paths based on target structure
4. Use environment variables or build-time substitution

- 2025-10-29: Fixed by removing hard-coded -I flags from metal-compiler-plugin.json files. Now relying on dependency-path-suffix which is portable.

---

## 305: Remove hard-coded path to MetalCompilerPlugin package
status: closed
priority: medium
kind: none
created: 2025-10-29
closed: 2025-10-29

The Examples Package.swift has a hard-coded absolute path to the MetalCompilerPlugin package dependency.

## Affected File

**Examples Package.swift**: Line 24
```swift
.package(path: "/Users/schwa/Projects//MetalCompilerPlugin"),
```

The commented-out line 23 shows the intended production dependency:
```swift
//        .package(url: "https://github.com/schwa/MetalCompilerPlugin", from: "0.1.3"),
```

## Problem

The hard-coded local path:
- Makes the project non-portable across different machines
- Requires manual editing for other developers
- Cannot be used in CI/CD environments
- Has a typo with double slashes (`//`)

## Solution

Once the required MetalCompilerPlugin fixes are released:
1. Uncomment line 23 with the proper version
2. Remove or comment out line 24 with the local path
3. Update to the new version that supports cross-package shader dependencies

- 2025-10-29: Fixed by upgrading to MetalCompilerPlugin 0.1.4 which includes the necessary cross-package shader dependency support. Removed hard-coded local paths in both Examples and AddOns Package.swift files.

---

