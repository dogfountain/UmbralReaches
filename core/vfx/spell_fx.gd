class_name SpellFx
extends RefCounted
## Signature effects for the big skills, layered from the shaders in world/vfx/:
##   Umbral Nova   circular rift disc (cracks + held radius edge), expanding dome, shards, wisps
##   Ember Lance   fire disc + flame column + blast dome + embers/smoke; aim circle while charging
##   Rift Step     tears at both ends of a teleport, implosion in, burst out, a seam between
## Every AoE is drawn on a round, clipped disc whose radius IS the gameplay radius.

const DISC := preload("res://world/vfx/aoe_disc.gdshader")
const SHELL := preload("res://world/vfx/shell.gdshader")
const COLUMN := preload("res://world/vfx/flame_column.gdshader")
const TARGET := preload("res://world/vfx/target_ring.gdshader")
const TEAR := preload("res://world/vfx/rift_tear.gdshader")

const VIOLET := Color(1.3, 0.55, 3.0)
const VIOLET_HOT := Color(2.4, 1.8, 3.4)
const EMBER := Color(2.6, 0.85, 0.25)
const EMBER_HOT := Color(3.0, 2.2, 1.1)

static var _plane: PlaneMesh
static var _sphere: SphereMesh
static var _cyl: CylinderMesh
static var _quad: QuadMesh
static var _mats := {}
static var _spear: ArrayMesh


static func _mat(key: String, shader: Shader, params: Dictionary) -> ShaderMaterial:
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = shader
	for k in params:
		m.set_shader_parameter(k, params[k])
	_mats[key] = m
	return m


static func _meshes() -> void:
	if _plane != null:
		return
	_plane = PlaneMesh.new()
	_plane.size = Vector2(2.0, 2.0)
	_sphere = SphereMesh.new()
	_sphere.radius = 1.0
	_sphere.height = 2.0
	_sphere.radial_segments = 32
	_sphere.rings = 16
	_cyl = CylinderMesh.new()
	_cyl.top_radius = 0.7
	_cyl.bottom_radius = 1.0
	_cyl.height = 1.0
	_cyl.radial_segments = 24
	_cyl.cap_top = false
	_cyl.cap_bottom = false
	_quad = QuadMesh.new()
	_quad.size = Vector2(1.0, 2.0)


static func _spawn(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var h := Vfx.host()
	if h == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 4.0
	h.add_child(mi)
	return mi


static func _drive(mi: MeshInstance3D, param: StringName, time: float, from := 0.0, to := 1.0) -> Tween:
	var tw := mi.create_tween()
	tw.tween_method(func(v: float) -> void: mi.set_instance_shader_parameter(param, v), from, to, time)
	tw.tween_callback(mi.queue_free)
	return tw


static func _basis_up(up: Vector3) -> Basis:
	if absf(up.dot(Vector3.UP)) > 0.999:
		return Basis.IDENTITY if up.y > 0.0 else Basis(Vector3.RIGHT, PI)
	var x := up.cross(Vector3.UP).normalized()
	return Basis(x, up, x.cross(up)).orthonormalized()


## Round AoE disc of exactly `radius` metres, facing `up`.
static func disc(at: Vector3, radius: float, style: int, col: Color, hot: Color, life: float, up := Vector3.UP) -> void:
	_meshes()
	var mi := _spawn(_plane, _mat("disc%d%s" % [style, col], DISC, {"style": style, "color": col, "hot": hot}))
	if mi == null:
		return
	var b := _basis_up(up)
	mi.global_transform = Transform3D(Basis(b.x * radius, b.y, b.z * radius), at + up * 0.05)
	_drive(mi, &"progress", life)


static func shell(at: Vector3, r0: float, r1: float, col: Color, life: float) -> void:
	_meshes()
	var mi := _spawn(_sphere, _mat("shell%s" % col, SHELL, {"color": col}))
	if mi == null:
		return
	mi.global_position = at
	mi.scale = Vector3.ONE * r0
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * r1, life).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: mi.set_instance_shader_parameter(&"progress", v), 0.0, 1.0, life)
	tw.chain().tween_callback(mi.queue_free)


