extends Node
## Stills of every enemy kind, elite and boss as the night shows them (windowed; headless cannot render).
##   godot --path . res://zz/creature_shots.tscn -- --out=<dir> [--only=id,id]
## Each creature is spawned alone on open ground (the Pilgrims' Road), its AI frozen after it has dressed,
## and shot from a free camera: player (7 m, eye 1.7 m, at its chest), close (2.5 m, at its head) and lit
## (the player view plus a warm lantern-ish OmniLight3D). Prints "CSTAT id tris meshes size" per creature.
const Tiers := preload("res://core/life/encounters/tiers.gd")
const Variants := preload("res://core/life/encounters/variants.gd")
const Elites := preload("res://core/life/encounters/elites.gd")
const EliteKit := preload("res://core/life/encounters/elite_kit.gd")
const SPOT := Vector2(62.0, 60.0)

var main: Node
var p: Player
var out := "/tmp/creatures"
var only: PackedStringArray = []
var t := 0
var started := false


## [id, script path, variant, elite id, note]
func _list() -> Array:
	var l: Array = []
	for k: String in Tiers.KIND_PATHS:
		l.append([k, Tiers.KIND_PATHS[k], "", "", "kind"])
	l.append(["husk_stonebound", Tiers.KIND_PATHS.husk, "stonebound", "", "variant"])
	l.append(["husk_drowned", Tiers.KIND_PATHS.husk, "drowned", "", "variant"])
	l.append(["wretch_deeper", Tiers.KIND_PATHS.wretch, "deeper", "", "variant"])
	l.append(["brood_mother", "res://core/enemy/brood_mother.gd", "", "", "guardian"])
	l.append(["tally_reliquary", "res://core/enemy/tally_reliquary.gd", "", "", "adjunct"])
	for id: String in Elites.ELITES:
		l.append(["elite_" + id, Elites.ELITES[id].script, "", id, "elite"])
	l.append(["boss_thornwarden", "res://core/enemy/thornwarden.gd", "", "", "boss"])
	l.append(["boss_bone_abbot", "res://core/enemy/bone_abbot.gd", "", "", "boss"])
	l.append(["boss_ascended_warden", "res://core/enemy/ascended_warden.gd", "", "", "boss"])
	l.append(["boss_anchoress", "res://core/enemy/anchoress.gd", "", "", "boss"])
	l.append(["boss_hierarch_voice", "res://core/enemy/hierarch_voice.gd", "", "", "boss"])
	return l


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


func _process(_d: float) -> void:
	t += 1
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if started or not main.has_meta("realm_done") or t < 600:
		return
	started = true
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _clear_enemies() -> void:
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()


func _ground(x: float, z: float) -> float:
	return RealmLayout.ground((main as Node3D).get_world_3d().direct_space_state, x, z)


func _bounds(n: Node) -> Dictionary:
	var box := AABB()
	var first := true
	var tris := 0
	var meshes := 0
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		if m.mesh is QuadMesh or m.mesh is PlaneMesh or m.mesh is RibbonTrailMesh:
			continue
		var gb := m.global_transform * m.get_aabb()
		if gb.size.length() > 40.0:
			continue
		box = gb if first else box.merge(gb)
		first = false
		meshes += 1
		for s in m.mesh.get_surface_count():
			var arr := m.mesh.surface_get_arrays(s)
			if arr.size() > Mesh.ARRAY_INDEX and arr[Mesh.ARRAY_INDEX] != null and (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() > 0:
				tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			elif arr[Mesh.ARRAY_VERTEX] != null:
				tris += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return {"box": box, "tris": tris, "meshes": meshes}


func _run() -> void:
	(p.get_node("Visual") as Node3D).visible = false
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if String(c.name) != "Grade":
			(c as CanvasLayer).visible = false
	_clear_enemies()
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.08
	add_child(cam)
	cam.make_current()
	var gy := _ground(SPOT.x, SPOT.y)
	var base := Vector3(SPOT.x, gy, SPOT.y)
	for item in _list():
		var id: String = item[0]
		if only.size() > 0 and not (id in only):
			continue
		_clear_enemies()
		p.global_position = base + Vector3(0, 1.0, 22.0)
		p.velocity = Vector3.ZERO
		var script := load(item[1]) as GDScript
		if script == null:
			print("CFAIL ", id, " no script")
			continue
		var e := script.new() as Enemy
		if e == null:
			print("CFAIL ", id, " not an Enemy")
			continue
		if item[3] != "":
			EliteKit.scale(e, 1, false)
			e.set_meta(&"display_name", Elites.title(item[3], false))
		if item[2] != "":
			Variants.pre(e, item[2])
			e.ready.connect(Variants.dress.bind(e, item[2]), CONNECT_ONE_SHOT)
		main.add_child(e)
		e.global_position = base + Vector3(0, 0.05, 0)
		e.home = base
		await _frames(45)
		if not is_instance_valid(e):
			print("CFAIL ", id, " freed itself")
			continue
		e.global_position = base + Vector3(0, 0.05, 0)
		e.velocity = Vector3.ZERO
		e.rotation.y = 0.0
		e.process_mode = Node.PROCESS_MODE_DISABLED
		await _frames(3)
		var b := _bounds(e)
		var box: AABB = b.box
		var h := maxf(box.end.y - base.y, 0.5)
		var w := maxf(box.size.x, box.size.z)
		print("CSTAT %s tris=%d meshes=%d height=%.2f width=%.2f kind=%s" % [id, b.tris, b.meshes, h, w, item[4]])
		var dist := 7.0
		if h > 3.2:
			dist = 7.0 + (h - 3.2) * 2.5
		var chest := base + Vector3(0, h * 0.6, 0)
		var head := base + Vector3(0, h * 0.9, 0)
		var eye := base + Vector3(0, 1.7, dist)
		await _shot(cam, id, "player", eye, chest)
		await _shot(cam, id, "close", base + Vector3(0, h * 0.9, 2.5 + maxf(0.0, h - 2.5) * 1.2), head)
		var ol := OmniLight3D.new()
		ol.light_color = Color(1.0, 0.68, 0.36)
		ol.light_energy = 2.0
		ol.omni_range = 8.0
		main.add_child(ol)
		ol.global_position = base + Vector3(3.0, 1.4, dist * 0.45)
		await _shot(cam, id, "lit", eye, chest)
		# near views from both sides (the rest pose faces -Z), a lantern-ish light beside the camera
		var mid := base + Vector3(0, h * 0.55, 0)
		var nd := 2.2 + h * 0.9
		ol.global_position = base + Vector3(1.2, 1.6, -nd * 0.7)
		await _shot(cam, id, "near_front", base + Vector3(nd * 0.35, h * 0.7 + 0.3, -nd), mid)
		ol.global_position = base + Vector3(-1.2, 1.6, nd * 0.7)
		await _shot(cam, id, "near_back", base + Vector3(-nd * 0.35, h * 0.7 + 0.3, nd), mid)
		ol.queue_free()
		if is_instance_valid(e):
			e.process_mode = Node.PROCESS_MODE_INHERIT
			e.queue_free()
		await _frames(2)
	print("CREATURESHOTS done")
	get_tree().quit()


func _shot(cam: Camera3D, id: String, view: String, eye: Vector3, tgt: Vector3) -> void:
	cam.global_position = eye
	cam.look_at(tgt, Vector3.UP)
	p.velocity = Vector3.ZERO
	await _frames(60)
	var path := out.path_join("%s_%s.png" % [id, view])
	get_viewport().get_texture().get_image().save_png(path)
	print("CSHOT ", path)
