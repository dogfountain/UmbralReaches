class_name OssKit
extends RefCounted
## Procedural building kit for the Ossuary: every solid piece is appended into ONE SurfaceTool
## per material, so a whole tier costs a handful of draw calls. Materials are world-triplanar
## (no UVs), so pieces can be any size without stretching. Small repeated props (skulls, bones,
## candles, flames) are MultiMeshes. Godot front faces wind clockwise; `quad()` orders vertices
## from the outward normal so callers never think about winding.

const T := "res://art/textures/"
const FLAME := preload("res://world/areas/ossuary/candle_flame.gdshader")

var _st: Dictionary = {}        # mat key -> SurfaceTool
var col_faces := PackedVector3Array()   # collision triangles (solid pieces only)
var candles: Array[Transform3D] = []
var skulls: Array[Transform3D] = []
var bones: Array[Transform3D] = []

static var _mats: Dictionary = {}
static var _skull: ArrayMesh
static var _bone: ArrayMesh
static var _candle: CylinderMesh
static var _flame_mesh: QuadMesh


# --- materials ------------------------------------------------------------------------------

static func mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	match key:
		"stone":      _tri(m, "tavern_stone", 0.5, Color(0.8, 0.76, 0.74))
		"plaster":    _tri(m, "tavern_plaster", 0.3, Color(0.86, 0.8, 0.72))
		"floor":      _tri(m, "stone", 0.35, Color(0.62, 0.6, 0.6))
		"dark":       _tri(m, "rock", 0.5, Color(0.16, 0.14, 0.15))
		"iron":       _tri(m, "tavern_iron", 0.6, Color(0.5, 0.48, 0.5))
		"wood":       _tri(m, "tavern_wood", 0.5, Color(0.55, 0.45, 0.38))
		"slate":      _tri(m, "tavern_slate", 0.4, Color(0.42, 0.42, 0.5))
		"bone":
			m.albedo_color = Color(0.86, 0.8, 0.68)
			m.vertex_color_use_as_albedo = true
			m.roughness = 0.62
			m.normal_enabled = true
			m.normal_texture = load(T + "micro_normal.png")
			m.normal_scale = 0.6
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3.ONE * 2.0
			m.rim_enabled = true
			m.rim = 0.2
		"wax":
			m.albedo_color = Color(0.86, 0.82, 0.7)
			m.roughness = 0.5
			m.emission_enabled = true
			m.emission = Color(1.0, 0.7, 0.4)
			m.emission_energy_multiplier = 0.08
		"glow":
			# lit window glass: warm, emissive, just over the glow threshold at its brightest
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.vertex_color_use_as_albedo = true
			m.albedo_color = Color(1.0, 0.62, 0.3)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.5, 0.18)
			m.emission_energy_multiplier = 1.25
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"flame":
			var sm := ShaderMaterial.new()
			sm.shader = FLAME
			_mats[key] = sm
			return sm
	_mats[key] = m
	return m


static func _tri(m: StandardMaterial3D, tex: String, scale: float, tint: Color) -> void:
	m.albedo_texture = load(T + tex + "_albedo.png")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(T + tex + "_normal.png")
	m.roughness_texture = load(T + tex + "_rough.png")
	m.ao_enabled = ResourceLoader.exists(T + tex + "_ao.png")
	if m.ao_enabled:
		m.ao_texture = load(T + tex + "_ao.png")
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC


# --- primitive writers ----------------------------------------------------------------------

func _tool(key: String) -> SurfaceTool:
	if not _st.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_st[key] = st
	return _st[key]


## One quad a-b-c-d (any rotation), facing `out`. Flat-shaded. `solid` adds it to collision.
func quad(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3, solid := true, shade := 1.0) -> void:
	var st := _tool(key)
	var n := out.normalized()
	var tri: Array[Vector3] = [a, b, c, a, c, d]
	if (b - a).cross(c - a).dot(n) > 0.0:     # counter-clockwise from outside -> flip
		tri = [a, c, b, a, d, c]
	var col := Color(shade, shade, shade)
	for v in tri:
		st.set_normal(n)
		st.set_color(col)
		st.add_vertex(v)
	if solid:
		col_faces.append_array(PackedVector3Array(tri))


