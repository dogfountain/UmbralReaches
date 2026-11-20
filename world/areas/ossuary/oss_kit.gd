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
var candles: Array = [[], [], []]       # Transform3D per candle, by height variant (tall, mid, stub)
var puddles: Array[Transform3D] = []
var skulls: Array = [[], []]            # with jaw / without jaw
var bones: Array = [[], [], []]         # femur, rib, vertebra
var solids: Array = []                  # [centre, basis, half extents] of every solid box (prop clipping test)
var rejected := 0
## The Ossuary's own walkways, in its own (local) coordinates: [name, [Vector3(x, floor y, z) ...], half width].
## Floor clutter (candles, bones) is kept off them by any kit with `always_lanes`.
const FIXED_LANES := [
	["oss_bridge", [Vector3(-9.0, 12.6, -34), Vector3(19.6, 12.6, -34), Vector3(20.2, 12.6, -36.6), Vector3(23, 12.6, -36.6), Vector3(23, 12.6, -39.5)], 0.8],
	["oss_stair1", [Vector3(23, 12.6, -39.5), Vector3(23, 8.4, -49.5), Vector3(23, 8.4, -52.5)], 1.0],
	["oss_gallery", [Vector3(23, 8.4, -52.5), Vector3(20, 8.4, -58), Vector3(20, 8.4, -65.5), Vector3(21, 8.4, -67.5)], 0.8],
	["oss_stair2", [Vector3(21, 8.4, -68.5), Vector3(21, 4.2, -78), Vector3(20.5, 4.2, -80), Vector3(17.5, 4.2, -84)], 0.9],
	["oss_chapel", [Vector3(17.5, 4.2, -84), Vector3(16, 4.2, -95.5), Vector3(16, 4.2, -104)], 0.8],
]
var keep_lanes := true                  ## reject floor clutter on FIXED_LANES
## Test the Ossuary's own walkways (FIXED_LANES are its bridge, gate hall, gallery, pit stair and chapel):
## only a kit with this on rejects clutter on them, so every night gets the same crypt.
var always_lanes := false
## r34 crypt: prop cell size (a big room like the pit hall draws far fewer, larger cells)
var chunk := CHUNK
## false: box(), quad() and everything built from them (stairs, arch panels, foundations) lay their collision and their
## solids but draw nothing: a structure whose look is a modelled glb (Blender, Luke's asset bar) keeps exactly the walk,
## the stairs' ramps and the props' clipping test it had (the visual pass, 19 Nov)
var visual := true
## zz/zone_fit_probe: with `record` on, every flight built is logged (kit-local lo/hi) and, on commit, filed with its holder
## in `stair_registry`, so a probe can measure each flight's foot and head against the ground and the floor it joins.
static var record := false
static var stair_registry: Array[Dictionary] = []
var stair_log: Array = []

static var _mats: Dictionary = {}
static var _skulls: Array[ArrayMesh] = []
static var _bones: Array[ArrayMesh] = []
static var _candles: Array[ArrayMesh] = []
static var _puddle: ArrayMesh
static var _flame_mesh: QuadMesh
static var _halo_mesh: QuadMesh
const CANDLE_H := [0.42, 0.26, 0.13]
const CHUNK := 10.0
const HALO := preload("res://world/areas/ossuary/candle_halo.gdshader")
const GLOW := preload("res://world/areas/ossuary/oss_glow.gdshader")


# --- materials ------------------------------------------------------------------------------

static func mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	if key == "hub":
		# the hub stair's own stone (world-triplanar), so new masonry on it matches exactly
		_mats[key] = load("res://art/materials/stone.tres")
		return _mats[key]
	var m := StandardMaterial3D.new()
	match key:
		"stone":      _tri(m, "oss_ashlar", 0.32, Color(0.92, 0.9, 0.88))
		"plaster":    _daub(m, 0.16, Color(0.84, 0.82, 0.78))        # lime daub, cracked and stained (oss_plaster's bare-brick holes read as leopard print on every facade)
		"brick":      _tri(m, "oss_brick", 0.5, Color(0.95, 0.92, 0.9))
		"ruin":       _tri(m, "oss_ruin", 0.4, Color(1.12, 1.1, 1.07))
		"floor":      _tri(m, "oss_floor", 0.22, Color(0.9, 0.88, 0.86))
		"dark":       _tri(m, "rock", 0.5, Color(0.26, 0.24, 0.25))
		"iron":       _tri(m, "tavern_iron", 0.6, Color(0.5, 0.48, 0.5))
		"wood":       _tri(m, "tavern_wood", 0.5, Color(0.7, 0.57, 0.46))
		"slate":      _tri(m, "oss_slate", 0.45, Color(0.9, 0.9, 0.95))
		# the world pass masonry scale tiers: a colossal work's courses are 2-3 times a house's, so its blocks read as the size they are
		# (the world-triplanar texture scale is per metre: half the scale, twice the stone)
		"stone_big":  _tri(m, "oss_ashlar", 0.14, Color(0.9, 0.9, 0.92))
		"ruin_big":   _tri(m, "oss_ruin", 0.17, Color(1.08, 1.06, 1.04))
		"brick_big":  _tri(m, "oss_brick", 0.22, Color(0.95, 0.92, 0.9))
		"wood_big":   _tri(m, "tavern_wood", 0.24, Color(0.52, 0.47, 0.42))
		"bark":       _tri(m, "bark", 0.2, Color(0.62, 0.56, 0.5))
		"chalk":      _tri(m, "oss_ashlar", 0.2, Color(1.1, 1.1, 1.18))
		"cave":       _tri(m, "rock", 0.13, Color(0.52, 0.55, 0.62))
		"cave_moss":  _tri(m, "rock", 0.15, Color(0.4, 0.62, 0.42))
		"crystal":    _tri(m, "oss_ashlar", 0.5, Color(0.7, 0.95, 1.35))
		"bone", "bone_cm":
			_tri(m, "oss_bone", 1.6, Color(1.0, 0.97, 0.92))
			m.vertex_color_use_as_albedo = true
			m.rim_enabled = true
			m.rim = 0.25
			m.rim_tint = 0.4
		"wax":
			m.albedo_color = Color(0.93, 0.88, 0.76)
			m.vertex_color_use_as_albedo = true
			m.roughness = 0.42
			m.rim_enabled = true                 # thin wax glows at grazing angles, like backlight
			m.rim = 0.5
			m.rim_tint = 0.8
			m.emission_enabled = true
			m.emission = Color(1.0, 0.62, 0.3)
			m.emission_energy_multiplier = 0.06
		"halo":
			var hm := ShaderMaterial.new()
			hm.shader = HALO
			_mats[key] = hm
			return hm
		"glow":
			# lit glass and coals (oss_glow.gdshader): leaded quarries on upright faces, a mottle of coals on flat ones, dimmer
			# edge-on (map audit, 18 Nov: an unshaded orange box read as a flat full-bright plate on every lantern, window and sconce)
			var gm := ShaderMaterial.new()
			gm.shader = GLOW
			_mats[key] = gm
			return gm
		"flame":
			var sm := ShaderMaterial.new()
			sm.shader = FLAME
			_mats[key] = sm
			return sm
	_mats[key] = m
	return m


