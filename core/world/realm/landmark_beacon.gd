extends Node3D
## A landmark's far read and its wayfinding marker. The camera sees FarDetail.VIEW_FAR (420 m), so the
## old sky column (and its far-plane homothety) is gone. Two jobs remain:
##   - the HUD compass and the map list nodes in group "landmark_beacon" and read `anchor` and `tint`;
##   - a faint glow sprite sits on the place itself (`glow_h` metres over its ground point): a soft,
##     additive, fog-free point of light that grows with distance so it stays a small steady spark on
##     the horizon, and is gone near the asset, whose own lit parts take over. No light node; the dark
##     stays the clock. `ember` stretches the sprite tall (a boss arena's rising embers).

const NEAR_OFF := 22.0                  ## closer than this the glow is out (the asset's own light is in)
const NEAR_ON := 70.0                   ## fully in from here
const ANGLE := 0.02                   ## on-screen size, radians (about 1.1 degrees): a point, not a beacon

var anchor := Vector3.ZERO              ## the marker's world position (compass, map)
var tint := Color(1.0, 0.8, 0.5)        ## the compass diamond and the glow
var reach := 0.0                        ## minor places: the glow thins past reach x 2.2 and is gone by x 3.4; 0 = never
var strength := 0.6                     ## glow brightness (alpha), a place 0.4, a boss arena 0.6, the summit 0.8
var glow_h := 0.0                       ## the glow's height relative to `anchor` (negative: it sits on the place, under the marker)
var ember := false                      ## taller than wide, with a slow breath

var _mi: MeshInstance3D
var _mat: StandardMaterial3D
var _t := 0.0
static var _tex: ImageTexture
static var _mesh: QuadMesh


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group(&"landmark_beacon")
	top_level = true
	global_position = anchor
	if _mesh == null:
		_mesh = QuadMesh.new()
		_mesh.size = Vector2.ONE
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y if ember else BaseMaterial3D.BILLBOARD_ENABLED
	_mat.billboard_keep_scale = true
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.disable_fog = true
	_mat.albedo_texture = _spark()
	_mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.0)
	_mi = MeshInstance3D.new()
	_mi.name = "FarGlow"
	_mi.mesh = _mesh
	_mi.material_override = _mat
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_mi.position = Vector3(0.0, glow_h, 0.0)
	_mi.extra_cull_margin = 40.0
	_mi.ignore_occlusion_culling = true
	_mi.add_to_group(Groups.CULL_SKIP)       # the Realm's size ranges (FarDetail.generic_range) would end a 1 m quad at 130 m
	_mi.visible = false
	add_child(_mi)
	_t = randf() * 6.0


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p := _mi.global_position
	var d := cam.global_position.distance_to(p)
	var a := smoothstep(NEAR_OFF, NEAR_ON, d)
	if reach > 0.0:
		a *= 1.0 - smoothstep(reach * 2.2, reach * 3.4, d)
	_mi.visible = a > 0.01
	if not _mi.visible:
		return
	_t += delta
	var breath := 0.88 + 0.12 * sin(_t * 0.9) + 0.05 * sin(_t * 2.7)
	var s := d * ANGLE
	_mi.scale = Vector3(s, s * (1.7 if ember else 1.0), 1.0)
	_mat.albedo_color.a = minf(a * strength * breath, 1.0)


## A soft point: a hot centre, a long gentle skirt (made once).
static func _spark() -> ImageTexture:
	if _tex:
		return _tex
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var r := Vector2(float(x) + 0.5 - n * 0.5, float(y) + 0.5 - n * 0.5).length() / (n * 0.5)
			var a := clampf(1.0 - r, 0.0, 1.0)
			a = a * a * 0.5 + pow(a, 5.0) * 0.35
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	_tex = ImageTexture.create_from_image(img)
	return _tex
