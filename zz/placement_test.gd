extends Node
## Skipped placements (core/world/realm/placement_log.gd): after the Realm is built, every skip that is
## not listed in tools/placement_baseline.txt fails. A baseline key that no longer skips is only an info line
## (delete it from the baseline when you fix that spot).
## Run: SCRATCH=<dir> JOBS=1 tools/run_tests.sh placement
const PlacementLog := preload("res://core/world/realm/placement_log.gd")
const BASELINE := "res://tools/placement_baseline.txt"

var main: Node
var t := 0.0
var done := false


func _ready() -> void:
	Travel._busy = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	t += d
	if done:
		return
	if t > 220.0:
		print("PLACEMENT TEST timed out waiting for the Realm")
		done = true
		get_tree().quit(1)
		return
	if main == null or not main.has_meta("realm_done") or t < 4.0:
		return
	done = true
	var base: Array[String] = []
	var f := FileAccess.open(BASELINE, FileAccess.READ)
	if f == null:
		print("PLACEMENT cannot read ", BASELINE)
		get_tree().quit(1)
		return
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line != "":
			base.append(line)
	var now := PlacementLog.keys()
	var fails := 0
	for k: String in now:
		if not base.has(k):
			fails += 1
			print("PLACEMENT FAIL new skip ", k)
	for k: String in base:
		if not now.has(k):
			print("PLACEMENT info no longer skipped ", k)
	print("PLACEMENT %d skips, %d in the baseline" % [now.size(), base.size()])
	if fails == 0:
		print("PLACEMENT TEST PASS")
	else:
		print("PLACEMENT TEST FAIL ", fails)
	get_tree().quit(fails)
