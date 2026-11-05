extends Node
## r34 layout captures (windowed): the doubled Realm from high above and each new region from a free
## camera (its own far plane; the player camera ends at 82 m). In memory only (saves held).
##   HOME=<scratch> godot --path . res://zz/layout_r34_shots.tscn -- --out=<dir> [--only=name,name]
## [name, camera position, look-at point, far plane, fog off]
var VIEWS := [
	["overview", Vector3(0.0, 430.0, 150.0), Vector3(0.0, 0.0, 12.0), 1400.0, true],
	["overview_south", Vector3(0.0, 170.0, 300.0), Vector3(0.0, 0.0, 10.0), 1000.0, true],
	["overview_west", Vector3(-300.0, 150.0, 20.0), Vector3(-40.0, 0.0, 0.0), 1000.0, true],
	["overview_east", Vector3(300.0, 150.0, 0.0), Vector3(40.0, 0.0, -10.0), 1000.0, true],
	["quarry", Vector3(-112.0, 40.0, -58.0), Vector3(-128.0, 4.0, -104.0), 400.0, false],
	["holds", Vector3(-110.0, 22.0, 34.0), Vector3(-134.0, 3.0, 12.0), 400.0, false],
	["foundry", Vector3(112.0, 30.0, -50.0), Vector3(132.0, 4.0, -92.0), 400.0, false],
	["moor", Vector3(100.0, 26.0, 20.0), Vector3(138.0, 6.0, -20.0), 400.0, false],
	["orchard", Vector3(-80.0, 26.0, 80.0), Vector3(-112.0, 1.0, 122.0), 400.0, false],
	["necropolis", Vector3(0.0, 22.0, 80.0), Vector3(0.0, 3.0, 128.0), 400.0, false],
	["mere", Vector3(80.0, 22.0, 78.0), Vector3(108.0, -1.0, 122.0), 400.0, false],
	["henge_raid", Vector3(-40.0, 45.0, 10.0), Vector3(-86.0, 9.0, -24.0), 400.0, false],
	["summit_raid", Vector3(0.0, 60.0, -60.0), Vector3(0.0, 27.0, -118.0), 400.0, false],
	["south_edge", Vector3(40.0, 18.0, 140.0), Vector3(40.0, 4.0, 178.0), 400.0, false],
	["west_edge", Vector3(-120.0, 14.0, 60.0), Vector3(-160.0, 4.0, 60.0), 400.0, false],
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
		cam.name = "LayoutShotCam"
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
		var path := out.path_join("layout_%s.png" % VIEWS[i][0])
		get_viewport().get_texture().get_image().save_png(path)
		print("LAYOUTSHOT ", path)
	i += 1
	if i >= VIEWS.size():
		print("LAYOUTSHOTS done")
		get_tree().quit()
		return
	var v: Array = VIEWS[i]
	cam.far = float(v[3])
	cam.fov = 60.0
	cam.global_position = v[1]
	cam.look_at(v[2], Vector3.UP)
	cam.current = true
	var env := _env()
	if env:
		env.fog_enabled = not bool(v[4])
		env.volumetric_fog_enabled = env.volumetric_fog_enabled and not bool(v[4])
	wait = SETTLE
