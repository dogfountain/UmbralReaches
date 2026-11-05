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
const VERSION := 9

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
	"horse_palfrey": {"warm": 0.11, "detail": 0.14, "detail_scale": 2.5, "streak": 3.0, "roughness": 0.7, "eye_col": Color(0.5, 0.42, 0.3), "eye_energy": 0.2, "rim_amount": 0.25},
	"horse_garron": {"warm": 0.11, "detail": 0.32, "detail_scale": 3.0, "streak": 3.5, "roughness": 0.92, "eye_col": Color(0.5, 0.42, 0.3), "eye_energy": 0.2, "rim_amount": 0.3},
	"horse_draught": {"warm": 0.11, "detail": 0.16, "detail_scale": 2.0, "streak": 3.0, "roughness": 0.6, "eye_col": Color(0.5, 0.42, 0.3), "eye_energy": 0.2, "rim_amount": 0.35},
	"horse_fenpony": {"warm": 0.11, "detail": 0.4, "detail_scale": 3.5, "streak": 4.0, "roughness": 0.95, "eye_col": Color(0.5, 0.42, 0.3), "eye_energy": 0.2, "rim_amount": 0.2},
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
		"horse_palfrey": _horse(cm, 1.42, HORSES["palfrey"])
		"horse_garron": _horse(cm, 1.3, HORSES["garron"])
		"horse_draught": _horse(cm, 1.6, HORSES["draught"])
		"horse_fenpony": _horse(cm, 1.15, HORSES["fenpony"])
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




## r36 horses (core/world/mount), rebuilt in the chunky, readable style of a fantasy MMO's mounts (an
## original model): a deep chest and a rounded croup, a thick arched neck with a crest, a shaped head
## (cheeks, a long face, a soft muzzle, nostrils, tall ears), muscled legs with knees, hocks and
## fetlocks on big hooves; a mane and tail of heavy flowing locks; and full tack: saddle and blanket
## with a trim, girth, stirrups, breastplate, bridle and reins. The deer's GPU rig drives it (parts:
## BODY, HEAD for the neck and head, the four legs, TAIL).
##   coat, mane, socks (white legs: "", "hind", "all"), blaze, feather (hair over the hooves),
##   girth, blanket and trim colours, dorsal (a dun's stripe)
const HORSES := {
	"palfrey": {"coat": Color(0.4, 0.17, 0.065), "mane": Color(0.06, 0.04, 0.035), "socks": "hind", "blaze": true, "feather": 0.0,
		"girth": 1.0, "blanket": Color(0.46, 0.07, 0.06), "trim": Color(0.82, 0.62, 0.26), "dorsal": false},
	"garron": {"coat": Color(0.64, 0.62, 0.6), "mane": Color(0.86, 0.85, 0.82), "socks": "", "blaze": false, "feather": 0.7,
		"girth": 1.14, "blanket": Color(0.16, 0.24, 0.38), "trim": Color(0.75, 0.75, 0.78), "dorsal": false},
	"draught": {"coat": Color(0.085, 0.07, 0.065), "mane": Color(0.05, 0.04, 0.035), "socks": "all", "blaze": true, "feather": 1.0,
		"girth": 1.28, "blanket": Color(0.62, 0.36, 0.08), "trim": Color(0.3, 0.16, 0.06), "dorsal": false},
	"fenpony": {"coat": Color(0.72, 0.53, 0.28), "mane": Color(0.18, 0.11, 0.06), "socks": "", "blaze": false, "feather": 0.5,
		"girth": 1.2, "blanket": Color(0.2, 0.32, 0.18), "trim": Color(0.58, 0.48, 0.3), "dorsal": true},
}


