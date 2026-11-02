class_name NovaWake
extends Node3D
## The Wake variant's lingering field: marks every living enemy inside once per second.

var _r := 4.6
var _life := 3.0
var _tick := 0.0


func setup(radius: float, life: float) -> void:
	_r = radius
	_life = life
	SpellFx.disc(global_position, radius, 0, SpellFx.VIOLET * 0.7, SpellFx.VIOLET_HOT * 0.6, life)


func _physics_process(delta: float) -> void:
	_life -= delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = 1.0
		for node in get_tree().get_nodes_in_group(Groups.ENEMY):
			var e := node as Enemy
			if e == null or not e.is_alive():
				continue
			var d := e.global_position - global_position
			if Vector2(d.x, d.z).length() <= _r and absf(d.y) < 2.5:
				e.add_mark(1)
	if _life <= 0.0:
		queue_free()
