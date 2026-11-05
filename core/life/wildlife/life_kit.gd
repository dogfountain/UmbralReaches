extends RefCounted
## Wildlife meshes, materials and the shared feather/fur detail texture (life system,
## docs/LIFE_PLAN.md). Bodies are CreatureMesh tubes and lumpy blobs with a rig written into the
## vertices (UV2.x = part id, UV2.y = eye), animated entirely by creature.gdshader / orbit.gdshader
## from per-instance custom data, so one MultiMesh draws a whole flock, herd or chorus.
## Meshes go through GenCache (generated once, then loaded). Creatures face -Z, +Y up; walkers and
## perchers have their origin on the ground under them, flyers at the body centre.
## Load by path (no class_name):  const LifeKit := preload("res://core/life/wildlife/life_kit.gd")

const CM := preload("res://core/enemy/creature_mesh.gd")
const GenCache := preload("res://core/world/realm/gen_cache.gd")
const SELF := "res://core/life/wildlife/life_kit.gd"
const CREATURE_SH := preload("res://core/life/wildlife/creature.gdshader")
const ORBIT_SH := preload("res://core/life/wildlife/orbit.gdshader")
const FIREFLY_SH := preload("res://core/life/wildlife/firefly.gdshader")
const RIPPLE_SH := preload("res://core/life/wildlife/ripple.gdshader")
const GHOST_SH := preload("res://core/life/wildlife/ghost.gdshader")
const VERSION := 8

## part ids (UV2.x)
const BODY := 0.0
const HEAD := 1.0
const WING_R := 2.0      ## +x
const WING_L := 3.0      ## -x
const LEG_FR := 4.0
const LEG_FL := 5.0
const LEG_BR := 6.0
const LEG_BL := 7.0
const TAIL := 8.0
const THROAT := 9.0

const ELK_S := 1.75

## Rig pivots per kind (creature.gdshader uniforms), in mesh space.
const RIG := {
	"crow": {"head_pivot": Vector3(0, 0.22, -0.08), "wing_hinge": Vector3(0.035, 0.215, -0.03), "flap_hz": 6.5, "wing_amp": 0.95, "wing_fold": 1.45, "wing_roll": 1.25},
	"owl": {"head_pivot": Vector3(0, 0.25, -0.01), "wing_hinge": Vector3(0.07, 0.235, -0.03), "flap_hz": 3.4, "wing_amp": 0.8, "wing_fold": 1.4, "wing_roll": 1.35},
	"heron": {"head_pivot": Vector3(0, 0.62, -0.13), "wing_hinge": Vector3(0.07, 0.63, -0.07), "flap_hz": 2.3, "wing_amp": 0.8, "wing_fold": 1.45, "wing_roll": 1.3,
		"hip_front": Vector2(0.44, 0.03), "leg_amp": 0.4},
	"frog": {"throat_c": Vector3(0, 0.013, -0.036)},
	"deer": {"head_pivot": Vector3(0, 1.0, -0.5), "hip_front": Vector2(0.9, -0.38), "hip_back": Vector2(0.95, 0.38), "leg_amp": 0.55},
	"stag": {"head_pivot": Vector3(0, 1.0, -0.5), "hip_front": Vector2(0.9, -0.38), "hip_back": Vector2(0.95, 0.38), "leg_amp": 0.55},
	"elk": {"head_pivot": Vector3(0, 1.0, -0.5) * ELK_S, "hip_front": Vector2(0.9, -0.38) * ELK_S, "hip_back": Vector2(0.95, 0.38) * ELK_S, "leg_amp": 0.45},
	# r36 horses (core/world/mount): deer-built, scaled per breed (HORSE_S)
	"horse_palfrey": {"head_pivot": Vector3(0, 1.0, -0.5) * 1.42, "hip_front": Vector2(0.9, -0.42) * 1.42, "hip_back": Vector2(0.95, 0.42) * 1.42, "leg_amp": 0.6},
	"horse_garron": {"head_pivot": Vector3(0, 1.0, -0.5) * 1.3, "hip_front": Vector2(0.9, -0.42) * 1.3, "hip_back": Vector2(0.95, 0.42) * 1.3, "leg_amp": 0.55},
	"horse_draught": {"head_pivot": Vector3(0, 1.0, -0.5) * 1.6, "hip_front": Vector2(0.9, -0.42) * 1.6, "hip_back": Vector2(0.95, 0.42) * 1.6, "leg_amp": 0.45},
	"horse_fenpony": {"head_pivot": Vector3(0, 1.0, -0.5) * 1.15, "hip_front": Vector2(0.9, -0.42) * 1.15, "hip_back": Vector2(0.95, 0.42) * 1.15, "leg_amp": 0.6},
	"fox": {"head_pivot": Vector3(0, 0.36, -0.2), "hip_front": Vector2(0.3, -0.18), "hip_back": Vector2(0.32, 0.17), "leg_amp": 0.6, "tail_sway": 0.18},
	"rat": {"head_pivot": Vector3(0, 0.05, -0.05), "hip_front": Vector2(0.03, -0.045), "hip_back": Vector2(0.03, 0.045), "leg_amp": 0.8, "tail_sway": 0.3},
	"mouse": {"head_pivot": Vector3(0, 0.03, -0.03), "hip_front": Vector2(0.018, -0.027), "hip_back": Vector2(0.018, 0.027), "leg_amp": 0.9, "tail_sway": 0.35},
	"hare": {"head_pivot": Vector3(0, 0.25, -0.15), "hip_front": Vector2(0.17, -0.13), "hip_back": Vector2(0.2, 0.1), "leg_amp": 0.85, "tail_sway": 0.1},
	"plover": {"head_pivot": Vector3(0, 0.17, -0.06), "wing_hinge": Vector3(0.03, 0.165, -0.02), "flap_hz": 5.2, "wing_amp": 0.9, "wing_fold": 1.45, "wing_roll": 1.25,
		"hip_front": Vector2(0.1, 0.0), "leg_amp": 0.55},
}

## Look per kind: detail strength, streak (feather/fur lie), roughness, eyeshine.
const LOOK := {
	"crow": {"detail": 0.3, "streak": 3.0, "roughness": 0.5, "rim_amount": 0.5, "eye_energy": 0.0},
	"owl": {"detail": 0.75, "streak": 2.5, "roughness": 0.9, "eye_col": Color(1.0, 0.62, 0.18), "eye_energy": 0.9},
	"heron": {"detail": 0.45, "streak": 3.5, "roughness": 0.85, "eye_col": Color(1.0, 0.85, 0.3), "eye_energy": 0.35},
	"frog": {"detail": 0.7, "streak": 1.0, "roughness": 0.35, "eye_col": Color(1.0, 0.8, 0.3), "eye_energy": 0.5, "detail_scale": 18.0, "throat_auto": 1.0},
	"deer": {"detail": 0.18, "detail_scale": 3.0, "streak": 3.0, "roughness": 0.88, "eye_col": Color(0.55, 0.95, 0.6), "eye_energy": 1.4, "rim_amount": 0.12},
	"stag": {"detail": 0.18, "detail_scale": 3.0, "streak": 3.0, "roughness": 0.88, "eye_col": Color(0.55, 0.95, 0.6), "eye_energy": 1.4, "rim_amount": 0.12},
	"elk": {"detail": 0.2, "detail_scale": 3.0, "streak": 3.0, "roughness": 0.95, "eye_col": Color(0.55, 0.95, 0.6), "eye_energy": 0.6, "rim_amount": 0.6},
	"horse_palfrey": {"detail": 0.14, "detail_scale": 2.5, "streak": 3.0, "roughness": 0.7, "eye_col": Color(0.5, 0.42, 0.3), "eye_energy": 0.2, "rim_amount": 0.25},
	"horse_garron": {"detail": 0.32, "detail_scale": 3.0, "streak": 3.5, "roughness": 0.92, "eye_col": Color(0.5, 0.42, 0.3), "eye_energy": 0.2, "rim_amount": 0.3},
	"horse_draught": {"detail": 0.16, "detail_scale": 2.0, "streak": 3.0, "roughness": 0.6, "eye_col": Color(0.5, 0.42, 0.3), "eye_energy": 0.2, "rim_amount": 0.35},
	"horse_fenpony": {"detail": 0.4, "detail_scale": 3.5, "streak": 4.0, "roughness": 0.95, "eye_col": Color(0.5, 0.42, 0.3), "eye_energy": 0.2, "rim_amount": 0.2},
	"fox": {"detail": 0.2, "detail_scale": 4.0, "streak": 3.0, "roughness": 0.88, "eye_col": Color(1.0, 0.85, 0.45), "eye_energy": 1.4, "rim_amount": 0.12},
	"rat": {"detail": 0.5, "streak": 2.0, "roughness": 0.8, "eye_col": Color(1.0, 0.3, 0.2), "eye_energy": 1.0, "detail_scale": 20.0},
	"branch": {"detail": 0.8, "streak": 4.0, "roughness": 0.95, "detail_scale": 3.0},
	"mouse": {"detail": 0.45, "streak": 2.0, "roughness": 0.85, "eye_col": Color(0.9, 0.5, 0.3), "eye_energy": 0.6, "detail_scale": 22.0},
	"plover": {"detail": 0.35, "streak": 3.0, "roughness": 0.55, "rim_amount": 0.4, "eye_energy": 0.0},
	"hare": {"detail": 0.3, "detail_scale": 7.0, "streak": 2.5, "roughness": 0.9, "eye_col": Color(1.0, 0.7, 0.3), "eye_energy": 1.1, "rim_amount": 0.18},
}

