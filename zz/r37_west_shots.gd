extends Node
## West Marches stills, LIT (a lamp at the camera, so the materials are judged rather than the night):
##   godot --path . res://zz/r37_west_shots.tscn -- --out=<dir> [--only=name,name]
const SETTLE := 45
const VIEWS := [
	["bridge", Vector3(-192, -99, 62), Vector3(-208, 3, 65.6)],
	["mill", Vector3(-205, -99, 66), Vector3(-218, 4, 58)],
	["inn", Vector3(-186, -99, 70), Vector3(-186, 3, 57)],
	["smithy", Vector3(-174, -99, 66), Vector3(-174, 2, 75)],
	["square", Vector3(-188, -99, 69), Vector3(-192, 2, 77)],
	["stables", Vector3(-184, -99, 90), Vector3(-196, 2, 92)],
	["statue_in", Vector3(-200, -99, -85), Vector3(-214, 8, -104)],
	["statue_far", Vector3(-190, -99, -66), Vector3(-230, 20, -92)],
	["hand", Vector3(-222, -99, -68), Vector3(-236, 3, -84)],
	["tower", Vector3(-214, -99, 170), Vector3(-236, 8, 170)],
	["trebs", Vector3(-190, -99, 194), Vector3(-196, 5, 208)],
	["shrine", Vector3(-198, -99, -33), Vector3(-208, 1, -40)],
	["palisade", Vector3(-214, -99, 106), Vector3(-214, 3, 116)],
]
var p: Player
var main: Node
var i := -1
var wait := 0
var out := "/tmp"
var only: PackedStringArray = []
var lamp: OmniLight3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",")
	get_window().size = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(_d: float) -> void:
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if not main.has_meta("realm_done") or main.get_node_or_null("RealmPois") == null:
		return
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if String(c.name) != "Grade":
			(c as CanvasLayer).visible = false
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		(a as Node).set_physics_process(false)
	if lamp == null:
		lamp = OmniLight3D.new()
		lamp.light_energy = 9.0
		lamp.omni_range = 60.0
		lamp.light_color = Color(1.0, 0.92, 0.8)
		main.add_child(lamp)
	if i >= 0 and i < _list().size():
		_hold()
	if wait > 0:
		wait -= 1
		return
	if i >= 0:
		var path := out.path_join("west_%s.png" % _list()[i][0])
		get_viewport().get_texture().get_image().save_png(path)
		print("WESTSHOT ", path)
	i += 1
	if i >= _list().size():
		print("WESTSHOTS done")
		get_tree().quit()
		return
	_hold()
	var v: Array = _list()[i]
	var from := _at(v[1])
	var to: Vector3 = v[2]
	p.set_view(atan2(-(to.x - from.x), -(to.z - from.z)), -0.05)
	lamp.global_position = from + Vector3(0, 6, 0) + (to - from).normalized() * 6.0
	wait = SETTLE


func _list() -> Array:
	if only.is_empty():
		return VIEWS
	return VIEWS.filter(func(v: Array) -> bool: return String(v[0]) in only)


func _at(at: Vector3) -> Vector3:
	if at.y < -50.0:
		at.y = RealmLayout.ground(p.get_world_3d().direct_space_state, at.x, at.z) + 0.2
	return at


func _hold() -> void:
	p.global_position = _at(_list()[i][1])
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
