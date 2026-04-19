# Documentation & Video Generation Plan

Automated screenshots, `DEMOS.md`, and per-demo video clips for the MetalSprocketsExamples demo set.

## Goals

- **Screenshots + `DEMOS.md`** — one PNG per demo, a Markdown index generated from `demos.yaml`.
- **Demo video** — a showcase reel built from per-demo clips captured through the same automation.

Both pipelines share the same navigation and metadata; only the capture step differs (`steveo screenshot` vs `screenrecording-tool record`).

## Tooling

### steveo (UI automation)

- **URL scheme navigation** — `steveo --app "MetalSprockets-Examples" open-url metalsprockets-examples://demo/<id>` routes to the running app instance and switches demos reliably. **Primary navigation method.**
- **Demos menu** — `steveo --app "MetalSprockets-Examples" menu "Demos" "<Name>"` exists but is flaky: SwiftUI command menus are sometimes not exposed through AX until the app has been frontmost and the menu opened at least once. Avoid when scripting.
- **Screenshot** — `steveo screenshot -o path.png` captures the focused window (Metal content preserved).
- **Sidebar toggle** — `steveo find --text "Hide Sidebar" --click`.
- **Description toggle** — Hide/show description banner via the (i) button.
- **Window resize** — `steveo window resize <url> <w> <h>`.
- **Drag/rotate** — `steveo focus` then `steveo drag x1 y1 x2 y2 --duration ms` rotates 3D views. Must `steveo focus` before drag.
- **Bezier drag** — `steveo drag-path` for smooth curved camera movements.
- **Key combos** — `steveo key` supports named keys and modifiers. Bracket keys (`]`, `[`) not in the named key list, but `--raw <keycode>` can send any keycode.

### screenrecording-tool (video capture)

- **Per-window recording** — `screenrecording-tool record --window "Title" -d 10 clip.mov` captures a single window.
- **Per-app recording** — `screenrecording-tool record --app "AppName"` captures all windows of an app.
- **Output profiles** — `--profile social` (small), `edit` (high quality), `raw` (maximum), `lossless`.
- **Click highlights** — `--click-highlight` overlays visual feedback on clicks.
- **Cursor control** — `--no-show-cursor` to hide cursor, `--cursor-image` for custom cursor.
- **Event logging** — `--event-log events.jsonl` records mouse + keyboard events alongside video.
- **System audio** — `--audio` captures system audio.
- **Padding** — `--padding N` adds pixels around the capture area.

### Project files

- `Documentation/demos.yaml` — Canonical demo index with metadata, interest levels, and choreography hints.
- `Documentation/generate-docs.py` — Screenshot capture + `DEMOS.md` generation. `--docs` / `--screenshots` / `--all`. Uses `uv run --with pyyaml`.
- `Documentation/DEMOS.md` — Generated output.
- `Documentation/screenshots/` — Full-size captures (1024×768 @2x).
- `Documentation/screenshots/thumbnails/` — 320px-wide thumbnails (`sips -Z 320`).

## Navigation Methods Compared

