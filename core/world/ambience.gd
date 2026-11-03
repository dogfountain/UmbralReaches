class_name Ambience
extends Node
## Background beds on the Ambience bus: the open night by default, and an area's own bed while the
## player is inside it (Area.ambience + Area.ambience_bounds). Equal-power crossfade, ~2 s.

const BEDS := {
	"night": "res://art/audio/amb_night.wav",
	"ossuary": "res://art/audio/amb_ossuary.wav",
}
const FADE := 2.0
const BASE_DB := -6.0

var _players: Dictionary = {}     # key -> AudioStreamPlayer
var _mix: Dictionary = {}         # key -> 0..1
var _want := "night"
var _t := 0.0


func _ready() -> void:
	for key: String in BEDS:
		var s := load(BEDS[key]) as AudioStreamWAV
		if s == null:
			continue
		s = s.duplicate() as AudioStreamWAV
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * float(s.mix_rate))
		var p := AudioStreamPlayer.new()
		p.name = "Bed_" + key
		p.stream = s
		p.bus = &"Ambience"
		p.volume_db = -80.0
		add_child(p)
		p.play(randf() * s.get_length())
		_players[key] = p
		_mix[key] = 0.0


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = 0.5
		_want = _pick()
	for key: String in _players:
		var target := 1.0 if key == _want else 0.0
		_mix[key] = move_toward(float(_mix[key]), target, delta / FADE)
		var g := sin(float(_mix[key]) * PI * 0.5)          # equal-power
		(_players[key] as AudioStreamPlayer).volume_db = BASE_DB + linear_to_db(maxf(g, 0.0001))


func _pick() -> String:
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if p == null:
		return "night"
	for node in get_tree().get_nodes_in_group(&"ambience_area"):
		var a := node as Area
		if a and a.ambience != "" and a.ambience_bounds.has_point(a.to_local(p.global_position)):
			return a.ambience
	return "night"