static func _horse(cm, s: float, h: Dictionary) -> void:
	var coat: Color = h.coat
	var mane: Color = h.mane
	var g: float = h.girth
	var white := Color(0.88, 0.86, 0.82)
	var hoof := Color(0.11, 0.09, 0.08)
	var leather := Color(0.32, 0.17, 0.07)
	var dark_leather := Color(0.2, 0.1, 0.05)
	var metal := Color(0.78, 0.66, 0.38)
	var muzzle := coat.darkened(0.35) if coat.get_luminance() > 0.2 else coat.lightened(0.08)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(coat)
	var v := func(x: float, y: float, z: float) -> Vector3: return Vector3(x, y, z) * s
	var R := 14
	var S := 24
	# --- body: ONE lofted surface along the spine (blobs overlapped into lumps): chest, brisket,
	# shoulder, barrel, loin, a two-lobed croup, buttock; a flatter back, a rounder belly ---------
	var body_keys := [
		# z, half-width, half-height, centre y
		[-0.64, 0.06, 0.1, 0.99], [-0.6, 0.14, 0.2, 0.97], [-0.48, 0.2, 0.27, 0.95], [-0.3, 0.235, 0.29, 0.99],
		[-0.08, 0.25, 0.285, 0.98], [0.14, 0.245, 0.265, 0.99], [0.3, 0.23, 0.23, 1.03], [0.44, 0.245, 0.25, 1.02],
		[0.56, 0.2, 0.22, 1.0], [0.64, 0.11, 0.14, 1.0], [0.68, 0.03, 0.05, 1.0]]
	_loft(cm, v, body_keys, g, coat, BODY, true)
	# --- neck: a lofted column from the shoulders, arched, deep at the base, a crest on top ------
	# (it starts well inside the chest, so neck and body meet without a crease)
	var neck_pts := [v.call(0, 0.98, -0.38), v.call(0, 1.12, -0.52), v.call(0, 1.3, -0.64), v.call(0, 1.48, -0.76), v.call(0, 1.64, -0.85), v.call(0, 1.74, -0.9)]
	var neck_w := [0.22 * g, 0.18 * g, 0.14, 0.11, 0.095, 0.085]
	var neck_h := [0.3, 0.26, 0.2, 0.16, 0.13, 0.115]
	_neck(cm, neck_pts, neck_w, neck_h, s, coat, HEAD)
	if bool(h.dorsal):
		cm.tube(_p([v.call(0, 1.2, -0.3), v.call(0, 1.24, 0.0), v.call(0, 1.23, 0.3), v.call(0, 1.15, 0.52)]), _r([0.03 * s, 0.035 * s, 0.03 * s, 0.02 * s]), 8, mane.lightened(0.1), 0.0, 0.02, BODY, Vector2(1.0, 0.3))
	# --- legs: muscle, knee / hock, cannon, fetlock, pastern, a big hoof (+ feathering) ----------
	for side: float in [1.0, -1.0]:
		var x := 0.13 * side * g
		var fp := LEG_FR if side > 0.0 else LEG_FL
		var bp := LEG_BR if side > 0.0 else LEG_BL
		var sock_f := String(h.socks) == "all"
		var sock_b := String(h.socks) in ["all", "hind"]
		# fore: forearm muscle, forearm, knee, cannon
		cm.blob(v.call(x, 0.82, -0.37), Vector3(0.1 * g, 0.2, 0.115) * s, Basis.IDENTITY, coat, 0.0, 0.03, fp, 12, 18)
		cm.tube(_p([v.call(x, 0.86, -0.37), v.call(x, 0.66, -0.365), v.call(x, 0.5, -0.37)]), _r([0.095 * s * g, 0.072 * s * g, 0.052 * s * g]), 14, coat, 0.0, 0.03, fp)
		_hleg(cm, v, x, -0.37, 0.5, coat.darkened(0.05), sock_f, white, hoof, float(h.feather), mane, fp, s, g)
		# hind: gaskin, hock with its point, cannon
		cm.blob(v.call(x, 0.86, 0.42), Vector3(0.12 * g, 0.25, 0.18) * s, Basis.IDENTITY, coat, 0.0, 0.03, bp, 12, 18)
		cm.tube(_p([v.call(x, 0.78, 0.43), v.call(x, 0.62, 0.48), v.call(x, 0.5, 0.5)]), _r([0.1 * s * g, 0.074 * s * g, 0.054 * s * g]), 14, coat, 0.0, 0.03, bp)
		cm.blob(v.call(x, 0.52, 0.54), Vector3(0.03, 0.035, 0.035) * s, Basis.IDENTITY, coat, 0.0, 0.02, bp, 6, 10)
		_hleg(cm, v, x, 0.49, 0.5, coat.darkened(0.05), sock_b, white, hoof, float(h.feather), mane, bp, s, g)
	# the head a size up (this style reads by its head), scaled about its centre
	var H0 := Vector3(0, 1.62, -0.98)
	var vh := func(x: float, y: float, z: float) -> Vector3: return (H0 + (Vector3(x, y, z) - H0) * 1.2) * s
	# --- head: cranium, a long face, cheeks, a soft muzzle, nostrils, eyes, tall ears -------------
	cm.blob(vh.call(0, 1.69, -0.94), Vector3(0.085, 0.1, 0.12) * s, Basis.IDENTITY, coat, 0.0, 0.02, HEAD, 12, 18)
	cm.tube(_p([vh.call(0, 1.68, -0.97), vh.call(0, 1.52, -1.07), vh.call(0, 1.38, -1.15)]), _r([0.072 * s, 0.062 * s, 0.056 * s]), 14, coat, 0.0, 0.02, HEAD, Vector2(1.0, 0.85))
	for sx2: float in [-1.0, 1.0]:
		cm.blob(vh.call(sx2 * 0.05, 1.6, -0.94), Vector3(0.045, 0.075, 0.075) * s, Basis.IDENTITY, coat, 0.0, 0.02, HEAD, 8, 12)
		cm.blob(vh.call(sx2 * 0.03, 1.36, -1.215), Vector3(0.014, 0.018, 0.01) * s, Basis.IDENTITY, Color(0.04, 0.03, 0.03), 0.0, 0.0, HEAD, 5, 8)
		cm.blob(vh.call(sx2 * 0.067, 1.64, -1.0), Vector3(0.02, 0.019, 0.016) * s, Basis.IDENTITY, hoof, 0.0, 0.0, HEAD, 6, 8, 1.0)
		var eb := Basis(Vector3.FORWARD, -sx2 * 0.18) * Basis(Vector3.RIGHT, -0.15)
		cm.blob(vh.call(sx2 * 0.05, 1.83, -0.9), Vector3(0.024, 0.08, 0.032) * s, eb, coat, 0.0, 0.02, HEAD, 8, 10)
		cm.blob(vh.call(sx2 * 0.05, 1.83, -0.912), Vector3(0.014, 0.062, 0.018) * s, eb, coat.darkened(0.4), 0.0, 0.0, HEAD, 6, 8)
	cm.blob(vh.call(0, 1.35, -1.17), Vector3(0.064, 0.058, 0.07) * s, Basis.IDENTITY, muzzle, 0.0, 0.02, HEAD, 10, 14)
	if bool(h.blaze):
		cm.tube(_p([vh.call(0, 1.73, -1.04), vh.call(0, 1.56, -1.105), vh.call(0, 1.4, -1.205)]), _r([0.02 * s, 0.024 * s, 0.03 * s]), 10, white, 0.0, 0.0, HEAD, Vector2(1.0, 0.25))
	# --- mane: a heavy mass falling to one side, from poll to withers: a curtain of flat, wide,
	# overlapping locks laid along the neck's side (two layers, the outer longer and wavier) -------
	var ncrest := func(t: float) -> Vector3:
		# the top of the lofted neck at t (0 poll .. 1 withers): its centre line raised by its own
		# half-height (scaled), so every lock roots on the crest, not inside the neck
		var f := (1.0 - t) * float(neck_pts.size() - 1)
		var i := mini(int(f), neck_pts.size() - 2)
		var u := f - float(i)
		var c: Vector3 = (neck_pts[i] as Vector3).lerp(neck_pts[i + 1], u)
		var hh := lerpf(float(neck_h[i]), float(neck_h[i + 1]), u) * s * 1.08
		return c + Vector3.UP * hh
	var nwidth := func(t: float) -> float:
		var f := (1.0 - t) * float(neck_pts.size() - 1)
		var i := mini(int(f), neck_pts.size() - 2)
		return lerpf(float(neck_w[i]), float(neck_w[i + 1]), f - float(i)) * s
	for layer in 2:
		var n := 44 if layer == 0 else 36
		for k in n:
			var t := (float(k) + rng.randf_range(-0.3, 0.3)) / float(n - 1)
			var tt := clampf(t, 0.0, 1.0)
			var root: Vector3 = ncrest.call(tt)
			var hw: float = nwidth.call(tt)
			var ln := rng.randf_range(0.2, 0.3) * (1.0 - 0.3 * t) * (1.0 + 0.25 * float(layer))
			var off := (0.012 + 0.012 * float(layer)) * s
			var wave := rng.randf_range(-0.025, 0.025) * s
			# over the crest and down the neck's side, outside its surface all the way
			var pts := _p([root + Vector3(-0.01 * s, 0.0, 0.0), root + Vector3(hw * 0.6 + off, -0.02 * s, 0.01 * s),
				root + Vector3(hw * 1.08 + off + wave, -ln * 0.5 * s, 0.025 * s), root + Vector3(hw * 1.14 + off + wave * 1.5, -ln * s, 0.05 * s)])
			cm.tube(pts, _r([0.05 * s, 0.065 * s, 0.05 * s, 0.01 * s]), 8, mane.lightened(rng.randf_range(-0.06, 0.06) + 0.04 * float(layer)), 0.0, 0.05, HEAD, Vector2(1.0, 0.32))
	for k2 in 6:
		var a := (float(k2) - 2.5) * 0.02
		var fr: Vector3 = vh.call(a, 1.8, -0.95)
		cm.tube(_p([fr, fr + v.call(a * 2.0, 0.0, -0.05) * 1.2, fr + v.call(a * 3.0, -0.12, -0.08) * 1.2]), _r([0.02 * s, 0.016 * s, 0.003 * s]), 6, mane.lightened(rng.randf_range(-0.05, 0.08)), 0.0, 0.05, HEAD, Vector2(1.0, 0.5))
	# --- tail: a dock carried out from the croup, then a full fall of locks fanned round it --------
	var d0: Vector3 = v.call(0, 1.14, 0.6)
	var d1: Vector3 = v.call(0, 1.06, 0.72)
	cm.tube(_p([d0, d1]), _r([0.055 * s, 0.045 * s]), 10, coat, 0.0, 0.02, TAIL)
	for k3 in 34:
		var ang := rng.randf() * TAU
		var rad := sqrt(rng.randf()) * 0.06
		var ox := cos(ang) * rad
		var oz := sin(ang) * rad * 0.7
		var ln2 := rng.randf_range(0.55, 0.78)
		var r0: Vector3 = d1 + v.call(ox * 0.4, 0.0, oz * 0.4)
		var pts2 := _p([r0, r0 + v.call(ox * 0.8, -0.08, 0.06 + oz), r0 + v.call(ox * 1.3, -ln2 * 0.5, 0.08 + oz * 1.3), r0 + v.call(ox * 1.6, -ln2, 0.04 + oz * 1.5)])
		cm.tube(pts2, _r([0.04 * s, 0.045 * s, 0.035 * s, 0.006 * s]), 7, mane.lightened(rng.randf_range(-0.06, 0.08)), 0.0, 0.06, TAIL, Vector2(1.0, 0.7))
	# --- tack ------------------------------------------------------------------------------------
	# the blanket: a cloth laid over the back and hanging down both flanks, its trim showing at the
	# edge (two sheets on the barrel's section, the trim a little bigger and under)
	_blanket(cm, v, g, h.trim, 1.035, 0.3, 1.62, BODY)
	_blanket(cm, v, g, h.blanket, 1.05, 0.27, 1.52, BODY)
	cm.blob(v.call(0, 1.27, -0.04), Vector3(0.15, 0.045, 0.18) * s, Basis.IDENTITY, leather, 0.0, 0.02, BODY, 8, 16)
	# an arched pommel in front, a curved cantle behind (arcs over the seat, not knobs)
	for arc: Array in [[-0.2, 0.08, 0.06, 0.03], [0.14, 0.12, 0.075, 0.032]]:
		var ap := PackedVector3Array()
		var ar := PackedFloat32Array()
		for i in 9:
			var a6 := PI * float(i) / 8.0
			ap.append(v.call(cos(a6) * float(arc[1]), 1.27 + sin(a6) * float(arc[2]), float(arc[0])))
			ar.append(float(arc[3]) * s)
		cm.tube(ap, ar, 8, leather.darkened(0.12), 0.0, 0.0, BODY, Vector2(1.0, 0.55))
	for sx3: float in [-1.0, 1.0]:
		# the blanket hangs down the flank with a trim along its edge; a leather flap over it
		var fb := Basis(Vector3.FORWARD, sx3 * 0.35)
		cm.blob(v.call(sx3 * 0.255 * g, 1.13, -0.04), Vector3(0.012, 0.085, 0.09) * s, fb, leather, 0.0, 0.02, BODY, 6, 12)
		# stirrup leather and an iron (horn-flagged so it shines a little)
		var sa: Vector3 = v.call(sx3 * 0.26 * g, 1.2, -0.06)
		var sb: Vector3 = v.call(sx3 * 0.3 * g, 0.92, -0.06)     # where the rider's foot rests (horse.gd / the ride IK)
		cm.tube(_p([sa, sb]), _r([0.012 * s, 0.012 * s]), 5, dark_leather, 0.0, 0.0, BODY, Vector2(1.0, 0.35))
		var ring := PackedVector3Array()
		for i in 9:
			var a2 := PI * float(i) / 8.0
			ring.append(sb + v.call(0, -sin(a2) * 0.05, cos(a2) * 0.045))
		cm.tube(ring, _r([0.008 * s, 0.008 * s, 0.008 * s, 0.008 * s, 0.008 * s, 0.008 * s, 0.008 * s, 0.008 * s, 0.008 * s]), 5, metal, 1.0, 0.0, BODY)
	# girth round the barrel, and a breastplate across the chest to the saddle
	var gpts := PackedVector3Array()
	var grr := PackedFloat32Array()
	for i in 17:
		var a3 := PI * float(i) / 16.0
		gpts.append(v.call(cos(a3) * 0.255 * g, 1.0 - sin(a3) * 0.3 * g, -0.16))
		grr.append(0.02 * s)
	cm.tube(gpts, grr, 5, dark_leather, 0.0, 0.0, BODY, Vector2(1.0, 0.3))
	var bpts := PackedVector3Array()
	var brr := PackedFloat32Array()
	for i in 13:
		var a4 := PI * float(i) / 12.0
		bpts.append(v.call(cos(a4) * 0.215 * g, 1.08 - sin(a4) * 0.12, -0.5 - sin(a4) * 0.08))
		brr.append(0.017 * s)
	cm.tube(bpts, brr, 5, leather, 0.0, 0.0, BODY, Vector2(1.0, 0.35))
	cm.blob(v.call(0, 0.96, -0.6), Vector3(0.04, 0.04, 0.012) * s, Basis.IDENTITY, metal, 1.0, 0.0, BODY, 6, 10)
	# bridle: browband, noseband, cheek pieces; reins back to the pommel
	cm.tube(_p([vh.call(-0.085, 1.74, -0.93), vh.call(0, 1.77, -0.99), vh.call(0.085, 1.74, -0.93)]), _r([0.009 * s, 0.009 * s, 0.009 * s]), 5, dark_leather, 0.0, 0.0, HEAD)
	var nb := PackedVector3Array()
	for i in 13:
		var a5 := TAU * float(i) / 12.0
		nb.append(vh.call(sin(a5) * 0.07, 1.43, -1.13 - cos(a5) * 0.07))
	cm.tube(nb, _r([0.009 * s, 0.009 * s, 0.009 * s, 0.009 * s, 0.009 * s, 0.009 * s, 0.009 * s, 0.009 * s, 0.009 * s, 0.009 * s, 0.009 * s, 0.009 * s, 0.009 * s]), 5, dark_leather, 0.0, 0.0, HEAD)
	for sx4: float in [-1.0, 1.0]:
		cm.tube(_p([vh.call(sx4 * 0.085, 1.74, -0.93), vh.call(sx4 * 0.075, 1.58, -1.02), vh.call(sx4 * 0.07, 1.43, -1.13)]), _r([0.009 * s, 0.009 * s, 0.009 * s]), 5, dark_leather, 0.0, 0.0, HEAD)
		cm.blob(vh.call(sx4 * 0.075, 1.38, -1.16), Vector3(0.015, 0.015, 0.006) * s, Basis.IDENTITY, metal, 1.0, 0.0, HEAD, 5, 8)
		cm.tube(_p([vh.call(sx4 * 0.075, 1.38, -1.16), v.call(sx4 * 0.14, 1.3, -0.8), v.call(sx4 * 0.11, 1.32, -0.24)]), _r([0.008 * s, 0.008 * s, 0.008 * s]), 5, dark_leather, 0.0, 0.0, BODY)


