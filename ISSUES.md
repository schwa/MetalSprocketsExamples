## 1: Hit testing demo
status: closed
priority: none
kind: none
created: 2025-10-22T00:00:00+00:00
updated: 2025-10-23T00:00:00+00:00
closed: 2025-10-23T00:00:00+00:00

Create a demo that demonstrates hit testing capabilities.

Origin: GitHub issue #273

---

## 2: Fix up names of shaders vs demos vs demo views vs elements
status: new
priority: none
kind: enhancement
created: 2025-10-22T00:00:00+00:00
updated: 2026-04-02T21:47:26.965348+00:00

e.g. TextureBillboard vs BillboardShader etc

Need to standardize naming conventions across the examples project.

Origin: GitHub issue #250

---

## 3: Code Reuse Pass
status: new
priority: none
kind: enhancement
created: 2025-10-22T00:00:00+00:00
updated: 2026-04-02T21:47:27.143514+00:00

Go through all demo code and look for code reuse opportunities.

Lots of shaders are doing very similar things now and the demos are bloating a little.

Also look for chances to make these part of Batteries Included.

Origin: GitHub issue #246

---

## 4: [NEW DEMO] MetalPaint
status: open
priority: none
kind: feature
created: 2025-10-22T00:00:00+00:00
updated: 2026-04-02T21:47:41.538893+00:00

It's MacPaint but Metal!

Create a painting/drawing demo using Metal.

Origin: GitHub issue #235

---

## 5: Make more demos runable in offscreen(video)renderer
status: new
priority: none
kind: feature
created: 2025-10-22T00:00:00+00:00
updated: 2026-04-02T21:47:12.072595+00:00

Enable additional demos to work with the offscreen video renderer.

Origin: GitHub issue #215

---

## 6: Move demos back into own repo
status: closed
priority: none
kind: none
created: 2025-10-22T00:00:00+00:00
updated: 2025-10-23T00:00:00+00:00
closed: 2025-10-23T00:00:00+00:00

Separate the demos into their own repository.

Origin: GitHub issue #213

---

## 7: Standalone demo
status: closed
priority: none
kind: feature
created: 2025-10-22T00:00:00+00:00
updated: 2026-04-02T21:57:01.017764+00:00
closed: 2026-04-02T21:57:01.017763+00:00

Create the simplest possible demo that can run independently.

Origin: GitHub issue #212

- 2026-04-02T22:13:34.802931+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Too vague to be actionable.

---

## 8: AxisLines should extend to screen edges instead of fixed world-space length
status: closed
priority: none
kind: none
created: 2025-10-22T00:00:00+00:00
updated: 2025-10-24T00:00:00+00:00
closed: 2025-10-24T00:00:00+00:00

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
kind: enhancement
created: 2025-10-22T00:00:00+00:00
updated: 2026-04-02T21:47:27.280482+00:00

Convert the .metal-sprocketsExampleShaders() method into a property for cleaner API.

Origin: GitHub issue #261

---

## 10: Sanitize vertex descriptors
status: new
priority: none
kind: enhancement
created: 2025-10-22T00:00:00+00:00
updated: 2026-04-02T21:47:27.413747+00:00

Clean up and standardize vertex descriptors across the examples project.

Origin: GitHub issue #259

---

## 11: Link all all issues from metal-sprockets
status: closed
priority: none
kind: none
created: 2025-10-22T00:00:00+00:00
updated: 2025-10-24T00:00:00+00:00
closed: 2025-10-24T00:00:00+00:00

{"id":"uv-eg-20","title":"Make sure all compute examples are using good sizes","description":"Review all compute shader examples to ensure they're using appropriate thread group sizes and dispatch sizes for optimal performance.\n\nOrigin: GitHub issue #252","status":"open","priority":2,"issue_type":"task","created_at":"2025-10-20T19:42:22.465146-07:00","updated_at":"2025-10-21T13:08:41.019653-07:00"}

---

## 23: Implement texture pooling/reuse strategy
status: new
priority: none
kind: feature
created: 2025-10-22T00:00:00+00:00
updated: 2026-04-02T21:47:13.405556+00:00

Currently each demo creates textures on-demand in init/onChange handlers with no reuse strategy. Issues: potential resource leaks in long-running demos, no centralized lifecycle management, repeated allocation/deallocation overhead. Should implement texture pooling for common sizes/formats to improve performance and resource management.

---

## 24: Extract common UI controls into reusable components
status: new
priority: high
kind: enhancement
created: 2025-10-22T00:00:00+00:00
updated: 2026-04-02T22:04:02.587890+00:00

Many demos duplicate similar UI patterns: slider controls for parameters, color pickers, dropdown menus, reset/download buttons. Should create reusable SwiftUI components in Support/ or new UI/ directory: ParameterSlider, DemoColorPicker, DemoOptionPicker, etc. This will reduce code duplication and ensure consistent UI across demos.

---

## 25: Add inline documentation to complex demos
status: new
priority: none
kind: enhancement
created: 2025-10-22T00:00:00+00:00
updated: 2026-04-02T21:47:27.679593+00:00

Complex demos lack sufficient inline documentation: PBR shader calculations, scene graph traversal logic, compute shader algorithms (Game of Life, particle systems), GLTF parsing. Should add: doc comments explaining what each demo demonstrates, inline comments for complex algorithms, references to graphics programming concepts, links to relevant papers/resources. This makes the examples more educational.

---

## 26: Standardize shader management approach
status: new
priority: none
kind: enhancement
created: 2025-10-22T00:00:00+00:00
updated: 2026-04-02T21:47:27.815714+00:00