## The lime-daub plaster (art/textures r37_daub_*: albedo, normal and an ORM map), world-triplanar like _tri.
static func _daub(m: StandardMaterial3D, scale: float, tint: Color) -> void:
	m.albedo_texture = load(T + "r37_daub_albedo.png")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(T + "r37_daub_normal.png")
	m.normal_scale = 0.5                         # at full strength its cracks read as static across a facade
	var orm: Texture2D = load(T + "r37_daub_orm.png")
	m.roughness_texture = orm
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.ao_enabled = true
	m.ao_texture = orm
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC


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
	m.vertex_color_use_as_albedo = true      # contact AO + per-block tint baked by box()


# --- primitive writers ----------------------------------------------------------------------

func _tool(key: String) -> SurfaceTool:
	if not _st.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_st[key] = st
	return _st[key]


## One quad a-b-c-d (any rotation), facing `out`. Flat-shaded. `solid` adds it to collision.
func quad(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3, solid := true, shade := 1.0) -> void:
	var n := out.normalized()
	var tri: Array[Vector3] = [a, b, c, a, c, d]
	if (b - a).cross(c - a).dot(n) > 0.0:     # counter-clockwise from outside -> flip
		tri = [a, c, b, a, d, c]
	if not visual:
		if solid:
			_quad_col(tri)
		return
	var st := _tool(key)
	var col := Color(shade, shade, shade)
	for v in tri:
		st.set_normal(n)
		st.set_color(col)
		st.add_vertex(v)
	if solid:
		_quad_col(tri)


## A quad's two triangles into the collision, leaving out a zero-area one (a fan's quad closing on its centre): degenerate
## triangles broke Jolt's contacts round them (see box()).
func _quad_col(tri: Array[Vector3]) -> void:
	for i in [0, 3]:
		if (tri[i + 1] - tri[i]).cross(tri[i + 2] - tri[i]).length_squared() > 1e-10:
			col_faces.append_array(PackedVector3Array([tri[i], tri[i + 1], tri[i + 2]]))


## Oriented box. `b` columns are the box axes (unit); size is full extents along them.
## Visually every box is chamfered (a 45-degree bevel catches a highlight on each arris, so masonry
## reads as cut stone instead of CSG), carries contact AO in its vertex colours (sides darken
## toward the foot, undersides are dark) and a small per-block tint jitter (no two ashlars alike).
## Collision stays the plain box.
func box(key: String, c: Vector3, size: Vector3, b := Basis.IDENTITY, solid := true, shade := 1.0) -> void:
	if key == "floor" and b.y.y > 0.95:
		c.y += FLOOR_LIFT              # a floor slab laid at the foundation's height z-fought it (pale stone through the tiles)
	var ex := b.x.normalized()
	var ey := b.y.normalized()
	var ez := b.z.normalized()
	var h := size.abs() * 0.5
	if solid and size.x > 0.05 and size.y > 0.05 and size.z > 0.05:
		solids.append([c, b.orthonormalized(), h, key])
	# (19 Nov) a box with no thickness on an axis (an arch panel's jamb of 0) gave the collision zero-area triangles and a
	# pair of coincident opposite faces; at the pit hall's chapels Jolt let a walking body through everything round them
	# (the map audit's MA1, zz/visual_probe.tscn --only=chapel): such a box lays no collision
	if solid and h.x > 0.0005 and h.y > 0.0005 and h.z > 0.0005:
		_box_col(c, ex * h.x, ey * h.y, ez * h.z)
	if not visual:
		return
	var mn := minf(size.x, minf(size.y, size.z))
	# small, uneven arris (1-3 cm, never a fixed 4.5 cm chamfer): real dressed stone is eased, not milled
	var rb := float(absi(hash(Vector3i((c * 37.0).round()))) % 1000) / 1000.0
	var ch := 0.0 if mn < 0.09 else minf(mn * 0.08, BEVEL * (0.3 + 0.7 * rb))
	var jit := 0.9 + 0.13 * float(absi(hash(Vector3i((c * 20.0).round()))) % 1000) / 1000.0
	var ybot := c.y - absf(ex.y) * h.x - absf(ey.y) * h.y - absf(ez.y) * h.z
	var upright := ey.y > 0.95
	var st := _tool(key)
	var sh := shade * jit
	var hc := h - Vector3.ONE * ch
	for s: float in [-1.0, 1.0]:
		_face(st, c + ex * (s * h.x), ez * hc.z, ey * hc.y, ex * s, sh, ybot, upright)
		_face(st, c + ez * (s * h.z), ex * hc.x, ey * hc.y, ez * s, sh, ybot, upright)
		_face(st, c + ey * (s * h.y), ex * hc.x, ez * hc.z, ey * s, sh, ybot, false)
	if ch <= 0.0:
		return
	sh *= 1.15                         # worn edges: the eased arris catches the light (vertex colour clamps at 1, so only the darker stones gain)
	for sa: float in [-1.0, 1.0]:
		for sb: float in [-1.0, 1.0]:
			# vertical arrises (x/z), then the x/y and y/z ones
			var p1 := ex * (sa * h.x) + ez * (sb * hc.z)
			var p2 := ex * (sa * hc.x) + ez * (sb * h.z)
			_rect(st, c + (p1 + p2) * 0.5, (p1 - p2) * 0.5, ey * hc.y, (ex * sa + ez * sb).normalized(), sh, ybot, upright)
			p1 = ex * (sa * h.x) + ey * (sb * hc.y)
			p2 = ex * (sa * hc.x) + ey * (sb * h.y)
			_rect(st, c + (p1 + p2) * 0.5, (p1 - p2) * 0.5, ez * hc.z, (ex * sa + ey * sb).normalized(), sh, ybot, false)
			p1 = ey * (sa * h.y) + ez * (sb * hc.z)
			p2 = ey * (sa * hc.y) + ez * (sb * h.z)
			_rect(st, c + (p1 + p2) * 0.5, (p1 - p2) * 0.5, ex * hc.x, (ey * sa + ez * sb).normalized(), sh, ybot, false)
			for sc: float in [-1.0, 1.0]:
				var o := c
				var a := o + ex * (sa * h.x) + ey * (sb * hc.y) + ez * (sc * hc.z)
				var bb := o + ex * (sa * hc.x) + ey * (sb * h.y) + ez * (sc * hc.z)
				var cc := o + ex * (sa * hc.x) + ey * (sb * hc.y) + ez * (sc * h.z)
				_tri3(st, a, bb, cc, (ex * sa + ey * sb + ez * sc).normalized(), sh, ybot)


