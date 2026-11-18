extends CharacterRig
## A rig whose motion is AUTHORED: a modelled skeleton and keyframed clips made in Blender (a glb with a
## Skeleton3D, a skinned mesh and an AnimationPlayer), played back here. It answers the same calls Enemy makes on
## the procedural rigs (animate / telegraph / strike / flinch / stagger / howl / collapse / socket / muzzle), so a
## boss changes rig without its fight changing. The procedural rigs pose ~16 rigid joints by formula; a boss that
## fills the screen needs a spine, a jaw, a tail and cloth that follow through, and anticipation and recovery that
## somebody drew.
## No class_name (project rule): const ClipRig := preload("res://core/enemy/clip_rig.gd")
##
## Clips (any may be missing; the rig falls back to the nearest it has):
##   idle, walk, run          loops; walk and run are played at the pace of the ground covered (no skating)
##   windup, windup_hold      the tell: windup is stretched to the telegraph's length, then the hold loops
##   strike                   the blow and its recovery, back to idle
##   stagger                  the reel, for as long as the punish window
##   howl                     a call that is not an attack
##   air, land                a pounce in flight and its landing
##   death                    falls and stays down
## Sockets are bone attachments: `socket_bones` maps the names the game asks for to bones in the model.

const GruntModel := preload("res://core/enemy/grunt_model.gd")
const BossLook := preload("res://core/enemy/boss_look.gd")
const DwarfLook := preload("res://core/npc/dwarf_look.gd")
const VillagerBossRig := preload("res://core/enemy/villager_boss_rig.gd")
## The glowing parts of a villager-look model (eyes, flames, the reliquary): its sRGB vertex colour, bright, unlit.
## No instance uniforms here: a surface's own would take other slots than the flesh overlay's on the same mesh, and the
## overlay then read its dissolve from a slot nobody writes (the Abbot drew as a gold ghost when it held junk).
const GLOW_CODE := """
shader_type spatial;
render_mode unshaded, shadows_disabled;
void fragment() {
	vec3 c = COLOR.rgb;
	c = mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
	ALBEDO = c * 2.4;
}
"""

var scene_path := ""
## The model is built geometry with named surfaces (tools/blender/boss_build.py), not a baked atlas body.
var built := false
## Game socket name -> bone name. Names missing here are looked up as bones of the same name.
var socket_bones := {}
## Metres of ground one loop of the clip covers at speed scale 1 (measured in Blender from the feet).
var walk_stride := 1.6
var run_stride := 3.2
## Ground speed (m/s, unscaled by the boss's size) at which the walk gives way to the run.
var run_at := 5.0
## The model's own facing: glb exports here face -Z, as the rigs do.
var model_yaw := 0.0
## The model is authored for the villagers' shader (tools/blender/vb_kit.py: COLOR = sRGB tint and AO, UV in metres,
## UV2.x = material layer; a surface named "glow" is lit), so it wears their look, not an atlas.
var villager_look := false

var _model: Node3D
var _skeleton: Skeleton3D
var _anim: AnimationPlayer
var _meshes: Array[MeshInstance3D] = []
var _state := &"idle"
var _lock_t := 0.0            ## seconds a one-shot still owns the body
var _hold := &""              ## the loop a one-shot hands over to (windup -> windup_hold)
var _dead := false
var _flinch := 0.0
var _flinch_side := 0.0
var _airborne := false
var _size := 1.0
var _sock_bone: PackedInt32Array = PackedInt32Array()
var _sock_node: Array[Node3D] = []
var _sock_rest: Array[Basis] = []


