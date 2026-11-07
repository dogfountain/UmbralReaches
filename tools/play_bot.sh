#!/usr/bin/env bash
# Runs the play bot (zz/play_bot.tscn): a NEW game played through Input actions only (see zz/play_bot.gd), in a
# fresh save dir, with a hard watchdog. Folds the engine's own errors into <out>/errors.txt.
#
#   tools/play_bot.sh                       # windowed: the title screen, New Game, then ~60 min of game time
#   HEADLESS=1 tools/play_bot.sh            # no window, no images (the clean check)
#   MINUTES=20 SCALE=4 WALL=900 OUT=/some/dir tools/play_bot.sh
#   EXTRA=--mouse tools/play_bot.sh         # windowed with a captured mouse (default windowed: the look stick, mouse stays free)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$(command -v godot || echo /opt/homebrew/bin/godot)}"
OUT="${OUT:-/private/tmp/claude-501/-Users-luke-UmbralReaches/968888c4-6238-49b1-a0f8-2ba292b49c0a/scratchpad/wave4/playbot}"
MINUTES="${MINUTES:-60}"
SCALE="${SCALE:-3}"
WALL="${WALL:-1700}"
HEADLESS="${HEADLESS:-0}"
mkdir -p "$OUT"
SAVES="$(mktemp -d "${TMPDIR:-/tmp}/play_bot_saves.XXXXXX")"
trap 'rm -rf "$SAVES"' EXIT
LOG="$OUT/run.log"
args=(--path "$ROOT")
[ "$HEADLESS" = "1" ] && args+=(--headless)
args+=(res://zz/play_bot.tscn -- "--out=$OUT" "--minutes=$MINUTES" "--scale=$SCALE" "--wall=$WALL" ${EXTRA:-})
rm -f "$OUT"/*.png
UMBRAL_SAVE_DIR="$SAVES" "$GODOT" "${args[@]}" > "$LOG" 2>&1 &
pid=$!
# outer watchdog: catches a hung engine (only kills the pid we started)
( sleep $((WALL + 150)); kill -9 "$pid" 2>/dev/null ) >/dev/null 2>&1 &
wd=$!
wait "$pid" 2>/dev/null
rc=$?
pkill -P "$wd" 2>/dev/null
kill "$wd" 2>/dev/null
wait "$wd" 2>/dev/null
{
	echo "# engine log lines (run.log), exit code $rc"
	grep -E "SCRIPT ERROR|Parse Error|Failed to load script|^ERROR:|^WARNING:|USER ERROR|USER WARNING" "$LOG" \
		| sed -E 's/[0-9]+(\.[0-9]+)?/N/g' | sort | uniq -c | sort -rn | head -60
} > "$OUT/errors.txt"
nerr=$(grep -cE "SCRIPT ERROR|Parse Error|Failed to load script" "$LOG")
echo "play bot exit $rc, script errors: $nerr, images: $(ls "$OUT" | grep -c '\.png$'), see $OUT/summary.txt"
exit 0
