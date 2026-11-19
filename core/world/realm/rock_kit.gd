extends RefCounted
## RockKit: procedural, cached, LOD'd rock meshes for the Realm (docs/REALM_PLAN.md, module assets).
##
## USAGE (no class_name: load by path)
##   const RockKit := preload("res://core/world/realm/rock_kit.gd")
##   var m := RockKit.boulder(seed, Vector3(2.2, 1.4, 1.8), "mossy")   # ArrayMesh, material on the surface
##   var c := RockKit.cliff(seed, Vector3(9.0, 6.0, 3.0), "granite")    # stratified face; front = +Z
##   var b := RockKit.basalt_columns(seed, 3.0, 5.0)                    # hex column cluster
##   var mat := RockKit.material("ash")                                 # for your own meshes too
##   var shape := RockKit.collision_shape(m)                            # convex, cached per mesh
##   RockKit.spawn(parent, m, xform)          # MeshInstance3D + StaticBody3D (WORLD) in one call
##   MultiMesh: mm.mesh = RockKit.boulder(...) works as is (the material lives on the surface).
##
## Styles: "granite" (cold grey, chipped facets, faint strata), "basalt" (dark, hexagonal column
## chunks), "mossy" (granite with moss caps on up faces), "ash" (dark, sooty, ember-glowing cracks).
## Size = full extents in metres (x width, y height above ground, z depth). Meshes are centred in
## x/z with the visible base at y = 0 and a buried skirt below it (so they seat on uneven ground).
##
## Caching: one mesh per (seed % VARIANTS, style, size bucket ~12 % steps). Calls with the same key
## return the SAME ArrayMesh (shared GPU buffers, instancing-friendly). For scatter, use a handful of
## sizes and vary the instance's yaw and scale (+/-20 %) rather than asking for hundreds of sizes.
## Budgets (LOD0): boulder <= ~2.8k tris, cliff <= ~7.5k, basalt_columns ~70 per column.
## LODs come from MeshChunks.with_lods. Build cost is ~5-25 ms per new mesh (GDScript), once.

const MeshChunksS := preload("res://core/world/mesh_chunks.gd")
const GenCache := preload("res://core/world/realm/gen_cache.gd")
const SELF := "res://core/world/realm/rock_kit.gd"
const SHADER := preload("res://core/world/realm/rock_kit.gdshader")
const STYLES := ["granite", "basalt", "mossy", "ash"]
const VARIANTS := 16
const BOULDER_TRIS := 2600
const CLIFF_TRIS := 7200
const T := "res://art/textures/"

static var _meshes := {}
static var _t_gen := 0                  ## start of the current cache-miss build (profiling)
static var _mats := {}
static var _shapes := {}
static var _n: FastNoiseLite
static var _cell: FastNoiseLite


# --- public API --------------------------------------------------------------------------------

static func boulder(seed: int, size: Vector3, style: String) -> ArrayMesh:
	style = _style(style)
	var b := _bucket(size)
	var key := "boulder|%d|%s|%s" % [posmod(seed, VARIANTS), style, str(b)]
	if _meshes.has(key):
		return _meshes[key]
	var disk := _from_disk(key)
	if disk:
		return disk
	var sz := _unbucket(b)
	var rng := _rng(key)
	_seed_noise(rng.randi())
	var g := _boulder_geo(rng, sz, style, BOULDER_TRIS)
	var mesh := _finish(g, style, key)
	return mesh


static func cliff(seed: int, size: Vector3, style: String) -> ArrayMesh:
	style = _style(style)
	var b := _bucket(size)
	var key := "cliff|%d|%s|%s" % [posmod(seed, VARIANTS), style, str(b)]
	if _meshes.has(key):
		return _meshes[key]
	var disk := _from_disk(key)
	if disk:
		return disk
	var sz := _unbucket(b)
	var rng := _rng(key)
	_seed_noise(rng.randi())
	var g: Geo
	if style == "basalt":
		g = _basalt_wall(rng, sz)
	else:
		g = _strata_cliff(rng, sz, style)
	return _finish(g, style, key)


static func basalt_columns(seed: int, radius: float, height: float) -> ArrayMesh:
	var rb := roundi(log(maxf(radius, 0.2)) / log(1.12))
	var hb := roundi(log(maxf(height, 0.2)) / log(1.12))
	var key := "columns|%d|%d|%d" % [posmod(seed, VARIANTS), rb, hb]
	if _meshes.has(key):
		return _meshes[key]
	var disk := _from_disk(key)
	if disk:
		return disk
	var rng := _rng(key)
	_seed_noise(rng.randi())
	var g := Geo.new()
	_columns_into(g, rng, pow(1.12, rb), pow(1.12, hb), Transform3D.IDENTITY, Vector2.ZERO)
	return _finish(g, "basalt", key)


## Dressed / standing stone: a tall or flat slab with a tapered, broken crown, chamfered and
## chipped edges and vertical weathering (menhirs, waystones, grave slabs, rune slabs).
## size = full extents (x width, y height, z thickness); base at y = 0. flat_front: the +Z face
## stays a clean plane (for inscriptions / rune meshes laid on it). Moss gathers at the foot.
static func slab(seed: int, size: Vector3, style: String, taper := 0.25, flat_front := false) -> ArrayMesh:
	style = _style(style)
	var b := _bucket(size)
	var key := "slab|%d|%s|%s|%d|%s" % [posmod(seed, VARIANTS), style, str(b), roundi(taper * 20.0), flat_front]
	if _meshes.has(key):
		return _meshes[key]
	var disk := _from_disk(key)
	if disk:
		return disk
	var sz := _unbucket(b)
	var rng := _rng(key)
	_seed_noise(rng.randi())
	return _finish(_slab_geo(rng, sz, style, taper, flat_front), style, key)


