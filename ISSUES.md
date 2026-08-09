# ISSUES.md

---

## 1: Hit testing demo

+++
status: closed
priority: none
kind: none
created: 2025-10-22T00:00:00Z
updated: 2025-10-23T00:00:00Z
closed: 2025-10-23T00:00:00Z
+++

Create a demo that demonstrates hit testing capabilities.

Origin: GitHub issue #273

---

## 2: Fix up names of shaders vs demos vs demo views vs elements

+++
status: closed
priority: none
kind: enhancement
created: 2025-10-22T00:00:00Z
updated: 2026-04-03T04:25:23Z
closed: 2026-04-03T04:25:23Z
+++

e.g. TextureBillboard vs BillboardShader etc

Need to standardize naming conventions across the examples project.

Origin: GitHub issue #250

- `2026-04-03T04:25:23Z`: Closing as stale/no longer relevant.

---

## 3: Code Reuse Pass

+++
status: closed
priority: none
kind: enhancement
created: 2025-10-22T00:00:00Z
updated: 2026-04-03T04:25:23Z
closed: 2026-04-03T04:25:23Z
+++

Go through all demo code and look for code reuse opportunities.

Lots of shaders are doing very similar things now and the demos are bloating a little.

Also look for chances to make these part of Batteries Included.

Origin: GitHub issue #246

- `2026-04-03T04:25:23Z`: Closing as stale/no longer relevant.

---

## 4: [NEW DEMO] MetalPaint

+++
status: open
priority: low
kind: feature
labels: effort:l, deferred
created: 2025-10-22T00:00:00Z
updated: 2026-08-09T16:23:47Z
+++

It's MacPaint but Metal!

Create a painting/drawing demo using Metal.

Origin: GitHub issue #235

---

## 5: Make more demos runable in offscreen(video)renderer

+++
status: closed
priority: none
kind: feature
created: 2025-10-22T00:00:00Z
updated: 2026-04-03T04:35:11Z
closed: 2026-04-03T04:35:11Z
+++

Enable additional demos to work with the offscreen video renderer.

Origin: GitHub issue #215

- `2026-04-03T04:35:11Z`: Closing — OffscreenVideoRenderer lives in MetalSprockets now.

---

## 6: Move demos back into own repo

+++
status: closed
priority: none
kind: none
created: 2025-10-22T00:00:00Z
updated: 2025-10-23T00:00:00Z
closed: 2025-10-23T00:00:00Z
+++

Separate the demos into their own repository.

Origin: GitHub issue #213

---

## 7: Standalone demo

+++
status: closed
priority: none
kind: feature
created: 2025-10-22T00:00:00Z
updated: 2026-04-02T21:57:01Z
closed: 2026-04-02T21:57:01Z
+++

Create the simplest possible demo that can run independently.

Origin: GitHub issue #212

- `2026-04-02T22:18:00Z`: Too vague to be actionable.

---

## 8: AxisLines should extend to screen edges instead of fixed world-space length

+++
status: closed
priority: none
kind: none
created: 2025-10-22T00:00:00Z
updated: 2025-10-24T00:00:00Z
closed: 2025-10-24T00:00:00Z
+++

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

+++
status: closed
priority: none
kind: enhancement
created: 2025-10-22T00:00:00Z
updated: 2026-04-03T04:25:23Z
closed: 2026-04-03T04:25:23Z
+++

Convert the .metal-sprocketsExampleShaders() method into a property for cleaner API.

Origin: GitHub issue #261

- `2026-04-03T04:25:23Z`: Closing as stale/no longer relevant.

---

## 10: Sanitize vertex descriptors

+++
status: closed
priority: none
kind: enhancement
created: 2025-10-22T00:00:00Z
updated: 2026-04-03T04:33:15Z
closed: 2026-04-03T04:33:15Z
+++

Clean up and standardize vertex descriptors across the examples project.

Origin: GitHub issue #259

- `2026-04-03T04:33:15Z`: Too vague.

---

## 11: Link all all issues from metal-sprockets

+++
status: closed
priority: none
kind: none
created: 2025-10-22T00:00:00Z
updated: 2025-10-24T00:00:00Z
closed: 2025-10-24T00:00:00Z
+++

{"id":"uv-eg-20","title":"Make sure all compute examples are using good sizes","description":"Review all compute shader examples to ensure they're using appropriate thread group sizes and dispatch sizes for optimal performance.\n\nOrigin: GitHub issue #252","status":"open","priority":2,"issue_type":"task","created_at":"2025-10-20T19:42:22.465146-07:00","updated_at":"2025-10-21T13:08:41.019653-07:00"}

---

## 23: Implement texture pooling/reuse strategy

+++
status: closed
priority: none
kind: feature
created: 2025-10-22T00:00:00Z
updated: 2026-04-03T04:34:18Z
closed: 2026-04-03T04:34:18Z
+++

Currently each demo creates textures on-demand in init/onChange handlers with no reuse strategy. Issues: potential resource leaks in long-running demos, no centralized lifecycle management, repeated allocation/deallocation overhead. Should implement texture pooling for common sizes/formats to improve performance and resource management.

- `2026-04-03T04:34:18Z`: Closing as stale/no longer relevant.

---

## 24: Extract common UI controls into reusable components

+++
status: closed
priority: high
kind: enhancement
created: 2025-10-22T00:00:00Z
updated: 2026-04-03T00:57:21Z
closed: 2026-04-03T00:57:21Z
+++

Many demos duplicate similar UI patterns: slider controls for parameters, color pickers, dropdown menus, reset/download buttons. Should create reusable SwiftUI components in Support/ or new UI/ directory: ParameterSlider, DemoColorPicker, DemoOptionPicker, etc. This will reduce code duplication and ensure consistent UI across demos.

- `2026-04-03T00:57:22Z`: Done — all demos ported to DemoKit demoConfiguration, custom menu replaced with DemosCommandMenu

---

## 25: Add inline documentation to complex demos

+++
status: closed
priority: none
kind: enhancement
created: 2025-10-22T00:00:00Z
updated: 2026-04-03T04:34:19Z
closed: 2026-04-03T04:34:19Z
+++

Complex demos lack sufficient inline documentation: PBR shader calculations, scene graph traversal logic, compute shader algorithms (Game of Life, particle systems), GLTF parsing. Should add: doc comments explaining what each demo demonstrates, inline comments for complex algorithms, references to graphics programming concepts, links to relevant papers/resources. This makes the examples more educational.

- `2026-04-03T04:34:19Z`: Closing as stale/no longer relevant.

---

## 26: Standardize shader management approach

+++
status: closed
priority: none
kind: enhancement
created: 2025-10-22T00:00:00Z
updated: 2026-04-03T04:34:19Z
closed: 2026-04-03T04:34:19Z
+++

Currently have inconsistent shader source management: some demos embed Metal shader code as strings (TriangleDemoView), others use external shader bundles via MetalCompilerPlugin, no shader validation at compile time for string-embedded shaders. Should establish standard approach, document when to use each method, prefer external shaders for complex code, add compile-time validation where possible, standardize namespace usage.

- `2026-04-03T04:34:19Z`: Closing as stale/no longer relevant.

---

## 27: Add Metal validation layer checks for development builds

+++
status: closed
priority: none
kind: enhancement
created: 2025-10-22T00:00:00Z
updated: 2026-04-03T04:34:19Z
closed: 2026-04-03T04:34:19Z
+++

Should enable Metal API validation and shader validation in development builds to catch: incorrect resource usage, memory leaks, invalid render state, shader compilation warnings, performance issues. Add conditional compilation to enable validation layers in debug builds while keeping release builds optimized.

- `2026-04-03T04:34:19Z`: Closing as stale/no longer relevant.

---

## 28: Add proper assertions for Texture2DSpecifier values

+++
status: closed
priority: none
kind: none
created: 2025-10-22T00:00:00Z
updated: 2026-04-02T21:45:22Z
closed: 2026-04-02T21:45:22Z
+++

Found in Sources/MetalSprocketsExamples/Support/Texture2DSpecifier.swift:20, :28, :36

Need to add proper assertions to verify that values are correct in Texture2DSpecifier methods.

Origin: GitHub issue #287

- `2026-04-02T22:18:00Z`: Duplicate of #279 which is already closed/done.

---

## 29: Use Mesh instead of MTKMesh more

+++
status: closed
priority: none
kind: enhancement
created: 2025-10-22T00:00:00Z
updated: 2026-04-03T04:34:19Z
closed: 2026-04-03T04:34:19Z
+++

Migrate demos that still use MTKMesh to the custom Mesh type where possible.

- `2026-04-03T04:34:19Z`: Closing as stale/no longer relevant.

---

## 30: Make Mesh Codable

+++
status: closed
priority: none
kind: task
created: 2025-10-23T00:00:00Z
closed: 2025-10-23T00:00:00Z
+++

- `2026-04-02T22:18:00Z`: Implemented Codable conformance for Mesh and all nested types. MTLBuffer contents are encoded/decoded as Data. Metal enums (MTLPrimitiveType, MTLVertexFormat, MTLVertexStepFunction) use raw UInt values. Codable implementations are in extensions. MTLVertexFormat and MTLVertexStepFunction extensions moved to Support.swift.

---

## 31: Make Network demo use Mesh

+++
status: closed
priority: none
kind: task
created: 2025-10-23T00:00:00Z
closed: 2025-10-23T00:00:00Z
+++

- `2026-04-02T22:18:00Z`: Implemented in NetworkListenerDemoView. The demo now converts AR mesh geometries to Mesh objects and renders them using EdgeLinesRenderPass.

---

## 32: Make Edge demo use Mesh

+++
status: closed
priority: none
kind: task
created: 2025-10-23T00:00:00Z
closed: 2025-10-23T00:00:00Z
+++

- `2026-04-02T22:18:00Z`: Converted EdgeRenderingDemo (now EdgeLinesDemoView) to use built-in Mesh type instead of MTKMesh. Primitive shapes (plane, cube, sphere) now use TrivialMesh factory methods. Teapot still loads via ModelIO but converts to Mesh. Also moved MeshWithEdges into EdgeLinesRenderPass and renamed EdgeRenderingElement to EdgeLinesRenderPass.

---

## 33: Make Network demo use Edge Renderer

+++
status: closed
priority: none
kind: task
created: 2025-10-23T00:00:00Z
closed: 2025-10-23T00:00:00Z
+++

