class_name Lamp
extends Interactable
## A small light the wanderer kindles: a hanging lamp, a candle niche, a standing lantern, a cresset.
## Unlit until she lights it (the staff gesture, E); then it burns for the rest of the night and the
## save remembers it (State "lamps"). Warm and dim: an emissive flame and, where it matters, one small
## shadowless OmniLight with a short range.
##
## It is NOT gameplay light. It is never registered with LightGrid, so it does not clear the Gloom,
## refill a camp or move the checkpoint: the dark is the clock (docs/PILLARS.md 1), and a fire or a
## brazier is the only thing that answers it. A lamp is comfort and wayfinding, light the wanderer made
## and can see by, earned with a gesture (pillar 2). Lamps others keep ("kept") are pre-lit story
## and have no prompt. A "follower" lights when its leader does (the crown of a wall tower).
##
## Built by lamp_places.gd. Local space: origin at the mount (the ground for post/cresset/free niche, the
## wall plane for a bracket or wall niche, the hook for a hung lamp); +z is out of the wall.

const State := preload("res://core/life/secrets/state.gd")
const Kit := preload("res://core/life/secrets/kit.gd")

const GROUP := &"lamp"                   ## every lamp a wanderer can light (the map and the tally read it)
const WARM := Color(1.0, 0.62, 0.28)
const HEART := Color(1.0, 0.74, 0.34)         ## a flame's pale root
const TIP := Color(0.88, 0.28, 0.07)           ## and its red tip
const PANE := Color(0.95, 0.62, 0.28)         ## lit glass
const FLAME_GLOW := 1.25                 ## flame brightness multiplier: the heart just reaches the glow threshold (1.15), the rest stays under
const ASH := 2                           ## grave ash for the first light of each (a small gift)

static var _meshes: Dictionary = {}
static var _mats: Dictionary = {}

var lamp_id := ""
var look := "post"
var kept := false                        ## pre-lit story: no prompt, nothing saved
var follower := false                    ## lights with its leader
var followers: Array[Lamp] = []
var want_light := true                   ## a real (small) OmniLight when lit
var free_niche := false                  ## a niche standing on its own plinth
var chain := 0.0                         ## a hung lamp's chain (metres) from a ceiling
var lit := false

var _body: MeshInstance3D
var _glow: MeshInstance3D
var _light: OmniLight3D
var _flame_at := Vector3.ZERO
var _light_at := Vector3.ZERO
var _e := 0.9
var _range := 5.5
var _t := 0.0
var _near := true
var _poll := 0.0
var _flare := 0.0
var _phase := 0.0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # its flame is scaled every rendered frame
	var d := _mesh_for(look, free_niche, chain)
	_flame_at = d.flame
	_light_at = d.light
	_e = d.e * 4.0                       # a lamp warms the ground and the wall it stands by, not just its own glass
	_range = d.range * 1.35
	_body = MeshInstance3D.new()
	_body.name = "Body"
	_body.mesh = d.body
	_body.material_override = _mat("body")
	_body.visibility_range_end = 110.0
	_body.visibility_range_end_margin = 10.0
	_body.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(_body)
	_glow = MeshInstance3D.new()
	_glow.name = "Glow"
	_glow.mesh = d.glow
	_glow.position = _flame_at
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow.visibility_range_end = 260.0
	add_child(_glow)
	_phase = randf() * TAU
	var sense := get_node_or_null("InteractSense") as Node3D
	if sense:
		sense.position = _flame_at
	if not kept and not follower:
		add_to_group(Groups.INTERACTABLE)
		add_to_group(GROUP)
	var saved := (not kept) and (not follower) and lamp_id != "" and State.has("lamps", lamp_id)
	_set_lit(kept or saved, false)
	if saved:
		for f in followers:
			f.light_from_leader(false)


func interact_reach() -> float:
	return 2.7


func can_interact() -> bool:
	return not lit and not kept and not follower


func interact_text() -> String:
	if lit:
		return ""
	var what: String = {"hang": "lamp", "niche": "candle", "post": "lantern", "pane": "lantern", "cresset": "cresset"}.get(look, "lamp")
	return "[%s]  Light the %s" % [Interactable.prompt_key(), what]


func interact_feel() -> StringName:
	return &"cast"


func interact(_by: Node) -> void:
	if lit or kept or follower:
		return
	_set_lit(true, true)
	var first := lamp_id != "" and State.mark("lamps", lamp_id)
	for f in followers:
		f.light_from_leader(true)
	Kit.fx_sparks(global_transform * _flame_at, Color(1.5, 0.8, 0.35))
	Kit.play("chime", global_position, -9.0, 1.3)
	if first:
		Travel.give("grave_ash", ASH, false, false)
	var t := tally(get_tree())
	Events.toast.emit("A flame takes.  Lamps lit: %d of %d." % [t.x, t.y])


