extends Node3D
## The rift's breath (no class_name; site_breath.gd builds it): a fissure on the rim that breathes
## out every PERIOD seconds. A second before, its crack brightens and the ground rumbles; then for
## EXHALE seconds hot air roars up in a column of embers. Anyone in the column off the ground (who
## jumped into it) is carried up to `top_y` + a little and can drift off onto the hermit's perch.
## Standing in it does nothing: you have to jump. Cheap: one timer, one distance test.

const Kit := preload("res://core/life/secrets/kit.gd")
const Beam := preload("res://core/life/secrets/beam.gd")
const PERIOD := 9.0
const WARN := 1.2
const EXHALE := 2.2
const RADIUS := 1.15
const LIFT := 9.5

var top_y := 6.0                 ## world y the column carries you to (the perch floor)
var _t := 0.0
var _fx_t := 0.0
var _crack: MeshInstance3D
var _light: OmniLight3D
var _column: Node3D
var _phase := 0                  ## 0 quiet, 1 warning, 2 exhaling


func _ready() -> void:
	_t = fmod(float(Time.get_ticks_msec()) * 0.001, PERIOD)
	_crack = get_node_or_null("Crack") as MeshInstance3D
	_light = Kit.omni(self, global_position + Vector3.UP * 0.6, Color(1.0, 0.45, 0.15), 0.4, 6.0)
	_light.name = "VentLight"
	_column = Node3D.new()
	_column.name = "Column"
	add_child(_column)
	for k in 3:
		var a := TAU * float(k) / 3.0
		var o := Vector3(cos(a), 0, sin(a)) * 0.35
		Beam.segment(_column, global_position + o, global_position + o + Vector3.UP * (top_y - global_position.y + 2.0), 0.9)
	_column.visible = false


## Is the rift breathing out right now (tests).
func breathing() -> bool:
	return _phase == 2


func _physics_process(delta: float) -> void:
	_t = fmod(_t + delta, PERIOD)
	var ph := 0
	if _t >= PERIOD - EXHALE:
		ph = 2
	elif _t >= PERIOD - EXHALE - WARN:
		ph = 1
	if ph != _phase:
		_phase = ph
		_on_phase()
	if _phase == 1:
		var u := (_t - (PERIOD - EXHALE - WARN)) / WARN
		_light.light_energy = lerpf(0.4, 1.6, u)
	elif _phase == 2:
		var u2 := (_t - (PERIOD - EXHALE)) / EXHALE
		_light.light_energy = lerpf(2.4, 0.4, u2 * u2)
		_fx_t -= delta
		if _fx_t <= 0.0:
			_fx_t = 0.12
			Vfx.burst(global_position + Vector3.UP * 0.2, Color(1.5, 0.6, 0.2), {"count": 10, "life": 1.1, "speed": Vector2(5.0, 9.0), "size": 0.05,
				"dir": Vector3.UP, "spread": 12.0, "gravity": 0.0, "radius": 0.5, "trail": 0.08})
		_lift()


func _on_phase() -> void:
	match _phase:
		1:
			Kit.play("hum", global_position, -6.0, 0.45)
		2:
			Kit.play("breath", global_position, 2.0)
			_column.visible = true
			Vfx.burst(global_position + Vector3.UP * 0.3, Color(0.25, 0.22, 0.22, 0.6), {"count": 30, "life": 1.8, "speed": Vector2(2.0, 5.0), "size": 0.35,
				"dir": Vector3.UP, "spread": 25.0, "gravity": -0.5, "radius": 0.6, "additive": false, "turbulence": true})
		0:
			_column.visible = false
			_light.light_energy = 0.4


func _lift() -> void:
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as CharacterBody3D
	if p == null:
		return
	var at := p.global_position
	if Vector2(at.x - global_position.x, at.z - global_position.z).length() > RADIUS:
		return
	if at.y < global_position.y - 0.5 or at.y > top_y + 1.6 or p.is_on_floor():
		return
	var want := LIFT * clampf((top_y + 1.6 - at.y) / 1.2, 0.25, 1.0)
	if p.velocity.y < want:
		p.velocity.y = want