## Put an enemy on a clip rig: what its _build did with attach_rig() and EnemyBody.dress(), for a modelled skeleton.
## opts: walk_stride, run_stride, run_at, scale (Vector3, the kind's own proportions), cap (collision height factor).
static func fit(e: Node, scene: String, kind: StringName, bones: Dictionary, opts := {}) -> CharacterRig:
	var rig: CharacterRig = (load("res://core/enemy/clip_rig.gd") as GDScript).new()
	rig.set("scene_path", scene)
	rig.set("socket_bones", bones)
	rig.set("walk_stride", float(opts.get("walk_stride", 1.0)))
	rig.set("run_stride", float(opts.get("run_stride", 2.0)))
	rig.set("run_at", float(opts.get("run_at", 99.0)))
	rig.set("built", bool(opts.get("built", false)))
	rig.set("villager_look", bool(opts.get("villager_look", false)))
	var en: Variant = e
	en.attach_rig(rig)
	rig.scale = opts.get("scale", Vector3.ONE)
	var col := e.get_node_or_null("Collision") as CollisionShape3D
	if col and col.shape is CapsuleShape3D and opts.has("cap"):
		var cap := col.shape as CapsuleShape3D
		cap.height = 1.7 * float(opts.cap)
		col.position.y = cap.height * 0.5
	var r: Variant = rig
	en.set_flesh(r.dress(kind))
	return rig


func _build() -> void:
	_sockets.clear()
	_equipped.clear()
	var ps := load(scene_path) as PackedScene if scene_path != "" else null
	if ps == null:
		push_error("ClipRig: no model at '%s'" % scene_path)
		_pelvis = ProcMesh.node(self, "Pelvis", Vector3(0, 0.9, 0))
		_chest = _pelvis
		_head = _pelvis
		for n: String in ["pelvis", "chest", "head", "body", "front"]:
			_sockets[n] = _pelvis
		return
	_model = ps.instantiate() as Node3D
	_model.name = "Model"
	_model.rotation.y = model_yaw
	add_child(_model)
	for n in _model.find_children("*", "Skeleton3D", true, false):
		_skeleton = n as Skeleton3D
	for n in _model.find_children("*", "AnimationPlayer", true, false):
		_anim = n as AnimationPlayer
	for n in _model.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(n as MeshInstance3D)
	if _skeleton != null:
		var want := {"pelvis": "", "chest": "", "head": "", "body": "", "front": "", "tail": "", "hand_r": "", "hand_l": ""}
		for k: String in socket_bones:
			want[k] = socket_bones[k]
		for k: String in want:
			var bone: String = want[k] if want[k] != "" else k
			var idx := _skeleton.find_bone(bone)
			if idx < 0:
				continue
			# a socket is a joint in RIG axes (what the procedural rigs gave): it sits on the bone and turns with
			# it, but at rest it is unrotated, so an offset written for the old rigs still points the same way
			var at := Node3D.new()
			at.name = "Socket_" + k
			add_child(at)
			_sockets[k] = at
			_sock_bone.append(idx)
			_sock_node.append(at)
			_sock_rest.append(_skeleton.get_bone_global_rest(idx).basis.orthonormalized().inverse())
		_place_sockets()
	# the three joints the base class and Enemy read; fall back along the chain so none is null
	_pelvis = (_sockets.get("pelvis", _sockets.get("body", _model)) as Node3D)
	_chest = (_sockets.get("chest", _sockets.get("front", _pelvis)) as Node3D)
	_head = (_sockets.get("head", _chest) as Node3D)
	for k: String in ["pelvis", "chest", "head", "body", "front"]:
		if not _sockets.has(k):
			_sockets[k] = _chest if k in ["chest", "front"] else (_head if k == "head" else _pelvis)
	if _anim != null:
		_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		clip_rate = _authored_rate()
		for nm: String in _anim.get_animation_list():
			if nm in ["idle", "walk", "run", "air"] or nm.ends_with("_hold"):
				_anim.get_animation(nm).loop_mode = Animation.LOOP_LINEAR
		_play(&"idle", 0.0)
	_spring_cloth()