## Oriented box. `b` columns are the box axes (unit); size is full extents along them.
func box(key: String, c: Vector3, size: Vector3, b := Basis.IDENTITY, solid := true, shade := 1.0) -> void:
	var hx := b.x * size.x * 0.5
	var hy := b.y * size.y * 0.5
	var hz := b.z * size.z * 0.5
	for s: float in [-1.0, 1.0]:
		var f := c + hx * s
		quad(key, f - hy - hz, f + hy - hz, f + hy + hz, f - hy + hz, b.x * s, solid, shade)
		f = c + hy * s
		quad(key, f - hx - hz, f + hx - hz, f + hx + hz, f - hx + hz, b.y * s, solid, shade)
		f = c + hz * s
		quad(key, f - hx - hy, f + hx - hy, f + hx + hy, f - hx + hy, b.z * s, solid, shade)


## Axis-aligned box from min corner to max corner.
func block(key: String, lo: Vector3, hi: Vector3, solid := true, shade := 1.0) -> void:
	box(key, (lo + hi) * 0.5, (hi - lo).abs(), Basis.IDENTITY, solid, shade)


## Pointed (lancet) arch curve for a span `w` springing at y=0: points from left foot over the
## apex to the right foot. `k` = radius / span (0.5 round, 1.0 equilateral, >1 lancet).
static func arch_curve(w: float, k: float, n := 8, grow := 0.0) -> PackedVector2Array:
	var r := k * w + grow
	var cx := -w * 0.5 + k * w             # centre of the left half's arc (right of the left foot)
	var pts := PackedVector2Array()
	var a0 := PI
	var a1 := acos(clampf(-cx / r, -1.0, 1.0))
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / float(n))
		pts.append(Vector2(cx + cos(a) * r, sin(a) * r))
	for i in range(n - 1, -1, -1):        # mirror for the right half
		pts.append(Vector2(-pts[i].x, pts[i].y))
	return pts


## A wall panel with a pointed opening, lying in the plane spanned by `along` (unit, horizontal)
## and UP, centred at `c` (base of the opening, wall mid-thickness). The panel is `w + 2*jamb`
## wide and `top` tall; the opening is `w` wide and springs at `spring` (0 = doorway to floor).
## `sill` > 0 leaves a solid sill (a window). `ring` adds a moulded arch ring in `ring_key`.
func arch_panel(key: String, c: Vector3, along: Vector3, w: float, spring: float, top: float, thick: float, jamb := 0.6, k := 0.85, sill := 0.0, ring_key := "") -> void:
	var nrm := along.cross(Vector3.UP).normalized()        # panel normal (one face)
	var half := w * 0.5 + jamb
	var curve := arch_curve(w, k, 7)
	var apex := curve[curve.size() / 2].y
	var top_y: float = maxf(top, spring + apex + 0.3)
	var p := func(x: float, y: float, side: float) -> Vector3: return c + along * x + Vector3.UP * y + nrm * (side * thick * 0.5)
	# jambs (solid both sides of the opening, full height)
	for s: float in [-1.0, 1.0]:
		var x0: float = s * w * 0.5
		var x1: float = s * half
		var mid := c + along * ((x0 + x1) * 0.5) + Vector3.UP * (top_y * 0.5)
		box(key, mid, Vector3(absf(x1 - x0), top_y, thick), Basis(along, Vector3.UP, nrm))
	# sill
	if sill > 0.0:
		box(key, c + Vector3.UP * (sill * 0.5), Vector3(w, sill, thick), Basis(along, Vector3.UP, nrm))
	# spandrel above the arch: for each curve segment, faces from the curve up to top_y
	for i in curve.size() - 1:
		var a := curve[i]
		var b := curve[i + 1]
		var ya := spring + a.y
		var yb := spring + b.y
		for side: float in [-1.0, 1.0]:
			quad(key, p.call(a.x, ya, side), p.call(b.x, yb, side), p.call(b.x, top_y, side), p.call(a.x, top_y, side), nrm * side)
		# intrados (underside of the arch, faces into the opening)
		var t := Vector2(b.x - a.x, b.y - a.y).normalized()
		var down := along * t.y * -1.0 + Vector3.UP * t.x * 1.0    # perpendicular to the tangent
		if down.y > 0.0:
			down = -down
		quad(key, p.call(a.x, ya, -1.0), p.call(b.x, yb, -1.0), p.call(b.x, yb, 1.0), p.call(a.x, ya, 1.0), down)
	# top cap
	quad(key, p.call(-half, top_y, -1.0), p.call(half, top_y, -1.0), p.call(half, top_y, 1.0), p.call(-half, top_y, 1.0), Vector3.UP)
	if ring_key != "":
		_arch_ring(ring_key, c + Vector3.UP * spring, along, nrm, w, k, thick + 0.12)


