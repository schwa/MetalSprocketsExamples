#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml"]
# ///
"""Record and composite a demo reel.

Subcommands:
  record    Launch the app, record a continuous video walk-through, and save
            a timeline sidecar derived from log-file wall-clocks.
  compose   Overlay per-demo captions onto the raw video using the timeline.
  all       Run both (default).

Outputs:
  Documentation/reel-raw.mov                  raw capture
  Documentation/reel-raw.mov.timeline.json    {demos: [{id, name, start, end}]}
  Documentation/reel-raw.log.jsonl            combined log (steveo + recorder)
  Documentation/reel-final.mov                composited
  Documentation/overlays/rendered/<id>.png    intermediate captions

Prerequisites: steveo, screenrecording-tool, rsvg-convert, ffmpeg, ffprobe.

Usage:
  Documentation/generate-video.py                         # record + compose
  Documentation/generate-video.py record --per-demo 3 --limit 5
  Documentation/generate-video.py compose
  Documentation/generate-video.py all --per-demo 3
"""

import argparse
import html
import json
import platform
import shutil
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

import yaml

SCRIPT_DIR = Path(__file__).parent
PROJECT_DIR = SCRIPT_DIR.parent
YAML_PATH = SCRIPT_DIR / "demos.yaml"

APP_NAME = "MetalSprockets-Examples"
APP_BUNDLE_ID = "io.schwa.MetalSprocketsExamples"
APP_SCHEME = "MetalSprockets-Examples"
URL_SCHEME = "metalsprockets-examples"

DEFAULT_OUTPUT = SCRIPT_DIR / "reel-raw.mov"
DEFAULT_FINAL = SCRIPT_DIR / "reel-final.mov"
DEFAULT_TEMPLATE = SCRIPT_DIR / "overlays" / "lower-third.svg"
RENDERED_DIR = SCRIPT_DIR / "overlays" / "rendered"

DEFAULT_WINDOW_SIZE = (1280, 720)
DEFAULT_DURATION = 5.0
NAV_SETTLE = 0.8
PER_DEMO_OVERHEAD = 1.0
TAIL_PAD = 2.0
LAUNCH_TIMEOUT = 15.0


# ─── shared helpers ──────────────────────────────────────────────────────────

def require_tool(name: str) -> None:
    if shutil.which(name) is None:
        print(f"Required tool not found: {name}", file=sys.stderr)
        sys.exit(1)


def steveo(*args: str, log_file: Path | None = None) -> dict | None:
    """Run `steveo --app APP_NAME [--log-file …] <args>` and parse JSON output."""
    cmd = ["steveo", "--app", APP_NAME]
    if log_file is not None:
        cmd += ["--log-file", str(log_file)]
    cmd += list(args)
    result = subprocess.run(cmd, capture_output=True, text=True)
    try:
        return json.loads(result.stdout.strip())
    except (json.JSONDecodeError, ValueError):
        return None


def app_alive(log_file: Path | None = None) -> bool:
    result = steveo("windows", log_file=log_file)
    if not (result and result.get("ok") and result.get("data")):
        return False
    # Reject placeholder AXApplication entries that have no real window.
    for w in result["data"]:
        if w.get("role") == "AXWindow" and (w.get("size") or {}).get("width"):
            return True
    return False


def host_platform() -> str:
    return {"Darwin": "macOS"}.get(platform.system(), platform.system())


def filter_demos_for_host(demos: list[dict]) -> list[dict]:
    host = host_platform()
    out: list[dict] = []
    for d in demos:
        if d.get("name") == "Empty":
            continue
        p = d.get("platform")
        if p is not None and p != host:
            continue
        out.append(d)
    return out


def demo_duration(d: dict, default: float) -> float:
    video = d.get("video") or {}
    dur = video.get("duration")
    try:
        return float(dur) if dur is not None else default
    except (TypeError, ValueError):
        return default


# ─── record subcommand ───────────────────────────────────────────────────────