## A horse's lower leg from the knee or hock at (x, top, z): joint, cannon, fetlock, pastern, a big
## hoof (horn-flagged), white socks, feathering spilling over the hoof.
static func _hleg(cm, v: Callable, x: float, z: float, top: float, coat: Color, sock: bool, white: Color, hoof: Color, feather: float, mane: Color, part: float, s: float, g: float) -> void:
	var lc := white if sock else coat
	cm.blob(v.call(x, top - 0.02, z), Vector3(0.05 * g, 0.055, 0.055) * s, Basis.IDENTITY, coat, 0.0, 0.02, part, 8, 12)
	cm.tube(_p([v.call(x, top - 0.04, z), v.call(x, 0.3, z + 0.01), v.call(x, 0.17, z + 0.015)]), _r([0.04 * s * g, 0.036 * s * g, 0.036 * s * g]), 10, coat if not sock else coat.lerp(white, 0.4), 0.0, 0.02, part)
	cm.blob(v.call(x, 0.15, z + 0.02), Vector3(0.05 * g, 0.05, 0.052) * s, Basis.IDENTITY, lc, 0.0, 0.02, part, 8, 12)
	cm.tube(_p([v.call(x, 0.13, z + 0.01), v.call(x, 0.09, z - 0.015)]), _r([0.037 * s * g, 0.038 * s * g]), 10, lc, 0.0, 0.02, part)
	# the hoof: wide, a slanted wall, a dark coronet band
	cm.tube(_p([v.call(x, 0.075, z - 0.02), v.call(x, 0.0, z - 0.035)]), _r([0.05 * s * g, 0.066 * s * g]), 14, hoof, 1.0, 0.0, part)
	cm.tube(_p([v.call(x, 0.085, z - 0.018), v.call(x, 0.068, z - 0.022)]), _r([0.047 * s * g, 0.054 * s * g]), 14, hoof.lightened(0.15), 1.0, 0.0, part)
	if feather > 0.0:
		var fc := white if sock else mane.lightened(0.1)
		for k in 10:
			var a := TAU * float(k) / 10.0
			var r0: Vector3 = v.call(x + cos(a) * 0.035 * g, 0.16, z + sin(a) * 0.035 * g)
			cm.tube(_p([r0, r0 + v.call(cos(a) * 0.03, -0.07, sin(a) * 0.03), r0 + v.call(cos(a) * 0.045, -0.13 * feather, sin(a) * 0.045)]),
				_r([0.018 * s, 0.014 * s, 0.003 * s]), 6, fc, 0.0, 0.06, part, Vector2(1.0, 0.5))


