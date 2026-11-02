#!/bin/zsh
# Stair of Ascension deepdive video for issue triage.
#   tools/deepdive_walkthrough.sh
# Writes:
#   ~/Downloads/umbral_deepdive_stair.mp4
#   ~/Downloads/umbral_deepdive_walkthrough_script.md
set -euo pipefail
setopt NULL_GLOB
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_ROOT="${1:-/tmp/umbral_deepdive}"
STAIR_DIR="$OUT_ROOT/stair"
rm -rf "$OUT_ROOT"
mkdir -p "$STAIR_DIR"

cp "$ROOT/tools/deepdive_walkthrough_script.md" "$HOME/Downloads/umbral_deepdive_walkthrough_script.md"

echo "=== STAIR demo deepdive ==="
T0=$(python3 -c 'import time; print(int(time.time()*1000))')
godot --path "$ROOT" --rendering-driver vulkan \
  -- --deepdive-rec="$STAIR_DIR" --deepdive-hz=12 --demo --quit-after-demo
ffmpeg -y -hide_banner -loglevel error -framerate 12 -i "$STAIR_DIR/frame_%05d.jpg" \
  -c:v libx264 -pix_fmt yuv420p -preset veryfast -crf 20 \
  "$HOME/Downloads/umbral_deepdive_stair.mp4"
T1=$(python3 -c 'import time; print(int(time.time()*1000))')
echo "→ ~/Downloads/umbral_deepdive_stair.mp4  ($((T1-T0))ms)  frames=$(ls "$STAIR_DIR"/frame_*.jpg 2>/dev/null | wc -l)"
echo "→ ~/Downloads/umbral_deepdive_walkthrough_script.md"
echo "done"