## r34 flora: a cairn: a broad footing stone and three or four smaller ones stacked on it, each
## seated a little into the one below. size: x/z footing width, y total height. Base at y = 0.
static func cairn(seed: int, size: Vector3, style: String) -> ArrayMesh:
	style = _style(style)
	var b := _bucket(size)
	var key := "cairn|%d|%s|%s" % [posmod(seed, VARIANTS), style, str(b)]
	if _meshes.has(key):
		return _meshes[key]
	var disk := _from_disk(key)
	if disk:
		return disk
	var sz := _unbucket(b)
	var rng := _rng(key)
	_seed_noise(rng.randi())
	var g := Geo.new()
	var y := 0.0
	var n := 4 + rng.randi_range(0, 1)
	var hs := []
	var tot := 0.0
	for k in n:
		var hk := lerpf(1.0, 0.55, float(k) / float(n - 1)) * rng.randf_range(0.85, 1.15)
		hs.append(hk)
		tot += hk
	for k in n:
		var hk: float = float(hs[k]) / tot * sz.y * 1.18
		var wk := lerpf(1.0, 0.42, float(k) / float(n - 1))
		var piece := _boulder_geo(rng, Vector3(sz.x * wk, hk, sz.z * wk * rng.randf_range(0.8, 1.0)), style, 600)
		var off := Vector3(rng.randf_range(-0.06, 0.06) * sz.x, y, rng.randf_range(-0.06, 0.06) * sz.z)
		g.add(piece, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), off))
		y += hk * 0.82
	return _finish(g, style, key)


static func material(style: String) -> Material:
	style = _style(style)
	if _mats.has(style):
		return _mats[style]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	var pre := "rockkit_" if ResourceLoader.exists(T + "rockkit_albedo.png") else "rock_"
	m.set_shader_parameter("albedo_tex", load(T + pre + "albedo.png"))
	m.set_shader_parameter("normal_tex", load(T + pre + "normal.png"))
	m.set_shader_parameter("rough_tex", load(T + pre + "rough.png"))
	if ResourceLoader.exists(T + "rockkit_mask.png"):
		m.set_shader_parameter("mask_tex", load(T + "rockkit_mask.png"))
	m.set_shader_parameter("moss_tex", load(T + "ground_albedo.png"))
	m.set_shader_parameter("moss_normal", load(T + "ground_normal.png"))
	m.set_shader_parameter("detail_normal", load(T + "micro_normal.png"))
	match style:
		"granite":
			_p(m, {"tint": Color(0.6, 0.64, 0.74), "tint_alt": Color(0.5, 0.52, 0.58), "lichen": 0.45,
				"moss_amount": 0.18, "moss_bias": -0.12, "rough_base": 0.84, "vcol_lichen": 1.0})
		"mossy":
			_p(m, {"tint": Color(0.52, 0.58, 0.64), "tint_alt": Color(0.44, 0.48, 0.52), "lichen": 0.6,
				"moss_amount": 1.0, "moss_bias": 0.05, "rough_base": 0.88, "vcol_lichen": 1.0})
		"basalt":
			_p(m, {"tint": Color(0.36, 0.38, 0.46), "tint_alt": Color(0.28, 0.29, 0.34), "lichen": 0.15,
				"moss_amount": 0.1, "moss_bias": -0.2, "rough_base": 0.72, "specular_amt": 0.45,
				"normal_strength": 0.9, "tex_scale": 0.42})
		"ash":
			_p(m, {"tint": Color(0.36, 0.34, 0.36), "tint_alt": Color(0.24, 0.22, 0.23), "lichen": 0.0,
				"moss_amount": 0.0, "rough_base": 0.9, "ember": 1.0, "soot": 0.55, "rim_amount": 0.18,
				"tex_scale": 0.38})
	_mats[style] = m
	return m


## The same stone, dissolving near the camera (a fine dither from 3.5 m in, gone at 1.2 m): for the great stones the
## camera is let through (group CAMERA_PASS on their bodies) so a fight beside one keeps the wanderer and the foe in view
## instead of a wall of granite (map audit MA3, the henge's 16 stones). Its own shader: the discard would cost every
## other rock its early depth test.
static var _fade_shader: Shader


static func fade_material(style: String) -> Material:
	style = _style(style)
	if _mats.has(style + "|fade"):
		return _mats[style + "|fade"]
	if _fade_shader == null:
		_fade_shader = Shader.new()
		_fade_shader.code = SHADER.code.replace("void fragment() {", """void fragment() {
	{
		float cam_k = smoothstep(1.2, 3.5, length(VERTEX));
		float ign = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		if (ign > cam_k) {
			discard;
		}
	}""")
	var base := material(style) as ShaderMaterial
	var m := ShaderMaterial.new()
	m.shader = _fade_shader
	for u: Dictionary in RenderingServer.get_shader_parameter_list(SHADER.get_rid()):
		m.set_shader_parameter(u.name, base.get_shader_parameter(u.name))
	_mats[style + "|fade"] = m
	return m


## Convex collision for a RockKit mesh (or any mesh), cached per mesh.
static func collision_shape(mesh: Mesh) -> Shape3D:
	if mesh == null:
		return null
	if _shapes.has(mesh):
		return _shapes[mesh]
	# a mesh of this kit's own (its key is its name) keeps its simplified hull in the GenCache: the hull is ~37 ms a
	# mesh, and the Realm's places use a few dozen of them every boot
	var key := "hull|" + mesh.resource_name if _meshes.get(mesh.resource_name) == mesh else ""
	var s: Shape3D = null
	if key != "":
		var pts: Variant = GenCache.load_var(key, SELF)
		if pts is PackedVector3Array and not (pts as PackedVector3Array).is_empty():
			var c := ConvexPolygonShape3D.new()
			c.points = pts
			s = c
	if s == null:
		s = mesh.create_convex_shape(true, true)
		if key != "" and s is ConvexPolygonShape3D:
			GenCache.save_var(key, SELF, (s as ConvexPolygonShape3D).points)
	_shapes[mesh] = s
	return s


