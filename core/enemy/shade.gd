class_name Shade
extends Node3D
## The Hollow One. Born when Gloom reaches its cap: it tears into the world behind you, a
## six-metre shroud with a crowned bone mask in a void of a hood, and drifts after you high
## above the ground. Light unmakes it (a lit brazier, or any hit); its reach Hollows.
##
## Presence, not hit points: a dark fog cloud swallows its lower body, a pool of shadow and a
## violet glow move across the ground beneath it, the camera trembles as it nears, the halo of
## shards turns, and its arms lift and reach as it closes.

const SHROUD := preload("res://world/vfx/shade_shroud.gdshader")
const SFX_ROAR := "res://art/audio/pounce_shriek.wav"
const HOVER := 3.4              ## core height above the player's feet
const REACH := 1.8              ## horizontal distance at which it takes you
const PRESENCE_R := 14.0        ## camera tremor radius

var target: Player
var speed := 5.2
var _t := 0.0
var _dying := false
var _blocked_t := 0.0
var _body: Node3D
var _mask: Node3D
var _halo: Node3D
var _arms: Array[Node3D] = []
var _core_light: OmniLight3D
var _eye_light: OmniLight3D
var _pool: Decal
var _whisper: AudioStreamPlayer3D
var _skins: Array[GeometryInstance3D] = []
var _reach := 0.0
var _tremor_t := 0.0
var _vel := Vector3.ZERO

static var _shroud_mesh: ArrayMesh
static var _rag_meshes: Array[ArrayMesh] = []
static var _mask_mesh: ArrayMesh
static var _arm_mesh: ArrayMesh
static var _shard_mesh: ArrayMesh
static var _mats: Dictionary = {}


func _ready() -> void:
	add_to_group(Groups.SHADE)
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	_build_meshes()
	_build_body()
	_build_presence()
	_build_hurtbox()
	_whisper = AudioStreamPlayer3D.new()
	_whisper.name = "Whisper"
	var loop := (load("res://art/audio/shade_whisper.wav") as AudioStreamWAV).duplicate()
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_whisper.stream = loop
	_whisper.max_distance = 40.0
	_whisper.volume_db = -14.0
	_whisper.pitch_scale = 0.6          # bigger thing, lower voice
	add_child(_whisper)
	_whisper.play()
	_set_dissolve(1.0)
	_body.scale = Vector3(0.6, 0.2, 0.6)
	call_deferred("_arrive")            # the spawner places it and sets target after add_child


# --- meshes (built once, shared) ------------------------------------------------------------

static func _mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m: Material
	match key:
		"shroud":
			var s := ShaderMaterial.new()
			s.shader = SHROUD
			m = s
		"rag":
			var s := ShaderMaterial.new()
			s.shader = SHROUD
			s.set_shader_parameter("flutter", 2.8)
			s.set_shader_parameter("rag_start", 0.55)
			s.set_shader_parameter("holes", 0.25)
			m = s
		"void":
			var s := StandardMaterial3D.new()
			s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			s.albedo_color = Color(0.0, 0.0, 0.004)
			m = s
		"bone":
			var s := StandardMaterial3D.new()
			s.albedo_color = Color(0.78, 0.72, 0.64)
			s.vertex_color_use_as_albedo = true
			s.roughness = 0.55
			s.rim_enabled = true
			s.rim = 0.35
			s.rim_tint = 0.6
			m = s
		"eye":
			var s := StandardMaterial3D.new()
			s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			s.albedo_color = Color(5.0, 1.5, 0.45)
			m = s
		"shard":
			var s := StandardMaterial3D.new()
			s.albedo_color = Color(0.02, 0.015, 0.03)
			s.metallic = 0.7
			s.roughness = 0.22
			s.emission_enabled = true
			s.emission = Color(0.55, 0.22, 1.3)
			s.emission_energy_multiplier = 0.22
			s.rim_enabled = true
			s.rim = 0.35
			m = s
	_mats[key] = m
	return m


static func _build_meshes() -> void:
	if _shroud_mesh != null:
		return
	_shroud_mesh = _lathe_shroud()
	for i in 3:
		_rag_meshes.append(_ribbon(0.75 - 0.1 * float(i), 1.5 + 0.45 * float(i), 7 + i))
	_mask_mesh = _make_mask()
	_arm_mesh = _make_arm()
	_shard_mesh = _make_shard()


