#!/usr/bin/env bash
# Build the browser version for Cloudflare (GitHub Actions deploy-website.yml,
# or a Workers Builds dashboard command).
#
# The build machine has Python and curl but no Godot, so this fetches the
# editor first. tools/export_game.py downloads whatever export templates it is
# missing by itself, fetching only the files the web build needs.
#
# Runs on Linux.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

GODOT_VERSION="4.6.3-stable"  # keep in step with the editor used to make the game
GODOT_DIR="${TMPDIR:-/tmp}/godot-${GODOT_VERSION}"
GODOT_BIN="$GODOT_DIR/Godot_v${GODOT_VERSION}_linux.x86_64"

if [ ! -x "$GODOT_BIN" ]; then
  echo "Downloading Godot ${GODOT_VERSION}..."
  mkdir -p "$GODOT_DIR"
  curl -fsSL -o "$GODOT_DIR/godot.zip" \
    "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
  unzip -q -o "$GODOT_DIR/godot.zip" -d "$GODOT_DIR"
fi

export GODOT="$GODOT_BIN"
python3 tools/deploy_web.py --build