## Convenience: a MeshInstance3D (+ StaticBody3D on the WORLD layer with the convex shape) under
## `parent` at `xform` (global if parent is in the tree). vis_end > 0 sets a fading visibility range.
static func spawn(parent: Node, mesh: Mesh, xform: Transform3D, collide := true, vis_end := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Rock"
	mi.mesh = mesh
	if vis_end > 0.0:
		mi.visibility_range_end = vis_end
		mi.visibility_range_end_margin = vis_end * 0.15
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(mi)
	if mi.is_inside_tree():
		mi.global_transform = xform
	else:
		mi.transform = xform
	if collide:
		var body := StaticBody3D.new()
		body.name = "RockBody"
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		cs.shape = collision_shape(mesh)
		body.add_child(cs)
		mi.add_child(body)
	return mi


## Triangle count of LOD0 (all surfaces).
static func tris(mesh: Mesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		n += (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if a[Mesh.ARRAY_INDEX] != null else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


# --- geometry container -----------------------------------------------------------------------

## Triangle soup with welded vertices. Triangles are stored in Godot's front-face winding:
## cross(b - a, c - a) points INTO the surface. `col` per vertex (see rock_kit.gdshader).
class Geo:
	var p := PackedVector3Array()
	var col := PackedColorArray()
	var t := PackedInt32Array()
	var hard := PackedByteArray()      # per triangle: 1 = flat shaded (columns)

	func add(g: Geo, xf: Transform3D) -> void:
		var base := p.size()
		for i in g.p.size():
			p.append(xf * g.p[i])
			col.append(g.col[i])
		for i in g.t.size():
			t.append(g.t[i] + base)
		hard.append_array(g.hard)


# --- builders ---------------------------------------------------------------------------------

## A chipped, faceted boulder: ellipsoid-ish superquadric -> settle (taper, lean) -> broad lumps
## -> strata -> plane cuts (big fracture facets, then small corner chips) -> refit to size -> fine
## breakup -> style passes (moss caps / ember cracks). Base at y = 0.
static func _boulder_geo(rng: RandomNumberGenerator, sz: Vector3, style: String, budget: int) -> Geo:
	var sink := clampf(sz.y * 0.16, 0.06, 0.6)
	var half := Vector3(sz.x * 0.5, (sz.y + sink) * 0.5, sz.z * 0.5)
	var centre := Vector3.ZERO          # built round the origin; _fit seats it on y = 0 at the end
	var q := 2.05
	match style:
		"basalt": q = 6.0
		"mossy": q = 2.15
		"ash": q = 2.1
	var g := _rounded_box(half, q, budget)
	var mx := maxf(sz.x, maxf(sz.y, sz.z))
	var mn := minf(sz.x, minf(sz.y, sz.z))
	# 1 settle: wider foot, top leaning off-centre; broad lumps
	var lean := Vector2(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.15, 0.15))
	var taper := rng.randf_range(0.2, 0.42) if style != "basalt" else 0.0
	var lump := 0.16 if style != "basalt" else 0.04
	var nseed := Vector3(rng.randf() * 50.0, rng.randf() * 50.0, rng.randf() * 50.0)
	for i in g.p.size():
		var v := g.p[i]
		var t := clampf((v.y + half.y) / (2.0 * half.y), 0.0, 1.0)
		v.x = v.x * (1.0 - taper * t) + lean.x * t * sz.x
		v.z = v.z * (1.0 - taper * t) + lean.y * t * sz.z
		var d := _dir(v, half)
		g.p[i] = v + d * _fbm(v / mx * 1.7 + nseed, 3) * lump * mn
	# 2 strata (tilted ledges), faint on boulders
	if style == "granite" or style == "mossy":
		var axis := Vector3(rng.randf_range(-0.35, 0.35), 1.0, rng.randf_range(-0.35, 0.35)).normalized()
		var spacing := clampf(sz.y * rng.randf_range(0.18, 0.3), 0.18, 0.9)
		_strata(g, half, axis, spacing, mn * (0.05 if style == "granite" else 0.03))
	# 3 plane cuts: the facets. Side/top only; the bottom gets one flat cut.
	var cuts := []
	match style:
		"basalt":
			var rot := rng.randf() * TAU
			for k in 6:
				var a := rot + TAU * float(k) / 6.0 + rng.randf_range(-0.1, 0.1)
				cuts.append([Vector3(cos(a), rng.randf_range(-0.06, 0.06), sin(a)).normalized(), rng.randf_range(0.68, 0.78)])
			cuts.append([Vector3(rng.randf_range(-0.4, 0.4), 1.0, rng.randf_range(-0.4, 0.4)).normalized(), rng.randf_range(0.8, 0.9)])
			for k in 3:
				cuts.append([_rand_dir(rng, 0.1), rng.randf_range(0.86, 0.94)])
		"ash":
			for k in rng.randi_range(6, 8):
				cuts.append([_rand_dir(rng, -0.1), rng.randf_range(0.68, 0.86)])
		"mossy":
			for k in rng.randi_range(5, 7):
				cuts.append([_rand_dir(rng, -0.2), rng.randf_range(0.72, 0.88)])
		_:
			for k in rng.randi_range(6, 8):
				# fracture faces mostly on the flanks; at most one shallow cut across the crown
				var n := _rand_dir(rng, -0.3)
				n.y = clampf(n.y, 0.12, 0.75)        # sloping flanks, never vertical walls
				cuts.append([n.normalized(), rng.randf_range(0.68, 0.88)])
			if rng.randf() < 0.5:
				cuts.append([Vector3(rng.randf_range(-0.6, 0.6), 1.0, rng.randf_range(-0.6, 0.6)).normalized(), rng.randf_range(0.86, 0.94)])
	# small chips on the edges the big cuts left
	for k in (rng.randi_range(3, 5) if style != "mossy" else 2):
		cuts.append([_rand_dir(rng, 0.0), rng.randf_range(0.9, 0.96)])
	for k in 3:
		cuts.append([_rand_dir(rng, 0.0), rng.randf_range(0.93, 0.975)])      # scars: faint secondary facets that break the outline
	for c in cuts:
		_cut(g, c[0], c[1], centre)
	# flat underside (the buried part)
	var floor_y := -half.y * 0.72
	for i in g.p.size():
		if g.p[i].y < floor_y:
			g.p[i].y = floor_y + (g.p[i].y - floor_y) * 0.15
	# fit the requested extents again (the cuts ate into them)
	_fit(g, Vector3(-sz.x * 0.5, -sink * 0.7, -sz.z * 0.5), Vector3(sz.x * 0.5, sz.y, sz.z * 0.5))
	# 4 fine breakup so facets are not glass-flat
	for i in g.p.size():
		var v := g.p[i]
		g.p[i] = v + _dir(v, half) * _fbm(v * 3.1 / maxf(mn, 0.3) + nseed, 2) * mn * 0.014
	# 5 style passes
	if style == "ash":
		_ember_cracks(g, half, mn)
	_shade(g, sink, sz.y)
	if style == "mossy" or style == "granite":
		_moss_caps(g, mn * (0.03 if style == "mossy" else 0.0), 0.55 if style == "mossy" else 0.82)
		_lichen_paint(g, 1.0)
	if style != "basalt":
		_band_tone(g, Vector3(0.0, 1.0, 0.0), clampf(sz.y * 0.24, 0.25, 0.9), 0.55)
	return g


static func _slab_geo(rng: RandomNumberGenerator, sz: Vector3, style: String, taper: float, flat_front: bool) -> Geo:
	var sink := clampf(sz.y * 0.08, 0.05, 0.4)
	var half := Vector3(sz.x * 0.5, (sz.y + sink) * 0.5, sz.z * 0.5)
	var centre := Vector3.ZERO
	var g := _rounded_box(half, 4.0, BOULDER_TRIS + 400)
	var mn := minf(sz.x, minf(sz.y, sz.z))
	var nseed := Vector3(rng.randf() * 50.0, rng.randf() * 50.0, rng.randf() * 50.0)
	var lean := rng.randf_range(-0.04, 0.04)
	for i in g.p.size():
		var v := g.p[i]
		var t := clampf((v.y + half.y) / (2.0 * half.y), 0.0, 1.0)
		var k := pow(t, 1.4)
		v.x = v.x * (1.0 - taper * k) + lean * t * sz.y
		v.z = v.z * (1.0 - taper * 0.5 * k)
		var d := _dir(v, half)
		var side := 1.0 - absf(d.y)
		# broad swell + vertical weathering runnels (stretched noise)
		var w := _fbm(v * Vector3(1.4, 0.35, 1.4) / maxf(mn, 0.2) + nseed, 3) * 0.06
		w += _fbm(Vector3(v.x * 7.0, v.y * 0.6, v.z * 7.0) / maxf(sz.x, 0.3) + nseed, 2) * 0.035 * side
		g.p[i] = v + d * w * mn
	var cuts := []
	# broken crown
	for k in rng.randi_range(1, 2):
		cuts.append([Vector3(rng.randf_range(-0.7, 0.7), 1.0, rng.randf_range(-0.3, 0.3)).normalized(), rng.randf_range(0.86, 0.95)])
	# chamfered vertical edges
	for sx in [-1.0, 1.0]:
		for sz2 in [-1.0, 1.0]:
			if rng.randf() < 0.75:
				cuts.append([Vector3(sx, rng.randf_range(-0.15, 0.25), sz2 * sz.x / maxf(sz.z, 0.05) * 0.6).normalized(), rng.randf_range(0.88, 0.95)])
	# chips
	for k in rng.randi_range(3, 5):
		cuts.append([_rand_dir(rng, -0.1), rng.randf_range(0.9, 0.96)])
	for c in cuts:
		_cut(g, c[0], c[1], centre)
	if flat_front:
		_cut(g, Vector3.BACK, 0.97, centre)
	for i in g.p.size():
		g.p[i].y = maxf(g.p[i].y, -half.y * 0.85)
	_fit(g, Vector3(-sz.x * 0.5, -sink * 0.7, -sz.z * 0.5), Vector3(sz.x * 0.5, sz.y, sz.z * 0.5))
	for i in g.p.size():
		var v := g.p[i]
		var d := _dir(v, half)
		var amp := 0.004 if (flat_front and d.z > 0.7) else 0.012
		g.p[i] = v + d * _fbm(v * 3.1 / maxf(mn, 0.2) + nseed, 2) * mn * amp
	if style == "ash":
		_ember_cracks(g, half, mn)
	_shade(g, sink, sz.y)
	if style != "ash" and style != "basalt":
		_moss_caps(g, 0.0, 0.7 if style == "mossy" else 0.85)
		# moss and soil creeping up the foot
		for i in g.p.size():
			var v := g.p[i]
			var m := (1.0 - smoothstep(0.0, 0.18 * sz.y + 0.1, v.y + _fbm(v * 2.5 + nseed, 2) * 0.25)) * 0.8
			var c := g.col[i]
			c.g = minf(c.g, 1.0 - m)
			g.col[i] = c
		_lichen_paint(g, 0.8)
		_band_tone(g, Vector3.UP, clampf(sz.y * 0.3, 0.3, 1.0), 0.4)
	return g


## A stratified rock face: stacked slab blocks with sharp, chipped edges (each layer its own
## thickness, outline and inset; vertical joints split some layers; the whole stack dips a few
## degrees), so the strata are real ledges with shadow lines. Front face = +Z.
static func _strata_cliff(rng: RandomNumberGenerator, sz: Vector3, style: String) -> Geo:
	var out := Geo.new()
	var sink := clampf(sz.y * 0.08, 0.2, 1.0)
	var total := sz.y + sink
	var nl := clampi(roundi(total / rng.randf_range(0.8, 1.2)), 2, 8)
	var hs := PackedFloat32Array()
	var sum := 0.0
	for i in nl:
		var h := rng.randf_range(0.35, 1.6)
		hs.append(h)
		sum += h
	var dip := Basis(Vector3.RIGHT, rng.randf_range(-0.06, 0.03)) * Basis(Vector3.BACK, rng.randf_range(-0.09, 0.09))
	var blocks: Array = []   # [centre, size, yaw, tilt]
	var y := -sink
	for i in nl:
		var h := hs[i] / sum * total
		var tf := float(i) / float(maxi(nl - 1, 1))
		var w := sz.x * rng.randf_range(0.8, 1.0) * (1.0 - tf * 0.2)
		# alternate proud and recessed layers (hard beds stand out, soft beds weather back)
		var inset := (rng.randf_range(0.0, 0.08) if i % 2 == 0 else rng.randf_range(0.1, 0.24)) * sz.z + tf * 0.1 * sz.z
		var d := sz.z * rng.randf_range(0.75, 0.95) - inset * 0.4
		var zc := sz.z * 0.5 - inset - d * 0.5
		var xs := rng.randf_range(-0.07, 0.07) * sz.x
		var nb := 1 + (1 if rng.randf() < 0.6 else 0) + (1 if w > 7.0 and rng.randf() < 0.7 else 0)
		var cuts := PackedFloat32Array([0.0])
		for k in nb - 1:
			cuts.append(clampf(float(k + 1) / float(nb) + rng.randf_range(-0.12, 0.12), 0.15, 0.85))
		cuts.append(1.0)
		for k in nb:
			var x0 := -w * 0.5 + w * cuts[k] + (0.015 if k > 0 else 0.0)
			var x1 := -w * 0.5 + w * cuts[k + 1] - (0.015 if k < nb - 1 else 0.0)
			var bz := zc + rng.randf_range(-0.06, 0.06) * sz.z
			blocks.append([dip * Vector3(xs + (x0 + x1) * 0.5, y + h * 0.5, bz), Vector3(x1 - x0, h + 0.04, d),
				rng.randf_range(-0.04, 0.04), rng.randf_range(-0.02, 0.02)])
		y += h
	var budget := maxi(CLIFF_TRIS / blocks.size(), 300)
	for b in blocks:
		var bs: Vector3 = b[1]
		var half := bs * 0.5
		var g := _rounded_box(half, 12.0, budget)
		var mn := minf(bs.x, minf(bs.y, bs.z))
		var c0: Vector3 = b[0]
		for i in g.p.size():
			var v := g.p[i]
			var d := _dir(v, half)
			# rough vertical faces, flatter bedding planes
			var amp := mn * (0.07 if absf(d.y) < 0.6 else 0.025)
			g.p[i] = v + d * _fbm((v + c0) * 0.8, 3) * amp
		# bevel / break the edges: mostly near-horizontal normals, a couple steep
		for k in rng.randi_range(4, 6):
			var n := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.5, 0.7), rng.randf_range(-0.2, 1.0)).normalized()
			_cut(g, n, rng.randf_range(0.82, 0.95), Vector3.ZERO)
		for i in g.p.size():
			var v := g.p[i]
			g.p[i] = v + _dir(v, half) * _fbm((v + c0) * 3.3, 2) * mn * 0.02
		var xf := Transform3D(dip * Basis(Vector3.UP, b[2]) * Basis(Vector3.RIGHT, b[3]), c0)
		# per-layer tone: cavity channel scaled so strata read in different shades
		var tone := rng.randf_range(0.78, 1.0)
		var band := rng.randf_range(0.6, 1.0)           # the layer's own shade (COLOR.a), darker under its ledge
		for i in g.col.size():
			g.col[i] = Color(tone, 1.0, 1.0, band * lerpf(0.8, 1.0, smoothstep(-half.y, half.y * 0.4, g.p[i].y)))
		out.add(g, xf)
	_shade(out, sink, sz.y)
	if style == "mossy" or style == "granite":
		_moss_caps(out, 0.05 if style == "mossy" else 0.0, 0.5 if style == "mossy" else 0.8)
		_lichen_paint(out, 1.0)
	if style == "ash":
		_ember_cracks(out, sz * 0.5, 1.0)
	return out


