extends Node3D
## Loot drops as ground models (windowed, a hard watchdog): every gear slot at every quality, and the
## trophy / kind shapes, on dark ground under a night-ish light and under a neutral lit check.
##   godot --path . res://zz/loot_ground_shot.tscn -- --out=<dir>
## -> <dir>/lootground_{gear,things}_{night,lit}.png and close-ups.
const LootBag := preload("res://core/items/loot_bag.gd")
const GearDB := preload("res://core/items/gear_db.gd")
const THINGS := ["hobbs_knuckles", "lisles_tally", "briar_antler", "heart_stone", "scraped_face", "abbot_crown", "ascension_seal",
	"grave_ash", "bone_reliquary", "core_prism", "charm_ring", "cinder_censer"]

var out := "user://"
var cam: Camera3D
var env: Environment
var moon: DirectionalLight3D
var bags: Array[Node] = []
var plain := true            ## hide the beam, motes and name so the item alone shows


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	get_window().size = Vector2i(1600, 900)
	get_tree().create_timer(100.0).timeout.connect(func() -> void: get_tree().quit(2))
	Travel.set("_busy", true)
	_stage()
	await _run()
	get_tree().quit(0)


func _stage() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 0.91
	env.tonemap_white = 6.5
	env.glow_enabled = true
	env.glow_intensity = 0.62
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.15
	for l in 7:
		env.set_glow_level(l, l <= 1)
	we.environment = env
	add_child(we)
	moon = DirectionalLight3D.new()
	moon.rotation = Vector3(-0.5, 0.75, 0)
	moon.shadow_enabled = true
	add_child(moon)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.2, 0.2, 0.19)
	gm.roughness = 1.0
	ground.material_override = gm
	add_child(ground)
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.current = true


func _light(night: bool) -> void:
	if night:
		env.background_color = Color(0.035, 0.045, 0.08)
		env.ambient_light_color = Color("#1A2040")
		env.ambient_light_energy = 0.9
		moon.light_color = Color(0.62, 0.72, 1.0)
		moon.light_energy = 1.15
	else:
		env.background_color = Color(0.32, 0.33, 0.36)
		env.ambient_light_color = Color(0.55, 0.55, 0.6)
		env.ambient_light_energy = 0.6
		moon.light_color = Color(1, 1, 1)
		moon.light_energy = 1.3


func _clear() -> void:
	Travel.leaving = true
	for b in bags:
		if is_instance_valid(b):
			b.free()
	Travel.leaving = false
	bags.clear()


func _bag(entries: Array, pos: Vector3) -> void:
	var b: Node3D = LootBag.new()
	b.set("entries", entries)
	b.set("kept", true)
	add_child(b)
	b.position = pos
	bags.append(b)
	if plain:
		for n in ["Beam", "Motes", "Name"]:
			(b.get_node(n) as Node3D).visible = false


func _gear_grid() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for si in GearDB.SLOTS.size():
		for r in 5:
			var p := GearDB.make(rng, {"slot": GearDB.SLOTS[si], "rarity": r})
			_bag([{"kind": "gear", "piece": p}], Vector3((r - 2) * 1.1, 0, (si - 1.5) * 1.1))


func _things_grid() -> void:
	for i in THINGS.size():
		_bag([{"kind": "item", "id": THINGS[i], "n": 1}], Vector3((i % 6 - 2.5) * 1.1, 0, (i / 6 - 0.5) * 1.2))


func _look(pos: Vector3, at: Vector3) -> void:
	cam.position = pos
	cam.look_at(at)


func _shot(n: String) -> void:
	for i in 8:
		await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := out.path_join("lootground_%s.png" % n)
	get_viewport().get_texture().get_image().save_png(path if path.begins_with("/") else ProjectSettings.globalize_path(path))
	print("shot ", path)


func _run() -> void:
	_gear_grid()
	for night in [true, false]:
		_light(night)
		var tag := "night" if night else "lit"
		_look(Vector3(0, 5.2, 4.6), Vector3(0, 0.1, 0.2))
		await _shot("gear_%s" % tag)
		for si in GearDB.SLOTS.size():
			var z := (si - 1.5) * 1.1
			_look(Vector3(0, 1.9, z + 2.5), Vector3(0, 0.1, z))
			await _shot("gear_%s_%s" % [GearDB.SLOTS[si], tag])
	_clear()
	_things_grid()
	for night in [true, false]:
		_light(night)
		var tag := "night" if night else "lit"
		_look(Vector3(0, 4.6, 4.0), Vector3(0, 0.1, 0.0))
		await _shot("things_%s" % tag)
	# with the beam, motes and name, as a drop really looks, from play distance (about 7 m)
	_clear()
	plain = false
	_gear_grid()
	_light(true)
	_look(Vector3(0, 1.6, 8.5), Vector3(0, 0.9, 0.0))
	await _shot("withbeam_night")
	_clear()
	plain = true
	# partial pickup: take the first entry of a two-entry bag and the shown item changes
	_clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var hi := GearDB.make(rng, {"slot": "focus", "rarity": 3})
	_bag([{"kind": "gear", "piece": hi}, {"kind": "item", "id": "grave_ash", "n": 3}], Vector3(-1, 0, 0))
	await get_tree().process_frame
	var b0: Node = bags[0]
	print("before: item=", b0.get("_item").get_child(0).name)
	b0.call("take", 0)
	await get_tree().process_frame
	await get_tree().process_frame
	print("after: item=", b0.get("_item").get_child(0).name)
	_look(Vector3(0, 2.0, 3.6), Vector3(-1, 0.3, 0))
	await _shot("partial")
