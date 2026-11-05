extends RefCounted
## World reactivity (secrets): the valley answers each boss, and keeps the answer (it is re-applied
## from Travel.bosses_slain on every load; State "react" only says the live beat has been played).
##   thornwarden      the Thornwood's brambles wither (flora buffers scaled down and greyed, the
##                    henge's hedge goes dead and dark) and moonlight breaks through the canopy
##                    (soft shafts in the deep wood)
##   bone_abbot       the fen pools clear (a calmer, clearer copy of the water material on the
##                    FenWater node) and the drowned graves rest: candles burn on them
##   (all three)      the vortex sky calms in stages: its spin, twist, intensity and rim are offset
##                    at runtime on the existing sky material from remembered base values (never
##                    saved; a reload starts from the shader's own values and re-applies)
##   seal marks       where a ward seal broke: a scorched ring and its debris (cut thorn, fallen bone
##                    bars, shattered light) stay on the ground

const Kit := preload("res://core/life/secrets/kit.gd")
const State := preload("res://core/life/secrets/state.gd")

const THORNWOOD := Rect2(-110.0, -70.0, 80.0, 115.0)
const SHAFTS := [Vector2(-95, -30), Vector2(-80, -50), Vector2(-62, -40), Vector2(-90, 4), Vector2(-104, -12), Vector2(-84, -26), Vector2(-66, 28)]
const GRAVES := [Rect2(50, 17, 10, 10), Rect2(87, 3, 10, 10), Rect2(65, -9, 10, 10), Rect2(56.5, -33.5, 7, 7)]
const CALM := {"thornwarden": 0.2, "bone_abbot": 0.2, "ascended_warden": 0.6}
const SKY_KEYS := ["spin_speed", "twist", "intensity", "col_hex"]

static var _sky_base := {}          ## sky material instance id -> {param: base value}
static var calm := 0.0              ## the sky's current calm (0 = as built, 1 = still)
static var _host: Node3D


static func release() -> void:
	_host = null
	_sky_base.clear()


static func build(root: Node, host: Node3D) -> void:
	_host = host
	for id: String in CALM:
		if Travel.bosses_slain.has(id):
			apply(root, host, id, false)
	_sky(root, false)
	seal_marks(root, host, false)


static func apply(root: Node, host: Node3D, id: String, animate: bool) -> void:
	match id:
		"thornwarden":
			_wither(root, animate)
			_moonlight(root, host, animate)
		"bone_abbot":
			_fen(root, host, animate)
	_sky(root, animate)
	if animate:
		var line: String = {"thornwarden": "In the Thornwood the brambles let go, and the moon comes through.",
			"bone_abbot": "Out in the fen the water stills. Someone has lit candles on the drowned graves."}.get(id, "")
		# (the Warden's fall has no toast: story.gd says "The sky stops turning." while it does)
		if line != "":
			State.toast(line)


# --- the Thornwood ------------------------------------------------------------------------------------

## Brambles in the Thornwood shrink to dead stubs and grey (undergrowth buffers, edited from their
## CPU copy), and the henge hedge goes dead. Idempotent: the original buffer is kept in meta.
static func _wither(root: Node, animate: bool) -> void:
	var flora := root.get_node_or_null("RealmFlora")
	if flora:
		for n in flora.find_children("Flora_bramble*", "MultiMeshInstance3D", true, false):
			var mmi := n as MultiMeshInstance3D
			var mm := mmi.multimesh
			if mm == null or not mm.has_meta("cpu_buffer") or mm.has_meta("secrets_withered"):
				continue
			var ch := mmi.get_parent() as Node3D
			var c3 := ch.position if ch else Vector3.ZERO
			if not THORNWOOD.grow(8.0).has_point(Vector2(c3.x, c3.z)):
				continue
			var buf: PackedFloat32Array = mm.get_meta("cpu_buffer")
			mm.set_meta("secrets_orig", buf)
			var out := buf.duplicate()
			var stride := 16 if mm.use_colors else 12
			for i in mm.instance_count:
				var o := i * stride
				if not THORNWOOD.has_point(Vector2(out[o + 3] + c3.x, out[o + 11] + c3.z)):
					continue
				for k: int in [0, 4, 8]:              # x column, slight
					out[o + k] *= 0.8
				for k: int in [1, 5, 9]:              # y column: down to stubs
					out[o + k] *= 0.35
				for k: int in [2, 6, 10]:
					out[o + k] *= 0.8
				if stride == 16:
					var g := (out[o + 12] + out[o + 13] + out[o + 14]) / 3.0
					out[o + 12] = g * 0.95
					out[o + 13] = g * 0.82
					out[o + 14] = g * 0.68
			mm.set_meta("secrets_withered", true)
			if animate:
				_tween_buffer(mmi, buf, out, 3.5)
			else:
				mm.buffer = out
			mm.set_meta("cpu_buffer", out)
	var hedge := root.find_child("Brambles", true, false) as MeshInstance3D
	if hedge and not hedge.has_meta("secrets_withered"):
		hedge.set_meta("secrets_withered", true)
		var m := (hedge.material_override as StandardMaterial3D)
		if m:
			var dead := m.duplicate() as StandardMaterial3D
			dead.emission_enabled = false
			dead.albedo_color = Color(0.55, 0.52, 0.5)
			hedge.material_override = dead