static func column(at: Vector3, radius: float, height: float, life: float) -> void:
	_meshes()
	var mi := _spawn(_cyl, _mat("column", COLUMN, {}))
	if mi == null:
		return
	mi.global_position = at + Vector3.UP * height * 0.5
	mi.scale = Vector3(radius, height, radius)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius * 1.35, height * 1.25, radius * 1.35), life).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: mi.set_instance_shader_parameter(&"progress", v), 0.0, 1.0, life)
	tw.chain().tween_callback(mi.queue_free)


static func tear(at: Vector3, height: float, life: float) -> void:
	_meshes()
	var mi := _spawn(_quad, _mat("tear", TEAR, {}))
	if mi == null:
		return
	mi.global_position = at + Vector3.UP * height * 0.5
	mi.scale = Vector3(height * 0.7, height * 0.5, 1.0)
	var tw := mi.create_tween()
	tw.tween_method(func(v: float) -> void: mi.set_instance_shader_parameter(&"open", v), 0.0, 1.0, life * 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: mi.set_instance_shader_parameter(&"open", v), 1.0, 0.0, life * 0.75).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


## Persistent aim circle (owner positions it, scales it to the radius, feeds `charge`).
static func target_ring() -> MeshInstance3D:
	_meshes()
	var mi := MeshInstance3D.new()
	mi.mesh = _plane
	mi.material_override = _mat("target", TARGET, {})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	mi.visible = false
	return mi


static func place_ring(mi: MeshInstance3D, at: Vector3, up: Vector3, radius: float, charge: float) -> void:
	var b := _basis_up(up)
	mi.global_transform = Transform3D(Basis(b.x * radius, b.y, b.z * radius), at + up * 0.06)
	mi.set_instance_shader_parameter(&"charge", charge)


## Long four-sided spearhead for the Lance (points down -Z, like the bolt basis).
static func spear_mesh() -> ArrayMesh:
	if _spear != null:
		return _spear
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tip := Vector3(0, 0, -0.62)
	var tail := Vector3(0, 0, 0.42)
	var ring: Array[Vector3] = [Vector3(0.07, 0, -0.1), Vector3(0, 0.07, -0.1), Vector3(-0.07, 0, -0.1), Vector3(0, -0.07, -0.1)]
	for i in 4:
		var a := ring[i]
		var b := ring[(i + 1) % 4]
		for tri in [[tip, b, a], [tail, a, b]]:
			var n: Vector3 = ((tri[1] as Vector3) - (tri[0] as Vector3)).cross((tri[2] as Vector3) - (tri[0] as Vector3)).normalized() * -1.0
			for v in tri:
				st.set_normal(n)
				st.add_vertex(v)
	_spear = st.commit()
	return _spear


# --- the three signatures ------------------------------------------------------------------

static func nova(feet: Vector3, radius: float) -> void:
	var chest := feet + Vector3.UP * 0.9
	disc(feet, radius, 0, VIOLET, VIOLET_HOT, 1.1)
	shell(chest, 0.4, radius, Color(1.0, 0.4, 2.6), 0.42)
	Vfx.burst(feet + Vector3.UP * 0.15, VIOLET, {"count": 70, "life": 0.5, "speed": Vector2(7.0, 12.0), "size": 0.05, "gravity": -1.0, "damping": 6.0, "trail": 0.1, "dir": Vector3.UP, "spread": 85.0, "ring": 0.5})
	Vfx.burst(chest, Color(0.03, 0.0, 0.06, 0.85), {"count": 36, "life": 0.7, "speed": Vector2(4.0, 8.0), "size": 0.3, "gravity": 0.0, "damping": 5.0, "additive": false, "dir": Vector3.UP, "spread": 95.0})
	Vfx.burst(feet, Color(1.0, 0.45, 2.4), {"count": 40, "life": 1.4, "speed": Vector2(0.3, 1.2), "size": 0.06, "gravity": 1.6, "ring": radius * 0.85, "turbulence": true})
	Vfx.light(chest, Color(0.7, 0.4, 1.0), 7.0, radius * 2.4, 0.5)


