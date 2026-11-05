extends Node
## Rift Tether's haul (r28): carries a hooked foe along a low arc to `land` over `time` seconds,
## kinematically (its own physics is held for the flight, then given back), so slopes, steps and
## its own AI can't cut the pull short. A lit zone is a sanctuary (Enemy._light_barrier): the haul
## stops at its edge. `done` is called when the foe lands (not if it dies on the way).

const ARC := 1.1

var foe: Node3D
var from := Vector3.ZERO
var land := Vector3.ZERO
var time := 0.4
var done: Callable
var _t := 0.0
var _was_physics := true


static func start(e: Node3D, to: Vector3, t: float, on_land: Callable) -> void:
	var d := new()
	d.name = "TetherDrag"
	d.foe = e
	d.from = e.global_position
	d.land = to
	d.time = t
	d.done = on_land
	d._was_physics = e.is_physics_processing()
	if e.has_method("hauled"):
		e.call("hauled")                         # its tell or charge is broken by the haul
	e.set_physics_process(false)
	e.add_child(d)


func _physics_process(delta: float) -> void:
	if foe == null or not is_instance_valid(foe) or (foe.has_method("is_alive") and not foe.call("is_alive")):
		_release(false)
		return
	_t += delta
	var u := clampf(_t / time, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - u, 2.0)                         # yanked: fast out of the gate
	var p := from.lerp(land, e) + Vector3.UP * sin(u * PI) * ARC
	if LightGrid.repel(p, 0.6) != Vector3.ZERO:
		_release(true)                                       # the light will not take it
		return
	foe.global_position = p
	if u >= 1.0:
		_release(true)


func _release(landed: bool) -> void:
	if is_instance_valid(foe):
		foe.set_physics_process(_was_physics)
		foe.set("velocity", Vector3.ZERO)
		foe.set("_knock", Vector3.ZERO)
		if foe.has_method("reset_physics_interpolation"):
			foe.reset_physics_interpolation()
	if landed and done.is_valid():
		done.call()
	queue_free()