## Cloth that moves: a model with spring chains (bones "<family><i>_<seg>", the old boss_humanoid_anim.py pipeline: the clips
## leave them at rest) gets a SpringBoneSimulator3D over them, so a cloak lags a turn, swings with the stride and the
## blow and settles after, and bell sleeves fall back down raised arms. Capsules on the trunk, legs and arms keep the
## cloth outside the body; a plane at the feet catches it when he falls. Rig units (the model's own scale).
## Held near the root and loose at the end: stiffer through the length, a cloak swung back to the chest's angle and
## flipped over the hood when he bent into a blow, and stood up when he lay dead.
const CLOTH_FAMILIES := [
	# [family, stiffness, at the root, at the end, drag, gravity, at the root, at the end, joint radius, colliders]
	# Each family meets only what it can touch: the cloak's top joints sit on the shoulders, and with the arm capsules
	# every swing of an arm shoved them out into a slab; a sleeve's chains start on the forearm they hang round.
	["cape", 0.9, 1.0, 0.25, 0.78, 2.4, 0.35, 1.0, 0.035, ["hips", "spine", "chest", "ground"]],
	["slv_l", 0.7, 1.0, 0.3, 0.65, 1.8, 0.6, 1.0, 0.025, ["chest", "spine", "upper_l", "ground"]],
	["slv_r", 0.7, 1.0, 0.3, 0.65, 1.8, 0.6, 1.0, 0.025, ["chest", "spine", "upper_r", "ground"]],
]
const CLOTH_COLLIDERS := [
	# the trunk's capsules sit inside the cloth's chains (they stand at 0.9 of the cloth's reach, about 0.18 out): at
	# 0.17-0.19 the chains started inside them and were shoved out, a slab of cloak held up through a lunge
	["hips", 0.12, 0.0, 0.1], ["spine", 0.11, 0.18, 0.09], ["chest", 0.13, 0.24, 0.12],
	["thigh_l", 0.13, 0.42, 0.21], ["thigh_r", 0.13, 0.42, 0.21], ["shin_l", 0.11, 0.42, 0.21], ["shin_r", 0.11, 0.42, 0.21],
	["upper_l", 0.09, 0.32, 0.16], ["upper_r", 0.09, 0.32, 0.16], ["fore_l", 0.07, 0.3, 0.15], ["fore_r", 0.07, 0.3, 0.15],
]   # [bone, radius, length (0: a sphere), offset along the bone]
var _springs: SpringBoneSimulator3D
const Smooth := preload("res://core/enemy/pose_smooth.gd")
var _flinch_v := 0.0                              ## the flinch is a critically damped spring (a blow kicks its speed)
var _dt := 0.0
var _pace_s := 1.0                                ## the clip's speed, smoothed: the ground speed is noisy tick to tick
# the skeleton as of the last two ticks (bone poses are not physics-interpolated; a model posed at 60 Hz steps on a faster screen)
var _bc_rot: Array[Quaternion] = []
var _bp_rot: Array[Quaternion] = []
var _bc_pos := PackedVector3Array()
var _bp_pos := PackedVector3Array()
var _bone_frame := -10
var _bone_primed := false
var _hold_forever := false                        ## the held clip after a boss move stays until the next call
## Authored seconds per glb second. tools/blender/vb_kit.py keys every clip at FPS = 30 (frame 1 + t * 30) in a Blender scene
## that exports at 24 frames a second, so each glb clip is 30/24 of the length it was keyed at (the abbot's 6 s idle is
## 7.54 s). The fights are timed to the authored seconds (the Crown's verdict jolts at 1.4/2.3/3.2 s, its rings land
## then), so the rig plays at this rate (_authored_rate: 1.0 again for a model exported at the rate it was keyed).
var clip_rate := 1.0