## Hooded shroud as a lathe: profile (radius, y) from crown to hem, the hood's front cut away
## so the void and mask show. UV.x = angle, UV.y = 0 crown .. 1 hem (drives flutter and rag).
static func _lathe_shroud() -> ArrayMesh:
	var prof: Array[Vector2] = [
		Vector2(0.0, 2.55), Vector2(0.28, 2.48), Vector2(0.52, 2.25), Vector2(0.68, 1.9),
		Vector2(0.74, 1.5), Vector2(0.92, 1.08), Vector2(1.18, 0.72), Vector2(1.22, 0.2),
		Vector2(1.3, -0.4), Vector2(1.42, -1.0), Vector2(1.58, -1.7),
	]
	var segs := 28
	var arc := PackedFloat32Array([0.0])
	for i in range(1, prof.size()):
		arc.append(arc[i - 1] + prof[i].distance_to(prof[i - 1]))
	var total := arc[arc.size() - 1]
	var vn: Array[Vector2] = []           # smooth (radial, y) normal per profile vertex
	for i in prof.size():
		var a := prof[maxi(i - 1, 0)]
		var b := prof[mini(i + 1, prof.size() - 1)]
		var tn := (b - a).normalized()
		var nn := Vector2(-tn.y, tn.x)
		vn.append(-nn if nn.x < 0.0 else nn)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in prof.size() - 1:
		var p0 := prof[i]
		var p1 := prof[i + 1]
		var tan := (p1 - p0).normalized()
		var n2 := Vector2(-tan.y, tan.x)          # outward in (radial, y)
		if n2.x < 0.0:
			n2 = -n2
		for j in segs:
			var a0 := TAU * float(j) / float(segs)
			var a1 := TAU * float(j + 1) / float(segs)
			var am := (a0 + a1) * 0.5
			# the face opening: front of the hood (angle near 0 = -Z) between y 1.2 and 2.25
			if absf(angle_difference(am, 0.0)) < 0.62 and p0.y <= 2.25 and p1.y >= 1.2:
				continue
			var verts: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			var nrms: Array[Vector3] = []
			var corner_n: Array[Vector2] = [vn[i], vn[i], vn[i + 1], vn[i + 1]]
			var k := 0
			for c: Vector3 in [Vector3(p0.x, p0.y, a0), Vector3(p0.x, p0.y, a1), Vector3(p1.x, p1.y, a1), Vector3(p1.x, p1.y, a0)]:
				verts.append(Vector3(sin(c.z) * c.x, c.y, -cos(c.z) * c.x))
				var cn := corner_n[k]
				nrms.append(Vector3(sin(c.z) * cn.x, cn.y, -cos(c.z) * cn.x).normalized())
				k += 1
			uvs = [Vector2(a0 / TAU, arc[i] / total), Vector2(a1 / TAU, arc[i] / total), Vector2(a1 / TAU, arc[i + 1] / total), Vector2(a0 / TAU, arc[i + 1] / total)]
			for idx: int in [0, 1, 2, 0, 2, 3]:
				st.set_normal(nrms[idx])
				st.set_uv(uvs[idx])
				st.add_vertex(verts[idx])
	return st.commit()