Currently have inconsistent shader source management: some demos embed Metal shader code as strings (TriangleDemoView), others use external shader bundles via MetalCompilerPlugin, no shader validation at compile time for string-embedded shaders. Should establish standard approach, document when to use each method, prefer external shaders for complex code, add compile-time validation where possible, standardize namespace usage.

---

## 27: Add Metal validation layer checks for development builds
status: new
priority: none
kind: enhancement
created: 2025-10-22T00:00:00+00:00
updated: 2026-04-02T21:47:27.952658+00:00

Should enable Metal API validation and shader validation in development builds to catch: incorrect resource usage, memory leaks, invalid render state, shader compilation warnings, performance issues. Add conditional compilation to enable validation layers in debug builds while keeping release builds optimized.

---

## 28: Add proper assertions for Texture2DSpecifier values
status: closed
priority: none
kind: none
created: 2025-10-22T00:00:00+00:00
updated: 2026-04-02T21:45:22.636033+00:00
closed: 2026-04-02T21:45:22.636033+00:00

Found in Sources/MetalSprocketsExamples/Support/Texture2DSpecifier.swift:20, :28, :36

Need to add proper assertions to verify that values are correct in Texture2DSpecifier methods.

Origin: GitHub issue #287

- 2026-04-02T22:13:34.805075+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Duplicate of #279 which is already closed/done.

---

## 29: Use Mesh instead of MTKMesh more
status: new
priority: none
kind: enhancement
created: 2025-10-22T00:00:00+00:00
updated: 2026-04-02T22:02:52.320466+00:00

Migrate demos that still use MTKMesh to the custom Mesh type where possible.

---

## 30: Make Mesh Codable
status: closed
priority: none
kind: task
created: 2025-10-23T00:00:00+00:00
closed: 2025-10-23T00:00:00+00:00

- 2026-04-02T22:13:34.805509+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Implemented Codable conformance for Mesh and all nested types. MTLBuffer contents are encoded/decoded as Data. Metal enums (MTLPrimitiveType, MTLVertexFormat, MTLVertexStepFunction) use raw UInt values. Codable implementations are in extensions. MTLVertexFormat and MTLVertexStepFunction extensions moved to Support.swift.

---

## 31: Make Network demo use Mesh
status: closed
priority: none
kind: task
created: 2025-10-23T00:00:00+00:00
closed: 2025-10-23T00:00:00+00:00

- 2026-04-02T22:13:34.805731+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Implemented in NetworkListenerDemoView. The demo now converts AR mesh geometries to Mesh objects and renders them using EdgeLinesRenderPass.

---

## 32: Make Edge demo use Mesh
status: closed
priority: none
kind: task
created: 2025-10-23T00:00:00+00:00
closed: 2025-10-23T00:00:00+00:00

- 2026-04-02T22:13:34.805953+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Converted EdgeRenderingDemo (now EdgeLinesDemoView) to use built-in Mesh type instead of MTKMesh. Primitive shapes (plane, cube, sphere) now use TrivialMesh factory methods. Teapot still loads via ModelIO but converts to Mesh. Also moved MeshWithEdges into EdgeLinesRenderPass and renamed EdgeRenderingElement to EdgeLinesRenderPass.

---

## 33: Make Network demo use Edge Renderer
status: closed
priority: none
kind: task
created: 2025-10-23T00:00:00+00:00
closed: 2025-10-23T00:00:00+00:00

- 2026-04-02T22:13:34.806174+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Integrated EdgeLinesRenderPass into Network demo. AR mesh geometries from anchors are now converted to Mesh with edge extraction and rendered using EdgeLinesRenderPass instead of GraphicsContext3D triangle-by-triangle rendering. Meshes rendered in purple with 2.0 line width.

---

## 34: Make the ARKit demo generate Meshes
status: closed
priority: none
kind: task
created: 2025-10-23T00:00:00+00:00
closed: 2025-10-23T00:00:00+00:00


---

## 35: EdgeLinesRenderPass requires 32-byte stride but ARKit meshes only have 12-byte position data
status: closed
priority: none
kind: bug
created: 2025-10-23T00:00:00+00:00
closed: 2025-10-23T00:00:00+00:00

EdgeLinesRenderPass validates 32-byte vertex stride (position+normal+texCoord) but ARKit meshes only have 12-byte position data. Need to either relax validation or pad ARKit vertices.

---

## 36: REname ARKitDemoView to CaptureDemo
status: closed
priority: none
kind: task
created: 2025-10-23T00:00:00+00:00
updated: 2025-10-24T00:00:00+00:00
closed: 2025-10-24T00:00:00+00:00


---

## 37: Make GraphicsContext3D use MetalCanvas.
status: closed
priority: none
kind: feature
created: 2025-10-24T00:00:00+00:00
updated: 2026-04-02T22:02:52.481046+00:00
closed: 2026-04-02T22:02:52.481046+00:00

- 2026-04-02T22:13:34.807022+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Moot — see #317 and #318 for deprecation discussion of GraphicsContext3D and MetalCanvas.

---

## 38: Finish MetalCanvas (fill, depth)
status: closed
priority: none
kind: feature
created: 2025-10-24T00:00:00+00:00
updated: 2026-04-02T22:02:52.658595+00:00
closed: 2026-04-02T22:02:52.658595+00:00

- 2026-04-02T22:13:34.807239+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Moot — see #317 and #318 for deprecation discussion of GraphicsContext3D and MetalCanvas.

---

## 39: Look for code that needs to go into GeometryLite3D
status: closed
priority: none
kind: enhancement
created: 2025-10-24T00:00:00+00:00
updated: 2026-04-02T22:02:52.831976+00:00
closed: 2026-04-02T22:02:52.831976+00:00

- 2026-04-02T22:13:34.807456+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: No longer relevant.

