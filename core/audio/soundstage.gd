extends Node
## The sound rework's root (one child of Ambience, built after the boss themes). It assembles and owns:
##   CueBank        every added one-shot, rendered on a worker thread (cue_bank.gd)
##   MixDirector    the UI and Score buses, glue compressors, named ducks (mix_director.gd)
##   ScoreDirector  the dynamic score: tension, combat, aftermath, the acts' beds, motifs, silence (score_director.gd)
##   CueRouter      the game's events turned into cues: blows, casts, fires, bosses, the eclipse, moths, fog, camp (cue_router.gd)
## and the night's hours: once a second the beds' multipliers (Ambience.hour_mul) follow the night clock and the eclipse, so the
## insects thin out as it gets cold and late, the wind rises, a dawn chorus comes up in the last tenth, and the totality hushes
## the small life. `eclipse_amount()` is the one reading of the eclipse every sound uses. No class_name.

const CueBank := preload("res://core/audio/cue_bank.gd")
const Reg := preload("res://core/world/night_life/night_registry.gd")
const MoonCourse := preload("res://core/world/night_life/moon_course.gd")

var ambience: Ambience
var eclipse := 0.0
var _t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "Soundstage"
	CueBank.warm()
	for path: String in ["res://core/audio/mix_director.gd", "res://core/audio/score_director.gd", "res://core/audio/cue_router.gd", "res://core/audio/landmark_voices.gd"]:
		var n: Node = (load(path) as GDScript).new()
		n.set("ambience", ambience)
		n.set("stage", self)
		add_child(n)


func _exit_tree() -> void:
	CueBank.release()


## 0 (no eclipse) .. 1 (totality): the same curve the moon follows (night_life/moon_course.gd), read from the night clock.
static func eclipse_amount(c: float) -> float:
	if MoonCourse.eclipse_done or not Reg.enabled:
		return 0.0
	var a := MoonCourse.ECLIPSE_AT - MoonCourse.APPROACH
	var z := MoonCourse.ECLIPSE_AT + MoonCourse.TOTAL + MoonCourse.RETURN
	if c < a or c >= z:
		return 0.0
	if c < MoonCourse.ECLIPSE_AT:
		return smoothstep(a, MoonCourse.ECLIPSE_AT, c) * 0.55
	if c < MoonCourse.ECLIPSE_AT + MoonCourse.TOTAL:
		return lerpf(0.55, 1.0, smoothstep(MoonCourse.ECLIPSE_AT, MoonCourse.ECLIPSE_AT + 0.004, c))
	return 1.0 - smoothstep(MoonCourse.ECLIPSE_AT + MoonCourse.TOTAL, z, c)


func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0 or ambience == null:
		return
	_t = 1.0
	var c := Reg.clock
	eclipse = eclipse_amount(c)
	var late := smoothstep(0.5, 0.85, c)
	var dawn := smoothstep(0.9, 1.0, c)
	var e := eclipse
	ambience.hour_mul = {
		"crickets": (1.0 - 0.55 * late + 0.35 * dawn) * (1.0 - 0.85 * e),
		"meadow": (1.0 + 0.9 * dawn) * (1.0 - 0.7 * e),
		"leaves": (1.0 + 0.2 * late) * (1.0 - 0.4 * e),
		"high_wind": 1.0 + 0.5 * late,
		"night": 1.0 + 0.1 * late,
		"murmur": 1.0 - 0.5 * e,
		"fen": 1.0 - 0.3 * e,
	}