- `2026-04-02T22:18:00Z`: Integrated EdgeLinesRenderPass into Network demo. AR mesh geometries from anchors are now converted to Mesh with edge extraction and rendered using EdgeLinesRenderPass instead of GraphicsContext3D triangle-by-triangle rendering. Meshes rendered in purple with 2.0 line width.

---

## 34: Make the ARKit demo generate Meshes

+++
status: closed
priority: none
kind: task
created: 2025-10-23T00:00:00Z
closed: 2025-10-23T00:00:00Z
+++

---

## 35: EdgeLinesRenderPass requires 32-byte stride but ARKit meshes only have 12-byte position data

+++
status: closed
priority: none
kind: bug
created: 2025-10-23T00:00:00Z
closed: 2025-10-23T00:00:00Z
+++

EdgeLinesRenderPass validates 32-byte vertex stride (position+normal+texCoord) but ARKit meshes only have 12-byte position data. Need to either relax validation or pad ARKit vertices.

---

## 36: REname ARKitDemoView to CaptureDemo

+++
status: closed
priority: none
kind: task
created: 2025-10-23T00:00:00Z
updated: 2025-10-24T00:00:00Z
closed: 2025-10-24T00:00:00Z
+++

---

## 37: Make GraphicsContext3D use MetalCanvas.

+++
status: closed
priority: none
kind: feature
created: 2025-10-24T00:00:00Z
updated: 2026-04-02T22:02:52Z
closed: 2026-04-02T22:02:52Z
+++

- `2026-04-02T22:18:00Z`: Moot — see #317 and #318 for deprecation discussion of GraphicsContext3D and MetalCanvas.

---

## 38: Finish MetalCanvas (fill, depth)

+++
status: closed
priority: none
kind: feature
created: 2025-10-24T00:00:00Z
updated: 2026-04-02T22:02:52Z
closed: 2026-04-02T22:02:52Z
+++

- `2026-04-02T22:18:00Z`: Moot — see #317 and #318 for deprecation discussion of GraphicsContext3D and MetalCanvas.

---

## 39: Look for code that needs to go into GeometryLite3D

+++
status: closed
priority: none
kind: enhancement
created: 2025-10-24T00:00:00Z
updated: 2026-04-02T22:02:52Z
closed: 2026-04-02T22:02:52Z
+++

- `2026-04-02T22:18:00Z`: No longer relevant.

---

## 40: Clean up dead code

+++
status: closed
priority: none
kind: enhancement
created: 2025-10-24T00:00:00Z
updated: 2026-04-03T04:25:23Z
closed: 2026-04-03T04:25:23Z
+++

- `2026-04-03T04:25:23Z`: Closing as stale/no longer relevant.

---

## 41: Clean up duplicate code

+++
status: closed
priority: none
kind: enhancement
created: 2025-10-24T00:00:00Z
updated: 2026-04-03T04:25:23Z
closed: 2026-04-03T04:25:23Z
+++

- `2026-04-03T04:25:23Z`: Closing as stale/no longer relevant.

---

## 65: Finish World Controller

+++
status: closed
priority: none
kind: feature
labels: effort:l
created: 2025-10-26T00:00:00Z
updated: 2026-04-03T04:34:19Z
closed: 2026-04-03T04:34:19Z
+++

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

*Imported from #57*

- `2026-04-03T04:34:19Z`: Closing as stale/no longer relevant.

---

## 72: Make demo app use all examples

+++
status: closed
priority: none
kind: none
labels: effort:m
created: 2025-10-26T00:00:00Z
updated: 2026-04-02T21:46:10Z
closed: 2026-04-02T21:46:10Z
+++

We have DemoView (via DemoKit) and Examples in UltraviolenceExamples/ExampleElements.

*Imported from #64*

- `2026-04-02T22:18:00Z`: Done — all demos are registered in allDemos.

---

## 74: VisionOS demo

+++
status: open
priority: low
kind: feature
labels: effort:l, deferred
created: 2025-10-26T00:00:00Z
updated: 2026-08-09T16:23:48Z
+++

Add visionOS-specific demos, e.g. immersive mode rendering.

---

## 75: [NEW DEMO] Gooch shader

+++
status: open
priority: low
kind: feature
labels: effort:l, deferred
created: 2025-10-26T00:00:00Z
updated: 2026-08-09T16:23:48Z
+++

*Imported from #67*

---

## 78: [NEW DEMO] Ray Tracing

+++
status: closed
priority: low
kind: feature
labels: effort:xl
created: 2025-10-26T00:00:00Z
updated: 2026-04-04T01:36:14Z
closed: 2026-04-04T01:36:14Z
+++

*Imported from #70*

- `2026-04-04T01:36:14Z`: Implemented Cornell box ray tracing demo with Next Event Estimation, interactive camera via WorldView turntable, per-quad normals, Reinhard tone mapping, and progressive accumulation.

---

## 80: [NEW DEMO] Toon shader

+++
status: open
priority: low
kind: feature
labels: effort:l, deferred
created: 2025-10-26T00:00:00Z
updated: 2026-08-09T16:23:48Z
+++

*Imported from #72*

---

## 114: Handle file extensions properly when loading textures

+++
status: closed
priority: none
kind: bug
labels: effort:xs, source:todo
created: 2025-10-26T00:00:00Z
updated: 2026-04-03T04:26:14Z
closed: 2026-04-03T04:26:14Z
+++

Found in Sources/UltraviolenceSupport/MetalSupport.swift at line 790

*Imported from #106*

- `2026-04-03T04:26:14Z`: Stale — referenced file no longer exists.

---

## 120: Add unit tests for TypedMTLBuffer

+++
status: closed
priority: none
kind: enhancement
labels: effort:s, source:todo, testing
created: 2025-10-26T00:00:00Z
updated: 2026-04-02T22:02:53Z
closed: 2026-04-02T22:02:53Z
+++

Found in Demo/Packages/UltraviolenceExamples/Sources/UltraviolenceExamples/Support/TypedMTLBuffer.swift at line 3

*Imported from #112*

- `2026-04-02T22:18:00Z`: TypedMTLBuffer no longer exists.

---

## 124: Compute pitch and yaw from camera transform matrix

+++
status: closed
priority: none
kind: enhancement
labels: effort:s, source:todo
created: 2025-10-26T00:00:00Z
updated: 2026-04-02T22:02:53Z
closed: 2026-04-02T22:02:53Z
+++

Found in Demo/Packages/UltraviolenceExamples/Sources/UltraviolenceExamples/Interaction/TurntableCameraController.swift at line 14

*Imported from #116*

- `2026-04-02T22:18:00Z`: No longer relevant.

---

## 136: Pre-calculate matrices in LambertianShader instead of computing in shader

+++
status: closed
priority: none
kind: none
labels: effort:s, source:todo
created: 2025-10-26T00:00:00Z
updated: 2025-10-29T00:00:00Z
closed: 2025-10-29T00:00:00Z
+++

Found in Demo/Packages/UltraviolenceExamples/Sources/UltraviolenceExamples/ReuseableElements/LambertianShader.metal at line 32

*Imported from #128*
- Added normalMatrix parameter (float3x3) to both vertex_main and vertex_instanced
- CPU now pre-computes normal matrix (upper-left 3x3 of model matrix)
- For instanced rendering, CPU now pre-computes all MVP matrices and normal matrices per instance
- Removed per-vertex matrix extraction and multiplication from shaders

Performance improvement: Reduces per-vertex computation, especially beneficial for high-poly meshes.

- `2026-04-02T22:18:00Z`: Pre-calculated matrices on CPU side to avoid per-vertex computation:

---

## 157: [NEW DEMO] GPU Text Rendering Pipeline

+++
status: closed
priority: low
kind: feature
labels: effort:xl
created: 2025-10-26T00:00:00Z
updated: 2026-04-04T00:50:47Z
closed: 2026-04-04T00:50:47Z
+++

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

*Imported from #149*

---

## 169: [NEW DEMO] VisionOS Immersive Features

+++
status: closed
priority: none
kind: enhancement
created: 2025-10-26T00:00:00Z
updated: 2026-04-02T22:02:53Z
closed: 2026-04-02T22:02:53Z
+++

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

*Imported from #161*

- `2026-04-02T22:18:00Z`: Duplicate of #74.

---

## 181: [NEW DEMO] Foil Stickers

+++
status: open
priority: low
kind: feature
labels: effort:m, deferred
created: 2025-10-26T00:00:00Z
updated: 2026-08-09T16:23:48Z
+++

Implement https://www.4rknova.com/blog/2025/08/30/foil-sticker

*Imported from #173*

---

## 226: Break out the video code from the OffscreenVideoRecorder

+++
status: closed
priority: none
kind: enhancement
created: 2025-10-26T00:00:00Z
updated: 2026-04-03T04:35:11Z
closed: 2026-04-03T04:35:11Z
+++

It's really just as simple as the offscreen renderer but doing extra work every frame.

*Imported from #218*

- `2026-04-03T04:35:11Z`: Closing — OffscreenVideoRenderer lives in MetalSprockets now.

---

## 227: Add a MetalPaint demo

+++
status: closed
priority: none
kind: feature
created: 2025-10-26T00:00:00Z
closed: 2025-10-26T00:00:00Z
+++

It's MacPaint but Metal!


*Imported from #219*

---

## 253: Make .ultraviolenceExampleShaders() into property

+++
status: closed
priority: none
kind: none
created: 2025-10-26T00:00:00Z
closed: 2025-10-26T00:00:00Z
+++

*Imported from #245*

---

## 261: Make a generic distort (vertex) shader that we can provide functions to

+++
status: closed
priority: none
kind: feature
created: 2025-10-26T00:00:00Z
closed: 2025-10-26T00:00:00Z
+++

*Imported from #253*

---

## 262: Make a gamma texture shader

+++
status: closed
priority: none
kind: none
created: 2025-10-26T00:00:00Z
closed: 2025-10-26T00:00:00Z
+++

*Imported from #254*

---

## 263: Improve CachingImportWell

+++
status: closed
priority: none
kind: enhancement
created: 2025-10-26T00:00:00Z
updated: 2026-04-02T21:57:01Z
closed: 2026-04-02T21:57:01Z
+++

*Imported from #255*