def build_app() -> None:
    print("Building app (xcb build)...")
    result = subprocess.run(
        ["xcb", "build", "--scheme", APP_SCHEME],
        cwd=PROJECT_DIR,
    )
    if result.returncode != 0:
        print("Build failed.", file=sys.stderr)
        sys.exit(result.returncode)


def ensure_app_running(log_file: Path | None = None) -> None:
    if app_alive(log_file=log_file):
        return
    print("Launching app...")
    result = subprocess.run(
        ["steveo", "launch", APP_BUNDLE_ID],
        capture_output=True,
        text=True,
    )
    try:
        payload = json.loads(result.stdout.strip())
    except (json.JSONDecodeError, ValueError):
        payload = None
    if not payload or not payload.get("ok"):
        print(f"Failed to launch {APP_BUNDLE_ID}: {result.stdout or result.stderr}", file=sys.stderr)
        sys.exit(1)

    deadline = time.monotonic() + LAUNCH_TIMEOUT
    while time.monotonic() < deadline:
        if app_alive(log_file=log_file):
            return
        time.sleep(0.5)
    print(f"App launched but no window appeared within {LAUNCH_TIMEOUT:.0f}s.", file=sys.stderr)
    sys.exit(1)


def resize_or_die(win_url: str, w: int, h: int, log_file: Path) -> None:
    actual_w = actual_h = None
    print(f"Resizing window to {w}x{h}...")
    for _ in range(5):
        steveo("window", "resize", win_url, str(w), str(h), log_file=log_file)
        time.sleep(0.5)
        info = steveo("windows", log_file=log_file)
        if info and info.get("ok") and info["data"]:
            sz = info["data"][0].get("size") or {}
            actual_w, actual_h = sz.get("width"), sz.get("height")
            if actual_w == w and actual_h == h:
                print(f"  actual: {actual_w}x{actual_h}")
                return
    print(
        f"✗ Window would not resize to {w}x{h} (last seen: {actual_w}x{actual_h}). Aborting.",
        file=sys.stderr,
    )
    sys.exit(1)


def set_sidebar(state: str, log_file: Path) -> None:
    info = steveo("find", "--text", "Hide Sidebar", log_file=log_file)
    is_visible = bool(info and info.get("ok") and info.get("data"))
    want_visible = state == "show"
    if is_visible != want_visible:
        subprocess.run(
            ["steveo", "--app", APP_NAME, "--log-file", str(log_file),
             "key", "s", "--cmd", "--ctrl"],
            capture_output=True,
        )
        time.sleep(0.3)


def wallclock_timestamp() -> str:
    """ISO8601 with microseconds, matching steveo's log format (but with us)."""
    return datetime.now().astimezone().isoformat(timespec="microseconds")


def append_log(log_file: Path, event: dict) -> None:
    with log_file.open("a") as f:
        f.write(json.dumps(event) + "\n")