## Basalt "cliff": a wall of hex columns (two staggered rows) stepping down at the ends.
static func _basalt_wall(rng: RandomNumberGenerator, sz: Vector3) -> Geo:
	var g := Geo.new()
	var r := clampf(sz.z * 0.22, 0.28, 0.5)
	var step := r * 1.72
	var n := maxi(int(sz.x / step), 1)
	for row in 2:
		for i in n:
			var x := -sz.x * 0.5 + (float(i) + 0.5 + 0.5 * float(row)) * step
			if x > sz.x * 0.5:
				continue
			var edge := 1.0 - pow(absf(x) / (sz.x * 0.5), 3.0)
			var h := sz.y * clampf(edge * rng.randf_range(0.78, 1.0) - float(row) * 0.08, 0.25, 1.0)
			var z := sz.z * 0.5 - r - float(row) * step * 0.86
			_column(g, rng, Vector3(x, 0.0, z), r * rng.randf_range(0.9, 1.08), h)
	return g


## Hex columns packed on a hex grid inside `radius`, tallest in the middle.
static func _columns_into(g: Geo, rng: RandomNumberGenerator, radius: float, height: float, _xf: Transform3D, _o: Vector2) -> void:
	var r := clampf(radius * 0.14, 0.26, 0.48)
	var step := r * 1.74
	var rings := int(radius / step) + 1
	for qi in range(-rings, rings + 1):
		for ri in range(-rings, rings + 1):
			var x := step * (float(qi) + float(ri) * 0.5)
			var z := step * float(ri) * 0.866
			var d := Vector2(x, z).length()
			if d > radius - r * 0.4:
				continue
			var k := d / radius
			var h := height * clampf((1.0 - k * k * 0.75) * rng.randf_range(0.62, 1.0), 0.12, 1.0)
			if rng.randf() < 0.12:
				h *= rng.randf_range(0.25, 0.5)        # a broken stub
			_column(g, rng, Vector3(x, 0.0, z), r * rng.randf_range(0.92, 1.06), h)


