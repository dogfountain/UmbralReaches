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

var scene_path := ""
## Game socket name -> bone name. Names missing here are looked up as bones of the same name.
var socket_bones := {}
## Metres of ground one loop of the clip covers at speed scale 1 (measured in Blender from the feet).
var walk_stride := 1.6
var run_stride := 3.2
## Ground speed (m/s, unscaled by the boss's size) at which the walk gives way to the run.
var run_at := 5.0
## The model's own facing: glb exports here face -Z, as the rigs do.
var model_yaw := 0.0

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
		for nm: String in ["idle", "walk", "run", "windup_hold", "air"]:
			if _anim.has_animation(nm):
				_anim.get_animation(nm).loop_mode = Animation.LOOP_LINEAR
		_play(&"idle", 0.0)


## The skinned meshes wearing the kind's material (flash, glint, dissolve): what Enemy.set_flesh wants.
func dress(kind: StringName) -> Array[MeshInstance3D]:
	var mat := GruntModel.material(kind) if GruntModel.has(kind) else null
	var phase := randf() * TAU
	for mi in _meshes:
		if mat != null:
			mi.material_override = mat
			mi.set_instance_shader_parameter(&"pulse_phase", phase)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return _meshes


func has_clip(nm: StringName) -> bool:
	return _anim != null and _anim.has_animation(nm)


func _len(nm: StringName) -> float:
	return _anim.get_animation(nm).length if has_clip(nm) else 0.0


func _play(nm: StringName, blend := 0.2, speed := 1.0) -> void:
	if _anim == null or not _anim.has_animation(nm):
		return
	_state = nm
	_anim.play(nm, blend, speed)


func animate(vel: Vector3, on_floor: bool, delta: float) -> void:
	if delta <= 0.0:
		return
	_t += delta
	_size = maxf(global_basis.get_scale().y, 0.01)
	_flinch = move_toward(_flinch, 0.0, delta * 3.0)
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
				_lock_t = INF if _state == &"windup_hold" else 0.0     # a tell is held until the strike or a stagger ends it
			elif _state != &"windup_hold":
				_locomote(vel, on_floor)
	_anim.advance(delta)
	_place_sockets()


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
	if speed < 0.15:
		if _state != &"idle":
			_play(&"idle", 0.3)
		return
	var run := speed >= run_at and has_clip(&"run")
	var nm: StringName = &"run" if run else &"walk"
	var stride := run_stride if run else walk_stride
	var pace := speed * _len(nm) / maxf(stride, 0.01)          # clip loops a second the ground asks for, over the clip's own
	if _state != nm:
		_play(nm, 0.25, pace)
	_anim.speed_scale = 1.0
	_anim.play(nm, -1.0, clampf(pace, 0.35, 2.2))


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
	_flinch = clampf(maxf(_flinch, amount), 0.0, 1.0)
	_flinch_side = side


func stagger() -> void:
	if _dead:
		return
	_hold = &""
	_flinch = 1.0
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