def do_record(args: argparse.Namespace) -> None:
    require_tool("steveo")
    require_tool("screenrecording-tool")

    w, h = (int(x) for x in args.window_size.split("x"))

    with open(YAML_PATH) as f:
        data = yaml.safe_load(f)
    demos = filter_demos_for_host(data["demos"])
    if args.limit is not None:
        demos = demos[: args.limit]
    if not demos:
        print("No demos to record.", file=sys.stderr)
        sys.exit(1)

    if args.per_demo is not None:
        per_demo = [(d, args.per_demo) for d in demos]
    else:
        per_demo = [(d, demo_duration(d, args.default_duration)) for d in demos]
    total_duration = sum(dur + PER_DEMO_OVERHEAD for _, dur in per_demo) + TAIL_PAD

    print(f"Plan: {len(demos)} demos, ~{total_duration:.0f}s total, window {w}x{h}")
    print(f"Output: {args.output}")
    print()
    for i, (d, dur) in enumerate(per_demo):
        print(f"  [{i + 1:2d}] {d['name']:30s} {dur:>5.1f}s")
    print()

    if args.dry_run:
        return

    out_path = args.output.resolve()
    out_path.parent.mkdir(parents=True, exist_ok=True)

    # screenrecording-tool's --log-file truncates, so keep it separate from
    # our steveo/nav log. Both log files share the system clock; we align by
    # matching the recorder's `recording_started` event (with a recorded
    # wall-clock we stash in our log) to establish t=0.
    log_file = out_path.with_suffix("").with_suffix(".log.jsonl")
    recorder_log = out_path.with_suffix("").with_suffix(".recorder.jsonl")
    log_file.write_text("")

    if not args.no_build:
        build_app()

    if not args.no_launch:
        ensure_app_running(log_file=log_file)
    elif not app_alive(log_file=log_file):
        print(f"Error: {APP_NAME} is not running and --no-launch was set.", file=sys.stderr)
        sys.exit(1)

    # Wait for a window with a real size to appear
    for _ in range(20):
        info = steveo("windows", log_file=log_file)
        if info and info.get("ok") and info["data"]:
            sz = info["data"][0].get("size") or {}
            if sz.get("width") and sz.get("height"):
                break
        time.sleep(0.25)

    win_url = steveo("windows", log_file=log_file)["data"][0]["url"]
    resize_or_die(win_url, w, h, log_file)

    print(f"Panels: sidebar={args.sidebar}, description={args.description}, configuration={args.configuration}")
    set_sidebar(args.sidebar, log_file)
    steveo("open-url", f"{URL_SCHEME}://description/{args.description}", log_file=log_file)
    time.sleep(0.2)
    steveo("open-url", f"{URL_SCHEME}://configuration/{args.configuration}", log_file=log_file)
    time.sleep(0.2)

    first_id = per_demo[0][0]["id"]
    print(f"Navigating to first demo: {first_id}")
    steveo("open-url", f"{URL_SCHEME}://demo/{first_id}", log_file=log_file)
    time.sleep(NAV_SETTLE)

    if not app_alive(log_file=log_file):
        print("App died before recording started. Aborting.", file=sys.stderr)
        sys.exit(1)

    # Log a marker so compose can find the recorder start
    append_log(log_file, {
        "timestamp": wallclock_timestamp(),
        "event": "recorder_launching",
        "duration": total_duration,
        "output": str(out_path),
    })

    cmd = [
        "screenrecording-tool", "record",
        "--app", APP_NAME,
        "--profile", args.profile,
        "--duration", f"{total_duration:.2f}",
        "--log-file", str(recorder_log),
        str(out_path),
    ]
    print(f"Starting recorder: {' '.join(cmd)}")
    recorder = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    time.sleep(1.0)  # small warm-up

    try:
        for i, (d, dur) in enumerate(per_demo):
            demo_id = d["id"]
            name = d["name"]
            label = f"[{i + 1:2d}/{len(per_demo)}] {name:30s}"

            if not app_alive(log_file=log_file):
                print(f"{label} ✗ app died — stopping navigation")
                break

            print(f"{label} → navigating...", flush=True)
            append_log(log_file, {
                "timestamp": wallclock_timestamp(),
                "event": "nav_start",
                "demo_id": demo_id,
                "demo_name": name,
            })
            steveo("open-url", f"{URL_SCHEME}://demo/{demo_id}", log_file=log_file)
            time.sleep(NAV_SETTLE)

            if not app_alive(log_file=log_file):
                print(f"{label} ✗ app died after navigation")
                break

            append_log(log_file, {
                "timestamp": wallclock_timestamp(),
                "event": "nav_visible",
                "demo_id": demo_id,
                "demo_name": name,
            })

            time.sleep(dur)
            print(f"{label} ✓ ({dur:.1f}s)", flush=True)
    finally:
        print("Waiting for recorder to finish...")
        out, err = recorder.communicate(timeout=total_duration + 10.0)
        print(f"Recorder exited with {recorder.returncode}")
        if out:
            text = out.decode("utf-8", errors="replace").strip()
            if text:
                print(f"recorder stdout:\n{text}")
        if err:
            text = err.decode("utf-8", errors="replace").strip()
            if text:
                print(f"recorder stderr:\n{text}", file=sys.stderr)

    timeline = timeline_from_log(log_file, recorder_log)
    sidecar = out_path.with_suffix(out_path.suffix + ".timeline.json")
    sidecar.write_text(json.dumps({"video": str(out_path), "demos": timeline}, indent=2))

    if out_path.exists():
        size_mb = out_path.stat().st_size / (1024 * 1024)
        print(f"\nRaw video: {out_path} ({size_mb:.1f} MB)")
    else:
        print(f"\n✗ Expected video at {out_path} but it was not created.", file=sys.stderr)
    print(f"Timeline:  {sidecar}")
    print(f"Log:       {log_file}")