## One irregular hexagonal column, flat shaded: buried foot, 0-2 joint notches, a tilted top
## with a chamfer.
static func _column(g: Geo, rng: RandomNumberGenerator, foot: Vector3, r: float, h: float) -> void:
	var rot := rng.randf_range(-0.2, 0.2)
	var lean := Vector3(rng.randf_range(-0.03, 0.03), 1.0, rng.randf_range(-0.03, 0.03)).normalized()
	var radj := PackedFloat32Array()
	for k in 6:
		radj.append(rng.randf_range(0.9, 1.1))
	var top_n := Vector3(rng.randf_range(-0.2, 0.2), 1.0, rng.randf_range(-0.2, 0.2)).normalized()
	var rings: Array = []          # [y, radius scale]
	rings.append([-0.6, 1.0])
	var joints := rng.randi_range(0, 2) if h > 1.2 else 0
	var js := PackedFloat32Array()
	for j in joints:
		js.append(rng.randf_range(0.25, 0.85) * h)
	js.sort()
	for jy in js:
		rings.append([jy - 0.035, 1.0])
		rings.append([jy, 0.93])
		rings.append([jy + 0.035, 1.0])
	var bev := minf(0.05, r * 0.15)
	var ring_pts: Array = []
	for rr in rings:
		var pts := PackedVector3Array()
		for k in 6:
			var a := rot + TAU * float(k) / 6.0
			var o := Vector3(cos(a), 0.0, sin(a)) * r * radj[k] * float(rr[1])
			pts.append(foot + o + lean * float(rr[0]))
		ring_pts.append(pts)
	# top edge ring: on the tilted top plane, then the chamfer inset ring
	var top_c := foot + lean * h
	var edge := PackedVector3Array()
	var cham := PackedVector3Array()
	for k in 6:
		var a := rot + TAU * float(k) / 6.0
		var o := Vector3(cos(a), 0.0, sin(a)) * r * radj[k]
		var pxz := foot + o
		# height of the top plane over pxz
		var dy := -(top_n.x * (pxz.x - top_c.x) + top_n.z * (pxz.z - top_c.z)) / top_n.y
		edge.append(pxz + lean * (h + dy - bev))
		cham.append(top_c + (pxz - foot) * (1.0 - bev / r * 1.4) + Vector3(0.0, dy * (1.0 - bev / r), 0.0))
	ring_pts.append(edge)
	var ao_of := func(y: float) -> float: return clampf(0.55 + 0.45 * (y - foot.y) / maxf(h, 0.5), 0.5, 1.0)
	for ri in ring_pts.size() - 1:
		var a: PackedVector3Array = ring_pts[ri]
		var b: PackedVector3Array = ring_pts[ri + 1]
		for k in 6:
			var k1 := (k + 1) % 6
			_quad(g, a[k], a[k1], b[k1], b[k], foot + Vector3(0, a[k].y - foot.y, 0), ao_of)
	# chamfer
	for k in 6:
		var k1 := (k + 1) % 6
		_quad(g, edge[k], edge[k1], cham[k1], cham[k], top_c - lean * r, ao_of)
	# cap
	var cc := Vector3.ZERO
	for v in cham:
		cc += v
	cc /= 6.0
	for k in 6:
		_tri_out(g, cc, cham[k], cham[(k + 1) % 6], cc - top_n, ao_of)