const BEVEL := 0.04
var candle_lights := true   ## commit() puts a small warm light at each cluster of candles (a few metres apart, at most 28), so a crypt's candles light the stone round them
var _cluster_pts: Array[Vector3] = []
const FLOOR_LIFT := 0.015         ## floor slabs stand this much proud of the masonry they sit on (no coplanar tops)
var under_shade := 0.6      ## vertex shade of a downward face (a room whose ceiling should take its hearth lifts it)
const AO_FLOOR := 0.56      ## vertex shade at a face's foot
const AO_RISE := 0.75       ## metres over which contact AO fades out


static func _ao(n: Vector3, y: float, ybot: float, under := 0.6) -> float:
	if n.y > 0.68:
		return 1.0
	if n.y < -0.68:
		return under
	var t := clampf((y - ybot) / AO_RISE, 0.0, 1.0)
	return lerpf(AO_FLOOR, 1.0, t * t * (3.0 - 2.0 * t))


## Vertex colour: contact AO plus damp grime at a wall's foot (a touch of green-brown, never brighter), and the world pass's
## macro weathering: a slow patchwork across every wall and roof, by world position (two sines, 20-60 m patches: a
## +-7 % tone drift, a warm/cool shift, moss on the up faces where the patch is damp). Faces are big and their vertices few,
## so the colour is interpolated across them: no texture, no shader, no cost. Position-based, so neighbouring pieces agree.
static func _grime(n: Vector3, y: float, ybot: float, shade: float, under: float, p := Vector3.ZERO) -> Color:
	var m := 0.5 * sin(p.x * 0.23 + p.z * 0.31 + p.y * 0.05) + 0.5 * sin(p.x * 0.11 - p.z * 0.19 + p.y * 0.4)
	var k := shade * _ao(n, y, ybot, under) * (1.0 + 0.07 * m)
	var cr := 1.0 + 0.03 * m
	var cb := 1.0 - 0.03 * m
	if absf(n.y) > 0.68:
		if n.y > 0.0 and m > 0.15:
			var mo := smoothstep(0.15, 0.7, m)
			return Color(k * cr * (1.0 - 0.06 * mo), k * (1.0 + 0.05 * mo), k * cb * (1.0 - 0.08 * mo))
		return Color(k * cr, k, k * cb)
	var d := 1.0 - clampf((y - ybot) / AO_RISE, 0.0, 1.0)
	return Color(k * cr * (1.0 - 0.1 * d), k * (1.0 - 0.02 * d), k * cb * (1.0 - 0.2 * d))


## A big face in relief (kits with `relief`: the landmarks): faces over 1.2 m both ways are cut into ~1.6 m ashlar cells, each
## proud of a darker recessed base by 0-5 cm with its own tone, mortar gaps showing the base: cut stone, not a slab. Collision stays
## the plain box; the extra triangles are build-time geometry (a cell is 2 triangles, the base 2).
var relief := false
var debris_max := 3                     ## > 0: commit() dresses up to this many tall RUIN walls (key ruin / ruin_big): fallen blocks at the foot, a carved band, crown rubble. A handful of boxes a kit, same mesh and draw as the wall


func _face(st: SurfaceTool, ctr: Vector3, u: Vector3, v: Vector3, n: Vector3, shade: float, ybot: float, split: bool) -> void:
	var ul := u.length()
	var vl := v.length()
	if not relief or ul < 1.2 or vl < 1.2:
		_rect(st, ctr, u, v, n, shade, ybot, split)
		return
	var nu := clampi(int(ul * 2.0 / 1.6), 1, 14)
	var nv := clampi(int(vl * 2.0 / 1.6), 1, 14)
	_rect(st, ctr - n * 0.06, u, v, n, shade * 0.6, ybot, false)
	var cu := u / float(nu)
	var cv := v / float(nv)
	for i in nu:
		for j in nv:
			var c := ctr + u * ((float(i) + 0.5) / float(nu) * 2.0 - 1.0) + v * ((float(j) + 0.5) / float(nv) * 2.0 - 1.0)
			var hv := float(absi(hash(Vector3i((c * 11.0).round()))) % 1000) / 1000.0
			var hv2 := float(absi(hash(Vector3i((c * 7.0).round() + Vector3(5.0, 3.0, 1.0)))) % 1000) / 1000.0
			var du := cu * (1.0 - 0.05 / maxf(cu.length(), 0.05))
			var dv := cv * (1.0 - 0.05 / maxf(cv.length(), 0.05))
			_rect(st, c + n * (0.012 + 0.05 * hv), du, dv, n, shade * (0.86 + 0.2 * hv2), ybot, false)


## Rectangle centre +-u +-v facing n. Upright side faces are split at the AO band so the contact
## darkening hugs the foot of a tall wall instead of shading it end to end.
func _rect(st: SurfaceTool, ctr: Vector3, u: Vector3, v: Vector3, n: Vector3, shade: float, ybot: float, split: bool) -> void:
	if split and absf(v.y) > 0.01:
		var ps := (ybot + AO_RISE - ctr.y) / v.y
		if ps > -0.95 and ps < 0.95:
			var mid := ctr + v * ps
			_rect(st, (ctr - v + mid) * 0.5, u, (mid - (ctr - v)) * 0.5, n, shade, ybot, false)
			_rect(st, (ctr + v + mid) * 0.5, u, ((ctr + v) - mid) * 0.5, n, shade, ybot, false)
			return
	var a := ctr - u - v
	var b := ctr + u - v
	var c := ctr + u + v
	var d := ctr - u + v
	var tri: Array[Vector3] = [a, b, c, a, c, d]
	if (b - a).cross(c - a).dot(n) > 0.0:
		tri = [a, c, b, a, d, c]
	for p in tri:
		st.set_normal(n)
		st.set_color(_grime(n, p.y, ybot, shade, under_shade, p))
		st.add_vertex(p)