def parse_iso(ts: str) -> float:
    """Parse ISO8601 timestamp to epoch seconds. Tolerates steveo's '3N' micro field."""
    # steveo writes e.g. "2026-04-19T17:13:46.3N-0700" where "3N" seems to be a
    # nanosecond-stripped placeholder. Replace any non-digit in the fractional
    # part with '0' so fromisoformat can parse it.
    # Rough split on 'T'
    if "T" not in ts:
        raise ValueError(f"not an ISO timestamp: {ts}")
    date, time_part = ts.split("T", 1)
    # Find the fractional + tz sections
    # Format: HH:MM:SS[.xxx](+|-)HHMM  or HH:MM:SS[.xxx]Z
    # Normalise the fractional digits to all-numeric.
    import re
    m = re.match(r"(\d{2}:\d{2}:\d{2})(\.[^+\-Z]*)?([+-]\d{2}:?\d{2}|Z)?$", time_part)
    if not m:
        raise ValueError(f"bad time: {time_part}")
    hms, frac, tz = m.groups()
    if frac:
        # Keep only digits, pad to 6
        digits = "".join(ch for ch in frac[1:] if ch.isdigit())
        digits = (digits + "000000")[:6]
        frac = "." + digits
    else:
        frac = ""
    if tz and tz != "Z" and ":" not in tz:
        tz = tz[:3] + ":" + tz[3:]
    if tz is None:
        tz = ""
    normalised = f"{date}T{hms}{frac}{tz}"
    dt = datetime.fromisoformat(normalised.replace("Z", "+00:00"))
    return dt.timestamp()


def timeline_from_log(log_file: Path, recorder_log: Path) -> list[dict]:
    """Return [{id, name, start, end}, ...] in seconds from recording start.

    `log_file` has our wall-clock events (nav_start, nav_visible,
    recorder_launching). `recorder_log` has the recorder's own meta events
    (recording_started, recording_stopped) with timestamps relative to its
    own capture start. We use the wall-clock we stash at `recorder_launching`
    (just before Popen) as an approximation of the recorder's t=0 wall-clock.
    """
    def load(path: Path) -> list[dict]:
        out = []
        if not path.exists():
            return out
        with path.open() as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    out.append(json.loads(line))
                except json.JSONDecodeError:
                    pass
        return out

    events = load(log_file)
    rec_events = load(recorder_log)

    recording_started_rel = None
    recording_stopped_rel = None
    recorder_launch_wall = None

    for e in rec_events:
        if e.get("type") == "meta" and e.get("event") == "recording_started":
            recording_started_rel = float(e.get("timestamp", 0))
        elif e.get("type") == "meta" and e.get("event") == "recording_stopped":
            recording_stopped_rel = float(e.get("timestamp", 0))

    for e in events:
        if e.get("event") == "recorder_launching":
            recorder_launch_wall = parse_iso(e["timestamp"])
            break

    if recorder_launch_wall is None:
        print("⚠ No `recorder_launching` marker in log; cannot align timestamps.", file=sys.stderr)
        return []

    wall_t0 = recorder_launch_wall + (recording_started_rel or 0.0)

    # Use nav_start as the caption-appears-at timestamp (the moment we fire
    # the URL scheme). That aligns the caption with the demo transition,
    # rather than after our NAV_SETTLE sleep.
    navs: list[tuple[float, str, str]] = []
    for e in events:
        if e.get("event") == "nav_start" and "demo_id" in e:
            ts = parse_iso(e["timestamp"]) - wall_t0
            navs.append((ts, e["demo_id"], e.get("demo_name", e["demo_id"])))
    navs.sort()

    if not navs:
        return []

    # `end` for each demo = `start` of the next demo; last demo ends at
    # recording_stopped (or its start + 3s fallback). Clamp the first demo's
    # `start` to 0 so its caption covers the recorder's warm-up window
    # (the first demo is already on screen when recording begins).
    timeline: list[dict] = []
    for i, (start, demo_id, name) in enumerate(navs):
        if i == 0:
            start = 0.0
        if i + 1 < len(navs):
            end = navs[i + 1][0]
        elif recording_stopped_rel is not None:
            end = recording_stopped_rel
        else:
            end = start + 3.0
        timeline.append({
            "id": demo_id,
            "name": name,
            "start": round(start, 3),
            "end": round(end, 3),
        })
    return timeline