## A hanging rag: flat two-sided ribbon, `w` wide at the top tapering to a point, `length` long.
static func _ribbon(w: float, length: float, n: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in n + 1:
		var t := float(i) / float(n)
		var hw := w * 0.5 * (1.0 - t * 0.85)
		var twist := sin(t * 2.4) * 0.12
		for s: float in [-1.0, 1.0]:
			st.set_normal(Vector3(0.0, 0.0, -1.0))
			st.set_uv(Vector2(0.5 + s * 0.5, t))
			st.add_vertex(Vector3(s * hw, -t * length, twist))
	return st.commit()


static func _make_mask() -> ArrayMesh:
	var cm := CreatureMesh.new(4141)
	var bone := Color(1, 1, 1)
	var hole := Color(0.05, 0.03, 0.04)
	cm.blob(Vector3(0, 0.06, 0.02), Vector3(0.25, 0.3, 0.24), Basis.IDENTITY, bone, 0.4, 0.06)
	cm.blob(Vector3(0, -0.2, -0.05), Vector3(0.15, 0.22, 0.14), Basis.IDENTITY, bone, 0.4, 0.05)
	for s: float in [-1.0, 1.0]:
		cm.blob(Vector3(s * 0.095, 0.03, -0.2), Vector3(0.07, 0.085, 0.05), Basis(Vector3.FORWARD, s * 0.35), hole, 0.0, 0.0, 0.0, 6, 8)
		cm.blob(Vector3(s * 0.11, -0.13, -0.15), Vector3(0.05, 0.08, 0.05), Basis.IDENTITY, hole, 0.0, 0.0, 0.0, 5, 7)
		# swept horns of the crown
		cm.tube(PackedVector3Array([Vector3(s * 0.16, 0.26, 0.04), Vector3(s * 0.3, 0.5, 0.12), Vector3(s * 0.36, 0.78, 0.28), Vector3(s * 0.3, 0.98, 0.5)]),
			PackedFloat32Array([0.05, 0.04, 0.025, 0.006]), 6, bone, 0.6, 0.05)
	for k in 5:
		var x := (float(k) - 2.0) * 0.07
		cm.tube(PackedVector3Array([Vector3(x, 0.3, 0.0), Vector3(x * 1.3, 0.48 + 0.1 * (2.0 - absf(float(k) - 2.0)), 0.04)]),
			PackedFloat32Array([0.025, 0.004]), 5, bone, 0.6, 0.0)
	cm.blob(Vector3(0, -0.36, -0.09), Vector3(0.09, 0.05, 0.07), Basis.IDENTITY, hole, 0.0, 0.0, 0.0, 5, 7)
	return cm.commit()


## Long skeletal arm hanging along -Y from the shoulder, with four long fingers.
static func _make_arm() -> ArrayMesh:
	var cm := CreatureMesh.new(4242)
	cm.limb(Vector3(0, 0, 0), Vector3(0, -1.05, -0.08), 0.06, 0.045, Color.WHITE, Vector3(0, 0, -0.08), 0.08)
	cm.limb(Vector3(0, -1.05, -0.08), Vector3(0, -2.0, -0.02), 0.045, 0.035, Color.WHITE, Vector3(0, 0, 0.05), 0.06)
	for f in 4:
		var spread := (float(f) - 1.5) * 0.07
		cm.claw(Vector3(spread, -2.02, -0.02), Vector3(spread * 1.5, -1.0, -0.35).normalized(), 0.52 - 0.06 * absf(float(f) - 1.5), 0.022, Vector3(0, 0, -0.08), Color(0.85, 0.8, 0.72))
	return cm.commit()


static func _make_shard() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(0, 0.55, 0)
	var bot := Vector3(0, -0.3, 0)
	var ring: Array[Vector3] = [Vector3(0.09, 0, 0), Vector3(0, 0, 0.05), Vector3(-0.09, 0, 0), Vector3(0, 0, -0.05)]
	for i in 4:
		var a := ring[i]
		var b := ring[(i + 1) % 4]
		for tri: Array in [[top, a, b], [bot, b, a]]:
			var v0: Vector3 = tri[0]
			var v1: Vector3 = tri[1]
			var v2: Vector3 = tri[2]
			var n := (v1 - v0).cross(v2 - v0).normalized()
			if n.dot((v0 + v1 + v2) / 3.0) < 0.0:
				n = -n
			for v: Vector3 in [v0, v2, v1]:
				st.set_normal(n)
				st.add_vertex(v)
	return st.commit()


# --- assembly -------------------------------------------------------------------------------

func _skin(mesh: Mesh, mat: Material, parent: Node3D, at := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 2.0
	parent.add_child(mi)
	_skins.append(mi)
	return mi


func _build_body() -> void:
	_skin(_shroud_mesh, _mat("shroud"), _body)
	# the void inside the hood, and the mask floating in it
	var void_mesh := SphereMesh.new()
	void_mesh.radius = 0.6
	void_mesh.height = 1.15
	void_mesh.radial_segments = 14
	void_mesh.rings = 8
	_skin(void_mesh, _mat("void"), _body, Vector3(0, 1.72, 0.08))
	_mask = Node3D.new()
	_mask.position = Vector3(0, 1.7, -0.42)
	_mask.scale = Vector3.ONE * 1.65
	_body.add_child(_mask)
	_skin(_mask_mesh, _mat("bone"), _mask)
	var eye := SphereMesh.new()
	eye.radius = 0.028
	eye.height = 0.056
	for s: float in [-1.0, 1.0]:
		_skin(eye, _mat("eye"), _mask, Vector3(s * 0.095, 0.03, -0.215))
		var sparks := Vfx.emitter(Color(3.0, 0.9, 0.3), {"count": 10, "life": 0.9, "speed": Vector2(0.05, 0.3), "size": 0.02, "gravity": -0.6, "trail": 0.12, "radius": 0.02})
		sparks.position = Vector3(s * 0.095, 0.03, -0.22)
		_mask.add_child(sparks)
		sparks.emitting = true
	_eye_light = OmniLight3D.new()
	_eye_light.light_color = Color(1.0, 0.45, 0.15)
	_eye_light.omni_range = 2.2
	_eye_light.light_energy = 0.6
	_eye_light.position = Vector3(0, 0.0, -0.9)     # throws ember light forward, keeps the bone pale
	_eye_light.set_meta(&"light_class", "fill")
	_mask.add_child(_eye_light)
	# rags trailing from the hem
	for i in 9:
		var a := TAU * float(i) / 9.0 + 0.2
		var r := 1.35 + 0.15 * float(i % 2)
		var rag := _skin(_rag_meshes[i % 3], _mat("rag"), _body, Vector3(sin(a) * r, -1.45 - 0.1 * float(i % 3), -cos(a) * r))
		rag.rotation.y = -a                  # plane tangent to the hem, facing outward
	# arms from inside the sleeves
	for s: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(s * 1.12, 0.85, -0.62)     # out of the sleeves, in front
		pivot.rotation = Vector3(0.62, 0.0, s * 0.1)
		_body.add_child(pivot)
		_skin(_arm_mesh, _mat("bone"), pivot)
		_arms.append(pivot)
	# halo of shards behind the head
	_halo = Node3D.new()
	_halo.position = Vector3(0, 1.85, 0.55)
	_body.add_child(_halo)
	for i in 11:
		var a := TAU * float(i) / 11.0
		var shard := _skin(_shard_mesh, _mat("shard"), _halo, Vector3(cos(a), sin(a), 0.0) * 1.35)
		shard.rotation.z = a - PI * 0.5
		shard.scale = Vector3.ONE * (0.9 + 0.5 * float((i * 7) % 3) / 2.0)


func _build_presence() -> void:
	_core_light = OmniLight3D.new()
	_core_light.light_color = Color(0.55, 0.3, 1.0)
	_core_light.omni_range = 9.0
	_core_light.light_energy = 2.0
	_core_light.position = Vector3(0, -2.6, -0.4)
	_core_light.set_meta(&"light_class", "fill")
	_body.add_child(_core_light)
	# dark cloud swallowing the lower body (volumetric fog is on in every night's environment)
	var fog := FogVolume.new()
	fog.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	fog.size = Vector3(5.5, 5.0, 5.5)
	fog.position = Vector3(0, -2.2, 0)
	var fm := FogMaterial.new()
	fm.density = 0.55
	fm.albedo = Color(0.0, 0.0, 0.01)
	fm.edge_fade = 0.9
	fog.material = fm
	add_child(fog)
	# a pool of shadow cast straight down onto whatever is beneath
	_pool = Decal.new()
	_pool.size = Vector3(7.0, 14.0, 7.0)
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(0.5, 0.0)
	g.width = 64
	g.height = 64
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 0.92), Color(0, 0, 0.02, 0.6), Color(0, 0, 0, 0)])
	g.gradient = grad
	_pool.texture_albedo = g
	_pool.albedo_mix = 1.0
	_pool.upper_fade = 0.15
	_pool.lower_fade = 0.3
	_pool.top_level = true
	add_child(_pool)
	# smoke shed from the hem
	var smoke := Vfx.emitter(Color(0.015, 0.008, 0.04, 0.6), {"count": 36, "life": 2.2, "speed": Vector2(0.1, 0.5), "size": 1.0, "gravity": 0.5, "radius": 1.3, "additive": false, "turbulence": true})
	smoke.position = Vector3(0, -1.4, 0)
	_body.add_child(smoke)
	smoke.emitting = true
	var embers := Vfx.emitter(Color(2.6, 0.75, 0.22), {"count": 18, "life": 1.4, "speed": Vector2(0.1, 0.6), "size": 0.03, "gravity": -1.2, "radius": 1.4, "trail": 0.08})
	embers.position = Vector3(0, -1.6, 0)
	_body.add_child(embers)
	embers.emitting = true