## A lofted trunk along -z..+z: `keys` [z, half-width, half-height, centre y] (deer units), smooth
## cross-sections (flat-topped, round-bellied), one continuous surface with capped ends.
static func _loft(cm, v: Callable, keys: Array, g: float, col: Color, part: float, croup := false) -> void:
	var rows := 40
	var segs := 36
	var z0: float = keys[0][0]
	var z1: float = keys[keys.size() - 1][0]
	var grid: Array = []
	for r in rows + 1:
		var z := lerpf(z0, z1, float(r) / float(rows))
		var k := 0
		while k < keys.size() - 2 and float(keys[k + 1][0]) < z:
			k += 1
		var a: Array = keys[k]
		var b: Array = keys[k + 1]
		var t := smoothstep(0.0, 1.0, clampf((z - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1e-4), 0.0, 1.0))
		var hw := lerpf(float(a[1]), float(b[1]), t) * g
		var hh := lerpf(float(a[2]), float(b[2]), t)
		var cy := lerpf(float(a[3]), float(b[3]), t)
		var ring: Array = []
		for c in segs + 1:
			var th := TAU * float(c) / float(segs)
			var sx := sin(th)
			var cyy := cos(th)                       # +1 top, -1 belly
			var w := hw * (1.0 - 0.08 * maxf(cyy, 0.0))        # a flatter back
			var y := cy + hh * cyy * (1.0 + 0.06 * minf(cyy, 0.0))
			if croup and z > 0.36 and z < 0.62 and cyy > 0.6:
				y -= 0.02 * exp(-pow(sx / 0.18, 2.0)) * smoothstep(0.36, 0.44, z) * (1.0 - smoothstep(0.56, 0.62, z))   # the croup's two lobes
			ring.append(v.call(w * sx, y, z))
		grid.append(ring)
	var idx: Array = []
	for r in rows + 1:
		var irow: Array = []
		for c in segs + 1:
			var p: Vector3 = grid[r][c]
			var pr: Vector3 = grid[mini(r + 1, rows)][c] - grid[maxi(r - 1, 0)][c]
			var pc: Vector3 = grid[r][(c + 1) % segs] - grid[r][(c - 1 + segs) % segs]
			var n := pc.cross(pr).normalized()
			var centre := Vector3(0, p.y, p.z)
			if n.dot(p - Vector3(0, (grid[r][0] as Vector3).y * 0.5 + (grid[r][segs / 2] as Vector3).y * 0.5, p.z)) < 0.0:
				n = -n
			irow.append(cm._vert(p, n, Vector2(float(c) / float(segs) * 2.0, float(r) / float(rows) * 1.6), col, 0.0, part, 0.0))
		idx.append(irow)
	for r in rows:
		for c in segs:
			cm._tri(idx[r][c], idx[r + 1][c], idx[r][c + 1])
			cm._tri(idx[r][c + 1], idx[r + 1][c], idx[r + 1][c + 1])