## Attach a follower (a tower's crown); it burns at once when this lamp already does.
func add_follower(f: Lamp) -> void:
	followers.append(f)
	if lit:
		f.light_from_leader(false)


## Put the flame out again (the shots' before frames, the tests); the save is untouched.
func douse() -> void:
	_set_lit(false, false)
	for f in followers:
		f.douse()


## A leader lit: this follower burns too (its own light and flame, no prompt).
func light_from_leader(animate: bool) -> void:
	_set_lit(true, animate)


func _set_lit(on: bool, animate: bool) -> void:
	lit = on
	if _glow == null:
		return
	_glow.material_override = _mat("flame" if on else "cold")
	if on:
		_flare = 1.0 if animate else 0.0
		if want_light and _light == null:
			_light = OmniLight3D.new()
			_light.name = "LampLight"
			_light.position = _light_at
			_light.light_color = WARM
			_light.light_energy = _e
			_light.omni_range = _range
			_light.omni_attenuation = 1.6
			_light.shadow_enabled = false
			_light.light_specular = 0.3
			_light.set_meta(&"light_class", &"lamp")
			_light.set_meta(&"base", {"e": _e, "r": _range, "a": 1.6})
			LightPolicy.apply_fade(_light)
			add_child(_light)
	elif _light:
		_light.queue_free()
		_light = null
	_glow.scale = Vector3.ONE


func _process(delta: float) -> void:
	if not lit:
		return
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.4 + randf() * 0.2
		var pl := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
		_near = pl == null or pl.global_position.distance_squared_to(global_position) < 3600.0
		if _light:
			_light.visible = _near
	if not _near:
		return
	_t += delta
	_flare = maxf(_flare - delta * 1.4, 0.0)
	var k := 1.0 + 0.07 * sin(_t * 8.3 + _phase) + 0.05 * sin(_t * 21.0 + _phase * 2.0)
	_glow.scale = Vector3(1.0, 0.9 + 0.2 * k, 1.0) * (1.0 + _flare * 0.5)
	if _light:
		_light.light_energy = _e * k * (1.0 + _flare * 1.6)


## (lit, total) of the lamps the wanderer can kindle.
static func tally(tree: SceneTree) -> Vector2i:
	var on := 0
	var all := 0
	for n in tree.get_nodes_in_group(GROUP):
		all += 1
		var l := n as Lamp
		if l != null and l.lit:
			on += 1
	return Vector2i(on, all)


static func release() -> void:
	_meshes.clear()
	_mats.clear()


# --- looks -----------------------------------------------------------------------------------

static func _mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	match key:
		"body":
			m.vertex_color_use_as_albedo = true
			m.roughness = 0.82
		"flame":
			# unshaded and vertex-coloured: a pale heart fading to red at the tip; the 1.3 lifts the heart to the
			# bloom threshold and no further
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.vertex_color_use_as_albedo = true
			m.albedo_color = Color(FLAME_GLOW, FLAME_GLOW, FLAME_GLOW)
		_:
			# cold: dark glass with a pale pinprick of ember inside; under the glow threshold, no light
			m.albedo_color = Color(0.08, 0.09, 0.11)
			m.roughness = 0.25
			m.emission_enabled = true
			m.emission = Color(0.5, 0.64, 0.95)
			m.emission_energy_multiplier = 0.22
	_mats[key] = m
	return m


