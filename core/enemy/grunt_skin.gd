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
			return
	else:
		_asleep_frames = 0
	_pose()


func _pose() -> void:
	if skel == null:
		return
	if _rig != null:
		_posed_t = _rig._t
	var inv := skel.global_transform.affine_inverse()
	for k in _bones.size():
		var sock := _socks[k]
		if is_instance_valid(sock):
			skel.set_bone_pose(_bones[k], inv * sock.global_transform * _bases[k])