static func _tween_buffer(mmi: MultiMeshInstance3D, a: PackedFloat32Array, b: PackedFloat32Array, time: float) -> void:
	var tw := mmi.create_tween()
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(mmi) or mmi.multimesh == null:
			return
		var mix := PackedFloat32Array()
		mix.resize(a.size())
		for i in a.size():
			mix[i] = lerpf(a[i], b[i], t)
		mmi.multimesh.buffer = mix, 0.0, 1.0, time)


## Moonlight through the opened canopy: soft shafts (crossed cards along the moon's direction),
## with a slow drift of motes. Additive, faint, no lights.
static func _moonlight(root: Node, host: Node3D, animate: bool) -> void:
	if host.get_node_or_null("MoonShafts") != null:
		return
	var node := Node3D.new()
	node.name = "MoonShafts"
	host.add_child(node)
	var sp := Kit.space(root)
	var moon_dir := Vector3(0.35, -0.85, 0.4).normalized()
	for l in root.find_children("*", "DirectionalLight3D", true, false):
		moon_dir = -(l as DirectionalLight3D).global_basis.z
		break
	var mesh := QuadMesh.new()
	mesh.size = Vector2(3.4, 16.0)
	mesh.center_offset = Vector3(0, 8.0, 0)
	var mat := Kit.shader_mat("shaft")
	for p: Vector2 in SHAFTS:
		var g := Kit.gy(sp, p.x, p.y)
		var up := -moon_dir
		if up.y < 0.3:
			up = (up + Vector3.UP).normalized()
		for k in 3:
			var yaw := float(k) * PI / 3.0
			var side := Vector3(cos(yaw), 0, sin(yaw)).cross(up).normalized()
			var fwd := side.cross(up).normalized()
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = 70.0
			mi.visibility_range_end_margin = 10.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			node.add_child(mi)
			mi.global_transform = Transform3D(Basis(side, up, fwd), Vector3(p.x, g - 0.5, p.y))
			mi.set_instance_shader_parameter(&"strength", 0.0 if animate else 1.0)
			if animate:
				mi.create_tween().tween_method(func(v: float) -> void: mi.set_instance_shader_parameter(&"strength", v), 0.0, 1.0, 6.0)
		var e := Vfx.emitter(Color(0.5, 0.65, 1.0, 0.6), {"count": 14, "life": 6.0, "speed": Vector2(0.02, 0.12), "size": 0.035, "gravity": 0.01, "radius": 1.4, "turbulence": true, "explosive": 0.0})
		if e:
			e.name = "Motes"
			node.add_child(e)
			e.global_position = Vector3(p.x, g + 2.5, p.y)
			e.visibility_range_end = 40.0


# --- the fen ---------------------------------------------------------------------------------------------

static func _fen(root: Node, host: Node3D, animate: bool) -> void:
	var water := root.find_child("FenWater", true, false) as MeshInstance3D
	if water and not water.has_meta("secrets_clear"):
		water.set_meta("secrets_clear", true)
		var base := water.material_override as ShaderMaterial
		if base:
			var m := base.duplicate() as ShaderMaterial
			water.material_override = m
			var to := {"shallow_color": Color(0.05, 0.075, 0.085), "deep_color": Color(0.012, 0.022, 0.03), "sky_strength": 0.3, "ripple": 0.08, "fade_depth": 0.6}
			for key: String in to:
				var from: Variant = m.get_shader_parameter(key)
				if from == null:
					from = RenderingServer.shader_get_parameter_default(m.shader.get_rid(), key)
				if animate and from != null:
					var k2 := key
					var tw := water.create_tween()
					tw.tween_method(func(t: float) -> void:
						if from is Color:
							m.set_shader_parameter(k2, (from as Color).lerp(to[k2], t))
						elif from is Vector3:
							var c: Color = to[k2]
							m.set_shader_parameter(k2, (from as Vector3).lerp(Vector3(c.r, c.g, c.b), t))
						else:
							m.set_shader_parameter(k2, lerpf(float(from), float(to[k2]), t)), 0.0, 1.0, 8.0)
				else:
					var v: Variant = to[key]
					if from is Vector3 and v is Color:
						v = Vector3((v as Color).r, (v as Color).g, (v as Color).b)
					m.set_shader_parameter(key, v)
	if host.get_node_or_null("FenCandles") != null:
		return
	var node := Node3D.new()
	node.name = "FenCandles"
	host.add_child(node)
	var sp := Kit.space(root)
	var k := OssKit.new()
	k.keep_lanes = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 1340
	var lights := 0
	for r: Rect2 in GRAVES:
		var placed := 0
		for i in 40:
			if placed >= 10:
				break
			var p := r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
			var g := Kit.gy(sp, p.x, p.y)
			if g < -0.86:                      # under the water line: no candle
				continue
			k.candle_cluster(Vector3(p.x, g, p.y), rng.randi_range(3, 5), 0.2, rng)
			placed += 1
		if lights < 4:
			var c := r.get_center()
			Kit.omni(node, Vector3(c.x, Kit.gy(sp, c.x, c.y) + 1.2, c.y), Color(1.0, 0.6, 0.3), 1.1, 7.0)
			lights += 1
	k.commit(node, "CandleBody")
	if animate:
		node.scale = Vector3.ONE
		for c2 in node.get_children():
			if c2 is GeometryInstance3D:
				var gi := c2 as GeometryInstance3D
				gi.transparency = 1.0
				gi.create_tween().tween_property(gi, "transparency", 0.0, 5.0)


