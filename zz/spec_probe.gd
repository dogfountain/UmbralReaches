extends Node3D
## Which scene states make Forward+ compile new pipelines for materials it has already drawn (shader pre-warm, 21 Nov).
## A tiny lab: a moon (soft, shadowed), depth fog, six boxes of different materials in view; then one change at a time,
## each held for 12 frames, printing the pipeline compiles it caused: "SPECPROBE <step> canvas/mesh/surface/draw/spec".
##   godot --path . res://zz/spec_probe.tscn
## Windowed (a headless run compiles nothing).

const PsoWatch := preload("res://zz/pso_watch.gd")
const HOLD := 12

var _cam: Camera3D
var _moon: DirectionalLight3D
var _env: Environment
var _boxes: Array[MeshInstance3D] = []
var _steps: Array = []
var _k := -1
var _f := 0
var _last: PackedInt64Array = []
var _extra: Array[Node] = []


func _ready() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_DEPTH
	_env.volumetric_fog_enabled = true
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_moon = DirectionalLight3D.new()
	_moon.shadow_enabled = true
	_moon.light_angular_distance = 0.42
	_moon.rotation = Vector3(-0.8, 0.4, 0.0)
	add_child(_moon)
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.position = Vector3(0, 2.0, 6.0)
	_cam.current = true
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	floor_mi.mesh = pm
	add_child(floor_mi)
	for i in 6:
		var mi := MeshInstance3D.new()
		mi.mesh = BoxMesh.new()
		var m := StandardMaterial3D.new()
		m.albedo_color = Color.from_hsv(float(i) / 6.0, 0.6, 0.8)
		match i:
			1: m.roughness = 0.3; m.metallic = 0.5; m.emission_enabled = true
			2: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			3: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.albedo_color.a = 0.5
			4: m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			5: m.rim_enabled = true; m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = m
		add_child(mi)
		mi.position = Vector3(float(i) - 2.5, 0.6, 0.0)
		_boxes.append(mi)
	var tex := GradientTexture2D.new()
	_steps = [
		["baseline", func() -> void: pass],
		["again (nothing changed)", func() -> void: pass],
		# shadowed lights first, before any light with a size: do they make the touched materials' colour pass new too?
		["omni, dual paraboloid shadow, size 0", func() -> void: _omni(OmniLight3D.SHADOW_DUAL_PARABOLOID, 0.0)],
		["removed", _clear],
		["omni, cube shadow, size 0", func() -> void: _omni(OmniLight3D.SHADOW_CUBE, 0.0)],
		["removed", _clear],
		["spot, shadow, size 0", func() -> void: _spot(true, null, 0.0)],
		["removed", _clear],
		["soft light (size 0.3, no shadow)", func() -> void: _omni_plain(0.3, Vector3(0, 2.5, 1.5))],
		["removed", _clear],
		["projector spot, no shadow", func() -> void: _spot(false, tex, 0.0)],
		["removed", _clear],
		["instance transparency 0.5 on every box", func() -> void: _alpha(0.5)],
		["transparency back to 0", func() -> void: _alpha(0.0)],
		["end", func() -> void: pass],
	]
	_last = PsoWatch._counts()


func _spot(shadow: bool, proj: Texture2D, size: float, at := Vector3(0, 3, 3), angle := 50.0) -> void:
	var s := SpotLight3D.new()
	s.shadow_enabled = shadow
	s.light_projector = proj
	s.light_size = size
	s.spot_range = 20.0
	s.spot_angle = angle
	add_child(s)
	s.position = at
	s.look_at(Vector3(at.x, 0.0, at.z + 0.01) if angle < 20.0 else Vector3.ZERO)
	_extra.append(s)


func _omni_plain(size: float, at: Vector3, r := 12.0) -> void:
	var o := OmniLight3D.new()
	o.light_size = size
	o.omni_range = r
	add_child(o)
	o.position = at
	_extra.append(o)


func _alpha(v: float) -> void:
	for b in _boxes:
		b.transparency = v


func _fade_band() -> void:
	var b := _boxes[1]
	var d := _cam.global_position.distance_to(b.global_position)
	b.visibility_range_end = d + 0.5
	b.visibility_range_end_margin = 2.0
	b.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


func _omni(mode: OmniLight3D.ShadowMode, size: float, at := Vector3(0, 2.5, 1.5), r := 12.0) -> void:
	var o := OmniLight3D.new()
	o.shadow_enabled = true
	o.omni_shadow_mode = mode
	o.light_size = size
	o.omni_range = r
	add_child(o)
	o.position = at
	_extra.append(o)


func _mm() -> void:
	var mmi := MultiMeshInstance3D.new()
	mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _boxes[1].mesh
	mm.instance_count = 1
	mmi.multimesh = mm
	mmi.material_override = _boxes[1].material_override
	add_child(mmi)
	mmi.position = Vector3(0, 2.0, 0)
	_extra.append(mmi)


func _clear() -> void:
	for n in _extra:
		if is_instance_valid(n):
			n.queue_free()
	_extra.clear()


func _process(_d: float) -> void:
	_f += 1
	if _f < HOLD:
		return
	_f = 0
	var now := PsoWatch._counts()
	if _k >= 0:
		var d: PackedInt64Array = []
		for i in now.size():
			d.append(now[i] - _last[i])
		print("SPECPROBE %-46s %s" % [_steps[_k][0], PsoWatch.totals_text(d)])
	_last = now
	_k += 1
	if _k >= _steps.size():
		get_tree().quit()
		return
	(_steps[_k][1] as Callable).call()
