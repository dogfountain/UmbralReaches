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


func setup(s: Skeleton3D, rig: CharacterRig, mesh: MeshInstance3D) -> void:
	skel = s
	body = mesh
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
	_pose()


func _pose() -> void:
	if skel == null:
		return
	var inv := skel.global_transform.affine_inverse()
	for k in _bones.size():
		var sock := _socks[k]
		if is_instance_valid(sock):
			skel.set_bone_pose(_bones[k], inv * sock.global_transform * _bases[k])
