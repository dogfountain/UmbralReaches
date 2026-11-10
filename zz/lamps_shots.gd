extends Node
## Lamp stills at night: each view may light the lamps whose ids start with a prefix first.
##   godot --path . res://zz/lamps_shots.tscn -- --out=<dir> [--only=name,name]
## A world view is [name, camera (y < -50: ground + 1.6, else absolute), target, [lamp id prefixes to light]].
## A node view is [name, "node:<scene node name>", offset in the node's local axes, look-at offset, prefixes].
const SETTLE := 50
const VIEWS := [
	["bridge_before", Vector3(-208, 2.4, 55), Vector3(-208, 0.0, 66), []],
	["bridge_after", Vector3(-208, 2.4, 55), Vector3(-208, 0.0, 66), ["wf_"]],
	["bridge_end_after", Vector3(-226, 3.2, 62), Vector3(-200, 1.0, 66), ["wf_"]],
	["arch_before", "node:Lamp_wf_arch_s_213", Vector3(2.5, 1.4, 6.0), Vector3(0, 0.4, 0), []],
	["arch_after", "node:Lamp_wf_arch_s_213", Vector3(2.5, 1.4, 6.0), Vector3(0, 0.4, 0), ["wf_"]],
	["shrine_before", "node:Lamp_rd_shrine_a", Vector3(2.0, 1.0, 5.5), Vector3(0, 0.6, 0), []],
	["shrine_after", "node:Lamp_rd_shrine_a", Vector3(2.0, 1.0, 5.5), Vector3(0, 0.6, 0), ["rd_shrine", "rd_way_9", "rd_lantern"]],
	["road_lantern", "node:Lamp_rd_lantern_0", Vector3(2.0, -0.4, 6.0), Vector3(0, 0, 0), ["rd_lantern_0"]],
	["gate_before", Vector3(-126, -98, 67), Vector3(-155, 8, 67), []],
	["gate_after", Vector3(-126, -98, 67), Vector3(-155, 8, 67), ["wall_g_-155"]],
	["cell_before", "node:Lamp_cell_1", Vector3(0, 0.2, 5.5), Vector3(0, 0.2, 0), []],
	["cell_after", "node:Lamp_cell_1", Vector3(0, 0.2, 5.5), Vector3(0, 0.2, 0), ["cell_"]],
	["cells_wide", "node:Lamp_cell_1", Vector3(8, 3.5, 18), Vector3(0, 1.5, 0), ["cell_", "chapel_"]],
	["oak", "node:Lamp_oak_3", Vector3(0, -0.3, 4.0), Vector3(0, 0.0, 0), ["oak_"]],
	["ledge", "node:Lamp_ledge_2", Vector3(0, -0.6, 6.0), Vector3(0, -0.8, 0), ["ledge_"]],
	["gate_crown", "node:Lamp_wall_gc_-155_-1", Vector3(26, -9, 0), Vector3(0, -2, 0), ["wall_g_-155"]],
	["tower_crown", "node:Lamp_wall_c_-152_104", Vector3(22, -7, 6), Vector3(0, -1, 0), ["wall_t_-152"]],
	["siege_tower", Vector3(-254, -98, 156), Vector3(-238, 10, 169), ["siege_"]],
	["camp", "node:Pilgrim", Vector3(-1.5, 1.6, 6.0), Vector3(-0.5, 0.3, 0), []],
	["camp_wide", "node:Pilgrim", Vector3(-9, 2.6, 14), Vector3(-1, 0.5, 0), []],
	["ferry", "node:Skiff", Vector3(-7, 2.0, 3), Vector3(-4, 0.6, 0), []],
	["hide", "node:HuntersHide", Vector3(1.6, 1.0, 3.2), Vector3(0.5, 0.45, 0), []],
	["window", "node:Lamp_press_window", Vector3(0, -0.8, 9.0), Vector3(0, 0.0, 0), []],
	["window_wide", "node:Lamp_press_window", Vector3(5, -0.5, 16.0), Vector3(0, 0.5, 0), []],
	["k_hang_unlit", "node:Studio", Vector3(-3.1, 2.2, 0.4), Vector3(-3.6, 2.1, -3), []],
	["k_hang_lit", "node:Studio", Vector3(-3.1, 2.2, 0.4), Vector3(-3.6, 2.1, -3), ["studio_hang"]],
	["k_niche_unlit", "node:Studio", Vector3(-0.7, 1.1, 0.4), Vector3(-1.2, 0.6, -3), []],
	["k_niche_lit", "node:Studio", Vector3(-0.7, 1.1, 0.4), Vector3(-1.2, 0.6, -3), ["studio_niche"]],
	["k_post_unlit", "node:Studio", Vector3(1.7, 1.9, 0.4), Vector3(1.2, 1.7, -3), []],
	["k_post_lit", "node:Studio", Vector3(1.7, 1.9, 0.4), Vector3(1.2, 1.7, -3), ["studio_post"]],
	["k_cresset_unlit", "node:Studio", Vector3(4.1, 1.4, 0.4), Vector3(3.6, 0.9, -3), []],
	["k_cresset_lit", "node:Studio", Vector3(4.1, 1.4, 0.4), Vector3(3.6, 0.9, -3), ["studio_cresset"]],
	["k_ember_unlit", "node:EmberPost", Vector3(1.9, 1.9, 0.5), Vector3(0.6, 1.8, -3), ["ember_off"]],
	["k_ember_lit", "node:EmberPost", Vector3(1.9, 1.9, 0.5), Vector3(0.6, 1.8, -3), ["ember"]],
	["looks_unlit", "node:Studio", Vector3(0, 0.0, 6.0), Vector3(0, 1.0, 0), []],
	["looks_lit", "node:Studio", Vector3(0, 0.0, 6.0), Vector3(0, 1.0, 0), ["studio"]],
]
var p: Player
var main: Node
var i := -1
var wait := 0
var out := "/tmp"
var only: PackedStringArray = []
var _studio_done := false


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
	if not main.has_meta("realm_done") or main.get_node_or_null("Lamps") == null:
		return
	if not _studio_done:
		_studio_done = true
		_studio()
	p.visible = false
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if String(c.name) != "Grade":
			(c as CanvasLayer).visible = false
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		(a as Node).set_physics_process(false)
	if i >= 0 and i < _list().size():
		_hold()
	if wait > 0:
		wait -= 1
		return
	if i >= 0:
		var path := out.path_join("lamps_%s.png" % _list()[i][0])
		get_viewport().get_texture().get_image().save_png(path)
		print("LAMPSHOT ", path)
	i += 1
	if i >= _list().size():
		print("LAMPSHOTS done")
		get_tree().quit()
		return
	var v: Array = _list()[i]
	_relight(v[v.size() - 1])
	var cam := _cam(v)
	_hold()
	var from: Vector3 = cam[0]
	var to: Vector3 = cam[1]
	var flat := Vector2(to.x - from.x, to.z - from.z).length()
	p.set_view(atan2(-(to.x - from.x), -(to.z - from.z)), clampf(atan2(to.y - from.y, flat), -0.6, 0.5))
	wait = SETTLE


