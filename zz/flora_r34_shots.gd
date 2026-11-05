extends Node
## r34 flora captures (windowed): the new regions from near the ground (the undergrowth ends ~40 m out): the doubled Realm from high above and each new region from a free
## camera (its own far plane; the player camera ends at 82 m). In memory only (saves held).
##   HOME=<scratch> godot --path . res://zz/flora_r34_shots.tscn -- --out=<dir> [--only=name,name]
## [name, camera position, look-at point (near views: y above the terrain), far plane, fog off]
var VIEWS := [
	["quarry", Vector3(-112.0, 12.0, -84.0), Vector3(-128.0, 0.0, -104.0), 300.0, false],
	["holds", Vector3(-132.0, 14.0, 22.0), Vector3(-137.0, 0.0, 6.0), 300.0, false],
	["foundry", Vector3(118.0, 10.0, -70.0), Vector3(135.0, 3.0, -92.0), 300.0, false],
	["moor", Vector3(128.0, 12.0, 6.0), Vector3(142.0, 6.0, -20.0), 300.0, false],
	["orchard", Vector3(-96.0, 8.0, 108.0), Vector3(-114.0, 1.0, 126.0), 300.0, false],
	["necropolis", Vector3(6.0, 7.0, 104.0), Vector3(-2.0, 3.0, 128.0), 300.0, false],
	["mere", Vector3(108.0, 7.0, 100.0), Vector3(88.0, -1.0, 116.0), 300.0, false],
	["overview", Vector3(0.0, 430.0, 150.0), Vector3(0.0, 0.0, 12.0), 1400.0, true],
]
const SETTLE := 50
var main: Node
var cam: Camera3D
var i := -1
var wait := 0
var out := "/tmp"
var only: PackedStringArray = []
var _fog := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	Travel.bosses_slain.clear()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",")
	if not only.is_empty():
		VIEWS = VIEWS.filter(func(v: Array) -> bool: return String(v[0]) in only)
	get_window().size = Vector2i(1600, 1000)
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _env() -> Environment:
	var we := get_tree().root.find_children("*", "WorldEnvironment", true, false)
	return (we[0] as WorldEnvironment).environment if not we.is_empty() else null


func _process(_d: float) -> void:
	if main == null or not main.has_meta("realm_done"):
		return
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if String(c.name) != "Grade":
			(c as CanvasLayer).visible = false
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		(a as Node).set_physics_process(false)
	if cam == null:
		cam = Camera3D.new()
		cam.name = "FloraShotCam"
		main.add_child(cam)
		var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
		if p:
			p.process_mode = Node.PROCESS_MODE_DISABLED
			p.visible = false
	if wait > 0:
		wait -= 1
		cam.current = true
		return
	if i >= 0:
		var path := out.path_join("flora_%s.png" % VIEWS[i][0])
		get_viewport().get_texture().get_image().save_png(path)
		print("FLORASHOT ", path)
	i += 1
	if i >= VIEWS.size():
		print("FLORASHOTS done")
		get_tree().quit()
		return
	var v: Array = VIEWS[i]
	cam.far = float(v[3])
	cam.fov = 60.0
	var cp: Vector3 = v[1]
	var lp: Vector3 = v[2]
	if not bool(v[4]):
		# near views: heights are above the terrain there
		var RL: GDScript = load("res://core/world/realm/realm_land.gd")
		cp.y += float(RL.call("height_at", cp.x, cp.z))
		lp.y += float(RL.call("height_at", lp.x, lp.z))
	cam.global_position = cp
	cam.look_at(lp, Vector3.UP)
	cam.current = true
	var env := _env()
	if env:
		env.fog_enabled = not bool(v[4])
		env.volumetric_fog_enabled = env.volumetric_fog_enabled and not bool(v[4])
	wait = SETTLE