static var _meshes := {}
static var _mats := {}
static var _tex: Texture2D


# --- public ------------------------------------------------------------------------------------

static func mesh(kind: String) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var m: Mesh
	match kind:
		"firefly":
			var q := QuadMesh.new()
			q.size = Vector2(2, 2)
			m = q
		"ring":
			var pl := PlaneMesh.new()
			pl.size = Vector2(2, 2)
			m = pl
		_:
			var key := "life_%s_v%d" % [kind, VERSION]
			m = GenCache.load_mesh(key, SELF)
			if m == null:
				m = _build(kind)
				GenCache.save_mesh(key, SELF, m as ArrayMesh)
	_meshes[kind] = m
	return m


static func material(kind: String) -> ShaderMaterial:
	if _mats.has(kind):
		return _mats[kind]
	var mat := ShaderMaterial.new()
	match kind:
		"moth":
			mat.shader = ORBIT_SH
			mat.set_shader_parameter("detail_tex", detail_tex())
			mat.set_shader_parameter("detail_scale", 30.0)
			mat.set_shader_parameter("wing_hinge", Vector3(0.004, 0, 0))
			mat.set_shader_parameter("flap_hz", 26.0)
			mat.set_shader_parameter("wing_amp", 0.9)
			mat.set_shader_parameter("jink", 0.32)
			mat.set_shader_parameter("ellipse", 0.85)
			mat.set_shader_parameter("bank", 0.3)
			mat.set_shader_parameter("translucency", 0.7)
			mat.set_shader_parameter("rim_col", Color(1.0, 0.72, 0.38))
			mat.set_shader_parameter("rim_amount", 0.35)
		"bat":
			mat.shader = ORBIT_SH
			mat.set_shader_parameter("detail_tex", detail_tex())
			mat.set_shader_parameter("detail_scale", 6.0)
			mat.set_shader_parameter("wing_hinge", Vector3(0.016, 0.0, 0.0))
			mat.set_shader_parameter("flap_hz", 11.0)
			mat.set_shader_parameter("wing_amp", 0.85)
			mat.set_shader_parameter("jink", 0.08)
			mat.set_shader_parameter("ellipse", 0.6)
			mat.set_shader_parameter("bank", 0.55)
			mat.set_shader_parameter("translucency", 0.25)
			mat.set_shader_parameter("rim_col", Color(0.45, 0.6, 1.0))
			mat.set_shader_parameter("rim_amount", 0.4)
			mat.set_shader_parameter("size_mul", 1.4)
		"firefly":
			mat.shader = FIREFLY_SH
		"ripple":
			mat.shader = RIPPLE_SH
		"ghost_stag":
			mat.shader = GHOST_SH
			mat.set_shader_parameter("detail_tex", detail_tex())
			for k: String in RIG["stag"]:
				mat.set_shader_parameter(k, RIG["stag"][k])
			mat.set_shader_parameter("detail", 0.3)
			mat.set_shader_parameter("detail_scale", 3.0)
			mat.set_shader_parameter("streak", 3.0)
		_:
			mat.shader = CREATURE_SH
			mat.set_shader_parameter("detail_tex", detail_tex())
			var rig: Dictionary = RIG.get(kind, {})
			for k: String in rig:
				mat.set_shader_parameter(k, rig[k])
			var look: Dictionary = LOOK.get(kind, {})
			for k: String in look:
				mat.set_shader_parameter(k, look[k])
	_mats[kind] = mat
	return mat


## A tiling streaky noise (feathers, fur, bark), grey around 0.5.
static func detail_tex() -> Texture2D:
	if _tex != null:
		return _tex
	var key := "life_detail_tex_v%d" % VERSION
	var data: Variant = GenCache.load_var(key, SELF)
	var img: Image
	if data is PackedByteArray and (data as PackedByteArray).size() == 128 * 128:
		img = Image.create_from_data(128, 128, false, Image.FORMAT_L8, data)
	else:
		var n := FastNoiseLite.new()
		n.seed = 77
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.045
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = 4
		n.fractal_gain = 0.55
		var a := n.get_seamless_image(128, 128, false, false, 0.1, true)
		var c := FastNoiseLite.new()
		c.seed = 9
		c.noise_type = FastNoiseLite.TYPE_CELLULAR
		c.frequency = 0.09
		c.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_DIV
		var b := c.get_seamless_image(128, 128, false, false, 0.1, true)
		img = Image.create(128, 128, false, Image.FORMAT_L8)
		for y in 128:
			for x in 128:
				var v := a.get_pixel(x, y).r * 0.6 + b.get_pixel(x, y).r * 0.4
				img.set_pixel(x, y, Color(v, v, v))
		GenCache.save_var(key, SELF, img.get_data())
	img.generate_mipmaps()
	_tex = ImageTexture.create_from_image(img)
	return _tex


## A MultiMeshInstance3D for `count` creatures of `kind` (transform + custom data), shadows off.
static func group(kind: String, count: int, mat_kind := "") -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh(kind)
	mm.instance_count = count
	var mmi := MultiMeshInstance3D.new()
	mmi.name = kind.capitalize().replace(" ", "")
	mmi.multimesh = mm
	mmi.material_override = material(kind if mat_kind == "" else mat_kind)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the groups write whole buffers every rendered frame (not per physics tick): with physics
	# interpolation on, an interpolated MultiMesh keeps prev/current copies and a herd written from
	# _process could draw stale or nothing at all
	mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	mm.physics_interpolation_quality = MultiMesh.INTERP_QUALITY_FAST
	mmi.set_meta("chunked", true)          # Atmosphere's realm pass must not split a live flock
	mmi.set_meta("site_owned", true)       # nor WorldLanes.cull_scatter thin it on a site (the henge)
	mmi.add_to_group(Groups.CULL_SKIP)
	return mmi


# --- builders ------------------------------------------------------------------------------------

static func _build(kind: String) -> ArrayMesh:
	var cm := CM.new(hash(kind) % 997)
	match kind:
		"moth": _moth(cm)
		"bat": _bat(cm)
		"crow": _crow(cm)
		"owl": _owl(cm)
		"heron": _heron(cm)
		"frog": _frog(cm)
		"deer": _deer(cm, 1.0, 0)
		"stag": _deer(cm, 1.0, 1)
		"elk": _deer(cm, ELK_S, 2)
		"fox": _fox(cm)
		"horse_palfrey": _horse(cm, 1.42, Color(0.36, 0.17, 0.08), Color(0.08, 0.05, 0.04), 0.0, 1.0)
		"horse_garron": _horse(cm, 1.3, Color(0.52, 0.5, 0.48), Color(0.86, 0.84, 0.8), 1.0, 1.18)
		"horse_draught": _horse(cm, 1.6, Color(0.07, 0.06, 0.06), Color(0.1, 0.08, 0.07), 1.0, 1.3)
		"horse_fenpony": _horse(cm, 1.15, Color(0.6, 0.48, 0.3), Color(0.24, 0.17, 0.1), 0.6, 1.25)
		"rat": _rat(cm)
		"mouse": _mouse(cm)
		"plover": _plover(cm)
		"hare": _hare(cm)
		"branch": _branch(cm)
	return cm.commit()


static func _p(a: Array) -> PackedVector3Array:
	return PackedVector3Array(a)


static func _r(a: Array) -> PackedFloat32Array:
	return PackedFloat32Array(a)


static func _tilt(a: float) -> Basis:
	return Basis(Vector3.RIGHT, a)


static func _moth(cm) -> void:
	var s := 1.7
	var body := Color(0.33, 0.27, 0.2)
	var wing := Color(0.7, 0.62, 0.48)
	cm.tube(_p([Vector3(0, 0, -0.011) * s, Vector3(0, 0.001, 0.0), Vector3(0, 0, 0.016) * s]), _r([0.0035 * s, 0.0045 * s, 0.0015 * s]), 5, body, 0.0, 0.1)
	cm.blob(Vector3(0, 0.001, -0.013) * s, Vector3(0.003, 0.003, 0.003) * s, Basis.IDENTITY, body, 0.0, 0.0, HEAD, 3, 5)
	for side: float in [1.0, -1.0]:
		var part := WING_R if side > 0.0 else WING_L
		cm.blob(Vector3(0.016 * side, 0.0015, -0.003) * s, Vector3(0.015, 0.0008, 0.0095) * s, Basis(Vector3.UP, side * 0.35), wing, 0.0, 0.25, part, 3, 7)
		cm.blob(Vector3(0.011 * side, 0.001, 0.008) * s, Vector3(0.01, 0.0007, 0.0075) * s, Basis(Vector3.UP, -side * 0.3), wing.darkened(0.15), 0.0, 0.25, part, 3, 6)
		cm.tube(_p([Vector3(0.002 * side, 0.002, -0.015) * s, Vector3(0.008 * side, 0.005, -0.026) * s]), _r([0.0006 * s, 0.0]), 3, body, 1.0, 0.0, HEAD)


