extends Node3D
## Ember Lance rank II, Wide Ember (progression): the burst throws COUNT cinders that arc out and
## burst again where they land: DMG x spell power within RADIUS, each. `throw(at, power, dir)`.

const COUNT := 3
const RADIUS := 1.7
const DMG := 0.8
const FLIGHT := 0.42
const StaffSfx := preload("res://core/vfx/staff_sfx.gd")

var power := 1.0
var _from := Vector3.ZERO
var _to: Array[Vector3] = []
var _t := 0.0
var _done := false
var _orbs: Array[MeshInstance3D] = []
static var _orb_mesh: SphereMesh
static var _orb_mat: StandardMaterial3D


static func throw(at: Vector3, spell_power: float, dir: Vector3) -> void:
	var host := Vfx.host()
	if host == null:
		return
	var c := new()
	c.name = "EmberCinders"
	c.power = spell_power
	c._from = at + Vector3.UP * 0.4
	var space := (host as Node).get_viewport().world_3d.direct_space_state if host is Node and (host as Node).get_viewport() else null
	var fwd := Vector3(dir.x, 0.0, dir.z)
	var base_a := atan2(fwd.x, fwd.z) if fwd.length() > 0.1 else randf() * TAU
	for k in COUNT:
		var a := base_a + PI + (float(k) - 1.0) * 1.05 + randf_range(-0.25, 0.25)     # thrown back and to the sides
		var d := randf_range(2.6, 3.8)
		var p := at + Vector3(sin(a), 0.0, cos(a)) * d
		if space:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 5.0, Layers.WORLD | Layers.PROPS))
			if not hit.is_empty():
				p = hit.position
		c._to.append(p)
	host.add_child(c)


func _ready() -> void:
	if _orb_mesh == null:
		_orb_mesh = SphereMesh.new()
		_orb_mesh.radius = 0.09
		_orb_mesh.height = 0.18
		_orb_mesh.radial_segments = 10
		_orb_mesh.rings = 6
		_orb_mat = ProcMesh.glow_mat(Color(3.4, 1.5, 0.5))
	for k in _to.size():
		var o := MeshInstance3D.new()
		o.mesh = _orb_mesh
		o.material_override = _orb_mat
		o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		o.top_level = true
		add_child(o)
		o.global_position = _from
		_orbs.append(o)
		var trail := Vfx.emitter(Color(2.6, 0.9, 0.3), {"count": 18, "life": 0.35, "speed": Vector2(0.05, 0.3), "size": 0.045, "gravity": 0.6, "radius": 0.05, "trail": 0.08})
		o.add_child(trail)
		trail.emitting = true


func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var u := clampf(_t / FLIGHT, 0.0, 1.0)
	for k in _orbs.size():
		var p := _from.lerp(_to[k], u) + Vector3.UP * sin(u * PI) * 1.6
		_orbs[k].global_position = p
	if u >= 1.0:
		_done = true
		for k in _to.size():
			_land(_to[k])
		for o in _orbs:
			o.visible = false
			for ch in o.get_children():
				if ch is GPUParticles3D:
					(ch as GPUParticles3D).emitting = false
		get_tree().create_timer(0.8, false).timeout.connect(queue_free)


func _land(at: Vector3) -> void:
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Node3D
		if e == null or (e.has_method("is_alive") and not e.call("is_alive")):
			continue
		if e.global_position.distance_to(at) <= RADIUS + 0.4:
			e.call("take_hit", DMG * power, self)
	SpellFx.disc(at, RADIUS, 1, SpellFx.EMBER * 0.7, SpellFx.EMBER_HOT, 0.7)
	Vfx.burst(at + Vector3.UP * 0.2, SpellFx.EMBER_HOT, {"count": 22, "life": 0.5, "speed": Vector2(2.0, 5.0), "size": 0.045, "gravity": -8.0, "trail": 0.07, "dir": Vector3.UP, "spread": 60.0})
	Vfx.burst(at + Vector3.UP * 0.4, Color(0.05, 0.03, 0.04, 0.75), {"count": 8, "life": 1.0, "speed": Vector2(0.4, 1.2), "size": 0.4, "gravity": 1.0, "additive": false})
	StaffSfx.play("burn_hit", at, -3.0, 0.8)