static func _mesh_for(kind: String, free: bool, chain_len: float) -> Dictionary:
	var key := "%s|%s|%.1f" % [kind, free, chain_len]
	if _meshes.has(key):
		return _meshes[key]
	var iron := Color(0.2, 0.2, 0.21)           # lifted: a dark post took the whole night grade as black
	var wood := Color(0.34, 0.25, 0.17)
	var stone := Color(0.26, 0.255, 0.25)
	var body := LampBuilder.new()
	var glow := LampBuilder.new()
	var d := {"e": 0.9, "range": 5.5, "flame": Vector3.ZERO, "light": Vector3.ZERO}
	match kind:
		"hang":
			var ring := Vector3.ZERO
			if chain_len > 0.05:
				var n := maxi(3, int(chain_len / 0.12))
				for i in n:
					body.box(Vector3(0, -(float(i) + 0.5) * chain_len / float(n), 0), Vector3(0.03, chain_len / float(n) * 0.8, 0.03), Basis(Vector3.UP, 0.8 * float(i)), iron)
				body.box(Vector3.ZERO, Vector3(0.12, 0.04, 0.12), Basis.IDENTITY, iron)
				ring = Vector3(0, -chain_len, 0)
			else:
				body.box(Vector3(0, 0.0, 0.02), Vector3(0.14, 0.34, 0.04), Basis.IDENTITY, iron)
				body.box(Vector3(0, 0.1, 0.34), Vector3(0.045, 0.045, 0.66), Basis.IDENTITY, iron)
				body.bar(Vector3(0, -0.12, 0.03), Vector3(0, 0.08, 0.5), 0.035, iron)
				body.box(Vector3(0, 0.04, 0.64), Vector3(0.03, 0.14, 0.03), Basis.IDENTITY, iron)
				ring = Vector3(0, -0.04, 0.64)
			d.flame = _lantern(body, glow, ring, iron)
			d.light = d.flame
		"post":
			body.box(Vector3(0, 0.1, 0), Vector3(0.34, 0.2, 0.34), Basis.IDENTITY, stone)
			body.box(Vector3(0, 1.0, 0), Vector3(0.1, 1.8, 0.1), Basis.IDENTITY, wood)
			body.box(Vector3(0, 1.84, 0), Vector3(0.24, 0.05, 0.24), Basis.IDENTITY, iron)
			d.flame = _lantern(body, glow, Vector3(0, 2.34, 0), iron)
			d.light = d.flame + Vector3(0, 0.05, 0)
			d.e = 1.0
			d.range = 6.0
		"pane":
			# only the glass: the cold lantern already stands there (the Pilgrims' Road lamps)
			glow.box(Vector3.ZERO, Vector3(0.19, 0.3, 0.19), Basis.IDENTITY, PANE)
			d.e = 1.0
			d.range = 6.0
		"camp":
			# a travellers' fire: a ring of stones, two crossed logs, a low wide flame
			for i in 9:
				var a := TAU * float(i) / 9.0
				body.box(Vector3(cos(a) * 0.62, 0.09, sin(a) * 0.62), Vector3(0.34, 0.2, 0.22), Basis(Vector3.UP, -a - PI * 0.5), stone)
			body.bar(Vector3(-0.4, 0.1, 0.12), Vector3(0.4, 0.16, -0.16), 0.11, wood)
			body.bar(Vector3(-0.3, 0.1, -0.3), Vector3(0.28, 0.15, 0.3), 0.1, wood * 0.9)
			body.lathe(Vector3(0, 0.02, 0), [Vector2(0.0, 0.0), Vector2(0.4, 0.0)], 8, Color(0.04, 0.03, 0.03))
			glow.lathe(Vector3.ZERO, [Vector2(0.0, 0.0), Vector2(0.24, 0.1), Vector2(0.2, 0.3), Vector2(0.1, 0.55), Vector2(0.0, 0.8)], 7, HEART, TIP, 0.08)
			d.flame = Vector3(0, 0.14, 0)
			d.light = Vector3(0, 0.8, 0)
			d.e = 1.7
			d.range = 8.5
		"shutter":
			# a hooded lantern on the ground, one slit of the shutter open on the front
			body.box(Vector3(0, 0.02, 0), Vector3(0.26, 0.04, 0.26), Basis.IDENTITY, iron)
			body.box(Vector3(0, 0.34, 0), Vector3(0.26, 0.04, 0.26), Basis.IDENTITY, iron)
			body.box(Vector3(0, 0.39, 0), Vector3(0.14, 0.06, 0.14), Basis.IDENTITY, iron)
			for sx: float in [-1.0, 1.0]:
				body.box(Vector3(sx * 0.115, 0.18, 0), Vector3(0.03, 0.3, 0.24), Basis.IDENTITY, iron)
			body.box(Vector3(0, 0.18, -0.115), Vector3(0.24, 0.3, 0.03), Basis.IDENTITY, iron)
			for sx: float in [-1.0, 1.0]:
				body.box(Vector3(sx * 0.07, 0.18, 0.125), Vector3(0.09, 0.3, 0.02), Basis.IDENTITY, iron)
			glow.box(Vector3.ZERO, Vector3(0.05, 0.24, 0.02), Basis.IDENTITY, Color(1.0, 0.82, 0.5))
			d.flame = Vector3(0, 0.18, 0.12)
			d.light = Vector3(0, 0.3, 0.4)
			d.e = 0.5
			d.range = 4.4
		"window":
			# a small window in a ruined wall: frame, mullion, a lit pane
			body.box(Vector3(0, -0.4, 0.07), Vector3(0.8, 0.08, 0.2), Basis.IDENTITY, stone)
			body.box(Vector3(0, 0.44, 0.05), Vector3(0.8, 0.1, 0.14), Basis.IDENTITY, stone)
			for sx: float in [-1.0, 1.0]:
				body.box(Vector3(sx * 0.36, 0.0, 0.05), Vector3(0.08, 0.84, 0.12), Basis.IDENTITY, wood)
			body.box(Vector3(0, 0.0, 0.05), Vector3(0.04, 0.8, 0.06), Basis.IDENTITY, wood)
			body.box(Vector3(0, 0.05, 0.05), Vector3(0.64, 0.04, 0.06), Basis.IDENTITY, wood)
			glow.box(Vector3.ZERO, Vector3(0.62, 0.78, 0.02), Basis.IDENTITY, Color(0.95, 0.66, 0.34))
			d.flame = Vector3(0, 0.0, 0.025)
			d.light = Vector3(0, -0.2, 1.4)
			d.e = 0.8
			d.range = 6.5
		"niche":
			var o := Vector3.ZERO
			if free:
				body.box(Vector3(0, 0.3, 0), Vector3(0.74, 0.6, 0.5), Basis.IDENTITY, stone)
				body.box(Vector3(0, 0.62, 0), Vector3(0.82, 0.07, 0.58), Basis.IDENTITY, stone * 1.1)
				o = Vector3(0, 0.66, -0.14)
			body.box(o + Vector3(-0.26, 0.38, 0.11), Vector3(0.12, 0.76, 0.22), Basis.IDENTITY, stone)
			body.box(o + Vector3(0.26, 0.38, 0.11), Vector3(0.12, 0.76, 0.22), Basis.IDENTITY, stone)
			body.box(o + Vector3(0, 0.78, 0.11), Vector3(0.66, 0.14, 0.24), Basis.IDENTITY, stone * 1.08)
			body.box(o + Vector3(0, 0.03, 0.12), Vector3(0.62, 0.07, 0.26), Basis.IDENTITY, stone * 1.08)
			body.box(o + Vector3(0, 0.4, 0.03), Vector3(0.42, 0.66, 0.06), Basis.IDENTITY, Color(0.07, 0.065, 0.06))
			body.box(o + Vector3(0, 0.12, 0.12), Vector3(0.06, 0.12, 0.06), Basis.IDENTITY, Color(0.78, 0.74, 0.6))
			body.box(o + Vector3(0, 0.07, 0.12), Vector3(0.14, 0.02, 0.14), Basis.IDENTITY, Color(0.7, 0.66, 0.54))
			glow.lathe(Vector3.ZERO, [Vector2(0.0, 0.0), Vector2(0.04, 0.05), Vector2(0.032, 0.13), Vector2(0.0, 0.23)], 6, HEART, TIP, 0.02)
			d.flame = o + Vector3(0, 0.2, 0.12)
			d.light = d.flame + Vector3(0, 0.1, 0.25)
			d.e = 0.55
			d.range = 3.6
		_:
			# cresset: an iron bowl on a tripod; the biggest flame of the four
			for i in 3:
				var a := TAU * float(i) / 3.0
				body.bar(Vector3(cos(a) * 0.3, 0.0, sin(a) * 0.3), Vector3(cos(a) * 0.1, 0.92, sin(a) * 0.1), 0.05, iron)
			body.lathe(Vector3(0, 0.86, 0), [Vector2(0.1, 0.0), Vector2(0.26, 0.12), Vector2(0.3, 0.26)], 8, iron)
			body.lathe(Vector3(0, 0.98, 0), [Vector2(0.0, 0.0), Vector2(0.24, 0.0)], 8, Color(0.05, 0.04, 0.04))
			glow.lathe(Vector3.ZERO, [Vector2(0.0, 0.0), Vector2(0.15, 0.1), Vector2(0.13, 0.26), Vector2(0.06, 0.4), Vector2(0.0, 0.54)], 7, HEART, TIP, 0.05)
			d.flame = Vector3(0, 1.02, 0)
			d.light = Vector3(0, 1.45, 0)
			d.e = 1.5
			d.range = 8.0
	d.body = body.commit()
	d.glow = glow.commit()
	_meshes[key] = d
	return d