---

## 40: Clean up dead code
status: new
priority: none
kind: enhancement
created: 2025-10-24T00:00:00+00:00
updated: 2026-04-02T21:47:28.372081+00:00


---

## 41: Clean up duplicate code
status: new
priority: none
kind: enhancement
created: 2025-10-24T00:00:00+00:00
updated: 2026-04-02T21:47:28.505909+00:00


---

## 65: Finish World Controller
status: open
priority: none
kind: feature
labels: effort:l
created: 2025-10-26T00:00:00+00:00
updated: 2026-04-02T21:47:13.136068+00:00

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

---

## 72: Make demo app use all examples
status: closed
priority: none
kind: none
labels: effort:m
created: 2025-10-26T00:00:00+00:00
updated: 2026-04-02T21:46:10.343356+00:00
closed: 2026-04-02T21:46:10.343356+00:00

We have DemoView (via DemoKit) and Examples in UltraviolenceExamples/ExampleElements.

*Imported from #64*

- 2026-04-02T22:13:34.808308+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Done — all demos are registered in allDemos.

---

## 74: VisionOS demo
status: open
priority: none
kind: feature
labels: effort:l
created: 2025-10-26T00:00:00+00:00
updated: 2026-04-02T22:02:53.169121+00:00

Add visionOS-specific demos, e.g. immersive mode rendering.

---

## 75: [NEW DEMO] Gooch shader
status: open
priority: none
kind: feature
labels: effort:l
created: 2025-10-26T00:00:00+00:00
updated: 2026-04-02T21:47:41.677004+00:00

*Imported from #67*

---

## 78: [NEW DEMO] Ray Tracing
status: open
priority: none
kind: feature
labels: effort:xl
created: 2025-10-26T00:00:00+00:00
updated: 2026-04-02T21:47:41.813850+00:00

*Imported from #70*

---

## 80: [NEW DEMO] Toon shader
status: open
priority: none
kind: feature
labels: effort:l
created: 2025-10-26T00:00:00+00:00
updated: 2026-04-02T21:47:41.949801+00:00

*Imported from #72*

---

## 114: Handle file extensions properly when loading textures
status: open
priority: none
kind: bug
labels: effort:xs, source:todo
created: 2025-10-26T00:00:00+00:00
updated: 2026-04-02T21:47:03.820404+00:00

Found in Sources/UltraviolenceSupport/MetalSupport.swift at line 790

*Imported from #106*

---

## 120: Add unit tests for TypedMTLBuffer
status: closed
priority: none
kind: enhancement
labels: effort:s, source:todo, testing
created: 2025-10-26T00:00:00+00:00
updated: 2026-04-02T22:02:53.325068+00:00
closed: 2026-04-02T22:02:53.325068+00:00

Found in Demo/Packages/UltraviolenceExamples/Sources/UltraviolenceExamples/Support/TypedMTLBuffer.swift at line 3

*Imported from #112*

- 2026-04-02T22:13:34.809582+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: TypedMTLBuffer no longer exists.

---

## 124: Compute pitch and yaw from camera transform matrix
status: closed
priority: none
kind: enhancement
labels: effort:s, source:todo
created: 2025-10-26T00:00:00+00:00
updated: 2026-04-02T22:02:53.500377+00:00
closed: 2026-04-02T22:02:53.500377+00:00

Found in Demo/Packages/UltraviolenceExamples/Sources/UltraviolenceExamples/Interaction/TurntableCameraController.swift at line 14

*Imported from #116*

- 2026-04-02T22:13:34.809790+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: No longer relevant.

---

## 136: Pre-calculate matrices in LambertianShader instead of computing in shader
status: closed
priority: none
kind: none
labels: effort:s, source:todo
created: 2025-10-26T00:00:00+00:00
updated: 2025-10-29T00:00:00+00:00
closed: 2025-10-29T00:00:00+00:00

Found in Demo/Packages/UltraviolenceExamples/Sources/UltraviolenceExamples/ReuseableElements/LambertianShader.metal at line 32

*Imported from #128*
- Added normalMatrix parameter (float3x3) to both vertex_main and vertex_instanced
- CPU now pre-computes normal matrix (upper-left 3x3 of model matrix)
- For instanced rendering, CPU now pre-computes all MVP matrices and normal matrices per instance
- Removed per-vertex matrix extraction and multiplication from shaders

Performance improvement: Reduces per-vertex computation, especially beneficial for high-poly meshes.

- 2026-04-02T22:13:34.810005+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Pre-calculated matrices on CPU side to avoid per-vertex computation:

---

## 157: [NEW DEMO] GPU Text Rendering Pipeline
status: open
priority: none
kind: enhancement
created: 2025-10-26T00:00:00+00:00
updated: 2026-04-02T21:47:42.086139+00:00

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
status: closed
priority: none
kind: enhancement
created: 2025-10-26T00:00:00+00:00
updated: 2026-04-02T22:02:53.015576+00:00
closed: 2026-04-02T22:02:53.015576+00:00

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

- 2026-04-02T22:13:34.810439+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Duplicate of #74.

---

## 181: [NEW DEMO] Foil Stickers
status: open
priority: none
kind: none
created: 2025-10-26T00:00:00+00:00
updated: 2026-04-02T21:47:42.361166+00:00

Implement https://www.4rknova.com/blog/2025/08/30/foil-sticker

*Imported from #173*

---

## 226: Break out the video code from the OffscreenVideoRecorder
status: open
priority: none
kind: enhancement
created: 2025-10-26T00:00:00+00:00
updated: 2026-04-02T21:47:28.908670+00:00

It's really just as simple as the offscreen renderer but doing extra work every frame.

*Imported from #218*

---

