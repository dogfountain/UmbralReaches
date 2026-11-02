#!/bin/zsh
# Record a short in-game OTS walk from world/main.tscn (real Player cam).
#   tools/ingame_walk.sh [out_dir] [frames]
set -euo pipefail
setopt NULL_GLOB
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-/tmp/ingame_walk}"
FRAMES="${2:-36}"
rm -rf "$OUT"
mkdir -p "$OUT"
T0=$(python3 -c 'import time; print(int(time.time()*1000))')
godot --path "$ROOT" --rendering-driver vulkan \
  -- --walk-rec="$OUT" --walk-frames="$FRAMES"
ffmpeg -y -hide_banner -loglevel error -framerate 30 -i "$OUT/ingame_%04d.jpg" \
  -c:v libx264 -pix_fmt yuv420p -preset ultrafast -crf 23 \
  "$HOME/Downloads/umbral_ingame_walk.mp4"
T1=$(python3 -c 'import time; print(int(time.time()*1000))')
echo "→ ~/Downloads/umbral_ingame_walk.mp4  total $((T1-T0))ms"
