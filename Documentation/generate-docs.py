#!/usr/bin/env python3
"""Generate screenshots and DEMOS.md from demos.yaml.

Usage:
    uv run --with pyyaml Documentation/generate-docs.py [--screenshots] [--docs] [--all]
    uv run --with pyyaml Documentation/generate-docs.py --screenshots --settle-time 5
    uv run --with pyyaml Documentation/generate-docs.py --screenshots --demo Triangle

Options:
    --screenshots       Capture screenshots (requires app running + steveo)
    --docs              Generate DEMOS.md from demos.yaml
    --all               Both screenshots and docs (default if no flags given)
    --settle-time SECS  Seconds to wait after navigating before capturing (default: 3)
    --demo NAME         Only capture a single demo by name
    --window-size WxH   Window size (default: 1024x768)
"""

import json
import subprocess
import time
import yaml
from collections import OrderedDict
from pathlib import Path
import argparse
import sys

SCRIPT_DIR = Path(__file__).parent
YAML_PATH = SCRIPT_DIR / "demos.yaml"
OUTPUT_MD = SCRIPT_DIR / "DEMOS.md"
SCREENSHOTS_DIR = SCRIPT_DIR / "screenshots"
APP_NAME = "MetalSprockets-Examples"


def steveo(*args: str) -> dict | None:
    result = subprocess.run(
        ["steveo", "--app", APP_NAME, *args],
        capture_output=True,
        text=True,
    )
    try:
        return json.loads(result.stdout.strip())
    except (json.JSONDecodeError, ValueError):
        return None


def capture_screenshots(demos: list[dict], settle_time: float, window_size: tuple[int, int], single_demo: str | None) -> None:
    SCREENSHOTS_DIR.mkdir(parents=True, exist_ok=True)

    # Check app is running
    result = steveo("windows", "--quiet")
    if not result or not result.get("ok"):
        print(f"Error: {APP_NAME} is not running. Launch it first.", file=sys.stderr)
        sys.exit(1)

    win_url = result["data"][0]["url"]
    w, h = window_size

    # Resize window
    print(f"Resizing window to {w}x{h}...")
    steveo("window", "resize", win_url, str(w), str(h))

    # Hide sidebar if showing
    result = steveo("find", "--text", "Hide Sidebar")
    if result and result.get("ok"):
        steveo("find", "--text", "Hide Sidebar", "--click")
        time.sleep(0.3)

    # Filter demos if single demo requested
    if single_demo:
        demos = [d for d in demos if d["name"] == single_demo]
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
        num = i + 1
        print(f"[{num:2d}/{total}] {name:30s} ", end="", flush=True)

        result = steveo("menu", "Demos", name)
        if not result or not result.get("ok"):
            print("SKIP (menu failed)")
            failed += 1
            continue

        time.sleep(settle_time)

        outpath = str(SCREENSHOTS_DIR / f"{file_id}.png")
        result = steveo("screenshot", "-o", outpath)
        if result and result.get("ok"):
            print("✓")
            captured += 1
        else:
            print("✗ screenshot failed")
            failed += 1

    print()
    print(f"Done: {captured} captured, {failed} failed out of {total} demos.")
    print(f"Screenshots saved to: {SCREENSHOTS_DIR}/")


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


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate screenshots and docs from demos.yaml")
    parser.add_argument("--screenshots", action="store_true", help="Capture screenshots")
    parser.add_argument("--docs", action="store_true", help="Generate DEMOS.md")
    parser.add_argument("--all", action="store_true", help="Both screenshots and docs")
    parser.add_argument("--settle-time", type=float, default=3.0, help="Settle time in seconds (default: 3)")
    parser.add_argument("--demo", type=str, default=None, help="Capture a single demo by name")
    parser.add_argument("--window-size", type=str, default="1024x768", help="Window size WxH (default: 1024x768)")
    args = parser.parse_args()

    if not args.screenshots and not args.docs and not args.all:
        args.all = True

    w, h = (int(x) for x in args.window_size.split("x"))

    with open(YAML_PATH) as f:
        data = yaml.safe_load(f)
    demos = data["demos"]

    if args.all or args.screenshots:
        capture_screenshots(demos, args.settle_time, (w, h), args.demo)

    if args.all or args.docs:
        generate_docs(demos)


if __name__ == "__main__":
    main()