## 227: Add a MetalPaint demo
status: closed
priority: none
kind: feature
created: 2025-10-26T00:00:00+00:00
closed: 2025-10-26T00:00:00+00:00

It's MacPaint but Metal!


*Imported from #219*

---

## 253: Make .ultraviolenceExampleShaders() into property
status: closed
priority: none
kind: none
created: 2025-10-26T00:00:00+00:00
closed: 2025-10-26T00:00:00+00:00

*Imported from #245*

---

## 261: Make a generic distort (vertex) shader that we can provide functions to
status: closed
priority: none
kind: feature
created: 2025-10-26T00:00:00+00:00
closed: 2025-10-26T00:00:00+00:00

*Imported from #253*

---

## 262: Make a gamma texture shader
status: closed
priority: none
kind: none
created: 2025-10-26T00:00:00+00:00
closed: 2025-10-26T00:00:00+00:00

*Imported from #254*

---

## 263: Improve CachingImportWell
status: closed
priority: none
kind: enhancement
created: 2025-10-26T00:00:00+00:00
updated: 2026-04-02T21:57:01.203164+00:00
closed: 2026-04-02T21:57:01.203164+00:00

*Imported from #255*

- 2026-04-02T22:13:34.811926+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: CachingImportWell no longer exists (renamed to SuperImportWell). Reopen with specifics if needed.

---

## 264: Wireframe shader
status: closed
priority: none
kind: none
created: 2025-10-26T00:00:00+00:00
closed: 2025-10-26T00:00:00+00:00

*Imported from #256*

---

## 265: hit testing demo
status: closed
priority: none
kind: none
created: 2025-10-26T00:00:00+00:00
closed: 2025-10-26T00:00:00+00:00

*Imported from #257*

---

## 266: Depth buffer demo is broken
status: closed
priority: none
kind: none
created: 2025-10-26T00:00:00+00:00
closed: 2025-10-26T00:00:00+00:00

*Imported from #258*

---

## 270: Use Ultraviolence's normal shader loading capabilities in ColorAdjustDemoView
status: closed
priority: none
kind: none
created: 2025-10-26T00:00:00+00:00
closed: 2025-10-26T00:00:00+00:00

Found in Sources/UltraviolenceExamples/Demos/ColorAdjustDemo/ColorAdjustDemoView.swift:39

The ColorAdjustDemoView should use Ultraviolence's standard shader loading mechanism instead of custom loading code.

*Imported from #262*

---

## 271: Use proper Metal function loading in ColorAdjustDemoView
status: closed
priority: none
kind: none
created: 2025-10-26T00:00:00+00:00
closed: 2025-10-26T00:00:00+00:00

Found in Sources/UltraviolenceExamples/Demos/ColorAdjustDemo/ColorAdjustDemoView.swift:40

The demo currently requires all functions to be named the same. Should use proper Metal function loading instead.

*Imported from #263*

---

## 272: Better solution for argument buffer in ColorAdjustComputePipeline
status: closed
priority: none
kind: none
created: 2025-10-26T00:00:00+00:00
closed: 2025-10-26T00:00:00+00:00

Found in Sources/UltraviolenceExamples/Demos/ColorAdjustDemo/ColorAdjustComputePipeline.swift:25

Consider using .argumentBuffer() as a better solution for handling parameters.

*Imported from #264*

---

## 273: Move ColorAdjustComputePipeline code to proper location
status: closed
priority: none
kind: none
created: 2025-10-26T00:00:00+00:00
closed: 2025-10-26T00:00:00+00:00

Found in Sources/UltraviolenceExamples/Demos/ColorAdjustDemo/ColorAdjustComputePipeline.swift:37

This code needs to be moved to a more appropriate location in the codebase.

*Imported from #265*

---

## 275: Use Ultraviolence's normal shader loading capabilities in DepthDemoView
status: closed
priority: none
kind: none
created: 2025-10-26T00:00:00+00:00
closed: 2025-10-26T00:00:00+00:00

Found in Sources/UltraviolenceExamples/Demos/DepthDemo/DepthDemoView.swift:58

The DepthDemoView should use Ultraviolence's standard shader loading mechanism instead of custom loading code.

*Imported from #267*

---

## 276: Use proper Metal function loading in DepthDemoView
status: closed
priority: none
kind: none
created: 2025-10-26T00:00:00+00:00
closed: 2025-10-26T00:00:00+00:00

Found in Sources/UltraviolenceExamples/Demos/DepthDemo/DepthDemoView.swift:59

The demo currently requires all functions to be named the same. Should use proper Metal function loading instead.

*Imported from #268*

---

## 277: Improve stitchable functions example in DepthDemoView
status: closed
priority: none
kind: none
created: 2025-10-26T00:00:00+00:00
closed: 2025-10-26T00:00:00+00:00

Found in Sources/UltraviolenceExamples/Demos/DepthDemo/DepthDemoView.swift:60

The current implementation is a terrible example of stitchable functions and needs improvement.

*Imported from #269*

---

## 278: Rename Texture2DSpecifier to more descriptive name
status: closed
priority: none
kind: none
created: 2025-10-26T00:00:00+00:00
closed: 2025-10-26T00:00:00+00:00

Found in Sources/UltraviolenceExamples/Support/Texture2DSpecifier.swift:5

The Texture2DSpecifier class should be renamed to TextureSpecifier or something more descriptive.

*Imported from #270*

---

## 279: Add proper assertions for Texture2DSpecifier values
status: closed
priority: none
kind: none
created: 2025-10-26T00:00:00+00:00
closed: 2025-10-26T00:00:00+00:00

Found in Sources/UltraviolenceExamples/Support/Texture2DSpecifier.swift:20, :28, :36