func _tri3(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, shade: float, ybot: float) -> void:
	var tri: Array[Vector3] = [a, b, c]
	if (b - a).cross(c - a).dot(n) > 0.0:
		tri = [a, c, b]
	for p in tri:
		st.set_normal(n)
		st.set_color(_grime(n, p.y, ybot, shade, under_shade, p))
		st.add_vertex(p)


func _box_col(c: Vector3, hx: Vector3, hy: Vector3, hz: Vector3) -> void:
	for s: float in [-1.0, 1.0]:
		for f: Array in [[hx, hy, hz], [hy, hx, hz], [hz, hx, hy]]:
			var o: Vector3 = c + (f[0] as Vector3) * s
			var u: Vector3 = f[1]
			var v: Vector3 = f[2]
			var t := PackedVector3Array([o - u - v, o + u - v, o + u + v, o - u - v, o + u + v, o - u + v])
			# clockwise seen from outside (Godot's front face), every side alike: the navigation bake reads the winding,
			# and the old mixed order made the slab undersides walkable and ate the ramps' tops
			if (t[1] - t[0]).cross(t[2] - t[0]).dot(f[0] as Vector3 * s) > 0.0:
				t = PackedVector3Array([t[0], t[2], t[1], t[3], t[5], t[4]])
			col_faces.append_array(t)


## Collision only (no mesh): a solid box for a modelled prop drawn elsewhere (the tavern's furniture).
func collider(c: Vector3, size: Vector3, b := Basis.IDENTITY) -> void:
	var h := size.abs() * 0.5
	solids.append([c, b.orthonormalized(), h])
	_box_col(c, b.x.normalized() * h.x, b.y.normalized() * h.y, b.z.normalized() * h.z)


## A lantern's lit glass `size` (w, h, d) at `c` in an iron cage: a cap and a foot a little wider than the glass and a strap
## at each corner, so a lantern reads as a made thing (a bare lit block read as an orange paddle or a cube; map audit, 18 Nov).
func lantern(c: Vector3, size: Vector3, b := Basis.IDENTITY, shade := 1.0) -> void:
	var ey := b.y.normalized()
	box("glow", c, size, b, false, shade)
	box("iron", c + ey * (size.y * 0.5 + 0.025), Vector3(size.x * 1.3, 0.05, size.z * 1.3), b, false, 0.6)
	box("iron", c + ey * (size.y * 0.5 + 0.07), Vector3(size.x * 0.5, 0.05, size.z * 0.5), b, false, 0.6)
	box("iron", c - ey * (size.y * 0.5 + 0.015), Vector3(size.x * 1.2, 0.03, size.z * 1.2), b, false, 0.6)
	for sx: float in [-0.5, 0.5]:
		for sz: float in [-0.5, 0.5]:
			box("iron", c + b.x.normalized() * (sx * size.x) + b.z.normalized() * (sz * size.z), Vector3(0.025, size.y, 0.025), b, false, 0.6)


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
	# jambs (solid both sides of the opening, full height; none when the wall beside it is its own)
	for s: float in [-1.0, 1.0]:
		if jamb <= 0.0:
			break
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
func stairs(key: String, lo: Vector3, hi: Vector3, width: float, steps: int, base_y := NAN) -> void:
	if record:
		stair_log.append([key, lo, hi, width, steps])
	var run := Vector3(hi.x - lo.x, 0.0, hi.z - lo.z)
	var dir := run.normalized()
	var side := dir.cross(Vector3.UP).normalized()
	var tread := run.length() / float(steps)
	var rise := (hi.y - lo.y) / float(steps)
	var bas := Basis(side, Vector3.UP, dir)
	for i in steps:
		var top := lo.y + rise * float(i + 1)
		var bottom := (lo.y - 0.5) if is_nan(base_y) else base_y
		var c := lo + dir * (tread * (float(i) + 0.5))
		box(key, Vector3(c.x, (top + bottom) * 0.5, c.z), Vector3(width, top - bottom, tread + 0.02), bas, false, 0.9 if i % 2 == 0 else 1.0)
	# Collision ramp through the middle of every tread top (shifted half a tread back), so the feet
	# ride within +-rise/2 of the visible step instead of sinking up to a whole riser into it. The
	# last half tread, past the ramp's end, gets a flat slab at head height.
	var back := dir * (tread * 0.5)
	var lo2 := lo - back
	var hi2 := hi - back
	var f := (hi2 - lo2).normalized()
	var u := side.cross(f).normalized()
	if u.y < 0.0:
		u = -u
	var rb := Basis(side, u, f)
	_ramp_faces((lo2 + hi2) * 0.5 - u * 0.15, Vector3(width, 0.3, (hi2 - lo2).length()), rb)
	_ramp_faces(hi - back * 0.5 + Vector3.DOWN * 0.15, Vector3(width, 0.3, tread * 0.5 + 0.04), bas)


func _ramp_faces(c: Vector3, size: Vector3, b: Basis) -> void:
	_box_col(c, b.x * size.x * 0.5, b.y * size.y * 0.5, b.z * size.z * 0.5)


## Masonry foundation under a rectangular footprint (holder/world space): a plinth from `floor_y`
## down to `ground_y - bury` (the lowest ground under the footprint, sampled by the caller), with
## a chamfered, slightly proud top course. On a slope the downhill side simply shows more plinth,
## so a building never floats and never needs the ground bent to fit it.
func foundation(key: String, lo: Vector2, hi: Vector2, floor_y: float, ground_y: float, bury := Metrics.FOUNDATION_BURY) -> void:
	# the plinth stands proud of the walls from the ground up (no overhanging course to float
	# over a slope); one closed block, so no internal faces
	var bottom := minf(ground_y, floor_y) - bury
	block(key, Vector3(lo.x - 0.12, bottom, lo.y - 0.12), Vector3(hi.x + 0.12, floor_y, hi.y + 0.12), true, 0.86)