static func _bat(cm) -> void:
	var fur := Color(0.16, 0.11, 0.09)
	var skin := Color(0.13, 0.09, 0.08)
	cm.blob(Vector3(0, 0, 0.005), Vector3(0.026, 0.022, 0.048), Basis.IDENTITY, fur, 0.0, 0.15, BODY, 5, 8)
	cm.blob(Vector3(0, 0.006, -0.045), Vector3(0.018, 0.017, 0.019), Basis.IDENTITY, fur, 0.0, 0.1, BODY, 5, 8)
	for side: float in [1.0, -1.0]:
		var part := WING_R if side > 0.0 else WING_L
		cm.tube(_p([Vector3(0.008 * side, 0.02, -0.05), Vector3(0.016 * side, 0.045, -0.047)]), _r([0.008, 0.0]), 4, skin, 0.0, 0.0, BODY)
		cm.blob(Vector3(0.095 * side, 0.0, 0.012), Vector3(0.085, 0.003, 0.045), Basis(Vector3.UP, side * 0.12), skin, 0.0, 0.3, part, 4, 10)
		var elbow := Vector3(0.075 * side, 0.004, -0.022)
		cm.tube(_p([Vector3(0.016 * side, 0.002, -0.008), elbow, Vector3(0.17 * side, 0.0, -0.005)]), _r([0.006, 0.0045, 0.0]), 4, fur, 1.0, 0.0, part)
		for tip: Vector3 in [Vector3(0.15, 0, 0.04), Vector3(0.11, 0, 0.058), Vector3(0.065, 0, 0.055)]:
			cm.tube(_p([elbow, Vector3(tip.x * side, tip.y, tip.z)]), _r([0.003, 0.0]), 3, skin, 1.0, 0.0, part)
		cm.blob(Vector3(0.009 * side, 0.012, -0.058), Vector3(0.003, 0.003, 0.002), Basis.IDENTITY, skin, 0.0, 0.0, BODY, 3, 4, 1.0)


static func _crow(cm) -> void:
	var black := Color(0.075, 0.075, 0.09)
	var beak := Color(0.09, 0.09, 0.1)
	cm.blob(Vector3(0, 0.17, 0.005), Vector3(0.066, 0.07, 0.13), _tilt(0.32), black, 0.0, 0.12, BODY, 7, 10)
	cm.blob(Vector3(0, 0.15, -0.04), Vector3(0.058, 0.06, 0.07), Basis.IDENTITY, black, 0.0, 0.15, BODY, 6, 9)
	# neck + head (rotate with the head)
	cm.tube(_p([Vector3(0, 0.2, -0.07), Vector3(0, 0.245, -0.11)]), _r([0.042, 0.038]), 7, black, 0.0, 0.15, HEAD)
	cm.blob(Vector3(0, 0.27, -0.125), Vector3(0.046, 0.044, 0.056), Basis.IDENTITY, black, 0.0, 0.1, HEAD, 6, 9)
	cm.tube(_p([Vector3(0, 0.272, -0.165), Vector3(0, 0.264, -0.21), Vector3(0, 0.252, -0.238)]), _r([0.017, 0.009, 0.0]), 6, beak, 1.0, 0.0, HEAD)
	for side: float in [1.0, -1.0]:
		cm.blob(Vector3(0.03 * side, 0.284, -0.148), Vector3(0.008, 0.008, 0.006), Basis.IDENTITY, black, 0.0, 0.0, HEAD, 3, 5, 1.0)
		var part := WING_R if side > 0.0 else WING_L
		# spread wing: inner blob + primaries (fingers) at the tip
		cm.blob(Vector3(0.14 * side, 0.215, 0.02), Vector3(0.12, 0.008, 0.06), Basis(Vector3.UP, side * 0.06), black, 0.0, 0.2, part, 4, 10)
		for k in 4:
			var root := Vector3(0.22 * side, 0.215, -0.005 + float(k) * 0.02)
			cm.tube(_p([root, root + Vector3(0.075 * side, 0.0, 0.01 + float(k) * 0.012)]), _r([0.011, 0.0]), 4, black, 0.0, 0.05, part, Vector2(1.0, 0.3))
		# legs and toes
		var hip := Vector3(0.025 * side, 0.12, 0.0)
		var foot := Vector3(0.03 * side, 0.004, -0.01)
		cm.tube(_p([hip, Vector3(0.028 * side, 0.06, 0.012), foot]), _r([0.009, 0.006, 0.005]), 4, beak, 1.0, 0.0)
		for t: Vector3 in [Vector3(0.0, 0, -0.04), Vector3(0.018 * side, 0, -0.03), Vector3(-0.004 * side, 0, 0.03)]:
			cm.tube(_p([foot, foot + t]), _r([0.004, 0.0]), 3, beak, 1.0, 0.0)
	cm.blob(Vector3(0, 0.13, 0.2), Vector3(0.042, 0.01, 0.1), _tilt(-0.35), black, 0.0, 0.15, TAIL, 4, 8)


static func _owl(cm) -> void:
	var brown := Color(0.36, 0.27, 0.19)
	var pale := Color(0.55, 0.45, 0.33)
	var disc := Color(0.58, 0.5, 0.38)
	cm.blob(Vector3(0, 0.15, 0.0), Vector3(0.1, 0.135, 0.09), _tilt(0.12), brown, 0.0, 0.12, BODY, 8, 12)
	cm.blob(Vector3(0, 0.135, -0.035), Vector3(0.085, 0.11, 0.06), Basis.IDENTITY, pale, 0.0, 0.1, BODY, 7, 10)
	cm.blob(Vector3(0, 0.3, -0.01), Vector3(0.088, 0.078, 0.078), Basis.IDENTITY, brown, 0.0, 0.1, HEAD, 8, 12)
	cm.blob(Vector3(0, 0.295, -0.058), Vector3(0.072, 0.064, 0.028), Basis.IDENTITY, disc, 0.0, 0.08, HEAD, 6, 10)
	cm.tube(_p([Vector3(0, 0.3, -0.083), Vector3(0, 0.285, -0.098), Vector3(0, 0.27, -0.096)]), _r([0.011, 0.006, 0.0]), 5, Color(0.4, 0.35, 0.22), 1.0, 0.0, HEAD)
	for side: float in [1.0, -1.0]:
		cm.blob(Vector3(0.028 * side, 0.308, -0.08), Vector3(0.016, 0.016, 0.009), Basis.IDENTITY, brown, 0.0, 0.0, HEAD, 4, 6, 1.0)
		cm.tube(_p([Vector3(0.05 * side, 0.355, -0.03), Vector3(0.062 * side, 0.395, -0.02), Vector3(0.068 * side, 0.42, -0.012)]), _r([0.016, 0.01, 0.0]), 4, brown.darkened(0.25), 0.0, 0.1, HEAD, Vector2(1.0, 0.5))
		var part := WING_R if side > 0.0 else WING_L
		cm.blob(Vector3(0.17 * side, 0.235, 0.02), Vector3(0.15, 0.01, 0.075), Basis(Vector3.UP, side * 0.05), brown, 0.0, 0.2, part, 4, 10)
		for k in 4:
			var root := Vector3(0.29 * side, 0.235, -0.015 + float(k) * 0.024)
			cm.tube(_p([root, root + Vector3(0.07 * side, 0.0, 0.012 + float(k) * 0.01)]), _r([0.014, 0.0]), 4, brown.darkened(0.1), 0.0, 0.05, part, Vector2(1.0, 0.3))
		# feathered legs and talons gripping the branch
		var knee := Vector3(0.035 * side, 0.05, -0.02)
		cm.blob(knee, Vector3(0.025, 0.035, 0.025), Basis.IDENTITY, pale, 0.0, 0.1, BODY, 4, 6)
		for t: Vector3 in [Vector3(0.0, -0.015, -0.035), Vector3(0.015 * side, -0.015, -0.03), Vector3(0.0, -0.015, 0.03)]:
			cm.claw(knee + Vector3(0, -0.03, 0), t.normalized(), 0.035, 0.006, Vector3(0, -0.6, 0), Color(0.2, 0.18, 0.15))
	cm.blob(Vector3(0, 0.08, 0.085), Vector3(0.045, 0.012, 0.06), _tilt(-0.9), brown.darkened(0.15), 0.0, 0.1, TAIL, 4, 8)


