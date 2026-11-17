extends Node
## The living night's pure parts, headless, no world:
##   godot --headless --path . res://zz/night_life_test.tscn
## The source registry (rows, kinds, shimmer bounds), the windows' bedtimes, the pose smoother (a mode change is a continuous blend, the spring
## never overshoots below zero), the constellation bake, the folk's definitions, and the new villager tools (each builds, each has a working end).
## Ends: NIGHTLIFE PASS / NIGHTLIFE FAIL n

const Reg := preload("res://core/world/night_life/night_registry.gd")
const Windows := preload("res://core/world/night_life/living_windows.gd")
const Smooth := preload("res://core/enemy/pose_smooth.gd")
const Sky := preload("res://core/world/night_life/sky_life.gd")
const Stage := preload("res://core/life/folk/folk_stage.gd")
const Roles := preload("res://core/life/folk/folk_roles.gd")
const Rig := preload("res://core/life/village/villager_rig.gd")
const Arena := preload("res://core/world/night_life/arena_light.gd")

var bad := 0


func ok(c: bool, what: String) -> void:
	print(("NIGHTLIFE ok   " if c else "NIGHTLIFE FAIL ") + what)
	if not c:
		bad += 1


func _ready() -> void:
	_registry()
	_windows()
	_smooth()
	_sky()
	_folk()
	_arena()
	_tools()
	print("NIGHTLIFE PASS" if bad == 0 else "NIGHTLIFE FAIL %d" % bad)
	get_tree().quit(1 if bad > 0 else 0)


func _registry() -> void:
	Reg.clear()
	var a := Reg.put("a", Vector3(1, 2, 3), Reg.Kind.FIRE, 1.0, 0.0, true)
	var b := Reg.put("b", Vector3(4, 5, 6), Reg.Kind.MYSTERY, 0.8, 1.0)
	ok(Reg.size() == 2 and a == 0 and b == 1, "two rows")
	ok(Reg.put("a", Vector3(9, 9, 9), Reg.Kind.FIRE, 1.0, 0.0, true) == 0 and Reg.size() == 2, "a key updates its row")
	Reg.set_on("b", false)
	ok(not Reg.is_on("b") and Reg.is_on("a"), "a row switches off")
	var lo := 9.0
	var hi := -9.0
	for k in 5:
		Reg.put("k%d" % k, Vector3.ZERO, k, 1.0, 0.0)
	for i in Reg.size():
		for step in 200:
			var v := Reg.shimmer(i, float(step) * 0.37)
			lo = minf(lo, v)
			hi = maxf(hi, v)
	ok(lo > 0.0 and hi <= 1.001, "every shimmer stays in (0, 1] (%.2f .. %.2f)" % [lo, hi])
	ok(Reg.colour(Reg.Kind.FIRE).r > Reg.colour(Reg.Kind.FIRE).b and Reg.colour(Reg.Kind.MYSTERY).b > Reg.colour(Reg.Kind.MYSTERY).r, "fire is warm, a mystery is cold")
	Reg.clear()


func _windows() -> void:
	ok(Windows.lamp_on(0.1, 2.0, 0.5, 0.0), "a lamp is lit between opening and closing")
	ok(not Windows.lamp_on(0.1, 2.0, 0.05, 0.0), "and dark before it opens")
	ok(not Windows.lamp_on(0.1, 0.6, 0.7, 0.0), "and dark after it closes")
	var flick := 0
	for i in 400:
		if not Windows.lamp_on(0.1, 0.6, 0.59, float(i) * 0.05):
			flick += 1
	ok(flick > 0 and flick < 400, "a lamp gutters in its last stretch (%d of 400 samples dark)" % flick)


func _smooth() -> void:
	var s := Smooth.new(3, 2)
	for i in 3:
		s.raw_q[i] = Quaternion.IDENTITY
	s.commit(0.016)
	s.mode_changed(0.2)
	for i in 3:
		s.raw_q[i] = Quaternion(Vector3.UP, 1.5)
	var last := 0.0
	var mono := true
	var worst := 0.0
	for step in 20:
		s.commit(0.016)
		var ang := s.cur_q[0].get_angle()
		if ang < last - 1e-4:
			mono = false
		worst = maxf(worst, ang - last)
		last = ang
	ok(mono, "a mode change blends monotonically")
	ok(worst < 0.5, "and in no one step by more than %.2f rad (a snap is 1.5)" % worst)
	ok(absf(s.cur_q[0].get_angle() - 1.5) < 0.05, "arriving at the new pose")
	var x := 0.0
	var v := 38.0
	var min_x := 0.0
	var peak := 0.0
	for step in 120:
		var r := Smooth.spring(x, v, 0.0, 14.0, 1.0 / 60.0)
		x = r.x
		v = r.y
		min_x = minf(min_x, x)
		peak = maxf(peak, x)
	ok(min_x > -0.02, "the spring does not swing past zero (%.3f)" % min_x)
	ok(peak > 0.7 and peak < 1.3, "an impulse of 38 peaks near 1 (%.2f)" % peak)
	ok(absf(x) < 0.01, "and settles")


func _sky() -> void:
	var sky := Sky.new()
	var tex: ImageTexture = sky._bake()
	ok(tex != null and tex.get_width() == 512 and tex.get_height() == 256, "the constellation texture is 512 x 256")
	var img := tex.get_image()
	var lit := 0
	for y in 256:
		for x in 512:
			if img.get_pixel(x, y).r > 0.05:
				lit += 1
	ok(lit > 150 and lit < 6000, "it holds stars and lines but is mostly dark (%d lit pixels)" % lit)
	var uv := Sky._uv(0.0, 0.0, 512, 256)
	ok(absf(uv.x - 256.0) < 0.1 and absf(uv.y - 128.0) < 0.1, "north on the horizon is the middle of the map")
	sky.free()


func _folk() -> void:
	var st := Stage.new()
	var defs: Array = st._definitions()
	ok(defs.size() == 13, "thirteen folk are defined (%d)" % defs.size())
	var ids := {}
	var roles := {}
	var good := true
	for d: Dictionary in defs:
		ids[d.id] = true
		roles[d.role] = true
		good = good and d.has("at") and d.has("look") and d.has("face")
	ok(ids.size() == defs.size(), "their ids are distinct")
	ok(good, "each has a place, a look and a facing")
	for r: String in ["sweeper", "fiddler", "dancer", "porter", "waterbearer", "kid", "watchman", "mourner", "netmender", "talk_a", "talk_b"]:
		ok(roles.has(r), "role %s present" % r)
	ok(Roles.node_pos("keg", Vector2.ZERO) != Vector2.ZERO, "the Keg's step is found among the village's nodes")
	st.free()


func _arena() -> void:
	for t: String in ["The Thornwarden", "The Bone Abbot", "The Ascended Warden", "The Anchoress", "The Speaking Crown"]:
		var pal := Arena.palette_for(t)
		ok(pal.size() == 3, "%s has three phase palettes" % t)
	ok(Arena.palette_for("The Bone Abbot") != Arena.palette_for("The Thornwarden"), "and the palettes differ")


func _tools() -> void:
	for kind: String in ["broom", "bucket", "sack", "fiddle", "bow", "torch"]:
		var rig: Variant = Rig.create({"seed": 77, "sex": "m", "age": "adult", "garment": "shirt", "r": kind})
		add_child(rig)
		var tip: Vector3 = (rig.tips as Array)[0]
		ok(tip.length() > 0.05, "a villager's %s builds and has a working end (%.2f m from the origin)" % [kind, tip.length()])
		rig.queue_free()
