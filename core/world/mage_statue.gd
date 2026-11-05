class_name MageStatue
extends Node3D
## The summit monument: a weathered stone mage, hooded and bearded, in a folded robe and a
## heavy mantle, one hand gripping a tall staff whose clawed head holds a living orb, the other
## held out over the stair in a casting gesture. Octagonal pedestal with a glowing rune band and
## candles. Built in code (one merged stone mesh + pedestal + orb), cached, ~12k tris.
##
## Local frame: feet of the figure at y = PEDESTAL_H, facing -Z (rotate the node to aim it).

const PEDESTAL_H := 1.55
const FIG_SCALE := 1.45
const T := "res://art/textures/"

static var _figure: ArrayMesh
static var _pedestal: ArrayMesh
static var _runes: ArrayMesh
static var _mats: Dictionary = {}

var _orb: MeshInstance3D
var _orb_light: OmniLight3D
var _t := 0.0


func _ready() -> void:
	if _figure == null:
		# deterministic meshes: built once, then loaded (GenCache) -- the figure was ~0.3 s a load
		var GenCache := load("res://core/world/realm/gen_cache.gd")
		var me := "res://core/world/mage_statue.gd"
		_figure = GenCache.load_mesh("statue|figure", me)
		_pedestal = GenCache.load_mesh("statue|pedestal", me)
		_runes = GenCache.load_mesh("statue|runes", me)
		if _figure == null or _pedestal == null or _runes == null:
			_figure = _build_figure()
			_pedestal = _build_pedestal()
			_runes = _build_runes()
			GenCache.save_mesh("statue|figure", me, _figure)
			GenCache.save_mesh("statue|pedestal", me, _pedestal)
			GenCache.save_mesh("statue|runes", me, _runes)
	var ped := MeshInstance3D.new()
	ped.name = "Pedestal"
	ped.mesh = _pedestal
	ped.material_override = _mat("stone")
	add_child(ped)
	var runes := MeshInstance3D.new()
	runes.name = "Runes"
	runes.mesh = _runes
	runes.material_override = _mat("rune")
	runes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(runes)
	var fig := MeshInstance3D.new()
	fig.name = "Figure"
	fig.mesh = _figure
	fig.material_override = _mat("statue")
	fig.position = Vector3(0, PEDESTAL_H, 0)
	fig.scale = Vector3.ONE * FIG_SCALE
	add_child(fig)
	_build_orb()
	_build_candles()
	_build_collision()


# --- materials ------------------------------------------------------------------------------

static func _mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	match key:
		"statue", "stone":
			var tex := "oss_statue" if key == "statue" else "oss_ashlar"
			m.albedo_texture = load(T + tex + "_albedo.png")
			m.normal_enabled = true
			m.normal_texture = load(T + tex + "_normal.png")
			m.roughness_texture = load(T + tex + "_rough.png")
			m.ao_enabled = true
			m.ao_texture = load(T + tex + "_ao.png")
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_triplanar_sharpness = 3.0
			m.uv1_scale = Vector3.ONE * (0.55 if key == "statue" else 0.4)
			m.vertex_color_use_as_albedo = true
			m.albedo_color = Color(0.86, 0.87, 0.9) if key == "statue" else Color(0.8, 0.8, 0.84)
			m.rim_enabled = true
			m.rim = 0.3
			m.rim_tint = 0.5
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		"rune":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(0.7, 0.85, 1.6)
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"orb":
			m.albedo_color = Color(0.75, 0.85, 1.0)
			m.emission_enabled = true
			m.emission = Color(0.45, 0.62, 1.0)
			m.emission_energy_multiplier = 3.0
			m.roughness = 0.2
			m.rim_enabled = true
			m.rim = 1.0
	_mats[key] = m
	return m


# --- geometry helpers -----------------------------------------------------------------------