- `2026-04-02T22:18:00Z`: CachingImportWell no longer exists (renamed to SuperImportWell). Reopen with specifics if needed.

---

## 264: Wireframe shader

+++
status: closed
priority: none
kind: none
created: 2025-10-26T00:00:00Z
closed: 2025-10-26T00:00:00Z
+++

*Imported from #256*

---

## 265: hit testing demo

+++
status: closed
priority: none
kind: none
created: 2025-10-26T00:00:00Z
closed: 2025-10-26T00:00:00Z
+++

*Imported from #257*

---

## 266: Depth buffer demo is broken

+++
status: closed
priority: none
kind: none
created: 2025-10-26T00:00:00Z
closed: 2025-10-26T00:00:00Z
+++

*Imported from #258*

---

## 270: Use Ultraviolence's normal shader loading capabilities in ColorAdjustDemoView

+++
status: closed
priority: none
kind: none
created: 2025-10-26T00:00:00Z
closed: 2025-10-26T00:00:00Z
+++

Found in Sources/UltraviolenceExamples/Demos/ColorAdjustDemo/ColorAdjustDemoView.swift:39

The ColorAdjustDemoView should use Ultraviolence's standard shader loading mechanism instead of custom loading code.

*Imported from #262*

---

## 271: Use proper Metal function loading in ColorAdjustDemoView

+++
status: closed
priority: none
kind: none
created: 2025-10-26T00:00:00Z
closed: 2025-10-26T00:00:00Z
+++

Found in Sources/UltraviolenceExamples/Demos/ColorAdjustDemo/ColorAdjustDemoView.swift:40

The demo currently requires all functions to be named the same. Should use proper Metal function loading instead.

*Imported from #263*

---

## 272: Better solution for argument buffer in ColorAdjustComputePipeline

+++
status: closed
priority: none
kind: none
created: 2025-10-26T00:00:00Z
closed: 2025-10-26T00:00:00Z
+++

Found in Sources/UltraviolenceExamples/Demos/ColorAdjustDemo/ColorAdjustComputePipeline.swift:25

Consider using .argumentBuffer() as a better solution for handling parameters.

*Imported from #264*

---

## 273: Move ColorAdjustComputePipeline code to proper location

+++
status: closed
priority: none
kind: none
created: 2025-10-26T00:00:00Z
closed: 2025-10-26T00:00:00Z
+++

Found in Sources/UltraviolenceExamples/Demos/ColorAdjustDemo/ColorAdjustComputePipeline.swift:37

This code needs to be moved to a more appropriate location in the codebase.

*Imported from #265*

---

## 275: Use Ultraviolence's normal shader loading capabilities in DepthDemoView

+++
status: closed
priority: none
kind: none
created: 2025-10-26T00:00:00Z
closed: 2025-10-26T00:00:00Z
+++

Found in Sources/UltraviolenceExamples/Demos/DepthDemo/DepthDemoView.swift:58

The DepthDemoView should use Ultraviolence's standard shader loading mechanism instead of custom loading code.

*Imported from #267*

---

## 276: Use proper Metal function loading in DepthDemoView

+++
status: closed
priority: none
kind: none
created: 2025-10-26T00:00:00Z
closed: 2025-10-26T00:00:00Z
+++

Found in Sources/UltraviolenceExamples/Demos/DepthDemo/DepthDemoView.swift:59

The demo currently requires all functions to be named the same. Should use proper Metal function loading instead.

*Imported from #268*

---

## 277: Improve stitchable functions example in DepthDemoView

+++
status: closed
priority: none
kind: none
created: 2025-10-26T00:00:00Z
closed: 2025-10-26T00:00:00Z
+++

Found in Sources/UltraviolenceExamples/Demos/DepthDemo/DepthDemoView.swift:60

The current implementation is a terrible example of stitchable functions and needs improvement.

*Imported from #269*

---

## 278: Rename Texture2DSpecifier to more descriptive name

+++
status: closed
priority: none
kind: none
created: 2025-10-26T00:00:00Z
closed: 2025-10-26T00:00:00Z
+++

Found in Sources/UltraviolenceExamples/Support/Texture2DSpecifier.swift:5

The Texture2DSpecifier class should be renamed to TextureSpecifier or something more descriptive.

*Imported from #270*

---

## 279: Add proper assertions for Texture2DSpecifier values

+++
status: closed
priority: none
kind: none
created: 2025-10-26T00:00:00Z
closed: 2025-10-26T00:00:00Z
+++

Found in Sources/UltraviolenceExamples/Support/Texture2DSpecifier.swift:20, :28, :36

Need to add proper assertions to verify that values are correct in Texture2DSpecifier methods.

*Imported from #271*

---

## 281: First class visible function support

+++
status: closed
priority: none
kind: feature
labels: effort:m, priority:high
created: 2025-10-26T00:00:00Z
updated: 2026-04-03T04:34:19Z
closed: 2026-04-03T04:34:19Z
+++

We really need to support visible functions. This would unlock/enable a lot of cool "CoreImage-lite" effects where you provide a mini function to (say) convert a color or manipulate a vertex and then the main kernel/shader uses it to manipulate a texture or a mesh.

See https://gist.github.com/schwa/ef6158e8813bc49a14a31ec930b89a0f for how to do it with a simple Compute hello world.

It would be usable from all of these:

#160: Demo: Gamma Correction Pipeline
#154: Demo: Barrel Distortion Post-Processing Effect
#156: Demo: Color Transform Filters
#261: Make a generic distort (vertex) shader that we can provide functions to

*Imported from #273*

- `2026-04-03T04:34:19Z`: Closing as stale/no longer relevant.

---

## 282: Replace deprecated Transforms type with separate matrices

+++
status: closed
priority: none
kind: none
labels: refactor, cleanup
created: 2025-10-29T00:00:00Z
closed: 2025-10-29T00:00:00Z
+++

Replace all uses of the deprecated Transforms struct with separate matrices (projectionMatrix, cameraMatrix, viewMatrix, modelMatrix, modelViewMatrix, modelViewProjectionMatrix). Pass the richest matrix needed to shaders. viewMatrix = cameraMatrix.inverse, modelViewMatrix = viewMatrix * modelMatrix, modelViewProjectionMatrix = projectionMatrix * viewMatrix * modelMatrix

---

## 283: Replace Transforms in BlinnPhongShaders.metal (EXAMPLE)

+++
status: closed
priority: none
kind: none
labels: refactor, shader
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00Z
closed: 2025-10-29T00:00:00Z
+++

Replace Transforms buffer parameter with separate matrices (projectionMatrix, cameraMatrix, modelMatrix). Calculate viewMatrix, modelViewMatrix, and modelViewProjectionMatrix in shader. This is the FIRST example to fix.

- `2026-04-02T22:18:00Z`: Replaced Transforms buffer with separate projectionMatrix, viewMatrix, and modelMatrix buffers in vertex shader. Fragment shader now only receives cameraMatrix. viewMatrix is passed from Swift (cameraMatrix.inverse) instead of being calculated in shader. Matrices calculated: modelViewMatrix = viewMatrix * modelMatrix, modelViewProjectionMatrix = projectionMatrix * viewMatrix * modelMatrix.

---

## 284: Replace Transforms in BlinnPhongDemoView.swift

+++
status: closed
priority: none
kind: none
labels: refactor, swift
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00Z
closed: 2025-10-29T00:00:00Z
+++

Update BlinnPhongDemoView to pass separate matrices instead of Transforms struct. Uses .transforms() modifier at line 62.

- `2026-04-02T22:18:00Z`: Replaced .transforms() modifier with separate .parameter() calls: projectionMatrix (vertex), viewMatrix (vertex), modelMatrix (vertex), and cameraMatrix (fragment). Build succeeds.

---

## 285: Replace Transforms in Panorama.metal

+++
status: closed
priority: none
kind: none
labels: refactor, shader
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00Z
closed: 2025-10-29T00:00:00Z
+++

Replace Transforms buffer parameter with separate matrices in Panorama shader (line 21).

- `2026-04-02T22:18:00Z`: Updated Panorama.metal to use separate matrices (projectionMatrix, viewMatrix, modelMatrix) at buffers 1, 2, 3. Removed Transforms dependency.

---

## 286: Replace Transforms in HitTestShaders.metal

+++
status: closed
priority: none
kind: none
labels: refactor, shader
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00Z
closed: 2025-10-29T00:00:00Z
+++

Replace Transforms buffer parameter with separate matrices in HitTest shader (line 34).

---

## 287: Replace Transforms in DepthShader.metal

+++
status: closed
priority: none
kind: none
labels: refactor, shader
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00Z
closed: 2025-10-29T00:00:00Z
+++

Replace Transforms buffer parameter with separate matrices in Depth shader (line 16).

---

## 288: Replace Transforms in SkyboxShader.metal

+++
status: closed
priority: none
kind: none
labels: refactor, shader
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00Z
closed: 2025-10-29T00:00:00Z
+++

Replace Transforms buffer parameter with separate matrices in Skybox shader (line 16).

- `2026-04-02T22:18:00Z`: Updated SkyboxShader.metal to use separate matrices (projectionMatrix, viewMatrix, modelMatrix) at buffers 1, 2, 3. Removed Transforms dependency.

---

## 289: Replace Transforms in BouncingTeapotsDemoView.swift

+++
status: closed
priority: none
kind: none
labels: refactor, swift
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00Z
closed: 2025-10-29T00:00:00Z
+++

Update BouncingTeapotsDemoView to pass separate matrices instead of Transforms struct (lines 73, 127, 147).

---

## 290: Replace Transforms in TeapotDemo.swift

+++
status: closed
priority: none
kind: none
labels: refactor, swift
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00Z
closed: 2025-10-29T00:00:00Z
+++

Update TeapotDemo to use separate matrices instead of storing Transforms (lines 19, 22, 24, 31).

---

## 291: Replace Transforms in SceneGraphRenderPass.swift

+++
status: closed
priority: none
kind: none
labels: refactor, swift
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00Z
closed: 2025-10-29T00:00:00Z
+++

Update SceneGraphRenderPass to pass separate matrices instead of Transforms (line 75).

- `2026-04-02T22:18:00Z`: Updated SceneGraphRenderPass to use .blinnPhongMatrices() instead of .transforms(). Added viewMatrix calculation at line 59. BlinnPhong shader now fully migrated in SceneGraph.