## Square pylon: shaft `w` wide and `h` tall from `base`, then a spire of `spike` height. Built as
## dressed stone rather than a brick stack: a plinth, a shaft that eases in, a belt course and a
## corbelled cap under a slim pyramid with a ball finial.
func pinnacle(key: String, base: Vector3, w: float, h: float, spike: float) -> void:
	var plinth := minf(0.4, h * 0.2)
	box(key, base + Vector3.UP * (plinth * 0.5), Vector3(w * 1.3, plinth, w * 1.3), Basis.IDENTITY, true, 0.88)
	box(key, base + Vector3.UP * (plinth + (h - plinth) * 0.5), Vector3(w * 0.88, h - plinth, w * 0.88))
	var belt := base.y + plinth + (h - plinth) * 0.58
	box(key, Vector3(base.x, belt, base.z), Vector3(w * 1.06, 0.1, w * 1.06), Basis.IDENTITY, false, 0.9)
	box(key, base + Vector3.UP * (h - 0.2), Vector3(w * 1.12, 0.14, w * 1.12), Basis.IDENTITY, false, 0.86)
	box(key, base + Vector3.UP * (h - 0.06), Vector3(w * 1.28, 0.12, w * 1.28), Basis.IDENTITY, true, 0.92)
	var top := base + Vector3.UP * h
	var apex := top + Vector3.UP * spike
	var hw := w * 0.5
	var c: Array[Vector3] = [top + Vector3(-hw, 0, -hw), top + Vector3(hw, 0, -hw), top + Vector3(hw, 0, hw), top + Vector3(-hw, 0, hw)]
	for i in 4:
		var a := c[i]
		var b := c[(i + 1) % 4]
		var out := ((a + b) * 0.5 - top).normalized() + Vector3.UP * (hw / spike)
		quad(key, a, b, apex, apex, out, false)
	box(key, apex - Vector3.UP * 0.02, Vector3.ONE * w * 0.16, Basis(Vector3(0.3, 0.5, 0.2).normalized(), 0.8), false, 0.95)


## Broken crown for a ruined wall column: two or three uneven stones sit on `top_c` (the centre of the
## column's top face, basis `b` = along / up / thickness), so a ruin ends in fallen-away blocks and
## not a flat saw-cut. Visual only; collision stays the column.
func broken_crown(key: String, top_c: Vector3, b: Basis, width: float, thick: float, rng: RandomNumberGenerator, shade := 0.9) -> void:
	var n := 2 if width < 0.8 else 3
	var seg := width / float(n)
	for i in n:
		if rng.randf() < 0.2:
			continue                                    # a gap where the stone has gone
		var w := seg * rng.randf_range(0.7, 1.0)
		var hh := rng.randf_range(0.07, 0.3)
		var tt := thick * rng.randf_range(0.6, 0.95)
		var cx := -width * 0.5 + seg * (float(i) + 0.5) + rng.randf_range(-0.05, 0.05)
		var cz := rng.randf_range(-0.1, 0.1) * thick
		var tilt := Basis.from_euler(Vector3(rng.randf_range(-0.07, 0.07), rng.randf_range(-0.14, 0.14), rng.randf_range(-0.1, 0.1)))
		box(key, top_c + b.x * cx + b.y * (hh * 0.5 - 0.03) + b.z * cz, Vector3(w, hh, tt), b * tilt, false, shade * rng.randf_range(0.85, 1.0))


## Glowing pane filling a pointed opening (lit from within). Two-sided, no collision.
func glow_pane(base: Vector3, along: Vector3, w: float, sill: float, spring: float, k := 0.85) -> void:
	var nrm := along.cross(Vector3.UP).normalized()
	var p := func(x: float, y: float) -> Vector3: return base + along * x + Vector3.UP * y
	var hw := w * 0.5
	quad("glow", p.call(-hw, sill), p.call(hw, sill), p.call(hw, spring), p.call(-hw, spring), nrm, false, 0.38)
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

## True when `p` is inside any solid box (shrunk by `margin`): props there would clip.
func blocked(p: Vector3, margin := 0.02) -> bool:
	if keep_lanes and _on_fixed_lane(AABB(p - Vector3(0.08, 0.1, 0.08), Vector3(0.16, 0.3, 0.16))):
		return true                         # floor clutter never lands on a walkway
	for sb in solids:
		var b: Basis = sb[1]
		var h: Vector3 = sb[2]
		var d: Vector3 = p - (sb[0] as Vector3)
		if absf(d.dot(b.x)) < h.x - margin and absf(d.dot(b.y)) < h.y - margin and absf(d.dot(b.z)) < h.z - margin:
			return true
	return false


func _on_fixed_lane(b: AABB) -> bool:
	if not always_lanes:
		return false
	for lane: Array in FIXED_LANES:
		var pts: Array = lane[1]
		var w: float = float(lane[2])
		var lo := Vector2(b.position.x, b.position.z)
		var hi := Vector2(b.end.x, b.end.z)
		for k in pts.size() - 1:
			var a: Vector3 = pts[k]
			var c: Vector3 = pts[k + 1]
			var n := maxi(1, ceili(Vector2(a.x, a.z).distance_to(Vector2(c.x, c.z)) / WorldLanes.STEP))
			for i in n + 1:
				var s3 := a.lerp(c, float(i) / float(n))
				var s := Vector2(s3.x, s3.z)
				if s.clamp(lo, hi).distance_to(s) > w:
					continue
				if b.position.y < s3.y + WorldLanes.HEADROOM and b.end.y > s3.y - 0.3:
					return true
	return false


## A cluster of candles standing on the surface at `at` (its y is the surface). Mixed heights,
## the tallest near the middle, a wax puddle under any group of 3+. Candles that would stand
## inside masonry are dropped.
func candle_cluster(at: Vector3, n: int, spread := 0.25, rng: RandomNumberGenerator = null) -> void:
	var placed := 0
	for i in n:
		var a := rng.randf() * TAU if rng else float(i) * 2.4
		var t := sqrt(rng.randf() if rng else float(i) / float(maxi(n, 1)))
		var r := spread * t
		var p := at + Vector3(cos(a) * r, 0.0, sin(a) * r)
		if blocked(p + Vector3.UP * 0.06) or blocked(p + Vector3.UP * 0.3):
			rejected += 1
			continue
		var v := 0 if t < 0.4 else (1 if t < 0.8 else 2)
		if rng and rng.randf() < 0.25:
			v = rng.randi_range(0, 2)
		var sc := rng.randf_range(0.85, 1.2) if rng else 1.0
		var yaw := rng.randf() * TAU if rng else 0.0
		(candles[v] as Array).append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(sc, sc * (rng.randf_range(0.8, 1.25) if rng else 1.0), sc)), p))
		placed += 1
	if placed >= 2:
		_cluster_pts.append(at + Vector3(0, 0.3, 0))
	if placed >= 3:
		puddles.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU if rng else 0.0).scaled(Vector3(spread * 0.8 + 0.06, 1.0, spread * 0.7 + 0.05)), at))


