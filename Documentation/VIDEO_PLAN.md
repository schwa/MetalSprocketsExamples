# Video Recording Plan

## Goal

Automatically record a demo video showcasing all MetalSprocketsExamples demos using `steveo` for UI automation and screen recording.

## What Works

- **Demos menu** — Fixed! The `FocusedViewModelRetainer` in DemoKit keeps the viewModel available even when the window isn't focused. Navigation via `steveo --app "MetalSprockets-Examples" menu "Demos" "Triangle"` works reliably.
- **Screenshot collection** — Fully automated via `steveo screenshot`. All 34 demos captured successfully at 1024×768.
- **Sidebar toggle** — Can hide/show sidebar via `steveo find --text "Hide Sidebar" --click`.
- **Description toggle** — Can hide/show description banner via the (i) button.
- **Window resize** — `steveo window resize` works for consistent sizing.
- **demos.yaml** — Canonical index of all demos with metadata, interest levels, and choreography hints.
- **Drag/rotate** — `steveo focus` then `steveo drag x1 y1 x2 y2 --duration ms` rotates 3D views. **IMPORTANT: must `steveo focus` the app before any drag, or the drag events won't register.**
- **Screen recording** — `steveo record --window "Title" --duration N -o file.mp4` captures per-window video. Can run in background while performing drags.
- **generate-docs.py** — Single script for both screenshot capture and DEMOS.md generation from demos.yaml.

## Bugs to Fix

### DemoKit

- **#DemoKit#11** — URL scheme navigation launches NEW app instances instead of routing to the running one. URLs do work when they reach the right instance. Not a blocker since menu navigation works, but would be cleaner for video.
- **#DemoKit#12** — `kebabCase` produces double hyphens (e.g., `game-of--life` instead of `game-of-life`).

### steveo

- **#steveo#11** — `steveo key "cmd+]"` doesn't work. Bracket characters aren't sent correctly as key events.
- **#steveo#13** — Drag requires `steveo focus` first — not auto-focused. (UX improvement, not a blocker.)
- Screen recording captures full screen instead of just the window. Fix in progress.

### MetalSprocketsExamples

- **#MSE#367** — Accessibility pass needed: sliders, pickers, popups missing `.accessibilityLabel()`. Blocks driving controls by name via steveo.
- **#MSE#368** — Interaction3D Turntable controls missing AX labels (upstream fix).

## Navigation for Video

The Demos menu works reliably but flashes on screen. Options:

| Method | Works? | Video-safe? | Notes |
|--------|--------|-------------|-------|
| Demos menu | ✅ | ❌ | Menu flashes on screen |
| URL scheme | ⚠️ | ✅ | Launches new app instances |
| Cmd+[/] via steveo | ❌ | ✅ | steveo key bug |
| Sidebar click | ✅ | ❌ | Sidebar visible in frame |

**Current approach:** Use Demos menu between recordings. Each demo gets its own recording clip (start recording → perform gestures → stop recording), so menu flash between clips doesn't matter.

## Video Choreography

Per-demo recording approach:

1. Launch app, resize to 1024×768, hide sidebar
2. For each demo (ordered by `demos.yaml`):
   a. Navigate via Demos menu
   b. Wait for settle time
   c. Focus app (`steveo focus`)
   d. Start recording (`steveo record --window "Title" --duration N -o clip.mp4 &`)
   e. Perform gestures (drag to rotate) per choreography in yaml
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