## [camera point, target point] of a view.
func _cam(v: Array) -> Array:
	if v[1] is String:
		var n := main.find_child(String(v[1]).trim_prefix("node:"), true, false) as Node3D
		if n == null:
			print("LAMPSHOT no node ", v[1])
			return [Vector3(0, 30, 0), Vector3(0, 0, 1)]
		var b := n.global_basis.orthonormalized()
		var o := n.global_position
		return [o + b * (v[2] as Vector3), o + b * (v[3] as Vector3)]
	return [_at(v[1]), v[2]]


func _relight(prefixes: Array) -> void:
	if "ember" in prefixes or "ember_off" in prefixes:                    # the ember post follows its fire
		for e in main.find_children("EmberPost", "", true, false):
			var br = e.get("brazier")
			if br != null:
				br._set_lit("ember" in prefixes, false)
	for n in get_tree().get_nodes_in_group(&"lamp"):
		var l := n as Lamp
		var want := false
		for pre: String in prefixes:
			if String(l.lamp_id).begins_with(pre):
				want = true
		if want and not l.lit:
			l.interact(null)
		elif not want and l.lit:
			l.douse()


func _list() -> Array:
	if only.is_empty():
		return VIEWS
	return VIEWS.filter(func(v: Array) -> bool: return String(v[0]) in only)


func _at(at: Vector3) -> Vector3:
	if at.y < -50.0:
		at.y = RealmLayout.ground(p.get_world_3d().direct_space_state, at.x, at.z) + 1.6
	return at


func _hold() -> void:
	var cam := _cam(_list()[i])
	p.global_position = cam[0]
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


## The four looks side by side on open ground at the Downs' south edge, for the close stills.
func _studio() -> void:
	var sp := p.get_world_3d().direct_space_state
	var holder := Node3D.new()
	holder.name = "Studio"
	main.add_child(holder)
	var c := Vector2(214.0, -121.0)
	holder.global_position = Vector3(c.x, RealmLayout.ground(sp, c.x, c.y), c.y)
	var x := -3.6
	for k: String in ["hang", "niche", "post", "cresset"]:
		var l := Lamp.new()
		l.lamp_id = "studio_" + k
		l.look = k
		l.free_niche = k == "niche"
		holder.add_child(l)
		l.position = Vector3(x, 2.4 if k == "hang" else 0.0, 0.0)
		x += 2.4
