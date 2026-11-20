extends RefCounted
## THE SINGING STONES (r28, agent D): four hollow standing stones of the Rooted in a ring near the
## Glimmer Glade, a small listening stone in the middle. Touch the small stone and it sings a
## phrase of four notes, each stone's mouth glowing as its note sounds; sing it back into the four
## stones in the same order. A wrong note and they go quiet (a dull knock) and wait. Sung right,
## the stones answer together, pale wisps wake and circle over the ring for good, and the root-lid
## beside it slides back off a hollow with the Rooted's offering in it.
## Sound and light both carry the phrase (the glow is there for anyone who cannot hear it).

const Kit := preload("res://core/life/secrets/kit.gd")
const State := preload("res://core/life/secrets/state.gd")
const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const PlacementLog := preload("res://core/world/realm/placement_log.gd")
const Access := preload("res://ui/access.gd")
const GLOW := Color(0.5, 0.85, 1.0)
const SELF := "res://core/life/secrets/site_glade.gd"

const GLADE_NEAR := Vector2(-36.0, 24.0)      ## searched outward from here for clear, level ground
const R := 3.3
const PHRASE := [2, 0, 3, 1]
const TONES := ["stone0", "stone1", "stone2", "stone3"]

static var _seq: Array[int] = []
static var _seq_t := 0.0
static var _mouths: Array[MeshInstance3D] = []


static func release() -> void:
	_mouths.clear()
	_seq.clear()


