# Video Recording Plan

## Goal

Automatically record a demo video showcasing all MetalSprocketsExamples demos using `steveo` for UI automation and `screenrecording-tool` for per-window video capture.

## Tooling

### steveo (UI automation)

- **Demos menu** — Navigation via `steveo --app "MetalSprockets-Examples" menu "Demos" "Triangle"` works reliably.
- **Screenshot collection** — Fully automated via `steveo screenshot`. All 34 demos captured at 1024×768.
- **Sidebar toggle** — `steveo find --text "Hide Sidebar" --click`.
- **Description toggle** — Hide/show description banner via the (i) button.
- **Window resize** — `steveo window resize` works.
- **Drag/rotate** — `steveo focus` then `steveo drag x1 y1 x2 y2 --duration ms` rotates 3D views. Must `steveo focus` before drag.
- **Bezier drag** — `steveo drag-path` for smooth curved camera movements.
- **Key combos** — `steveo key` supports named keys and modifiers. Bracket keys (`]`, `[`) not in the named key list but `--raw <keycode>` can send any keycode.

### screenrecording-tool (video capture)

- **Per-window recording** — `screenrecording-tool record --window "Title" -d 10 clip.mov` captures a single window.
- **Per-app recording** — `screenrecording-tool record --app "AppName"` captures all windows of an app.
- **Output profiles** — `--profile social` (small), `edit` (high quality), `raw` (maximum), `lossless`.
- **Click highlights** — `--click-highlight` overlays visual feedback on clicks in the video.
- **Cursor control** — `--no-show-cursor` to hide cursor, `--cursor-image` for custom cursor.
- **Event logging** — `--event-log events.jsonl` records mouse + keyboard events alongside video.
- **System audio** — `--audio` captures system audio if needed.
- **Padding** — `--padding N` adds pixels around the capture area.

### Other tooling

- **demos.yaml** — Canonical index of all demos with metadata, interest levels, and choreography hints.
- **generate-docs.py** — Single script for both screenshot capture and DEMOS.md generation from demos.yaml.

## Remaining Bugs / Blockers

### DemoKit

- **#DemoKit#11** — URL scheme navigation launches new app instances instead of routing to the running one. Not a blocker — menu navigation works.
- **#DemoKit#12** — `kebabCase` produces double hyphens (e.g., `game-of--life`). Minor.

### steveo

- **#steveo#11** — Named key list doesn't include bracket characters. Workaround: `steveo key --raw 30` for `]`, `--raw 33` for `[`. May be fixed; needs verification.

### MetalSprocketsExamples

- **#MSE#367** — Accessibility pass needed: sliders, pickers, popups missing `.accessibilityLabel()`. Blocks driving controls by name via steveo.
- **#MSE#368** — Interaction3D Turntable controls missing AX labels (upstream fix).

## Navigation for Video

| Method | Works? | Video-safe? | Notes |
|--------|--------|-------------|-------|
| Demos menu | ✅ | ✅ | Per-clip recording means menu flash is between clips |
| URL scheme | ⚠️ | ✅ | Launches new app instances (#DemoKit#11) |
| Cmd+]/[ via steveo --raw | ✅ | ✅ | Needs verification |
| Sidebar click | ✅ | ❌ | Sidebar visible in frame |

**Current approach:** Use Demos menu to navigate between demos. Each demo gets its own recording via `screenrecording-tool record --window`, so menu flash happens outside the capture window.

## Video Choreography

Per-demo recording approach:

1. Launch app, resize to 1024×768, hide sidebar
2. For each demo (ordered by `demos.yaml`):
   a. Navigate via Demos menu
   b. Wait for settle time
   c. Focus app (`steveo focus`)
   d. Start recording: `screenrecording-tool record --window "Title" --profile edit -d N clip.mov &`
   e. Perform gestures (drag/drag-path to rotate) per choreography in yaml
   f. Adjust UI controls per yaml (once AX labels are added)
   g. Wait for recording to finish
3. Concatenate clips in post (ffmpeg)

## Files

- `Documentation/demos.yaml` — Canonical demo index with video choreography fields
- `Documentation/generate-docs.py` — Screenshot capture + DEMOS.md generation
- `Documentation/DEMOS.md` — Generated from demos.yaml
- `Documentation/screenshots/` — Fresh screenshots (34 demos, 1024×768 @2x)
- `Documentation/collect-screenshots.fish` — Old screenshot script (legacy)
- `Documentation/VIDEO_PLAN.md` — This file
