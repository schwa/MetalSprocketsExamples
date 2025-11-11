# Tiled SDF Demo with Imageblocks

This demo demonstrates tile-based rendering for 2D signed distance fields using Metal's explicit imageblock feature for on-chip tile memory.

## Current Implementation

The demo uses a three-pass approach:

1. **Compute Pass**: Culls primitives (circles, lines, Bezier curves) to tiles using bounding boxes
2. **Fragment Pass**: Evaluates SDF at each pixel and writes results to imageblock (tile memory)
3. **Blit Pass**: Reads imageblock and writes to color attachment (framebuffer)

## Architecture

### Imageblock Flow

```
Compute Shader → Tile Culling
    ↓
Fragment Shader → SDF Evaluation → Imageblock (Tile Memory)
    ↓
Blit Shader → Read Imageblock → Color Attachment (Framebuffer)
```

**Key insight**: The imageblock is scoped to the render pass, not individual pipelines. All pipelines within the same render pass share the same tile memory, allowing data to flow between them without touching main memory.

## What We're Missing

### Imageblock Initialization Kernel

Apple's OIT sample includes an initialization step that we currently skip:

```metal
kernel void initTransparentFragmentStore(
    imageblock<TransparentFragmentValues, imageblock_layout_explicit> blockData,
    ushort2 localThreadID[[thread_position_in_threadgroup]]
)
{
    // Initialize imageblock to sentinel values
}
```

Called via:
```objc
[renderEncoder setRenderPipelineState:_initImageBlockPipeline];
[renderEncoder dispatchThreadsPerTile:_optimalTileSize];
```

**Why we're getting away without it:**
- In OIT, not every pixel writes to all layers → uninitialized data shows garbage
- In our SDF demo, every pixel writes a color → no uninitialized data

**Why we should add it anyway:**
- Shows the complete imageblock pattern: init → write → blit
- Demonstrates `dispatchThreadsPerTile` API
- More robust if we later add features with conditional writes
- Educational value for understanding full imageblock workflow

## Potential Next Steps

### 1. Add Imageblock Init Kernel

Add a tile kernel to initialize the imageblock at the start of the render pass:

```metal
kernel void initSDFImageblock(
    imageblock<TransparentFragmentValues, imageblock_layout_explicit> blockData,
    ushort2 localThreadID[[thread_position_in_threadgroup]]
)
{
    threadgroup_imageblock MasterImageblock* imageblock = blockData.data(localThreadID);
    imageblock->color = half4(0.0h, 0.0h, 0.0h, 1.0h); // Default background
}
```

Swift side:
```swift
// In RenderPass, before first pipeline:
try TileRenderPipeline(tileShader: initKernel) {
    DispatchThreadsPerTile(tileSize: MTLSize(width: tileSize, height: tileSize, depth: 1))
}
```

### 2. Explore More Complex Imageblock Uses

Current demo is simple: each pixel writes once, blit reads once. Could explore:

- **Multiple layers**: Store multiple SDF results per pixel (like OIT stores multiple transparent layers)
- **Accumulation**: Multiple draw calls accumulating into imageblock
- **Tile-local computation**: Use imageblock for intermediate results in multi-pass algorithms

### 3. Performance Comparison

Add metrics to compare:
- Imageblock path (current)
- Direct color attachment path (no imageblock)
- Show bandwidth savings

### 4. Visualization Enhancements

- Show which tiles have imageblock data written
- Visualize tile memory usage
- Heat map of per-tile primitive density

## References

- Apple Sample: [Implementing Order-Independent Transparency with Image Blocks](https://developer.apple.com/documentation/metal/implementing-order-independent-transparency-with-image-blocks)
- Sample code: `/Users/schwa/Downloads/ImplementingOrderIndependentTransparencyWithImageBlocks`
- Apple Docs: [Tailor Your Apps for Apple GPUs and Tile-Based Deferred Rendering](https://developer.apple.com/documentation/metal/tailor-your-apps-for-apple-gpus-and-tile-based-deferred-rendering)

## How Tile Memory Transfer Works

The imageblock → framebuffer transfer happens automatically:

```metal
fragment half4 sdfBlitFragment(
    ImageblockIn imageblockIn [[imageblock_data(MasterImageblock)]]
) {
    return imageblockIn.color;  // <-- This return triggers tile memory → framebuffer write
}
```

- Fragment shader reads from imageblock (tile memory) via input parameter
- Return value goes to color attachment (framebuffer)
- GPU handles the tile-based flush automatically when tile is complete
- Still efficient because it's one tile write, not per-fragment writes

## Imageblock Lifetime

```swift
try RenderPass {  // <-- Imageblock allocated here
    try TileRenderPipeline { /* init */ }
    try RenderPipeline { /* write to imageblock */ }
    try RenderPipeline { /* read imageblock, write to color */ }
}  // <-- Imageblock deallocated here
```

The imageblock persists for the entire render pass and is shared by all pipelines within it.