static func build(root: Node, host: Node3D) -> void:
	# a fresh build is a cold one: puzzle progress that is not the save does not outlive its night
	_seq.clear()
	_seq_t = 0.0
	_mouths.clear()
	var sp := Kit.space(root)
	var c2 := LK.search_spot(sp, GLADE_NEAR, 48.0, Vector2(4.8, 4.8), 1.0, 1.7, ["secrets_singing"], 3.0, func(q: Vector2) -> bool: return Kit.gy(sp, q.x, q.y) > -0.5)
	if c2 == Vector2.INF:
		print("SECRETS singing stones: no clear spot")
		PlacementLog.skip("secrets", "singing_stones", Vector3(GLADE_NEAR.x, 0, GLADE_NEAR.y), "no clear spot")
		return
	var node := Node3D.new()
	node.name = "SingingStones"
	node.set_meta("site", "secrets_singing")
	host.add_child(node)
	var gy := Kit.low(sp, c2, 3.0)
	var c := Vector3(c2.x, gy, c2.y)
	Kit.clear_flora(root, [Vector3(c2.x, c2.y, 6.5)])
	Kit.site(root, "secrets_singing", Rect2(c2.x - 5.0, c2.y - 5.0, 10.0, 10.0), gy)
	var k := OssKit.new()
	k.keep_lanes = false
	LK.ensure_mats()
	var rng := RandomNumberGenerator.new()
	rng.seed = 6161
	_mouths.clear()
	var stones: Array[Node3D] = []
	var menhir := Kit.cached_mesh("singer", func() -> ArrayMesh:
		var cm := CreatureMesh.new(6262)
		cm.blob(Vector3(0, 1.0, 0), Vector3(0.48, 1.05, 0.4), Basis.IDENTITY, Color(1, 1, 1), 0.0, 0.2, 0.0, 8, 10)
		cm.blob(Vector3(0, 1.95, 0.02), Vector3(0.3, 0.22, 0.3), Basis.IDENTITY, Color(0.95, 0.95, 0.95), 0.0, 0.25, 0.0, 5, 8)
		return cm.commit(), true, SELF)
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		var q := Vector2(c2.x + cos(a) * R, c2.y + sin(a) * R)
		var g := Kit.gy(sp, q.x, q.y)
		var inward := Vector3(c2.x - q.x, 0, c2.y - q.y).normalized()
		var yaw := atan2(inward.x, inward.z)
		var s := 0.9 + 0.12 * float((i * 7) % 3)
		var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -0.05)
		var at := Vector3(q.x, g - 0.25, q.y)
		LK.organic(k, "lore_moss", menhir, Transform3D(b.scaled(Vector3(1, s, 1)), at), false)
		Kit.box_body(node, at + Vector3.UP * 1.0 * s, Vector3(0.8, 2.0 * s, 0.7), b)
		# the mouth: a dark hollow on the inner face, and a ring of carved spirals round it
		var mouth_at := at + b * Vector3(0, 1.25 * s, 0.38)
		k.box("dark", mouth_at, Vector3(0.22, 0.3, 0.06), b, false, 0.3)
		for j in 6:
			var ra := TAU * float(j) / 6.0
			k.box("lore_tstone", mouth_at + b * Vector3(cos(ra) * 0.24, sin(ra) * 0.28, 0.01), Vector3(0.06, 0.06, 0.03), b, false, 1.1)
		var glow := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.9, 0.9)
		glow.mesh = qm
		glow.material_override = Kit.shader_mat("glint")
		glow.set_instance_shader_parameter(&"tint", GLOW)
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.visibility_range_end = 60.0
		node.add_child(glow)
		glow.global_position = mouth_at + inward * 0.12
		glow.visible = false
		_mouths.append(glow)
		var idx := i
		var t := Kit.touch(node, mouth_at + inward * 0.5, "", func(_by: Node) -> void: sing(idx, mouth_at), 2.2)
		t.name = "Singer_%d" % i
		t.set("prompt_fn", func() -> String: return "" if State.has("solved", "singing") else "Sing into the stone")
		stones.append(t)
		L_cairn(k, at + inward * -0.9 + Vector3.UP * 0.25, rng)
	# the listening stone: low, flat, a spiral cut in its top
	var ls := Kit.cached_mesh("listener", func() -> ArrayMesh:
		var cm := CreatureMesh.new(6363)
		cm.blob(Vector3(0, 0.22, 0), Vector3(0.62, 0.3, 0.5), Basis.IDENTITY, Color(1, 1, 1), 0.0, 0.2, 0.0, 6, 10)
		return cm.commit(), true, SELF)
	LK.organic(k, "lore_moss", ls, Transform3D(Basis(Vector3.UP, 0.5), c), false)
	Kit.box_body(node, c + Vector3.UP * 0.25, Vector3(1.0, 0.5, 0.8), Basis(Vector3.UP, 0.5))
	for j in 14:
		var ra := float(j) * 0.7
		var rr := 0.04 + 0.022 * float(j)
		k.box("dark", c + Vector3(cos(ra) * rr, 0.53, sin(ra) * rr), Vector3(0.05, 0.01, 0.05), Basis(Vector3.UP, -ra), false, 0.6)
	var lt := Kit.touch(node, c + Vector3.UP * 0.7, "", func(_by: Node) -> void: listen(c), 2.0)
	lt.name = "Listen"
	lt.set("prompt_fn", func() -> String: return "Listen to the small stone" if not State.has("solved", "singing") else "")
	# the root-lid: a slab ringed by rough stones beside the ring, the Rooted's offering under it
	var hollow2 := c2 + Vector2(cos(-0.3), sin(-0.3)) * (R + 2.1)
	var hg := Kit.gy(sp, hollow2.x, hollow2.y)
	var hollow := Vector3(hollow2.x, hg, hollow2.y)
	for j in 8:
		var ra := TAU * float(j) / 8.0
		k.box("lore_rock", hollow + Vector3(cos(ra) * 0.75, 0.08, sin(ra) * 0.75), Vector3(0.32, 0.22, 0.26), Basis(Vector3.UP, ra + rng.randf()), false, 0.8)
	k.box("dark", hollow + Vector3.UP * 0.01, Vector3(1.0, 0.02, 1.0), Basis.IDENTITY, false, 0.2)
	k.box("lore_bronze", hollow + Vector3.UP * 0.12, Vector3(0.3, 0.24, 0.3), Basis(Vector3.UP, 0.4), false, 0.9)   # the offering bowl
	k.commit(node, "SingersBody")
	_fade(node, 120.0)
	var lid := Kit.mi(node, _box(Vector3(1.15, 0.16, 1.15)), OssKit.mat("lore_tstone"), Transform3D(Basis(Vector3.UP, 0.2), hollow + Vector3.UP * 0.12), 70.0)
	var door := Kit.box_body(node, hollow + Vector3.UP * 0.2, Vector3(1.15, 0.4, 1.15))
	State.cache(node, "singing", hollow + Vector3.UP * 0.4, "the Rooted's offering", Callable(), func() -> bool: return State.has("solved", "singing"))
	State.reading(node, "sc_sing_listen", c + Vector3(0.0, 0.7, -0.9))
	State.reading(node, "sc_sing_done", hollow + Vector3(0.9, 0.5, 0.0))
	# the wisps: pale motes circling over the ring once the stones have answered
	var wisps := Node3D.new()
	wisps.name = "Wisps"
	node.add_child(wisps)
	wisps.global_position = c + Vector3.UP * 2.4
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var mq := QuadMesh.new()
	mq.size = Vector2(0.28, 0.28)
	mm.mesh = mq
	mm.instance_count = 14
	for j in 14:
		var ra := TAU * float(j) / 14.0
		var rr := R * (0.6 + 0.4 * float(j % 3) / 2.0)
		mm.set_instance_transform(j, Transform3D(Basis.IDENTITY, Vector3(cos(ra) * rr, sin(ra * 3.0) * 0.6 + float(j % 2) * 0.5, sin(ra) * rr)))
		mm.set_instance_color(j, Color(1, 1, 1, 0.7 + 0.3 * float(j % 2)))
	var mmi := MultiMeshInstance3D.new()
	mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # static: interpolating a MultiMesh makes its add wait on the GPU (zz/stream_probe.gd)
	mmi.multimesh = mm
	mmi.material_override = Kit.shader_mat("mote")
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 90.0
	wisps.add_child(mmi)
	print("SITES SingingStones owns %d scatter nodes" % WorldLanes.own(wisps))   # the motes circle inside the site
	var spin := wisps.create_tween().set_loops()
	spin.tween_property(wisps, "rotation:y", TAU, 38.0).from(0.0)
	var wl := Kit.omni(wisps, wisps.global_position, Color(0.55, 0.85, 1.0), 0.8, 9.0)
	wl.name = "WispLight"
	var sync := func(animate: bool) -> void:
		var done := State.has("solved", "singing")
		wisps.visible = done
		Kit.set_body(door, not done)
		for m in _mouths:
			if is_instance_valid(m):
				m.visible = done
		var to := Transform3D(Basis(Vector3.UP, 0.2) * Basis(Vector3.BACK, 0.25), hollow + Vector3(-1.05, 0.2, 0.25))
		if done and animate:
			Kit.play("grind", hollow, -4.0, 1.4)
			lid.create_tween().tween_property(lid, "global_transform", to, 1.6).set_trans(Tween.TRANS_SINE)
		elif done:
			lid.global_transform = to
	State.register({"id": "singing", "name": "The Singing Stones", "at": c, "r": 7.0, "node": node, "sync": sync,
		"stones": stones, "phrase": PHRASE, "door": door, "inside": hollow + Vector3(-0.6, 0.0, 0.9),
		"route": {"from": Vector3(c2.x + 10.0, 0.0, c2.y + 4.0), "pts": [Vector3(c2.x + 6.0, 0, c2.y + 2.0), Vector3(c2.x + 1.2, 0, c2.y + 1.6)] as Array[Vector3]},
		"goal": Vector3(c2.x + 1.2, 0, c2.y + 1.6)})
	sync.call(false)