Need to add proper assertions to verify that values are correct in Texture2DSpecifier methods.

*Imported from #271*

---

## 281: First class visible function support
status: open
priority: none
kind: feature
labels: effort:m, priority:high
created: 2025-10-26T00:00:00+00:00
updated: 2026-04-02T21:47:13.269119+00:00

We really need to support visible functions. This would unlock/enable a lot of cool "CoreImage-lite" effects where you provide a mini function to (say) convert a color or manipulate a vertex and then the main kernel/shader uses it to manipulate a texture or a mesh.

See https://gist.github.com/schwa/ef6158e8813bc49a14a31ec930b89a0f for how to do it with a simple Compute hello world.

It would be usable from all of these:

#160: Demo: Gamma Correction Pipeline
#154: Demo: Barrel Distortion Post-Processing Effect
#156: Demo: Color Transform Filters
#261: Make a generic distort (vertex) shader that we can provide functions to

*Imported from #273*

---

## 282: Replace deprecated Transforms type with separate matrices
status: closed
priority: none
kind: none
labels: refactor, cleanup
created: 2025-10-29T00:00:00+00:00
closed: 2025-10-29T00:00:00+00:00

Replace all uses of the deprecated Transforms struct with separate matrices (projectionMatrix, cameraMatrix, viewMatrix, modelMatrix, modelViewMatrix, modelViewProjectionMatrix). Pass the richest matrix needed to shaders. viewMatrix = cameraMatrix.inverse, modelViewMatrix = viewMatrix * modelMatrix, modelViewProjectionMatrix = projectionMatrix * viewMatrix * modelMatrix

---

## 283: Replace Transforms in BlinnPhongShaders.metal (EXAMPLE)
status: closed
priority: none
kind: none
labels: refactor, shader
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00+00:00
closed: 2025-10-29T00:00:00+00:00

Replace Transforms buffer parameter with separate matrices (projectionMatrix, cameraMatrix, modelMatrix). Calculate viewMatrix, modelViewMatrix, and modelViewProjectionMatrix in shader. This is the FIRST example to fix.

- 2026-04-02T22:13:34.815076+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Replaced Transforms buffer with separate projectionMatrix, viewMatrix, and modelMatrix buffers in vertex shader. Fragment shader now only receives cameraMatrix. viewMatrix is passed from Swift (cameraMatrix.inverse) instead of being calculated in shader. Matrices calculated: modelViewMatrix = viewMatrix * modelMatrix, modelViewProjectionMatrix = projectionMatrix * viewMatrix * modelMatrix.

---

## 284: Replace Transforms in BlinnPhongDemoView.swift
status: closed
priority: none
kind: none
labels: refactor, swift
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00+00:00
closed: 2025-10-29T00:00:00+00:00

Update BlinnPhongDemoView to pass separate matrices instead of Transforms struct. Uses .transforms() modifier at line 62.

- 2026-04-02T22:13:34.815294+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Replaced .transforms() modifier with separate .parameter() calls: projectionMatrix (vertex), viewMatrix (vertex), modelMatrix (vertex), and cameraMatrix (fragment). Build succeeds.

---

## 285: Replace Transforms in Panorama.metal
status: closed
priority: none
kind: none
labels: refactor, shader
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00+00:00
closed: 2025-10-29T00:00:00+00:00

Replace Transforms buffer parameter with separate matrices in Panorama shader (line 21).

- 2026-04-02T22:13:34.815506+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Updated Panorama.metal to use separate matrices (projectionMatrix, viewMatrix, modelMatrix) at buffers 1, 2, 3. Removed Transforms dependency.

---

## 286: Replace Transforms in HitTestShaders.metal
status: closed
priority: none
kind: none
labels: refactor, shader
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00+00:00
closed: 2025-10-29T00:00:00+00:00

Replace Transforms buffer parameter with separate matrices in HitTest shader (line 34).

---

## 287: Replace Transforms in DepthShader.metal
status: closed
priority: none
kind: none
labels: refactor, shader
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00+00:00
closed: 2025-10-29T00:00:00+00:00

Replace Transforms buffer parameter with separate matrices in Depth shader (line 16).

---

## 288: Replace Transforms in SkyboxShader.metal
status: closed
priority: none
kind: none
labels: refactor, shader
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00+00:00
closed: 2025-10-29T00:00:00+00:00

Replace Transforms buffer parameter with separate matrices in Skybox shader (line 16).

- 2026-04-02T22:13:34.816138+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Updated SkyboxShader.metal to use separate matrices (projectionMatrix, viewMatrix, modelMatrix) at buffers 1, 2, 3. Removed Transforms dependency.

---

## 289: Replace Transforms in BouncingTeapotsDemoView.swift
status: closed
priority: none
kind: none
labels: refactor, swift
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00+00:00
closed: 2025-10-29T00:00:00+00:00

Update BouncingTeapotsDemoView to pass separate matrices instead of Transforms struct (lines 73, 127, 147).

---

## 290: Replace Transforms in TeapotDemo.swift
status: closed
priority: none
kind: none
labels: refactor, swift
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00+00:00
closed: 2025-10-29T00:00:00+00:00

Update TeapotDemo to use separate matrices instead of storing Transforms (lines 19, 22, 24, 31).

---

## 291: Replace Transforms in SceneGraphRenderPass.swift
status: closed
priority: none
kind: none
labels: refactor, swift
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00+00:00
closed: 2025-10-29T00:00:00+00:00

Update SceneGraphRenderPass to pass separate matrices instead of Transforms (line 75).

- 2026-04-02T22:13:34.816782+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Updated SceneGraphRenderPass to use .blinnPhongMatrices() instead of .transforms(). Added viewMatrix calculation at line 59. BlinnPhong shader now fully migrated in SceneGraph.