static func _heron(cm) -> void:
	var grey := Color(0.46, 0.48, 0.52)
	var pale := Color(0.7, 0.71, 0.72)
	var dark := Color(0.12, 0.12, 0.14)
	var leg := Color(0.38, 0.33, 0.2)
	var bill := Color(0.75, 0.6, 0.26)
	cm.blob(Vector3(0, 0.58, 0.04), Vector3(0.1, 0.1, 0.22), _tilt(0.45), grey, 0.0, 0.1, BODY, 7, 11)
	cm.blob(Vector3(0, 0.6, -0.08), Vector3(0.075, 0.09, 0.08), Basis.IDENTITY, pale, 0.0, 0.1, BODY, 5, 8)
	for side: float in [1.0, -1.0]:
		var lp := LEG_FR if side > 0.0 else LEG_FL
		var hip := Vector3(0.04 * side, 0.48, 0.03)
		var knee := Vector3(0.042 * side, 0.24, 0.05)
		var foot := Vector3(0.04 * side, 0.005, 0.03)
		cm.tube(_p([hip, knee, foot]), _r([0.02, 0.012, 0.01]), 5, leg, 0.5, 0.05, lp)
		for t: Vector3 in [Vector3(0.0, 0, -0.08), Vector3(0.04 * side, 0, -0.06), Vector3(-0.01 * side, 0, 0.05)]:
			cm.tube(_p([foot, foot + t]), _r([0.006, 0.0]), 3, leg, 0.5, 0.0, lp)
		var part := WING_R if side > 0.0 else WING_L
		cm.blob(Vector3(0.3 * side, 0.63, 0.04), Vector3(0.27, 0.012, 0.13), Basis(Vector3.UP, side * 0.06), grey, 0.0, 0.15, part, 4, 12)
		for k in 5:
			var root := Vector3(0.52 * side, 0.63, -0.05 + float(k) * 0.04)
			cm.tube(_p([root, root + Vector3(0.1 * side, 0.0, 0.02 + float(k) * 0.015)]), _r([0.02, 0.0]), 4, dark, 0.0, 0.05, part, Vector2(1.0, 0.3))
		cm.blob(Vector3(0.095 * side, 0.6, 0.0), Vector3(0.015, 0.05, 0.12), _tilt(0.45), dark, 0.0, 0.1, BODY, 4, 6)
		cm.blob(Vector3(0.014 * side, 0.975, -0.285), Vector3(0.006, 0.006, 0.005), Basis.IDENTITY, pale, 0.0, 0.0, HEAD, 3, 4, 1.0)
	# S-necked, head and dagger bill, a black crest plume
	cm.tube(_p([Vector3(0, 0.62, -0.13), Vector3(0, 0.71, -0.2), Vector3(0, 0.8, -0.17), Vector3(0, 0.9, -0.19), Vector3(0, 0.955, -0.25)]),
		_r([0.045, 0.034, 0.03, 0.028, 0.026]), 6, pale, 0.0, 0.08, HEAD)
	cm.blob(Vector3(0, 0.97, -0.27), Vector3(0.03, 0.032, 0.05), Basis.IDENTITY, pale, 0.0, 0.05, HEAD, 5, 8)
	cm.tube(_p([Vector3(0, 0.968, -0.31), Vector3(0, 0.96, -0.39), Vector3(0, 0.952, -0.45)]), _r([0.014, 0.008, 0.0]), 5, bill, 1.0, 0.0, HEAD)
	cm.tube(_p([Vector3(0, 0.99, -0.25), Vector3(0, 0.98, -0.18), Vector3(0, 0.96, -0.13)]), _r([0.006, 0.004, 0.0]), 3, dark, 0.0, 0.0, HEAD)
	cm.blob(Vector3(0, 0.52, 0.25), Vector3(0.05, 0.012, 0.08), _tilt(-0.4), grey.darkened(0.2), 0.0, 0.1, TAIL, 4, 6)


static func _frog(cm) -> void:
	var olive := Color(0.25, 0.29, 0.13)
	var belly := Color(0.55, 0.5, 0.33)
	cm.blob(Vector3(0, 0.026, 0.012), Vector3(0.03, 0.022, 0.04), _tilt(0.25), olive, 0.0, 0.25, BODY, 6, 9)
	cm.blob(Vector3(0, 0.03, -0.024), Vector3(0.027, 0.018, 0.026), Basis.IDENTITY, olive, 0.0, 0.15, BODY, 5, 8)
	cm.blob(Vector3(0, 0.013, -0.036), Vector3(0.016, 0.009, 0.013), Basis.IDENTITY, belly, 0.0, 0.05, THROAT, 4, 6)
	for side: float in [1.0, -1.0]:
		cm.blob(Vector3(0.016 * side, 0.046, -0.028), Vector3(0.0085, 0.008, 0.008), Basis.IDENTITY, olive, 0.0, 0.0, BODY, 4, 6)
		cm.blob(Vector3(0.019 * side, 0.049, -0.031), Vector3(0.006, 0.006, 0.005), Basis.IDENTITY, olive, 0.0, 0.0, BODY, 3, 5, 1.0)
		cm.tube(_p([Vector3(0.022 * side, 0.022, 0.035), Vector3(0.042 * side, 0.02, 0.005), Vector3(0.03 * side, 0.004, 0.042), Vector3(0.036 * side, 0.002, 0.065)]),
			_r([0.012, 0.009, 0.006, 0.004]), 5, olive, 0.0, 0.1)
		cm.tube(_p([Vector3(0.016 * side, 0.016, -0.02), Vector3(0.022 * side, 0.004, -0.032), Vector3(0.026 * side, 0.001, -0.045)]), _r([0.006, 0.004, 0.003]), 4, olive, 0.0, 0.1)