static func L_cairn(k: OssKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	for j in 3:
		k.box("lore_rock", at + Vector3(rng.randf_range(-0.15, 0.15), -0.1 + 0.12 * float(j), rng.randf_range(-0.15, 0.15)), Vector3(0.24 - 0.05 * float(j), 0.12, 0.2 - 0.04 * float(j)), Basis(Vector3.UP, rng.randf() * TAU), false, 0.85)


static func _flat(sp: PhysicsDirectSpaceState3D, c: Vector2, r: float) -> bool:
	var lo := INF
	var hi := -INF
	for i in 9:
		var q := c if i == 8 else c + Vector2(cos(TAU * float(i) / 8.0), sin(TAU * float(i) / 8.0)) * r
		var y := Kit.gy(sp, q.x, q.y)
		lo = minf(lo, y)
		hi = maxf(hi, y)
	return hi - lo < 1.4 and lo > -0.6


## The small stone sings the phrase; each singer's mouth glows with its own note.
static func listen(c: Vector3) -> void:
	_seq.clear()
	var tree := Engine.get_main_loop() as SceneTree
	for i in PHRASE.size():
		var idx: int = PHRASE[i]
		tree.create_timer(0.3 + 0.75 * float(i), false).timeout.connect(func() -> void:
			_flash(idx)
			if idx < _mouths.size() and is_instance_valid(_mouths[idx]):
				Kit.play(TONES[idx], _mouths[idx].global_position, -2.0))


static func _flash(idx: int) -> void:
	if idx >= _mouths.size() or not is_instance_valid(_mouths[idx]):
		return
	var m := _mouths[idx]
	if State.has("solved", "singing"):
		return
	m.visible = true
	var tw := m.create_tween()
	if Access.flash() < 1.0:
		# Reduce Flashes: the same phrase as a slow swell (0.25 s up, a held glow, 0.25 s down) rather than a pop, so it still reads
		# in the puzzle's rhythm (0.75 s a note) without a sudden brightness change. The tint is the glint shader's own brightness.
		var set_k := func(k: float) -> void:
			if is_instance_valid(m):
				m.set_instance_shader_parameter(&"tint", GLOW * k)
		set_k.call(0.0)
		tw.tween_method(set_k, 0.0, 1.0, 0.25)
		tw.tween_interval(0.2)
		tw.tween_method(set_k, 1.0, 0.0, 0.25)
		tw.tween_callback(func() -> void:
			if is_instance_valid(m):
				m.set_instance_shader_parameter(&"tint", GLOW)
				if not State.has("solved", "singing"):
					m.visible = false)
		return
	tw.tween_interval(0.6)
	tw.tween_callback(func() -> void:
		if not State.has("solved", "singing"):
			m.visible = false)


static func sing(idx: int, at: Vector3) -> void:
	if State.has("solved", "singing"):
		Kit.play(TONES[idx], at, -4.0)
		return
	Kit.play(TONES[idx], at, -1.0)
	_flash(idx)
	var now := Time.get_ticks_msec() * 0.001
	if now - _seq_t > 20.0:
		_seq.clear()
	_seq_t = now
	_seq.append(idx)
	var want: int = PHRASE[_seq.size() - 1]
	if idx != want:
		_seq.clear()
		if idx == PHRASE[0]:
			_seq.append(idx)          # a wrong run, but this note starts the phrase again
			return
		Kit.play("thud", at, -3.0)
		State.toast("The stones go quiet. They wait.")
		return
	if _seq.size() < PHRASE.size():
		return
	_seq.clear()
	State.mark("solved", "singing")
	var tree := Engine.get_main_loop() as SceneTree
	for i in 4:
		tree.create_timer(0.7 + 0.08 * float(i), false).timeout.connect(func() -> void:
			if i < _mouths.size() and is_instance_valid(_mouths[i]):
				Kit.play(TONES[i], _mouths[i].global_position, 0.0))
	State.toast("The stones sing it back, all together. Lights wake in the grass, and a root-lid slides aside.")
	State.banner("the wood is sung awake", "The Singing Stones")
	State.refresh(true)


static func _fade(node: Node3D, end: float) -> void:
	for ch in node.get_children():
		if ch is GeometryInstance3D and (ch as GeometryInstance3D).visibility_range_end == 0.0:
			(ch as GeometryInstance3D).visibility_range_end = end
			(ch as GeometryInstance3D).visibility_range_end_margin = end * 0.1
			(ch as GeometryInstance3D).visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b