# --- the sky -------------------------------------------------------------------------------------------

static func target_calm() -> float:
	var c := 0.0
	for id: String in CALM:
		if Travel.bosses_slain.has(id):
			c += float(CALM[id])
	return clampf(c, 0.0, 1.0)


static func sky_material(root: Node) -> ShaderMaterial:
	for n in root.get_tree().root.find_children("*", "WorldEnvironment", true, false):
		var env := (n as WorldEnvironment).environment
		if env and env.sky and env.sky.sky_material is ShaderMaterial:
			var m := env.sky.sky_material as ShaderMaterial
			if m.shader and String(m.shader.resource_path).ends_with("vortex.gdshader"):
				return m
	return null


static func _sky(root: Node, animate: bool) -> void:
	var m := sky_material(root)
	if m == null:
		return
	var key := m.get_instance_id()
	if not _sky_base.has(key):
		var b := {}
		for p: String in SKY_KEYS:
			var v: Variant = m.get_shader_parameter(p)
			if v == null:
				v = RenderingServer.shader_get_parameter_default(m.shader.get_rid(), p)
			b[p] = v
		_sky_base[key] = b
	var to := target_calm()
	if animate and absf(to - calm) > 0.01 and _host and _host.is_inside_tree():
		var tw := _host.create_tween()
		# the last calm (the Warden) stops the spin under the ending's first lines (story.gd)
		tw.tween_method(func(c: float) -> void: _set_sky(m, c), calm, to, 9.0 if to >= 0.99 else 18.0).set_trans(Tween.TRANS_SINE)
	else:
		_set_sky(m, to)


static func _set_sky(m: ShaderMaterial, c: float) -> void:
	calm = c
	var b: Dictionary = _sky_base.get(m.get_instance_id(), {})
	if b.is_empty():
		return
	if b.spin_speed != null:
		# 1 - 0.82c for the first two calms; the Warden's last 0.6 takes it the rest of the way to
		# still: "The sky stops turning." (r30 story). The shader's angle is sky_time * spin_speed,
		# so spin_phase absorbs each change: the arms ease to a stop instead of sweeping back.
		var s := float(b.spin_speed) * (1.0 - 0.82 * c) * (1.0 - smoothstep(0.4, 1.0, c))
		var was: Variant = m.get_shader_parameter("spin_speed")
		var ph: Variant = m.get_shader_parameter("spin_phase")
		if was != null:
			var t := Time.get_ticks_msec() * 0.001          # = the sky_time global (zone.gd)
			m.set_shader_parameter("spin_phase", (float(ph) if ph != null else 0.0) + t * (float(was) - s))
		m.set_shader_parameter("spin_speed", s)
	if b.twist != null:
		m.set_shader_parameter("twist", float(b.twist) - 1.6 * c)
	if b.intensity != null:
		m.set_shader_parameter("intensity", float(b.intensity) * (1.0 - 0.28 * c))
	if b.col_hex != null:
		var h: Variant = b.col_hex
		if h is Vector3:
			m.set_shader_parameter("col_hex", (h as Vector3) * (1.0 - 0.6 * c))
		elif h is Color:
			m.set_shader_parameter("col_hex", (h as Color) * (1.0 - 0.6 * c))


# --- seal marks ---------------------------------------------------------------------------------------

