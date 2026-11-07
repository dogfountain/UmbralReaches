#!/usr/bin/env bash
# Renders and assembles the action trailer (zz/trailer.gd, cast in zz/trailer_shots_act*.gd).
#
#   tools/trailer.sh list                      # the cut: id, seconds, act
#   tools/trailer.sh render [id ...]           # Movie Maker, windowed: contiguous shots rendered in groups of $GROUP
#                                              #   (default: every shot in the cut); clips + logs land in $OUT/clips
#   tools/trailer.sh cut [id ...]              # trims each rendered shot out of its group clip -> $OUT/shots/<id>.mp4
#   tools/trailer.sh assemble                  # joins the shots in cut order -> $OUT/umbral_trailer.mp4 (H.264 yuv420p AAC)
#   tools/trailer.sh preview id[,id...]        # a quick 960x540 30 fps render of just those shots (prints the clip path)
#
# Env: OUT (default scratch dir), RES (1920x1080), FPS (60), GROUP (6 shots per process), TIMEOUT (900 s per
# process; a watchdog kills only the PID this script started), GODOT, FFMPEG. Saves are held (Travel._busy) and the
# user:// folder is a scratch HOME. Never commit the video: $OUT is outside the project.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$(command -v godot || echo /opt/homebrew/bin/godot)}"
FFMPEG="${FFMPEG:-/opt/homebrew/bin/ffmpeg}"
OUT="${OUT:-/private/tmp/claude-501/-Users-luke-UmbralReaches/968888c4-6238-49b1-a0f8-2ba292b49c0a/scratchpad/trailer}"
RES="${RES:-1920x1080}"
FPS="${FPS:-60}"
GROUP="${GROUP:-6}"
TIMEOUT="${TIMEOUT:-900}"
HOMEDIR="$OUT/home"
mkdir -p "$OUT/clips" "$OUT/shots" "$HOMEDIR"

cut_ids() {   # ids of the cut, in order
	HOME="$HOMEDIR" "$GODOT" --headless --path "$ROOT" res://zz/trailer.tscn -- --list 2>/dev/null | awk '/^SHOT /{print $2}'
}

cmd_list() {
	HOME="$HOMEDIR" "$GODOT" --headless --path "$ROOT" res://zz/trailer.tscn -- --list 2>/dev/null | grep '^SHOT '
}

render_group() {   # name res fps shots-csv [extra flag]
	local name="$1" res="$2" fps="$3" shots="$4" extra="${5:-}"
	echo "== render $name: $shots ($res @ $fps)"
	HOME="$HOMEDIR" UMBRAL_SAVE_DIR="$HOMEDIR/save" "$GODOT" --path "$ROOT" --write-movie "$OUT/clips/$name.avi" \
		--fixed-fps "$fps" --resolution "$res" res://zz/trailer.tscn -- "--shots=$shots" $extra > "$OUT/clips/$name.log" 2>&1 &
	local pid=$!
	( sleep "$TIMEOUT"; kill -9 "$pid" 2>/dev/null ) >/dev/null 2>&1 &
	local wd=$!
	wait "$pid" 2>/dev/null
	kill "$wd" 2>/dev/null
	grep -E "SCRIPT ERROR|Parse Error|TRAILER no |solve_cam: no" "$OUT/clips/$name.log" | sort | uniq -c | head -10
}

cmd_render() {
	local ids=("$@")
	[ ${#ids[@]} -eq 0 ] && ids=($(cut_ids))
	local i=0 n=${#ids[@]}
	while [ $i -lt $n ]; do
		local g=("${ids[@]:$i:$GROUP}")
		local csv
		csv="$(IFS=,; echo "${g[*]}")"
		local extra=""
		[ "$RES" != "1920x1080" ] && extra="--preview"
		render_group "${g[0]}" "$RES" "$FPS" "$csv" "$extra"
		i=$((i + GROUP))
	done
}

cmd_preview() {
	local first="${1%%,*}"
	render_group "preview_$first" 960x540 30 "$1" --preview
	echo "$OUT/clips/preview_$first.avi"
}

# one trimmed shot per `CLIP id start= drawn= dur=` line in every group log (movie frame = drawn + 1)
cmd_cut() {
	local want=" $* "
	for log in "$OUT"/clips/*.log; do
		local base="${log%.log}"
		[ -f "$base.avi" ] || continue
		case "$base" in */preview_*) continue ;; esac
		local fps="$FPS"
		grep -E '^CLIP ' "$log" | while read -r _ id _ drawn dur; do
			drawn="${drawn#drawn=}"; dur="${dur#dur=}"
			[ $# -gt 0 ] && [[ "$want" != *" $id "* ]] && continue
			local start
			start=$(awk -v d="$drawn" -v f="$fps" 'BEGIN{printf "%.4f", (d+1)/f}')
			"$FFMPEG" -loglevel error -y -ss "$start" -i "$base.avi" -t "$dur" \
				-c:v libx264 -preset fast -crf 14 -pix_fmt yuv420p -r "$fps" -c:a aac -b:a 192k -ar 48000 "$OUT/shots/$id.mp4"
			echo "cut $id"
		done
	done
}

cmd_assemble() {
	local list="$OUT/concat.txt"
	: > "$list"
	for id in $(cut_ids); do
		[ -f "$OUT/shots/$id.mp4" ] && echo "file 'shots/$id.mp4'" >> "$list"
	done
	[ -s "$list" ] || { echo "no shots cut yet"; exit 1; }
	( cd "$OUT" && "$FFMPEG" -loglevel error -y -f concat -safe 0 -i concat.txt \
		-vf "eq=contrast=1.04:saturation=1.06,format=yuv420p" -c:v libx264 -preset slow -crf 17 -r "$FPS" \
		-c:a aac -b:a 192k -movflags +faststart umbral_trailer.mp4 )
	echo "$OUT/umbral_trailer.mp4"
}

case "${1:-list}" in
	list) cmd_list ;;
	render) shift; cmd_render "$@" ;;
	preview) shift; cmd_preview "$1" ;;
	cut) shift; cmd_cut "$@" ;;
	assemble) cmd_assemble ;;
	*) sed -n 2,14p "$0" ;;
esac
