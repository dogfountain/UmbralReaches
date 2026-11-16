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
var _out := false                      ## past the body's draw distance last frame


static var _cam_frame := -1
static var _cam_at := Vector3.ZERO


## The camera's position, looked up once a frame for every grunt.
func _cam_pos() -> Vector3:
	var f := Engine.get_process_frames()
	if f != _cam_frame:
		_cam_frame = f
		var cam := get_viewport().get_camera_3d()
		_cam_at = cam.global_position if cam else Vector3(INF, INF, INF)
	return _cam_at


## Parked skins (asleep and settled) stop processing: ~195 grunts' per-frame checks cost ~0.47 ms. The
## rig unparks its skin on animate() and when it processes again; one driver keeps the REFRESH pose of
## the parked ones (anything that set a socket by hand), a share of them each frame.
var _is_parked := false
var _drv: Node = null                   ## the scene's driver while parked


class Driver extends Node:
	var parked: Array = []
	var i := 0
	func _process(_d: float) -> void:
		var n := parked.size()
		if n == 0:
			return
		for _j in ceili(float(n) / REFRESH):
			if parked.is_empty():
				return
			if i >= parked.size():
				i = 0
			var sk: Variant = parked[i]
			if not is_instance_valid(sk) or not (sk as Node).is_inside_tree():
				parked.remove_at(i)
				continue
			sk.call(&"_refresh")
			i += 1


## One driver per night, under the scene (freed with it; no static holds it).
func _driver() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var d: Variant = scene.get_meta(&"grunt_skin_driver") if scene.has_meta(&"grunt_skin_driver") else null
	if d is Node and is_instance_valid(d):
		return d
	var nd := Driver.new()
	nd.name = "GruntSkinDriver"
	nd.process_priority = 100
	scene.set_meta(&"grunt_skin_driver", nd)
	scene.add_child.call_deferred(nd)
	return nd


func _park() -> void:
	if _is_parked or _rig == null:
		return
	_drv = _driver()
	if _drv == null:
		return
	_is_parked = true
	set_process(false)
	_rig.skin_parked = self
	(_drv as Driver).parked.append(self)


func unpark() -> void:
	if not _is_parked:
		return
	_is_parked = false
	_asleep_frames = 0
	if _rig != null and is_instance_valid(_rig):
		_rig.skin_parked = null
	if is_instance_valid(_drv):
		(_drv as Driver).parked.erase(self)
	_drv = null
	set_process(true)


## The parked pose, looked at again (what _process did every REFRESH frames).
func _refresh() -> void:
	if body and not body.is_visible_in_tree():
		return
	if _beyond_draw():
		_out = true
		return
	if _out:
		_out = false
		_posed_t = -1.0
		_cap_tick = -1
	var held := _shown >= 0.999
	_capture()
	if _same and held:
		_shown = 1.0                     # every bone where it is drawn already (a sleeping rig's sockets rarely move)
		return
	_blend()
	if _fresh:
		_shown = 1.0                     # (a fresh capture's two poses are one: it draws exactly that pose)


## Past the body's draw distance (and its fade) from the camera: nothing of the pose is seen.
func _beyond_draw() -> bool:
	if body == null or body.visibility_range_end <= 0.0:
		return false
	var far := body.visibility_range_end + body.visibility_range_end_margin + 2.0
	return _cam_pos().distance_squared_to(body.global_position) > far * far


## A sleeping rig whose body is hidden or out of draw range: nothing to pose, nothing to check every frame
## (~220 of the doubled Realm's sleeping camp pawns did both checks each frame, ~0.3 ms). The driver's
## REFRESH look poses it once it is shown or comes in range; waking or animate() unparks it.
func _park_unseen() -> bool:
	if _rig == null or _rig.can_process():
		return false
	_park()
	return _is_parked


func _exit_tree() -> void:
	if _is_parked:
		unpark()


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
		_park_unseen()
		return
	# past the body's draw distance nothing of the pose is seen: skip it, and pose afresh on the way back in
	if body and body.visibility_range_end > 0.0:
		var far := body.visibility_range_end + body.visibility_range_end_margin + 2.0
		if _cam_pos().distance_squared_to(body.global_position) > far * far:
			_out = true
			_park_unseen()
			return
		if _out:
			_out = false
			_posed_t = -1.0
			_cap_tick = -1
	if _rig != null and not _rig.can_process():
		_asleep_frames += 1
		if _rig._t == _posed_t and _asleep_frames > 3 and (_asleep_frames + get_instance_id()) % REFRESH != 0:
			if _shown < 0.999:
				_blend()                 # posed by hand on the tick: still draw the in-between
			else:
				_park()                  # settled: stop processing until the rig wakes or is animated
			return
	else:
		_asleep_frames = 0
	# a new pose from animate(); or, a few ticks on without one, whatever set the sockets by hand
	if _rig == null or _rig._t != _posed_t or Engine.get_physics_frames() - _cap_tick >= 3:
		_capture()
	_blend()


## The rig poses on the physics tick, but the screen
## draws at its own rate. Keep the last two posed ticks in skeleton space and draw the blend
## for the moment the renderer is showing (the same time the interpolated body is at), so a
## grunt's limbs move at the display's rate instead of stepping at 60 (or 30) Hz.
var _prev: Array[Transform3D] = []
var _cur: Array[Transform3D] = []
var _prev_tick := -1
var _cap_tick := -1
var _shown := -1.0                     ## the last blend drawn (1 = cur); skip redrawing a held pose
var _same := false                     ## the last capture found every bone where the one before had it
var _fresh := false                    ## the last capture started afresh (its previous pose is itself)
const POSE_EVERY := 3
var pose_span := 1                     ## its rig is posed one tick in this many (idle_lod)


## Enemy._animate_rig: an idle foe at rest far off (`far_idle`) is posed one tick in POSE_EVERY with the time
## saved up, and the skin glides over the whole span (_blend), so its breath and shuffle stay smooth (the pose
## was half an idle foe's tick, and a fight's edge has a dozen idle camp foes awake). True: skip this tick's pose.
func idle_lod(far_idle: bool, id: int) -> bool:
	pose_span = POSE_EVERY if far_idle else 1
	return far_idle and (Engine.get_physics_frames() + id) % POSE_EVERY != 0


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
	_fresh = fresh
	_same = _cap_tick >= 0
	for k in n:
		var sock := _socks[k]
		var t := inv * sock.global_transform * _bases[k] if is_instance_valid(sock) else _cur[k]
		if _same and t != _cur[k]:
			_same = false
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
		if span > 1.0 and pose_span == int(span):
			# posed one tick in pose_span (idle_lod): glide over the whole span, a span behind
			a = clampf((float(Engine.get_physics_frames() - _cap_tick) + Engine.get_physics_interpolation_fraction()) / span, 0.0, 1.0)
		elif span > 0.0:
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
