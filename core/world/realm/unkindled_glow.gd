extends Node3D
## A cold coal glint over an UNLIT checkpoint brazier (r30 wayfinding): the unlit fire's own 3.4 m
## ember light is invisible past ~10 m at night, so a new player could not find the Shrine, the
## Landing, Threshold or the meadow fire (StairFoot) by eye. A small pale, unshaded flame tongue over the bowl,
## readable at 40 m+ by contrast (dim: under the glow threshold, no bloom), and no light of its own.
## Hidden once the fire is kindled (the parent Brazier's `lit`), polled twice a second.

const HEIGHT := 1.05            ## above the brazier's origin (the bowl's rim)

var _t := 0.0
var _poll := 0.0
var _mi: MeshInstance3D
var _mat: StandardMaterial3D
static var _mesh: QuadMesh


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # its glow is scaled every rendered frame
	name = "UnkindledGlow"
	if _mesh == null:
		_mesh = QuadMesh.new()
		_mesh.size = Vector2(0.34, 0.62)
		_mesh.center_offset = Vector3(0, 0.31, 0)
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.albedo_texture = _tongue()
	_mat.albedo_color = Color(0.55, 0.72, 1.0, 0.85)
	_mat.disable_fog = true
	_mi = MeshInstance3D.new()
	_mi.mesh = _mesh
	_mi.material_override = _mat
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.position = Vector3(0, HEIGHT, 0)
	add_child(_mi)
	_t = randf() * 6.0
	_sync()


func _process(delta: float) -> void:
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.5
		_sync()
	if not visible:
		# hidden (its fire burns): no script call a frame until the next look, an engine timer wakes it
		set_process(false)
		get_tree().create_timer(_poll, false).timeout.connect(_wake)
		return
	_t += delta
	var k := 0.8 + 0.2 * sin(_t * 1.7) + 0.08 * sin(_t * 5.3)
	_mi.scale = Vector3(1.0, 0.85 + 0.25 * k, 1.0)
	_mat.albedo_color.a = 0.6 + 0.3 * k


func _wake() -> void:
	_poll = 0.0
	set_process(true)


func _sync() -> void:
	var b := get_parent()
	visible = b != null and not bool(b.get("lit"))


## A soft flame-tongue alpha mask (made once): bright at the root, tapering to a point.
static var _tex: ImageTexture
static func _tongue() -> ImageTexture:
	if _tex:
		return _tex
	var w := 32
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var v := 1.0 - float(y) / float(h - 1)          # 1 at the tip (top row), 0 at the root (bottom row)
		var half := lerpf(0.42, 0.02, pow(v, 0.8))
		for x in w:
			var u := absf(float(x) / float(w - 1) - 0.5)
			var a := clampf(1.0 - u / maxf(half, 0.001), 0.0, 1.0)
			a = a * a * (1.0 - v * 0.65) * smoothstep(0.0, 0.12, v + 0.02)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_tex = ImageTexture.create_from_image(img)
	return _tex