## Red deer: hind (0), stag (1: branched antlers, neck mane) or the great elk (2: scaled, palmate).
## Warm red-brown coat with a darker dorsal line and legs, a buff belly and rump patch; legs are
## built joint by joint (shoulder / thigh muscle, forearm or gaskin, knee or hock, cannon, fetlock,
## pastern, a cloven hoof); a modelled head: skull, tapered muzzle, jaw, nose pad, eye with a dark
## rim, cupped ears.
static func _deer(cm, s: float, antler: int) -> void:
	var elk := antler == 2
	var coat := Color(0.46, 0.21, 0.09) if not elk else Color(0.3, 0.17, 0.09)
	var dorsal := coat.darkened(0.3)
	var belly := Color(0.56, 0.38, 0.23) if not elk else Color(0.4, 0.3, 0.21)
	var rump := Color(0.64, 0.5, 0.34)
	var leg := Color(0.26, 0.14, 0.07)
	var hoof := Color(0.05, 0.04, 0.035)
	var horn := Color(0.3, 0.23, 0.15)
	var tip := Color(0.7, 0.64, 0.52)
	var mane := Color(0.2, 0.11, 0.06)
	var v := func(x: float, y: float, z: float) -> Vector3: return Vector3(x, y, z) * s
	# the head sits forward and a little low on a neck that reaches out, not up
	var h := func(x: float, y: float, z: float) -> Vector3: return (Vector3(x, y, z) + Vector3(0, -0.09, -0.11)) * s
	# torso
	cm.blob(v.call(0, 0.98, 0.0), Vector3(0.2, 0.25, 0.5) * s, Basis.IDENTITY, coat, 0.0, 0.07, BODY, 9, 14)
	cm.blob(v.call(0, 0.99, -0.31), Vector3(0.19, 0.27, 0.24) * s, Basis.IDENTITY, coat, 0.0, 0.07, BODY, 7, 11)
	cm.blob(v.call(0, 1.01, 0.31), Vector3(0.2, 0.25, 0.25) * s, Basis.IDENTITY, coat, 0.0, 0.07, BODY, 7, 11)
	cm.blob(v.call(0, 1.18, 0.0), Vector3(0.1, 0.07, 0.48) * s, Basis.IDENTITY, dorsal, 0.0, 0.05, BODY, 5, 10)
	cm.blob(v.call(0, 0.84, 0.02), Vector3(0.14, 0.1, 0.36) * s, Basis.IDENTITY, belly, 0.0, 0.05, BODY, 5, 10)
	cm.blob(v.call(0, 1.02, 0.5), Vector3(0.09, 0.11, 0.035) * s, Basis.IDENTITY, rump, 0.0, 0.05, BODY, 5, 8)
	cm.tube(_p([v.call(0, 1.1, 0.55), v.call(0, 1.05, 0.6), v.call(0, 0.98, 0.61)]), _r([0.035 * s, 0.03 * s, 0.0]), 5, dorsal, 0.0, 0.1, TAIL)
	for side: float in [1.0, -1.0]:
		var x := 0.11 * side
		var fp := LEG_FR if side > 0.0 else LEG_FL
		var bp := LEG_BR if side > 0.0 else LEG_BL
		# foreleg: shoulder muscle, forearm, knee, cannon, fetlock, pastern, hoof
		cm.blob(v.call(x * 1.05, 0.84, -0.37), Vector3(0.075, 0.16, 0.1) * s, Basis.IDENTITY, coat, 0.0, 0.06, fp, 6, 8)
		cm.tube(_p([v.call(x, 0.82, -0.37), v.call(x, 0.62, -0.355), v.call(x * 0.95, 0.42, -0.37)]), _r([0.062 * s, 0.045 * s, 0.033 * s]), 7, coat.darkened(0.15), 0.0, 0.06, fp)
		cm.blob(v.call(x * 0.95, 0.4, -0.368), Vector3(0.034, 0.042, 0.036) * s, Basis.IDENTITY, leg, 0.0, 0.03, fp, 4, 6)
		_lower_leg(cm, v, x * 0.95, -0.37, 0.4, leg, hoof, fp, s)
		# hind leg: thigh, gaskin, hock (+ its point), cannon, fetlock, pastern, hoof
		cm.blob(v.call(x * 1.05, 0.87, 0.36), Vector3(0.08, 0.2, 0.15) * s, Basis.IDENTITY, coat, 0.0, 0.06, bp, 6, 9)
		cm.tube(_p([v.call(x, 0.78, 0.36), v.call(x, 0.6, 0.42), v.call(x * 0.95, 0.44, 0.47)]), _r([0.068 * s, 0.045 * s, 0.034 * s]), 7, coat.darkened(0.15), 0.0, 0.06, bp)
		cm.blob(v.call(x * 0.95, 0.43, 0.47), Vector3(0.033, 0.045, 0.04) * s, Basis.IDENTITY, leg, 0.0, 0.03, bp, 4, 6)
		cm.blob(v.call(x * 0.95, 0.45, 0.505), Vector3(0.018, 0.022, 0.018) * s, Basis.IDENTITY, leg, 1.0, 0.0, bp, 3, 5)
		_lower_leg(cm, v, x * 0.95, 0.465, 0.42, leg, hoof, bp, s, 0.41)
		# head details per side: eye with a dark rim, cupped ear with a pale inner face
		cm.blob(h.call(0.058 * side, 1.565, -0.825), Vector3(0.026, 0.024, 0.02) * s, Basis.IDENTITY, hoof, 0.0, 0.0, HEAD, 4, 6)
		cm.blob(h.call(0.066 * side, 1.565, -0.83), Vector3(0.017, 0.017, 0.014) * s, Basis.IDENTITY, hoof, 0.0, 0.0, HEAD, 4, 6, 1.0)
		var ear_b := Basis(Vector3.FORWARD, -side * (0.75 if antler == 0 else 0.95)) * Basis(Vector3.RIGHT, -0.35)
		var ear_c: Vector3 = h.call(0.09 * side, 1.665, -0.71)
		var ear_r := Vector3(0.036, 0.085, 0.016) if antler == 0 else Vector3(0.03, 0.068, 0.014)
		cm.blob(ear_c, ear_r * s, ear_b, coat, 0.0, 0.05, HEAD, 5, 8)
		cm.blob(ear_c + ear_b * Vector3(0, 0, -0.008 * s), ear_r * Vector3(0.7, 0.8, 0.5) * s, ear_b, belly, 0.0, 0.0, HEAD, 4, 7)
		if antler == 1:
			_antler(cm, h, side, horn, tip, s)
		elif elk:
			var beam2 := [h.call(0.05 * side, 1.66, -0.72), h.call(0.16 * side, 1.74, -0.66), h.call(0.32 * side, 1.84, -0.56), h.call(0.46 * side, 1.98, -0.48)]
			cm.tube(_p(beam2), _r([0.038 * s, 0.032 * s, 0.027 * s, 0.022 * s]), 6, horn, 1.0, 0.08, HEAD)
			cm.blob(h.call(0.48 * side, 2.04, -0.45), Vector3(0.2, 0.14, 0.028) * s, Basis(Vector3.FORWARD, side * 0.5) * Basis(Vector3.UP, side * 0.35), horn, 1.0, 0.12, HEAD, 5, 12)
			for k in 7:
				var t0: Vector3 = h.call((0.32 + 0.055 * k) * side, 2.07 + 0.05 * sin(float(k)), -0.49 + 0.012 * k)
				cm.tube(_p([t0, t0 + h.call(0.03 * side, 0.15, 0.0)]), _r([0.02 * s, 0.0]), 4, tip, 1.0, 0.0, HEAD)
			cm.tube(_p([h.call(0.1 * side, 1.72, -0.72), h.call(0.13 * side, 1.79, -0.88)]), _r([0.02 * s, 0.0]), 4, horn, 1.0, 0.0, HEAD)
	# neck (HEAD pivots at the chest so grazing lowers it all), throat, the stag's shaggy mane
	cm.tube(_p([v.call(0, 1.02, -0.42), v.call(0, 1.18, -0.6), v.call(0, 1.32, -0.75), v.call(0, 1.42, -0.84)]), _r([0.17 * s, 0.125 * s, 0.095 * s, 0.08 * s]), 9, coat, 0.0, 0.05, HEAD)
	cm.tube(_p([v.call(0, 1.16, -0.37), v.call(0, 1.32, -0.58), v.call(0, 1.43, -0.76)]), _r([0.05 * s, 0.04 * s, 0.025 * s]), 5, dorsal, 0.0, 0.05, HEAD)
	if antler > 0:
		for k in 7:
			var t := float(k) / 6.0
			var root: Vector3 = v.call(0.0, lerpf(1.06, 1.33, t), lerpf(-0.6, -0.84, t))
			cm.tube(_p([root, root + h.call(0.025 * sin(float(k) * 2.3), -0.14 + 0.06 * t, -0.02)]), _r([0.05 * s, 0.0]), 5, mane, 0.0, 0.25, HEAD, Vector2(1.0, 0.6))
	# head: skull, brow, tapered muzzle, jaw, pale lips and chin, nose pad
	cm.blob(h.call(0, 1.56, -0.78), Vector3(0.072, 0.08, 0.1) * s, _tilt(-0.35), coat, 0.0, 0.05, HEAD, 7, 10)
	cm.tube(_p([h.call(0, 1.55, -0.84), h.call(0, 1.5, -0.93), h.call(0, 1.455, -1.0)]), _r([0.058 * s, 0.044 * s, 0.033 * s]), 8, coat, 0.0, 0.04, HEAD, Vector2(1.0, 0.85))
	cm.tube(_p([h.call(0, 1.49, -0.8), h.call(0, 1.44, -0.92), h.call(0, 1.425, -0.985)]), _r([0.04 * s, 0.028 * s, 0.02 * s]), 6, belly, 0.0, 0.03, HEAD)
	cm.blob(h.call(0, 1.44, -0.99), Vector3(0.036, 0.022, 0.03) * s, Basis.IDENTITY, belly, 0.0, 0.0, HEAD, 4, 7)
	cm.blob(h.call(0, 1.458, -1.012), Vector3(0.03, 0.022, 0.016) * s, Basis.IDENTITY, hoof, 1.0, 0.0, HEAD, 4, 7)


static func _lower_leg(cm, v: Callable, x: float, z: float, top: float, leg: Color, hoof: Color, part: float, s: float, z_hoof := NAN) -> void:
	var zh := z if is_nan(z_hoof) else z_hoof
	cm.tube(_p([v.call(x, top, z), v.call(x, 0.11, lerpf(z, zh, 0.8))]), _r([0.026 * s, 0.021 * s]), 6, leg, 0.0, 0.03, part)
	cm.blob(v.call(x, 0.1, zh), Vector3(0.029, 0.032, 0.03) * s, Basis.IDENTITY, leg, 0.0, 0.02, part, 4, 6)
	cm.tube(_p([v.call(x, 0.1, zh), v.call(x, 0.045, zh - 0.02)]), _r([0.022 * s, 0.024 * s]), 6, leg, 0.0, 0.02, part)
	for t: float in [-1.0, 1.0]:
		cm.tube(_p([v.call(x + t * 0.011, 0.048, zh - 0.018), v.call(x + t * 0.013, 0.0, zh - 0.045)]), _r([0.016 * s, 0.011 * s]), 5, hoof, 1.0, 0.0, part)
	cm.blob(v.call(x, 0.07, zh + 0.03), Vector3(0.008, 0.01, 0.008) * s, Basis.IDENTITY, hoof, 1.0, 0.0, part, 3, 4)


## A red deer stag's antler: beaded beam sweeping up and back, brow, bez and trez tines, a crown.
static func _antler(cm, v: Callable, side: float, horn: Color, tip: Color, s: float) -> void:
	var beam: Array = [v.call(0.05 * side, 1.655, -0.72), v.call(0.09 * side, 1.73, -0.715), v.call(0.16 * side, 1.87, -0.68),
		v.call(0.22 * side, 2.02, -0.61), v.call(0.26 * side, 2.17, -0.53), v.call(0.26 * side, 2.27, -0.48)]
	cm.blob(beam[0], Vector3(0.036, 0.022, 0.036) * s, Basis.IDENTITY, horn, 1.0, 0.3, HEAD, 4, 7)
	cm.tube(_p(beam), _r([0.03 * s, 0.028 * s, 0.024 * s, 0.021 * s, 0.018 * s, 0.016 * s]), 6, horn, 1.0, 0.12, HEAD)
	var tines := [[1, Vector3(0.03, 0.06, -0.2), Vector3(0.02, 0.07, -0.05)], [2, Vector3(0.04, 0.05, -0.17), Vector3(0.0, 0.05, -0.04)],
		[3, Vector3(0.05, 0.06, -0.15), Vector3(0.0, 0.05, -0.03)]]
	for tn: Array in tines:
		var b: Vector3 = beam[int(tn[0])]
		var d1: Vector3 = tn[1]
		var d2: Vector3 = tn[2]
		var m: Vector3 = b + v.call(d1.x * side, d1.y, d1.z)
		var e: Vector3 = m + v.call(d2.x * side, d2.y, d2.z)
		cm.tube(_p([b, m, e]), _r([0.017 * s, 0.012 * s, 0.0]), 5, horn, 1.0, 0.05, HEAD)
		cm.tube(_p([m.lerp(e, 0.4), e]), _r([0.009 * s, 0.0]), 4, tip, 1.0, 0.0, HEAD)
	var top: Vector3 = beam[5]
	for d: Vector3 in [Vector3(0.0, 0.13, -0.06), Vector3(0.06, 0.11, 0.0), Vector3(-0.02, 0.1, 0.07)]:
		var e: Vector3 = top + v.call(d.x * side, d.y, d.z)
		cm.tube(_p([top, e]), _r([0.014 * s, 0.0]), 5, horn, 1.0, 0.05, HEAD)
		cm.tube(_p([top.lerp(e, 0.55), e]), _r([0.007 * s, 0.0]), 4, tip, 1.0, 0.0, HEAD)