func _build_hurtbox() -> void:
	var hb := StaticBody3D.new()
	hb.name = "Hurt"
	hb.collision_layer = Layers.HURTBOX
	hb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 1.2
	cap.height = 4.2
	cs.shape = cap
	cs.position = Vector3(0.0, 0.2, 0.0)
	hb.add_child(cs)
	add_child(hb)


## Tearing in: a tall rift, a shock dome, a roar, and the body unfolding out of the dark.
func _arrive() -> void:
	SpellFx.tear(global_position + Vector3.DOWN * 3.0, 7.5, 1.6)
	SpellFx.shell(global_position, 0.5, 6.0, Color(0.8, 0.3, 2.2), 0.6)
	Vfx.burst(global_position, Color(0.01, 0.0, 0.03, 0.9), {"count": 60, "life": 1.6, "speed": Vector2(2.0, 6.0), "size": 1.1, "gravity": 0.0, "damping": 3.0, "additive": false, "turbulence": true})
	Sfx.play(SFX_ROAR, global_position, 2.0, 0.42, 0.02)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_body, "scale", Vector3.ONE, 1.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_dissolve, 1.0, 0.0, 1.3)
	if is_instance_valid(target):
		target.kick(0.9)


func _set_dissolve(v: float) -> void:
	for gi in _skins:
		if is_instance_valid(gi) and gi.material_override is ShaderMaterial:
			gi.set_instance_shader_parameter(&"dissolve", v)


