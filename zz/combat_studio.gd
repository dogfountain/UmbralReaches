extends Node3D
## Studio renders of every enemy kind and boss under a moonlit night rig (azure key, warm lantern
## fill, violet rim), front-3/4 and side, plus a contact sheet. Before/after comparisons:
##   godot --path . res://zz/combat_studio.tscn -- --tag=before [--only=wretch,husk] [--pose=windup]
## -> shots/combat/<tag>_<kind>_<view>.png and shots/combat/<tag>_sheet.png
const KINDS := {
	"wretch": "res://core/enemy/wretch.gd", "husk": "res://core/enemy/husk.gd",
	"spitter": "res://core/enemy/spitter.gd", "crawler": "res://core/enemy/crawler.gd",
	"leaper": "res://core/enemy/leaper.gd", "ossuant": "res://core/enemy/ossuant.gd",
	"thornwarden": "res://core/enemy/thornwarden.gd", "bone_abbot": "res://core/enemy/bone_abbot.gd",
	"ascended_warden": "res://core/enemy/ascended_warden.gd",
	"hierarch": "res://core/enemy/hierarch_voice.gd", "anchoress": "res://core/enemy/anchoress.gd",
	"bulwark": "res://core/enemy/bulwark.gd", "chanter": "res://core/enemy/chanter.gd",
	"burrower": "res://core/enemy/burrower.gd", "mite": "res://core/enemy/mite.gd",
	# r31 (docs/enshrouded/enemies.md)
	"gaunt": "res://core/enemy/gaunt.gd", "quiller": "res://core/enemy/quiller.gd",
	"tollman": "res://core/enemy/tollman.gd", "brood_mother": "res://core/enemy/brood_mother.gd",
	# r34
	"pilgrim": "res://core/enemy/pilgrim.gd", "cinder_caster": "res://core/enemy/cinder_caster.gd",
}
var tag := "shot"
var pose := ""
var order: Array[String] = []
var cam: Camera3D
var cur: Enemy
var ki := 0
var vi := 0
var t := 0.0
var saved: Array[String] = []

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="): tag = a.trim_prefix("--tag=")
		elif a.begins_with("--pose="): pose = a.trim_prefix("--pose=")
		elif a.begins_with("--size="):
			var wh := a.trim_prefix("--size=").split("x")
			if wh.size() == 2: get_window().size = Vector2i(int(wh[0]), int(wh[1]))
		elif a.begins_with("--only="):
			for k in a.trim_prefix("--only=").split(","):
				if KINDS.has(k):
					order.append(k)
				else:
					print("STUDIO unknown kind '%s' skipped (known: %s)" % [k, ", ".join(KINDS.keys())])
	if order.is_empty():
		for k: String in KINDS: order.append(k)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/combat"))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.035, 0.05, 0.1)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.3, 0.42, 0.7)
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.2
	e.glow_enabled = true
	e.glow_intensity = 0.62
	e.glow_bloom = 0.06
	e.glow_hdr_threshold = 1.15
	for i in 7: e.set_glow_level(i, 1.0 if i <= 1 else 0.0)
	env.environment = e
	add_child(env)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.45, 0.73, 1.0)
	moon.light_energy = 1.05
	moon.shadow_enabled = true
	moon.rotation = Vector3(-0.75, 0.9, 0)
	add_child(moon)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.62, 0.3)
	lamp.light_energy = 2.2
	lamp.omni_range = 9.0
	lamp.position = Vector3(-2.2, 1.6, -2.4)
	add_child(lamp)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.16, 0.16, 0.18)
	fm.roughness = 0.95
	pm.material = fm
	floor_mi.mesh = pm
	add_child(floor_mi)
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(40, 1, 40)
	cs.shape = bs
	cs.position.y = -0.5
	body.add_child(cs)
	add_child(body)
	cam = Camera3D.new()
	cam.fov = 38.0
	add_child(cam)
	cam.current = true
	_spawn()

