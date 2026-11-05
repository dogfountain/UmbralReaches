extends Node3D
## r36 Rift Step · Mist (the Fog-Shepherd's Crook): the place the wanderer stepped from fogs over
## for `life` seconds; foes standing in it are slowed by half. A few smoke cards and a low ring;
## it ticks four times a second and frees itself.

const Afflict := preload("res://core/skills/afflict.gd")
const SLOW := 0.5

var radius := 3.0
var life := 3.0
var _t := 0.0
var _tick := 0.0
var _smoke: GPUParticles3D


func _ready() -> void:
	_smoke = Vfx.emitter(Color(0.62, 0.68, 0.78, 0.55), {"count": 18, "life": 1.6, "speed": Vector2(0.1, 0.4), "size": 0.9,
		"gravity": -0.05, "radius": radius * 0.8, "damping": 1.5, "additive": false, "dir": Vector3.UP, "spread": 80.0})
	if _smoke:
		add_child(_smoke)
		_smoke.position = Vector3.UP * 0.4
		_smoke.emitting = true
	Vfx.ring(global_position + Vector3.UP * 0.05, radius, Color(0.9, 1.0, 1.4), 0.5, 0.05, Vector3.UP, 1.0)


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= life:
		if _smoke:
			_smoke.emitting = false
		if _t >= life + 1.6:
			queue_free()
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Node3D
		if e == null:
			continue
		var d := e.global_position - global_position
		if Vector2(d.x, d.z).length() <= radius and absf(d.y) < 2.5:
			Afflict.slow(e, SLOW, 0.4)