static func lance_impact(at: Vector3, normal: Vector3, radius: float, pierce: bool) -> void:
	var hot := Color(3.2, 2.6, 1.8) if pierce else EMBER_HOT
	disc(at, radius, 1, EMBER, hot, 1.6, normal)
	column(at, radius * 0.45, radius * 1.6, 0.7)
	shell(at, 0.3, radius, Color(2.4, 0.8, 0.3), 0.35)
	Vfx.burst(at, hot, {"count": 60, "life": 0.9, "speed": Vector2(4.0, 10.0), "size": 0.05, "gravity": -10.0, "trail": 0.1, "dir": normal, "spread": 70.0})
	Vfx.burst(at, Color(1.8, 0.5, 0.15), {"count": 40, "life": 1.8, "speed": Vector2(0.4, 2.2), "size": 0.07, "gravity": 1.8, "radius": radius * 0.6, "turbulence": true})
	Vfx.burst(at + normal * 0.4, Color(0.05, 0.03, 0.04, 0.8), {"count": 22, "life": 1.6, "speed": Vector2(0.6, 1.8), "size": 0.7, "gravity": 1.0, "radius": radius * 0.4, "additive": false, "turbulence": true})
	Vfx.light(at + normal * 0.6, Color(1.0, 0.5, 0.2), 8.0, radius * 3.2, 0.55)


## Bone Reliquary · Implosion: a dome collapsing inward onto the caster, motes sucked in.
static func implosion(feet: Vector3, radius: float) -> void:
	var chest := feet + Vector3.UP * 0.9
	shell(chest, radius, 0.3, Color(1.0, 0.4, 2.6), 0.35)
	disc(feet, radius, 0, VIOLET * 0.8, VIOLET_HOT, 0.5)
	Vfx.burst(chest, VIOLET_HOT, {"count": 70, "life": 0.35, "speed": Vector2(0.0, 0.4), "size": 0.05, "radius": radius * 0.9, "radial": -radius * 2.6, "gravity": 0.0, "trail": 0.1})
	Vfx.light(chest, Color(0.7, 0.4, 1.0), 4.0, radius * 1.6, 0.35)


static func rift_out(at: Vector3) -> void:
	tear(at, 2.6, 0.5)
	Vfx.burst(at + Vector3.UP, Color(1.4, 0.6, 3.0), {"count": 40, "life": 0.35, "speed": Vector2(0.0, 0.5), "size": 0.05, "radius": 1.3, "radial": -22.0, "gravity": 0.0, "trail": 0.08})
	Vfx.burst(at + Vector3.UP, Color(0.02, 0.0, 0.05, 0.85), {"count": 16, "life": 0.5, "speed": Vector2(0.2, 0.8), "size": 0.5, "radius": 0.5, "gravity": 0.4, "additive": false})


static func rift_in(at: Vector3) -> void:
	tear(at, 2.6, 0.55)
	shell(at + Vector3.UP, 0.2, 1.6, Color(1.2, 0.5, 2.8), 0.3)
	disc(at, 1.6, 0, VIOLET, VIOLET_HOT, 0.6)
	Vfx.burst(at + Vector3.UP, VIOLET_HOT, {"count": 46, "life": 0.45, "speed": Vector2(3.0, 7.0), "size": 0.045, "gravity": -3.0, "trail": 0.08})
	Vfx.light(at + Vector3.UP, Color(0.7, 0.4, 1.0), 4.0, 6.0, 0.35)


static func rift_seam(from: Vector3, to: Vector3) -> void:
	var a := from + Vector3.UP
	var b := to + Vector3.UP
	Vfx.arc(a, b, Color(1.6, 0.8, 3.2), 0.3, 0.12)
	var pts := PackedVector3Array()
	for i in 12:
		pts.append(a.lerp(b, float(i) / 11.0))
	Vfx.ribbon(pts, 0.1, 0.9, Color(0.8, 0.4, 2.2, 0.8), 0.35)