func _spring_cloth() -> void:
	if _skeleton == null:
		return
	var chains: Array = []                 # [root name, end name, family row]
	for fam: Array in CLOTH_FAMILIES:
		var k := 0
		while _skeleton.find_bone("%s%d_0" % [fam[0], k]) >= 0:
			var last := 0
			while _skeleton.find_bone("%s%d_%d" % [fam[0], k, last + 1]) >= 0:
				last += 1
			chains.append(["%s%d_0" % [fam[0], k], "%s%d_%d" % [fam[0], k, last], fam])
			k += 1
	if chains.is_empty():
		return
	var sb := SpringBoneSimulator3D.new()
	sb.name = "Cloth"
	_skeleton.add_child(sb)
	sb.setting_count = chains.size()
	for k in chains.size():
		var ch: Array = chains[k]
		var fam: Array = ch[2]
		sb.set_root_bone_name(k, ch[0])
		sb.set_end_bone_name(k, ch[1])
		sb.set_extend_end_bone(k, true)
		sb.set_end_bone_direction(k, SpringBoneSimulator3D.BONE_DIRECTION_FROM_PARENT)
		sb.set_end_bone_length(k, _skeleton.get_bone_rest(_skeleton.find_bone(ch[1])).origin.length())
		sb.set_radius(k, fam[8])
		sb.set_stiffness(k, fam[1])
		sb.set_stiffness_damping_curve(k, _ramp(fam[2], fam[3]))
		sb.set_drag(k, fam[4])
		sb.set_gravity(k, fam[5])
		sb.set_gravity_damping_curve(k, _ramp(fam[6], fam[7]))
		if _skeleton.find_bone("hips") >= 0:
			# simulated about the hips, not the world: in world space a lunge left the hem behind and the chain flung
			# it up to hip height (the hem rose 0.6 in a strike); the body's turns, bends and gravity still swing it
			sb.set_center_from(k, SpringBoneSimulator3D.CENTER_FROM_BONE)
			sb.set_center_bone_name(k, "hips")
	for c: Array in CLOTH_COLLIDERS:
		if _skeleton.find_bone(c[0]) < 0:
			continue
		var col: SpringBoneCollision3D
		if float(c[2]) > 0.0:
			var cap := SpringBoneCollisionCapsule3D.new()
			cap.set_radius(c[1])
			cap.set_height(float(c[2]) + 2.0 * float(c[1]))
			col = cap
		else:
			var sp := SpringBoneCollisionSphere3D.new()
			sp.set_radius(c[1])
			col = sp
		col.name = c[0]
		sb.add_child(col)
		col.set_bone_name(c[0])
		col.set_position_offset(Vector3(0.0, c[3], 0.0))
	var ground := SpringBoneCollisionPlane3D.new()
	ground.name = "ground"
	sb.add_child(ground)
	ground.position.y = -0.04          # under the hem's joints (on the floor, with their radius they sat inside it, and
	                                   # a dropped stance shoved the cloak's whole lower panel up and out like a slab)
	for k in chains.size():
		var want: Array = (chains[k][2] as Array)[9]
		var paths: Array[NodePath] = []
		for nm: String in want:
			if sb.has_node(nm):
				paths.append(sb.get_path_to(sb.get_node(nm)))
		sb.set_enable_all_child_collisions(k, false)
		sb.set_collision_count(k, paths.size())
		for i in paths.size():
			sb.set_collision_path(k, i, paths[i])
	_springs = sb


## A curve from `a` at the root of a chain to `b` at its end (a damping curve multiplies a setting along the chain).
static func _ramp(a: float, b: float) -> Curve:
	var c := Curve.new()
	c.max_value = maxf(1.0, maxf(a, b))
	c.add_point(Vector2(0.0, a))
	c.add_point(Vector2(1.0, b))
	return c


## The skinned meshes wearing the kind's material (flash, glint, dissolve): what Enemy.set_flesh wants.
func dress(kind: StringName) -> Array[MeshInstance3D]:
	if villager_look:
		return _dress_villager()
	# a BUILT model names its surfaces (wool, trim, bone...) and wears tiling materials; a baked one wears its atlas
	if built and BossLook.has(kind) and not (GruntModel.KINDS.has(kind) and ResourceLoader.exists(GruntModel._tex(kind, "albedo"))):
		return BossLook.dress(kind, _meshes)
	var mat := GruntModel.material(kind) if GruntModel.has(kind) else null
	var phase := randf() * TAU
	for mi in _meshes:
		if mat != null:
			mi.material_override = mat
			mi.set_instance_shader_parameter(&"pulse_phase", phase)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return _meshes


static var _glow_mat: ShaderMaterial
static var _fx_mat: ShaderMaterial


## The villagers' boss material on the body, the glow surface lit, and the flesh overlay (hit flash, glint, dissolve).
func _dress_villager() -> Array[MeshInstance3D]:
	if _glow_mat == null:
		var gs := Shader.new()
		gs.code = GLOW_CODE
		_glow_mat = ShaderMaterial.new()
		_glow_mat.shader = gs
		var fs := Shader.new()
		fs.code = VillagerBossRig.FX_CODE
		_fx_mat = ShaderMaterial.new()
		_fx_mat.shader = fs
	for mi in _meshes:
		var mesh := mi.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var sm := mesh.surface_get_material(i)
			var nm: String = (sm.resource_name if sm != null else "") + " " + mesh.surface_get_name(i)
			mi.set_surface_override_material(i, _glow_mat if nm.contains("glow") else DwarfLook.material_boss())
		mi.material_overlay = _fx_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return _meshes


