class_name AreaStreamer
extends Node
## Loads areas near the player, frees them far away. An area is a script (an Area subclass)
## or a PackedScene path. Hysteresis (load_r < unload_r) stops a player on the boundary from
## thrashing; `y_max` lets an area under the hub (the Ember Rift) stay out until you descend.
## Respawns into a not-yet-loaded area load it synchronously before the body can fall.

const TICK := 0.25

## {id, source: String (res path to .gd or .tscn), anchor: Vector3, load_r, unload_r, y_max}
var table: Array[Dictionary] = []
var _live: Dictionary = {}       # id -> Area
var _t := 0.0


static func attach(zone: Node3D, entries: Array[Dictionary]) -> AreaStreamer:
	var s := AreaStreamer.new()
	s.name = "AreaStreamer"
	s.table = entries
	zone.add_child(s)
	return s


func _ready() -> void:
	Events.respawned.connect(func(at: Vector3) -> void: _sync(at, true))
	var p := _player()
	if p:
		_sync(p.global_position, true)


func _process(delta: float) -> void:
	_t += delta
	if _t < TICK:
		return
	_t = 0.0
	var p := _player()
	if p:
		_sync(p.global_position, false)


func live(id: String) -> Area:
	var a: Area = _live.get(id)
	return a if is_instance_valid(a) else null


func _sync(pos: Vector3, force: bool) -> void:
	for e in table:
		var id: String = e.id
		var d := Vector2(pos.x - (e.anchor as Vector3).x, pos.z - (e.anchor as Vector3).z).length()
		var below: bool = pos.y <= float(e.get("y_max", INF))
		var want := d < float(e.load_r) and below
		var a := live(id)
		if a == null and (want or (force and d < float(e.load_r) * 1.2)):
			_load(e, force)
		elif a != null and d > float(e.unload_r):
			_live.erase(id)
			a.queue_free()


func _load(e: Dictionary, force := false) -> void:
	var src: String = e.source
	var node: Node = null
	var res := load(src)
	if res is PackedScene:
		node = (res as PackedScene).instantiate()
	elif res is GDScript:
		node = (res as GDScript).new()
	var a := node as Area
	if a == null:
		push_error("AreaStreamer: %s is not an Area" % src)
		return
	a.area_id = e.id
	a.instant = force
	a.name = "Area_" + String(e.id)
	var t0 := Time.get_ticks_usec()
	get_parent().add_child(a)
	_live[e.id] = a
	print("AREA load %s %.1f ms" % [e.id, (Time.get_ticks_usec() - t0) * 0.001])


func _player() -> Node3D:
	return get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