# ─── compose subcommand ──────────────────────────────────────────────────────

def ffprobe_dimensions(video: Path) -> tuple[int, int]:
    result = subprocess.run(
        [
            "ffprobe", "-v", "error",
            "-select_streams", "v:0",
            "-show_entries", "stream=width,height",
            "-of", "json",
            str(video),
        ],
        capture_output=True, text=True, check=True,
    )
    data = json.loads(result.stdout)
    stream = data["streams"][0]
    return int(stream["width"]), int(stream["height"])


def load_demo_index() -> dict[str, dict]:
    with open(YAML_PATH) as f:
        data = yaml.safe_load(f)
    return {d["id"]: d for d in data["demos"]}


def render_caption(template: str, demo: dict, width: int, out_path: Path) -> None:
    keywords = demo.get("keywords") or []
    kw_text = "  ·  ".join(keywords[:4])
    filled = (
        template
        .replace("{{WIDTH}}", str(width))
        .replace("{{NAME}}", html.escape(demo.get("name", "")))
        .replace("{{DESCRIPTION}}", html.escape(demo.get("description") or ""))
        .replace("{{KEYWORDS}}", html.escape(kw_text))
    )
    svg_path = out_path.with_suffix(".svg")
    svg_path.write_text(filled)
    subprocess.run(
        ["rsvg-convert", "-w", str(width), "-o", str(out_path), str(svg_path)],
        check=True,
    )


def build_filter_complex(timeline: list[dict], video_height: int, caption_height: int) -> str:
    y = video_height - caption_height
    chain = []
    prev = "[0:v]"
    for i, demo in enumerate(timeline):
        input_idx = i + 1
        label = f"[v{i}]"
        chain.append(
            f"{prev}[{input_idx}:v]overlay=0:{y}:enable='between(t,{demo['start']:.3f},{demo['end']:.3f})'{label}"
        )
        prev = label
    chain.append(f"{prev}null[vout]")
    return ";".join(chain)