# --- behaviour ------------------------------------------------------------------------------

func take_hit(_dmg: float, _from: Node = null) -> void:
	if is_instance_valid(target):
		target.note_shade_bolt()
	dissipate()


func _process(delta: float) -> void:
	_t += delta
	# slow heavy bob, lean into the drift, halo turns, mask tracks you
	_body.position.y = sin(_t * 0.9) * 0.28
	var lean := clampf(_vel.length() / maxf(speed, 0.1), 0.0, 1.0) * 0.22
	_body.rotation.x = lerpf(_body.rotation.x, -lean, 1.0 - exp(-3.0 * delta))
	_halo.rotation.z += delta * 0.35
	_core_light.light_energy = 1.7 + 0.6 * sin(_t * 2.6) + 0.3 * sin(_t * 7.1)
	_eye_light.light_energy = 0.5 + 0.2 * sin(_t * 9.0)
	_reach = move_toward(_reach, _reach_goal(), delta * 1.6)
	for i in _arms.size():
		var s := -1.0 if i == 0 else 1.0
		var sway := sin(_t * 1.3 + float(i) * 1.7) * 0.08
		_arms[i].rotation = Vector3(lerpf(0.62, 1.4, _reach) + sway, s * lerpf(0.0, -0.35, _reach), s * lerpf(0.1, 0.24, _reach))
	if is_instance_valid(target):
		var look := target.global_position + Vector3.UP * 1.4
		if _mask.global_position.distance_squared_to(look) > 0.01:
			var m := _mask.global_transform.looking_at(look, Vector3.UP)
			_mask.global_basis = _mask.global_basis.orthonormalized().slerp(m.basis.orthonormalized(), 1.0 - exp(-4.0 * delta))
	# the pool of shadow follows the ground under it
	_pool.global_position = global_position + Vector3.DOWN * 3.0
	if _whisper and is_instance_valid(target):
		_whisper.volume_db = linear_to_db(clampf(target.gloom / maxf(target.gloom_max, 1.0), 0.08, 1.0)) - 4.0