func _spawn() -> void:
	if is_instance_valid(cur):
		cur.queue_free()
	var scr := load(KINDS[order[ki]]) as GDScript
	cur = scr.new() as Enemy
	if "dormant" in cur:
		cur.set("dormant", false)      # a Pilgrim lies in its grave until woken
	add_child(cur)
	cur.global_position = Vector3.ZERO
	cur.rotation.y = 0.0
	cur.sleep()
	if pose == "windup" and cur._rig and cur._rig.has_method("telegraph"):
		cur._rig.call("telegraph", 30.0)
		# the ground telegraphs, mid-fill: a strike cone in front, a pounce disc and a lane beside
		SpellFx.danger(Vector3.ZERO, 1.2, {"radius": cur.strike_range + 0.45, "half_angle": deg_to_rad(cur.strike_arc), "yaw": 0.0, "hold": 5.0})
		SpellFx.danger(Vector3(-2.2, 0, 0.5), 1.2, {"radius": 1.5, "hold": 5.0})
		SpellFx.danger(Vector3(2.0, 0, 1.5), 1.2, {"rect": Vector2(0.45, 2.0), "yaw": 0.0, "color": Color(0.3, 1.6, 1.1), "hold": 5.0})
	if pose == "spikes":                            # the bosses' eruptions, either side (r30)
		BossKit.spikes(self, Vector3(-1.4, 0, -1.4), {"radius": 1.1}, "bone")
		BossKit.spikes(self, Vector3(1.9, 0, 0.6), {"radius": 1.2}, "thorn")
	if cur._hp_bar: cur._hp_bar.visible = false
	t = 0.0
	vi = 0

func _process(d: float) -> void:
	t += d
	if cur == null: return
	if cur._rig:
		if pose == "windup":                         # hold the rear-up at its peak
			if cur._rig.get("_wind_t") != null:
				cur._rig.set("_wind_dur", 0.5)
				cur._rig.set("_wind_t", 0.4)
			elif cur._rig.get("_gesture_t") != null:
				cur._rig.set("_coil_dur", 0.5)
				cur._rig.set("_gesture_t", 0.4)
		cur._rig.animate(Vector3.ZERO, true, d)     # the enemy is asleep; pose its rig by hand
	var h := maxf(cur.hp_bar_y, 1.0)
	var look := Vector3(0, h * 0.5, 0)
	var dist := h * 1.7 + 0.7
	var views := [Vector3(-0.62, 0.32, -1.0), Vector3(-1.0, 0.18, 0.08), Vector3(0.55, 0.25, 1.0)]
	cam.global_position = look + views[vi].normalized() * dist
	cam.look_at(look)
	if t > 0.45:
		var path := "res://shots/combat/%s_%s_%d.png" % [tag, order[ki], vi]
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		saved.append(ProjectSettings.globalize_path(path))
		vi += 1
		t = 0.3
		if vi >= views.size():
			ki += 1
			if ki >= order.size():
				_sheet()
				print("STUDIO saved ", saved.size())
				get_tree().quit()
				return
			_spawn()

func _sheet() -> void:
	var tw := 420
	var ims: Array[Image] = []
	for p in saved:
		var im := Image.load_from_file(p)
		if im: ims.append(im)
	if ims.is_empty(): return
	var th := int(float(tw) * float(ims[0].get_height()) / float(ims[0].get_width()))
	var cols := 4
	var rows := ceili(float(ims.size()) / float(cols))
	var sheet := Image.create(tw * cols, th * rows, false, Image.FORMAT_RGB8)
	for i in ims.size():
		var im := ims[i]
		im.convert(Image.FORMAT_RGB8)
		im.resize(tw, th, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(im, Rect2i(0, 0, tw, th), Vector2i((i % cols) * tw, (i / cols) * th))
	sheet.save_png(ProjectSettings.globalize_path("res://shots/combat/%s_sheet.png" % tag))