## Raised moulding following the arch (a separate material so it reads as dressed stone).
func _arch_ring(key: String, base: Vector3, along: Vector3, nrm: Vector3, w: float, k: float, depth: float) -> void:
	var inner := arch_curve(w, k, 7)
	var outer := arch_curve(w, k, 7, 0.22)
	for i in inner.size() - 1:
		var pts: Array[Vector3] = []
		for q in [inner[i], inner[i + 1], outer[i + 1], outer[i]]:
			pts.append(base + along * (q as Vector2).x + Vector3.UP * (q as Vector2).y)
		for side: float in [-1.0, 1.0]:
			var o := nrm * (side * depth * 0.5)
			quad(key, pts[0] + o, pts[1] + o, pts[2] + o, pts[3] + o, nrm * side, false)
		var e := Vector3(pts[3] - pts[0]).normalized()
		quad(key, pts[3] - nrm * depth * 0.5, pts[2] - nrm * depth * 0.5, pts[2] + nrm * depth * 0.5, pts[3] + nrm * depth * 0.5, e, false)


## Straight flight from `lo` (foot, floor height) up to `hi` (head, floor height), `width` across.
## Steps are visual only; collision is one smooth ramp under the nosings (CharacterBody-friendly).
func stairs(key: String, lo: Vector3, hi: Vector3, width: float, steps: int) -> void:
	var run := Vector3(hi.x - lo.x, 0.0, hi.z - lo.z)
	var dir := run.normalized()
	var side := dir.cross(Vector3.UP).normalized()
	var tread := run.length() / float(steps)
	var rise := (hi.y - lo.y) / float(steps)
	var bas := Basis(side, Vector3.UP, dir)
	for i in steps:
		var top := lo.y + rise * float(i + 1)
		var bottom := lo.y - 0.5
		var c := lo + dir * (tread * (float(i) + 0.5))
		box(key, Vector3(c.x, (top + bottom) * 0.5, c.z), Vector3(width, top - bottom, tread + 0.02), bas, false, 0.9 if i % 2 == 0 else 1.0)
	var f := (hi - lo).normalized()
	var u := side.cross(f).normalized()
	if u.y < 0.0:
		u = -u
	var rb := Basis(side, u, f)
	# top face runs exactly floor-to-floor (lo -> hi): no lip at either end to snag the capsule
	var mid := (lo + hi) * 0.5 - u * 0.15
	_ramp_faces(mid, Vector3(width, 0.3, (hi - lo).length()), rb)


func _ramp_faces(c: Vector3, size: Vector3, b: Basis) -> void:
	var tmp := OssKit.new()
	tmp.box("x", c, size, b)
	col_faces.append_array(tmp.col_faces)


