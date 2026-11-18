#!/usr/bin/env bash
# Runs the r39 map-audit capture harness (zz/map_audit_shots.tscn) windowed, under the machine's one-Godot lock
# (/tmp/umbral_godot.lock: retried every 30 s while another run holds it, released on exit, also on failure), with a
# watchdog, an isolated HOME (its own warm Realm cache) and a scratch save folder (the real save is never touched).
#
#   tools/map_audit.sh --section=grid --rows=0-6
#   tools/map_audit.sh --section=places --part=0/3
#   tools/map_audit.sh --section=interiors
#   OUT=/some/dir TIMEOUT=2400 tools/map_audit.sh --section=spots --spot=henge_gate:-38,-11,14
# Output: $OUT/<region>/<spot>.jpg (contact sheets), $OUT/<region>/full/*.jpg (frames), $OUT/index_*.md, $OUT/logs/.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$(command -v godot || echo /opt/homebrew/bin/godot)}"
SCRATCH="/private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad"
OUT="${OUT:-$SCRATCH/map_audit}"
TIMEOUT="${TIMEOUT:-2400}"
LOCK=/tmp/umbral_godot.lock
AHOME="${AHOME:-$SCRATCH/map_audit_home}"
mkdir -p "$OUT/logs" "$AHOME"
tag="$(echo "$*" | tr -c 'a-zA-Z0-9_' '_' | cut -c1-80)"
LOG="$OUT/logs/run_${tag}_$(date +%H%M%S).log"

until mkdir "$LOCK" 2>/dev/null; do sleep 30; done
SAVES="$(mktemp -d "${TMPDIR:-/tmp}/map_audit_saves.XXXXXX")"
cleanup() { rm -rf "$SAVES"; rmdir "$LOCK" 2>/dev/null; }
trap cleanup EXIT INT TERM

HL=()
[ "${HEADLESS:-0}" = "1" ] && HL=(--headless)
HOME="$AHOME" UMBRAL_SAVE_DIR="$SAVES" "$GODOT" ${HL[@]+"${HL[@]}"} --path "$ROOT" "${SCENE:-res://zz/map_audit_shots.tscn}" -- "--out=$OUT" "$@" > "$LOG" 2>&1 &
pid=$!
( sleep "$TIMEOUT"; kill -9 "$pid" 2>/dev/null ) >/dev/null 2>&1 &
wd=$!
wait "$pid" 2>/dev/null
rc=$?
pkill -P "$wd" 2>/dev/null
kill "$wd" 2>/dev/null
wait "$wd" 2>/dev/null
echo "exit $rc  log $LOG"
grep -E "MAPAUDIT (realm|section|done|quit|never)" "$LOG"
echo "script errors: $(grep -cE 'SCRIPT ERROR|Parse Error|Failed to load script' "$LOG")"
grep -E "SCRIPT ERROR|Parse Error" -A2 "$LOG" | head -20
exit 0
