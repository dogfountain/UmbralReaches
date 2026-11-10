extends Node
## South pass captures (copy of world_poi_shots with the South views); r31 world pass captures: the real player camera at each new place (core/world/realm/realm_pois.gd)
## from its approach, from far off (the landmark read), and from its top; plus the denser wood and
## meadow. In memory only (saves held).
##   godot --path . res://zz/world_poi_shots.tscn -- --out=<dir> [--only=name,name]
## Views are built once the places exist: [name, position (y < -50: snap to the ground), yaw toward
## a point or a fixed yaw, pitch].
const SETTLE := 60
var VIEWS: Array = []
var p: Player
var main: Node
var i := -1
var wait := 0
var out := "/tmp"
var only: PackedStringArray = []
var lit := false                  ## daylight check: a strong sun, a lifted ambient, no grade
var cam: Camera3D
var lamp: OmniLight3D             ## the wanderer's lantern, standing in for the hidden player on close views


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(200.0, true, false, true).timeout.connect(get_tree().quit)     # a hard stop: never hang on a screen
	Travel._busy = true
	Travel.bosses_slain.clear()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a == "--lit":
			lit = true
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
	var South := load("res://core/world/realm/realm_pois_south_marches.gd")
	var oak: Dictionary = South.oak
	var well: Dictionary = South.well
	var c: Vector3 = (oak.xf as Transform3D).origin
	var oak_in := Vector3(c.x + 1.8, c.y + 0.3, c.z + 0.6)
	VIEWS.append(["south_oak_whole", Vector3(c.x - 8.0, -92.0, c.z - 42.0), c + Vector3(0, 19, 0), 0.3])
	VIEWS.append(["south_oak_bark", Vector3(c.x - 7.6, -99.0, c.z - 7.4), c + Vector3(-4.6, 4.2, -2.2), 0.0])
	VIEWS.append(["south_oak_door", Vector3(c.x - 3.0, -99.0, c.z - 17.0), c + Vector3(0.5, 3.0, 0), 0.0])
	VIEWS.append(["south_oak_stair", oak_in, c + Vector3(-1, 14, 1.5), 0.75])
	var tips: Array = oak.tips
	var t0: Vector3 = tips[0]
	var outward := Vector3(t0.x - c.x, 0.0, t0.z - c.z).normalized()
	VIEWS.append(["south_oak_limb", t0 - outward * 9.0 + Vector3(0, 1.7, 0), t0 + outward * 10.0 + Vector3(0, 0.5, 0), 0.0])
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
	if cam == null:
		cam = Camera3D.new()
		cam.fov = 62.0
		cam.far = 600.0
		get_tree().root.add_child(cam)
		cam.make_current()
		p.visible = false
		lamp = OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.86, 0.68)
		lamp.light_energy = 1.4
		lamp.omni_range = 11.0
		cam.add_child(lamp)
		lamp.position = Vector3(0.5, -0.3, -0.8)
		if lit:
			var sun := DirectionalLight3D.new()
			sun.light_energy = 2.4
			sun.rotation_degrees = Vector3(-48.0, 35.0, 0.0)
			sun.shadow_enabled = true
			get_tree().root.add_child(sun)
			for we in get_tree().root.find_children("*", "WorldEnvironment", true, false):
				var env := (we as WorldEnvironment).environment
				if env:
					env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
					env.ambient_light_color = Color(0.75, 0.78, 0.85)
					env.ambient_light_energy = 1.2
					env.tonemap_exposure = 1.0
			for c2 in get_tree().root.find_children("Grade", "CanvasLayer", true, false):
				(c2 as CanvasLayer).visible = false
	if i >= 0 and i < VIEWS.size():
		_hold()
	if wait > 0:
		wait -= 1
		return
	if i >= 0:
		var path := out.path_join("poi_%s%s.png" % [VIEWS[i][0], "_lit" if lit else ""])
		get_viewport().get_texture().get_image().save_png(path)
		print("POISHOT ", path)
	i += 1
	if i >= VIEWS.size():
		print("POISHOTS done")
		get_tree().quit()
		return
	_hold()
	wait = SETTLE


func _at(at: Vector3) -> Vector3:
	if at.y < -50.0:
		var up := 1.7 if at.y < -95.0 else at.y + 100.0         # -99: eye height; -94..-80: that many metres up
		at.y = RealmLayout.ground(p.get_world_3d().direct_space_state, at.x, at.z) + up
	return at


## The camera at the view's place, looking at its target; the (hidden) player is parked under it so streaming and
## culling follow.
func _hold() -> void:
	var v: Array = VIEWS[i]
	var at := _at(v[1])
	cam.global_position = at
	cam.look_at(v[2] as Vector3)
	lamp.visible = false
	if not lit:
		for key: String in ["bark", "stair", "limb", "door", "ledge", "close", "fall"]:
			if String(v[0]).contains(key):
				lamp.visible = true
	p.global_position = Vector3(at.x, at.y - 1.7 if v[1].y < -50.0 else at.y - 1.0, at.z)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