## Red fox: bright orange coat with a white throat, chest, cheeks and tail tip, black socks and
## ear backs, a slim pointed muzzle and a big bushy tail.
static func _fox(cm) -> void:
	var red := Color(0.82, 0.34, 0.07)
	var white := Color(0.88, 0.85, 0.78)
	var cream := Color(0.78, 0.62, 0.42)
	var black := Color(0.05, 0.04, 0.035)
	cm.blob(Vector3(0, 0.33, 0.0), Vector3(0.088, 0.1, 0.24), Basis.IDENTITY, red, 0.0, 0.1, BODY, 8, 12)
	cm.blob(Vector3(0, 0.27, 0.0), Vector3(0.068, 0.05, 0.17), Basis.IDENTITY, cream, 0.0, 0.05, BODY, 5, 9)
	cm.blob(Vector3(0, 0.34, -0.17), Vector3(0.068, 0.092, 0.075), Basis.IDENTITY, white, 0.0, 0.08, BODY, 6, 9)
	for side: float in [1.0, -1.0]:
		var x := 0.055 * side
		var fp := LEG_FR if side > 0.0 else LEG_FL
		var bp := LEG_BR if side > 0.0 else LEG_BL
		cm.blob(Vector3(x * 1.1, 0.29, -0.17), Vector3(0.035, 0.06, 0.045), Basis.IDENTITY, red, 0.0, 0.05, fp, 4, 6)
		cm.tube(_p([Vector3(x, 0.29, -0.175), Vector3(x, 0.17, -0.185)]), _r([0.03, 0.019]), 6, red, 0.0, 0.05, fp)
		cm.tube(_p([Vector3(x, 0.18, -0.185), Vector3(x, 0.04, -0.19), Vector3(x, 0.015, -0.2)]), _r([0.019, 0.015, 0.015]), 6, black, 0.0, 0.03, fp)
		cm.blob(Vector3(x, 0.012, -0.21), Vector3(0.019, 0.012, 0.026), Basis.IDENTITY, black, 0.0, 0.0, fp, 3, 6)
		cm.blob(Vector3(x * 1.1, 0.3, 0.16), Vector3(0.045, 0.085, 0.07), Basis.IDENTITY, red, 0.0, 0.06, bp, 5, 7)
		cm.tube(_p([Vector3(x, 0.27, 0.17), Vector3(x, 0.16, 0.12), Vector3(x, 0.1, 0.18)]), _r([0.035, 0.022, 0.017]), 6, red, 0.0, 0.05, bp)
		cm.tube(_p([Vector3(x, 0.11, 0.18), Vector3(x, 0.02, 0.195)]), _r([0.017, 0.015]), 6, black, 0.0, 0.03, bp)
		cm.blob(Vector3(x, 0.012, 0.18), Vector3(0.018, 0.012, 0.025), Basis.IDENTITY, black, 0.0, 0.0, bp, 3, 6)
		# ears: pointed, black backs; amber eyes; white cheeks
		cm.tube(_p([Vector3(0.034 * side, 0.485, -0.315), Vector3(0.043 * side, 0.535, -0.312), Vector3(0.05 * side, 0.58, -0.31)]), _r([0.03, 0.019, 0.0]), 5, black, 0.0, 0.03, HEAD, Vector2(1.0, 0.4))
		cm.tube(_p([Vector3(0.034 * side, 0.488, -0.322), Vector3(0.046 * side, 0.55, -0.32)]), _r([0.02, 0.0]), 4, cream, 0.0, 0.0, HEAD, Vector2(1.0, 0.3))
		cm.blob(Vector3(0.03 * side, 0.468, -0.383), Vector3(0.011, 0.009, 0.008), Basis.IDENTITY, black, 0.0, 0.0, HEAD, 3, 5, 1.0)
		cm.blob(Vector3(0.036 * side, 0.428, -0.37), Vector3(0.028, 0.026, 0.038), Basis.IDENTITY, white, 0.0, 0.04, HEAD, 4, 6)
	cm.tube(_p([Vector3(0, 0.36, -0.2), Vector3(0, 0.43, -0.29)]), _r([0.058, 0.046]), 7, red, 0.0, 0.08, HEAD)
	cm.blob(Vector3(0, 0.452, -0.335), Vector3(0.06, 0.054, 0.062), Basis.IDENTITY, red, 0.0, 0.06, HEAD, 6, 9)
	cm.tube(_p([Vector3(0, 0.448, -0.375), Vector3(0, 0.432, -0.44), Vector3(0, 0.42, -0.49)]), _r([0.03, 0.017, 0.007]), 6, red, 0.0, 0.03, HEAD, Vector2(1.0, 0.8))
	cm.blob(Vector3(0, 0.418, -0.43), Vector3(0.02, 0.013, 0.045), Basis.IDENTITY, white, 0.0, 0.0, HEAD, 3, 6)
	cm.blob(Vector3(0, 0.422, -0.492), Vector3(0.011, 0.01, 0.009), Basis.IDENTITY, black, 1.0, 0.0, HEAD, 3, 5)
	# the brush: thick, slightly darker on top, a white tip
	cm.tube(_p([Vector3(0, 0.33, 0.22), Vector3(0, 0.3, 0.34), Vector3(0, 0.24, 0.47), Vector3(0, 0.2, 0.56)]), _r([0.04, 0.078, 0.072, 0.045]), 8, red.darkened(0.08), 0.0, 0.3, TAIL)
	cm.blob(Vector3(0, 0.192, 0.6), Vector3(0.042, 0.042, 0.055), Basis.IDENTITY, white, 0.0, 0.25, TAIL, 5, 7)


static func _rat(cm) -> void:
	var fur := Color(0.25, 0.21, 0.18)
	var pink := Color(0.52, 0.38, 0.36)
	cm.blob(Vector3(0, 0.045, 0.005), Vector3(0.04, 0.038, 0.08), Basis.IDENTITY, fur, 0.0, 0.15, BODY, 6, 9)
	cm.blob(Vector3(0, 0.05, -0.075), Vector3(0.027, 0.025, 0.038), _tilt(-0.25), fur, 0.0, 0.1, HEAD, 5, 8)
	cm.tube(_p([Vector3(0, 0.045, -0.1), Vector3(0, 0.038, -0.128)]), _r([0.015, 0.006]), 5, fur, 0.0, 0.05, HEAD)
	cm.blob(Vector3(0, 0.038, -0.13), Vector3(0.005, 0.004, 0.004), Basis.IDENTITY, pink, 1.0, 0.0, HEAD, 3, 4)
	cm.tube(_p([Vector3(0, 0.035, 0.08), Vector3(0, 0.022, 0.15), Vector3(0.01, 0.01, 0.21), Vector3(0.0, 0.006, 0.27)]), _r([0.008, 0.006, 0.004, 0.0015]), 4, pink, 0.5, 0.0, TAIL)
	for side: float in [1.0, -1.0]:
		cm.blob(Vector3(0.019 * side, 0.072, -0.068), Vector3(0.012, 0.012, 0.004), Basis.IDENTITY, pink, 0.0, 0.0, HEAD, 3, 6)
		cm.blob(Vector3(0.017 * side, 0.058, -0.095), Vector3(0.005, 0.005, 0.004), Basis.IDENTITY, fur, 0.0, 0.0, HEAD, 3, 4, 1.0)
		var fp := LEG_FR if side > 0.0 else LEG_FL
		var bp := LEG_BR if side > 0.0 else LEG_BL
		cm.tube(_p([Vector3(0.025 * side, 0.03, -0.045), Vector3(0.028 * side, 0.0, -0.05)]), _r([0.009, 0.005]), 4, pink, 0.0, 0.0, fp)
		cm.tube(_p([Vector3(0.028 * side, 0.035, 0.045), Vector3(0.032 * side, 0.0, 0.05)]), _r([0.012, 0.005]), 4, pink, 0.0, 0.0, bp)