---

## 292: Replace .transforms() modifier in HitTestDemoView.swift
status: closed
priority: none
kind: none
labels: refactor, swift
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00+00:00
closed: 2025-10-29T00:00:00+00:00

Update HitTestDemoView to use new matrix parameters instead of .transforms() modifier.

- 2026-04-02T22:13:34.817001+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Fixed BlinnPhong shader usage in HitTestDemoView. Replaced .transforms() with .blinnPhongMatrices() at line 84. Note: HitTestShader (line 99) still uses .transforms() - will be updated when HitTest shader is migrated (issue #286).

---

## 293: Replace .transforms() modifier in TrivialMeshDemoView.swift
status: closed
priority: none
kind: none
labels: refactor, swift
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00+00:00
closed: 2025-10-29T00:00:00+00:00

Update TrivialMeshDemoView to use new matrix parameters instead of .transforms() modifier.

- 2026-04-02T22:13:34.817221+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Updated TrivialMeshDemoView to use .blinnPhongMatrices() instead of .transforms() at line 312. viewMatrix was already available at line 293.

---

## 294: Replace .transforms() modifier in PanoramaElements.swift
status: closed
priority: none
kind: none
labels: refactor, swift
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00+00:00
closed: 2025-10-29T00:00:00+00:00

Update PanoramaElements to use new matrix parameters instead of .transforms() modifier.

- 2026-04-02T22:13:34.817442+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Updated PanoramaElements.swift to pass separate matrices using .parameter() calls. Calculates viewMatrix = cameraMatrix.inverse, passes modelMatrix as .identity. Build succeeds.

---

## 295: Replace .transforms() modifier in SkyboxDemoView.swift
status: closed
priority: none
kind: none
labels: refactor, swift
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00+00:00
closed: 2025-10-29T00:00:00+00:00

Update SkyboxDemoView to use new matrix parameters instead of .transforms() modifier.

- 2026-04-02T22:13:34.817662+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Updated SkyboxDemoView.swift to pass separate matrices using .parameter() calls. Calculates viewMatrix = cameraMatrix.inverse, passes modelMatrix as .identity. Build succeeds.

---

## 296: Remove .transforms() Element extension
status: closed
priority: none
kind: none
labels: refactor, cleanup
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00+00:00
closed: 2025-10-29T00:00:00+00:00

Remove the deprecated .transforms() extension from Transforms.swift (lines 26-34) after all usages are replaced.

---

## 297: Remove Transforms struct from Support.h
status: closed
priority: none
kind: none
labels: refactor, cleanup
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00+00:00
closed: 2025-10-29T00:00:00+00:00

Remove the Transforms struct definition from Support.h (lines 69-80) after all usages are replaced.

---

## 298: Remove Transforms.swift file
status: closed
priority: none
kind: none
labels: refactor, cleanup
depends: MetalSprocketsExamples#282
created: 2025-10-29T00:00:00+00:00
closed: 2025-10-29T00:00:00+00:00

Remove Transforms.swift file entirely after all usages are replaced and the struct is removed from Support.h.

---

## 299: Shaders should try not to do MVP concat in GPU - do in CPU
status: closed
priority: none
kind: task
created: 2025-10-29T00:00:00+00:00
closed: 2025-10-29T00:00:00+00:00


---

## 300: Include a default panorama image.
status: open
priority: medium
kind: enhancement
labels: effort:s
created: 2025-10-29T00:00:00+00:00
updated: 2026-04-02T22:05:53.902826+00:00

- 2026-04-02T22:13:34.818702+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Duplicate of #316.

---

## 301: Use 4x3 matrices instead of 4x4
status: new
priority: none
kind: enhancement
created: 2025-10-29T00:00:00+00:00
updated: 2026-04-02T21:47:29.308559+00:00

Use 4x3 matrixes instead of 4x4 where possible. This incurs some ceremony on both the CPU and GPU

---

## 302: Fix #import vs #include in shader code
status: closed
priority: none
kind: none
created: 2025-10-29T00:00:00+00:00
closed: 2025-10-29T00:00:00+00:00

- 2026-04-02T22:13:34.819135+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Fixed all shader files in MetalSprocketsAddOnsShaders to use #import instead of #include for consistency with MetalSprocketsExampleShaders. This ensures headers are only included once, preventing potential multiple definition errors.
- 2026-04-02T22:13:34.819142+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Standardized all 37 shader files to use #include instead of #import. Both header files (MetalSprocketsAddOnsShaders.h and MetalSprocketsExampleShaders.h) have #pragma once to prevent multiple inclusion issues. Using #include with #pragma once is the consistent approach across the codebase.

---

## 303: Move MetalSprocketsAddOns targets from Examples to AddOns project
status: closed
priority: none
kind: none
created: 2025-10-29T00:00:00+00:00
closed: 2025-10-29T00:00:00+00:00

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

- 2026-04-02T22:13:34.819367+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Migration complete. MetalSprocketsAddOns and MetalSprocketsAddOnsShaders targets successfully moved from Examples to AddOns. Both projects build successfully. Hard-coded paths in metal-compiler-plugin.json tracked separately in #304.

---

## 304: Remove hard-coded paths from metal-compiler-plugin.json files
status: closed
priority: none
kind: none
created: 2025-10-29T00:00:00+00:00
closed: 2025-10-29T00:00:00+00:00

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

- 2026-04-02T22:13:34.819588+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Fixed by removing hard-coded -I flags from metal-compiler-plugin.json files. Now relying on dependency-path-suffix which is portable.

---

## 305: Remove hard-coded path to MetalCompilerPlugin package
status: closed
priority: none
kind: none
created: 2025-10-29T00:00:00+00:00
closed: 2025-10-29T00:00:00+00:00

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

- 2026-04-02T22:13:34.819810+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Fixed by upgrading to MetalCompilerPlugin 0.1.4 which includes the necessary cross-package shader dependency support. Removed hard-coded local paths in both Examples and AddOns Package.swift files.

---

## 306: Add Demos menu to menu bar for accessibility-driven navigation
status: closed
priority: none
kind: feature
created: 2026-04-02T17:21:43.828932+00:00
updated: 2026-04-02T17:29:04.638879+00:00
closed: 2026-04-02T17:29:04.638879+00:00

Add a 'Demos' menu to the app's menu bar listing all demos by name. This enables reliable automation via 'steveo menu --app ... Demos Triangle' since menus are the most robust accessibility targets. The sidebar list rows are AXUnknown and clicks don't trigger selection.

- 2026-04-02T22:13:34.820020+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Added Demos menu to menu bar listing all demos

---

## 307: Add URL scheme for direct demo navigation
status: closed
priority: none
kind: feature
created: 2026-04-02T17:21:49.207464+00:00
updated: 2026-04-02T17:29:04.809008+00:00
closed: 2026-04-02T17:29:04.809008+00:00

Register a URL scheme (e.g. metalsprockets-examples://demo/triangle) so demos can be opened directly from the command line via 'open metalsprockets-examples://demo/triangle'. This enables screenshot automation without any accessibility dependency. The app should handle the URL, navigate to the matching and render it.

- 2026-04-02T22:13:34.820231+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Added metalsprockets-examples:// URL scheme for direct demo navigation

---

## 308: Automated screenshot collection script
status: closed
priority: none
kind: task
created: 2026-04-02T17:21:54.678188+00:00
updated: 2026-04-02T21:45:23.020140+00:00
closed: 2026-04-02T21:45:23.020140+00:00

Write a script that cycles through all demos, navigates to each one (via URL scheme or menu), waits for render, and saves a screenshot to Documentation/<DemoName>.png. Depends on #307 (URL scheme) or #306 (Demos menu). Should skip Empty demo and handle demos that need extra settle time (animated demos).

- 2026-04-02T22:13:34.820441+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Done — screenshot collection script exists and works.

---

## 309: Unified configuration UI across all demos
status: closed
priority: none
kind: none
created: 2026-04-02T21:40:48.453894+00:00
updated: 2026-04-02T21:46:10.524663+00:00
closed: 2026-04-02T21:46:10.524663+00:00

Many demos have oversized or inconsistent configuration panels (Point Cloud, Video Playback, Particle Effects, Grass Sphere, Spiral Particles, Tiled SDF, etc.). The control panels often dominate the viewport or obscure the rendering. Standardize on a consistent, compact configuration UI pattern — e.g., a collapsible inspector panel or popover — that all demos share.

- 2026-04-02T22:13:34.820651+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Duplicate of #24.

---

## 310: Improve default camera angles across demos
status: new
priority: high
kind: enhancement
created: 2026-04-02T21:40:56.405502+00:00
updated: 2026-04-02T22:04:02.725631+00:00

Many demos have poor default camera angles that don't showcase the rendering well. The teapot sits too high, scenes have too much empty space, or the camera is too far away. Affected demos: Blinn-Phong, Skybox, Debug Shaders, Point Cloud, Wireframe Teapot, Trivial Mesh, Scene Graph, Hit Test, Depth Buffer, Mixed Techniques, Bouncing Teapots, SDF Raymarching, PBR Rendering. Consider standardizing a default camera setup that frames the subject well.

---

## 311: Skybox: remove debug face labels, use more exciting skybox
status: closed
priority: none
kind: bug
labels: low-hanging-fruit, effort:xs
created: 2026-04-02T21:41:10.047928+00:00
updated: 2026-04-02T22:13:34.775587+00:00
closed: 2026-04-02T22:13:34.775587+00:00

The -Z axis label is rendered on the skybox face and should be hidden by default (make it a toggle). Also the skybox texture is a bit dull — consider a more vibrant cubemap.

- 2026-04-02T22:13:34.824823+00:00: Face labels now hidden by default with a toolbar toggle.

---

## 312: Compute: needs a proper UI instead of raw debug dump
status: new
priority: none
kind: enhancement
created: 2026-04-02T21:41:10.197698+00:00
updated: 2026-04-02T21:52:34.640887+00:00

Currently displays 'Optional(Swift.Result<(), Swift.Error>.success())' on a blank white background. Needs a real UI that visually demonstrates the compute operation. Brainstorm ideas for making a compute-only demo visually interesting.

---

## 313: Stencil Buffer: use a more interesting stencil shape and pattern
status: new
priority: none
kind: enhancement
created: 2026-04-02T21:41:10.342366+00:00
updated: 2026-04-02T21:47:29.576+00:00

The triangle shape and green checkerboard are functional but dull. Use a more interesting stencil mask shape and a more visually appealing pattern.

---

## 314: LUT Color Grading: better default LUT and 50% blend
status: new
priority: none
kind: enhancement
labels: low-hanging-fruit, effort:xs
created: 2026-04-02T21:41:10.486483+00:00
updated: 2026-04-02T22:04:52.219512+00:00

Default should use a more visually dramatic LUT preset and set the blend slider to ~50% so the effect is clearly visible in screenshots.

---

## 315: Video Playback: bundle a default video
status: new
priority: medium
kind: enhancement
labels: effort:s
created: 2026-04-02T21:41:22.070028+00:00
updated: 2026-04-02T22:05:53.770904+00:00

The demo shows an empty player with 'No default video found' error. Bundle a short default video so the demo works out of the box. Also reduce the VCR settings panel size (see #309).

---

## 316: 360° Panorama: bundle a default panorama image
status: closed
priority: none
kind: none
created: 2026-04-02T21:41:22.221320+00:00
updated: 2026-04-02T21:45:29.651786+00:00
closed: 2026-04-02T21:45:29.651786+00:00

Shows 'No File' placeholder. Bundle a default equirectangular panorama so the demo works without user interaction.

- 2026-04-02T22:13:34.822097+00:00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: 00: Duplicate of #300.

---

## 317: GraphicsContext3D: consider deprecating or improving demo scene
status: new
priority: none
kind: enhancement
created: 2026-04-02T21:41:22.369174+00:00
updated: 2026-04-02T21:47:29.977975+00:00

Currently shows three flat colored bars which don't showcase 3D path capabilities. Either improve the demo scene to show compelling 3D Path content, or consider deprecating this demo.

---

## 318: MetalCanvas: consider deprecating or expanding with a bigger plan
status: new
priority: none
kind: enhancement
created: 2026-04-02T21:41:22.516616+00:00
updated: 2026-04-02T21:47:30.112646+00:00

The random lines demo works but the feature needs a bigger plan. Consider deprecating or developing a proper roadmap for the Canvas API.

---

## 319: Hello Imageblock: fix rotated image
status: new
priority: medium
kind: bug
labels: effort:xs
created: 2026-04-02T21:41:34.688774+00:00
updated: 2026-04-02T22:05:54.034400+00:00

The puppy test image appears rotated in the imageblock demo. Investigate and fix the image orientation.

---

## 320: Offscreen Rendering: clean up debug info and fix white sidebars
status: new
priority: none
kind: bug
labels: low-hanging-fruit, effort:xs
created: 2026-04-02T21:41:34.839345+00:00
updated: 2026-04-02T22:04:51.820003+00:00

Raw CGImage description (memory address, color space, pixel format) is displayed over the rendered image. Hide this behind a debug toggle. Also has white sidebars that shouldn't be there.

---

## 321: MetalFX Upscaling: more dramatic comparison view
status: new
priority: none
kind: enhancement
created: 2026-04-02T21:41:34.983689+00:00
updated: 2026-04-02T21:47:30.246122+00:00

The side-by-side layout only shows half the upscaled mandrill. Need a more dramatic comparison that better illustrates the upscaling quality — e.g., a slider wipe or a more zoomed-in detail comparison.

---

## 322: Mixed Techniques: fix rendering and allow animation settle time
status: new
priority: medium
kind: bug
labels: effort:m
created: 2026-04-02T21:41:35.130329+00:00
updated: 2026-04-02T22:05:53.589940+00:00

Only a barely-visible silhouette outline renders — the lighting, color, and animation appear missing or broken. Also needs a few frames of animation to settle before screenshots look good.

---

## 323: Apple Event Logo: remove debug text and fix white sidebars
status: new
priority: none
kind: bug
labels: low-hanging-fruit, effort:xs
created: 2026-04-02T21:41:46.009758+00:00
updated: 2026-04-02T22:04:51.547127+00:00

Mouse coordinate debug text 'Mouse: (0.00, 0.00)' is visible below the rendered logo. Remove it or hide behind a toggle. Also has white sidebars.

---

## 324: SDF Raymarching: change background color for better contrast
status: new
priority: none
kind: enhancement
labels: low-hanging-fruit, effort:xs
created: 2026-04-02T21:41:46.166881+00:00
updated: 2026-04-02T22:04:52.611026+00:00

The flat gray background makes the SDF shapes look muted. Use a darker or more contrasting background color to make the shapes pop.

---

## 325: glTF Model Viewer: bundle a default model and fix nil text
status: new
priority: medium
kind: bug
created: 2026-04-02T21:41:46.317090+00:00
updated: 2026-04-02T22:04:02.858527+00:00

Shows empty state with 'Download & Unzip' and 'Import' buttons plus a 'nil' text bug. Bundle a default glTF model so the demo renders something on launch. Fix the nil text display.

---

## 326: Spiral Particles: increase default particle count
status: new
priority: none
kind: enhancement
labels: low-hanging-fruit, effort:xs
created: 2026-04-02T21:41:46.468035+00:00
updated: 2026-04-02T22:04:51.951083+00:00

Default of 8 particles looks sparse. Increase the default to show a more impressive spiral effect.

---

## 327: Voxel Renderer: start at higher resolution with a better default dataset
status: new
priority: none
kind: enhancement
labels: low-hanging-fruit, effort:xs
created: 2026-04-02T21:41:57.338229+00:00
updated: 2026-04-02T22:04:52.084686+00:00

The default 4×4×4 voxel grid looks like a color test pattern. Start at a higher resolution with a more recognizable 3D shape to demonstrate voxel rendering.

---

## 328: PBR Rendering: remove broken orientation widget
status: new
priority: none
kind: bug
labels: low-hanging-fruit, effort:xs
created: 2026-04-02T21:41:57.496227+00:00
updated: 2026-04-02T22:04:52.480376+00:00

The PBR teapot rendering itself looks good (golden metallic with environment reflections), but there's a broken orientation widget displaying '(broken)' in orange text. Remove the widget entirely. The demo should also be moved out of the '* Broken' group.

---

## 329: Color Adjust: better default settings
status: new
priority: none
kind: enhancement
labels: low-hanging-fruit, effort:xs
created: 2026-04-02T21:41:57.648542+00:00
updated: 2026-04-02T22:04:52.350315+00:00

The default gamma 2.20 with Gamma function selected is functional but not visually dramatic. Consider defaulting to a more visually interesting adjustment function or value.

---

