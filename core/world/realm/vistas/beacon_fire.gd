extends Node3D
## A March beacon's fire (realm_vistas.gd): the big flame in the iron basket, its halo and its smoke, seen from across
## the Realm once the wanderer has kindled it. The kindling itself is the Lamp at the basket (lamp.gd: the gesture, the
## save, the grave ash, the tally); this node only watches it. Cold, nothing burns (pillar 2: warmth is earned).
##
## The moment: when it takes, the fire rises out of the basket over two seconds and flares, sparks go up, and every
## other lit beacon answers with a flare of its own a beat later, in order of distance; a line says how many burn.
## Group `vista_beacon`. Asleep (no per-frame work) while cold or steady.

const GROUP := &"vista_beacon"
const FLAME := preload("res://core/world/realm/vistas/beacon_flame.gdshader")
const SMOKE := preload("res://core/world/realm/vistas/beacon_smoke.gdshader")

var lamp: Lamp                         ## the kindling (set before add_child)
var title := "beacon"
var _flames: Array[MeshInstance3D] = []
var _smoke: MeshInstance3D
var _sparks: GPUParticles3D
var _mats: Array[ShaderMaterial] = []
var _smoke_mat: ShaderMaterial
var _energy := 0.0
var _goal := 0.0
var _flare := 0.0
var _was_lit := false
var _poll := 0.0
var _answer_in := -1.0


func _ready() -> void:
	add_to_group(GROUP)
	var seed := float(hash(title) % 1000) * 0.01
	# two crossed flames (one turned a quarter, so the fire has body from any side) and the halo
	for k in 3:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		var is_halo := k == 2
		q.size = Vector2(8.0, 8.0) if is_halo else Vector2(3.0, 4.6)
		q.center_offset = Vector3(0.0, 1.0 if is_halo else 2.05, 0.0)
		var m := ShaderMaterial.new()
		m.shader = FLAME
		m.set_shader_parameter("halo", 1.0 if is_halo else 0.0)
		m.set_shader_parameter("energy", 0.0)
		q.material = m
		mi.mesh = q
		mi.name = "BeaconFlame%d" % k
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 16.0
		mi.set_instance_shader_parameter("seed", seed + k * 1.7)
		mi.set_meta(&"far_detail", true)
		mi.add_to_group(Groups.CULL_SKIP)
		mi.visible = false
		add_child(mi)
		_flames.append(mi)
		_mats.append(m)
	_smoke = MeshInstance3D.new()
	var sq := QuadMesh.new()
	sq.size = Vector2(2.6, 26.0)
	sq.center_offset = Vector3(0.0, 13.6, 0.0)
	_smoke_mat = ShaderMaterial.new()
	_smoke_mat.shader = SMOKE
	_smoke_mat.set_shader_parameter("energy", 0.0)
	sq.material = _smoke_mat
	_smoke.mesh = sq
	_smoke.name = "BeaconSmoke"
	_smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_smoke.extra_cull_margin = 24.0
	_smoke.set_instance_shader_parameter("seed", seed)
	_smoke.set_meta(&"far_detail", true)
	_smoke.add_to_group(Groups.CULL_SKIP)
	_smoke.visible = false
	add_child(_smoke)
	_sparks = _make_sparks()
	add_child(_sparks)
	_was_lit = lamp != null and lamp.lit
	if _was_lit:
		_energy = 1.0
		_goal = 1.0
	_apply()


## Embers rising off the fire: few, and only near (the far view has the flame and the smoke).
func _make_sparks() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "BeaconEmbers"
	p.amount = 26
	p.lifetime = 3.2
	p.emitting = false
	p.visibility_range_end = 150.0
	p.visibility_range_end_margin = 20.0
	p.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 22, 12))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.55
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 22.0
	pm.initial_velocity_min = 1.6
	pm.initial_velocity_max = 3.4
	pm.gravity = Vector3(0.35, 0.55, 0.15)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.6
	pm.turbulence_noise_scale = 2.4
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.72, 0.32, 1.0))
	ramp.set_color(1, Color(0.9, 0.25, 0.05, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.vertex_color_use_as_albedo = true
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.albedo_color = Color(1.0, 0.7, 0.4)
	q.material = sm
	p.draw_pass_1 = q
	p.position = Vector3(0.0, 0.9, 0.0)
	return p


func _process(delta: float) -> void:
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.4
		var lit := lamp != null and is_instance_valid(lamp) and lamp.lit
		if lit and not _was_lit:
			_take()
		elif not lit and _was_lit:
			_goal = 0.0
		_was_lit = lit
	if _answer_in >= 0.0:
		_answer_in -= delta
		if _answer_in < 0.0:
			_flare = maxf(_flare, 0.7)
	var steady := absf(_energy - _goal) < 0.001 and _flare <= 0.0 and _answer_in < 0.0
	if steady:
		return
	_energy = move_toward(_energy, _goal, delta * 0.5)
	_flare = maxf(0.0, _flare - delta * 0.45)
	_apply()


## It takes: the fire rises and flares; the other lit beacons answer in turn.
func _take() -> void:
	_goal = 1.0
	_flare = 1.0
	_sparks.amount_ratio = 1.0
	_sparks.restart()
	var lit := 1
	var others: Array = []
	for b in get_tree().get_nodes_in_group(GROUP):
		if b == self or not (b is Node3D):
			continue
		if b.get("lamp") != null and (b.get("lamp") as Lamp).lit:
			lit += 1
			others.append(b)
	others.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_to(global_position) < b.global_position.distance_to(global_position))
	for i in others.size():
		var other: Variant = others[i]
		other.answer(2.5 + 1.2 * i)
	var total := get_tree().get_nodes_in_group(GROUP).size()
	if lit > 1:
		Events.toast.emit("Far off, the other beacons answer.  Beacons burning: %d of %d." % [lit, total])
	else:
		Events.toast.emit("The beacon takes.  Beacons burning: %d of %d." % [lit, total])


## Another beacon was lit: flare after `delay` seconds (if this one burns).
func answer(delay: float) -> void:
	if _goal > 0.5:
		_answer_in = delay


func _apply() -> void:
	var e := _energy * (1.0 + 0.8 * _flare)
	var on := e > 0.003
	for i in _flames.size():
		_flames[i].visible = on
		_mats[i].set_shader_parameter("energy", e * (1.0 if i < 2 else 0.9))
		var s := 0.35 + 0.65 * smoothstep(0.0, 1.0, _energy) + 0.45 * _flare
		_flames[i].scale = Vector3(s, s, s)
	_smoke.visible = on
	_smoke_mat.set_shader_parameter("energy", clampf(_energy, 0.0, 1.0))
	_sparks.emitting = on
	_sparks.amount_ratio = clampf(0.4 + 0.6 * _flare, 0.0, 1.0)