## The neck: a lofted column along `pts` with elliptical sections `w` x `h` (deer units), the long
## axis vertical (deep at the base, narrowing to the throat), and a crest along its top.
static func _neck(cm, pts: Array, w: Array, h: Array, s: float, col: Color, part: float) -> void:
	var segs := 28
	var rows := (pts.size() - 1) * 6
	var idx: Array = []
	var P: Array = []
	for r in rows + 1:
		var f := float(r) / float(rows) * float(pts.size() - 1)
		var i := mini(int(f), pts.size() - 2)
		var t := f - float(i)
		var c: Vector3 = (pts[i] as Vector3).lerp(pts[i + 1], t)
		var tan: Vector3 = ((pts[i + 1] as Vector3) - (pts[i] as Vector3)).normalized()
		var side := Vector3.RIGHT
		var up := side.cross(tan).normalized() * -1.0
		if up.y < 0.0:
			up = -up
		var hw := lerpf(float(w[i]), float(w[i + 1]), t) * s
		var hh := lerpf(float(h[i]), float(h[i + 1]), t) * s
		var ring: Array = []
		for k in segs + 1:
			var th := TAU * float(k) / float(segs)
			var crest := 1.0 + 0.12 * maxf(cos(th), 0.0) * sin(PI * clampf(f / float(pts.size() - 1), 0.0, 1.0))
			ring.append(c + side * sin(th) * hw + up * cos(th) * hh * crest)
		P.append(ring)
	for r in rows + 1:
		var irow: Array = []
		for k in segs + 1:
			var p: Vector3 = P[r][k]
			var pr: Vector3 = P[mini(r + 1, rows)][k] - P[maxi(r - 1, 0)][k]
			var pk: Vector3 = P[r][(k + 1) % segs] - P[r][(k - 1 + segs) % segs]
			var n := pk.cross(pr).normalized()
			var mid: Vector3 = ((P[r][0] as Vector3) + (P[r][segs / 2] as Vector3)) * 0.5
			if n.dot(p - mid) < 0.0:
				n = -n
			irow.append(cm._vert(p, n, Vector2(float(k) / float(segs) * 1.5, float(r) / float(rows)), col, 0.0, part, 0.0))
		idx.append(irow)
	for r in rows:
		for k in segs:
			cm._tri(idx[r][k], idx[r + 1][k], idx[r][k + 1])
			cm._tri(idx[r][k + 1], idx[r + 1][k], idx[r + 1][k + 1])