## A gnarled dead branch stub for an owl's perch: grows from the origin (inside the trunk) along +X.
static func _branch(cm) -> void:
	var bark := Color(0.2, 0.16, 0.13)
	cm.tube(_p([Vector3(-0.2, -0.08, 0), Vector3(0.4, 0.0, 0.02), Vector3(0.95, 0.05, -0.03), Vector3(1.35, 0.13, 0.02), Vector3(1.75, 0.25, 0.0)]),
		_r([0.13, 0.085, 0.065, 0.045, 0.0]), 7, bark, 0.0, 0.25)
	cm.tube(_p([Vector3(1.15, 0.08, -0.02), Vector3(1.35, 0.22, -0.18), Vector3(1.45, 0.38, -0.32)]), _r([0.03, 0.018, 0.0]), 5, bark, 0.0, 0.2)
	cm.tube(_p([Vector3(0.6, 0.02, 0.02), Vector3(0.7, -0.12, 0.15), Vector3(0.75, -0.2, 0.26)]), _r([0.025, 0.012, 0.0]), 4, bark, 0.0, 0.2)


## A field mouse (the owls' prey): a small round body, big ears and eyes, a long thin tail.
static func _mouse(cm) -> void:
	var fur := Color(0.36, 0.27, 0.18)
	var belly := Color(0.55, 0.47, 0.36)
	var pink := Color(0.55, 0.42, 0.38)
	cm.blob(Vector3(0, 0.026, 0.004), Vector3(0.024, 0.022, 0.042), Basis.IDENTITY, fur, 0.0, 0.15, BODY, 6, 9)
	cm.blob(Vector3(0, 0.02, 0.0), Vector3(0.018, 0.012, 0.03), Basis.IDENTITY, belly, 0.0, 0.1, BODY, 5, 7)
	cm.blob(Vector3(0, 0.03, -0.042), Vector3(0.016, 0.015, 0.021), _tilt(-0.25), fur, 0.0, 0.1, HEAD, 5, 8)
	cm.tube(_p([Vector3(0, 0.027, -0.055), Vector3(0, 0.022, -0.07)]), _r([0.009, 0.003]), 5, fur, 0.0, 0.05, HEAD)
	cm.tube(_p([Vector3(0, 0.022, 0.042), Vector3(0, 0.012, 0.08), Vector3(0.006, 0.006, 0.115), Vector3(0.0, 0.004, 0.15)]), _r([0.004, 0.003, 0.002, 0.001]), 4, pink, 0.5, 0.0, TAIL)
	for side: float in [1.0, -1.0]:
		cm.blob(Vector3(0.012 * side, 0.047, -0.036), Vector3(0.009, 0.01, 0.003), Basis.IDENTITY, pink, 0.0, 0.0, HEAD, 3, 6)
		cm.blob(Vector3(0.01 * side, 0.036, -0.052), Vector3(0.004, 0.004, 0.003), Basis.IDENTITY, fur, 0.0, 0.0, HEAD, 3, 4, 1.0)
		var fp := LEG_FR if side > 0.0 else LEG_FL
		var bp := LEG_BR if side > 0.0 else LEG_BL
		cm.tube(_p([Vector3(0.014 * side, 0.016, -0.026), Vector3(0.016 * side, 0.0, -0.03)]), _r([0.005, 0.003]), 4, pink, 0.0, 0.0, fp)
		cm.tube(_p([Vector3(0.016 * side, 0.02, 0.026), Vector3(0.018 * side, 0.0, 0.03)]), _r([0.007, 0.003]), 4, pink, 0.0, 0.0, bp)


## r33 world: a brown hare (the heath and the road's verges): long hind legs, a lean body, tall
## black-tipped ears, a white scut. Moves like a small deer (life_beasts.gd "hare"): crouched grazing,
## sitting up to look, a long zig-zag bolt.
static func _hare(cm) -> void:
	var fur := Color(0.46, 0.34, 0.22)
	var belly := Color(0.72, 0.64, 0.52)
	var dark := Color(0.08, 0.06, 0.05)
	var white := Color(0.9, 0.88, 0.84)
	cm.blob(Vector3(0, 0.2, 0.03), Vector3(0.075, 0.085, 0.17), _tilt(0.18), fur, 0.0, 0.12, BODY, 7, 10)
	cm.blob(Vector3(0, 0.16, 0.02), Vector3(0.06, 0.045, 0.12), Basis.IDENTITY, belly, 0.0, 0.05, BODY, 5, 8)
	cm.blob(Vector3(0, 0.2, 0.12), Vector3(0.08, 0.09, 0.09), Basis.IDENTITY, fur, 0.0, 0.12, BODY, 6, 9)
	# head: a blunt muzzle, big side eyes, tall ears laid half back
	cm.tube(_p([Vector3(0, 0.22, -0.1), Vector3(0, 0.25, -0.15)]), _r([0.045, 0.04]), 6, fur, 0.0, 0.08, HEAD)
	cm.blob(Vector3(0, 0.27, -0.18), Vector3(0.042, 0.045, 0.06), _tilt(-0.3), fur, 0.0, 0.08, HEAD, 6, 9)
	cm.blob(Vector3(0, 0.25, -0.235), Vector3(0.024, 0.022, 0.022), Basis.IDENTITY, belly, 0.0, 0.0, HEAD, 4, 6)
	for side: float in [1.0, -1.0]:
		cm.blob(Vector3(0.033 * side, 0.285, -0.19), Vector3(0.011, 0.012, 0.011), Basis.IDENTITY, dark, 0.0, 0.0, HEAD, 3, 5, 1.0)
		cm.tube(_p([Vector3(0.014 * side, 0.3, -0.16), Vector3(0.024 * side, 0.38, -0.12), Vector3(0.03 * side, 0.45, -0.09)]), _r([0.016, 0.019, 0.006]), 5, fur, 0.0, 0.05, HEAD, Vector2(1.0, 0.45))
		cm.blob(Vector3(0.03 * side, 0.445, -0.09), Vector3(0.012, 0.02, 0.008), Basis.IDENTITY, dark, 0.0, 0.0, HEAD, 3, 5)
		var fp := LEG_FR if side > 0.0 else LEG_FL
		var bp := LEG_BR if side > 0.0 else LEG_BL
		# forelegs: thin, straight
		cm.tube(_p([Vector3(0.035 * side, 0.15, -0.09), Vector3(0.033 * side, 0.06, -0.11), Vector3(0.032 * side, 0.01, -0.12)]), _r([0.02, 0.012, 0.011]), 5, fur, 0.0, 0.03, fp)
		# hind legs: a big haunch, the long foot flat on the ground
		cm.blob(Vector3(0.05 * side, 0.17, 0.11), Vector3(0.035, 0.07, 0.07), Basis.IDENTITY, fur, 0.0, 0.08, bp, 5, 7)
		cm.tube(_p([Vector3(0.05 * side, 0.12, 0.13), Vector3(0.05 * side, 0.05, 0.16), Vector3(0.048 * side, 0.012, 0.08)]), _r([0.025, 0.016, 0.013]), 5, fur, 0.0, 0.03, bp)
	cm.blob(Vector3(0, 0.22, 0.2), Vector3(0.03, 0.03, 0.025), Basis.IDENTITY, white, 0.0, 0.1, TAIL, 4, 6)


## A lapwing (the heath's flock): dark glossy back and wings, white belly and cheeks, a black breast
## band, a long thin crest swept back from the crown, short bill, longish pink-grey legs.
static func _plover(cm) -> void:
	var back := Color(0.1, 0.13, 0.1)
	var white := Color(0.72, 0.72, 0.7)
	var band := Color(0.05, 0.05, 0.06)
	var leg := Color(0.45, 0.33, 0.32)
	cm.blob(Vector3(0, 0.125, 0.01), Vector3(0.05, 0.048, 0.1), _tilt(0.2), back, 0.0, 0.12, BODY, 7, 10)
	cm.blob(Vector3(0, 0.11, -0.01), Vector3(0.045, 0.04, 0.08), Basis.IDENTITY, white, 0.0, 0.1, BODY, 6, 9)
	cm.blob(Vector3(0, 0.14, -0.06), Vector3(0.042, 0.03, 0.03), Basis.IDENTITY, band, 0.0, 0.1, BODY, 5, 8)
	cm.tube(_p([Vector3(0, 0.15, -0.07), Vector3(0, 0.18, -0.09)]), _r([0.03, 0.026]), 6, white, 0.0, 0.1, HEAD)
	cm.blob(Vector3(0, 0.195, -0.1), Vector3(0.031, 0.03, 0.036), Basis.IDENTITY, white, 0.0, 0.1, HEAD, 6, 8)
	cm.blob(Vector3(0, 0.215, -0.098), Vector3(0.028, 0.014, 0.03), Basis.IDENTITY, back, 0.0, 0.1, HEAD, 5, 7)
	cm.tube(_p([Vector3(0, 0.2, -0.13), Vector3(0, 0.196, -0.152)]), _r([0.007, 0.0]), 5, band, 1.0, 0.0, HEAD)
	cm.tube(_p([Vector3(0, 0.222, -0.09), Vector3(0, 0.245, -0.07), Vector3(0, 0.258, -0.04)]), _r([0.005, 0.004, 0.0]), 3, back, 0.0, 0.0, HEAD)
	for side: float in [1.0, -1.0]:
		cm.blob(Vector3(0.022 * side, 0.205, -0.118), Vector3(0.006, 0.006, 0.005), Basis.IDENTITY, band, 0.0, 0.0, HEAD, 3, 5, 1.0)
		var part := WING_R if side > 0.0 else WING_L
		cm.blob(Vector3(0.12 * side, 0.165, 0.02), Vector3(0.1, 0.007, 0.06), Basis(Vector3.UP, side * 0.05), back, 0.0, 0.2, part, 4, 10)
		cm.blob(Vector3(0.21 * side, 0.165, 0.025), Vector3(0.05, 0.006, 0.055), Basis.IDENTITY, back.darkened(0.3), 0.0, 0.1, part, 4, 8)
		var hip := Vector3(0.02 * side, 0.09, 0.0)
		var foot := Vector3(0.022 * side, 0.003, -0.005)
		var lp := LEG_FR if side > 0.0 else LEG_FL
		cm.tube(_p([hip, Vector3(0.022 * side, 0.05, 0.01), foot]), _r([0.006, 0.004, 0.003]), 4, leg, 0.5, 0.0, lp)
		for t: Vector3 in [Vector3(0.0, 0, -0.03), Vector3(0.012 * side, 0, -0.022), Vector3(-0.003 * side, 0, 0.015)]:
			cm.tube(_p([foot, foot + t]), _r([0.003, 0.0]), 3, leg, 0.5, 0.0, lp)
	cm.blob(Vector3(0, 0.12, 0.12), Vector3(0.035, 0.008, 0.05), _tilt(-0.2), white, 0.0, 0.1, TAIL, 4, 6)