| Method | Works? | Video-safe? | Notes |
|--------|--------|-------------|-------|
| URL scheme (`steveo open-url --app`) | ✅ | ✅ | Primary method. Fast, reliable, no UI flash. |
| Demos menu | ⚠️ | ✅ | AX exposure is flaky; requires app frontmost and menu previously opened. |
| Cmd+]/[ via `steveo --raw` | ✅ | ✅ | Needs verification. |
| Sidebar click | ✅ | ❌ | Sidebar visible in frame. |

## Current State

- All 46 macOS demos capture cleanly at 1024×768 via URL-scheme navigation.
- `DEMOS.md` regenerates from `demos.yaml` with screenshots embedded.
- Per-step app-liveness check in the python script aborts cleanly if the app crashes mid-run.

## Known Issues / TODO

### Window chrome

- **Sidebar is visible in all captures**, wasting ~250px on the left. Hide it before the capture loop. Options:
  - Toolbar "Hide Sidebar" button via `steveo find --click`
  - `Cmd+Ctrl+S` keystroke via `steveo key`
  - A DemoKit configuration flag (if one exists / can be added)
- **Title bar decision pending.** Include (gives demo-name context) or exclude (cleaner for doc embeds)? DemoKit may already expose a toggle for this — find it before rolling our own.
- DemoKit supports URL actions like `<scheme>://screenshot` (triggers its own built-in capture) but that uses SwiftUI `ImageRenderer` and **won't capture Metal content** — not useful here. Keep using `steveo screenshot`.

Newer DemoKit adds URL actions for chrome control (once we update):
- `<scheme>://configuration/show|hide|toggle` (alias `config`)
- `<scheme>://description/show|hide|toggle`

These let us pre-script panel state via URL scheme instead of AX-finding buttons.

### Per-demo capture behaviour

Some demos need interaction before they render anything interesting. Add per-demo fields to `demos.yaml`:

- **`settle_time`** (float, optional) — override the global `--settle-time` for demos that need more (or less) time before the first frame is representative. Path tracers need several seconds to converge; a static triangle is ready immediately.
- **`pre_capture`** (list, optional) — ordered actions to perform after navigation, before the screenshot. Each item is something like:
  - `{ click_text: "Start" }` — find and click a button by visible text
  - `{ click_at: [x, y] }` — click a specific point inside the window
  - `{ key: "space" }` — send a keystroke
  - `{ wait: 2.0 }` — extra sleep

Example:

```yaml
- name: Some Demo
  id: SomeDemo
  settle_time: 5
  pre_capture:
    - click_text: "Run"
    - wait: 2
```

The python script walks `pre_capture` sequentially via corresponding `steveo` subcommands, then falls through to the screenshot.

### Upstream blockers

- **DemoKit #12** — `kebabCase` produces double hyphens (e.g., `game-of--life`). Minor.
- **steveo #11** — Named key list doesn't include bracket characters. Workaround: `steveo key --raw 30` for `]`, `--raw 33` for `[`. May be fixed; needs verification.
- **MSE #367** — Accessibility pass needed: sliders, pickers, popups missing `.accessibilityLabel()`. Blocks driving controls by name via steveo.
- **MSE #368** — Interaction3D Turntable controls missing AX labels (upstream fix).

### Nice-to-have (script ergonomics)

- `--list` mode that prints the demos that would be captured (respecting platform filter) without running anything.
- `--skip-thumbnails` flag for quick iteration.
- Validate that every yaml entry's `id` actually resolves in the app (a dry-run URL ping that checks the window title changes).

## Video Choreography

Unlike screenshots (one still per demo), the video pipeline does **one continuous recording** for the entire run. The recorder starts once, navigates between demos while rolling, and stops at the end — producing a single raw clip. Overlays/trims/concatenation are applied later to the raw clip (see "Pipeline: raw capture → overlay composite" below).

Top-level flow:

1. Build app (`xcb build`).
2. Launch app (`steveo launch io.schwa.MetalSprocketsExamples`).
3. Resize to target size, hide sidebar.
4. Navigate to the first demo in the video order.
5. Verify app is still alive and displaying the expected demo (check window title matches).
6. **Start recording** (`screenrecording-tool record --window "Title" --profile edit -d <total_duration> reel-raw.mov &`).
7. For each demo in the video order:
   1. Navigate via URL scheme (`steveo open-url --app "$APP" metalsprockets-examples://demo/<id>`).
   2. Wait briefly for the view to mount.
   3. Liveness check — if the app crashed, bail out (recording will still save what it got).
   4. Run the demo's `choreography` (waits + clicks + drags) while the recording continues.
8. **Stop recording.**
9. Raw clip is saved untouched. A second pass composites overlays and trims / concatenates as needed.

### Per-demo video fields (`demos.yaml`)

The existing `video:` block should carry everything the recorder needs:

- **`duration`** (float) — total clip length in seconds.
- **`choreography`** (list, optional) — ordered actions performed **during** the recording. Each item maps to a steveo call, e.g.:
  - `{ wait: 2 }` — idle for N seconds (recording keeps rolling)
  - `{ click_text: "Run" }` — click a button by visible text
  - `{ click_at: [x, y] }` — click a specific point inside the window
  - `{ drag: { from: [x1, y1], to: [x2, y2], duration_ms: 1000 } }` — drag to rotate/pan
  - `{ drag_path: [...] }` — bezier-curve drag for smooth camera moves
  - `{ key: "space" }` / `{ key_raw: 30 }` — keystrokes
  - `{ set_value: { label: "Intensity", value: 0.8 } }` — slider/picker (needs AX labels)
- **`interest`** (`low`/`medium`/`high`) — hint for which clips to feature in trailers.
- **`notes`** — freeform human notes.

Example:

```yaml
- name: Bouncing Teapots
  id: BouncingTeapots
  video:
    duration: 10
    interest: high
    choreography:
      - wait: 2                         # let physics run visibly
      - drag: { from: [512, 400], to: [800, 200], duration_ms: 1500 }
      - wait: 2
```

Key difference from screenshots' `pre_capture`: video `choreography` runs **while** the single long recording is live; `pre_capture` runs **before** each individual still capture.

To compute the total recording duration, sum each demo's `video.duration` (plus a small per-demo overhead for navigation settle). That total becomes the `-d` flag passed to `screenrecording-tool record`.

### Video order & curation

The video is **not** just `demos.yaml` in yaml order — it's a curated screening with a narrative arc. Requirements:

- An ordered list of demo ids defining the video sequence.
- Ability to **exclude** demos from the video entirely (not every demo belongs).
- Dedupe concern: some visual elements (e.g. the grid/axis gizmo) appear in many demos; once the viewer has seen them, later clips shouldn't re-explain them. Ordering should put "foundations" first so later clips can build on them without redundancy.
- Probable shape: separate `video_order` list (ids only) kept beside `demos.yaml`, so the catalog and the video script stay decoupled.

Design and authoring the ordering is future work — just capturing the requirement here.

### Text overlay

Each clip gets an on-screen caption explaining what the viewer is looking at. The text is driven straight from `demos.yaml` so it stays in sync with the rest of the docs.

- **Title line:** `name` (e.g. *Bouncing Teapots*).
- **Subtitle line:** `description` (the short one-liner).
- Optional third line: short keyword chips from `keywords` (e.g. `instancing · metalfx`).

### Pipeline: raw capture → overlay composite

The raw capture is a **single long recording** covering all demos. The post-processing pass timelines per-demo caption overlays onto that single clip, so we can re-render captions without re-recording.

```
reel-raw.mov  +  caption-<id>.svg  →  caption-<id>.png  →  reel-final.mov
(unmodified)     (templated)           (rendered)           (ffmpeg overlay, timed)
```

Steps:

1. **Timeline.** During capture, record a timestamp each time we navigate to a new demo (seconds-since-recording-start → demo id). Store as a sidecar JSON/YAML next to the raw video.
2. **Template.** One SVG template per caption style, with placeholder text (e.g. `{{name}}`, `{{description}}`, `{{keywords}}`). Stored under `Documentation/overlays/`.
3. **Fill + render.** For each demo in the timeline, substitute values from `demos.yaml` into the template and rasterise to a transparent PNG (1024×Xpx, matching the capture size). Candidate CLI tools:
   - `rsvg-convert -o out.png in.svg` (cairo/librsvg, fast, handles most SVG).
   - `resvg out.png -- in.svg` (pure-Rust; stricter about CSS but sharper hinting).
   - `qlmanage -t -s 1024` (native macOS fallback).
4. **Composite.** One ffmpeg invocation overlays all caption PNGs at their timeline offsets, e.g.:
   ```bash
   ffmpeg -i reel-raw.mov \
     -i caption-Triangle.png -i caption-BouncingTeapots.png ... \
     -filter_complex "\
       [0][1]overlay=0:H-h:enable='between(t,0.0,4.0)'[v1]; \
       [v1][2]overlay=0:H-h:enable='between(t,4.0,14.0)'[v2]; \
       ..." \
     reel-final.mov
   ```
   Add `format=yuva420p,fade=in:st=..:d=0.3:alpha=1,fade=out:...` per overlay input for fade transitions.
5. (Optional) **Trim / re-cut.** If demos ran over/under, cut with `ffmpeg -ss/-t` using the sidecar timeline; no re-recording required.

Keep everything driven from `demos.yaml` so templates + data = final video. No state hidden in a video editor.

Styling knobs worth having:
- Fade-in / fade-out at start and end of the caption.
- Safe-area padding so captions don't clash with demo chrome.
- Per-demo opt-out via a `video.no_caption: true` flag for demos where text would obscure the point (e.g. Text Panel, Matrix Rain).
- Per-demo or per-template overlay variants (e.g. title card vs lower-third vs corner-badge).