## A cloth laid over the back: a sheet on the barrel's section (half-width 0.25 g, half-height 0.285,
## centre y 0.98, deer units), from `th_max` radians down one flank over the top to the other, `zlen`
## long (centred at z -0.04), lifted `lift` times off the body.
static func _blanket(cm, v: Callable, g: float, col: Color, lift: float, zlen: float, th_max: float, part: float) -> void:
	var cols := 14
	var rows := 22
	var idx: Array = []
	for r in rows + 1:
		var th := lerpf(-th_max, th_max, float(r) / float(rows))
		var irow: Array = []
		for c in cols + 1:
			var z := -0.04 + lerpf(-zlen, zlen, float(c) / float(cols))
			var hang := smoothstep(0.9, th_max, absf(th))          # the hem falls a little straighter
			var x := sin(th) * 0.25 * g * lift
			var y := 0.98 + cos(th) * 0.285 * lift - hang * 0.02
			var p: Vector3 = v.call(x, y, z)
			var n := Vector3(sin(th), cos(th), 0.0).normalized()
			irow.append(cm._vert(p, n, Vector2(float(c) / float(cols), float(r) / float(rows)), col, 0.0, part, 0.0))
		idx.append(irow)
	for r in rows:
		for c in cols:
			cm._tri(idx[r][c], idx[r + 1][c], idx[r][c + 1])
			cm._tri(idx[r][c + 1], idx[r + 1][c], idx[r + 1][c + 1])
