extends Node
## r30 world-builder captures: the real player camera at the arena mouths (their gates shut for the
## shot), the summit, the world's edges and the lit spokes. In memory only (saves held).
##   godot --path . res://zz/world_r30_shots.tscn -- --out=<dir> [--only=name,name]
## [name, position (y < -50: snap to the ground), yaw, pitch, close the arena gates]
var VIEWS := [
	["spawn_north", Vector3(0.0, -99.0, 44.0), 0.0, 0.12, false],
	["pit_from_stair", Vector3(21.0, 4.4, -79.6), 0.62, -0.12, true],
	["pit_grille", Vector3(16.0, 4.4, -83.0), -2.6, -0.02, true],
	["pit_chapel", Vector3(16.0, 4.4, -89.5), 0.0, -0.02, true],
	["dais_mouth", Vector3(0.0, 27.5, -100.0), PI, -0.02, true],
	["dais_from_deck", Vector3(0.0, 27.5, -82.0), 0.0, 0.05, true],
	["summit_from_rim", Vector3(-14.0, -99.0, 6.0), -0.12, 0.22, false],
	["dais_rim_fires", Vector3(-5.0, 27.5, -94.0), 0.9, -0.05, false],
	["henge_from_westway", Vector3(-36.0, -99.0, 12.0), 0.95, 0.05, false],
	["tower_from_green", Vector3(0.0, -99.0, 26.0), -0.9, 0.1, false],
	["tower_top_vista", Vector3(18.4, 9.4, 10.0), 0.2, -0.14, false],
	["stairfoot_glow", Vector3(-12.0, -99.0, 26.0), -0.25, 0.0, false],
	["south_edge", Vector3(20.0, -99.0, 66.0), PI, 0.02, false],
	["road_east_gate", Vector3(86.0, -99.0, 63.0), -PI * 0.5, 0.0, false],
	["west_edge", Vector3(-92.0, -99.0, 0.0), PI * 0.5, 0.02, false],
	["east_way", Vector3(40.0, -99.0, 14.0), -0.606, -0.02, false],
	["fen_descent", Vector3(76.0, -99.0, -38.0), 0.588, -0.04, false],
	["shrine_far", Vector3(-12.0, -99.0, 26.0), 0.9, -0.02, false],
]
const SETTLE := 45
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
	if not only.is_empty():
		VIEWS = VIEWS.filter(func(v: Array) -> bool: return String(v[0]) in only)
	get_window().size = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _gates(shut: bool) -> void:
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		var ar := a as BossArena
		var all: Array = [ar.gate]
		all.append_array(ar.gates)
		for g in all:
			if g != null and is_instance_valid(g) and g.get("arena_only") == true:
				if shut:
					g.call("close")
				else:
					g.call("release")


func _process(_d: float) -> void:
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if not main.has_meta("realm_done"):
		return
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if String(c.name) != "Grade":
			(c as CanvasLayer).visible = false
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		(a as Node).set_physics_process(false)          # no fight wakes while we look
	if i >= 0 and i < VIEWS.size():
		_hold()
	if wait > 0:
		wait -= 1
		return
	if i >= 0:
		var path := out.path_join("wb_%s.png" % VIEWS[i][0])
		get_viewport().get_texture().get_image().save_png(path)
		print("WBSHOT ", path)
	i += 1
	if i >= VIEWS.size():
		print("WBSHOTS done")
		get_tree().quit()
		return
	_gates(bool(VIEWS[i][4]))
	_hold()
	p.set_view(float(VIEWS[i][2]), float(VIEWS[i][3]))
	wait = SETTLE


func _hold() -> void:
	var at: Vector3 = VIEWS[i][1]
	if at.y < -50.0:
		at.y = RealmLayout.ground(p.get_world_3d().direct_space_state, at.x, at.z) + 0.2
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
