extends Node3D
## Rift Tether's chain (r28): iron links glowing rift-teal, thrown from the staff to a hook, held
## while the foe is dragged in (or the wanderer is dragged to it), then let go. One MultiMesh for
## the links, one glow ribbon redrawn each frame, a hook head. Follows the staff and the foe live.

const THROW := 0.12            ## seconds for the chain to fly out
const LINK := 0.19             ## metres between links
const TEAL := Color(0.35, 2.2, 1.9)
const TEAL_HOT := Color(1.6, 3.2, 3.0)

static var _link_mesh: TorusMesh
static var _link_mat: StandardMaterial3D
static var _ribbon_mat: StandardMaterial3D
static var _hook_mat: StandardMaterial3D

var src: Node3D                ## the wanderer (the staff end follows its muzzle)
var dst: Node3D                ## the hooked foe (the hook end follows its chest)
var dst_point := Vector3.ZERO  ## used when there is no foe (a miss) or once it is gone
var hold := 0.4                ## seconds held after the throw
var _t := 0.0
var _mm: MultiMeshInstance3D
var _ribbon: MeshInstance3D
var _im: ImmediateMesh
var _hook: MeshInstance3D


static func throw(by: Node3D, to: Node3D, hold_for: float, point := Vector3.INF) -> Node3D:
	var host := Vfx.host()
	if host == null:
		return null
	var c := new()
	c.name = "TetherChain"
	c.src = by
	c.dst = to
	c.hold = hold_for
	c.dst_point = point if point != Vector3.INF else (_chest(to) if to else by.global_position)
	host.add_child(c)
	return c


static func _chest(e: Node3D) -> Vector3:
	var h: Variant = e.get("hp_bar_y")
	return e.global_position + Vector3.UP * (float(h) * 0.55 if h != null else 1.0)


static func _shared() -> void:
	if _link_mesh != null:
		return
	_link_mesh = TorusMesh.new()
	_link_mesh.inner_radius = 0.04
	_link_mesh.outer_radius = 0.08
	_link_mesh.rings = 8
	_link_mesh.ring_segments = 5
	_link_mat = StandardMaterial3D.new()
	_link_mat.albedo_color = Color(0.12, 0.13, 0.15)
	_link_mat.metallic = 0.8
	_link_mat.roughness = 0.35
	_link_mat.emission_enabled = true
	_link_mat.emission = Color(0.2, 1.0, 0.9)
	_link_mat.emission_energy_multiplier = 2.4
	_ribbon_mat = StandardMaterial3D.new()
	_ribbon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ribbon_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ribbon_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ribbon_mat.vertex_color_use_as_albedo = true
	_ribbon_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ribbon_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_hook_mat = ProcMesh.glow_mat(TEAL_HOT)


func _ready() -> void:
	_shared()
	top_level = true
	_mm = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _link_mesh
	mm.instance_count = 180
	mm.visible_instance_count = 0
	_mm.multimesh = mm
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mm.material_override = _link_mat
	_mm.extra_cull_margin = 30.0
	_mm.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # its links are rewritten every rendered frame
	add_child(_mm)
	_im = ImmediateMesh.new()
	_ribbon = MeshInstance3D.new()
	_ribbon.mesh = _im
	_ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ribbon.extra_cull_margin = 30.0
	add_child(_ribbon)
	_hook = MeshInstance3D.new()
	_hook.mesh = SpellFx.spear_mesh()
	_hook.material_override = _hook_mat
	_hook.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hook.top_level = true
	add_child(_hook)


func _process(delta: float) -> void:
	_t += delta
	var total := THROW + hold
	if _t > total + 0.18 or src == null or not is_instance_valid(src):
		queue_free()
		return
	var a := _muzzle()
	if dst != null and is_instance_valid(dst) and dst.is_inside_tree():
		dst_point = _chest(dst)
	var b := dst_point
	var out := clampf(_t / THROW, 0.0, 1.0)
	var fade := 1.0 - clampf((_t - total) / 0.18, 0.0, 1.0)
	var tip := a.lerp(b, out) if fade >= 1.0 else b.lerp(a, 1.0 - fade)       # snaps back on release
	var span := tip - a
	var length := span.length()
	if length < 0.05:
		_mm.multimesh.visible_instance_count = 0
		_im.clear_surfaces()
		return
	var fwd := span / length
	var up := Vector3.UP if absf(fwd.y) < 0.95 else Vector3.RIGHT
	var side := fwd.cross(up).normalized()
	var n := mini(int(length / LINK), _mm.multimesh.instance_count)
	var slack := 0.25 * (1.0 - out) + 0.06                                  # it straightens as it bites
	for i in n:
		var u := (float(i) + 0.5) / float(maxi(n, 1))
		var p := a + span * u + Vector3.DOWN * sin(u * PI) * slack * length * 0.08
		var roll := PI * 0.5 * float(i % 2)
		var bz := fwd
		var bx := side.rotated(fwd, roll)
		var by := bz.cross(bx)
		# the torus lies in its local XZ plane: its axis (Y) across the chain, so links face along it
		_mm.multimesh.set_instance_transform(i, Transform3D(Basis(bz, bx, by).scaled(Vector3.ONE * fade), p))
	_mm.multimesh.visible_instance_count = n
	_hook.global_transform = Transform3D(Basis.looking_at(fwd, up).scaled(Vector3.ONE * 0.55 * fade), tip)
	_draw_glow(a, tip, fade)


func _muzzle() -> Vector3:
	var rig: Variant = src.get("_visual")
	if rig is Object and (rig as Object).has_method("muzzle"):
		return (rig as Object).call("muzzle")
	return src.global_position + Vector3.UP * 1.5


func _draw_glow(a: Vector3, b: Vector3, fade: float) -> void:
	_im.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam else a + Vector3.UP
	var flick := 0.85 + 0.15 * sin(_t * 47.0)
	for layer in 2:
		var w := (0.32 if layer == 0 else 0.08) * fade
		var col := Color(TEAL.r, TEAL.g, TEAL.b, 0.45 * flick) if layer == 0 else Color(TEAL_HOT.r, TEAL_HOT.g, TEAL_HOT.b, 0.9 * flick)
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _ribbon_mat)
		var steps := 10
		for i in steps + 1:
			var u := float(i) / float(steps)
			var p := a.lerp(b, u)
			var s := (b - a).normalized().cross(eye - p).normalized() * w * 0.5
			var c := Color(col.r, col.g, col.b, col.a * (0.55 + 0.45 * u))
			_im.surface_set_color(c)
			_im.surface_add_vertex(p + s)
			_im.surface_set_color(c)
			_im.surface_add_vertex(p - s)
		_im.surface_end()