## Lathe a profile (radius, y) round the Y axis between angles a0..a1 (radians, 0 = -Z front),
## with vertical drapery folds: radius *= 1 + fold_amp(t) * sin(angle * folds + phase), where the
## amplitude grows toward the hem (t = 0 top .. 1 bottom). Outward-facing, smooth-shaded.
static func _lathe(prof: Array[Vector2], a0: float, a1: float, segs: int, folds: float, amp_top: float, amp_hem: float, shade_hem := 0.75) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := prof.size()
	var grid: Array = []
	for i in rows:
		var t := float(i) / float(rows - 1)
		var row: Array[Vector3] = []
		for j in segs + 1:
			var a := lerpf(a0, a1, float(j) / float(segs))
			var amp := lerpf(amp_top, amp_hem, t)
			var r := prof[i].x * (1.0 + amp * sin(a * folds + 1.3 + t * 0.8))
			row.append(Vector3(sin(a) * r, prof[i].y, -cos(a) * r))
		grid.append(row)
	for i in rows - 1:
		var t0 := float(i) / float(rows - 1)
		var t1 := float(i + 1) / float(rows - 1)
		for j in segs:
			var p00: Vector3 = grid[i][j]
			var p01: Vector3 = grid[i][j + 1]
			var p10: Vector3 = grid[i + 1][j]
			var p11: Vector3 = grid[i + 1][j + 1]
			var c00 := Color.WHITE.lerp(Color(shade_hem, shade_hem, shade_hem), t0)
			var c10 := Color.WHITE.lerp(Color(shade_hem, shade_hem, shade_hem), t1)
			for tri: Array in [[p00, p01, p11, c00, c00, c10], [p00, p11, p10, c00, c10, c10]]:
				var v0: Vector3 = tri[0]
				var v1: Vector3 = tri[1]
				var v2: Vector3 = tri[2]
				var n := (v1 - v0).cross(v2 - v0)
				var out := Vector3(v0.x + v1.x + v2.x, 0.0, v0.z + v1.z + v2.z)
				var order: Array[int] = [0, 1, 2]
				if n.dot(out) >= 0.0:
					order = [0, 2, 1]                # Godot: clockwise = front face
				for k: int in order:
					st.set_color(tri[3 + k])
					st.add_vertex(tri[k])
	st.index()
	st.generate_normals()
	return st.commit()