## r36 a horse (core/world/mount): built on the deer's frame at scale `s`, a heavier barrel, a long
## crested neck, a long head, a mane and a full tail; `feather` hangs hair over the hooves (garrons,
## draughts), `girth` thickens the body. The rig is the deer's (RIG horse_*): legs swing, head pivots.
static func _horse(cm, s: float, coat: Color, mane: Color, feather: float, girth: float) -> void:
	var belly := coat.lightened(0.08)
	var leg := coat.darkened(0.35)
	var hoof := Color(0.05, 0.045, 0.04)
	var v := func(x: float, y: float, z: float) -> Vector3: return Vector3(x, y, z) * s
	var g := girth
	# barrel, chest and quarters (rounder and deeper than a deer's)
	cm.blob(v.call(0, 0.98, 0.0), Vector3(0.23 * g, 0.27 * g, 0.52) * s, Basis.IDENTITY, coat, 0.0, 0.05, BODY, 9, 14)
	cm.blob(v.call(0, 1.0, -0.33), Vector3(0.22 * g, 0.29 * g, 0.24) * s, Basis.IDENTITY, coat, 0.0, 0.05, BODY, 7, 11)
	cm.blob(v.call(0, 1.03, 0.33), Vector3(0.24 * g, 0.28 * g, 0.26) * s, Basis.IDENTITY, coat, 0.0, 0.05, BODY, 7, 11)
	cm.blob(v.call(0, 0.82, 0.02), Vector3(0.16 * g, 0.1, 0.38) * s, Basis.IDENTITY, belly, 0.0, 0.04, BODY, 5, 10)
	# a saddle cloth and a plain saddle, so a horse reads as kept, not wild
	cm.blob(v.call(0, 1.22, -0.04), Vector3(0.25 * g, 0.03, 0.2) * s, Basis.IDENTITY, Color(0.24, 0.16, 0.12), 0.0, 0.02, BODY, 4, 10)
	cm.blob(v.call(0, 1.26, -0.04), Vector3(0.14, 0.05, 0.16) * s, Basis.IDENTITY, Color(0.2, 0.12, 0.07), 0.0, 0.03, BODY, 5, 10)
	# tail: a full fall from the dock
	cm.tube(_p([v.call(0, 1.16, 0.56), v.call(0, 1.02, 0.66), v.call(0, 0.74, 0.7), v.call(0, 0.5, 0.68)]), _r([0.05 * s, 0.07 * s, 0.07 * s, 0.03 * s]), 7, mane, 0.0, 0.3, TAIL, Vector2(1.0, 0.6))
	for side: float in [1.0, -1.0]:
		var x := 0.12 * side * g
		var fp := LEG_FR if side > 0.0 else LEG_FL
		var bp := LEG_BR if side > 0.0 else LEG_BL
		cm.blob(v.call(x * 1.05, 0.84, -0.38), Vector3(0.085, 0.17, 0.11) * s, Basis.IDENTITY, coat, 0.0, 0.05, fp, 6, 8)
		cm.tube(_p([v.call(x, 0.82, -0.38), v.call(x, 0.62, -0.365), v.call(x * 0.95, 0.42, -0.38)]), _r([0.07 * s, 0.05 * s, 0.038 * s]), 7, coat.darkened(0.1), 0.0, 0.05, fp)
		_lower_leg(cm, v, x * 0.95, -0.38, 0.42, leg, hoof, fp, s)
		cm.blob(v.call(x * 1.05, 0.88, 0.37), Vector3(0.09, 0.21, 0.16) * s, Basis.IDENTITY, coat, 0.0, 0.05, bp, 6, 9)
		cm.tube(_p([v.call(x, 0.78, 0.37), v.call(x, 0.6, 0.43), v.call(x * 0.95, 0.44, 0.48)]), _r([0.075 * s, 0.05 * s, 0.038 * s]), 7, coat.darkened(0.1), 0.0, 0.05, bp)
		_lower_leg(cm, v, x * 0.95, 0.475, 0.42, leg, hoof, bp, s, 0.42)
		if feather > 0.0:
			for z: float in [-0.39, 0.42]:
				var part := fp if z < 0.0 else bp
				cm.blob(v.call(x * 0.95, 0.07, z), Vector3(0.045, 0.06 * feather, 0.05) * s, Basis.IDENTITY, mane.lightened(0.1), 0.0, 0.3, part, 4, 7)
		# eye, ear
		cm.blob(v.call(0.07 * side, 1.62, -0.98), Vector3(0.024, 0.022, 0.02) * s, Basis.IDENTITY, hoof, 0.0, 0.0, HEAD, 4, 6, 1.0)
		var ear_b := Basis(Vector3.FORWARD, -side * 0.25) * Basis(Vector3.RIGHT, -0.2)
		cm.blob(v.call(0.06 * side, 1.78, -0.9), Vector3(0.025, 0.07, 0.016) * s, ear_b, coat, 0.0, 0.04, HEAD, 4, 7)
	# neck: deep at the chest, arched, crested; the mane along its top
	cm.tube(_p([v.call(0, 1.05, -0.45), v.call(0, 1.3, -0.62), v.call(0, 1.52, -0.78), v.call(0, 1.66, -0.86)]), _r([0.2 * s * g, 0.15 * s, 0.11 * s, 0.09 * s]), 10, coat, 0.0, 0.04, HEAD)
	for k in 9:
		var t := float(k) / 8.0
		var root: Vector3 = v.call(0.02, lerpf(1.24, 1.72, t), lerpf(-0.5, -0.86, t))
		cm.tube(_p([root, root + v.call(0.06, -0.16 + 0.05 * t, 0.03)]), _r([0.045 * s, 0.0]), 5, mane, 0.0, 0.3, HEAD, Vector2(1.0, 0.5))
	# head: long, the face flat, the muzzle soft
	cm.blob(v.call(0, 1.66, -0.93), Vector3(0.075, 0.09, 0.12) * s, _tilt(-0.9), coat, 0.0, 0.04, HEAD, 7, 10)
	cm.tube(_p([v.call(0, 1.62, -0.98), v.call(0, 1.48, -1.08), v.call(0, 1.36, -1.14)]), _r([0.07 * s, 0.058 * s, 0.05 * s]), 8, coat, 0.0, 0.03, HEAD, Vector2(1.0, 0.85))
	cm.blob(v.call(0, 1.33, -1.15), Vector3(0.052, 0.048, 0.055) * s, Basis.IDENTITY, coat.darkened(0.25), 0.0, 0.03, HEAD, 5, 8)
	# a bridle: brow band and reins down to the saddle
	cm.tube(_p([v.call(-0.08, 1.6, -0.95), v.call(0, 1.64, -0.99), v.call(0.08, 1.6, -0.95)]), _r([0.008 * s, 0.008 * s, 0.008 * s]), 4, Color(0.14, 0.08, 0.05), 1.0, 0.0, HEAD)
	for side2: float in [1.0, -1.0]:
		cm.tube(_p([v.call(0.05 * side2, 1.36, -1.1), v.call(0.12 * side2, 1.3, -0.6), v.call(0.1 * side2, 1.3, -0.25)]), _r([0.007 * s, 0.007 * s, 0.007 * s]), 4, Color(0.14, 0.08, 0.05), 1.0, 0.0, HEAD)