## Square pinnacle: shaft `w` wide and `h` tall from `base`, then a pyramid of `spike` height.
func pinnacle(key: String, base: Vector3, w: float, h: float, spike: float) -> void:
	box(key, base + Vector3.UP * (h * 0.5), Vector3(w, h, w))
	box(key, base + Vector3.UP * (h - 0.15), Vector3(w * 1.25, 0.3, w * 1.25), Basis.IDENTITY, true, 0.85)
	var top := base + Vector3.UP * h
	var apex := top + Vector3.UP * spike
	var hw := w * 0.5
	var c: Array[Vector3] = [top + Vector3(-hw, 0, -hw), top + Vector3(hw, 0, -hw), top + Vector3(hw, 0, hw), top + Vector3(-hw, 0, hw)]
	for i in 4:
		var a := c[i]
		var b := c[(i + 1) % 4]
		var out := ((a + b) * 0.5 - top).normalized() + Vector3.UP * (hw / spike)
		quad(key, a, b, apex, apex, out)


## Glowing pane filling a pointed opening (lit from within). Two-sided, no collision.
func glow_pane(base: Vector3, along: Vector3, w: float, sill: float, spring: float, k := 0.85) -> void:
	var nrm := along.cross(Vector3.UP).normalized()
	var p := func(x: float, y: float) -> Vector3: return base + along * x + Vector3.UP * y
	var hw := w * 0.5
	quad("glow", p.call(-hw, sill), p.call(hw, sill), p.call(hw, spring), p.call(-hw, spring), nrm, false, 0.75)
	var curve := arch_curve(w, k, 7)
	var mid: Vector3 = p.call(0.0, spring)
	for i in curve.size() - 1:
		quad("glow", mid, p.call(curve[i].x, spring + curve[i].y), p.call(curve[i + 1].x, spring + curve[i + 1].y), mid, nrm, false, 1.0)
	# mullion and transom bars
	box("iron", p.call(0.0, (sill + spring + curve[curve.size() / 2].y) * 0.5), Vector3(0.06, spring + curve[curve.size() / 2].y - sill, 0.08), Basis(along, Vector3.UP, nrm), false)
	box("iron", p.call(0.0, (sill + spring) * 0.55), Vector3(w, 0.06, 0.08), Basis(along, Vector3.UP, nrm), false)


## Parapet with merlon-like posts along a->b.
func parapet(key: String, a: Vector3, b: Vector3, h := 1.0, t := 0.35) -> void:
	var d := b - a
	var along := Vector3(d.x, 0.0, d.z).normalized()
	var bas := Basis(along, Vector3.UP, along.cross(Vector3.UP).normalized())
	box(key, (a + b) * 0.5 + Vector3.UP * (h * 0.5), Vector3(d.length(), h, t), bas)
	var n := maxi(1, int(d.length() / 2.2))
	for i in n + 1:
		var p := a.lerp(b, float(i) / float(n))
		box(key, p + Vector3.UP * (h * 0.5 + 0.15), Vector3(0.5, h + 0.3, t + 0.15), bas)


# --- props (MultiMesh) ----------------------------------------------------------------------

func candle_cluster(at: Vector3, n: int, spread := 0.25, rng: RandomNumberGenerator = null) -> void:
	for i in n:
		var a := rng.randf() * TAU if rng else float(i) * 2.4
		var r := spread * sqrt(rng.randf() if rng else float(i) / float(n))
		var h := rng.randf_range(0.12, 0.42) if rng else 0.25
		var s := rng.randf_range(0.8, 1.25) if rng else 1.0
		var p := at + Vector3(cos(a) * r, 0.0, sin(a) * r)
		candles.append(Transform3D(Basis.IDENTITY.scaled(Vector3(s, h / 0.3, s)), p + Vector3.UP * h * 0.5))


func skull(at: Vector3, yaw: float, s := 1.0) -> void:
	skulls.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), at))


func bone(at: Vector3, b: Basis) -> void:
	bones.append(Transform3D(b, at))