## A move of the boss's own (a clip named for it: "toll", "sweep"...), played once over `dur` seconds (its own length
## when 0), then back to the idle. False when the model has no such clip, so the fight falls back to the shared calls.
## `then`: a looping clip held after it until the next move, stagger or strike (a boss rooted for its intermission).
func boss_move(nm: StringName, dur := 0.0, then := &"") -> bool:
	if _dead or not has_clip(nm):
		return false
	_hold = then if then != &"" and has_clip(then) else &""
	_hold_forever = _hold != &""
	var l := _len(nm)
	var d := l if dur <= 0.0 else maxf(dur, 0.2)
	_play(nm, 0.2, l / d)
	_lock_t = d
	return true


func has_clip(nm: StringName) -> bool:
	return _anim != null and _anim.has_animation(nm)


## A clip's length in authored seconds (what the fight times its moves by).
func _len(nm: StringName) -> float:
	return _anim.get_animation(nm).length / clip_rate if has_clip(nm) else 0.0


func _play(nm: StringName, blend := 0.2, speed := 1.0) -> void:
	if _anim == null or not _anim.has_animation(nm):
		return
	_state = nm
	_anim.play(nm, blend * clip_rate, speed)


## 30/24 when the model's clips were keyed at 30 frames a second and exported at 24. The importer moves every first key to 0
## and resamples, so the tell is the lengths: a 24 fps export ends each clip on a whole 24th of a second (1 + the clip's
## frames, over 24); a clip keyed and exported at 30 does that only one time in five. All of them on a 24th: stretched.
func _authored_rate() -> float:
	var n := 0
	for nm: String in _anim.get_animation_list():
		var f := _anim.get_animation(nm).length * 24.0
		if absf(f - roundf(f)) > 0.01:
			return 1.0
		n += 1
	return 1.25 if n >= 4 else 1.0


func animate(vel: Vector3, on_floor: bool, delta: float) -> void:
	if delta <= 0.0:
		return
	_t += delta
	_size = maxf(global_basis.get_scale().y, 0.01)
	_dt = delta
	var sp := Smooth.spring(_flinch, _flinch_v, 0.0, 14.0, delta)
	_flinch = sp.x
	_flinch_v = sp.y
	if _model != null:
		# a hit rocks the whole body off the blow for a moment, on top of whatever clip is playing
		_model.rotation.x = -_flinch * 0.12
		_model.rotation.z = _flinch * _flinch_side * 0.14
	if _anim == null:
		return
	if not _dead:
		_lock_t = maxf(_lock_t - delta, 0.0)
		if _lock_t <= 0.0:
			if _hold != &"":
				_play(_hold, 0.12)
				_hold = &""
				_lock_t = INF if (_state == &"windup_hold" or _hold_forever) else 0.0     # a tell is held until the strike or a stagger ends it
				_hold_forever = false
			elif _state != &"windup_hold":
				_locomote(vel, on_floor)
	_anim.advance(delta * clip_rate)
	_capture_bones()
	_place_sockets()


## Keep the skeleton's last two ticks (after the clip advanced), and draw between them every rendered frame.
func _capture_bones() -> void:
	if _skeleton == null:
		return
	var n := _skeleton.get_bone_count()
	if _bc_rot.size() != n:
		_bc_rot.resize(n)
		_bp_rot.resize(n)
		_bc_pos.resize(n)
		_bp_pos.resize(n)
		_bone_primed = false
	for i in n:
		_bp_rot[i] = _bc_rot[i]
		_bp_pos[i] = _bc_pos[i]
		_bc_rot[i] = _skeleton.get_bone_pose_rotation(i)
		_bc_pos[i] = _skeleton.get_bone_pose_position(i)
		if not _bone_primed:
			_bp_rot[i] = _bc_rot[i]
			_bp_pos[i] = _bc_pos[i]
	_bone_primed = true
	_bone_frame = Engine.get_physics_frames()


