extends Node
## Poses a grunt's skinned body (GruntModel) from its rig: every bone follows the socket of the same
## name. The bones are flat (no parents) and rest on their sockets, so a bone's pose is simply its
## socket in skeleton space times the bone's rest basis. Runs after the rig has animated (Enemy
## animates in _physics_process; this runs in _process), skipped while the body is off screen.
## Load by path (no class_name): const GruntSkin := preload("res://core/enemy/grunt_skin.gd")

var skel: Skeleton3D
var body: MeshInstance3D
var _socks: Array[Node3D] = []
var _bases: Array[Transform3D] = []
var _bones: PackedInt32Array = PackedInt32Array()
var _rig: CharacterRig
## A sleeping enemy (process disabled: out of its sleep range, ~90% of the camps at any spot) does
## not move its sockets, so its pose is skipped unless its rig was animated by hand since (every
## animate() advances the rig's clock `_t`). A few frames after it falls asleep, and every
## REFRESH frames after that, it is posed anyway (anything that set a socket without animate()).
## 140 grunts asleep in view cost ~0.4 ms/frame before.
const REFRESH := 30
var _posed_t := -1.0
var _asleep_frames := 0


func setup(s: Skeleton3D, rig: CharacterRig, mesh: MeshInstance3D) -> void:
	skel = s
	body = mesh
	_rig = rig
	for i in skel.get_bone_count():
		var sock := rig.socket(skel.get_bone_name(i))
		if sock == null:
			continue
		_bones.append(i)
		_socks.append(sock)
		_bases.append(Transform3D(skel.get_bone_global_rest(i).basis, Vector3.ZERO))
	process_priority = 100
	# a sleeping enemy disables its subtree, but its rig can still be posed by hand (the studio, a
	# cutscene): follow the sockets whenever they move
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pose()


func _process(_delta: float) -> void:
	if body and not body.is_visible_in_tree():
		return
	if _rig != null and not _rig.can_process():
		_asleep_frames += 1
		if _rig._t == _posed_t and _asleep_frames > 3 and (_asleep_frames + get_instance_id()) % REFRESH != 0:
			if _shown < 0.999:
				_blend()                 # posed by hand on the tick: still draw the in-between
			return
	else:
		_asleep_frames = 0
	# a new pose from animate(); or, a few ticks on without one, whatever set the sockets by hand
	if _rig == null or _rig._t != _posed_t or Engine.get_physics_frames() - _cap_tick >= 3:
		_capture()
	_blend()


## r36 smooth: the rig poses on the physics tick (every other tick past 16 m), but the screen
## draws at its own rate. Keep the last two posed ticks in skeleton space and draw the blend
## for the moment the renderer is showing (the same time the interpolated body is at), so a
## grunt's limbs move at the display's rate instead of stepping at 60 (or 30) Hz.
var _prev: Array[Transform3D] = []
var _cur: Array[Transform3D] = []
var _prev_tick := -1
var _cap_tick := -1
var _shown := -1.0                     ## the last blend drawn (1 = cur); skip redrawing a held pose


func _capture() -> void:
	if skel == null:
		return
	if _rig != null:
		_posed_t = _rig._t
	var n := _bones.size()
	if _cur.size() != n:
		_cur.resize(n)
		_prev.resize(n)
		_cap_tick = -1
	var inv := skel.global_transform.affine_inverse()
	var tick := Engine.get_physics_frames()
	var fresh := _cap_tick < 0 or tick - _cap_tick > 4 or tick <= _cap_tick
	for k in n:
		var sock := _socks[k]
		var t := inv * sock.global_transform * _bases[k] if is_instance_valid(sock) else _cur[k]
		_prev[k] = t if fresh else _cur[k]
		_cur[k] = t
	_prev_tick = tick - 1 if fresh else _cap_tick
	_cap_tick = tick
	_shown = -1.0


func _blend() -> void:
	if _cur.is_empty():
		return
	var a := 1.0
	if is_inside_tree() and skel.is_physics_interpolated_and_enabled() and not Engine.is_in_physics_frame():
		var span := float(_cap_tick - _prev_tick)
		if span > 0.0:
			a = clampf((float(Engine.get_physics_frames() - 1 - _prev_tick) + Engine.get_physics_interpolation_fraction()) / span, 0.0, 1.0)
	if a >= 0.999:
		if _shown >= 0.999:
			return
		a = 1.0
		for k in _bones.size():
			skel.set_bone_pose(_bones[k], _cur[k])
	else:
		for k in _bones.size():
			skel.set_bone_pose(_bones[k], _prev[k].interpolate_with(_cur[k], a))
	_shown = a


func _pose() -> void:
	_capture()
	_shown = -1.0
	if _cur.is_empty():
		return
	for k in _bones.size():
		skel.set_bone_pose(_bones[k], _cur[k])
	_shown = 1.0