static func _merge(meshes: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for m: ArrayMesh in meshes:
		st.append_from(m, 0, Transform3D.IDENTITY)
	return st.commit()


# --- the figure -----------------------------------------------------------------------------

static func _build_figure() -> ArrayMesh:
	var parts: Array = []
	# robe: hem flare, falling folds, waist, chest, shoulders
	parts.append(_lathe([Vector2(0.2, 2.78), Vector2(0.3, 2.68), Vector2(0.47, 2.52), Vector2(0.44, 2.3), Vector2(0.38, 2.0),
		Vector2(0.33, 1.62), Vector2(0.38, 1.5), Vector2(0.44, 1.1), Vector2(0.52, 0.6), Vector2(0.6, 0.18), Vector2(0.66, 0.02), Vector2(0.6, 0.0)],
		0.0, TAU, 40, 9.0, 0.015, 0.11))
	# mantle over the shoulders and down the back (open at the front)
	parts.append(_lathe([Vector2(0.22, 2.84), Vector2(0.42, 2.7), Vector2(0.56, 2.5), Vector2(0.58, 2.1), Vector2(0.62, 1.4),
		Vector2(0.7, 0.7), Vector2(0.78, 0.12), Vector2(0.8, 0.04)],
		0.95, TAU - 0.95, 30, 7.0, 0.02, 0.13, 0.7))
	# hood: cowl round the head, open at the face, peak at the back
	parts.append(_lathe([Vector2(0.02, 3.42), Vector2(0.16, 3.36), Vector2(0.25, 3.22), Vector2(0.28, 3.02), Vector2(0.27, 2.86), Vector2(0.24, 2.78)],
		0.72, TAU - 0.72, 20, 5.0, 0.02, 0.06, 0.85))
	var cm := CreatureMesh.new(5150)
	var w := Color.WHITE
	var shade := Color(0.55, 0.55, 0.58)
	# hood peak: a long wizard's point swept back and down
	cm.tube(PackedVector3Array([Vector3(0, 3.3, 0.04), Vector3(0, 3.55, 0.14), Vector3(0, 3.74, 0.34), Vector3(0, 3.8, 0.6), Vector3(0, 3.7, 0.8)]),
		PackedFloat32Array([0.2, 0.14, 0.09, 0.05, 0.015]), 9, w, 0.0, 0.04)
	# face in the shadow of the hood: brow, nose, cheeks, and a long forked beard
	cm.blob(Vector3(0, 3.0, -0.04), Vector3(0.14, 0.17, 0.15), Basis.IDENTITY, shade, 0.0, 0.03, 0.0, 6, 9)
	cm.blob(Vector3(0, 3.07, -0.17), Vector3(0.12, 0.03, 0.04), Basis.IDENTITY, w, 0.0, 0.03, 0.0, 4, 7)
	cm.blob(Vector3(0, 3.0, -0.2), Vector3(0.025, 0.06, 0.035), Basis(Vector3.RIGHT, -0.2), w, 0.0, 0.02, 0.0, 4, 6)
	for s: float in [-1.0, 1.0]:
		cm.blob(Vector3(s * 0.06, 3.06, -0.16), Vector3(0.03, 0.014, 0.012), Basis.IDENTITY, Color(0.25, 0.25, 0.28), 0.0, 0.0, 0.0, 3, 5)
		cm.blob(Vector3(s * 0.075, 2.97, -0.15), Vector3(0.04, 0.035, 0.035), Basis.IDENTITY, w, 0.0, 0.02, 0.0, 3, 6)
		cm.tube(PackedVector3Array([Vector3(s * 0.07, 2.95, -0.16), Vector3(s * 0.04, 2.92, -0.2)]), PackedFloat32Array([0.02, 0.014]), 5, w)   # moustache
	cm.tube(PackedVector3Array([Vector3(0, 2.95, -0.17), Vector3(0, 2.78, -0.24), Vector3(0, 2.55, -0.27), Vector3(0, 2.3, -0.27)]),
		PackedFloat32Array([0.11, 0.1, 0.07, 0.03]), 9, w, 0.0, 0.08, 0.0, Vector2(1.0, 0.65))
	for s: float in [-1.0, 1.0]:
		cm.tube(PackedVector3Array([Vector3(s * 0.02, 2.4, -0.27), Vector3(s * 0.05, 2.22, -0.26), Vector3(s * 0.07, 2.08, -0.24)]), PackedFloat32Array([0.03, 0.02, 0.006]), 5, w)
	# belt, clasp, hanging tome
	cm.tube(PackedVector3Array([Vector3(-0.34, 1.6, 0.0), Vector3(-0.24, 1.58, -0.26), Vector3(0, 1.57, -0.34), Vector3(0.24, 1.58, -0.26), Vector3(0.34, 1.6, 0.0),
		Vector3(0.24, 1.62, 0.25), Vector3(0, 1.63, 0.33), Vector3(-0.24, 1.62, 0.25), Vector3(-0.34, 1.6, 0.0)]), PackedFloat32Array([0.035, 0.035, 0.035, 0.035, 0.035, 0.035, 0.035, 0.035, 0.035]), 5, w)
	cm.blob(Vector3(0, 1.57, -0.36), Vector3(0.06, 0.06, 0.03), Basis.IDENTITY, w, 0.0, 0.0, 0.0, 4, 6)
	cm.tube(PackedVector3Array([Vector3(0, 1.55, -0.35), Vector3(0, 1.1, -0.42), Vector3(0, 0.55, -0.5), Vector3(0, 0.12, -0.6)]), PackedFloat32Array([0.09, 0.1, 0.11, 0.11]), 4, w, 0.0, 0.02, 0.0, Vector2(1.0, 0.18))   # tabard
	cm.blob(Vector3(-0.38, 1.38, -0.06), Vector3(0.1, 0.13, 0.05), Basis(Vector3.UP, 0.4), shade, 0.0, 0.02, 0.0, 3, 6)   # tome at the hip
	cm.blob(Vector3(0, 2.62, -0.33), Vector3(0.06, 0.06, 0.04), Basis.IDENTITY, w, 0.0, 0.05, 0.0, 4, 6)   # mantle clasp
	# right arm (statue's right = +x): raised, gripping the staff
	var staff_x := 0.62
	var staff_z := -0.38
	cm.tube(PackedVector3Array([Vector3(0.4, 2.56, 0.0), Vector3(0.6, 2.25, -0.08), Vector3(0.62, 2.3, -0.3), Vector3(staff_x, 2.42, staff_z + 0.04)]),
		PackedFloat32Array([0.13, 0.14, 0.16, 0.19]), 10, w, 0.0, 0.06)                                     # sleeve, belling at the cuff
	cm.blob(Vector3(staff_x, 2.44, staff_z), Vector3(0.07, 0.09, 0.07), Basis.IDENTITY, w, 0.0, 0.03, 0.0, 5, 7)     # fist
	# left arm: out over the stair, palm down, fingers spread
	cm.tube(PackedVector3Array([Vector3(-0.4, 2.56, 0.0), Vector3(-0.6, 2.4, -0.22), Vector3(-0.66, 2.5, -0.55), Vector3(-0.64, 2.56, -0.82)]),
		PackedFloat32Array([0.13, 0.14, 0.15, 0.18]), 10, w, 0.0, 0.06)
	# the wide sleeve hangs below the outstretched forearm
	cm.tube(PackedVector3Array([Vector3(-0.66, 2.44, -0.62), Vector3(-0.68, 2.2, -0.6), Vector3(-0.67, 1.95, -0.55), Vector3(-0.64, 1.78, -0.5)]),
		PackedFloat32Array([0.16, 0.15, 0.12, 0.05]), 8, w, 0.0, 0.05, 0.0, Vector2(1.0, 0.35))
	var palm := Vector3(-0.63, 2.55, -0.93)
	cm.blob(palm, Vector3(0.07, 0.03, 0.08), Basis.IDENTITY, w, 0.0, 0.02, 0.0, 4, 7)
	for f in 4:
		var fx := -0.03 + 0.022 * float(f)
		cm.tube(PackedVector3Array([palm + Vector3(fx, -0.005, -0.06), palm + Vector3(fx * 1.6, -0.03, -0.14), palm + Vector3(fx * 2.0, -0.06, -0.19)]), PackedFloat32Array([0.014, 0.012, 0.008]), 4, w)
	cm.tube(PackedVector3Array([palm + Vector3(0.06, 0.0, -0.01), palm + Vector3(0.1, -0.02, -0.07)]), PackedFloat32Array([0.016, 0.01]), 4, w)
	# staff: shaft with bands, clawed head that cradles the orb
	cm.tube(PackedVector3Array([Vector3(staff_x, 0.02, staff_z), Vector3(staff_x + 0.01, 1.8, staff_z), Vector3(staff_x, 3.62, staff_z)]), PackedFloat32Array([0.035, 0.032, 0.03]), 7, w, 0.0, 0.02)
	for y: float in [0.7, 1.6, 2.7, 3.3]:
		cm.blob(Vector3(staff_x, y, staff_z), Vector3(0.05, 0.035, 0.05), Basis.IDENTITY, w, 0.0, 0.0, 0.0, 3, 7)
	var head := Vector3(staff_x, 3.86, staff_z)
	for k in 4:
		var a := TAU * float(k) / 4.0 + 0.4
		var o := Vector3(cos(a), 0, sin(a))
		cm.tube(PackedVector3Array([Vector3(staff_x, 3.6, staff_z) + o * 0.02, head + o * 0.13 + Vector3.DOWN * 0.1, head + o * 0.15 + Vector3.UP * 0.06, head + o * 0.07 + Vector3.UP * 0.16]),
			PackedFloat32Array([0.03, 0.026, 0.02, 0.006]), 5, w)
	parts.append(cm.commit())
	return _merge(parts)


# --- pedestal ------------------------------------------------------------------------------

static func _octagon(st: SurfaceTool, r_bot: float, r_top: float, y0: float, y1: float, shade := 1.0) -> void:
	var col := Color(shade, shade, shade)
	for i in 8:
		var a0 := TAU * float(i) / 8.0 + PI / 8.0
		var a1 := TAU * float(i + 1) / 8.0 + PI / 8.0
		var b0 := Vector3(sin(a0) * r_bot, y0, -cos(a0) * r_bot)
		var b1 := Vector3(sin(a1) * r_bot, y0, -cos(a1) * r_bot)
		var t0 := Vector3(sin(a0) * r_top, y1, -cos(a0) * r_top)
		var t1 := Vector3(sin(a1) * r_top, y1, -cos(a1) * r_top)
		var out := ((a0 + a1) * 0.5)
		var n := Vector3(sin(out), (r_bot - r_top) / maxf(y1 - y0, 0.01), -cos(out)).normalized()
		for v: Vector3 in [b0, t1, t0, b0, b1, t1]:
			st.set_normal(n)
			st.set_color(col)
			st.add_vertex(v)
		var c := Vector3(0, y1, 0)
		for v: Vector3 in [c, t0, t1]:
			st.set_normal(Vector3.UP)
			st.set_color(col)
			st.add_vertex(v)


static func _build_pedestal() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_octagon(st, 1.75, 1.75, 0.0, 0.22, 0.85)
	_octagon(st, 1.55, 1.5, 0.22, 0.42, 0.9)
	_octagon(st, 1.2, 1.12, 0.42, 1.3)
	_octagon(st, 1.32, 1.36, 1.3, 1.42, 0.92)
	_octagon(st, 1.36, 1.28, 1.42, PEDESTAL_H, 0.95)
	return st.commit()


## Rune band: glowing glyph strokes on the pedestal shaft, one ring of short bars per face.
static func _build_runes() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 707
	for face in 8:
		var a := TAU * float(face) / 8.0 + PI / 8.0 + PI / 8.0
		var out := Vector3(sin(a), 0, -cos(a))
		var side := out.cross(Vector3.UP).normalized()
		var r := 1.2 * cos(PI / 8.0) - 0.015 + 0.012
		var c := out * r
		for g in 4:
			var gx := (float(g) - 1.5) * 0.17
			for stroke in rng.randi_range(2, 3):
				var vertical := rng.randf() < 0.5
				var len := rng.randf_range(0.06, 0.13)
				var off := Vector3.UP * (0.86 + rng.randf_range(-0.07, 0.07)) + side * (gx + rng.randf_range(-0.03, 0.03))
				var dir := Vector3.UP if vertical else side
				var thick := (side if vertical else Vector3.UP) * 0.008
				var p0 := c + off - dir * len * 0.5
				var p1 := c + off + dir * len * 0.5
				for v: Vector3 in [p0 - thick, p1 - thick, p1 + thick, p0 - thick, p1 + thick, p0 + thick]:
					st.set_normal(out)
					st.add_vertex(v + out * 0.004)
	return st.commit()


# --- orb, candles, collision ----------------------------------------------------------------

func _build_orb() -> void:
	var head := Vector3(0.62, 3.9, -0.38) * FIG_SCALE + Vector3(0, PEDESTAL_H, 0)
	_orb = MeshInstance3D.new()
	_orb.name = "Orb"
	var sph := SphereMesh.new()
	sph.radius = 0.14 * FIG_SCALE
	sph.height = 0.28 * FIG_SCALE
	_orb.mesh = sph
	_orb.material_override = _mat("orb")
	_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_orb.position = head
	add_child(_orb)
	_orb_light = OmniLight3D.new()
	_orb_light.name = "OrbLight"
	_orb_light.light_color = Color(0.55, 0.7, 1.0)
	_orb_light.light_energy = 1.6
	_orb_light.omni_range = 9.0
	_orb_light.light_volumetric_fog_energy = 0.7
	_orb_light.set_meta(&"light_class", "fill")
	_orb.add_child(_orb_light)
	var motes := Vfx.emitter(Color(0.7, 0.9, 1.8), {"count": 26, "life": 2.2, "speed": Vector2(0.05, 0.25), "size": 0.035, "gravity": -0.25, "radius": 0.35, "swirl": 1.2, "turbulence": true})
	_orb.add_child(motes)
	motes.emitting = true


func _build_candles() -> void:
	var xf: Array = [[], [], []]
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	for i in 8:
		var a := TAU * float(i) / 8.0 + PI / 8.0
		for k in 3:
			var r := 1.62 + rng.randf_range(-0.06, 0.06)
			var aa := a + rng.randf_range(-0.12, 0.12)
			(xf[k] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(sin(aa) * r, 0.22, -cos(aa) * r)))
	var tips: Array[Transform3D] = []
	for v in 3:
		var mm := OssKit.multimesh(OssKit.candle_mesh(v), xf[v], OssKit.mat("wax"), false)
		add_child(mm)
		for t: Transform3D in xf[v]:
			tips.append(Transform3D(Basis.IDENTITY, t.origin + Vector3.UP * (OssKit.CANDLE_H[v] + 0.075)))
	var q := QuadMesh.new()
	q.size = Vector2(0.075, 0.17)
	add_child(OssKit.multimesh(q, tips, OssKit.mat("flame"), false))


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "StatueBody"
	body.collision_layer = Layers.WORLD
	add_child(body)
	var base := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.6
	cyl.height = PEDESTAL_H
	base.shape = cyl
	base.position = Vector3(0, PEDESTAL_H * 0.5, 0)
	body.add_child(base)
	var fig := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.55 * FIG_SCALE
	cap.height = 2.9 * FIG_SCALE
	fig.shape = cap
	fig.position = Vector3(0, PEDESTAL_H + 1.45 * FIG_SCALE, 0)
	body.add_child(fig)


func _process(delta: float) -> void:
	_t += delta
	if _orb_light:
		_orb_light.light_energy = 1.5 + 0.25 * sin(_t * 1.7) + 0.1 * sin(_t * 5.3)
		_orb.position.y += sin(_t * 1.1) * 0.0004
