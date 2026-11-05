#!/usr/bin/env bash
# Pack the playable Mac app (the binding route: .cursor/skills/umbral-pack).
# The .app loads a Linux .pck, so this exports the "Linux" preset, never "macOS".
#   tools/pack_mac.sh "/path/to/Umbral Reaches.app"
set -euo pipefail

APP="${1:-}"
if [[ -z "$APP" || ! -d "$APP/Contents/Resources" ]]; then
	echo "usage: tools/pack_mac.sh \"/path/to/Umbral Reaches.app\"" >&2
	exit 2
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-}"
if [[ -z "$GODOT" ]]; then
	if command -v godot >/dev/null 2>&1; then GODOT="godot"
	elif [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then GODOT=/Applications/Godot.app/Contents/MacOS/Godot
	else echo "godot not found (set GODOT=...)" >&2; exit 2; fi
fi
PCK="${TMPDIR:-/tmp}/Umbral Reaches.pck"

cd "$ROOT"
echo "== tests (must end ALL n PASS)"
tools/run_tests.sh
echo "== import"
"$GODOT" --headless --path "$ROOT" --import --quit
echo "== export-pack Linux"
"$GODOT" --headless --path "$ROOT" --export-pack "Linux" "$PCK"
echo "== copy into the app"
cp "$PCK" "$APP/Contents/Resources/Umbral Reaches.pck"
codesign --force --deep --sign - "$APP"
touch "$APP"
echo "== packed at $(date '+%H:%M:%S'); quit and relaunch the app"
shasum -a 256 "$APP/Contents/Resources/Umbral Reaches.pck"
