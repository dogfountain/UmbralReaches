extends Node
## A KINDLED FIRE CALLS. When the wanderer kindles a brazier (Events.brazier_kindled) the fire does not just
## switch on: a wide ring of heat runs out over the ground, embers burst upward, a flash lights the place for a moment, and
## the fire's far card surges to twice its brightness and settles over six seconds, so anyone on a far hill sees
## it catch. Every other unkindled brazier within 180 m glints brighter for twenty seconds: one flame wakes the cold
## ones, and the next fire to light is the one the eye is drawn to. Rows are the night registry's (`boost`); the effect
## nodes are the shared Vfx pools.

const Reg := preload("res://core/world/night_life/night_registry.gd")
const Access := preload("res://ui/access.gd")
const NightFx := preload("res://core/world/night_life/night_fx.gd")

const CALL_RANGE := 180.0

var _decay := 0.0


func _ready() -> void:
	Events.brazier_kindled.connect(_on_kindled)


func _on_kindled(b: Node3D) -> void:
	if not Reg.enabled or b == null or not b.is_inside_tree():
		return
	var p := b.global_position
	Vfx.ring(p, 14.0, Color(2.2, 1.0, 0.35), 1.1, 0.14, Vector3.UP, Access.flash())
	Vfx.ring(p, 7.0, Color(2.0, 1.4, 0.7), 0.7, 0.1, Vector3.UP, Access.flash())
	NightFx.burst(p + Vector3(0.0, 1.4, 0.0), Color(2.2, 1.0, 0.3), "kindle", Vector3.UP)
	Vfx.light(p + Vector3(0.0, 1.8, 0.0), Color(1.0, 0.65, 0.3), 4.0, 14.0, 1.2, 2)
	var key := "br_%s_%d" % [b.name, hash(b.get_path())]
	var row: int = Reg.keys.get(key, -1)
	if row >= 0:
		Reg.boost[row] = 1.0
	for i in Reg.size():
		if int(Reg.kind[i]) == Reg.Kind.COLD and Reg.on[i] == 1 and i != row and p.distance_to(Reg.pos[i]) < CALL_RANGE:
			Reg.boost[i] = maxf(Reg.boost[i], 0.9)


func _process(delta: float) -> void:
	_decay += delta
	if _decay < 0.1:
		return
	var dt := _decay
	_decay = 0.0
	for i in Reg.boost.size():
		var v := Reg.boost[i]
		if v > 0.0:
			Reg.boost[i] = maxf(0.0, v - dt * (0.17 if int(Reg.kind[i]) == Reg.Kind.FIRE else 0.045))
