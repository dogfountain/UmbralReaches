#!/bin/zsh
# Fast walk debug reel.
#   tools/walk_video.sh           # side+foot (~few sec)
#   tools/walk_video.sh --quick   # foot only
#   tools/walk_video.sh --all
set -euo pipefail
setopt NULL_GLOB
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLAGS=()
OUT="/tmp/walkvid"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --quick|--all) FLAGS+=("$1"); shift ;;
    *) OUT="$1"; shift ;;
  esac
done
rm -rf "$OUT"
mkdir -p "$OUT"
T0=$(python3 -c 'import time; print(int(time.time()*1000))')
godot --path "$ROOT" --rendering-driver vulkan -s res://tools/walk_video.gd -- --out="$OUT" "${FLAGS[@]}"
for tag in side foot ots sprint; do
  frames=("$OUT"/${tag}_*.jpg(N))
  (( ${#frames} )) || continue
  ffmpeg -y -hide_banner -loglevel error -framerate 30 -i "$OUT/${tag}_%04d.jpg" \
    -c:v libx264 -pix_fmt yuv420p -preset ultrafast -crf 26 \
    "$HOME/Downloads/umbral_walk_${tag}.mp4"
  echo "→ ~/Downloads/umbral_walk_${tag}.mp4 (${#frames}f)"
done
T1=$(python3 -c 'import time; print(int(time.time()*1000))')
echo "total $((T1 - T0))ms"
