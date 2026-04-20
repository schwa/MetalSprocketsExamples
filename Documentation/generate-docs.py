#!/usr/bin/env python3
"""Generate screenshots and DEMOS.md from demos.yaml.

Navigation uses the app's URL scheme (metalsprockets-examples://demo/<id>),
so `id` in demos.yaml must match what DemoKit derives for each demo.
Screenshots are captured via `steveo screenshot` against the app window so
Metal-rendered content is preserved.

Prerequisites:
    - steveo, sips in PATH
    - MetalSprockets-Examples app already running (e.g. launch via `xcb run`)

Usage:
    uv run --with pyyaml Documentation/generate-docs.py [--screenshots] [--docs] [--all]
    uv run --with pyyaml Documentation/generate-docs.py --screenshots --settle-time 5
    uv run --with pyyaml Documentation/generate-docs.py --screenshots --demo Triangle

Options:
    --screenshots       Capture screenshots (requires app running + steveo)
    --docs              Generate DEMOS.md from demos.yaml
    --all               Both screenshots and docs (default if no flags given)
    --settle-time SECS  Seconds to wait after navigating before capturing (default: 3)
    --demo NAME         Only capture a single demo by name or id
    --window-size WxH   Window size (default: 1024x768)
"""

import json
import platform
import subprocess
import time
import yaml
from collections import OrderedDict
from pathlib import Path
import argparse
import sys

SCRIPT_DIR = Path(__file__).parent
REPO_ROOT = SCRIPT_DIR.parent
YAML_PATH = SCRIPT_DIR / "demos.yaml"
OUTPUT_MD = SCRIPT_DIR / "DEMOS.md"
README_MD = REPO_ROOT / "README.md"
SCREENSHOTS_DIR = SCRIPT_DIR / "screenshots"
THUMBNAILS_DIR = SCREENSHOTS_DIR / "thumbnails"
APP_NAME = "MetalSprockets-Examples"
URL_SCHEME = "metalsprockets-examples"
THUMB_WIDTH = 320

README_BEGIN_MARKER = "<!-- BEGIN:DEMOS -->"
README_END_MARKER = "<!-- END:DEMOS -->"


def steveo(*args: str) -> dict | None:
    """Run `steveo --app APP_NAME ...` and parse JSON output."""
    result = subprocess.run(
        ["steveo", "--app", APP_NAME, *args],
        capture_output=True,
        text=True,
    )
    try:
        return json.loads(result.stdout.strip())
    except (json.JSONDecodeError, ValueError):
        return None


def app_alive() -> bool:
    """Return True if the app has at least one window visible."""
    result = steveo("windows")
    return bool(result and result.get("ok") and result.get("data"))


def host_platform() -> str:
    """Canonical platform string used in demos.yaml."""
    system = platform.system()
    return {"Darwin": "macOS"}.get(system, system)


def filter_demos_for_host(demos: list[dict]) -> list[dict]:
    """Drop the Empty placeholder and any demos whose platform doesn't match."""
    host = host_platform()
    out = []
    for d in demos:
        if d.get("name") == "Empty":
            continue
        p = d.get("platform")
        if p is not None and p != host:
            continue
        out.append(d)
    return out


def capture_screenshots(
    demos: list[dict],
    settle_time: float,
    window_size: tuple[int, int],
    single_demo: str | None,
) -> None:
    SCREENSHOTS_DIR.mkdir(parents=True, exist_ok=True)
    THUMBNAILS_DIR.mkdir(parents=True, exist_ok=True)

    if not app_alive():
        print(f"Error: {APP_NAME} is not running. Launch it first.", file=sys.stderr)
        sys.exit(1)

    win_url = steveo("windows")["data"][0]["url"]
    w, h = window_size
    print(f"Resizing window to {w}x{h}...")
    steveo("window", "resize", win_url, str(w), str(h))

    demos = filter_demos_for_host(demos)
    if single_demo:
        demos = [d for d in demos if d["name"] == single_demo or d["id"] == single_demo]
        if not demos:
            print(f"Error: demo '{single_demo}' not found.", file=sys.stderr)
            sys.exit(1)

    total = len(demos)
    captured = 0
    failed = 0

    print(f"Capturing screenshots for {total} demos (settle time: {settle_time}s)...")
    print()

    for i, d in enumerate(demos):
        name = d["name"]
        file_id = d["id"]
        print(f"[{i + 1:2d}/{total}] {name:30s} ", end="", flush=True)

        if not app_alive():
            print("✗ app died — aborting")
            failed += 1
            break

        result = steveo("open-url", f"{URL_SCHEME}://demo/{file_id}")
        if not result or not result.get("ok"):
            print("SKIP (navigation failed)")
            failed += 1
            continue

        time.sleep(settle_time)

        if not app_alive():
            print("✗ app died after navigation — aborting")
            failed += 1
            break

        outpath = SCREENSHOTS_DIR / f"{file_id}.png"
        result = steveo("screenshot", "-o", str(outpath))
        if not (result and result.get("ok")):
            print("✗ screenshot failed")
            failed += 1
            continue

        thumbpath = THUMBNAILS_DIR / f"{file_id}.png"
        subprocess.run(
            ["sips", "-Z", str(THUMB_WIDTH), str(outpath), "--out", str(thumbpath)],
            capture_output=True,
        )
        print("✓")
        captured += 1

    print()
    print(f"Done: {captured} captured, {failed} failed out of {total} demos.")
    print(f"Screenshots saved to: {SCREENSHOTS_DIR}/")
    print(f"Thumbnails saved to: {THUMBNAILS_DIR}/")


