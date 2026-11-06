extends Node3D
## A Bound Shade (r28): a small hooded wisp that circles the wanderer's shoulder for `life`
## seconds and looses a dart at the foe nearest the crosshair every `rate` seconds (0.5 x power
## and a Mark). Keen Eyes (seek) makes the darts curve home from further off; Last Breath dives at
## the nearest foe when its time runs out and detonates the Marks around it; the Sexton's Wisp-Jar
## makes a dart that strikes a Marked foe burst on its neighbours. Never collides with anything.

const Aim := preload("res://core/skills/aim.gd")
const CombatState := preload("res://core/skills/combat_state.gd")
const Combo := preload("res://core/skills/combo.gd")
const StaffSfx := preload("res://core/vfx/staff_sfx.gd")
const PALE := Color(1.6, 1.3, 3.2)
const DART_DMG := 0.5
const REACH := 16.0
const DIVE_R := 3.0

static var _body_mesh: SphereMesh
static var _body_mat: StandardMaterial3D
static var _aura_quad: QuadMesh
static var _eye_mesh: SphereMesh
static var _eye_mat: StandardMaterial3D

var owner_p: Node3D
var life := 14.0
var rate := 1.1
var seek := false
var last_breath := false
var jar := false
var marks := 1                 ## Marks per dart (Nan's Chalk: 2)
var power := 1.0
var phase := 0.0               ## where on the orbit it rides (two shades ride opposite)
var darts := 0                 ## loosed so far (tests)
var _t := 0.0
var _cd := 0.6
var _vis: Node3D
var _trail: GPUParticles3D
var _gone := false


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # r36 smooth: moved in _process, drawn as set (interpolated, it judders between ticks)
	name = "BoundShade"
	add_to_group(&"bound_shade")
	top_level = true
	_shared()
	_vis = Node3D.new()
	add_child(_vis)
	var body := MeshInstance3D.new()
	body.mesh = _body_mesh
	body.material_override = _body_mat
	body.scale = Vector3(1.0, 1.35, 1.0)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vis.add_child(body)
	var aura := MeshInstance3D.new()                       # a soft billboard glow, not a sphere (a disc)
	aura.mesh = _aura_quad
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vis.add_child(aura)
	for sx: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.mesh = _eye_mesh
		eye.material_override = _eye_mat
		eye.position = Vector3(0.05 * sx, 0.05, -0.13)
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_vis.add_child(eye)
	_trail = Vfx.emitter(Color(1.1, 0.8, 2.6), {"count": 26, "life": 0.7, "speed": Vector2(0.05, 0.25), "size": 0.045, "gravity": -0.4, "radius": 0.12, "trail": 0.12})
	add_child(_trail)
	_trail.emitting = true
	var smoke := Vfx.emitter(Color(0.03, 0.01, 0.06, 0.7), {"count": 10, "life": 0.8, "speed": Vector2(0.05, 0.2), "size": 0.22, "gravity": -0.2, "radius": 0.1, "additive": false})
	add_child(smoke)
	smoke.emitting = true
	if owner_p:
		global_position = _home(0.0)
	_vis.scale = Vector3.ONE * 0.05
	create_tween().tween_property(_vis, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Vfx.burst(global_position, PALE, {"count": 30, "life": 0.5, "speed": Vector2(0.5, 2.5), "size": 0.04, "gravity": 0.0, "radius": 0.3, "radial": -4.0, "trail": 0.08})


static func _shared() -> void:
	if _body_mesh != null:
		return
	_body_mesh = SphereMesh.new()
	_body_mesh.radius = 0.13
	_body_mesh.height = 0.26
	_body_mesh.radial_segments = 14
	_body_mesh.rings = 8
	_body_mat = StandardMaterial3D.new()
	_body_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_body_mat.albedo_color = Color(0.03, 0.01, 0.06)
	var am := StandardMaterial3D.new()
	am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	am.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	am.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	am.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	am.albedo_texture = Vfx.dot()
	am.albedo_color = Color(0.9, 0.65, 2.2, 0.75)
	_aura_quad = QuadMesh.new()
	_aura_quad.size = Vector2(0.75, 0.75)
	_aura_quad.material = am
	_eye_mesh = SphereMesh.new()
	_eye_mesh.radius = 0.024
	_eye_mesh.height = 0.03
	_eye_mesh.radial_segments = 8
	_eye_mesh.rings = 4
	_eye_mat = ProcMesh.glow_mat(Color(3.0, 2.6, 4.4))


func _home(t: float) -> Vector3:
	var p := owner_p.global_position
	var a := phase + t * 1.4
	return p + Vector3(cos(a) * 1.05, 2.05 + sin(t * 2.3 + phase) * 0.12, sin(a) * 1.05)


func remaining() -> float:
	return clampf(1.0 - _t / life, 0.0, 1.0)


func _process(delta: float) -> void:
	if _gone or owner_p == null or not is_instance_valid(owner_p):
		return
	var want := _home(_t)
	global_position = global_position.lerp(want, 1.0 - exp(-delta * 7.0))
	var look := Aim.forward(owner_p)
	look.y = 0.0
	if look.length_squared() > 0.01:
		_vis.global_basis = Basis.looking_at(look.normalized(), Vector3.UP)


func _physics_process(delta: float) -> void:
	if _gone:
		return
	if owner_p == null or not is_instance_valid(owner_p):
		_fade()
		return
	_t += delta
	_cd -= delta
	if _cd <= 0.0:
		var t := _target()
		if t:
			_cd = rate
			_loose(t)
		else:
			_cd = 0.2
	if _t >= life:
		if last_breath:
			_dive()
		else:
			_fade()


## The foe nearest the crosshair within REACH of the wanderer. An empty cone holds the dart.
func _target() -> Node3D:
	return Aim.pick(owner_p, REACH, 0.8)


func _loose(t: Node3D) -> void:
	darts += 1
	var from := global_position
	var to := Aim.chest(t)
	var pts := PackedVector3Array()
	var bend := Vector3.UP * 0.6 + (to - from).cross(Vector3.UP).normalized() * (0.8 if darts % 2 == 0 else -0.8)
	if not seek:
		bend *= 0.15
	for i in 10:
		var u := float(i) / 9.0
		pts.append(from.lerp(to, u) + bend * sin(u * PI))
	Vfx.ribbon(pts, 0.03, 0.12, Color(1.4, 1.0, 3.0, 0.9), 0.22)
	StaffSfx.play("dart", from, -6.0)
	_vis.scale = Vector3.ONE * 1.25
	create_tween().tween_property(_vis, "scale", Vector3.ONE, 0.2)
	var tid := t.get_instance_id()
	get_tree().create_timer(0.12, false).timeout.connect(func() -> void: _strike(instance_from_id(tid) as Node3D, to))


func _strike(t: Node3D, at: Vector3) -> void:
	if not is_instance_valid(t) or (t.has_method("is_alive") and not t.call("is_alive")):
		return
	at = Aim.chest(t)
	var had := int(t.get("marks")) if t.get("marks") != null else 0
	CombatState.strike(t, DART_DMG * power, &"umbral", self)
	t.call("add_mark", marks)
	Vfx.burst(at, PALE, {"count": 14, "life": 0.3, "speed": Vector2(1.5, 4.0), "size": 0.04, "gravity": -3.0, "trail": 0.06})
	if jar and had > 0:
		for node in get_tree().get_nodes_in_group(Groups.ENEMY):
			var o := node as Node3D
			if o == null or o == t or (o.has_method("is_alive") and not o.call("is_alive")):
				continue
			if o.global_position.distance_to(t.global_position) <= 1.5:
				CombatState.strike(o, 0.5 * power, &"umbral", self)
		Vfx.ring(at, 1.5, PALE, 0.25, 0.08, Vector3.UP, 1.0)


## Last Breath: it dives at the nearest foe and bursts, detonating every Mark within DIVE_R.
func _dive() -> void:
	_gone = true
	var t := Aim.nearest(get_tree(), global_position, 14.0)
	if t == null:
		_fade()
		return
	var to := Aim.chest(t)
	var tw := create_tween()
	tw.tween_property(self, "global_position", to, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: _burst_at(to))
	StaffSfx.play("dart", global_position, -2.0, 0.6)


func _burst_at(at: Vector3) -> void:
	var total := 0
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		var o := node as Node3D
		if o == null or (o.has_method("is_alive") and not o.call("is_alive")):
			continue
		var flat := Vector2(o.global_position.x - at.x, o.global_position.z - at.z).length()   # along the ground
		if flat > DIVE_R or absf(o.global_position.y - at.y) > 3.5:
			continue
		var m := int(o.call("take_marks")) if o.has_method("take_marks") else 0
		total += m
		var dmg := (2.0 if flat < 1.8 else 0.0) + float(m)
		if dmg > 0.0:
			CombatState.strike(o, dmg * power, &"umbral", self)
	SpellFx.disc(at - Vector3.UP * 0.9, DIVE_R, 0, SpellFx.VIOLET * 0.8, Color(2.6, 2.2, 3.6), 0.6)
	SpellFx.shell(at, 0.2, DIVE_R, Color(1.3, 1.0, 2.8), 0.32)
	Vfx.burst(at, PALE, {"count": 50, "life": 0.5, "speed": Vector2(3.0, 8.0), "size": 0.05, "gravity": -4.0, "trail": 0.08})
	Vfx.light(at, Color(0.75, 0.6, 1.0), 4.0, DIVE_R * 2.4, 0.35)
	StaffSfx.play("echo", at, -2.0, 1.2)
	if total >= 3:
		Combo.note("DETONATION", at + Vector3.UP, Color(0.85, 0.55, 1.0), "%d Marks" % total)
	_vis.visible = false
	_trail.emitting = false
	get_tree().create_timer(0.8, false).timeout.connect(queue_free)


func _fade() -> void:
	_gone = true
	Vfx.burst(global_position, PALE, {"count": 24, "life": 0.5, "speed": Vector2(0.4, 1.6), "size": 0.04, "gravity": 0.6, "radius": 0.2, "trail": 0.06})
	_trail.emitting = false
	var tw := create_tween()
	tw.tween_property(_vis, "scale", Vector3.ONE * 0.01, 0.3)
	tw.tween_callback(queue_free)