static func skull_mesh() -> ArrayMesh:
	if _skull:
		return _skull
	var cm := CreatureMesh.new(77)
	var w := Color(1, 1, 1)
	var hole := Color(0.08, 0.06, 0.05)
	cm.blob(Vector3(0, 0.1, 0.02), Vector3(0.1, 0.095, 0.12), Basis.IDENTITY, w, 0.0, 0.05, 0.0, 6, 9)
	cm.blob(Vector3(0, 0.035, -0.07), Vector3(0.07, 0.06, 0.06), Basis.IDENTITY, w, 0.0, 0.05, 0.0, 5, 8)
	for s: float in [-1.0, 1.0]:
		cm.blob(Vector3(s * 0.033, 0.07, -0.11), Vector3(0.026, 0.024, 0.02), Basis.IDENTITY, hole, 0.0, 0.0, 0.0, 4, 6)
	cm.blob(Vector3(0, 0.035, -0.125), Vector3(0.012, 0.016, 0.01), Basis.IDENTITY, hole, 0.0, 0.0, 0.0, 3, 5)
	cm.blob(Vector3(0, -0.01, -0.06), Vector3(0.055, 0.025, 0.05), Basis.IDENTITY, w, 0.0, 0.03, 0.0, 4, 7)
	_skull = cm.commit()
	return _skull


static func bone_mesh() -> ArrayMesh:
	if _bone:
		return _bone
	var cm := CreatureMesh.new(78)
	cm.tube(PackedVector3Array([Vector3(0, 0, -0.22), Vector3(0, 0.005, 0.0), Vector3(0, 0, 0.22)]), PackedFloat32Array([0.022, 0.016, 0.022]), 5)
	for z: float in [-0.23, 0.23]:
		for s: float in [-1.0, 1.0]:
			cm.blob(Vector3(s * 0.018, 0, z), Vector3(0.024, 0.022, 0.024), Basis.IDENTITY, Color.WHITE, 0.0, 0.0, 0.0, 3, 5)
	_bone = cm.commit()
	return _bone


static func multimesh(mesh: Mesh, xforms: Array[Transform3D], mat_override: Material, shadows := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat_override
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


## Commit everything under `parent`: one MeshInstance3D per material, one StaticBody3D with the
## collision soup, and the prop MultiMeshes. Returns the draw-call count it added.
func commit(parent: Node3D, body_name := "Body") -> int:
	var draws := 0
	for key in _st:
		var st: SurfaceTool = _st[key]
		var mi := MeshInstance3D.new()
		mi.name = "Mesh_" + key
		mi.mesh = st.commit()
		mi.material_override = mat(key)
		parent.add_child(mi)
		draws += 1
	if not col_faces.is_empty():
		var body := StaticBody3D.new()
		body.name = body_name
		body.collision_layer = Layers.WORLD
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(col_faces)
		shape.backface_collision = true
		cs.shape = shape
		body.add_child(cs)
		parent.add_child(body)
	if not skulls.is_empty():
		var m := multimesh(skull_mesh(), skulls, mat("bone"), false)
		m.name = "Skulls"
		parent.add_child(m)
		draws += 1
	if not bones.is_empty():
		var m := multimesh(bone_mesh(), bones, mat("bone"), false)
		m.name = "Bones"
		parent.add_child(m)
		draws += 1
	if not candles.is_empty():
		if _candle == null:
			_candle = CylinderMesh.new()
			_candle.top_radius = 0.035
			_candle.bottom_radius = 0.04
			_candle.height = 0.3
			_candle.radial_segments = 6
			_candle.rings = 1
			_flame_mesh = QuadMesh.new()
			_flame_mesh.size = Vector2(0.09, 0.2)
		var wax := multimesh(_candle, candles, mat("wax"), false)
		wax.name = "Candles"
		parent.add_child(wax)
		var tips: Array[Transform3D] = []
		for t in candles:
			tips.append(Transform3D(Basis.IDENTITY, t.origin + Vector3.UP * (t.basis.y.length() * 0.15 + 0.09)))
		var fl := multimesh(_flame_mesh, tips, mat("flame"), false)
		fl.name = "Flames"
		parent.add_child(fl)
		draws += 2
	return draws