func _process(_delta: float) -> void:
	if _dead and villager_look and not _meshes.is_empty():
		var d := float(_meshes[0].get_instance_shader_parameter(&"dissolve"))
		for mi in _meshes:
			mi.transparency = clampf(d * 1.15, 0.0, 1.0)
	if _skeleton == null or not _bone_primed:
		return
	var live := is_physics_interpolated_and_enabled() and Engine.get_physics_frames() - _bone_frame < 2
	var f := Engine.get_physics_interpolation_fraction() if live else 1.0
	for i in _bc_rot.size():
		_skeleton.set_bone_pose_rotation(i, _bp_rot[i].slerp(_bc_rot[i], f))
		_skeleton.set_bone_pose_position(i, _bp_pos[i].lerp(_bc_pos[i], f))


func _place_sockets() -> void:
	if _skeleton == null:
		return
	var rel := global_transform.affine_inverse() * _skeleton.global_transform
	for i in _sock_node.size():
		var xf := rel * _skeleton.get_bone_global_pose(_sock_bone[i])
		_sock_node[i].transform = Transform3D(xf.basis.orthonormalized() * _sock_rest[i], xf.origin)


func _locomote(vel: Vector3, on_floor: bool) -> void:
	if not on_floor and has_clip(&"air"):
		if not _airborne:
			_airborne = true
			_play(&"air", 0.12)
		return
	if _airborne:
		_airborne = false
		if has_clip(&"land"):
			_play(&"land", 0.05)
			_lock_t = _len(&"land")
			return
	# ground speed as the model walks it: a boss three times the size covers three times the ground a stride
	var speed := Vector2(vel.x, vel.z).length() / _size
	var thr := 0.1 if (_state == &"walk" or _state == &"run") else 0.2        # a hysteresis: ground speed hovering at the edge flickered idle and walk
	if speed < thr:
		if _state != &"idle":
			_play(&"idle", 0.3)
		return
	var run := speed >= run_at and has_clip(&"run")
	var nm: StringName = &"run" if run else &"walk"
	var stride := run_stride if run else walk_stride
	var pace := speed * _len(nm) / maxf(stride, 0.01)          # clip loops a second the ground asks for, over the clip's own
	if _state != nm:
		_pace_s = pace
		_play(nm, 0.25, pace)
	else:
		_pace_s = lerpf(_pace_s, pace, 1.0 - exp(-6.0 * _dt))
	_anim.speed_scale = 1.0
	_anim.play(nm, -1.0, clampf(_pace_s, 0.35, 2.2))


func cast(_sound := "") -> void:
	telegraph(maxf(_len(&"windup"), 0.4))


## The tell before a strike, `dur` seconds long: the windup clip stretched or squeezed to fit, then its hold.
func telegraph(dur: float) -> void:
	if _dead:
		return
	var l := _len(&"windup")
	if l <= 0.0:
		return
	dur = maxf(dur, 0.12)
	var rise := minf(l, dur) if has_clip(&"windup_hold") else dur     # with a hold, the rise keeps its own pace when there is time
	_play(&"windup", 0.12, l / rise)
	_lock_t = rise
	_hold = &"windup_hold" if has_clip(&"windup_hold") else &""
	if _hold == &"":
		_lock_t = dur + 0.3


func strike() -> void:
	if _dead:
		return
	_hold = &""
	if has_clip(&"strike"):
		_play(&"strike", 0.04)
		_lock_t = _len(&"strike")
	else:
		_lock_t = 0.0


func howl(dur: float) -> void:
	if _dead or not has_clip(&"howl"):
		return
	_hold = &""
	var l := _len(&"howl")
	_play(&"howl", 0.2, l / maxf(dur, 0.2))
	_lock_t = maxf(dur, 0.2)


func flinch(amount: float, side := 0.0) -> void:
	_flinch_v += clampf(amount, 0.0, 1.0) * 38.0
	_flinch_side = side


func stagger() -> void:
	if _dead:
		return
	_hold = &""
	_flinch_v += 38.0
	if has_clip(&"stagger"):
		_play(&"stagger", 0.08)
		_lock_t = _len(&"stagger")
	else:
		_lock_t = 0.0


func collapse(_back := false) -> void:
	if _dead:
		return
	_dead = true
	_hold = &""
	if has_clip(&"death"):
		_play(&"death", 0.1)


func muzzle() -> Vector3:
	var m := _sockets.get("muzzle", _sockets.get("head")) as Node3D
	return m.global_position if m != null else global_position + Vector3.UP
