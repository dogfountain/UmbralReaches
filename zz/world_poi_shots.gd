extends Node
## r31 world pass captures: the real player camera at each new place (core/world/realm/realm_pois.gd)
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
	for h in get_tree().get_nodes_in_group("world_poi"):
		var id := String(h.get_meta("poi"))
		var c: Vector3 = h.get_meta("centre")
		var ap: Vector3 = h.get_meta("approach", c + Vector3(0, 0, 10))
		var away := Vector3(ap.x - c.x, 0, ap.z - c.z).normalized()
		var near := c + away * 13.0 + Vector3(2.5, 0, 0)
		near.y = -99.0
		VIEWS.append([id + "_near", near, c + Vector3.UP * 3.0, -0.02])
		var far := c + away * 34.0
		far.y = -99.0
		VIEWS.append([id + "_far", far, c + Vector3.UP * 5.0, 0.04])
		if h.has_meta("route"):
			var rte: Array = h.get_meta("route")
			var top: Vector3 = rte[rte.size() - 1]
			VIEWS.append([id + "_top", top + Vector3.UP * 0.2, top + away * 30.0 + Vector3.DOWN * 10.0, -0.25])
	# the landmark reads from the places a player actually stands: the spokes and the Crossing
	var spots := {"belfry": Vector3(58.0, -99.0, -12.0), "almonry": Vector3(42.0, -99.0, 12.0), "spire": Vector3(-8.3, 18.2, -43.5), "charcoal": Vector3(-52.0, -99.0, -2.0)}
	for h in get_tree().get_nodes_in_group("world_poi"):
		var id := String(h.get_meta("poi"))
		if spots.has(id):
			VIEWS.append([id + "_from_path", spots[id], (h.get_meta("centre") as Vector3) + Vector3.UP * 6.0, 0.0])
	VIEWS.append(["wood_floor", Vector3(-80.0, -99.0, 6.0), 0.5, -0.05])
	VIEWS.append(["wood_edge", Vector3(-30.0, -99.0, 30.0), PI * 0.5 + 0.3, -0.02])
	VIEWS.append(["meadow_drift", Vector3(-12.0, -99.0, 66.0), -PI * 0.5, -0.04])
	VIEWS.append(["heath_stones", Vector3(30.0, -99.0, 72.0), PI * 0.5, -0.08])
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
