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

## Bugs to Fix

### DemoKit

- **#DemoKit#11** — URL scheme navigation not working reliably. `open` with a URL scheme launches a NEW app instance instead of routing to the running one. Even `open -a` sometimes spawns duplicates. This is the **critical blocker** for video recording — we need URL-based navigation so we don't see the Demos menu flash on screen.
- **#DemoKit#12** — `kebabCase` produces double hyphens (e.g., `game-of--life` instead of `game-of-life`). Cosmetic but affects URL usability.
- **Window title not updating** — When navigating via URL, the window title bar doesn't always reflect the current demo. May be related to `navigationTitle` not being triggered on URL-driven selection changes.

### steveo

- **#steveo#10** — No screen recording support. Need to start/stop recording manually for now.
- **#steveo#11** — `steveo key "cmd+]"` doesn't work. Bracket characters aren't sent correctly as key events.

## Navigation Options (for video)

| Method | Works? | Video-safe? | Notes |
|--------|--------|-------------|-------|
| Demos menu | ✅ | ❌ | Menu flashes on screen |
| URL scheme | ⚠️ | ✅ | Launches new app instances |
| Cmd+[/] via steveo | ❌ | ✅ | steveo key bug |
| Sidebar click | ✅ | ❌ | Sidebar visible in frame |

**Best path forward:** Fix the URL scheme so `open` routes to the running instance. This requires:
1. Ensuring the app uses `handlesExternalEvents(matching:)` on the Window/WindowGroup scene.
2. Possibly adding `LSMultipleInstancesProhibited = YES` to Info.plist to prevent duplicate launches.
3. Or using an alternative IPC mechanism (e.g., Distributed Notifications, XPC) to send demo selection to the running app.

## Alternative: Sidebar Click + Hide

A workaround that works today:
1. Show sidebar, click demo name, hide sidebar, wait, screenshot/record.
2. Downside: brief sidebar flash during transitions. Might be acceptable if transitions are cut in post.

## Video Choreography

Once navigation is fixed, the recording script should:

1. Launch app, resize to 1024×768, hide sidebar, hide description
2. Start screen recording (manual or steveo #10)
3. For each demo (ordered by `demos.yaml`):
   a. Navigate to demo (via URL — no menu flash)
   b. Wait for settle time
   c. Perform gestures (rotate, click) per choreography in yaml
   d. Adjust UI controls per yaml
   e. Hold for `duration` seconds
4. Stop recording
5. Optionally: split into per-demo clips in post

## Files

- `Documentation/demos.yaml` — Canonical demo index with video choreography fields
- `Documentation/screenshots/` — Fresh screenshots (34 demos, 1024×768 @2x)
- `Documentation/collect-screenshots.fish` — Old screenshot script (superseded)
- `Documentation/DEMOS.md` — Old demo docs (outdated, superseded by demos.yaml)