static func _quad(g: Geo, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3, ao_of: Callable) -> void:
	_tri_out(g, a, b, c, inside, ao_of)
	_tri_out(g, a, c, d, inside, ao_of)


## Flat-shaded triangle, wound so it faces away from `inside`.
static func _tri_out(g: Geo, a: Vector3, b: Vector3, c: Vector3, inside: Vector3, ao_of: Callable) -> void:
	var base := g.p.size()
	g.p.append(a)
	g.p.append(b)
	g.p.append(c)
	for v in [a, b, c]:
		g.col.append(Color(float(ao_of.call((v as Vector3).y)), 1.0, 1.0))
	var into := (b - a).cross(c - a).dot(inside - (a + b + c) / 3.0) > 0.0
	g.t.append(base)
	if into:
		g.t.append(base + 1)
		g.t.append(base + 2)
	else:
		g.t.append(base + 2)
		g.t.append(base + 1)
	g.hard.append(1)


# --- shape operations -------------------------------------------------------------------------

## Cube-grid sphere mapped onto a superquadric (q = 2 ellipsoid .. large = box) with half extents
## `half`. Grid counts follow the extents so triangles stay even; total ~ `budget` triangles.
static func _rounded_box(half: Vector3, q: float, budget: int) -> Geo:
	var s := half * 2.0
	var area := 2.0 * (s.x * s.y + s.y * s.z + s.x * s.z)
	# small rocks don't need the full budget: cap the density (~750 tris per m2 of surface)
	budget = mini(budget, maxi(160, roundi(area * 750.0)))
	var step := sqrt(2.0 * area / float(budget))
	var cnt := Vector3i(clampi(roundi(s.x / step), 2, 40), clampi(roundi(s.y / step), 2, 40), clampi(roundi(s.z / step), 2, 40))
	var g := Geo.new()
	var weld := {}
	var faces := [
		[Vector3.RIGHT, Vector3.BACK, Vector3.UP, cnt.z, cnt.y], [Vector3.LEFT, Vector3.BACK, Vector3.UP, cnt.z, cnt.y],
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK, cnt.x, cnt.z], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK, cnt.x, cnt.z],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP, cnt.x, cnt.y], [Vector3.FORWARD, Vector3.RIGHT, Vector3.UP, cnt.x, cnt.y],
	]
	for f in faces:
		var nrm: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var nu: int = f[3]
		var nv: int = f[4]
		var ids := PackedInt32Array()
		for j in nv + 1:
			for i in nu + 1:
				var pb := nrm + u * (float(i) / float(nu) * 2.0 - 1.0) + v * (float(j) / float(nv) * 2.0 - 1.0)
				var key := Vector3i(roundi(pb.x * 4096.0), roundi(pb.y * 4096.0), roundi(pb.z * 4096.0))
				if not weld.has(key):
					# superquadric surface along pb (cube-sphere warp first evens the spacing)
					var d := _cube_to_sphere(pb)
					var r := pow(pow(absf(d.x), q) + pow(absf(d.y), q) + pow(absf(d.z), q), -1.0 / q)
					weld[key] = g.p.size()
					g.p.append(d * r * half)
					g.col.append(Color.WHITE)
				ids.append(weld[key])
		for j in nv:
			for i in nu:
				var a := ids[j * (nu + 1) + i]
				var b := ids[j * (nu + 1) + i + 1]
				var c := ids[(j + 1) * (nu + 1) + i + 1]
				var d2 := ids[(j + 1) * (nu + 1) + i]
				for tri in [[a, b, c], [a, c, d2]]:
					var pa := g.p[tri[0]]
					var pbv := g.p[tri[1]]
					var pc := g.p[tri[2]]
					g.t.append(tri[0])
					if (pbv - pa).cross(pc - pa).dot(nrm) > 0.0:
						g.t.append(tri[2])
						g.t.append(tri[1])
					else:
						g.t.append(tri[1])
						g.t.append(tri[2])
					g.hard.append(0)
	return g


