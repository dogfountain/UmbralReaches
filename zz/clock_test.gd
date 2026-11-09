extends Node
## The dark's clock in a boss fight: a thin gather, never a pause, and still slower than the open.
##   godot --headless --path . res://zz/clock_test.tscn

var bad := 0


func _ready() -> void:
	var open := Player.place_gather(0.75, false, false)
	var fight := Player.place_gather(0.75, true, false)
	var sprint := Player.place_gather(0.75, true, true)
	var rift := Player.place_gather(1.25, true, false)
	_ok(is_equal_approx(open, 0.75), "open dark is the place rate")
	_ok(fight > 0.1, "a boss fight still gathers")
	_ok(is_equal_approx(fight, 0.75 * Player.FIGHT_GATHER), "the fight keeps FIGHT_GATHER of the place")
	_ok(fight * 3.0 < open, "open dark is more than three times a fight")
	_ok(is_equal_approx(sprint, fight * Player.SPRINT_DARK_MULT), "sprinting in a fight still multiplies")
	_ok(sprint < open, "a sprinting fight stays under the open dark")
	_ok(rift > fight, "the rift stays the faster place, even in a fight")
	print("clock_test: ", "FAIL %d" % bad if bad > 0 else "PASS")
	get_tree().quit(1 if bad > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	if cond:
		return
	bad += 1
	push_error("clock: " + what)