---

## 292: Replace .transforms() modifier in HitTestDemoView.swift

+++
status: closed
priority: none
kind: none
labels: refactor, swift
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00Z
closed: 2025-10-29T00:00:00Z
+++

Update HitTestDemoView to use new matrix parameters instead of .transforms() modifier.

- `2026-04-02T22:18:00Z`: Fixed BlinnPhong shader usage in HitTestDemoView. Replaced .transforms() with .blinnPhongMatrices() at line 84. Note: HitTestShader (line 99) still uses .transforms() - will be updated when HitTest shader is migrated (issue #286).

---

## 293: Replace .transforms() modifier in TrivialMeshDemoView.swift

+++
status: closed
priority: none
kind: none
labels: refactor, swift
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00Z
closed: 2025-10-29T00:00:00Z
+++

Update TrivialMeshDemoView to use new matrix parameters instead of .transforms() modifier.

- `2026-04-02T22:18:00Z`: Updated TrivialMeshDemoView to use .blinnPhongMatrices() instead of .transforms() at line 312. viewMatrix was already available at line 293.

---

## 294: Replace .transforms() modifier in PanoramaElements.swift

+++
status: closed
priority: none
kind: none
labels: refactor, swift
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00Z
closed: 2025-10-29T00:00:00Z
+++

Update PanoramaElements to use new matrix parameters instead of .transforms() modifier.

- `2026-04-02T22:18:00Z`: Updated PanoramaElements.swift to pass separate matrices using .parameter() calls. Calculates viewMatrix = cameraMatrix.inverse, passes modelMatrix as .identity. Build succeeds.

---

## 295: Replace .transforms() modifier in SkyboxDemoView.swift

+++
status: closed
priority: none
kind: none
labels: refactor, swift
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00Z
closed: 2025-10-29T00:00:00Z
+++

Update SkyboxDemoView to use new matrix parameters instead of .transforms() modifier.

- `2026-04-02T22:18:00Z`: Updated SkyboxDemoView.swift to pass separate matrices using .parameter() calls. Calculates viewMatrix = cameraMatrix.inverse, passes modelMatrix as .identity. Build succeeds.

---

## 296: Remove .transforms() Element extension

+++
status: closed
priority: none
kind: none
labels: refactor, cleanup
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00Z
closed: 2025-10-29T00:00:00Z
+++

Remove the deprecated .transforms() extension from Transforms.swift (lines 26-34) after all usages are replaced.

---

## 297: Remove Transforms struct from Support.h

+++
status: closed
priority: none
kind: none
labels: refactor, cleanup
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00Z
closed: 2025-10-29T00:00:00Z
+++

Remove the Transforms struct definition from Support.h (lines 69-80) after all usages are replaced.

---

## 298: Remove Transforms.swift file

+++
status: closed
priority: none
kind: none
labels: refactor, cleanup
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00Z
closed: 2025-10-29T00:00:00Z
+++

Remove Transforms.swift file entirely after all usages are replaced and the struct is removed from Support.h.

---

## 299: Shaders should try not to do MVP concat in GPU - do in CPU

+++
status: closed
priority: none
kind: task
created: 2025-10-29T00:00:00Z
closed: 2025-10-29T00:00:00Z
+++

---

## 300: Include a default panorama image.

+++
status: closed
priority: medium
kind: enhancement
labels: effort:s
created: 2025-10-29T00:00:00Z
updated: 2026-04-03T02:15:37Z
closed: 2026-04-03T02:15:37Z
+++

- `2026-04-02T22:18:00Z`: Duplicate of #316.

---

## 301: Use 4x3 matrices instead of 4x4

+++
status: closed
priority: none
kind: enhancement
created: 2025-10-29T00:00:00Z
updated: 2026-04-03T04:34:19Z
closed: 2026-04-03T04:34:19Z
+++

Use 4x3 matrixes instead of 4x4 where possible. This incurs some ceremony on both the CPU and GPU

- `2026-04-03T04:34:19Z`: Closing as stale/no longer relevant.

---

## 302: Fix #import vs #include in shader code

+++
status: closed
priority: none
kind: none
created: 2025-10-29T00:00:00Z
closed: 2025-10-29T00:00:00Z
+++

- `2026-04-02T22:18:00Z`: Fixed all shader files in MetalSprocketsAddOnsShaders to use #import instead of #include for consistency with MetalSprocketsExampleShaders. This ensures headers are only included once, preventing potential multiple definition errors.
- `2026-04-02T22:18:00Z`: Standardized all 37 shader files to use #include instead of #import. Both header files (MetalSprocketsAddOnsShaders.h and MetalSprocketsExampleShaders.h) have #pragma once to prevent multiple inclusion issues. Using #include with #pragma once is the consistent approach across the codebase.

---

## 303: Move MetalSprocketsAddOns targets from Examples to AddOns project

+++
status: closed
priority: none
kind: none
created: 2025-10-29T00:00:00Z
closed: 2025-10-29T00:00:00Z
+++

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

- `2025-10-29T00:00:00Z`: AddOns project contains the latest code from Examples
- `2025-10-29T00:00:00Z`: AddOns project builds successfully
- `2025-10-29T00:00:00Z`: Examples project depends on AddOns as an external package
- `2025-10-29T00:00:00Z`: Examples project builds successfully
- `2025-10-29T00:00:00Z`: No duplication of AddOns code between projects
- `2026-04-02T22:18:00Z`: Migration complete. MetalSprocketsAddOns and MetalSprocketsAddOnsShaders targets successfully moved from Examples to AddOns. Both projects build successfully. Hard-coded paths in metal-compiler-plugin.json tracked separately in #304.

---

## 304: Remove hard-coded paths from metal-compiler-plugin.json files

+++
status: closed
priority: none
kind: none
created: 2025-10-29T00:00:00Z
closed: 2025-10-29T00:00:00Z
+++

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

- `2026-04-02T22:18:00Z`: Fixed by removing hard-coded -I flags from metal-compiler-plugin.json files. Now relying on dependency-path-suffix which is portable.

---

## 305: Remove hard-coded path to MetalCompilerPlugin package

+++
status: closed
priority: none
kind: none
created: 2025-10-29T00:00:00Z
closed: 2025-10-29T00:00:00Z
+++

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

- `2026-04-02T22:18:00Z`: Fixed by upgrading to MetalCompilerPlugin 0.1.4 which includes the necessary cross-package shader dependency support. Removed hard-coded local paths in both Examples and AddOns Package.swift files.

---

## 306: Add Demos menu to menu bar for accessibility-driven navigation

+++
status: closed
priority: none
kind: feature
created: 2026-04-02T17:21:43Z
updated: 2026-04-02T17:29:04Z
closed: 2026-04-02T17:29:04Z
+++

Add a 'Demos' menu to the app's menu bar listing all demos by name. This enables reliable automation via 'steveo menu --app ... Demos Triangle' since menus are the most robust accessibility targets. The sidebar list rows are AXUnknown and clicks don't trigger selection.

- `2026-04-02T22:18:00Z`: Added Demos menu to menu bar listing all demos

---

## 307: Add URL scheme for direct demo navigation

+++
status: closed
priority: none
kind: feature
created: 2026-04-02T17:21:49Z
updated: 2026-04-02T17:29:04Z
closed: 2026-04-02T17:29:04Z
+++

Register a URL scheme (e.g. metalsprockets-examples://demo/triangle) so demos can be opened directly from the command line via 'open metalsprockets-examples://demo/triangle'. This enables screenshot automation without any accessibility dependency. The app should handle the URL, navigate to the matching and render it.

- `2026-04-02T22:18:00Z`: Added metalsprockets-examples:// URL scheme for direct demo navigation

---

## 308: Automated screenshot collection script

+++
status: closed
priority: none
kind: task
created: 2026-04-02T17:21:54Z
updated: 2026-04-02T21:45:23Z
closed: 2026-04-02T21:45:23Z
+++

Write a script that cycles through all demos, navigates to each one (via URL scheme or menu), waits for render, and saves a screenshot to Documentation/<DemoName>.png. Depends on #307 (URL scheme) or #306 (Demos menu). Should skip Empty demo and handle demos that need extra settle time (animated demos).

- `2026-04-02T22:18:00Z`: Done — screenshot collection script exists and works.

---

## 309: Unified configuration UI across all demos

+++
status: closed
priority: none
kind: none
created: 2026-04-02T21:40:48Z
updated: 2026-04-02T21:46:10Z
closed: 2026-04-02T21:46:10Z
+++

Many demos have oversized or inconsistent configuration panels (Point Cloud, Video Playback, Particle Effects, Grass Sphere, Spiral Particles, Tiled SDF, etc.). The control panels often dominate the viewport or obscure the rendering. Standardize on a consistent, compact configuration UI pattern — e.g., a collapsible inspector panel or popover — that all demos share.

- `2026-04-02T22:18:00Z`: Duplicate of #24.

---

## 310: Improve default camera angles across demos

+++
status: closed
priority: high
kind: enhancement
created: 2026-04-02T21:40:56Z
updated: 2026-04-03T04:20:49Z
closed: 2026-04-03T04:20:49Z
+++

Many demos have poor default camera angles that don't showcase the rendering well. The teapot sits too high, scenes have too much empty space, or the camera is too far away. Affected demos: Blinn-Phong, Skybox, Debug Shaders, Point Cloud, Wireframe Teapot, Trivial Mesh, Scene Graph, Hit Test, Depth Buffer, Mixed Techniques, Bouncing Teapots, SDF Raymarching, PBR Rendering. Consider standardizing a default camera setup that frames the subject well.

- `2026-04-03T04:20:49Z`: Default camera angles have been improved across demos.

---

## 311: Skybox: remove debug face labels, use more exciting skybox

+++
status: closed
priority: none
kind: bug
labels: low-hanging-fruit, effort:xs
created: 2026-04-02T21:41:10Z
updated: 2026-04-02T22:13:34Z
closed: 2026-04-02T22:13:34Z
+++

The -Z axis label is rendered on the skybox face and should be hidden by default (make it a toggle). Also the skybox texture is a bit dull — consider a more vibrant cubemap.

- `2026-04-02T22:18:00Z`: Face labels now hidden by default with a toolbar toggle.

---

## 312: Compute: needs a proper UI instead of raw debug dump

+++
status: open
priority: low
kind: enhancement
labels: effort:m
created: 2026-04-02T21:41:10Z
updated: 2026-04-03T17:30:51Z
+++

Currently displays 'Optional(Swift.Result<(), Swift.Error>.success())' on a blank white background. Needs a real UI that visually demonstrates the compute operation. Brainstorm ideas for making a compute-only demo visually interesting.

---

## 313: Stencil Buffer: use a more interesting stencil shape and pattern

+++
status: closed
priority: none
kind: enhancement
created: 2026-04-02T21:41:10Z
updated: 2026-04-03T04:47:49Z
closed: 2026-04-03T04:47:49Z
+++

The triangle shape and green checkerboard are functional but dull. Use a more interesting stencil mask shape and a more visually appealing pattern.

- `2026-04-03T04:47:49Z`: Replaced triangle with a 5-pointed star shape.

---

## 314: LUT Color Grading: better default LUT and 50% blend

+++
status: closed
priority: none
kind: enhancement
labels: low-hanging-fruit, effort:xs
created: 2026-04-02T21:41:10Z
updated: 2026-04-02T22:51:55Z
closed: 2026-04-02T22:51:55Z
+++

Default should use a more visually dramatic LUT preset and set the blend slider to ~50% so the effect is clearly visible in screenshots.

- `2026-04-02T22:51:55Z`: Default LUT changed to Sepia Tone at 75% blend. Image now fills window.

---

## 315: Video Playback: bundle a default video

+++
status: closed
priority: medium
kind: enhancement
labels: effort:s
created: 2026-04-02T21:41:22Z
updated: 2026-04-03T04:21:48Z
closed: 2026-04-03T04:21:48Z
+++

The demo shows an empty player with 'No default video found' error. Bundle a short default video so the demo works out of the box. Also reduce the VCR settings panel size (see #309).

- `2026-04-03T04:21:48Z`: Fixed.

---

## 316: 360° Panorama: bundle a default panorama image

+++
status: closed
priority: none
kind: none
created: 2026-04-02T21:41:22Z
updated: 2026-04-02T21:45:29Z
closed: 2026-04-02T21:45:29Z
+++

Shows 'No File' placeholder. Bundle a default equirectangular panorama so the demo works without user interaction.

- `2026-04-02T22:18:00Z`: Duplicate of #300.

---

## 317: GraphicsContext3D: consider deprecating or improving demo scene

+++
status: open
priority: low
kind: enhancement
labels: effort:m, deferred
created: 2026-04-02T21:41:22Z
updated: 2026-08-09T16:23:48Z
+++

Currently shows three flat colored bars which don't showcase 3D path capabilities. Either improve the demo scene to show compelling 3D Path content, or consider deprecating this demo.

---

## 318: MetalCanvas: consider deprecating or expanding with a bigger plan

+++
status: open
priority: low
kind: enhancement
labels: effort:m, deferred
created: 2026-04-02T21:41:22Z
updated: 2026-08-09T16:23:48Z
+++

The random lines demo works but the feature needs a bigger plan. Consider deprecating or developing a proper roadmap for the Canvas API.

---

## 319: Hello Imageblock: fix rotated image

+++
status: closed
priority: medium
kind: bug
labels: needs-info, effort:s
created: 2026-04-02T21:41:34Z
updated: 2026-04-03T02:16:30Z
closed: 2026-04-03T02:16:30Z
+++

The puppy image appears rotated in the imageblock demo. This is a timing issue — the image starts rotating. Needs investigation into why rotation is happening on launch.

---

## 320: Offscreen Rendering: clean up debug info and fix white sidebars

+++
status: closed
priority: none
kind: bug
labels: low-hanging-fruit, effort:xs
created: 2026-04-02T21:41:34Z
updated: 2026-04-02T22:54:32Z
closed: 2026-04-02T22:54:32Z
+++

Raw CGImage description (memory address, color space, pixel format) is displayed over the rendered image. Hide this behind a debug toggle. Also has white sidebars that shouldn't be there.

- `2026-04-02T22:54:32Z`: Replaced raw CGImage debug dump with clean size label. Added black background.

---

## 321: MetalFX Upscaling: more dramatic comparison view

+++
status: open
priority: low
kind: enhancement
labels: effort:s
created: 2026-04-02T21:41:34Z
updated: 2026-04-03T17:30:51Z
+++

The side-by-side layout only shows half the upscaled mandrill. Need a more dramatic comparison that better illustrates the upscaling quality — e.g., a slider wipe or a more zoomed-in detail comparison.

---

## 322: Mixed Techniques: fix rendering and allow animation settle time

+++
status: closed
priority: medium
kind: bug
labels: effort:m
created: 2026-04-02T21:41:35Z
updated: 2026-04-03T04:20:32Z
closed: 2026-04-03T04:20:32Z
+++

Only a barely-visible silhouette outline renders — the lighting, color, and animation appear missing or broken. Also needs a few frames of animation to settle before screenshots look good.

- `2026-04-03T04:20:32Z`: Fixed by adjusting the light position.

---

## 323: Apple Event Logo: remove debug text and fix white sidebars

+++
status: closed
priority: none
kind: bug
labels: low-hanging-fruit, effort:xs
created: 2026-04-02T21:41:46Z
updated: 2026-04-02T22:47:40Z
closed: 2026-04-02T22:47:40Z
+++

Mouse coordinate debug text 'Mouse: (0.00, 0.00)' is visible below the rendered logo. Remove it or hide behind a toggle. Also has white sidebars.

- `2026-04-02T22:47:40Z`: Removed debug mouse text, added black background filling the window.

---

## 324: SDF Raymarching: change background color for better contrast

+++
status: closed
priority: none
kind: enhancement
labels: low-hanging-fruit, effort:xs
created: 2026-04-02T21:41:46Z
updated: 2026-04-02T22:59:10Z
closed: 2026-04-02T22:59:10Z
+++

The flat gray background makes the SDF shapes look muted. Use a darker or more contrasting background color to make the shapes pop.

- `2026-04-02T22:59:10Z`: Changed missed ray color to black, added black clear color, moved toggle to toolbar.

---

## 325: glTF Model Viewer: bundle a default model and fix nil text

+++
status: closed
priority: medium
kind: bug
created: 2026-04-02T21:41:46Z
updated: 2026-04-02T23:35:31Z
closed: 2026-04-02T23:35:31Z
+++

The nil text bug is fixed. Still needs: 1) Bundle a default glTF model (BarramundiFish.glb crashed SwiftGLTF — need to find a compatible model). 2) Fix the file browser dialog — filenames, sizes, and categories are all truncated because columns are too narrow.

- `2026-04-02T23:35:31Z`: Fixed nil text, bundled VirtualCity.glb as default model, fixed file picker two-column layout (NavigationStack), added Reveal in Finder button.

---

## 326: Spiral Particles: increase default particle count

+++
status: closed
priority: none
kind: enhancement
labels: low-hanging-fruit, effort:xs
created: 2026-04-02T21:41:46Z
updated: 2026-04-02T22:48:33Z
closed: 2026-04-02T22:48:33Z
+++

Default of 8 particles looks sparse. Increase the default to show a more impressive spiral effect.

- `2026-04-02T22:48:33Z`: Default particle count increased from 8 to 32.

---

## 327: Voxel Renderer: start at higher resolution with a better default dataset

+++
status: closed
priority: none
kind: enhancement
labels: needs-info, effort:m
created: 2026-04-02T21:41:57Z
updated: 2026-04-03T04:36:53Z
closed: 2026-04-03T04:36:53Z
+++

The default 4×4×4 voxel grid looks like a color test pattern. Start at a higher resolution with a more recognizable 3D shape to demonstrate voxel rendering.

- `2026-04-03T04:36:54Z`: Done.

---

## 328: PBR Rendering: remove broken orientation widget

+++
status: closed
priority: none
kind: bug
labels: low-hanging-fruit, effort:xs
created: 2026-04-02T21:41:57Z
updated: 2026-04-02T23:02:21Z
closed: 2026-04-02T23:02:21Z
+++

The PBR teapot rendering itself looks good (golden metallic with environment reflections), but there's a broken orientation widget displaying '(broken)' in orange text. Remove the widget entirely. The demo should also be moved out of the '* Broken' group.

- `2026-04-02T23:02:21Z`: Removed broken orientation widget, moved PBR from '* Broken' to 'Complex' group.

---

## 329: Color Adjust: better default settings

+++
status: closed
priority: none
kind: enhancement
labels: low-hanging-fruit, effort:xs
created: 2026-04-02T21:41:57Z
updated: 2026-04-02T22:43:42Z
closed: 2026-04-02T22:43:42Z
+++

The default gamma 2.20 with Gamma function selected is functional but not visually dramatic. Consider defaulting to a more visually interesting adjustment function or value.

- `2026-04-02T22:43:42Z`: Default changed to vignette with radius 0.4 for a more dramatic screenshot.

---

## 330: Triangle: needs black background

+++
status: closed
priority: medium
kind: enhancement
created: 2026-04-03T00:48:19Z
updated: 2026-04-03T01:59:07Z
closed: 2026-04-03T01:59:07Z
+++

---

## 331: Stencil Buffer: lost checkerboard pattern, needs black background

+++
status: closed
priority: high
kind: bug
created: 2026-04-03T00:48:24Z
updated: 2026-04-03T04:17:11Z
closed: 2026-04-03T04:17:11Z
+++

- `2026-04-03T04:17:11Z`: Fixed in MetalSprockets #306 — viewModel deferred creation broke BlitPass environment access. Clear color also restored.

---

## 332: Video Playback: port to DemoKit demoConfiguration

+++
status: closed
priority: medium
kind: enhancement
created: 2026-04-03T00:48:28Z
updated: 2026-04-03T00:56:54Z
closed: 2026-04-03T00:56:54Z
+++

- `2026-04-03T00:56:54Z`: Fixed in demoConfiguration and camera angle commits

---

## 333: Trivial Mesh: camera needs to move up a touch and slightly right

+++
status: closed
priority: medium
kind: enhancement
created: 2026-04-03T00:48:32Z
updated: 2026-04-03T00:56:54Z
closed: 2026-04-03T00:56:54Z
+++

- `2026-04-03T00:56:55Z`: Fixed in demoConfiguration and camera angle commits

---

## 334: Scene Graph: use same camera angle as Trivial Mesh

+++
status: closed
priority: medium
kind: enhancement
created: 2026-04-03T00:48:35Z
updated: 2026-04-03T00:56:55Z
closed: 2026-04-03T00:56:55Z
+++

- `2026-04-03T00:56:55Z`: Fixed in demoConfiguration and camera angle commits

---

## 335: Hello Imageblock: port to DemoKit demoConfiguration

+++
status: closed
priority: medium
kind: enhancement
created: 2026-04-03T00:48:38Z
updated: 2026-04-03T00:56:55Z
closed: 2026-04-03T00:56:55Z
+++

- `2026-04-03T00:56:55Z`: Fixed in demoConfiguration and camera angle commits

---

## 336: Bouncing Teapots: sometimes doesn't load at all

+++
status: closed
priority: high
kind: bug
created: 2026-04-03T00:48:51Z
updated: 2026-04-03T04:17:11Z
closed: 2026-04-03T04:17:11Z
+++

- `2026-04-03T04:11:47Z`: Likely same root cause as #363 — MetalSprockets d7f64a82 deferred viewModel creation to .onAppear, so first-frame environment access could fail silently. Fixed in MetalSprockets #306.
- `2026-04-03T04:17:11Z`: Fixed in MetalSprockets #306 — viewModel deferred creation caused first-frame failures.

---

## 337: PBR Rendering: use standard teapot camera [0, 4, 8]

+++
status: closed
priority: medium
kind: enhancement
created: 2026-04-03T00:48:55Z
updated: 2026-04-03T00:56:55Z
closed: 2026-04-03T00:56:55Z
+++

- `2026-04-03T00:56:55Z`: Fixed in demoConfiguration and camera angle commits

---

## 338: SDF Raymarching: use standard teapot camera [0, 4, 8]

+++
status: closed
priority: medium
kind: enhancement
created: 2026-04-03T00:48:59Z
updated: 2026-04-03T00:56:55Z
closed: 2026-04-03T00:56:55Z
+++

- `2026-04-03T00:56:55Z`: Fixed in demoConfiguration and camera angle commits

---

## 339: glTF Viewer: port toolbar controls to DemoKit demoConfiguration

+++
status: closed
priority: medium
kind: enhancement
created: 2026-04-03T00:49:04Z
updated: 2026-04-03T00:56:55Z
closed: 2026-04-03T00:56:55Z
+++

Move the controls from the top of the VStack into demoConfiguration. Slightly more complex case than other demos.

- `2026-04-03T00:56:55Z`: Fixed in demoConfiguration and camera angle commits

---

## 340: Color Adjust: use .fill instead of .fit for aspect ratio

+++
status: closed
priority: medium
kind: bug
created: 2026-04-03T00:49:08Z
updated: 2026-04-03T01:59:07Z
closed: 2026-04-03T01:59:07Z
+++

---

## 341: Update per-demo documentation after demoConfiguration migration

+++
status: open
priority: medium
kind: task
labels: effort:m
created: 2026-04-03T00:57:08Z
updated: 2026-04-03T17:30:51Z
+++

Many demos had their UI controls moved to demoConfiguration and camera angles changed. The per-demo documentation and screenshots need updating to reflect the new layouts.

---

## 342: Hit Test Demo: needs to show what's being hit

+++
status: closed
priority: medium
kind: enhancement
created: 2026-04-03T02:01:48Z
updated: 2026-04-03T04:53:28Z
closed: 2026-04-03T04:53:28Z
+++

- `2026-04-03T04:53:28Z`: Added HUD overlay on the render view showing geometry/instance/triangle ID and depth on hover.

---

## 343: Hit Test Demo: make rendering full screen instead of fixed 512x512

+++
status: closed
priority: medium
kind: enhancement
created: 2026-04-03T02:09:46Z
updated: 2026-04-03T04:57:03Z
closed: 2026-04-03T04:57:03Z
+++

- `2026-04-03T04:57:03Z`: Closed — keeping fixed size for now.

---

## 344: SceneGraph: lighting is regenerated every frame

+++
status: closed
priority: medium
kind: bug
created: 2026-04-03T03:11:53Z
updated: 2026-04-03T04:28:58Z
closed: 2026-04-03T04:28:58Z
+++

- `2026-04-03T04:28:58Z`: Moved lighting computation out of SceneGraphRenderPass.init into a static method, called once at view init.

---

## 345: GLTF: tangents are (x,y,z,w) — needs investigation

+++
status: closed
priority: medium
kind: bug
labels: effort:m
created: 2026-04-03T03:11:53Z
updated: 2026-08-09T16:42:01Z
closed: 2026-08-09T16:42:01Z
+++

- `2026-08-09T16:42:01Z`: Investigated: the (x,y,z,w) handling was already correct where it ran — bitangent = cross(normal, tangent.xyz) * tangent.w matches the glTF spec. The real defect was ordering: bitangents were only derived inside 'if let perVertexNormals', so a primitive supplying TANGENT but no NORMAL got tangents, then had smooth normals generated, and ended up with no bitangents at all (withTangents() is skipped because tangents are already set).

Fixed by extracting GLTFMeshAttributes and deriving bitangents after normal generation.

---

## 346: GLTF: inefficient accessor info getting and discarding

+++
status: open
priority: medium
kind: enhancement
labels: effort:s
created: 2026-04-03T03:11:53Z
updated: 2026-04-03T17:30:51Z
+++

---

## 347: PBR: break out model uniforms from PBRShader

+++
status: open
priority: medium
kind: enhancement
labels: effort:m
created: 2026-04-03T03:11:53Z
updated: 2026-04-03T17:30:51Z
+++

---

## 348: PBR: use scalar instead of color for metallic/roughness/AO

+++
status: open
priority: medium
kind: enhancement
labels: effort:s
created: 2026-04-03T03:11:53Z
updated: 2026-04-03T17:30:51Z
+++

---

## 349: ColorAdjust: document the two VisibleFunction parameters

+++
status: closed
priority: medium
kind: task
created: 2026-04-03T03:11:53Z
updated: 2026-04-03T04:57:59Z
closed: 2026-04-03T04:57:59Z
+++

- `2026-04-03T04:57:59Z`: Added doc comments for mapTextureCoordinateFunction and colorAdjustFunction parameters.

---

## 350: ColorAdjust: consider using .argumentBuffer() instead

+++
status: closed
priority: medium
kind: enhancement
created: 2026-04-03T03:11:53Z
updated: 2026-04-03T04:42:49Z
closed: 2026-04-03T04:42:49Z
+++

- `2026-04-03T04:42:49Z`: Low impact — not worth pursuing.

---

## 351: PointCloud: clean up shader handling

+++
status: closed
priority: medium
kind: enhancement
created: 2026-04-03T03:11:53Z
updated: 2026-04-03T05:01:53Z
closed: 2026-04-03T05:01:53Z
+++

- `2026-04-03T05:01:53Z`: Shader handling is already clean — closing.

---

## 352: MixedExample: clarify if offscreen-only lines are dead code

+++
status: closed
priority: medium
kind: task
created: 2026-04-03T03:11:54Z
updated: 2026-04-03T04:44:03Z
closed: 2026-04-03T04:44:03Z
+++

- `2026-04-03T04:44:03Z`: Removed redundant explicit color/depth attachment setters — only needed for offscreen path.

---

## 353: BlinnPhongShader+Support: expand vertex descriptor handling

+++
status: closed
priority: medium
kind: enhancement
created: 2026-04-03T03:11:54Z
updated: 2026-04-03T04:45:49Z
closed: 2026-04-03T04:45:49Z
+++

- `2026-04-03T04:45:49Z`: Not needed currently — all material textures are already declared.

---

## 354: MetalCanvas: use pipelineState.maxTotalThreadsPerThreadgroup instead of hardcoded value

+++
status: closed
priority: medium
kind: enhancement
created: 2026-04-03T03:11:54Z
updated: 2026-04-03T04:50:19Z
closed: 2026-04-03T04:50:19Z
+++

- `2026-04-03T04:50:19Z`: Duplicate of #355.

---

## 355: Centralize threadsPerThreadgroup computation instead of hardcoding

+++
status: open
priority: medium
kind: enhancement
labels: effort:s
created: 2026-04-03T03:12:53Z
updated: 2026-04-03T17:31:02Z
+++

- `2026-04-03T17:31:02Z`: Related: part of a batch of boilerplate-reduction enhancements (#355-#360)

---

## 356: Extract shader library convenience to eliminate 16x boilerplate

+++
status: open
priority: medium
kind: enhancement
labels: effort:m
created: 2026-04-03T03:15:29Z
updated: 2026-04-03T17:31:02Z
+++

- `2026-04-03T17:31:02Z`: Related: part of a batch of boilerplate-reduction enhancements (#355-#360)

---

## 357: Centralize _MTLCreateSystemDefaultDevice() access (45 ad-hoc calls)

+++
status: open
priority: medium
kind: enhancement
labels: effort:s
created: 2026-04-03T03:15:29Z
updated: 2026-04-03T17:31:03Z
+++

- `2026-04-03T17:31:03Z`: Related: part of a batch of boilerplate-reduction enhancements (#355-#360)

---

## 358: Extract texture creation helper to reduce boilerplate

+++
status: open
priority: medium
kind: enhancement
labels: effort:s
created: 2026-04-03T03:15:29Z
updated: 2026-04-03T17:31:03Z
+++

- `2026-04-03T17:31:03Z`: Related: part of a batch of boilerplate-reduction enhancements (#355-#360)

---

## 359: Consolidate lighting setup patterns across demos

+++
status: open
priority: medium
kind: enhancement
labels: effort:m
created: 2026-04-03T03:15:29Z
updated: 2026-04-03T17:31:03Z
+++

- `2026-04-03T17:31:03Z`: Related: part of a batch of boilerplate-reduction enhancements (#355-#360)

---

## 360: Standardize onDrawableSizeChange texture recreation pattern

+++
status: open
priority: medium
kind: enhancement
labels: effort:s
created: 2026-04-03T03:15:29Z
updated: 2026-04-03T17:31:03Z
+++

- `2026-04-03T17:31:03Z`: Related: part of a batch of boilerplate-reduction enhancements (#355-#360)

---

## 361: Research: convert each demo to its own target (or two targets if including shaders)

+++
status: open
priority: medium
kind: task
labels: effort:l, deferred
created: 2026-04-03T03:15:59Z
updated: 2026-08-09T16:23:48Z
+++

---

## 362: Video keeps playing after navigating away from VideoPlaybackDemoView

+++
status: closed
priority: high
kind: bug
created: 2026-04-03T03:30:56Z
updated: 2026-04-03T04:18:40Z
closed: 2026-04-03T04:18:40Z
+++

The AVPlayer in VideoTexturePipeline continues playing audio/video after the user navigates away from the VideoPlaybackDemoView. The view only has an onAppear to start playback but no onDisappear to stop it, and the VideoTexturePipeline's frame update task keeps running. Need to pause/stop playback when the view disappears.

- `2026-04-03T04:18:40Z`: Added .onDisappear to pause video player when navigating away.

---

## 363: Stencil demo: checkerboard stencil clipping not working

+++
status: closed
priority: high
kind: bug
created: 2026-04-03T03:45:28Z
updated: 2026-04-03T04:07:55Z
closed: 2026-04-03T04:07:55Z
+++

The StencilDemoView renders the triangle without any checkerboard stencil clipping — the triangle appears as a full unclipped triangle. The clear color was also removed in commit xqx and has been restored, but that didn't fix the stencil issue. The stencil pipeline (BlitPass copying checkerboard texture into stencil attachment, then RenderPass with .load and compareFunction .equal) may be broken due to an upstream MetalSprockets change affecting how BlitPass accesses the render pass descriptor's stencil attachment.

- `2026-04-03T03:56:15Z`: Root cause likely in MetalSprockets commit d7f64a82 ('Fix RenderView per-frame allocation churn and resource leak on view removal'). The viewModel was changed from non-optional @State to optional, created in .onAppear. This means .environment(viewModel) passes nil on early evaluations. The BlitPass's EnvironmentReader for \.renderPassDescriptor likely depends on this — when nil, the stencil blit silently doesn't execute, so the stencil buffer stays all zeros and .equal passes everywhere (no clipping). The fix needs to be in MetalSprockets, not here.
- `2026-04-03T04:07:55Z`: Root cause found and fixed in MetalSprockets #306. Commit d7f64a82 deferred viewModel creation to .onAppear, breaking BlitPass environment access. Fix creates viewModel eagerly in init.

---

## 364: the .frame(infinite, infinite).black() is causing black to leak into sidebar

+++
status: closed
priority: medium
kind: bug
labels: effort:s
created: 2026-04-03T05:19:21Z
updated: 2026-08-09T16:29:02Z
closed: 2026-08-09T16:29:02Z
+++

- `2026-08-09T16:29:02Z`: Obsolete: the pattern this issue names no longer exists. `rg 'infinity'` across the sources finds exactly one hit (VideoPlaybackDemoView loopEnd), and there is no `.black()` helper or `.frame(maxWidth: .infinity, maxHeight: .infinity)` on any demo root — the demoConfiguration migration replaced them. Demos now use a plain `.background(.black)` inside DemoKit's detail column, which is itself `ZStack { Color.clear; ... }.clipped()`, so it cannot paint outside the detail column. No code change; closing as no-longer-reproducible. Reopen with a screenshot if black still bleeds into the sidebar — the suspect would then be `.background(.black)` on the demo roots, not the old frame modifier.

---

## 365: Grass shader shading looks wrong - flipped

+++
status: open
priority: medium
kind: bug
labels: effort:m
created: 2026-04-03T05:27:48Z
updated: 2026-08-09T16:43:28Z
+++

- `2026-08-09T16:43:28Z`: Partial fix committed, leaving open for visual confirmation.

Found a definite bug: grassMeshShader emitted the object-space normal straight into VertexOut, and grassFragmentShader lights it against a fixed world-space lightDir. GrassUniforms already carried modelMatrix but nothing used it — dead field. So as the sphere rotated, the lit side rotated with the model instead of staying put, which reads as inverted/backwards shading. Now the normal is transformed by modelMatrix before shading.

Not closing because the issue says 'flipped' with no description and I could not verify on screen. If it still looks wrong, the next suspect is that every blade uses the ground normal rather than its own facing normal (cross(bladeDirection, bladeRight)), so blades are shaded like the sphere surface rather than like blades. Can you eyeball the demo and say which it is?

---

## 366: replace /2 *2 buttons in voxel with a slider

+++
status: open
priority: medium
kind: enhancement
labels: effort:xs
created: 2026-04-03T05:59:54Z
updated: 2026-04-03T17:30:52Z
+++

---

## 367: Accessibility pass: add labels to all interactive controls

+++
status: open
priority: medium
kind: task
labels: accessibility, effort:l
created: 2026-04-03T06:27:01Z
updated: 2026-04-03T17:31:02Z
+++

Sliders, pickers, and popups across demos are missing accessibility labels. SwiftUI doesn't automatically associate adjacent StaticText with controls. Need to add `.accessibilityLabel()` to all interactive controls (sliders, toggles, pickers, buttons) across all demos. This also blocks automated UI testing with steveo since controls can't be found by name.

- `2026-04-03T17:31:02Z`: Related: #368 (Interaction3D accessibility is a subset of this)

---

## 368: Interaction3D: Turntable/WorldView controls missing accessibility labels

+++
status: open
priority: medium
kind: task
labels: accessibility, upstream, effort:m
created: 2026-04-03T06:27:31Z
updated: 2026-08-09T16:23:47Z
+++

The Turntable camera control popup and related WorldView interaction controls from the Interaction3D package have no accessibility labels. Need to add `.accessibilityLabel()` to the camera mode picker and any other interactive elements. This blocks automated UI testing via steveo. Upstream fix needed in Interaction3D project.

- `2026-04-03T17:31:02Z`: Related: #367 (parent accessibility pass covering all controls)
- `2026-08-09T16:23:47Z`: Upstream ticket filed: Interaction3D#15.

---

## 369: Organize all demos into consistent directory structure

+++
status: open
priority: low
kind: task
labels: effort:l
created: 2026-04-04T00:38:02Z
updated: 2026-04-14T16:12:51Z
+++

Reorganize demo files so every demo follows a consistent directory structure with consistent naming.

## Target Structure

For a demo named `Foobar`:

```
MetalSprocketsExamples/Demos/
  Foobar/
    FoobarDemoView.swift
    FoobarDemoRenderPass.swift (or Pipeline, etc.)
MetalSprocketsExampleShaders/Metal/
  FoobarShaders.metal
```

Every demo gets its own subdirectory, even if it only has a single view file.

Standalone support code should either:
- Move into `MetalSprocketsExamplesSupport/`
- Or live in a `FoobarSupport/` directory alongside the demo if it's demo-specific

## Naming Conventions

- View files: `FoobarDemoView.swift`
- Render passes: `FoobarDemoRenderPass.swift`
- Render pipelines: `FoobarDemoRenderPipeline.swift`
- Compute pipelines: `FoobarDemoComputePipeline.swift`
- Shader files: `FoobarShaders.metal`
- Support types: `FoobarSupport/` or `FoobarSomething.swift` with demo prefix

Ensure all files are named consistently — no orphan names that don't match the demo they belong to.

## Demos needing subdirectories (currently loose files):
- `ComputeDemoView.swift` → `ComputeDemo/`
- `GraphicsContext3DDemoView.swift` → `GraphicsContext3DDemo/`
- `MetalCanvasDemoView.swift` → `MetalCanvasDemo/`
- `MetalFXDemoView.swift` → `MetalFXDemo/`
- `OffscreenDemoView.swift` → `OffscreenDemo/`
- `SDFDemoView.swift` → `SDFDemo/`
- `SkyboxDemoView.swift` → `SkyboxDemo/`
- `StencilDemoView.swift` → `StencilDemo/`
- `TriangleDemoView.swift` → `TriangleDemo/`
- `TrivialMeshDemoView.swift` → `TrivialMeshDemo/`
- `WireframeDemoView.swift` → `WireframeDemo/`

## Existing demos to audit for naming consistency:
- `AppleEventLogoDemo/` — e.g. `ColorRemapComputePipeline.swift`, `GradientTextureGenerator.swift`, `HeatParameters.swift`, `ThermalVideoBlendPipeline.swift` need demo prefix or support dir
- `BouncingTeapots/` — `TeapotSimulation.swift` is standalone support
- `GameOfLife/` — `GameOfLife.swift` is standalone support
- `HitTestDemo/` — `HitTestShader.swift` naming
- `LUT/` — `CubeReader.swift`, `LUT-Support.swift` are standalone support
- `MixedDemo/` — `EdgeDetectionKernel.swift`, `TeapotDemo.swift`, `MixedExample.swift`
- `Panorama/` — `PanoramaElements.swift`, `PanoramaMiniMapView.swift`
- `VideoPlaybackDemo/` — `VCRDistortionPipeline.swift`, `VideoTexturePipeline.swift`
- `VoxelDemo/` — `MagicaVoxel.swift` is standalone support

## Also review:
- `LightingModels/` subdemos (BlinnPhongDemo, DebugShaderDemo, GLTFDemo, PBR, SceneGraph)
- `MetalCanvas/` support files
- `ReusableElements/` (shared kernels — may stay as-is)

No functional changes — just file moves and renames.

---

## 370: Ray tracing demo: migrate to MetalSprockets element system

+++
status: open
priority: low
kind: task
labels: effort:l
created: 2026-04-04T01:37:41Z
updated: 2026-04-14T16:12:51Z
+++

The ray tracing demo currently bypasses most of MetalSprockets and manages its own device, command queue, compute pipeline, and textures manually. It should be refactored to use the MetalSprockets element system (ComputePass, ComputePipeline, ComputeDispatch, RenderPass, etc.) like the GameOfLife demo does.

Areas to investigate:
- Use ComputePass/ComputePipeline/ComputeDispatch instead of manual compute encoder setup
- Use the RenderView's device and command queue instead of creating separate ones
- Bind acceleration structures and buffers via the element parameter system
- Manage accumulation/output textures via @MSState instead of a separate RayTracingResources class
- Determine if ComputeDispatch supports setAccelerationStructure or if extensions are needed
- Consider whether MetalSprockets needs new API to support ray tracing workloads (e.g. acceleration structure binding, useResource for primitive AS visibility)

This needs more investigation into what MetalSprockets supports today vs what would need to be added.

---

## 371: Demo: Simple renderer with ray-traced shadows

+++
status: closed
priority: low
kind: feature
labels: effort:l
created: 2026-04-04T02:34:33Z
updated: 2026-04-14T16:15:47Z
closed: 2026-04-14T16:15:47Z
+++

---

## 372: Demo: Simple renderer with ray-traced ambient occlusion

+++
status: open
priority: low
kind: feature
labels: effort:l, needs-info
created: 2026-04-04T02:34:33Z
updated: 2026-08-09T16:23:47Z
+++

- `2026-08-09T16:23:47Z`: needs-info: no description. What should this demo show beyond the existing RT demos — which scene, what AO parameters are exposed, and does it reuse the existing ray tracing pipeline?

---

## 373: Track and display ray/collision counts in RT demos

+++
status: new
priority: low
kind: feature
labels: effort:m, needs-info
created: 2026-04-04T02:40:14Z
updated: 2026-04-14T16:12:52Z
+++

---

## 374: Promote high-quality shaders/pipelines from examples to MetalSprocketsAddOns

+++
status: closed
priority: medium
kind: task
created: 2026-04-13T06:00:53Z
updated: 2026-04-13T15:59:23Z
closed: 2026-04-13T15:59:23Z
+++

Promote the following from MetalSprocketsExamples into MetalSprocketsAddOns:

- `2026-04-13T06:00:53Z`: BlinnPhongShader (+ Lighting support it depends on)
- `2026-04-13T06:00:53Z`: DebugRenderPipeline — switchable debug visualization modes (normals, tangents, UVs, depth, wireframe, etc.)
- `2026-04-13T06:00:53Z`: VideoTexturePipeline — AVFoundation video frame to Metal texture streaming
- `2026-04-13T15:59:23Z`: Promoted BlinnPhongShader, DebugRenderPipeline, VideoTexturePipeline, and Lighting to MetalSprocketsAddOns. Removed local copies from Examples.

---

## 375: Demo views render with wrong size/aspect ratio on initial load

+++
status: open
priority: medium
kind: bug
labels: effort:m, upstream
created: 2026-04-14T02:52:09Z
updated: 2026-08-09T16:23:47Z
+++

RenderView-based demos (Spinning Cube, GraphicsContext3D) render with incorrect aspect ratio or empty content on first load. Requires window resize or navigating away and back to fix. Likely caused by RenderView receiving a stale/zero drawable size before the NavigationSplitView detail column finishes layout. May be a DemoKit or MetalSprockets RenderView issue.

Duplicated from MetalSprocketsAddOns#3.

- `2026-04-14T16:12:57Z`: Related to #376 — both are initial-load rendering failures, likely same root cause in RenderView layout timing.

---

## 376: GraphicsContext3D does not render until window is resized

+++
status: open
priority: high
kind: bug
labels: effort:m, upstream
created: 2026-04-14T02:52:21Z
updated: 2026-08-09T16:28:03Z
+++

GraphicsContext3D content is completely invisible on initial load. Requires a window resize to trigger rendering. Affects both the standalone GraphicsContext3D demo and the BlinnPhong demo light marker. Possibly related to #375 (wrong size/aspect on initial load) but this is a complete rendering failure, not just wrong aspect.

Duplicated from MetalSprocketsAddOns#7.

- `2026-04-14T16:12:57Z`: Related to #375 — both are initial-load rendering failures, likely same root cause in RenderView layout timing.
- `2026-08-09T16:28:04Z`: Investigated: GraphicsContext3DDemoView itself looks correct — it derives aspect/viewport from the closure's drawableSize, and MetalSprockets' RenderViewViewModel.draw() already re-syncs currentDrawableSize defensively before invoking content. The suspect is GraphicsContext3DRenderPipeline (MetalSprocketsAddOns): geometry is only regenerated when 'hasValidViewport && (previousContext != context || previousViewProjection != viewProjection || previousViewport != viewport)'. If the pipeline's @MSState survives across the zero-size frames while previousContext/ViewProjection/Viewport get populated at a degenerate viewport, joinCount/fillVertexCount stay 0 and nothing draws until a resize dirties the comparison.

Punting: can't confirm without running the app and watching the first frames, and the fix would land in MetalSprocketsAddOns, not here. Unblocker: run the demo with MS_RENDERVIEW_LOG_FRAME=1 and report the first few drawableSize values, or confirm you want me to launch the app and inspect it.

---

## 377: Add a skinning-specific debug view to the skinning demo

+++
status: open
priority: medium
kind: feature
labels: effort:m, needs-info
created: 2026-04-14T03:19:43Z
updated: 2026-08-09T16:23:47Z
+++

- `2026-08-09T16:23:47Z`: needs-info: no description. What should the debug view visualize — joint/bone axes, weight heatmap per vertex, bind vs. animated pose overlay, something else?

---

## 378: Skinning demo should NOT embed Metal source code

+++
status: closed
priority: medium
kind: bug
created: 2026-04-14T03:19:50Z
updated: 2026-04-14T16:12:39Z
closed: 2026-04-14T16:12:39Z
+++

- `2026-04-14T16:12:39Z`: Fixed in previous commit — skinning shaders moved to SkinningShaders.metal, loaded via ShaderLibrary.
- `2026-04-14T16:12:39Z`: Fixed in previous commit — skinning shaders moved to SkinningShaders.metal, loaded via ShaderLibrary.
- `2026-04-14T16:12:39Z`: Fixed in previous commit — skinning shaders moved to SkinningShaders.metal, loaded via ShaderLibrary.
- `2026-04-14T16:12:39Z`: Fixed in previous commit — skinning shaders moved to SkinningShaders.metal, loaded via ShaderLibrary.

---

## 379: Audit all code for MetalSprockets best practices

+++
status: open
priority: medium
kind: task
labels: effort:l
created: 2026-04-14T16:11:05Z
updated: 2026-04-14T16:12:52Z
+++

Review all demo code to ensure it follows MetalSprockets best practices: load shaders from ShaderLibrary (not inline source strings), avoid side effects in Element body, use onChange/onWorkloadEnter for lifecycle, use proper resource declaration patterns, etc.

- `2026-04-14T16:13:02Z`: #378 (skinning inline shader strings) was the first item addressed under this audit — now closed.

---

## 380: Consider merging entire project into MetalSprocketsAddOns

+++
status: new
priority: low
kind: task
labels: effort:xl, needs-info, deferred
created: 2026-04-14T16:14:27Z
updated: 2026-08-09T16:23:48Z
+++

---

## 381: Absorb Phosphor project into MetalSprocketsExamples

+++
status: closed
priority: medium
kind: task
created: 2026-04-19T15:54:34Z
updated: 2026-04-19T17:49:44Z
closed: 2026-04-19T17:49:44Z
+++

Phosphor (in Current/Phosphor) contains MetalSprockets demo content (e.g. Plasma.metal) that would fit better as demos within MetalSprocketsExamples. Migrate the relevant shaders and demo code into MetalSprocketsExamples and retire the standalone Phosphor project.

---

## 382: Absorb MetalSprocketsShaderGraph into MetalSprocketsExamples

+++
status: closed
priority: medium
kind: task
created: 2026-04-19T15:56:47Z
updated: 2026-04-19T16:22:21Z
closed: 2026-04-19T16:22:21Z
+++

MetalSprocketsShaderGraph (in Current/MetalSprocketsShaderGraph) provides a Swift DSL that generates Metal code via MTLFunctionStitchingGraph. Migrate its ShaderGraph sources and demo into MetalSprocketsExamples (likely as a dedicated demo) and retire the standalone project.

---

## 383: PhosphorPipeline relies on zero-cleared ping-pong textures on first frame

+++
status: closed
priority: medium
kind: bug
created: 2026-04-20T18:05:31Z
updated: 2026-04-20T19:33:49Z
closed: 2026-04-20T19:33:49Z
+++

`PhosphorUI/PhosphorPipeline.swift` creates two `rgba32Float` textures with `storageMode = .private` via `device.makeTexture(...)` (lines 99-100) and immediately samples one of them as `previousTexture` in the `Phosphor.computeMain` kernel on frame 0. The shader (`PhosphorShaders/Metal/PhosphorCompute.metal`) passes `previousTexture` straight into snippet functions as `backbuffer` with no frame-index guard.

Not all Apple GPUs zero-initialize newly allocated textures. On devices that don't, the first-frame feedback will contain garbage until it's overwritten.

Fix: after creating `textureA`/`textureB` in `setupTexturesIfNeeded`, explicitly clear them — either via a blit `fillBuffer`-style clear, a small compute clear kernel, or a one-shot render pass with `.clear` load action and `.store`. A frame-index guard in the shader is an alternative but requires plumbing the frame counter into uniforms.

- `2026-04-20T19:33:49Z`: Fixed by explicitly zero-filling both ping-pong textures with MTLTexture.fill(with:using:) after creation in setupTexturesIfNeeded. Required pulling MetalSupport main via a package override in Packages/MetalSprocketsExamples/Package.swift.

---

## 384: AppleEventLogoDemo relies on zero-cleared heat textures on first frame

+++
status: closed
priority: medium
kind: bug
created: 2026-04-20T18:05:42Z
updated: 2026-04-20T19:33:49Z
closed: 2026-04-20T19:33:49Z
+++

`MetalSprocketsExamples/Demos/AppleEventLogoDemo/AppleEventLogoDemoView.swift` creates two ping-pong `rgba16Float` heat textures in its `.task { ... }` (lines ~173-177) via `device.makeTexture(descriptor:)` with no explicit initialization. On the first frame, the `heatup` kernel in `AppleEventLogoShaders.metal` reads `previousTexture.read(uint2(sampleCoord))` (line 59) and feeds it back into the next frame, so any uncleared garbage persists and accumulates.

Not all Apple GPUs zero-initialize newly allocated textures, so on affected devices this will show stale/garbage heat on startup.

Fix: after creating the heat textures, explicitly clear both to zero — a blit clear, a trivial "clear" compute kernel dispatch, or a one-shot render pass with `.clear` load action + `.store` store action will all work. A frame-index guard in the shader is an alternative but more invasive.

- `2026-04-20T19:33:49Z`: Fixed by explicitly zero-filling both heat textures with MTLTexture.fill(with:using:) after creation (UInt64(0) since rgba16Float is 8 bytes/pixel).

---
