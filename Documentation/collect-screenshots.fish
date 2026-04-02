#!/usr/bin/env fish

# Collect screenshots for all MetalSprockets examples.
# Prerequisites: steveo installed, app built and launchable via xcb.
# Usage: ./Documentation/collect-screenshots.fish [--settle-time 3] [--output-dir Documentation]

set app_name "MetalSprockets-Examples"
set settle_time 3
set output_dir (status dirname)
set skip_demos "Empty"

# Parse arguments
set i 1
while test $i -le (count $argv)
    switch $argv[$i]
        case --settle-time
            set i (math $i + 1)
            set settle_time $argv[$i]
        case --output-dir
            set i (math $i + 1)
            set output_dir $argv[$i]
        case --help -h
            echo "Usage: collect-screenshots.fish [--settle-time SECS] [--output-dir DIR]"
            exit 0
    end
    set i (math $i + 1)
end

mkdir -p $output_dir

# Demo name -> filename mapping
# Menu names map to PascalCase filenames matching README.md references
set demo_entries \
    "Blinn-Phong Lighting|BlinnPhongLighting" \
    "Skybox|Skybox" \
    "Triangle|Triangle" \
    "Compute|Compute" \
    "Stencil Buffer|StencilBuffer" \
    "LUT Color Grading|LUTColorGrading" \
    "Game of Life|GameOfLife" \
    "Debug Shaders|DebugShaders" \
    "Point Cloud|PointCloud" \
    "Video Playback|VideoPlayback" \
    "360° Panorama|Panorama" \
    "Wireframe Teapot|WireframeTeapot" \
    "Trivial Mesh|TrivialMesh" \
    "Scene Graph|SceneGraph" \
    "GraphicsContext3D|GraphicsContext3D" \
    "MetalCanvas|MetalCanvas" \
    "Hello Imageblock|HelloImageblock" \
    "Offscreen Rendering|OffscreenRendering" \
    "MetalFX Upscaling|MetalFXUpscaling" \
    "Hit Test Demo|HitTestDemo" \
    "Depth Buffer|DepthBuffer" \
    "Mixed Techniques|MixedTechniques" \
    "Bouncing Teapots|BouncingTeapots" \
    "Apple Event Logo|AppleEventLogo" \
    "SDF Raymarching|SDFRaymarching" \
    "Particle Effects|ParticleEffects" \
    "glTF Model Viewer|GLTFModelViewer" \
    "Grass Sphere|GrassSphere" \
    "Spiral Particles|SpiralParticles" \
    "Tiled SDF (2D)|TiledSDF2D" \
    "Voxel Renderer|VoxelRenderer" \
    "PBR Rendering|PBRRendering" \
    "Color Adjust|ColorAdjust"

# Check app is running
if not steveo --app $app_name windows --quiet &>/dev/null
    echo "App not running. Launch it first (e.g. xcb run) and try again."
    exit 1
end

set total (count $demo_entries)
set captured 0
set failed 0

echo "Collecting screenshots for $total demos (settle time: {$settle_time}s)..."
echo ""

for entry in $demo_entries
    set menu_name (string split "|" $entry)[1]
    set filename (string split "|" $entry)[2]
    set outpath "$output_dir/$filename.png"

    printf "[%2d/%2d] %-30s " (math $captured + $failed + 1) $total $menu_name

    # Navigate via menu
    set result (steveo --app $app_name menu "Demos" $menu_name 2>&1)
    if not string match -q '*"ok":true*' $result
        echo "SKIP (menu failed)"
        set failed (math $failed + 1)
        continue
    end

    # Wait for render to settle
    sleep $settle_time

    # Verify window title changed
    set win_title (steveo --app $app_name windows 2>&1 | python3 -c "import sys,json; print(json.load(sys.stdin)['data'][0]['title'])" 2>/dev/null)

    # Take screenshot
    set result (steveo --app $app_name screenshot -o $outpath 2>&1)
    if string match -q '*"ok":true*' $result
        echo "✓ $outpath"
        set captured (math $captured + 1)
    else
        echo "✗ screenshot failed"
        set failed (math $failed + 1)
    end
end

echo ""
echo "Done: $captured captured, $failed failed out of $total demos."
echo "Screenshots saved to: $output_dir/"
