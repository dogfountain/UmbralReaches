class_name LanternWard
extends Node3D
## A planted warm light (Lantern Ward skill). Registered with LightGrid for its whole life, so
## every existing rule about light applies to it for free: Gloom drains, shades dissipate,
## light-averse enemies slink, spawners hold off. The ground ring shows the safe radius.
## r30: it is a "ward" zone, not a fire: it never counts as a rest (camps do not refill, a tide
## does not break), it drains Gloom at DRAIN/s up to DRAIN_CAP a cast (not the fire's 12/s), and
## bosses and elites walk through it (Enemy._light_barrier skips them). A breather, not a fortress.

const LIFE := 7.0
const RADIUS := 7.0
const DRAIN := 4.0              ## Gloom/s inside it (a fire is 12)
const DRAIN_CAP := 25.0         ## at most this much Gloom drained per cast
const WARM := Color("#FFB347")
const FLARE_SHADER := preload("res://world/flare.gdshader")
const RUNE_SHADER := preload("res://world/vfx/rune_circle.gdshader")
const LANTERN_GLB := "res://art/models/hand_lantern.glb"
const SFX_CHIME := "res://art/audio/ward_chime.wav"

static var _ring_mesh: TorusMesh
static var _ring_mat: StandardMaterial3D
static var _flare_mesh: QuadMesh
static var _rune_mesh: PlaneMesh
static var _rune_mat: ShaderMaterial
static var _lantern_scene: PackedScene

var _t := 0.0
var _light: OmniLight3D
var _ring: MeshInstance3D
var _rune: MeshInstance3D
var _totem: Node3D
var _embers: GPUParticles3D


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
	w.position = _ground_below(by)       # before add_child: _ready spawns effects at its position
	host.add_child(w)
	by.ward_drain_left = DRAIN_CAP
	return w


static func _ground_below(by: Player) -> Vector3:
	var from := by.global_position + Vector3.UP * 0.5
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 4.0)
	q.collision_mask = Layers.WORLD | Layers.PROPS
	q.exclude = [by.get_rid()]
	var hit := by.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else by.global_position


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # its ring and totem turn every rendered frame
	name = "LanternWard"
	add_to_group(&"lantern_ward")
	_ensure_shared()
	_light = OmniLight3D.new()
	_light.light_color = WARM
	_light.light_energy = 0.0
	_light.omni_range = RADIUS
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
	# ground sigil the size of the safe zone
	_rune = MeshInstance3D.new()
	_rune.mesh = _rune_mesh
	_rune.material_override = _rune_mat
	_rune.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rune.position = Vector3(0.0, 0.05, 0.0)
	_rune.scale = Vector3(RADIUS, 1.0, RADIUS)
	add_child(_rune)
	_rune.set_instance_shader_parameter(&"life", 1.0)
	_rune.set_instance_shader_parameter(&"bloom_in", 0.0)
	# the totem: a lantern that rises out of the ground and hangs, turning
	_totem = Node3D.new()
	_totem.position = Vector3(0.0, 0.2, 0.0)
	add_child(_totem)
	if _lantern_scene:
		var model := _lantern_scene.instantiate() as Node3D
		if model:
			model.scale = Vector3.ONE * 1.6
			_totem.add_child(model)
	flare.reparent(_totem, false)
	flare.position = Vector3(0.0, 0.0, 0.0)
	_light.reparent(_totem, false)
	_light.position = Vector3(0.0, 0.1, 0.0)
	# embers rising over the whole zone + a tight swirl round the lantern
	_embers = Vfx.emitter(Color(2.2, 1.1, 0.4), {"count": 60, "life": 2.4, "speed": Vector2(0.2, 0.8), "size": 0.05, "gravity": 0.9, "ring": RADIUS * 0.8, "damping": 0.2, "turbulence": true, "explosive": 0.0})
	add_child(_embers)
	_embers.emitting = true
	var swirl := Vfx.emitter(Color(2.6, 1.5, 0.6), {"count": 24, "life": 1.0, "speed": Vector2(0.1, 0.3), "size": 0.035, "gravity": 0.4, "radius": 0.45, "swirl": 3.5, "radial": -1.0, "trail": 0.12, "explosive": 0.0})
	_totem.add_child(swirl)
	swirl.emitting = true
	Vfx.ring(global_position, RADIUS, Color(2.4, 1.3, 0.45), 0.5, 0.05, Vector3.UP, 1.4)
	Vfx.burst(global_position + Vector3.UP * 0.3, Color(2.6, 1.4, 0.5), {"count": 50, "life": 0.9, "speed": Vector2(2.0, 6.0), "size": 0.05, "gravity": -3.0, "trail": 0.1, "dir": Vector3.UP, "spread": 50.0})
	Sfx.play(SFX_CHIME, global_position + Vector3.UP, 1.0)
	LightGrid.register(self, RADIUS, LightGrid.WARD, DRAIN)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_light, "light_energy", 3.2, 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(_ring, "scale", Vector3(1.0, 0.02, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_totem, "position:y", 1.35, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: _rune.set_instance_shader_parameter(&"bloom_in", v), 0.0, 1.0, 0.45)


func _process(delta: float) -> void:
	_t += delta
	var fade := clampf((LIFE - _t) / 1.2, 0.0, 1.0)
	if _t > 0.35:
		_light.light_energy = 3.2 * fade * (1.0 + sin(_t * 11.0) * 0.05 + sin(_t * 17.3) * 0.04)
	_ring.rotation.y += delta * 0.4
	_totem.rotation.y += delta * 0.9
	if _t > 0.6:
		_totem.position.y = 1.35 + sin(_t * 1.8) * 0.08
	_rune.set_instance_shader_parameter(&"life", fade)
	if _t >= LIFE - 1.2 and _ring.visible:
		_ring.visible = int(_t * 8.0) % 2 == 0   # blink: about to go
	if _t >= LIFE:
		Vfx.burst(_totem.global_position, Color(2.4, 1.2, 0.4), {"count": 40, "life": 0.7, "speed": Vector2(1.0, 4.0), "size": 0.05, "gravity": -4.0, "trail": 0.08})
		Vfx.burst(_totem.global_position, Color(0.06, 0.04, 0.03, 0.7), {"count": 10, "life": 1.0, "speed": Vector2(0.3, 1.0), "size": 0.4, "gravity": 0.6, "additive": false})
		queue_free()


func _exit_tree() -> void:
	LightGrid.unregister(self)


static func _ensure_shared() -> void:
	if _ring_mesh != null:
		return
	_rune_mesh = PlaneMesh.new()
	_rune_mesh.size = Vector2(2.0, 2.0)
	_rune_mat = ShaderMaterial.new()
	_rune_mat.shader = RUNE_SHADER
	if ResourceLoader.exists(LANTERN_GLB):
		_lantern_scene = load(LANTERN_GLB) as PackedScene
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