## An iron candelabrum (floor-standing): tripod foot, shaft, a crown of five candles.
func candelabrum(at: Vector3, h: float, rng: RandomNumberGenerator) -> void:
	if blocked(at + Vector3.UP * 0.5):
		rejected += 1
		return
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.4
		box("iron", at + Vector3(cos(a) * 0.18, 0.05, sin(a) * 0.18), Vector3(0.4, 0.06, 0.06), Basis(Vector3.UP, -a), false)
	box("iron", at + Vector3.UP * (h * 0.5), Vector3(0.06, h, 0.06), Basis.IDENTITY, false)
	for k: float in [0.3, 0.62]:
		box("iron", at + Vector3.UP * (h * k), Vector3(0.12, 0.1, 0.12), Basis.IDENTITY, false, 0.8)
	box("iron", at + Vector3.UP * h, Vector3(0.7, 0.05, 0.05), Basis.IDENTITY, false)
	box("iron", at + Vector3.UP * h, Vector3(0.05, 0.05, 0.7), Basis.IDENTITY, false)
	for o: Vector3 in [Vector3.ZERO, Vector3(0.32, 0, 0), Vector3(-0.32, 0, 0), Vector3(0, 0, 0.32), Vector3(0, 0, -0.32)]:
		var cup := at + o + Vector3.UP * (h + 0.04)
		box("iron", cup, Vector3(0.1, 0.04, 0.1), Basis.IDENTITY, false)
		(candles[0 if o == Vector3.ZERO else 1] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), cup + Vector3.UP * 0.02))


func skull(at: Vector3, yaw: float, s := 1.0, jaw := -1, tilt := 0.0) -> void:
	if blocked(at + Vector3.UP * 0.08):
		rejected += 1
		return
	var v := jaw if jaw >= 0 else (1 if hash(at) % 3 == 0 else 0)
	(skulls[v] as Array).append(Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt).scaled(Vector3.ONE * s), at))


## kind: 0 femur, 1 rib, 2 vertebra
func bone(at: Vector3, b: Basis, kind := 0, check := true) -> void:
	if check and blocked(at):
		rejected += 1
		return
	(bones[kind] as Array).append(Transform3D(b, at))


## Organic mesh (CreatureMesh output) merged into the area's single bone surface.
func append_mesh(key: String, mesh: ArrayMesh, xf: Transform3D) -> void:
	# its own surface: SurfaceTool drops box vertices when organic meshes (UVs, other format)
	# are appended into the same tool, so `wood` boxes vanished once a barrel was added
	if not key.ends_with("_cm"):
		key += "#m"
	if not _st.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_st[key] = st
	(_st[key] as SurfaceTool).append_from(mesh, 0, xf)


# --- prop meshes ----------------------------------------------------------------------------

## Runtime LOD chain (the importer's simplifier): distant prop cells draw a fraction of the tris.
static func with_lods(m: ArrayMesh) -> ArrayMesh:
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, m.surface_get_arrays(0))
	im.generate_lods(25.0, 60.0, [])
	return im.get_mesh()


static func skull_mesh(variant := 0) -> ArrayMesh:
	if _skulls.is_empty():
		for v in 2:
			_skulls.append(with_lods(_build_skull(v == 0)))
	return _skulls[variant]


static func _build_skull(with_jaw: bool) -> ArrayMesh:
	var cm := CreatureMesh.new(77 if with_jaw else 79)
	var w := Color(1, 1, 1)
	var hole := Color(0.06, 0.045, 0.04)
	var tooth := Color(1.05, 1.0, 0.92)
	cm.blob(Vector3(0, 0.1, 0.015), Vector3(0.098, 0.094, 0.118), Basis.IDENTITY, w, 0.0, 0.04, 0.0, 7, 11)
	cm.blob(Vector3(0, 0.075, 0.075), Vector3(0.08, 0.072, 0.055), Basis.IDENTITY, w, 0.0, 0.04, 0.0, 5, 8)    # occiput
	cm.blob(Vector3(0, 0.083, -0.088), Vector3(0.088, 0.022, 0.03), Basis.IDENTITY, w, 0.0, 0.03, 0.0, 4, 8)   # brow ridge
	cm.blob(Vector3(0, 0.025, -0.084), Vector3(0.048, 0.034, 0.036), Basis.IDENTITY, w, 0.0, 0.03, 0.0, 5, 8)  # maxilla
	for s: float in [-1.0, 1.0]:
		cm.blob(Vector3(s * 0.062, 0.04, -0.07), Vector3(0.03, 0.02, 0.036), Basis.IDENTITY, w, 0.0, 0.03, 0.0, 4, 6)  # cheekbone
		cm.blob(Vector3(s * 0.034, 0.058, -0.112), Vector3(0.026, 0.024, 0.018), Basis.IDENTITY, hole, 0.0, 0.0, 0.0, 4, 7)
		cm.blob(Vector3(s * 0.088, 0.07, 0.0), Vector3(0.012, 0.03, 0.03), Basis.IDENTITY, hole, 0.0, 0.0, 0.0, 3, 5)   # temple hollow
	cm.blob(Vector3(0, 0.035, -0.118), Vector3(0.012, 0.018, 0.01), Basis.IDENTITY, hole, 0.0, 0.0, 0.0, 3, 5)      # nasal
	for k in 6:
		var x := (float(k) - 2.5) * 0.011
		cm.blob(Vector3(x, -0.002, -0.106 + absf(x) * 0.5), Vector3(0.0055, 0.01, 0.006), Basis.IDENTITY, tooth, 0.0, 0.0, 0.0, 2, 4)
	if with_jaw:
		cm.tube(PackedVector3Array([Vector3(-0.052, 0.012, -0.02), Vector3(-0.047, -0.03, -0.068), Vector3(0, -0.042, -0.098), Vector3(0.047, -0.03, -0.068), Vector3(0.052, 0.012, -0.02)]),
			PackedFloat32Array([0.012, 0.015, 0.017, 0.015, 0.012]), 5, w, 0.0, 0.03)
		for k in 4:
			var x := (float(k) - 1.5) * 0.012
			cm.blob(Vector3(x, -0.016, -0.1 + absf(x) * 0.4), Vector3(0.005, 0.009, 0.005), Basis.IDENTITY, tooth, 0.0, 0.0, 0.0, 2, 4)
	return cm.commit()


static func bone_mesh(kind := 0) -> ArrayMesh:
	if _bones.is_empty():
		_bones.append(with_lods(_build_femur()))
		_bones.append(_build_rib())
		_bones.append(with_lods(_build_vertebra()))
	return _bones[kind]


