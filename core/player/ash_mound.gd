extends Node3D
## r30: the ash a hollowed wanderer was carrying, left where they fell (Player._drop_ash). Walk
## within REACH to take it back up. A second hollowing first loses it (the Player frees the old
## mound). The Player writes its place and amount to the save (Travel.system_state) so a continue puts it back.

const REACH := 1.8
const ASH := Color(0.62, 0.58, 0.66)

var amount := 0
var _t := 0.0
var _light: OmniLight3D
var _heap: MeshInstance3D
var _taken := false


func _ready() -> void:
	name = "AshMound"
	add_to_group(&"ash_mound")
	_heap = MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.45
	m.height = 0.4
	m.radial_segments = 12
	m.rings = 6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.2, 0.24)
	mat.roughness = 1.0
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.82, 0.7)
	mat.emission_energy_multiplier = 0.35
	m.material = mat
	_heap.mesh = m
	_heap.position = Vector3(0.0, 0.08, 0.0)
	_heap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_heap)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.9, 0.75)
	_light.light_energy = 0.9
	_light.omni_range = 3.2
	_light.shadow_enabled = false
	_light.position = Vector3(0.0, 0.7, 0.0)
	add_child(_light)
	var motes := Vfx.emitter(Color(1.1, 1.0, 0.85), {"count": 14, "life": 1.8, "speed": Vector2(0.1, 0.4), "size": 0.035, "gravity": -0.4, "radius": 0.4, "explosive": 0.0})
	add_child(motes)
	motes.emitting = true


func _physics_process(delta: float) -> void:
	_t += delta
	_light.light_energy = 0.8 + 0.25 * sin(_t * 2.4)
	if _taken:
		return
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if p == null:
		return
	var d := p.global_position - global_position
	if absf(d.y) < 2.0 and Vector2(d.x, d.z).length() < REACH:
		take()


func take() -> void:
	if _taken:
		return
	_taken = true
	if amount > 0:
		Travel.give("grave_ash", amount, false)
		Events.toast.emit("The ash comes back to you: %d." % amount)
	var rec := Travel.system_state("ash_mound")     # taken: the save forgets the heap
	rec.clear()
	Travel.save_soon()
	Vfx.burst(global_position + Vector3.UP * 0.4, ASH, {"count": 30, "life": 0.8, "speed": Vector2(1.0, 3.5), "size": 0.05, "gravity": -2.0, "dir": Vector3.UP, "spread": 40.0})
	var tw := create_tween()
	tw.tween_property(_heap, "scale", Vector3(1.2, 0.05, 1.2), 0.3)
	tw.parallel().tween_property(_light, "light_energy", 0.0, 0.3)
	tw.tween_callback(queue_free)