def do_compose(args: argparse.Namespace) -> None:
    for tool in ("rsvg-convert", "ffmpeg", "ffprobe"):
        require_tool(tool)

    in_path = args.input.resolve()
    out_path = args.output.resolve()
    template_path = args.template.resolve()
    timeline_path = (args.timeline or in_path.with_suffix(in_path.suffix + ".timeline.json")).resolve()

    for p in (in_path, template_path, timeline_path, YAML_PATH):
        if not p.exists():
            print(f"Missing input: {p}", file=sys.stderr)
            sys.exit(1)

    timeline = json.loads(timeline_path.read_text())["demos"]
    demo_index = load_demo_index()
    template = template_path.read_text()

    video_w, video_h = ffprobe_dimensions(in_path)
    print(f"Input: {in_path.name} ({video_w}x{video_h}), {len(timeline)} demo slots")

    RENDERED_DIR.mkdir(parents=True, exist_ok=True)
    caption_pngs: list[Path] = []
    for demo in timeline:
        demo_id = demo["id"]
        meta = demo_index.get(demo_id, {"name": demo.get("name", demo_id), "description": "", "keywords": []})
        png = RENDERED_DIR / f"{demo_id}.png"
        render_caption(template, meta, video_w, png)
        caption_pngs.append(png)

    _, cap_h = ffprobe_dimensions(caption_pngs[0])
    print(f"Caption size: {video_w}x{cap_h}")

    filter_complex = build_filter_complex(timeline, video_h, cap_h)

    cmd: list[str] = ["ffmpeg", "-y", "-i", str(in_path)]
    for png in caption_pngs:
        cmd += ["-i", str(png)]
    cmd += [
        "-filter_complex", filter_complex,
        "-map", "[vout]",
        "-map", "0:a?",
        "-c:v", "libx264",
        "-preset", "medium",
        "-crf", "18",
        "-pix_fmt", "yuv420p",
        "-c:a", "copy",
        str(out_path),
    ]

    if args.dry_run:
        print("Dry run. ffmpeg command:")
        print(" \\\n  ".join(cmd))
        return

    print(f"Rendering {out_path}...")
    result = subprocess.run(cmd)
    if result.returncode != 0:
        sys.exit(result.returncode)

    size_mb = out_path.stat().st_size / (1024 * 1024)
    print(f"✓ {out_path} ({size_mb:.1f} MB)")


# ─── cli ─────────────────────────────────────────────────────────────────────

def _add_record_args(p: argparse.ArgumentParser) -> None:
    p.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    p.add_argument("--default-duration", type=float, default=DEFAULT_DURATION)
    p.add_argument("--per-demo", type=float, default=None)
    p.add_argument("--limit", type=int, default=None)
    p.add_argument("--window-size", default=f"{DEFAULT_WINDOW_SIZE[0]}x{DEFAULT_WINDOW_SIZE[1]}")
    p.add_argument("--profile", default="edit", choices=["social", "edit", "raw", "lossless"])
    p.add_argument("--no-build", action="store_true")
    p.add_argument("--no-launch", action="store_true")
    p.add_argument("--sidebar", choices=["show", "hide"], default="hide")
    p.add_argument("--description", choices=["show", "hide"], default="show")
    p.add_argument("--configuration", choices=["show", "hide"], default="show")
    p.add_argument("--dry-run", action="store_true")


def _add_compose_args(p: argparse.ArgumentParser) -> None:
    p.add_argument("--input", type=Path, default=DEFAULT_OUTPUT)
    p.add_argument("--output", type=Path, default=DEFAULT_FINAL)
    p.add_argument("--template", type=Path, default=DEFAULT_TEMPLATE)
    p.add_argument("--timeline", type=Path, default=None)
    p.add_argument("--dry-run", action="store_true")


def main() -> None:
    parser = argparse.ArgumentParser(description="Record and/or composite a demo reel.")
    sub = parser.add_subparsers(dest="cmd")

    r = sub.add_parser("record", help="Record the raw reel")
    _add_record_args(r)

    c = sub.add_parser("compose", help="Composite captions onto a raw reel")
    _add_compose_args(c)

    a = sub.add_parser("all", help="Record then compose")
    _add_record_args(a)
    a.add_argument("--final-output", dest="final_output", type=Path, default=DEFAULT_FINAL, help=f"Final composited video (default: {DEFAULT_FINAL})")
    a.add_argument("--template", type=Path, default=DEFAULT_TEMPLATE)

    args = parser.parse_args()

    if args.cmd == "record":
        do_record(args)
    elif args.cmd == "compose":
        do_compose(args)
    elif args.cmd == "all" or args.cmd is None:
        if args.cmd is None:
            # Default: `all` with its defaults
            args = parser.parse_args(["all"])
        do_record(args)
        # Feed record's output → compose
        compose_ns = argparse.Namespace(
            input=args.output,
            output=args.final_output,
            template=args.template,
            timeline=None,
            dry_run=False,
        )
        do_compose(compose_ns)


if __name__ == "__main__":
    main()