static func seal_marks(root: Node, host: Node3D, animate: bool) -> void:
	if root == null or not root.is_inside_tree():
		return
	for n in root.get_tree().get_nodes_in_group(&"ward_seal"):
		var s := n as Node3D
		if s == null or s.has_meta("secrets_marked") or not s.has_method("is_open") or not bool(s.call("is_open")):
			continue
		s.set_meta("secrets_marked", true)
		var sid := String(s.get("seal_id"))
		State.mark("marks", sid, false)
		_mark(s, String(s.get("look")), Vector2(s.get("size")), animate)


static func _mark(seal: Node3D, look: String, size: Vector2, animate: bool) -> void:
	var node := Node3D.new()
	node.name = "SealMark"
	seal.add_child(node)            # rides with the seal (the Ossuary's streams in and out)
	node.top_level = true
	node.global_transform = Transform3D(seal.global_basis, seal.global_position)
	var q := QuadMesh.new()
	q.size = Vector2(size.x + 2.6, size.x + 2.6)
	q.orientation = PlaneMesh.FACE_Y
	var ring := MeshInstance3D.new()
	ring.mesh = q
	ring.material_override = Kit.shader_mat("scorch")
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tint := {"bone": Color(0.85, 0.75, 0.55), "thorn": Color(0.7, 0.15, 0.12), "light": Color(0.55, 0.45, 1.0)}.get(look, Color(0.6, 0.5, 1.0)) as Color
	ring.set_instance_shader_parameter(&"tint", tint)
	ring.set_instance_shader_parameter(&"glow", 0.35 if look == "light" else 0.18)
	node.add_child(ring)
	ring.position = Vector3(0, 0.035, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(seal.global_position.x * 13.0 + seal.global_position.z * 7.0))
	var k := OssKit.new()
	k.keep_lanes = false
	match look:
		"bone":
			for i in 7:
				var p := Vector3(rng.randf_range(-size.x * 0.6, size.x * 0.6), 0.05, rng.randf_range(-1.2, 1.2))
				k.bone(seal.global_transform * p, Basis(Vector3.UP, rng.randf() * TAU).rotated(Vector3.FORWARD, PI * 0.5), 0, false)
			for i in 3:
				var p2 := Vector3(rng.randf_range(-size.x * 0.5, size.x * 0.5), 0.05, rng.randf_range(-0.8, 0.8))
				k.box("iron", seal.global_transform * p2, Vector3(rng.randf_range(0.6, 1.4), 0.07, 0.06), seal.global_basis.rotated(Vector3.UP, rng.randf_range(-0.6, 0.6)), false)
		"thorn":
			var cm := CreatureMesh.new(13)
			for i in 9:
				var a := rng.randf() * TAU
				var o := Vector3(rng.randf_range(-size.x * 0.6, size.x * 0.6), 0.06, rng.randf_range(-1.4, 1.4))
				var pts := PackedVector3Array()
				var rad := PackedFloat32Array()
				for qq in 5:
					var t := float(qq) / 4.0
					pts.append(o + Vector3(cos(a) * t * 1.6, 0.05 + sin(t * 3.0) * 0.08, sin(a) * t * 1.6 + sin(t * 6.0) * 0.2))
					rad.append(lerpf(0.06, 0.02, t))
				cm.tube(pts, rad, 5, Color(0.3, 0.26, 0.22), 0.0, 0.2)
			var tm := MeshInstance3D.new()
			tm.mesh = cm.commit()
			tm.material_override = Kit.mat("thorn_dead")
			node.add_child(tm)
		"light":
			for i in 12:
				var p3 := Vector3(rng.randf_range(-size.x * 0.6, size.x * 0.6), 0.05, rng.randf_range(-1.5, 1.5))
				k.box("slate", seal.global_transform * p3, Vector3(rng.randf_range(0.1, 0.35), 0.04, rng.randf_range(0.06, 0.2)), Basis(Vector3.UP, rng.randf() * TAU), false, 0.6)
			var shards := Node3D.new()
			node.add_child(shards)
			for i in 6:
				var p4 := Vector3(rng.randf_range(-size.x * 0.5, size.x * 0.5), 0.06, rng.randf_range(-1.0, 1.0))
				var sm := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.05, 0.02, rng.randf_range(0.15, 0.4))
				sm.mesh = bm
				sm.material_override = Kit.mat("rune_lit")
				sm.transparency = 0.55
				shards.add_child(sm)
				sm.global_transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU), seal.global_transform * p4)
	var tmp := Node3D.new()
	tmp.top_level = true
	node.add_child(tmp)
	k.commit(tmp, "MarkBody")
	if animate:
		for c in node.find_children("*", "GeometryInstance3D", true, false):
			var gi := c as GeometryInstance3D
			var t0 := gi.transparency
			gi.transparency = 1.0
			gi.create_tween().tween_property(gi, "transparency", t0, 3.0)
