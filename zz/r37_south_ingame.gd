extends Node
## South pass captures (copy of world_poi_shots with the South views); r31 world pass captures: the real player camera at each new place (core/world/realm/realm_pois.gd)
## from its approach, from far off (the landmark read), and from its top; plus the denser wood and
## meadow. In memory only (saves held).
##   godot --path . res://zz/world_poi_shots.tscn -- --out=<dir> [--only=name,name]
## Views are built once the places exist: [name, position (y < -50: snap to the ground), yaw toward
## a point or a fixed yaw, pitch].
const SETTLE := 50
var VIEWS: Array = []
var p: Player
var main: Node
var i := -1
var wait := 0
var out := "/tmp"
var only: PackedStringArray = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	Travel.bosses_slain.clear()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",")
	get_window().size = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


## Yaw that looks from `from` at `to` (the player's view yaw: 0 looks down -z).
static func _look(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(-d.x, -d.z)


func _views() -> void:
	var South := load("res://core/world/realm/realm_pois_r37_south.gd")
	var oak: Dictionary = South.oak
	var well: Dictionary = South.well
	var c: Vector3 = (oak.xf as Transform3D).origin
	var oak_in := Vector3(c.x + 1.8, c.y + 0.3, c.z + 0.6)
	VIEWS.append(["south_oak_whole", Vector3(c.x, -99.0, c.z - 42.0), c + Vector3(0, 16, 0), 0.28])
	VIEWS.append(["south_oak_bark", Vector3(c.x + 2.0, -99.0, c.z - 9.0), c + Vector3(0, 7, 0), 0.4])
	VIEWS.append(["south_oak_stair", oak_in, c + Vector3(-1, 14, 1.5), 0.75])
	var tips: Array = oak.tips
	var t0: Vector3 = tips[0]
	VIEWS.append(["south_oak_limb", t0.lerp(c + Vector3(0, t0.y, 0), 0.45) + Vector3(0, 0.3, 0), c + Vector3(0, t0.y + 6.0, 0), 0.15])
	var wc := Vector3(RealmLayout.WELL_C.x, 0, RealmLayout.WELL_C.y)
	var gate: Vector3 = well.get("gate_at", Vector3(wc.x - 24.0, 0, wc.z - 8.0))
	VIEWS.append(["south_well_rim", Vector3(wc.x - 26.0, -99.0, wc.z - 12.0), Vector3(wc.x, well.floor_y + 6.0, wc.z), -0.3])
	var land: Vector3 = well.landing
	VIEWS.append(["south_well_ledge", Vector3(land.x + 9.0, land.y + 9.0, land.z - 6.0), land + Vector3(0, 1, 0), -0.1])
	var lip: Vector3 = well.get("fall_lip", Vector3(wc.x + 24.0, 8.0, wc.z))
	VIEWS.append(["south_well_fall", Vector3(wc.x - 12.0, well.rim_y - 8.0, wc.z + 4.0), Vector3(wc.x + 18.0, well.rim_y - 10.0, wc.z), 0.0])
	var hut: Vector3 = (get_tree().get_first_node_in_group("world_poi") as Node3D).global_position
	for h in get_tree().get_nodes_in_group("world_poi"):
		if String(h.get_meta("poi", "")) == "r37s_hut":
			hut = h.get_meta("centre")
	VIEWS.append(["south_hut", Vector3(hut.x + 3.0, -99.0, hut.z - 15.0), hut + Vector3(0, 2, 0), 0.0])
	VIEWS.append(["south_gate_road", Vector3(-120.0, -99.0, 66.0), Vector3(-155.0, 6.0, 67.0), 0.12])
	VIEWS.append(["south_gate_close", Vector3(-141.0, -99.0, 62.0), Vector3(-155.0, 5.0, 67.0), 0.1])
	if not only.is_empty():
		VIEWS = VIEWS.filter(func(v: Array) -> bool: return String(v[0]) in only)


func _process(_d: float) -> void:
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if not main.has_meta("realm_done") or main.get_node_or_null("RealmPois") == null:
		return
	if VIEWS.is_empty():
		_views()
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if String(c.name) != "Grade":
			(c as CanvasLayer).visible = false
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		(a as Node).set_physics_process(false)
	if i >= 0 and i < VIEWS.size():
		_hold()
	if wait > 0:
		wait -= 1
		return
	if i >= 0:
		var path := out.path_join("poi_%s.png" % VIEWS[i][0])
		get_viewport().get_texture().get_image().save_png(path)
		print("POISHOT ", path)
	i += 1
	if i >= VIEWS.size():
		print("POISHOTS done")
		get_tree().quit()
		return
	_hold()
	var v: Array = VIEWS[i]
	var yaw: float = _look(_at(v[1]), v[2]) if v[2] is Vector3 else float(v[2])
	p.set_view(yaw, float(v[3]))
	wait = SETTLE


func _at(at: Vector3) -> Vector3:
	if at.y < -50.0:
		at.y = RealmLayout.ground(p.get_world_3d().direct_space_state, at.x, at.z) + 0.2
	return at


func _hold() -> void:
	p.global_position = _at(VIEWS[i][1])
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
