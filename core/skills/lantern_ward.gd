class_name LanternWard
extends Node3D
## A planted warm light (Lantern Ward skill). Registered with LightGrid for its whole life, so
## every existing rule about light applies to it for free: Gloom drains, shades dissipate,
## light-averse enemies slink, spawners hold off. The ground ring shows the safe radius.

const LIFE := 7.0
const RADIUS := 5.5
const WARM := Color("#FFB347")
const FLARE_SHADER := preload("res://world/flare.gdshader")

static var _ring_mesh: TorusMesh
static var _ring_mat: StandardMaterial3D
static var _flare_mesh: QuadMesh

var _t := 0.0
var _light: OmniLight3D
var _ring: MeshInstance3D


## One ward at a time: planting again replaces the old one.
static func plant(by: Player) -> LanternWard:
	if by == null or not by.is_inside_tree():
		return null
	var tree := by.get_tree()
	for old in tree.get_nodes_in_group(&"lantern_ward"):
		(old as Node).queue_free()
	var host := tree.current_scene
	if host == null:
		return null
	var w := LanternWard.new()
	host.add_child(w)
	w.global_position = _ground_below(by)
	return w


static func _ground_below(by: Player) -> Vector3:
	var from := by.global_position + Vector3.UP * 0.5
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 4.0)
	q.collision_mask = Layers.WORLD | Layers.PROPS
	q.exclude = [by.get_rid()]
	var hit := by.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else by.global_position


func _ready() -> void:
	name = "LanternWard"
	add_to_group(&"lantern_ward")
	_ensure_shared()
	_light = OmniLight3D.new()
	_light.light_color = WARM
	_light.light_energy = 0.0
	_light.omni_range = RADIUS * 1.6
	_light.omni_attenuation = 1.1
	_light.shadow_enabled = false
	_light.light_volumetric_fog_energy = 1.4
	_light.set_meta("light_class", "beacon")
	_light.position = Vector3(0.0, 1.3, 0.0)
	add_child(_light)
	var flare := MeshInstance3D.new()
	flare.mesh = _flare_mesh
	flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flare.position = _light.position
	add_child(flare)
	_ring = MeshInstance3D.new()
	_ring.mesh = _ring_mesh
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.position = Vector3(0.0, 0.06, 0.0)
	_ring.scale = Vector3(0.2, 0.02, 0.2)
	add_child(_ring)
	LightGrid.register(self, RADIUS)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_light, "light_energy", 3.2, 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(_ring, "scale", Vector3(1.0, 0.02, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	var fade := clampf((LIFE - _t) / 1.2, 0.0, 1.0)
	if _t > 0.35:
		_light.light_energy = 3.2 * fade * (1.0 + sin(_t * 11.0) * 0.05 + sin(_t * 17.3) * 0.04)
	_ring.rotation.y += delta * 0.4
	if _t >= LIFE - 1.2 and _ring.visible:
		_ring.visible = int(_t * 8.0) % 2 == 0   # blink: about to go
	if _t >= LIFE:
		queue_free()


func _exit_tree() -> void:
	LightGrid.unregister(self)


static func _ensure_shared() -> void:
	if _ring_mesh != null:
		return
	_ring_mesh = TorusMesh.new()
	_ring_mesh.inner_radius = RADIUS - 0.12
	_ring_mesh.outer_radius = RADIUS
	_ring_mesh.rings = 48
	_ring_mesh.ring_segments = 6
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = Color(1.6, 0.95, 0.4, 0.55)
	_ring_mat.disable_receive_shadows = true
	_ring_mesh.material = _ring_mat
	_flare_mesh = QuadMesh.new()
	_flare_mesh.size = Vector2(1.1, 1.1)
	var fmat := ShaderMaterial.new()
	fmat.shader = FLARE_SHADER
	fmat.set_shader_parameter("color", Color(2.6, 1.4, 0.55))
	_flare_mesh.material = fmat