static func _cube_to_sphere(p: Vector3) -> Vector3:
	var x2 := p.x * p.x
	var y2 := p.y * p.y
	var z2 := p.z * p.z
	return Vector3(p.x * sqrt(1.0 - y2 * 0.5 - z2 * 0.5 + y2 * z2 / 3.0),
		p.y * sqrt(1.0 - z2 * 0.5 - x2 * 0.5 + z2 * x2 / 3.0),
		p.z * sqrt(1.0 - x2 * 0.5 - y2 * 0.5 + x2 * y2 / 3.0))


## Scale/translate the vertices so their bounds are exactly lo..hi.
static func _fit(g: Geo, lo: Vector3, hi: Vector3) -> void:
	var mn := Vector3(INF, INF, INF)
	var mx := -mn
	for v in g.p:
		mn = mn.min(v)
		mx = mx.max(v)
	var span := (mx - mn).max(Vector3(1e-4, 1e-4, 1e-4))
	var k := (hi - lo) / span
	for i in g.p.size():
		g.p[i] = lo + (g.p[i] - mn) * k


## Outward direction of an ellipsoid-ish point (gradient), for displacing along the surface normal.
static func _dir(v: Vector3, half: Vector3) -> Vector3:
	var d := Vector3(v.x / (half.x * half.x), v.y / (half.y * half.y), v.z / (half.z * half.z))
	return d.normalized() if d.length_squared() > 1e-8 else Vector3.UP


## Clamp every vertex behind a plane: the plane's normal n, placed at `frac` of the shape's
## current support distance along n (measured from `origin`). Makes a flat facet.
static func _cut(g: Geo, n: Vector3, frac: float, origin: Vector3) -> void:
	var sup := -INF
	for v in g.p:
		sup = maxf(sup, (v - origin).dot(n))
	var d := sup * frac
	for i in g.p.size():
		var s := (g.p[i] - origin).dot(n) - d
		if s > 0.0:
			g.p[i] -= n * s


static func _strata(g: Geo, half: Vector3, axis: Vector3, spacing: float, depth: float) -> void:
	for i in g.p.size():
		var v := g.p[i]
		var t := v.dot(axis) / spacing + _fbm(v * 0.8 + Vector3(3, 7, 1), 2) * 0.5
		var f := t - floorf(t)
		# sawtooth ledges: each layer recedes towards its top, then steps out
		var s := smoothstep(0.0, 0.85, f) - smoothstep(0.88, 1.0, f)
		var hz := Vector3(v.x / half.x, 0.0, v.z / half.z).normalized()
		g.p[i] = v - Vector3(hz.x, 0.0, hz.z) * s * depth


## Ash: grooves along a 3D cellular crack network, and the ember region (COLOR.b) beside them.
static func _ember_cracks(g: Geo, half: Vector3, mn: float) -> void:
	for i in g.p.size():
		var v := g.p[i]
		var e := (_cell.get_noise_3dv(v * 1.0) + 1.0) * 0.5         # F2-F1: 0 at a crack
		var cr := 1.0 - smoothstep(0.0, 0.1, e)
		g.p[i] = v - _dir(v, half) * cr * clampf(mn * 0.04, 0.01, 0.06)
		var reg := 1.0 - smoothstep(0.05, 0.3, e)
		var c := g.col[i]
		c.b = 1.0 - reg
		g.col[i] = c


## Cavity AO into COLOR.r (concavity from the welded neighbour average, plus foot darkening).
static func _shade(g: Geo, sink: float, h: float) -> void:
	var n := g.p.size()
	var sum := PackedVector3Array()
	sum.resize(n)
	var cnt := PackedInt32Array()
	cnt.resize(n)
	var nrm := _vertex_normals(g)
	for i in range(0, g.t.size(), 3):
		for k in 3:
			var a := g.t[i + k]
			var b := g.t[i + (k + 1) % 3]
			sum[a] += g.p[b]
			cnt[a] += 1
			sum[b] += g.p[a]
			cnt[b] += 1
	var span := 0.0
	for i in n:
		if cnt[i] == 0:
			continue
		var cav := ((sum[i] / float(cnt[i])) - g.p[i]).dot(nrm[i])
		span = maxf(span, absf(cav))
	for i in n:
		var ao := 1.0
		if cnt[i] > 0 and span > 0.0:
			var cav := ((sum[i] / float(cnt[i])) - g.p[i]).dot(nrm[i]) / span
			ao = clampf(1.0 - maxf(cav, 0.0) * 1.4, 0.35, 1.0)
		ao *= lerpf(0.5, 1.0, smoothstep(-sink, minf(h * 0.3, 0.6), g.p[i].y))
		var c := g.col[i]
		c.r *= ao
		g.col[i] = c


## Moss caps: up-facing vertices (noise-broken) get COLOR.g = 1 - moss, pushed out by `thick`.
static func _moss_caps(g: Geo, thick: float, thresh: float) -> void:
	var nrm := _vertex_normals(g)
	for i in g.p.size():
		var v := g.p[i]
		var m := smoothstep(thresh, thresh + 0.25, nrm[i].y + _fbm(v * 1.7 + Vector3(4, 0, 9), 2) * 0.35)
		if thick > 0.0:
			g.p[i] = v + nrm[i] * m * thick * (0.6 + 0.8 * (_fbm(v * 4.0, 1) + 0.5))
		var c := g.col[i]
		c.g = 1.0 - m * (1.0 if thick > 0.0 else 0.6)
		g.col[i] = c


## Strata tone into COLOR.a (1 = neutral): each layer its own shade, a shadow line under each ledge. Same layering as
## _strata (the vertices have moved a little since, so the bands sit near the ledges, not exactly on them).
static func _band_tone(g: Geo, axis: Vector3, spacing: float, amt: float) -> void:
	for i in g.p.size():
		var v := g.p[i]
		var t := v.dot(axis) / spacing + _fbm(v * 0.8 + Vector3(3, 7, 1), 2) * 0.5
		var tone := 0.6 + 0.4 * fposmod(sin(floorf(t) * 12.9898 + 4.1) * 43758.5453, 1.0)
		var c := g.col[i]
		c.a = lerpf(1.0, tone * lerpf(0.8, 1.0, smoothstep(0.0, 0.2, t - floorf(t))), amt)
		g.col[i] = c