## An iron lantern whose ring is at `ring`; its glass goes to the glow mesh (centred on the flame).
## Returns the flame point.
static func _lantern(body: LampBuilder, glow: LampBuilder, ring: Vector3, iron: Color) -> Vector3:
	body.box(ring, Vector3(0.06, 0.07, 0.025), Basis.IDENTITY, iron)
	body.box(ring + Vector3(0, -0.08, 0), Vector3(0.24, 0.05, 0.24), Basis(Vector3.UP, 0.78), iron)
	body.box(ring + Vector3(0, -0.13, 0), Vector3(0.14, 0.05, 0.14), Basis.IDENTITY, iron)
	body.box(ring + Vector3(0, -0.44, 0), Vector3(0.24, 0.04, 0.24), Basis.IDENTITY, iron)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			body.box(ring + Vector3(sx * 0.1, -0.28, sz * 0.1), Vector3(0.03, 0.3, 0.03), Basis.IDENTITY, iron)
	glow.box(Vector3.ZERO, Vector3(0.15, 0.25, 0.15), Basis.IDENTITY, PANE)
	return ring + Vector3(0, -0.28, 0)


class LampBuilder extends RefCounted:
	var st := SurfaceTool.new()
	var n_tris := 0

	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	func _tri(a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color, ca := Color.TRANSPARENT, cb := Color.TRANSPARENT, cc := Color.TRANSPARENT) -> void:
		n_tris += 1
		var pts: Array[Vector3] = [a, c, b]
		var cols: Array[Color] = []
		if ca.a == 0.0:
			cols.assign([col, col, col])
		else:
			cols.assign([ca, cc, cb])
		for i in 3:
			st.set_color(cols[i])
			st.set_normal(n)
			st.add_vertex(pts[i])

	func box(c: Vector3, s: Vector3, b: Basis, col: Color) -> void:
		var h := s * 0.5
		for ax in 3:
			for sg: float in [-1.0, 1.0]:
				var n := Vector3.ZERO
				n[ax] = sg
				var u := Vector3.ZERO
				u[(ax + 1) % 3] = 1.0
				var v := n.cross(u)
				var hu := h[(ax + 1) % 3]
				var hv := h[(ax + 2) % 3]
				var base := n * h[ax]
				var nn := (b * n).normalized()
				var p0 := c + b * (base - u * hu - v * hv)
				var p1 := c + b * (base + u * hu - v * hv)
				var p2 := c + b * (base + u * hu + v * hv)
				var p3 := c + b * (base - u * hu + v * hv)
				_tri(p0, p1, p2, nn, col)
				_tri(p0, p2, p3, nn, col)

	## A square bar from `a` to `b`.
	func bar(a: Vector3, b: Vector3, thick: float, col: Color) -> void:
		var y := (b - a).normalized()
		var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
		var z := x.cross(y)
		box((a + b) * 0.5, Vector3(thick, a.distance_to(b), thick), Basis(x, y, z), col)

	## A lathe round +y from `at`: profile is [Vector2(radius, height)] bottom to top. With `col_top` the colour
	## fades from `col` at the bottom to `col_top` at the top; `lean` bends the upper rings sideways (a flame).
	func lathe(at: Vector3, profile: Array, sides: int, col := Color.WHITE, col_top := Color.TRANSPARENT, lean := 0.0) -> void:
		var h_top := maxf((profile[profile.size() - 1] as Vector2).y, 0.001)
		for i in profile.size() - 1:
			var p0: Vector2 = profile[i]
			var p1: Vector2 = profile[i + 1]
			var f0 := p0.y / h_top
			var f1 := p1.y / h_top
			var c0 := col.lerp(col_top, f0) if col_top.a > 0.0 else col
			var c1 := col.lerp(col_top, f1) if col_top.a > 0.0 else col
			var o0 := Vector3(lean * f0 * f0, 0, 0)
			var o1 := Vector3(lean * f1 * f1, 0, 0)
			for k in sides:
				var a0 := TAU * float(k) / float(sides)
				var a1 := TAU * float(k + 1) / float(sides)
				var b0 := at + o0 + Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x)
				var b1 := at + o0 + Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x)
				var t0 := at + o1 + Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x)
				var t1 := at + o1 + Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x)
				var am := (a0 + a1) * 0.5
				var n := Vector3(cos(am), 0.3, sin(am)).normalized()
				if col_top.a > 0.0:
					_tri(b0, b1, t1, n, col, c0, c0, c1)
					_tri(b0, t1, t0, n, col, c0, c1, c1)
				else:
					_tri(b0, b1, t1, n, col)
					_tri(b0, t1, t0, n, col)

	func commit() -> ArrayMesh:
		return st.commit() if n_tris > 0 else null