func _reach_goal() -> float:
	if not is_instance_valid(target):
		return 0.0
	var d := Vector2(global_position.x - target.global_position.x, global_position.z - target.global_position.z).length()
	return clampf(1.0 - (d - REACH) / 7.0, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if _dying or not is_instance_valid(target):
		return
	var goal := target.global_position + Vector3.UP * HOVER
	if _blocked_t >= 2.5:
		var around := _ring_goal(target)
		goal = around if around != Vector3.ZERO else goal + Vector3.UP * 3.0
	var to := goal - global_position
	var near := Vector2(global_position.x - target.global_position.x, global_position.z - target.global_position.z).length()
	_tremble(near, delta)
	if near < REACH and absf(global_position.y - target.global_position.y - HOVER) < 2.5:
		if target.is_evading():
			return
		if not _blocked(target):
			_take(target)
			return
		_blocked_t += delta
		return
	if _blocked(target):
		_blocked_t += delta
	else:
		_blocked_t = maxf(0.0, _blocked_t - delta * 2.0)
	var d := to.length()
	var v := to / maxf(d, 0.001) * minf(speed, d / maxf(delta, 0.001))
	_vel = _vel.lerp(v, 1.0 - exp(-4.0 * delta))
	global_position += _vel * delta
	if Vector2(to.x, to.z).length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-3.0 * delta))
	if LightGrid.is_lit(global_position) or LightGrid.is_lit(global_position + Vector3.DOWN * HOVER):
		dissipate()


## Camera tremor grows as it closes; the player feels it before they see it.
func _tremble(near: float, delta: float) -> void:
	_tremor_t -= delta
	if _tremor_t > 0.0 or near > PRESENCE_R:
		return
	_tremor_t = 0.22
	target.kick(0.12 * clampf(1.0 - near / PRESENCE_R, 0.0, 1.0))


func _take(player: Player) -> void:
	_dying = true
	_reach = 1.0
	Vfx.burst(player.global_position + Vector3.UP * 1.0, Color(0.01, 0.0, 0.03, 0.95), {"count": 50, "life": 1.0, "speed": Vector2(1.0, 4.0), "size": 0.8, "gravity": 0.0, "radial": -4.0, "additive": false, "radius": 1.6})
	Sfx.play(SFX_ROAR, global_position, 0.0, 0.36, 0.02)
	player.hollow()
	_unmake(0.8)


func _blocked(player: Player) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var q := PhysicsRayQueryParameters3D.create(global_position, player.global_position + Vector3.UP * 0.9)
	q.collision_mask = Layers.WORLD
	return not space.intersect_ray(q).is_empty()


func _ring_goal(player: Player) -> Vector3:
	var space := get_world_3d().direct_space_state
	if space == null:
		return Vector3.ZERO
	var best := Vector3.ZERO
	var best_d := INF
	var origin := player.global_position + Vector3.UP * (HOVER + 2.0)
	for i in 8:
		var a := TAU * float(i) / 8.0
		var p := origin + Vector3(cos(a), 0.0, sin(a)) * 2.6
		var q := PhysicsRayQueryParameters3D.create(p, player.global_position + Vector3.UP * 0.9)
		q.collision_mask = Layers.WORLD
		if space.intersect_ray(q).is_empty():
			var d := global_position.distance_squared_to(p)
			if d < best_d:
				best_d = d
				best = p
	return best


## Light unmakes it: the shroud burns away from the hem up, the halo bursts outward.
func dissipate() -> void:
	if _dying:
		return
	_dying = true
	SpellFx.implosion(global_position + Vector3.DOWN * 0.9, 4.0)
	Vfx.burst(global_position + Vector3.UP * 1.8, Color(0.6, 0.25, 1.4), {"count": 40, "life": 0.9, "speed": Vector2(4.0, 9.0), "size": 0.06, "gravity": -3.0, "trail": 0.12})
	Sfx.play(SFX_ROAR, global_position, -2.0, 0.6, 0.02)
	_unmake(0.9)


func _unmake(time: float) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_method(_set_dissolve, 0.0, 1.0, time)
	tw.tween_property(_halo, "scale", Vector3.ONE * 2.2, time).set_ease(Tween.EASE_OUT)
	tw.tween_property(_core_light, "light_energy", 0.0, time)
	tw.tween_property(_body, "scale", Vector3(1.15, 0.6, 1.15), time).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)