## Lichen: grey-green patches, noise-broken and favouring up-facing faces, into COLOR.b (styles without embers; the
## shader's vcol_lichen turns it on).
static func _lichen_paint(g: Geo, amt: float) -> void:
	var nrm := _vertex_normals(g)
	for i in g.p.size():
		var m := smoothstep(0.58, 0.78, _fbm(g.p[i] * 2.3 + Vector3(11, 2, 5), 3) + 0.5 + nrm[i].y * 0.12) * amt
		var c := g.col[i]
		c.b = 1.0 - m
		g.col[i] = c


## Smooth (area-weighted) normals per welded vertex. Outward = (c - a) x (b - a).
static func _vertex_normals(g: Geo) -> PackedVector3Array:
	var nrm := PackedVector3Array()
	nrm.resize(g.p.size())
	for i in range(0, g.t.size(), 3):
		var a := g.p[g.t[i]]
		var fn := (g.p[g.t[i + 2]] - a).cross(g.p[g.t[i + 1]] - a)
		for k in 3:
			nrm[g.t[i + k]] += fn
	for i in nrm.size():
		nrm[i] = nrm[i].normalized() if nrm[i].length_squared() > 1e-12 else Vector3.UP
	return nrm


# --- output -----------------------------------------------------------------------------------

## Auto-smoothed normals (faces within ~34 deg share a normal; sharper edges stay crisp), box UVs,
## tangents, surface material, LODs; cached under `key`.
static func _finish(g: Geo, style: String, key: String) -> ArrayMesh:
	var nt := g.t.size() / 3
	var fn := PackedVector3Array()
	fn.resize(nt)
	var fa := PackedFloat32Array()
	fa.resize(nt)
	var vf: Array[PackedInt32Array] = []
	vf.resize(g.p.size())
	for f in nt:
		var a := g.p[g.t[f * 3]]
		var n := (g.p[g.t[f * 3 + 2]] - a).cross(g.p[g.t[f * 3 + 1]] - a)
		fa[f] = n.length()
		fn[f] = n / fa[f] if fa[f] > 1e-12 else Vector3.ZERO
		for k in 3:
			vf[g.t[f * 3 + k]].append(f)
	var cos_t := cos(deg_to_rad(30.0))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in nt:
		if fa[f] < 1e-9:
			continue
		for k in 3:
			var vi := g.t[f * 3 + k]
			var n := Vector3.ZERO
			if g.hard.size() > f and g.hard[f] == 1:
				n = fn[f]
			else:
				for o in vf[vi]:
					if fn[o].dot(fn[f]) > cos_t:
						n += fn[o] * fa[o]
				n = n.normalized() if n.length_squared() > 1e-16 else fn[f]
			var v := g.p[vi]
			st.set_normal(n)
			st.set_color(g.col[vi])
			var an := n.abs()
			var uv := Vector2(v.z, v.y) if an.x >= an.y and an.x >= an.z else (Vector2(v.x, v.z) if an.y >= an.z else Vector2(v.x, v.y))
			st.set_uv(uv * 0.5)
			st.add_vertex(v)
	st.index()
	st.generate_tangents()
	var raw := st.commit()
	raw.surface_set_material(0, material(style))
	var mesh := MeshChunksS.with_lods(raw) as ArrayMesh
	if mesh == null:
		mesh = raw
	mesh.resource_name = key
	_meshes[key] = mesh
	GenCache.save_mesh(key, SELF, mesh)
	Realm.prof_add("gen: rockkit", _t_gen)
	return mesh


## A mesh built by an earlier run (GenCache), with this run's shared material put back.
static func _from_disk(key: String) -> ArrayMesh:
	var m := GenCache.load_mesh(key, SELF)
	if m == null:
		return null
	var style := key.split("|")[2] if key.begins_with("boulder") or key.begins_with("cliff") or key.begins_with("slab") or key.begins_with("cairn") else "basalt"
	for i in m.get_surface_count():
		if m.surface_get_material(i) == null:
			m.surface_set_material(i, material(style))
	_meshes[key] = m
	return m


# --- helpers ----------------------------------------------------------------------------------

static func _style(s: String) -> String:
	return s if s in STYLES else "granite"


static func _bucket(size: Vector3) -> Vector3i:
	var l := log(1.12)
	return Vector3i(roundi(log(maxf(size.x, 0.1)) / l), roundi(log(maxf(size.y, 0.1)) / l), roundi(log(maxf(size.z, 0.1)) / l))


static func _unbucket(b: Vector3i) -> Vector3:
	return Vector3(pow(1.12, b.x), pow(1.12, b.y), pow(1.12, b.z))


static func _rng(key: String) -> RandomNumberGenerator:
	_t_gen = Time.get_ticks_usec()
	var r := RandomNumberGenerator.new()
	r.seed = hash(key)
	return r


static func _rand_dir(rng: RandomNumberGenerator, min_y: float) -> Vector3:
	for _i in 16:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		if d.length_squared() > 0.05 and d.length_squared() <= 1.0 and d.normalized().y >= min_y:
			return d.normalized()
	return Vector3(1, 0.3, 0).normalized()


static func _seed_noise(s: int) -> void:
	if _n == null:
		_n = FastNoiseLite.new()
		_n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_n.frequency = 1.0
		_n.fractal_type = FastNoiseLite.FRACTAL_NONE
		_cell = FastNoiseLite.new()
		_cell.noise_type = FastNoiseLite.TYPE_CELLULAR
		_cell.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
		_cell.cellular_jitter = 1.0
		_cell.frequency = 1.0
		_cell.fractal_type = FastNoiseLite.FRACTAL_NONE
	_n.seed = s
	_cell.seed = s + 7


## Fractal simplex in about [-0.5, 0.5].
static func _fbm(v: Vector3, oct: int) -> float:
	var s := 0.0
	var amp := 0.5
	var f := 1.0
	var norm := 0.0
	for o in oct:
		s += _n.get_noise_3dv(v * f) * amp
		norm += amp
		amp *= 0.5
		f *= 2.07
	return s / norm * 0.5


static func _p(m: ShaderMaterial, d: Dictionary) -> void:
	for k: String in d:
		m.set_shader_parameter(k, d[k])
