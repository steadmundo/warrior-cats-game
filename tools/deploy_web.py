#!/usr/bin/env python3
"""
Build the browser version of the game and publish it to Cloudflare.

Usage:
    python3 tools/deploy_web.py            # build, then deploy the Worker
    python3 tools/deploy_web.py --build    # build only, no deploy
    python3 tools/deploy_web.py --local    # build, then serve on http://localhost:8790

The Worker lives in web/ (wrangler.jsonc + src/index.js). Cloudflare refuses to
store any single static asset bigger than 25 MiB, and Godot's index.wasm is
about 36 MiB, so the build cuts it into parts and web/src/index.js streams them
back to the browser as one ordinary /index.wasm download.

Exit code 0 = deployed (or built), 1 = something failed.
"""

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WEB_EXPORT = ROOT / "game" / "export" / "web"
WEB_PROJECT = ROOT / "web"
SITE_DIR = WEB_PROJECT / "public"

# Cloudflare's limit for one static asset. Over this, the upload is rejected.
ASSET_LIMIT = 25 * 1024 * 1024
# Stay comfortably below the limit so the manifest and headers have room.
PART_SIZE = 20 * 1024 * 1024


def human(size: int) -> str:
    return f"{size / (1024 * 1024):.1f} MiB"


def build() -> bool:
    """Export the web build, then copy it into web/public, splitting the engine."""
    print("Exporting the browser version...")
    result = subprocess.run([sys.executable, str(ROOT / "tools" / "export_game.py"), "web"])
    if result.returncode != 0:
        print("The web export failed, so there is nothing to deploy.", file=sys.stderr)
        return False

    if SITE_DIR.exists():
        shutil.rmtree(SITE_DIR)
    SITE_DIR.mkdir(parents=True)

    for item in WEB_EXPORT.iterdir():
        if item.is_file():
            shutil.copy2(item, SITE_DIR / item.name)

    wasm = SITE_DIR / "index.wasm"
    if not wasm.exists():
        print("The export did not produce index.wasm.", file=sys.stderr)
        return False

    size = wasm.stat().st_size
    if size <= ASSET_LIMIT:
        print(f"  index.wasm is {human(size)}, under Cloudflare's limit as it is.")
        return True

    data = wasm.read_bytes()
    wasm.unlink()
    parts = []
    for number, start in enumerate(range(0, len(data), PART_SIZE)):
        name = f"index.wasm.{number}"
        (SITE_DIR / name).write_bytes(data[start : start + PART_SIZE])
        parts.append(name)
    (SITE_DIR / "index.wasm.json").write_text(json.dumps({"parts": parts}) + "\n")

    print(f"  index.wasm {human(size)} cut into {len(parts)} parts:")
    for name in parts:
        print(f"    {name} {human((SITE_DIR / name).stat().st_size)}")
    return True


def deploy() -> bool:
    print("Deploying to Cloudflare...")
    result = subprocess.run(["wrangler", "deploy"], cwd=WEB_PROJECT)
    return result.returncode == 0


def serve_local() -> bool:
    print("Serving at http://localhost:8790 (CTRL+C to stop)...")
    result = subprocess.run(["wrangler", "dev", "--port", "8790"], cwd=WEB_PROJECT)
    return result.returncode == 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", action="store_true", help="build only, do not deploy")
    parser.add_argument("--local", action="store_true", help="build, then run wrangler dev")
    args = parser.parse_args()

    if not build():
        return 1
    if args.build:
        print(f"Built into {SITE_DIR.relative_to(ROOT)}. Nothing was deployed.")
        return 0
    if args.local:
        return 0 if serve_local() else 1
    return 0 if deploy() else 1


if __name__ == "__main__":
    sys.exit(main())