static func _build_femur() -> ArrayMesh:
	var cm := CreatureMesh.new(81)
	cm.tube(PackedVector3Array([Vector3(0, 0, -0.2), Vector3(0, 0.006, -0.06), Vector3(0, 0.004, 0.08), Vector3(0, 0, 0.2)]), PackedFloat32Array([0.02, 0.014, 0.014, 0.02]), 6, Color.WHITE, 0.0, 0.03)
	for s: float in [-1.0, 1.0]:
		cm.blob(Vector3(s * 0.017, -0.004, 0.215), Vector3(0.019, 0.021, 0.023), Basis.IDENTITY, Color.WHITE, 0.0, 0.04, 0.0, 4, 6)
	cm.tube(PackedVector3Array([Vector3(0, 0, -0.2), Vector3(0.022, 0.012, -0.225)]), PackedFloat32Array([0.016, 0.013]), 5)
	cm.blob(Vector3(0.03, 0.016, -0.232), Vector3(0.022, 0.022, 0.022), Basis.IDENTITY, Color.WHITE, 0.0, 0.02, 0.0, 4, 6)
	cm.blob(Vector3(-0.012, -0.006, -0.205), Vector3(0.016, 0.02, 0.02), Basis.IDENTITY, Color.WHITE, 0.0, 0.03, 0.0, 3, 5)
	return cm.commit()


static func _build_rib() -> ArrayMesh:
	var cm := CreatureMesh.new(82)
	var pts := PackedVector3Array()
	var rad := PackedFloat32Array()
	for i in 7:
		var a := float(i) / 6.0 * 2.2
		pts.append(Vector3(sin(a) * 0.17, 0.0, -cos(a) * 0.17 + 0.08))
		rad.append(lerpf(0.011, 0.006, float(i) / 6.0))
	cm.tube(pts, rad, 4, Color(0.95, 0.92, 0.88), 0.0, 0.02, 0.0, Vector2(1.0, 0.45))
	return cm.commit()


static func _build_vertebra() -> ArrayMesh:
	var cm := CreatureMesh.new(83)
	cm.blob(Vector3.ZERO, Vector3(0.03, 0.022, 0.028), Basis.IDENTITY, Color.WHITE, 0.0, 0.05, 0.0, 4, 7)
	cm.tube(PackedVector3Array([Vector3(0, 0.0, 0.025), Vector3(0, 0.03, 0.06)]), PackedFloat32Array([0.009, 0.004]), 4)
	for s: float in [-1.0, 1.0]:
		cm.tube(PackedVector3Array([Vector3(s * 0.02, 0, 0.012), Vector3(s * 0.055, 0.006, 0.02)]), PackedFloat32Array([0.008, 0.004]), 4)
	return cm.commit()


static func candle_mesh(v: int) -> ArrayMesh:
	if _candles.is_empty():
		for i in 3:
			_candles.append(with_lods(_build_candle(CANDLE_H[i], 90 + i)))
	return _candles[v]


static func _build_candle(h: float, seed_n: int) -> ArrayMesh:
	var cm := CreatureMesh.new(seed_n)
	var wax := Color(1.0, 0.97, 0.9)
	var old := Color(0.92, 0.84, 0.66)
	cm.tube(PackedVector3Array([Vector3(0, 0, 0), Vector3(0.002, h * 0.5, 0), Vector3(0, h - 0.008, 0)]), PackedFloat32Array([0.036, 0.034, 0.032]), 8, wax, 0.0, 0.025)
	cm.blob(Vector3(0, h - 0.006, 0), Vector3(0.036, 0.014, 0.036), Basis.IDENTITY, wax, 0.0, 0.18, 0.0, 3, 9)   # melted lip
	cm.blob(Vector3(0, h + 0.002, 0), Vector3(0.022, 0.006, 0.022), Basis.IDENTITY, old, 0.0, 0.0, 0.0, 2, 8)   # pool
	for k in 3:
		var a := TAU * float(k) / 3.0 + float(seed_n)
		var len := h * (0.25 + 0.2 * float(k))
		var o := Vector3(cos(a) * 0.033, h - 0.004, sin(a) * 0.033)
		cm.tube(PackedVector3Array([o, o + Vector3(cos(a) * 0.004, -len * 0.5, sin(a) * 0.004), o + Vector3(cos(a) * 0.006, -len, sin(a) * 0.006)]),
			PackedFloat32Array([0.011, 0.009, 0.007]), 4, old, 0.0, 0.0)
	cm.tube(PackedVector3Array([Vector3(0, h, 0), Vector3(0.004, h + 0.028, 0)]), PackedFloat32Array([0.003, 0.002]), 3, Color(0.04, 0.03, 0.03))
	return cm.commit()


static func puddle_mesh() -> ArrayMesh:
	if _puddle == null:
		var cm := CreatureMesh.new(97)
		cm.blob(Vector3(0, 0.0, 0), Vector3(1.0, 0.01, 1.0), Basis.IDENTITY, Color(0.62, 0.56, 0.45), 0.0, 0.35, 0.0, 3, 14)
		_puddle = cm.commit()
	return _puddle