def generate_docs(demos: list[dict]) -> None:
    groups: OrderedDict[str, list[dict]] = OrderedDict()
    for d in demos:
        g = d.get("group") or "Ungrouped"
        groups.setdefault(g, []).append(d)

    lines = ["# Demos", ""]
    lines.append(f"*{len(demos)} demos — generated from [`demos.yaml`](demos.yaml)*")
    lines.append("")

    for group, group_demos in groups.items():
        lines.append(f"## {group}")
        lines.append("")
        for d in group_demos:
            lines.append(f'### {d["name"]}')
            lines.append("")
            if d.get("screenshot"):
                lines.append(f'![{d["name"]}](screenshots/{d["screenshot"]})')
                lines.append("")
            lines.append(f'> {d["description"]}')
            lines.append("")
            long = d.get("long_description")
            if long and long.strip():
                lines.append(long.strip())
                lines.append("")
            tags = list(d.get("keywords", []))
            if d.get("platform"):
                tags.append(d["platform"])
            if tags:
                lines.append("**Tags:** " + "  ".join(f"`{t}`" for t in tags))
                lines.append("")
            lines.append("---")
            lines.append("")

    OUTPUT_MD.write_text("\n".join(lines))
    print(f"Generated {OUTPUT_MD} ({len(demos)} demos)")


def generate_readme(demos: list[dict]) -> None:
    """Regenerate the demo section of README.md between BEGIN/END markers."""
    # Preserve YAML group order; drop Empty placeholder.
    groups: OrderedDict[str, list[dict]] = OrderedDict()
    for d in demos:
        if d.get("name") == "Empty":
            continue
        g = d.get("group") or "Other"
        groups.setdefault(g, []).append(d)

    lines: list[str] = ["## Examples", ""]
    for group, group_demos in groups.items():
        lines.append(f"### {group}")
        lines.append("")
        lines.append("| Example | Description | Screenshot |")
        lines.append("|---------|-------------|------------|")
        for d in group_demos:
            name = d["name"]
            if d.get("platform"):
                name = f"{name} *({d['platform']} only)*"
            desc = (d.get("description") or "").strip()
            file_id = d["id"]
            shot = d.get("screenshot")
            if shot:
                full = f"Documentation/screenshots/{shot}"
                thumb = f"Documentation/screenshots/thumbnails/{file_id}.png"
                cell = f'[<img src="{thumb}" width="320" alt="{name}">]({full})'
            else:
                cell = "—"
            lines.append(f"| **{name}** | {desc} | {cell} |")
        lines.append("")

    new_block = "\n".join(lines).rstrip() + "\n"

    existing = README_MD.read_text() if README_MD.exists() else ""
    if README_BEGIN_MARKER in existing and README_END_MARKER in existing:
        before, rest = existing.split(README_BEGIN_MARKER, 1)
        _, after = rest.split(README_END_MARKER, 1)
        updated = (
            before
            + README_BEGIN_MARKER
            + "\n"
            + new_block
            + README_END_MARKER
            + after
        )
    else:
        # No markers yet — append a fresh block at the end.
        sep = "" if existing.endswith("\n") or not existing else "\n"
        updated = (
            existing
            + sep
            + "\n"
            + README_BEGIN_MARKER
            + "\n"
            + new_block
            + README_END_MARKER
            + "\n"
        )

    README_MD.write_text(updated)
    print(f"Updated {README_MD.relative_to(REPO_ROOT)} ({sum(len(v) for v in groups.values())} demos)")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate screenshots and docs from demos.yaml")
    parser.add_argument("--screenshots", action="store_true", help="Capture screenshots")
    parser.add_argument("--docs", action="store_true", help="Generate DEMOS.md")
    parser.add_argument("--readme", action="store_true", help="Regenerate the demo tables in README.md")
    parser.add_argument("--all", action="store_true", help="Screenshots, docs, and readme")
    parser.add_argument("--settle-time", type=float, default=3.0, help="Settle time in seconds (default: 3)")
    parser.add_argument("--demo", type=str, default=None, help="Capture a single demo by name")
    parser.add_argument("--window-size", type=str, default="1024x768", help="Window size WxH (default: 1024x768)")
    args = parser.parse_args()

    if not any([args.screenshots, args.docs, args.readme, args.all]):
        args.all = True

    w, h = (int(x) for x in args.window_size.split("x"))

    with open(YAML_PATH) as f:
        data = yaml.safe_load(f)
    demos = data["demos"]

    if args.all or args.screenshots:
        capture_screenshots(demos, args.settle_time, (w, h), args.demo)

    if args.all or args.docs:
        generate_docs(demos)

    if args.all or args.readme:
        generate_readme(demos)


if __name__ == "__main__":
    main()