static func multimesh(mesh: Mesh, xforms: Array, mat_override: Material, shadows := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # static: interpolating a MultiMesh makes its add wait on the GPU (zz/stream_probe.gd)
	mmi.multimesh = mm
	mmi.material_override = mat_override
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


func candle_count() -> int:
	return (candles[0] as Array).size() + (candles[1] as Array).size() + (candles[2] as Array).size()


func skull_count() -> int:
	return (skulls[0] as Array).size() + (skulls[1] as Array).size()


func bone_count() -> int:
	return (bones[0] as Array).size() + (bones[1] as Array).size() + (bones[2] as Array).size()


## Commit everything under `parent`: one MeshInstance3D per material, one StaticBody3D with the
## collision soup, and the prop MultiMeshes (one per prop mesh). Returns draw calls added.
func commit(parent: Node3D, body_name := "Body") -> int:
	var draws := 0
	if record:
		for sl: Array in stair_log:
			stair_registry.append({"parent": parent, "key": sl[0], "lo": sl[1], "hi": sl[2], "w": sl[3], "n": sl[4]})
	if debris_max > 0:
		_debris()
	for key in _st:
		var st: SurfaceTool = _st[key]
		var mi := MeshInstance3D.new()
		mi.name = "Mesh_" + key.replace("#", "_")
		mi.mesh = st.commit()
		mi.material_override = mat(key.split("#")[0])
		parent.add_child(mi)
		draws += 1
	Atmosphere.kit_occluder(parent, solids)    # walls/piers/floors hide what is behind them (occlusion culling)
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
	var counter := [0]                      # lambdas capture locals by value: count through an array
	# Props are bucketed into CHUNK-metre cells, one MultiMesh per (prop mesh, cell), so frustum
	# culling and mesh LODs work per cell instead of drawing the whole area's bones every frame.
	var add := func(n: String, mesh: Mesh, xf: Array, m: Material, far: float) -> void:
		if xf.is_empty():
			return
		var cells := {}
		for t: Transform3D in xf:
			var key := Vector2i(floori(t.origin.x / chunk), floori(t.origin.z / chunk))
			if not cells.has(key):
				cells[key] = []
			(cells[key] as Array).append(t)
		for key: Vector2i in cells:
			var mm := multimesh(mesh, cells[key], m, false)
			mm.name = "%s_%d_%d" % [n, key.x, key.y]
			mm.visibility_range_end = far
			mm.visibility_range_end_margin = far * 0.12
			mm.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			parent.add_child(mm)
			counter[0] += 1
	# a skull is a few pixels past ~30 m: these ranges keep the crypt's thousands of them (and
	# the summit view down into it) off the GPU when they cannot be read anyway
	for v in 2:
		add.call("Skulls%d" % v, skull_mesh(v), skulls[v], mat("bone"), 34.0)
	for kind in 3:
		add.call("Bones%d" % kind, bone_mesh(kind), bones[kind], mat("bone"), 30.0 if kind == 0 else 22.0)
	add.call("WaxPuddles", puddle_mesh(), puddles, mat("wax"), 30.0)
	var tips: Array[Transform3D] = []
	for v in 3:
		add.call("Candles%d" % v, candle_mesh(v), candles[v], mat("wax"), 55.0)
		for t: Transform3D in candles[v]:
			tips.append(Transform3D(Basis.IDENTITY, t.origin + Vector3.UP * (CANDLE_H[v] * t.basis.y.length() + 0.075)))
	if not tips.is_empty():
		if _flame_mesh == null:
			_flame_mesh = QuadMesh.new()
			_flame_mesh.size = Vector2(0.075, 0.17)
			_halo_mesh = QuadMesh.new()
			_halo_mesh.size = Vector2(0.55, 0.55)
		add.call("Flames", _flame_mesh, tips, mat("flame"), 55.0)    # the wax range: no flame floats over a candle that has faded
		add.call("Halos", _halo_mesh, tips, mat("halo"), 55.0)
	if candle_lights:
		_light_clusters(parent)
	return draws + int(counter[0])


## Fallen blocks at the foot of tall upright walls (non-solid, the wall's own material): up to `debris_max` walls,
## chosen by a hash of their place, 1-3 blocks each, thrown to the side the hash picks.
func _debris() -> void:
	var made := 0
	for sb in solids.duplicate():
		if made >= debris_max or (sb as Array).size() < 4:
			continue
		var c: Vector3 = sb[0]
		var b: Basis = sb[1]
		var h: Vector3 = sb[2]
		if h.y < 1.4 or absf(b.y.y) < 0.95 or h.y * 2.0 < minf(h.x, h.z) * 1.6:
			continue
		var hv := absi(hash(Vector3i((c * 3.0).round()))) % 100
		if hv > 40:
			continue
		var key: String = sb[3]
		if not key.begins_with("ruin"):
			continue
		var out := b.z if h.x > h.z else b.x
		if hv % 2 == 0:
			out = -out
		var base_y := c.y - h.y
		for i in 1 + hv % 3:
			var r := float((hv * (i + 3)) % 100) / 100.0
			var p := c + out * (maxf(h.x, h.z) + 0.5 + r * 1.4) + b.x * ((r - 0.5) * 2.0 * h.x * 0.6)
			p.y = base_y + 0.2 + 0.1 * float(i)
			var sz := Vector3(0.5 + 0.7 * r, 0.3 + 0.3 * r, 0.45 + 0.5 * (1.0 - r))
			box(key, p, sz, Basis(Vector3.UP, r * TAU) * Basis(Vector3.RIGHT, (r - 0.5) * 0.5), false, 0.78 + 0.2 * r)
		# a carved band along the long face (a darker, proud course), and two tilted stones on the broken crown
		var along := b.x if h.x > h.z else b.z
		var lh := maxf(h.x, h.z)
		var th := minf(h.x, h.z)
		if lh > 1.2:
			var face := out * (1.0 if hv % 4 < 2 else -1.0)
			box(key, c + face * (th + 0.02) + Vector3.UP * h.y * 0.4, (Vector3(lh * 1.7, 0.18, 0.06) if h.x > h.z else Vector3(0.06, 0.18, lh * 1.7)), b, false, 0.7)
		for s: float in [-1.0, 1.0]:
			var q := float((hv * 7 + (3 if s > 0.0 else 0)) % 100) / 100.0
			box(key, c + along * (s * lh * (0.3 + 0.5 * q)) + Vector3.UP * (h.y + 0.1), Vector3(0.45 + 0.4 * q, 0.22, th * 1.5), Basis(Vector3.UP, q * 0.8) * Basis(Vector3.BACK, (q - 0.5) * 0.7), false, 0.8)
		made += 1


## One unshadowed warm light per few clustered candles (fade past 14 m): the wax lights the walls and the floor round it.
func _light_clusters(parent: Node3D) -> void:
	var kept: Array[Vector3] = []
	for p: Vector3 in _cluster_pts:
		if kept.size() >= 28:
			break
		var near := false
		for q: Vector3 in kept:
			if q.distance_squared_to(p) < 5.0:
				near = true
				break
		if near:
			continue
		kept.append(p)
		var l := OmniLight3D.new()
		l.name = "CandleLight"
		l.light_color = Color(1.0, 0.72, 0.38)
		l.light_energy = 1.0
		l.omni_range = 4.6
		l.omni_attenuation = 1.4
		l.light_specular = 0.3
		l.light_volumetric_fog_energy = 0.0
		l.shadow_enabled = false
		l.distance_fade_enabled = true
		l.distance_fade_begin = 14.0
		l.distance_fade_length = 5.0
		l.set_meta(&"light_class", &"lamp")
		l.set_meta(&"base", {"e": 1.0, "r": 4.6, "a": 1.4})
		parent.add_child(l)
		l.position = p
