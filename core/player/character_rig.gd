@tool
class_name CharacterRig
extends Node3D
## The wanderer: a skeleton of plain Node3D joints, animated procedurally from real movement, with
## EquipmentPiece meshes attached at named sockets (see DefaultLoadout). Stride phase advances with
## distance travelled, so feet don't slide. The skeleton and the gear worn on it are independent --
## swap the loadout for a new look without touching this file.
## States blend continuously: idle (breathing) -> walk -> sprint, airborne tuck, landing dip, staff cast.

const STEP_LEN := 0.78          # metres per step at walk pace
const Check := preload("res://core/debug/check.gd")
const ROBE_WAVE := preload("res://core/player/robe_wave.gdshader")
const VOID_FACE := preload("res://core/player/void_face.gdshader")
const ROBE_ALBEDO := "res://art/textures/robe_albedo.png"
const ROBE_MAGIC := "res://art/textures/robe_magic.png"
const ROBE_NORMAL := "res://art/textures/robe_normal.png"
const WBody := preload("res://core/player/wanderer_body.gd")
const WPiece := preload("res://core/player/wanderer_piece.gd")
static var _cloth_shared := {}

var walk_speed := 4.5
var sprint_speed := 7.5
var dress_default := true
var rim_light := true
## True when the owner calls animate() every physics frame (Player, Enemy). Turns off the idle
## fallback in _process, which would otherwise zero the stride in between those calls.
var driven := false
## Enemies set this. Player stays false so the staff pose is untouched.
var melee := false
## 0..1 while a charged skill is held. Swells the orb and its light (Ember Lance).
var charge := 0.0
## 0..1 slide blend from Player: low, legs out front, torso leaning back, trailing arm.
var slide := 0.0
var _tuck := 0.0                 ## double-jump knees-up, decays
## The wanderer (built with the default loadout): foot IK, leaning, secondary motion. Enemy rigs
## (HunchRig, QuadRig) share this class and keep the plain stride.
var hero := false
## Plant the feet on the real ground (stairs, slopes) with a two-bone leg solve. Needs physics.
var foot_ik := true
const THIGH := 0.40
const SHIN := 0.40
var _ik_off := [0.0, 0.0]        ## smoothed ground height under each foot, relative to the root
var _ik_pitch := [0.0, 0.0]      ## ground slope under each foot along the body (toe up +)
var _lean := 0.0                 ## roll into turns
var _pitch_lean := 0.0           ## lean into acceleration / back when braking
var _pitch_lean_v := 0.0
var _staff_sw := Vector2.ZERO    ## staff swing spring (pitch, roll)
var _staff_sw_v := Vector2.ZERO
var _nod := 0.0                  ## head/hood nod spring (landings, stops)
var _nod_v := 0.0
var _jump_t := -1.0              ## jump push-off pose clock
var _bump := 0.0                 ## a small knee flex on a step-up
var _pend := {}                  ## hanging things (lantern, satchel): pendulum state per key
var _grip_r: Node3D              ## right glove: aligned to the staff each frame
var _local_acc := Vector3.ZERO

var _pelvis: Node3D
var _torso: Node3D
var _chest: Node3D
var _head: Node3D
var _hood_peak: Node3D
var _sh := [null, null]          # shoulders  [left, right]
var _el := [null, null]          # elbows
var _hand := [null, null]
var _hip := [null, null]
var _knee := [null, null]
var _foot := [null, null]
var _staff: Node3D
var _orb: Node3D
var _orb_light: OmniLight3D
var _burst: GPUParticles3D
var _trail: GPUParticles3D
var _lantern: Node3D
var _lantern_light: OmniLight3D
var _sockets := {}               # String socket name -> Node3D joint, for EquipmentPiece attachment
var _equipped := {}              # String key -> built Node3D root, for re-equip/unequip
var _phase := 0.0
var _stride := 0.0
var _t := 0.0
var _lag := Vector3.ZERO
var _hem_spring := Vector2.ZERO
var _hem_spring_v := Vector2.ZERO
var _cloth: Array[MeshInstance3D] = []
var _cloth_lag_s := Vector3(999, 0, 0)
var _cloth_phase_s := -99.0
var _cloth_stride_s := -99.0
var _foot_l_sent := Vector3(999, 0, 0)
var _foot_r_sent := Vector3(999, 0, 0)
var _foot_r_s_sent := -1.0
var _coat_mi: MeshInstance3D = null   # coat mesh — foot targets must be in its VERTEX space
var _lag_v := Vector3.ZERO
var _prev_vel := Vector3.ZERO
var _air := 0.0
var _land := 0.0
var _was_floor := true
var _gesture := 0.0
var _gesture_t := -1.0
var _turn := 0.0
var _prev_yaw := 0.0
var _vy := 0.0
var _foot_l_s := Vector3.ZERO     # smoothed shin targets for the cloth shader
var _foot_r_s := Vector3.ZERO
var _feet_s_ready := false
var _prev_phase := 0.0
var _steps: AudioStreamPlayer3D
var _cast_sfx: AudioStreamPlayer3D

# --- the merged body (wanderer): one skinned mesh posed from the joints, see wanderer_body.gd ---
var _skel: Skeleton3D
var _body_mi: MeshInstance3D
var _drivers: Array[Node3D] = []
var _bone_prev: Array[Transform3D] = []
var _bone_cur: Array[Transform3D] = []
var _burst_t := -1.0
var _flare: GeometryInstance3D
var _cap_frame := -10

# --- the wanderer's richer motion (hero only) ---
## World point the head turns toward (Player: the nearest enemy in front, else where the camera
## looks). Vector3.INF = no target, the head keeps its idle wander.
var look_at_point := Vector3.INF
var _look := Vector2.ZERO          ## smoothed (yaw, pitch) of the look, body-relative
var _cast_kind := &""
var _cast_t := -1.0
var _cast_len := 0.4
var _hit := 0.0                    ## hit react 0..1, decays
var _hit_dir := Vector2.ZERO       ## where the hit came from, body-local (x right, y forward)
var _shuffle := 0.0                ## turning in place: the feet step round
var _run := 0.0                    ## 0 walk .. 1 sprint, smoothed (carry pose)
var _staff_off := Vector3.ZERO     ## pose offsets for the staff (pitch, yaw, roll)
var _rune := 0.0                   ## the staff's runes waking after a cast
const HARD_LAND := 11.0           ## m/s down: a landing this hard folds the knees (hero)
const CAST_LEN := {&"bolt": 0.42, &"lance": 0.62, &"nova": 0.9, &"ward": 1.0, &"step": 0.55, &"greet": 0.9, &"reach": 0.7,
	&"tether": 0.75, &"well": 0.95, &"familiar": 0.85,
	&"strike_a": 0.38, &"strike_b": 0.38, &"strike_c": 0.56, &"heavy": 0.66, &"parry": 0.42}   # r31 staff arts
# r31 staff arts and the cloak-glide (Player / StaffArts feed these; 0..1 blends)
var guard := 0.0                    ## the staff held crosswise before the body
var wind := 0.0                     ## a heavy strike drawn back overhead
var glide := 0.0                    ## the robe spread as a sail, arms wide
var _strike_frame := Basis.IDENTITY ## the staff's swing for the current strike (applied in _moves_pose)
var _strike_k := 0.0


func _ready() -> void:
	if _pelvis == null:
		_build()
	set_process(not driven or _skel != null)
	_ensure_audio()


# --- construction ---------------------------------------------------------------------------
# The skeleton is just joints (Node3D, no mesh) exposed as named sockets. All visible geometry
# comes from EquipmentPiece.build() calls via equip() -- see DefaultLoadout for the actual look.

func _build() -> void:
	_sockets.clear()
	_equipped.clear()
	_build_skeleton()
	if dress_default:
		_equip_default()
	if rim_light and _skel == null:
		_add_rim_light()          # the merged body's shaders carry this light themselves (rim_* uniforms)


## Soft violet key from in front/above so the near-black robe keeps a readable silhouette
## and fold detail against the night. No shadows: cheap, and it only needs to lift edges.
func _add_rim_light() -> void:
	var l := OmniLight3D.new()
	l.name = "RimLight"
	l.light_color = Color(0.62, 0.5, 1.0)
	l.light_energy = 1.25
	l.omni_range = 3.0                 # the robe and a step round it: fewer lit pixels than 4.5 m
	l.omni_attenuation = 1.1
	l.shadow_enabled = false
	l.position = Vector3(0.5, 2.1, 1.4)
	add_child(l)


func _build_skeleton() -> void:
	_pelvis = ProcMesh.node(self, "Pelvis", Vector3(0, 0.94, 0))
	_sockets["pelvis"] = _pelvis

	for i in 2:
		var sx := -1.0 if i == 0 else 1.0
		var tag := "l" if i == 0 else "r"
		_hip[i] = ProcMesh.node(_pelvis, "Hip" + tag.to_upper(), Vector3(sx * 0.11, -0.19, 0))
		_sockets["hip_" + tag] = _hip[i]
		_knee[i] = ProcMesh.node(_hip[i], "Knee", Vector3(0, -0.42, 0))
		_sockets["knee_" + tag] = _knee[i]
		_foot[i] = ProcMesh.node(_knee[i], "Foot", Vector3(0, -0.42, 0))
		_sockets["foot_" + tag] = _foot[i]

	_torso = ProcMesh.node(_pelvis, "Torso", Vector3(0, 0.04, 0))
	_chest = ProcMesh.node(_torso, "Chest", Vector3(0, 0.3, 0))
	_sockets["chest"] = _chest

	_head = ProcMesh.node(_chest, "Head", Vector3(0, 0.36, 0.0))
	_sockets["head"] = _head
	_hood_peak = ProcMesh.node(_head, "HoodPeak", Vector3(0, 0.2, 0.08))
	_hood_peak.rotation.x = 0.4
	_sockets["hood_peak"] = _hood_peak

	for i in 2:
		var sx := -1.0 if i == 0 else 1.0
		var tag := "l" if i == 0 else "r"
		_sh[i] = ProcMesh.node(_chest, "Shoulder" + tag.to_upper(), Vector3(sx * 0.24, 0.12, 0))
		_sockets["shoulder_" + tag] = _sh[i]
		_el[i] = ProcMesh.node(_sh[i], "Elbow", Vector3(0, -0.32, 0))
		_sockets["elbow_" + tag] = _el[i]
		_hand[i] = ProcMesh.node(_el[i], "Hand", Vector3(0, -0.30, 0))
		_sockets["hand_" + tag] = _hand[i]


## Builds every piece in DefaultLoadout onto its socket, then grabs the refs the per-frame
## animate() loop needs (staff/orb/particles, lantern/light) out of what equip() just built.
func _equip_default() -> void:
	# the wanderer's legs: 0.40 + 0.40 (the shared 0.42 joints left the soles 9 cm under the ground
	# at rest). Set before the gear is built so the merged body's rests match.
	for i in 2:
		(_knee[i] as Node3D).position = Vector3(0.0, -H_LEG, 0.0)
		(_foot[i] as Node3D).position = Vector3(0.0, -H_LEG, 0.0)
	_pelvis.position.y = H_PELVIS
	var merge := not DefaultLoadout.use_legacy and not Engine.is_editor_hint()
	WPiece.merged = merge
	for entry in DefaultLoadout.entries():
		equip(entry.socket, entry.piece, entry.key)
	WPiece.merged = false

	_staff = _equipped.get("weapon_main")
	if _staff:
		_orb = _staff.get_node_or_null("Head/Orb")
		if _orb:
			_orb_light = _orb.get_node_or_null("OrbLight")
			_trail = _orb.get_node_or_null("Trail")
			_burst = _orb.get_node_or_null("Burst")
			_flare = _orb.get_node_or_null("Starburst") as GeometryInstance3D

	_lantern = _equipped.get("lantern")
	if _lantern:
		_lantern_light = _lantern.get_node_or_null("LanternLight")
	hero = true
	_grip_r = _equipped.get("hand_r")
	if _grip_r and not _grip_r.has_meta("dressed"):
		_grip_r = null                              # the old gauntlet glb is not a fist round a bar
	# Coat mesh Y is [-1.16, 0.30] under chest — weight must use that local range, not world Y.
	var coat_root: Node = _equipped.get("coat")
	if coat_root:
		_coat_mi = coat_root.find_child("Torso", true, false) as MeshInstance3D
		if _coat_mi == null:
			for node in coat_root.find_children("*", "MeshInstance3D", true, false):
				_coat_mi = node as MeshInstance3D
				break
	if coat_root and coat_root.has_meta("dressed"):
		# generated gear dresses itself; collect its cloth for the per-frame hem uniforms
		for k: String in _equipped:
			var root: Node = _equipped[k]
			if root == null or not root.has_meta("dressed"):
				continue
			for node in root.find_children("*", "MeshInstance3D", true, false):
				if node.has_meta("wave") and not _cloth.has(node):
					_cloth.append(node as MeshInstance3D)
	else:
		_dress_cloth(coat_root, 0.28, 1.42, 1.0, 1.0, 0.0)
		_dress_cloth(_equipped.get("hood"), 0.26, 0.38, 0.0, 0.35, 0.0)
		_dress_cloth(_equipped.get("sleeve_l"), 0.05, 0.36, 0.0, 0.25, 0.0)
		_dress_cloth(_equipped.get("sleeve_r"), 0.05, 0.36, 0.0, 0.25, 0.0)
	if merge:
		_bake_body()
	_build_face()


## The wanderer's gear as ONE skinned mesh (wanderer_body.gd): a flat Skeleton3D with a bone per
## gear driver (every node carrying meta "gen_parts": the pieces' roots, the staff, its orb, the
## lantern), rest = where the driver sits now, in rig space. Each physics tick the drivers' poses are
## captured (_capture_bones) and every frame they are interpolated onto the bones (_process), so the
## limbs stay as smooth as the old per-piece meshes were under physics interpolation. The body casts
## no shadow; a coarse proxy on the same skeleton does.
func _bake_body() -> void:
	_drivers.clear()
	var parts := []
	for k: String in _equipped:
		var root: Node3D = _equipped[k]
		if root == null:
			continue
		var nodes: Array[Node] = [root]
		nodes.append_array(root.find_children("*", "Node3D", true, false))
		for n in nodes:
			if not n.has_meta("gen_parts"):
				continue
			var bi := _drivers.size()
			_drivers.append(n as Node3D)
			for gp: Array in n.get_meta("gen_parts"):
				parts.append([String(gp[0]), bi, gp[1] if gp.size() > 1 else Vector4.ZERO])
	if _drivers.is_empty():
		return
	var rests: Array = []
	for d in _drivers:
		rests.append(_rel(d))
	var meshes: Array = WBody.build(parts, rests)
	_skel = Skeleton3D.new()
	_skel.name = "Skeleton"
	add_child(_skel)
	var skin := Skin.new()
	for i in _drivers.size():
		_skel.add_bone("b%d" % i)
		_skel.set_bone_rest(i, rests[i])
		skin.add_bind(i, (rests[i] as Transform3D).affine_inverse())
	_skel.reset_bone_poses()
	_body_mi = MeshInstance3D.new()
	_body_mi.name = "Body"
	_body_mi.mesh = meshes[0]
	_body_mi.skin = skin
	_body_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body_mi.extra_cull_margin = 1.0             # a raised staff reaches out of the rest bounds
	_skel.add_child(_body_mi)
	_body_mi.skeleton = NodePath("..")
	for si in _body_mi.mesh.get_surface_count():
		_body_mi.set_surface_override_material(si, WBody.material(_body_mi.mesh.surface_get_name(si)))
	var shadow := MeshInstance3D.new()
	shadow.name = "ShadowProxy"
	shadow.mesh = meshes[1]
	shadow.skin = skin
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	shadow.extra_cull_margin = 1.0
	_skel.add_child(shadow)
	shadow.skeleton = NodePath("..")
	_cloth.clear()
	_cloth.append(_body_mi)
	_bone_prev.clear()
	_bone_cur.clear()
	for i in _drivers.size():
		_bone_prev.append(rests[i])
		_bone_cur.append(rests[i])


## Transform of a node under this rig, relative to the rig (no tree needed).
func _rel(n: Node3D) -> Transform3D:
	var t := n.transform
	var p := n.get_parent()
	while p != null and p != self:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


## Physics tick: where the drivers are now (rig space). _process blends prev -> cur.
func _capture_bones() -> void:
	var inv := global_transform.affine_inverse()
	for i in _drivers.size():
		_bone_prev[i] = _bone_cur[i]
		_bone_cur[i] = inv * _drivers[i].global_transform
	_cap_frame = Engine.get_physics_frames()
	if not Engine.is_in_physics_frame() or not is_physics_interpolated_and_enabled():
		_apply_bones(1.0)


func has_merged_body() -> bool:
	return _skel != null


func _apply_bones(f: float) -> void:
	if f >= 0.999:
		for i in _drivers.size():
			_skel.set_bone_pose(i, _bone_cur[i])
	else:
		for i in _drivers.size():
			_skel.set_bone_pose(i, _bone_prev[i].interpolate_with(_bone_cur[i], f))


## Attaches `piece` to the named socket, freeing whatever previously held `key` (default: the
## socket name) first. Returns the built root, or null if the socket doesn't exist. This is the
## one path every piece of gear goes through -- runtime reskinning is just equip() again.
func equip(socket_name: String, piece: EquipmentPiece, key := "") -> Node3D:
	var k := key if key != "" else socket_name
	unequip(k)
	var socket: Node3D = _sockets.get(socket_name)
	if socket == null:
		push_error("CharacterRig.equip: unknown socket '%s'" % socket_name)
		return null
	if piece == null:
		push_error("CharacterRig.equip null piece on '%s'" % socket_name)
		return null
	var root := piece.build(socket)
	if root == null:
		push_error("CharacterRig.equip %s.build returned null" % k)
		return null
	_equipped[k] = root
	return root


func unequip(key: String) -> void:
	if _equipped.has(key):
		var n: Node = _equipped[key]
		if is_instance_valid(n):
			n.queue_free()
		_equipped.erase(key)


## Joint by socket name (`chest`, `hand_r`, …). Owners never walk bone paths.
func socket(socket_name: String) -> Node3D:
	return _sockets.get(socket_name) as Node3D


# --- animation --------------------------------------------------------------------------------

## Called by the player each physics frame with its velocity (world), floor state and facing yaw.
func animate(vel: Vector3, on_floor: bool, delta: float) -> void:
	if _pelvis == null or delta <= 0.0:
		return
	_t += delta
	var flat := Vector3(vel.x, 0.0, vel.z)
	var speed := flat.length()
	_vy = vel.y

	# Stride amount and phase: phase advances with distance, so foot placement matches travel.
	var target_stride := clampf(speed / walk_speed, 0.0, 1.0) + clampf((speed - walk_speed) / (sprint_speed - walk_speed), 0.0, 1.0) * 0.35
	if not on_floor:
		target_stride *= 0.3
	target_stride *= 1.0 - slide
	var gait := _gait_ok()
	if hero and not gait:
		# turning in place: the feet shuffle round (a small stride whose phase follows the yaw)
		var turning := on_floor and speed < 0.6 and absf(_turn) > 0.9 and slide < 0.1
		_shuffle = move_toward(_shuffle, 1.0 if turning else 0.0, delta * (7.0 if turning else 3.0))
		target_stride = maxf(target_stride, 0.22 * _shuffle)
	_stride = lerpf(_stride, target_stride, 1.0 - exp(-8.0 * delta))
	if gait:
		_gait_advance(speed, flat, on_floor, delta)     # cycle, feet, _phase and footsteps
	else:
		var step_len := STEP_LEN * (1.0 + clampf((speed - walk_speed) / (sprint_speed - walk_speed), 0.0, 1.0) * 0.55)
		if on_floor:
			_phase += speed * delta / step_len * PI + absf(_turn) * delta * 1.3 * _shuffle
		elif _stride < 0.05:
			_phase = lerp_angle(_phase, 0.0, 1.0 - exp(-4.0 * delta))
		if on_floor and _stride > 0.25 and sin(_prev_phase) * sin(_phase) <= 0.0:
			_footstep(speed)
	_prev_phase = _phase

	# Air and landing
	_air = move_toward(_air, 0.0 if on_floor else 1.0, delta * 6.0)
	if on_floor and not _was_floor:
		_land = clampf(-_prev_vel.y / 9.0, 0.25, 1.0)
		if _land > 0.3:
			_landing_sfx(_land)
		if hero and -_prev_vel.y > HARD_LAND and move_playing() != &"roll":
			_land_hard = clampf((-_prev_vel.y - HARD_LAND) / 5.0 + 0.6, 0.6, 1.0)
	_was_floor = on_floor
	_land = move_toward(_land, 0.0, delta * 3.5)

	# Turning rate (rad/s) for lean and lateral cloth swing
	var yaw := rotation.y
	_turn = lerpf(_turn, wrapf(yaw - _prev_yaw, -PI, PI) / maxf(delta, 0.0001), 1.0 - exp(-6.0 * delta))
	_prev_yaw = yaw

	# Gesture (staff cast)
	if _gesture_t >= 0.0:
		_gesture_t += delta
		_gesture = sin(clampf(_gesture_t / 0.95, 0.0, 1.0) * PI)
		if _gesture_t > 0.95:
			_gesture_t = -1.0
			_gesture = 0.0

	var s := sin(_phase)
	var c := cos(_phase)
	var st := _stride
	var breathe := sin(_t * 1.7)
	var idle := clampf(1.0 - st * 2.0, 0.0, 1.0)

	var body := global_basis.orthonormalized()
	_local_acc = body.inverse() * ((vel - _prev_vel) / delta)
	if gait:
		# the IK leaves full rotations on the legs: start each frame from the stride's plain swing
		for i in 2:
			(_hip[i] as Node3D).rotation = Vector3.ZERO
			(_knee[i] as Node3D).rotation = Vector3.ZERO
			(_foot[i] as Node3D).rotation = Vector3.ZERO
	_legacy_pose(s, c, st, breathe, idle)
	if gait:
		_gait_body(speed, on_floor, idle, breathe, delta)
	_tuck = move_toward(_tuck, 0.0, delta * 2.2)
	if slide > 0.01 or _tuck > 0.01:
		_pose_overlay()
	if hero:
		_hero_pose(speed, on_floor, idle, breathe, delta)
		if gait:
			_moves_pose(speed, on_floor, delta)        # traversal / roll / idle acts (FK)
			_gait_legs(delta)                          # planted feet: two-bone IK onto the ground
		elif foot_ik and on_floor and slide < 0.4 and not Engine.is_editor_hint():
			_foot_ik(delta)
		else:
			_ik_off[0] = lerpf(_ik_off[0], 0.0, 1.0 - exp(-10.0 * delta))
			_ik_off[1] = lerpf(_ik_off[1], 0.0, 1.0 - exp(-10.0 * delta))

	if _staff and _orb and _orb_light:
		var tilt := -0.12 - s * 0.12 * st - _gesture * 0.75 + _staff_sw.x + _staff_off.x
		_staff.global_basis = body * _staff_frame * Basis.from_euler(Vector3(tilt, _staff_off.y, 0.06 + _turn * 0.03 + _staff_sw.y + _staff_off.z))
		_hand[1].rotation.z = 0.35
		if _grip_r:
			# the fist closes round the shaft wherever the staff points, the wrist toward the elbow
			var gx := _staff.global_basis.y.normalized()
			var to_el := (_el[1] as Node3D).global_position - (_hand[1] as Node3D).global_position
			var gy := to_el - gx * to_el.dot(gx)
			if gy.length_squared() > 1e-6:
				gy = gy.normalized()
				_grip_r.global_basis = Basis(gx, gy, gx.cross(gy))
		_orb.position.y = 0.17 + sin(_t * 2.2) * 0.015
		_orb.rotation.y += delta * 1.5
		_orb_light.light_energy = 1.3 + sin(_t * 3.1) * 0.15 + (_gesture + _cast_glow) * 3.5 + charge * (4.0 + sin(_t * 31.0) * 0.6)
		_orb.scale = Vector3.ONE * (1.0 + charge * 0.7)
		if _trail:
			var run := clampf((speed - walk_speed * 0.85) / maxf(sprint_speed - walk_speed, 0.2), 0.0, 1.0)
			_trail.amount_ratio = lerpf(1.0, 0.16, run)
			_trail.lifetime = lerpf(1.15, 0.38, run)
	if _lantern_light:
		_lantern_light.light_energy = 1.85 + sin(_t * 13.0) * 0.07 + sin(_t * 7.3) * 0.05
	if hero:
		_swing("lantern", _lantern, 0.26, Vector3.ZERO, body, delta)
		_swing("satchel", _equipped.get("satchel"), 0.3, Vector3.ZERO, body, delta)

	# Body lag is for lantern/hood lean only — NEVER feed walk velocity into cloth_lag
	# (that slid the whole coat behind the body while walking).
	var local_vel := body.inverse() * vel
	_prev_vel = vel
	var local_acc := _local_acc
	var target := Vector3(_turn * 0.04, -clampf(local_vel.y, -12.0, 12.0) * 0.015, 0.0)
	target += Vector3(-local_acc.x, 0.0, -local_acc.z) * 0.004
	_lag_v += (target - _lag) * 40.0 * delta
	_lag_v *= exp(-7.0 * delta)
	_lag += _lag_v * delta
	_lag = _lag.limit_length(0.08)
	_animate_cloth(local_vel, local_acc, delta)
	# Cloth verts: stop/land overshoot only. Steady stride → zero.
	var lag := Vector3.ZERO
	if _stride < 0.2 or _land > 0.08 or _air > 0.15 or local_acc.length() > 10.0:
		lag = Vector3(_hem_spring.y * 0.15 + _lag.x * 0.25, _lag.y * 0.15, _hem_spring.x * 0.15 + _lag.z * 0.2)
	# Boot tips in coat mesh space for X/Y; Z uses body-forward so torso pitch can't fake a long toe.
	var mesh_xf: Transform3D = _coat_mi.global_transform if _coat_mi else (_chest.global_transform if _chest else global_transform)
	var inv := mesh_xf.affine_inverse()
	var inv_body := body.inverse()
	var toe_world := body * Vector3(0.0, 0.02, -0.14)
	var foot_l := Vector3(-0.11, -0.95, 0.0)
	var foot_r := Vector3(0.11, -0.95, 0.0)
	if _foot[0] is Node3D:
		var wl: Vector3 = (_foot[0] as Node3D).global_position + toe_world
		foot_l = inv * wl
		foot_l.z = (inv_body * (wl - mesh_xf.origin)).z
	if _foot[1] is Node3D:
		var wr: Vector3 = (_foot[1] as Node3D).global_position + toe_world
		foot_r = inv * wr
		foot_r.z = (inv_body * (wr - mesh_xf.origin)).z
	# Z tracks the plant hard; soft-filter XY.
	var foot_a := 1.0 - exp(-22.0 * delta)
	if not _feet_s_ready:
		_foot_l_s = foot_l
		_foot_r_s = foot_r
		_feet_s_ready = true
	else:
		_foot_l_s.x = lerpf(_foot_l_s.x, foot_l.x, foot_a)
		_foot_l_s.y = lerpf(_foot_l_s.y, foot_l.y, foot_a)
		_foot_l_s.z = foot_l.z
		_foot_r_s.x = lerpf(_foot_r_s.x, foot_r.x, foot_a)
		_foot_r_s.y = lerpf(_foot_r_s.y, foot_r.y, foot_a)
		_foot_r_s.z = foot_r.z
	var frad := 0.16 + 0.04 * st
	if _body_mi:
		# merged body: the cloth inputs are kept per tick and blended per RENDERED frame in _process
		# (r29: set here they stepped at 60 Hz against the interpolated bones: the hem kick, the boot
		# cover and the torso basis ratcheted at a sprint on a 120-144 Hz screen). The knees and hips
		# ride along so the robe drapes over a knee that comes forward instead of the leg piercing it.
		var kl := inv * (_knee[0] as Node3D).global_position if _knee[0] else Vector3(-0.11, -0.55, 0.0)
		var kr := inv * (_knee[1] as Node3D).global_position if _knee[1] else Vector3(0.11, -0.55, 0.0)
		var hl := inv * (_hip[0] as Node3D).global_position if _hip[0] else Vector3(-0.11, -0.19, 0.0)
		var hr := inv * (_hip[1] as Node3D).global_position if _hip[1] else Vector3(0.11, -0.19, 0.0)
		var cb := (body.inverse() * _chest.global_basis).orthonormalized()
		_cl_prev = _cl_cur if _cl_cur.size() == CL_N else []
		_cl_cur = [lag, _phase, _stride, _foot_l_s, _foot_r_s, frad, cb.x, cb.y, kl, kr, hl, hr]
		if _cl_prev.is_empty():
			_cl_prev = _cl_cur
		if not is_physics_interpolated_and_enabled() or not Engine.is_in_physics_frame():
			_push_cloth(1.0)
	var cloth_changed := _body_mi == null and (
		not lag.is_equal_approx(_cloth_lag_s)
		or not is_equal_approx(_phase, _cloth_phase_s)
		or not is_equal_approx(_stride, _cloth_stride_s)
		or not _foot_l_s.is_equal_approx(_foot_l_sent)
		or not _foot_r_s.is_equal_approx(_foot_r_sent)
		or not is_equal_approx(frad, _foot_r_s_sent)
	)
	if cloth_changed:
		_cloth_lag_s = lag
		_cloth_phase_s = _phase
		_cloth_stride_s = _stride
		_foot_l_sent = _foot_l_s
		_foot_r_sent = _foot_r_s
		_foot_r_s_sent = frad
		for mi in _cloth:
			if not is_instance_valid(mi):
				continue
			mi.set_instance_shader_parameter("cloth_lag", lag)
			mi.set_instance_shader_parameter("walk_phase", _phase)
			mi.set_instance_shader_parameter("stride", _stride)
			mi.set_instance_shader_parameter("foot_l", _foot_l_s)
			mi.set_instance_shader_parameter("foot_r", _foot_r_s)
			mi.set_instance_shader_parameter("foot_radius", frad)
	_hood_peak.rotation.x = 0.4 + clampf(-_lag.z * 1.5, -0.3, 0.45) + _air * 0.15 - _nod * 0.8 + _run * _stride * 0.25 + _hit_s.x * 0.6 + _hood_s.x
	_hood_peak.rotation.z = clampf(_lag.x * 1.5, -0.3, 0.3) - _look.x * 0.12 + _hood_s.y
	if _burst_t >= 0.0:
		_burst_t += delta
		if _burst_t > 1.1 and _burst:
			_burst.visible = false
			_burst_t = -1.0
	if _body_mi:
		if _lantern_light:
			_body_mi.set_instance_shader_parameter("lantern_glow", _lantern_light.light_energy / 1.85)
		_rune = move_toward(_rune, 0.0, delta * 1.1)
		_body_mi.set_instance_shader_parameter("rune_boost", _rune)
		_body_mi.set_instance_shader_parameter("orb_boost", (_gesture + _cast_glow) * 0.35 + charge * 0.2)
		if _flare:
			_flare.set_instance_shader_parameter("flare_boost", clampf(_gesture + _cast_glow + charge * 0.6, 0.0, 1.0))
		_capture_bones()


func _legacy_pose(s: float, c: float, st: float, breathe: float, idle: float) -> void:
	# Procedural stride. Phase advances with distance travelled, so the feet match the ground.
	_pelvis.position.y = 0.94 + 0.035 * st * (absf(c) - 0.6) - _land * 0.13 + _air * 0.04 + breathe * 0.004 * idle
	_pelvis.position.x = -s * 0.025 * st
	_pelvis.rotation.y = s * 0.09 * st
	_pelvis.rotation.z = -_turn * 0.015
	for i in 2:
		var ps := s if i == 0 else -s
		var pc := c if i == 0 else -c
		var hip := ps * 0.38 * st
		var knee := maxf(0.0, pc) * 0.98 * st + 0.1 * st + _land * 0.5
		hip += _air * 0.45 + _land * 0.25
		knee += _air * 0.75
		_hip[i].rotation.x = hip
		_knee[i].rotation.x = -knee
		_foot[i].rotation.x = -(hip - knee) * 0.55
	_torso.rotation.y = -s * 0.16 * st
	_torso.rotation.x = -0.05 - 0.13 * maxf(0.0, st - 0.6) - _land * 0.25 + _air * 0.08 - _gesture * 0.08
	_torso.rotation.z = -_turn * 0.04 + sin(_t * 0.7) * 0.015 * idle
	_chest.scale = Vector3(1.0 + breathe * 0.012 * idle, 1.0 + breathe * 0.018 * idle, 1.0 + breathe * 0.012 * idle)
	_head.rotation.y = s * 0.1 * st + sin(_t * 0.45) * 0.12 * idle
	_head.rotation.x = 0.05 * st - breathe * 0.02 * idle - _gesture * 0.12
	if melee:
		_sh[0].rotation.x = -s * 0.55 * st + 0.28 + _gesture * 0.35
		_sh[0].rotation.y = 0.0
		_sh[0].rotation.z = -0.22 - _air * 0.35
		_el[0].rotation.x = 0.58 + maxf(0.0, -s) * 0.25 * st
		_sh[1].rotation.x = 0.62 + s * 0.22 * st + _gesture * 1.35
		_sh[1].rotation.y = 0.08
		_sh[1].rotation.z = 0.12 + _air * 0.2
		_el[1].rotation.x = 0.28 + _gesture * 0.55
	else:
		_sh[0].rotation.x = -s * 0.85 * st + 0.05
		_sh[0].rotation.y = 0.0
		_sh[0].rotation.z = -0.16 - _air * 0.5 - idle * breathe * 0.02
		_el[0].rotation.x = 0.32 + maxf(0.0, -s) * 0.55 * st + _air * 0.3
		_sh[1].rotation.x = 0.42 + s * 0.32 * st + _gesture * 1.05
		_sh[1].rotation.y = 0.0
		_sh[1].rotation.z = 0.3 + _air * 0.35
		_el[1].rotation.x = 0.85 - _gesture * 0.6


## Double jump: a quick knees-up tuck that unfolds as it decays.
func air_tuck() -> void:
	_tuck = 1.0


## Held crouch in the air (slide queued): keep the knees up at least this much.
func hold_tuck(v: float) -> void:
	_tuck = maxf(_tuck, v)


## Slide and tuck poses layered over the stride (blend by `slide` / `_tuck`).
func _pose_overlay() -> void:
	var k := slide
	# the wanderer's coat hangs from the chest: sitting back further swings its hem up over the
	# legs instead of through the ground
	_pelvis.position.y = lerpf(_pelvis.position.y, 0.66 if hero else 0.5, k)
	_torso.rotation.x = lerpf(_torso.rotation.x, 0.64 if hero else 0.42, k) - _tuck * 0.3
	_head.rotation.x = lerpf(_head.rotation.x, -0.3, k)
	for i in 2:
		var lead := i == 1
		_hip[i].rotation.x = lerpf(_hip[i].rotation.x, 1.15 if lead else 0.75, k) + _tuck * 0.9
		_knee[i].rotation.x = lerpf(_knee[i].rotation.x, -0.25 if lead else -1.45, k) - _tuck * 1.3
		_foot[i].rotation.x = lerpf(_foot[i].rotation.x, -0.5, k)
	_sh[0].rotation.x = lerpf(_sh[0].rotation.x, -0.9, k)
	_sh[0].rotation.z = lerpf(_sh[0].rotation.z, -0.7, k)
	_el[0].rotation.x = lerpf(_el[0].rotation.x, 0.4, k)


## Gives cloth surfaces a slight hem wave. Metal (the cross, the belt buckle) is left alone.
func _dress_cloth(root: Node, anchor_y: float, cloth_len: float, leg_push: float, wave_scale: float, use_world_y: float) -> void:
	if root == null:
		return
	var key := "%s/%.3f/%.3f/%.3f/%.3f" % [root.name, anchor_y, cloth_len, leg_push, wave_scale]
	var mat: ShaderMaterial = _cloth_shared.get(key)
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = ROBE_WAVE
		var dye := Vector3(0.055, 0.062, 0.12)
		mat.set_shader_parameter("base_color", dye)
		mat.set_shader_parameter("rim_color", Vector3(0.46, 0.34, 0.27))
		mat.set_shader_parameter("roughness_amt", 0.82)
		mat.set_shader_parameter("glow_energy", 0.08)
		var albedo := Check.res(ROBE_ALBEDO, Texture2D) as Texture2D
		var magic := Check.res(ROBE_MAGIC, Texture2D) as Texture2D
		var nrm := Check.res(ROBE_NORMAL, Texture2D) as Texture2D
		if albedo:
			mat.set_shader_parameter("albedo_tex", albedo)
		if magic:
			mat.set_shader_parameter("magic_tex", magic)
		if nrm:
			mat.set_shader_parameter("normal_tex", nrm)
		if albedo == null or magic == null:
			push_error("CharacterRig._dress_cloth missing robe 1k maps")
		mat.set_shader_parameter("anchor_y", anchor_y)
		mat.set_shader_parameter("cloth_len", cloth_len)
		mat.set_shader_parameter("leg_push", leg_push)
		mat.set_shader_parameter("wave_scale", wave_scale)
		mat.set_shader_parameter("use_world_y", use_world_y)
		_cloth_shared[key] = mat
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var used := false
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			var n_name := String(src.resource_name) if src else ""
			if n_name.begins_with("Body") or n_name.begins_with("Leather"):
				continue
			if src is StandardMaterial3D and (src as StandardMaterial3D).metallic > 0.4:
				continue
			mi.set_surface_override_material(s, mat)
			used = true
		if used and not _cloth.has(mi):
			_cloth.append(mi)


## Black void in the cowl. Solid at the centre, dissolving to mist at the rim and the chin.
func _build_face() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = VOID_FACE
	var sphere := SphereMesh.new()
	sphere.radius = 0.11
	sphere.height = 0.17
	sphere.radial_segments = 18
	sphere.rings = 12
	var face := MeshInstance3D.new()
	face.name = "Face"
	face.mesh = sphere
	face.material_override = mat
	face.position = Vector3(0.0, 0.02, -0.10)
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_head.add_child(face)

	var mist := GPUParticles3D.new()
	mist.name = "Mist"
	mist.amount = 34
	mist.lifetime = 2.1
	mist.explosiveness = 0.0
	mist.local_coords = true
	mist.visibility_aabb = AABB(Vector3(-0.4, -0.5, -0.4), Vector3(0.8, 0.7, 0.8))
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.05
	pm.direction = Vector3(0, -0.35, -1)
	pm.spread = 32.0
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.07
	pm.gravity = Vector3(0, -0.08, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var fade := Curve.new()
	fade.add_point(Vector2(0, 0.2))
	fade.add_point(Vector2(0.25, 1.0))
	fade.add_point(Vector2(1, 0.0))
	var fade_tex := CurveTexture.new()
	fade_tex.curve = fade
	pm.scale_curve = fade_tex
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.02, 0.02, 0.025, 0.0))
	ramp.add_point(0.2, Color(0.015, 0.015, 0.02, 0.55))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.01, 0.01, 0.012, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	mist.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	var qmat := StandardMaterial3D.new()
	qmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qmat.vertex_color_use_as_albedo = true
	qmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	# dark and round whatever the particle colour does; no fog (fog lit the puffs into a pale square)
	qmat.albedo_color = Color(0.06, 0.06, 0.07, 1)
	qmat.albedo_texture = Vfx.dot()
	qmat.disable_fog = true
	quad.material = qmat
	mist.draw_pass_1 = quad
	mist.position = Vector3(0, -0.04, -0.02)
	face.add_child(mist)


## Hem spring: stop / land / air only. No forward-speed term (that dragged the coat).
func _animate_cloth(local_vel: Vector3, local_acc: Vector3, delta: float) -> void:
	var target := Vector2(
		clampf(local_acc.z * 0.008, -0.15, 0.15) - _air * 0.18 + _land * 0.18,
		clampf(-local_vel.x * 0.02, -0.1, 0.1))
	var dt := minf(delta, 0.05)
	_hem_spring_v += (target - _hem_spring) * 36.0 * dt
	_hem_spring_v *= exp(-6.5 * dt)
	_hem_spring += _hem_spring_v * dt
	_hem_spring = _hem_spring.limit_length(0.14)


# --- the wanderer's extra motion ---------------------------------------------------------------

## Player calls this as the jump fires: a short push-off (legs extend, arms lift).
func jump_start() -> void:
	_jump_t = 0.0


## Player calls this on an automatic step-up: a small knee flex as the body rises.
func step_bump(rise: float) -> void:
	_bump = maxf(_bump, clampf(rise / 0.45, 0.0, 1.0))


## Leans, springs and small life on top of the stride (wanderer only).
func _hero_pose(speed: float, on_floor: bool, idle: float, breathe: float, delta: float) -> void:
	var dt := minf(delta, 0.05)
	# roll into the turn like a runner (yaw rate x speed), the hips lead and the chest follows
	# (about a third of the physical bank atan(v w / g): enough to read, not a motorbike)
	var roll_target := clampf(_turn * speed * 0.035, -0.3, 0.3) if on_floor else _turn * 0.02
	_lean = lerpf(_lean, roll_target, 1.0 - exp(-7.0 * dt))
	_pelvis.rotation.z += _lean * 0.75
	_pelvis.position.x -= sin(_lean) * 0.35          # the hips swing out, the body leans in over the feet
	_torso.rotation.z += _lean * 0.35
	_head.rotation.z = -_lean * 0.6                    # the head stays level-ish
	# pitch: forward when speeding up, back when braking -- a spring, so stops rock a little
	var pitch_target := clampf(_local_acc.z * 0.014, -0.2, 0.24) if on_floor else 0.0
	_pitch_lean_v += (pitch_target - _pitch_lean) * 90.0 * dt
	_pitch_lean_v *= exp(-11.0 * dt)
	_pitch_lean += _pitch_lean_v * dt
	_torso.rotation.x += _pitch_lean
	_head.rotation.x -= _pitch_lean * 0.5
	# nod: head and hood dip on landings and hard stops, then settle
	var nod_force := -_local_acc.y * 0.002 + _local_acc.z * 0.0015
	_nod_v += (clampf(nod_force, -0.3, 0.3) * 40.0 - _nod * 120.0) * dt
	_nod_v *= exp(-9.0 * dt)
	_nod = clampf(_nod + _nod_v * dt, -0.25, 0.25)
	_head.rotation.x += _nod
	# staff: the head lags a start and swings past on a stop
	var sw_target := Vector2(clampf(_local_acc.z * 0.012, -0.25, 0.25), clampf(-_local_acc.x * 0.01, -0.2, 0.2))
	_staff_sw_v += (sw_target - _staff_sw) * 70.0 * dt
	_staff_sw_v *= exp(-6.0 * dt)
	_staff_sw += _staff_sw_v * dt
	# idle: a slow weight shift from foot to foot, the free hand settles
	var shift := sin(_t * 0.43) * idle
	_pelvis.position.x += shift * 0.018
	_pelvis.rotation.z += shift * 0.025
	_torso.rotation.z -= shift * 0.03
	_sh[0].rotation.x += sin(_t * 0.9 + 1.3) * 0.03 * idle
	# jump push-off: legs extend, arms come up, then the air pose takes over
	if _jump_t >= 0.0:
		_jump_t += dt
		var k := sin(clampf(_jump_t / 0.28, 0.0, 1.0) * PI)
		for i in 2:
			_knee[i].rotation.x *= 1.0 - 0.6 * k
			_hip[i].rotation.x -= 0.15 * k
		_sh[0].rotation.x -= 0.5 * k
		_sh[0].rotation.z -= 0.2 * k
		_torso.rotation.x += 0.08 * k
		if _jump_t > 0.28:
			_jump_t = -1.0
	# step-up flex
	if _bump > 0.001:
		_pelvis.position.y -= _bump * 0.05
		for i in 2:
			_knee[i].rotation.x -= _bump * 0.25
		_bump = move_toward(_bump, 0.0, dt * 5.0)
	# landing: the arms open for balance and the head dips with the body
	_sh[0].rotation.z -= _land * 0.4
	_sh[1].rotation.z += _land * 0.22
	_el[0].rotation.x += _land * 0.3
	_staff_off = Vector3.ZERO
	_idle_life(idle, breathe)
	_carry_pose(speed, idle, dt)
	_cast_tick(dt)
	_hit_tick(dt)
	_look_tick(speed, dt)


## Idle: breath lifts the shoulders, the weight settles onto one leg (that knee locks, the other
## softens), and every few seconds the free hand and the staff shift their grip.
func _idle_life(idle: float, breathe: float) -> void:
	if idle <= 0.001:
		return
	var shift := sin(_t * 0.43)
	for i in 2:
		var carry := -shift if i == 0 else shift         # > 0: this leg carries the weight
		_knee[i].rotation.x -= maxf(0.0, -carry) * 0.12 * idle
		_hip[i].rotation.x += maxf(0.0, -carry) * 0.05 * idle
	_pelvis.position.y -= absf(shift) * 0.008 * idle
	_sh[0].rotation.z -= breathe * 0.015 * idle
	_sh[1].rotation.z += breathe * 0.012 * idle
	var fidget := pow(maxf(0.0, sin(_t * 0.23 + 0.7)), 12.0)          # a rare regrip
	_el[0].rotation.x += fidget * 0.25 * idle
	_staff_off.x += sin(_t * 0.37 + 1.0) * 0.03 * idle - fidget * 0.06 * idle
	_staff_off.z += (0.04 + sin(_t * 0.6) * 0.02) * idle


## How the staff is carried: at a walk upright and rocking like a walking stick; at a run tipped
## forward with the arm bent; at a sprint trailed back along the body, low, while the lantern arm
## pumps. Blends by speed.
func _carry_pose(speed: float, _idle: float, dt: float) -> void:
	var r := clampf((speed - walk_speed * 0.9) / maxf(sprint_speed - walk_speed * 0.9, 0.1), 0.0, 1.0)
	_run = lerpf(_run, r, 1.0 - exp(-6.0 * dt))
	var st := _stride
	var mid := sin(_run * PI) * st
	var spr := smoothstep(0.55, 1.0, _run) * st
	var walk := (1.0 - _run) * st
	_staff_off.x += sin(_phase) * 0.07 * walk - 0.32 * mid + 0.7 * spr
	_staff_off.z += -0.25 * spr
	_sh[1].rotation.x += 0.12 * mid - 0.5 * spr
	_sh[1].rotation.z += 0.1 * spr
	_el[1].rotation.x += 0.28 * mid + 0.15 * spr
	_el[0].rotation.x += 0.5 * spr + 0.15 * mid
	_sh[0].rotation.x += -sin(_phase) * 0.25 * spr
	_torso.rotation.x -= 0.1 * spr
	_head.rotation.x += 0.07 * spr


## Per-skill casts (Player -> cast_pose(skill id)), layered over everything else.
func cast_pose(kind: StringName) -> void:
	if not hero:
		return
	if kind == _cast_kind and _cast_t >= 0.0 and _cast_k > 0.05:
		# a repeat while the last one is still out (held Rift Bolt fires every 0.28 s, the flick
		# lasts 0.42): carry on from where the staff is instead of snapping it back to rest
		_cast_t = float(CAST_LEN.get(kind, 0.45)) * 0.16 * clampf(_cast_k, 0.0, 1.0)
	else:
		_cast_t = 0.0
		_cast_k = 0.0
	if kind == &"bolt":
		_bolt_side = -_bolt_side                # a chain alternates its flick a little left, right
	_cast_kind = kind
	_cast_len = float(CAST_LEN.get(kind, 0.45))
	_gesture_t = -1.0                       # the generic staff raise yields to the skill's own motion
	_gesture = 0.0
	_rune = 1.0


var _cast_glow := 0.0
var _cast_k := 0.0           ## how far out the current cast pose is (0..1), for smooth repeats
var _bolt_side := 1.0


func _cast_tick(dt: float) -> void:
	_cast_glow = 0.0
	_strike_k = 0.0
	# Ember Lance held: drawn back to throw, the free hand pointing the line, weight on the back leg
	if charge > 0.0:
		var c := smoothstep(0.0, 0.3, charge)
		_sh[1].rotation.x -= 0.4 * c
		_sh[1].rotation.z += 0.3 * c
		_el[1].rotation.x += 0.3 * c
		_staff_off.x += 0.6 * c + sin(_t * 31.0) * 0.012 * charge
		_torso.rotation.y += 0.34 * c
		_head.rotation.y -= 0.28 * c
		_sh[0].rotation.x += 1.05 * c
		_el[0].rotation.x -= 0.25 * c
		_pelvis.position.y -= 0.035 * c
		_knee[0].rotation.x -= 0.2 * c
		_knee[1].rotation.x -= 0.2 * c
	if _cast_t < 0.0:
		return
	_cast_t += dt
	var u := _cast_t / _cast_len
	if u >= 1.0:
		_cast_t = -1.0
		_cast_k = 0.0
		return
	match _cast_kind:
		&"bolt":
			# a flick: the staff snaps forward at the target and swings back, the shoulders turning
			# into it (alternating a little through a chain), then a small recoil as the bolt leaves
			var k := smoothstep(0.0, 0.16, u) * (1.0 - smoothstep(0.32, 1.0, u))
			var kick := smoothstep(0.14, 0.24, u) * (1.0 - smoothstep(0.24, 0.6, u))
			_cast_k = k
			_cast_glow = k
			_sh[1].rotation.x += 0.78 * k
			_el[1].rotation.x -= 0.5 * k
			_staff_off.x -= 0.95 * k - 0.18 * kick
			_torso.rotation.y -= (0.18 + 0.06 * _bolt_side) * k
			_torso.rotation.x -= 0.06 * k - 0.05 * kick
			_head.rotation.y += 0.06 * _bolt_side * k
			_sh[0].rotation.x += 0.25 * k       # the lantern hand comes up for balance
		&"lance":
			# the throw: the body drives the staff forward nearly level, a lunge onto the front foot
			var k := smoothstep(0.0, 0.1, u) * (1.0 - smoothstep(0.38, 1.0, u))
			_cast_glow = k
			_sh[1].rotation.x += 1.1 * k
			_el[1].rotation.x -= 0.6 * k
			_staff_off.x -= 1.15 * k
			_torso.rotation.y -= 0.38 * k
			_torso.rotation.x -= 0.16 * k
			_sh[0].rotation.x -= 0.55 * k
			_sh[0].rotation.z -= 0.25 * k
			_pelvis.position.y -= 0.05 * k
			_hip[1].rotation.x += 0.3 * k
			_knee[1].rotation.x -= 0.35 * k
			_hip[0].rotation.x -= 0.2 * k
		&"nova":
			# the staff swept up overhead, then the butt slammed down; the knees take the blow
			var raise := smoothstep(0.0, 0.3, u) * (1.0 - smoothstep(0.32, 0.42, u))
			var slam := smoothstep(0.32, 0.42, u) * (1.0 - smoothstep(0.62, 1.0, u))
			_cast_glow = raise * 0.6 + slam
			_sh[1].rotation.x += 2.2 * raise + 0.65 * slam
			_el[1].rotation.x -= 0.55 * raise
			_staff_off.x += 0.25 * raise + 0.1 * slam
			_sh[0].rotation.x += 1.3 * raise - 0.2 * slam
			_sh[0].rotation.z -= 0.3 * raise + 0.5 * slam
			_torso.rotation.x += 0.12 * raise - 0.36 * slam
			_head.rotation.x += 0.2 * raise - 0.15 * slam
			_pelvis.position.y += 0.025 * raise - 0.15 * slam
			for i in 2:
				_hip[i].rotation.x += 0.45 * slam
				_knee[i].rotation.x -= 0.8 * slam
		&"greet":
			# a nod and the lantern hand lifted a little: hello, not a spell
			var k := smoothstep(0.0, 0.25, u) * (1.0 - smoothstep(0.55, 1.0, u))
			_head.rotation.x -= 0.22 * k
			_sh[0].rotation.x += 0.5 * k
			_el[0].rotation.x -= 0.3 * k
			_torso.rotation.x -= 0.04 * k
		&"reach":
			# the free hand reaches out to the thing and back
			var k := smoothstep(0.0, 0.3, u) * (1.0 - smoothstep(0.55, 1.0, u))
			_sh[0].rotation.x += 0.95 * k
			_el[0].rotation.x -= 0.15 * k
			_torso.rotation.x -= 0.1 * k
			_head.rotation.x -= 0.12 * k
		&"ward":
			# the lantern lifted high, the head following it, the staff planted out to the side
			var k := smoothstep(0.0, 0.22, u) * (1.0 - smoothstep(0.7, 1.0, u))
			_cast_glow = k * 0.4
			_sh[0].rotation.x += 2.5 * k
			_sh[0].rotation.z -= 0.2 * k
			_el[0].rotation.x -= 0.25 * k
			_head.rotation.x += 0.3 * k
			_head.rotation.y += 0.15 * k
			_torso.rotation.x += 0.07 * k
			_sh[1].rotation.z += 0.18 * k
			_staff_off.z += 0.18 * k
		&"tether":
			# Rift Tether: the staff drawn back over the shoulder, cast out like a line, then hauled
			# back hand over hand, the body leaning against the pull
			var wind := smoothstep(0.0, 0.18, u) * (1.0 - smoothstep(0.18, 0.3, u))
			var throw := smoothstep(0.2, 0.32, u) * (1.0 - smoothstep(0.42, 0.55, u))
			var haul := smoothstep(0.45, 0.6, u) * (1.0 - smoothstep(0.82, 1.0, u))
			_cast_glow = throw + haul * 0.5
			_sh[1].rotation.x += 2.0 * wind + 1.25 * throw + 0.55 * haul
			_el[1].rotation.x += 0.6 * wind - 0.55 * throw + 0.9 * haul
			_staff_off.x += 0.9 * wind - 1.05 * throw + 0.35 * haul
			_torso.rotation.y += 0.3 * wind - 0.35 * throw + 0.15 * haul
			_torso.rotation.x += 0.08 * wind - 0.18 * throw + 0.2 * haul
			_sh[0].rotation.x += 0.9 * haul + 0.3 * throw
			_el[0].rotation.x += 0.9 * haul
			_head.rotation.x += 0.1 * haul
			_pelvis.position.y -= 0.04 * haul
			_hip[0].rotation.x += 0.2 * haul
			_knee[1].rotation.x -= 0.25 * haul
		&"well":
			# Umbral Well: the staff lifted and planted upright before the body, the knees taking
			# it; the free hand reaches out over the ground and drags down
			var lift := smoothstep(0.0, 0.22, u) * (1.0 - smoothstep(0.24, 0.36, u))
			var plant := smoothstep(0.24, 0.36, u) * (1.0 - smoothstep(0.75, 1.0, u))
			var pull := smoothstep(0.3, 0.55, u) * (1.0 - smoothstep(0.8, 1.0, u))
			var drag := smoothstep(0.45, 0.8, u)
			_cast_glow = lift * 0.4 + plant * 0.8
			_sh[1].rotation.x += 0.9 * lift + 0.55 * plant
			_el[1].rotation.x -= 0.3 * lift + 0.2 * plant
			_staff_off.x += -0.15 * lift + 0.12 * plant
			_sh[0].rotation.x += (1.3 - 0.8 * drag) * pull
			_sh[0].rotation.z -= 0.25 * pull
			_el[0].rotation.x -= 0.25 * pull
			_torso.rotation.x -= 0.12 * lift + 0.32 * plant
			_head.rotation.x -= 0.3 * plant
			_pelvis.position.y -= 0.12 * plant
		&"familiar":
			# Bound Shade: the lantern drawn to the chest, then held out and up as the wisp leaves it,
			# the head following it away
			var gather := smoothstep(0.0, 0.25, u) * (1.0 - smoothstep(0.28, 0.42, u))
			var release := smoothstep(0.28, 0.45, u) * (1.0 - smoothstep(0.7, 1.0, u))
			_cast_glow = release * 0.5
			_sh[0].rotation.x += 0.7 * gather + 1.75 * release
			_sh[0].rotation.z += 0.35 * gather - 0.15 * release
			_el[0].rotation.x += 1.2 * gather - 0.1 * release
			_head.rotation.x -= 0.15 * gather - 0.35 * release
			_head.rotation.y += 0.2 * release
			_torso.rotation.x -= 0.08 * gather - 0.06 * release
			_torso.rotation.y += 0.15 * release
			_staff_off.z += 0.1 * release
		&"strike_a", &"strike_b":
			# r31 staff sweep: wound across the body, then whipped through the front arc, the hips
			# leading; strike_b is the backhand the other way
			var side := 1.0 if _cast_kind == &"strike_a" else -1.0
			var wind_k := smoothstep(0.0, 0.18, u) * (1.0 - smoothstep(0.18, 0.34, u))
			var cut := smoothstep(0.14, 0.36, u)
			var k := smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.6, 1.0, u))
			_cast_glow = k * 0.6
			var sweep := lerpf(0.75, -0.8, cut) * side
			_torso.rotation.y += sweep * k
			_chest.rotation.y += sweep * 0.4 * k
			_head.rotation.y -= sweep * 0.35 * k
			_sh[1].rotation.x += (0.9 + 0.35 * wind_k) * k
			_sh[1].rotation.z += 0.35 * side * (1.0 - cut) * k
			_el[1].rotation.x -= 0.45 * k
			_sh[0].rotation.x += 0.35 * k
			_sh[0].rotation.z -= 0.3 * k
			_pelvis.position.y -= 0.04 * k
			_hip[1 if side > 0.0 else 0].rotation.x += 0.25 * k
			_knee[1 if side > 0.0 else 0].rotation.x -= 0.3 * k
			_strike_frame = Basis(Vector3.UP, sweep * 0.6) * Basis(Vector3.BACK, -PI * 0.42 * side)
			_strike_k = k
		&"strike_c", &"heavy":
			# r31 finisher / heavy: the staff swept up overhead and brought down two-handed in front,
			# the knees taking the blow (a heavier, longer cousin of the Nova slam)
			var heavy := _cast_kind == &"heavy"
			var hit_u := 0.42 if heavy else 0.36
			var raise := smoothstep(0.0, hit_u * 0.8, u) * (1.0 - smoothstep(hit_u * 0.8, hit_u, u))
			var slam := smoothstep(hit_u * 0.8, hit_u, u) * (1.0 - smoothstep(0.62, 1.0, u))
			var big := 1.25 if heavy else 1.0
			_cast_glow = raise * 0.5 + slam
			_sh[1].rotation.x += (2.3 * raise + 1.2 * slam) * big
			_sh[0].rotation.x += (2.0 * raise + 1.1 * slam) * big
			_el[1].rotation.x -= 0.4 * raise
			_el[0].rotation.x -= 0.6 * raise + 0.3 * slam
			_torso.rotation.x += (0.14 * raise - 0.42 * slam) * big
			_head.rotation.x += 0.18 * raise - 0.2 * slam
			_pelvis.position.y += 0.03 * raise - 0.16 * slam * big
			for i in 2:
				_hip[i].rotation.x += 0.4 * slam * big
				_knee[i].rotation.x -= 0.75 * slam * big
			_strike_frame = Basis(Vector3.RIGHT, -1.35 * slam + 0.5 * raise)
			_strike_k = maxf(raise, slam)
		&"parry":
			# r31 parry: the staff snapped up across the blow and turned aside
			var k := smoothstep(0.0, 0.1, u) * (1.0 - smoothstep(0.35, 1.0, u))
			_cast_glow = k
			_sh[1].rotation.x += 1.3 * k
			_sh[0].rotation.x += 1.2 * k
			_el[1].rotation.x -= 0.6 * k
			_el[0].rotation.x -= 0.7 * k
			_torso.rotation.y -= 0.35 * k
			_torso.rotation.x -= 0.1 * k
			_strike_frame = Basis(Vector3.BACK, -PI * 0.5) * Basis(Vector3.UP, 0.4)
			_strike_k = k
		&"step":
			# the rift step: thrown forward low, arms and staff trailing, then up again
			var k := smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.3, 1.0, u))
			_cast_glow = k * 0.5
			_torso.rotation.x -= 0.45 * k
			_head.rotation.x += 0.3 * k
			_sh[0].rotation.x -= 0.75 * k
			_sh[1].rotation.x -= 0.6 * k
			_staff_off.x += 0.85 * k
			_pelvis.position.y -= 0.08 * k
			for i in 2:
				_hip[i].rotation.x += 0.2 * k
				_knee[i].rotation.x -= 0.4 * k


## Player calls this when the wanderer is hit: a snap away from the blow on a spring (torso, head,
## the staff wobbling), the arms flung a little. from_world = Vector3.INF: from the front.
func hurt_react(from_world: Vector3, amount := 10.0) -> void:
	if not hero:
		return
	var dir := Vector2(0.0, 1.0)
	if from_world != Vector3.INF:
		var l := global_basis.orthonormalized().inverse() * (from_world - global_position)
		if Vector2(l.x, l.z).length_squared() > 0.01:
			dir = Vector2(l.x, -l.z).normalized()
	var k := clampf(0.55 + amount * 0.025, 0.55, 1.0)
	_hit_sv += Vector2(dir.y, dir.x) * 7.0 * k
	_hit = maxf(_hit, k)


var _hit_s := Vector2.ZERO
var _hit_sv := Vector2.ZERO


func _hit_tick(dt: float) -> void:
	_hit_sv += -_hit_s * 170.0 * dt
	_hit_sv *= exp(-9.0 * dt)
	_hit_s += _hit_sv * dt
	_hit = move_toward(_hit, 0.0, dt * 2.5)
	if _hit_s.length_squared() < 1e-6 and _hit <= 0.0:
		return
	_torso.rotation.x += _hit_s.x * 0.8
	_torso.rotation.z += _hit_s.y * 0.6
	_head.rotation.x += _hit_s.x * 0.7
	_head.rotation.z += _hit_s.y * 0.4
	_staff_off.x += _hit_s.x * 0.9
	_staff_off.z -= _hit_s.y * 0.5
	_sh[0].rotation.z -= absf(_hit_s.x) * 0.5 + _hit * 0.15
	_sh[1].rotation.z += absf(_hit_s.y) * 0.3
	_pelvis.position.y -= _hit * 0.03


## The head (and a little the chest) turns toward look_at_point: enemies, or where the camera looks.
## Less at a run; nothing behind the shoulder.
func _look_tick(speed: float, dt: float) -> void:
	var want := Vector2.ZERO
	if look_at_point != Vector3.INF and _head:
		var l := global_basis.orthonormalized().inverse() * (look_at_point - _head.global_position)
		var yaw := atan2(-l.x, -l.z)
		if absf(yaw) < 2.1:
			var pitch := atan2(l.y, Vector2(l.x, l.z).length())
			want = Vector2(clampf(yaw, -1.1, 1.1), clampf(pitch, -0.45, 0.4))
	var lim := lerpf(1.0, 0.3, clampf(speed / maxf(sprint_speed, 0.1), 0.0, 1.0))
	want *= lim
	if _cast_t >= 0.0 or charge > 0.0:
		want *= 0.4                                  # the cast's own aim wins
	_look = _look.lerp(want, 1.0 - exp(-4.5 * dt))
	_head.rotation.y += _look.x * 0.68
	_torso.rotation.y += _look.x * 0.22
	_head.rotation.x += _look.y * 0.75
	_torso.rotation.x += _look.y * 0.12


## Two-bone leg IK onto the real ground. On flat ground it changes nothing (the stride is authored
## for flat); on stairs and slopes the lower foot drops the pelvis, the higher one bends its knee,
## and both feet tilt to the ground's slope.
func _foot_ik(delta: float) -> void:
	var world := get_world_3d()
	if world == null:
		return
	var space := world.direct_space_state
	var root_y := global_position.y
	var exclude: Array[RID] = []
	var body := get_parent() as CollisionObject3D
	if body:
		exclude.append(body.get_rid())
	var fwd := -global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var a := 1.0 - exp(-18.0 * delta)
	for i in 2:
		var f: Vector3 = (_foot[i] as Node3D).global_position
		var q := PhysicsRayQueryParameters3D.create(Vector3(f.x, root_y + 0.6, f.z), Vector3(f.x, root_y - 0.6, f.z), 1 | 16, exclude)
		var hit := space.intersect_ray(q)
		var off := 0.0
		var pitch := 0.0
		if not hit.is_empty():
			off = clampf((hit.position as Vector3).y - root_y, -0.45, 0.45)
			var n: Vector3 = hit.normal
			pitch = clampf(atan2(-n.dot(fwd), n.y), -0.6, 0.6)   # toe up on an upslope
		_ik_off[i] = lerpf(_ik_off[i], off, a)
		_ik_pitch[i] = lerpf(_ik_pitch[i], pitch, a)
	var drop := minf(0.0, minf(_ik_off[0], _ik_off[1]))
	_pelvis.position.y += drop
	for i in 2:
		_solve_leg(i, _ik_off[i] - drop)


func _solve_leg(i: int, raise: float) -> void:
	var hip := _hip[i] as Node3D
	var knee := _knee[i] as Node3D
	var foot := _foot[i] as Node3D
	if raise > 0.004:
		var target := foot.global_position + Vector3.UP * raise
		var t_local := _pelvis.global_transform.affine_inverse() * target
		var d := t_local - hip.position
		var dist := clampf(Vector2(d.y, d.z).length(), 0.12, THIGH + SHIN - 0.002)
		var dir_ang := atan2(-d.z, -d.y)
		var alpha := acos(clampf((THIGH * THIGH + dist * dist - SHIN * SHIN) / (2.0 * THIGH * dist), -1.0, 1.0))
		var bend := PI - acos(clampf((THIGH * THIGH + SHIN * SHIN - dist * dist) / (2.0 * THIGH * SHIN), -1.0, 1.0))
		hip.rotation.x = dir_ang + alpha
		knee.rotation.x = -bend
	# the sole follows the slope (blended over the stride's own heel-toe roll)
	foot.rotation.x += _ik_pitch[i] * (1.0 - 0.5 * _stride)


## A hanging thing (lantern on its chain, satchel on its strap) as a damped pendulum driven by
## how its pivot actually moves: it lags starts, swings on stops and rocks with the arm swing.
func _swing(key: String, n: Node3D, length: float, rest: Vector3, body: Basis, delta: float) -> void:
	if n == null or not is_instance_valid(n) or delta <= 0.0:
		return
	var dt := minf(delta, 0.05)
	var st: Dictionary = _pend.get(key, {})
	var pos := n.global_position
	if st.is_empty():
		st = {"p": pos, "v": Vector3.ZERO, "th": Vector2.ZERO, "w": Vector2.ZERO}
	var v: Vector3 = (pos - (st["p"] as Vector3)) / dt
	var acc_w: Vector3 = (v - (st["v"] as Vector3)) / dt
	if acc_w.length() > 120.0:
		acc_w = Vector3.ZERO                         # teleports (rift step, respawn)
	var acc := body.inverse() * acc_w
	var th: Vector2 = st["th"]
	var w: Vector2 = st["w"]
	var g := 9.8 / length
	var ang_acc := Vector2(-g * th.x + acc.z / length, -g * th.y - acc.x / length) - w * 3.2
	w += ang_acc * dt
	th = (th + w * dt).clamp(Vector2(-0.8, -0.8), Vector2(0.8, 0.8))
	st["p"] = pos
	st["v"] = v
	st["th"] = th
	st["w"] = w
	_pend[key] = st
	n.global_basis = body * Basis.from_euler(Vector3(rest.x + th.x, rest.y, rest.z + th.y))


## Raise the staff and release a burst of violet motes (kindling and spellcasting). `sound`: a
## StaffSfx kind ("bolt", "lash", ...), "" for none (the caller plays its own).
func cast(sound := "bolt") -> void:
	_gesture_t = 0.0
	if _burst:
		_burst.visible = true
		_burst_t = 0.0
		_burst.restart()
		_burst.emitting = true
	play_cast_sound(sound)


func play_cast_sound(kind := "bolt") -> void:
	if kind == "" or Engine.is_editor_hint() or not is_inside_tree():
		return
	StaffSfx.play(kind, muzzle(), -3.0)


func _ensure_audio() -> void:
	if Engine.is_editor_hint() or _steps != null:
		return
	# Eight layered stone footsteps (tools/refine_sfx.py), never the same one twice in a row,
	# small pitch/volume drift. random_pitch is a ratio (1.0 = none): 1.05 = +-5 %.
	var rand := AudioStreamRandomizer.new()
	rand.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	rand.random_pitch = 1.05
	rand.random_volume_offset_db = 1.5
	for i in STEP_COUNT:
		rand.add_stream(i, load("res://art/audio/step_%d.wav" % i))
	_steps = AudioStreamPlayer3D.new()
	_steps.name = "Steps"
	_steps.stream = rand
	_steps.max_polyphony = 4             # a step never cuts off (or waits for) the previous one
	_steps.unit_size = 3.0
	_steps.max_distance = 18.0
	_steps.bus = "SFX"
	add_child(_steps)
	_cast_sfx = AudioStreamPlayer3D.new()
	_cast_sfx.bus = &"SFX"
	_cast_sfx.name = "CastSfx"
	_cast_sfx.stream = load("res://art/audio/bolt_cast.wav")
	_cast_sfx.max_distance = 22.0
	add_child(_cast_sfx)


const STEP_COUNT := 8
const StaffSfx := preload("res://core/vfx/staff_sfx.gd")
var _step_n := 0


## Every stride gets a step (the old guard skipped any step that landed while the previous
## sample was still ringing, so sprinting dropped beats). Louder at a run than a walk.
func _footstep(speed := 0.0) -> void:
	if _steps == null:
		return
	var run := clampf((speed - 1.0) / maxf(sprint_speed - 1.0, 0.1), 0.0, 1.0)
	# r29: the ground under the step colours it (one sample set for everything read as one soft thud
	# on grass, stair stone, the Keg's boards and the fen alike): pitch and level per surface, and a
	# wet slap in shallow water
	var surf := _surface()
	var sp: Vector2 = SURF_TONE.get(surf, Vector2(1.0, 0.0))
	_steps.volume_db = lerpf(-11.0, -4.0, run) + sp.y
	_steps.pitch_scale = lerpf(0.97, 1.04, run) * sp.x * randf_range(0.97, 1.03)
	_steps.play()
	if surf == &"water":
		Sfx.play("res://art/audio/step_%d.wav" % randi_range(0, STEP_COUNT - 1), global_position, lerpf(-16.0, -9.0, run), 0.62, 0.05)
	_step_n += 1
	if hero and run < 0.5 and _step_n % 2 == 0:
		# walking, the staff is a walking stick: its iron ferrule meets the ground every other step
		StaffSfx.play("tap", global_position + global_basis.x * -0.35, -15.0, 1.0, 0.06)
	if hero and run > 0.55 and _foot[0] is Node3D:
		# a scuff of dust from the planting foot at a run (pooled burst, same key every time)
		var fl := (_foot[0] as Node3D).global_position
		var fr := (_foot[1] as Node3D).global_position
		var at := fl if fl.y < fr.y else fr
		Vfx.burst(at + Vector3.UP * 0.04, Color(0.17, 0.16, 0.18, 0.4), {"count": 6, "life": 0.45, "speed": Vector2(0.3, 0.9), "size": 0.13, "gravity": -0.3, "dir": Vector3.UP, "spread": 70.0, "additive": false, "radius": 0.08})


## pitch x, extra dB y, per surface
const SURF_TONE := {&"grass": Vector2(0.9, -2.5), &"fen": Vector2(0.84, -1.0), &"water": Vector2(0.8, 0.0),
	&"ash": Vector2(1.06, -1.0), &"stone": Vector2(1.12, 1.0), &"wood": Vector2(0.96, 0.5)}
var _surf_t := -1.0
var _surf: StringName = &"grass"


## What the wanderer is standing on, from one short ray (cached for 0.3 s: several steps share it).
func _surface() -> StringName:
	if not hero or not is_inside_tree() or Engine.is_editor_hint():
		return &""
	if _t - _surf_t < 0.3:
		return _surf
	_surf_t = _t
	var from := global_position + Vector3.UP * 0.4
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.2, Layers.WORLD | Layers.PROPS)) if space else {}
	var gp := global_position
	var on_terrain := hit.is_empty() or (hit.collider is Node and String((hit.collider as Node).name).begins_with("Terrain"))
	if on_terrain and Realm.enabled() and _land_script().call("in_water", gp.x, gp.z):
		_surf = &"water"
	elif on_terrain:
		var biome := RealmLayout.biome_at(gp.x, gp.z) if Realm.enabled() else "meadow"
		_surf = &"fen" if biome == "fen" else (&"ash" if biome == "ash" else &"grass")
	else:
		var nm := String((hit.collider as Node).name).to_lower() if hit.collider is Node else ""
		_surf = &"wood" if (nm.contains("board") or nm.contains("deck") or nm.contains("floor") or nm.contains("dock") or nm.contains("bridge")) else &"stone"
	return _surf


var _land_gd: GDScript              ## instance, not static: no engine resource outlives the tree at exit


func _land_script() -> GDScript:
	if _land_gd == null:
		_land_gd = load("res://core/world/realm/realm_land.gd")
	return _land_gd


## Landing: two heavy steps pitched down, scaled by how hard you came down.
func _landing_sfx(force: float) -> void:
	if Engine.is_editor_hint():
		return
	var at := global_position
	Sfx.play("res://art/audio/step_%d.wav" % randi_range(0, STEP_COUNT - 1), at, lerpf(-8.0, -1.0, force), 0.78, 0.03)
	Sfx.play("res://art/audio/step_%d.wav" % randi_range(0, STEP_COUNT - 1), at, lerpf(-12.0, -4.0, force), 0.9, 0.03)


## World-space spawn at the staff orb. Falls back to the chest if the weapon is missing.
func muzzle() -> Vector3:
	if _orb:
		return _orb.global_position
	if _chest:
		return _chest.global_position
	return global_position + Vector3.UP * 1.4


const CL_N := 12
const CL_NAMES := ["cloth_lag", "walk_phase", "stride", "foot_l", "foot_r", "foot_radius", "chest_x", "chest_y", "knee_l", "knee_r", "hip_l", "hip_r"]
var _cl_prev: Array = []          ## cloth shader inputs at the last two physics ticks (merged body)
var _cl_cur: Array = []
var _cl_sent: Array = []


## The robe's instance inputs at fraction `f` between the last two ticks, sent only when changed.
func _push_cloth(f: float) -> void:
	if _body_mi == null or _cl_cur.size() != CL_N:
		return
	if _cl_sent.size() != CL_N:
		_cl_sent.resize(CL_N)
	for i in CL_N:
		var a: Variant = _cl_prev[i]
		var b: Variant = _cl_cur[i]
		var v: Variant
		if i == 1:
			v = float(a) + wrapf(float(b) - float(a), -PI, PI) * f      # walk phase: an angle
		elif b is Vector3:
			v = (a as Vector3).lerp(b, f)
		else:
			v = lerpf(float(a), float(b), f)
		var last: Variant = _cl_sent[i]
		if last != null and typeof(last) == typeof(v):
			if v is Vector3 and (v as Vector3).is_equal_approx(last):
				continue
			if v is float and is_equal_approx(float(v), float(last)):
				continue
		_cl_sent[i] = v
		_body_mi.set_instance_shader_parameter(CL_NAMES[i], v)


## Where the staff orb is DRAWN this rendered frame (its driver moves on physics ticks; the body
## and the merged skin are interpolated between them). For things placed every frame on the orb.
func muzzle_drawn() -> Vector3:
	if _orb and _orb.is_inside_tree() and not Engine.is_in_physics_frame():
		return _orb.get_global_transform_interpolated().origin
	return muzzle()


## Drop a traversal pose at once (teleports, respawns): the next tick poses from scratch.
func cancel_move() -> void:
	_mv_t = -1.0
	_mv = &""
	_land_hard = 0.0


func _process(delta: float) -> void:
	if _skel != null:
		# a tick without animate() (a held pose): show the last capture, don't blend
		var live := is_physics_interpolated_and_enabled() and Engine.get_physics_frames() - _cap_frame < 2
		var f := Engine.get_physics_interpolation_fraction() if live else 1.0
		_apply_bones(f)
		_push_cloth(f)
	if Engine.is_editor_hint() or driven:
		return
	# Idle-only fallback when no player drives the rig (e.g. a preview scene).
	if get_parent() == null or not get_parent().has_method("hollow"):
		animate(Vector3.ZERO, true, delta)


# =================================================================================================
# Hero locomotion (r28). A real gait instead of a sine stride: each foot is either PLANTED (held
# where it touched down in the world, so it never slides, and it pivots as the body turns) or
# SWINGING along an arc to where the next touchdown will be, relative to the body. Step length,
# duty factor (the share of the cycle a foot is down) and lift follow the speed: a walk always
# keeps a foot down, a run has a flight phase, a sprint lands long. The step follows the travel
# direction, so strafing side-steps and backpedalling steps back. Standing, the feet step back
# under the body whenever it turns or drifts off them (turning on the spot, combat facing, the
# last step of a stop). Legs are solved by two-bone IK onto the targets; airborne, sliding,
# hanging and the traversal poses blend back to forward kinematics (plant_k).
# =================================================================================================

const H_LEG := 0.40                 ## the wanderer's thigh = shin
const H_PELVIS := 0.955             ## pelvis height standing (hip 0.765: soft knees under the robe)
const BALL := 0.1                   ## sole point -> ball of the foot: the heel rises about it
const TOE_OUT := 0.07
const STEP_KEYS := [[0.0, 0.3], [1.5, 0.52], [3.0, 0.78], [4.5, 1.0], [7.5, 1.5], [11.0, 1.8]]

## Traversal state the Player feeds in (all 0..1 blends unless noted).
var ride := 0.0                     ## r36: astride a horse (core/world/mount): 0..1
var hang := 0.0                     ## hanging from a ledge by the hands
var hang_shimmy := 0.0              ## -1..1 moving sideways along the ledge
var steep := 0.0                    ## sliding down a slope too steep to stand on
var beam := 0.0                     ## balancing on something narrow
var twist := 0.0                    ## rad, + left: the upper body turned toward the aim
var lock := false                   ## locked on to a foe: squared up, staff ready

var _g_mode := 0                    ## 0 standing (settle steps), 1 cycling
var _cyc := 0.0                     ## 0..1 gait cycle, left touchdown at 0, right at 0.5
var _g_dir := Vector2(0.0, -1.0)    ## travel direction, rig-local (x right, y = z, -1 forward)
var _g_L := 0.5
var _g_W := 0.5
var _g_td := 0.25                   ## touchdown point ahead of the hip along the travel
var _g_lo := 0.25                   ## lift-off point behind it
var _g_D := 0.6
var _g_run := 0.0
var _g_spr := 0.0
var _g_hip := 0.765
var _g_stop_t := 0.0
var _g_air := true
var _g_prev := Vector3.INF
var _g_yaw := 0.0
var _g_ex: Array[RID] = []
var _plant_k := 0.0
var _f_sw := [false, false]
var _f_pos := [Vector3.ZERO, Vector3.ZERO]
var _f_yaw := [0.0, 0.0]
var _f_n := [Vector3.UP, Vector3.UP]
var _f_from := [Vector3.ZERO, Vector3.ZERO]
var _f_from_yaw := [0.0, 0.0]
var _f_u0 := [0.0, 0.0]
var _f_st := [0.0, 0.0]
var _f_dur := [0.2, 0.2]
var _f_out := [Vector3.ZERO, Vector3.ZERO]
var _f_out_yaw := [0.0, 0.0]
var _f_out_pitch := [0.0, 0.0]
var _f_out_n := [Vector3.UP, Vector3.UP]
var _f_su := [0.0, 0.0]             ## 0..1 through the stance, -1 swinging
var _pel_drop := 0.0
var _flight := 0.0
var _hip_yaw := 0.0
var _land_hard := 0.0
var _staff_frame := Basis.IDENTITY
var _hood_s := Vector2.ZERO
var _hood_v := Vector2.ZERO
var _hood_pp := Vector3.INF
var _hood_pv := Vector3.ZERO
# timed moves (Player -> play_move)
var _mv := &""
var _mv_t := -1.0
var _mv_len := 0.5
var _mv_side := 1.0
# idle acts
var _still := 0.0
var _ia := -1
var _ia_last := -1
var _ia_t := 0.0
var _ia_len := 3.0
var _ia_next := 5.0
var _ia_k := 0.0
var _rng := RandomNumberGenerator.new()
const LEG_MOVES := [&"roll", &"hop", &"vault", &"climb", &"mantle", &"wallkick"]


func _gait_ok() -> bool:
	return hero and foot_ik and not Engine.is_editor_hint() and is_inside_tree() and _hip[0] != null


## Traversal and dodge poses: &"roll" (forward roll: a dodge or a hard landing carried), &"hop"
## (backstep), &"vault", &"climb" (hang -> standing on the ledge), &"wallkick", &"land_hard".
func play_move(kind: StringName, length: float, side := 1.0) -> void:
	_mv = kind
	_mv_t = 0.0
	_mv_len = maxf(length, 0.05)
	_mv_side = side
	if kind == &"land_hard":
		_land_hard = 1.0


func move_playing() -> StringName:
	return _mv if _mv_t >= 0.0 else &""


func _legs_free() -> bool:
	return hang < 0.05 and steep < 0.3 and not (_mv_t >= 0.0 and LEG_MOVES.has(_mv))


func _step_len(v: float) -> float:
	if v <= 0.0:
		return 0.3
	for k in range(1, STEP_KEYS.size()):
		var a: Array = STEP_KEYS[k - 1]
		var b: Array = STEP_KEYS[k]
		if v <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (v - float(a[0])) / (float(b[0]) - float(a[0])))
	return 1.8


## How far along the travel a sole may sit from under the hip before it leaves the robe: the hem
## covers ~0.46 m in front (the shader carries it over the leading boot) but only ~0.3 m behind.
## `back` = the travel direction's z (rig +z is behind).
func _robe_reach(back: float) -> float:
	var r := (0.46 if _g_dir.y < 0.3 else 0.3) if back <= 0.0 else 0.3    # back-pedalling: the front is the trail
	return r / maxf(absf(back), 0.25) if absf(back) > 0.01 else 4.0


func _foot_w() -> float:
	return lerpf(0.105, 0.075, _g_run) * lerpf(1.0, 0.25, beam)


## Ground under a world point near the rig's height: [position, normal]. Misses and wall faces
## give a level spot at the rig's own height.
func _ground(w: Vector3, ref_y: float) -> Array:
	var world := get_world_3d()
	if world == null:
		return [Vector3(w.x, ref_y, w.z), Vector3.UP]
	if _g_ex.is_empty():
		var body := get_parent() as CollisionObject3D
		if body:
			_g_ex.append(body.get_rid())
	var q := PhysicsRayQueryParameters3D.create(Vector3(w.x, ref_y + 0.75, w.z), Vector3(w.x, ref_y - 0.9, w.z), 1 | 16, _g_ex)
	var hit := world.direct_space_state.intersect_ray(q)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.5:
		return [Vector3(w.x, ref_y, w.z), Vector3.UP]
	return [hit.position, hit.normal]


func _rig_yaw(xf: Transform3D) -> float:
	var f := -xf.basis.z
	return atan2(-f.x, -f.z)


func _gait_reset(xf: Transform3D) -> void:
	var by := _rig_yaw(xf)
	for i in 2:
		var spot := xf * Vector3((-1.0 if i == 0 else 1.0) * 0.12, 0.0, -0.03 if i == 0 else 0.03)
		_plant(i, _ground(spot, xf.origin.y), by)
		_f_out[i] = _f_pos[i]
	_g_mode = 0
	_g_prev = xf.origin


func _plant(i: int, g: Array, by: float) -> void:
	_f_sw[i] = false
	_f_pos[i] = g[0]
	_f_n[i] = g[1]
	_f_yaw[i] = by + (-TOE_OUT if i == 0 else TOE_OUT)
	_f_out[i] = g[0]
	_f_out_yaw[i] = _f_yaw[i]
	_f_out_n[i] = g[1]
	_f_out_pitch[i] = 0.0
	_f_su[i] = 0.0


func _lift(i: int, c: float) -> void:
	_f_sw[i] = true
	_f_u0[i] = c
	_f_from[i] = _f_out[i]
	_f_from_yaw[i] = _f_out_yaw[i]
	_f_su[i] = -1.0


func _gait_advance(speed: float, flat: Vector3, on_floor: bool, dt: float) -> void:
	var xf := global_transform.orthonormalized()
	var by := _rig_yaw(xf)
	_g_yaw = by
	if _g_prev == Vector3.INF or xf.origin.distance_squared_to(_g_prev) > 2.25:
		_gait_reset(xf)
	# treadmill: a rig shown moving without going anywhere (studio previews) carries its planted
	# feet back at the speed it claims, so the stride still reads
	var moved := xf.origin - _g_prev
	if Vector2(moved.x, moved.z).length() < 0.0005 and speed > 0.05:
		for i in 2:
			_f_pos[i] -= flat * dt
			_f_from[i] -= flat * dt
	_g_prev = xf.origin
	var lv := xf.basis.inverse() * flat
	var l2 := Vector2(lv.x, lv.z)
	if speed > 0.25 and l2.length_squared() > 0.0001:
		var a := _g_dir.angle_to(l2)
		_g_dir = _g_dir.rotated(clampf(a, -14.0 * dt, 14.0 * dt)).normalized()
	_g_run = smoothstep(2.0, 4.2, speed)
	_g_spr = smoothstep(5.4, 7.4, speed)
	var L := _step_len(speed) * lerpf(1.0, 0.62, absf(_g_dir.x)) * lerpf(1.0, 0.65, beam)
	_g_hip = H_PELVIS - 0.19 - 0.045 * smoothstep(0.3, 1.6, speed) - 0.035 * _g_run - 0.03 * _g_spr
	var reach := 2.0 * H_LEG * 0.985
	var cap := 2.0 * sqrt(maxf(reach * reach - _g_hip * _g_hip, 0.01)) * 0.95 + BALL * 0.6 * _g_run
	var d_nom := lerpf(lerpf(0.62, 0.42, _g_run), 0.32, _g_spr)
	_g_L = L
	_g_W = minf(2.0 * L * d_nom, cap)
	# where the touchdown and lift-off points fall along the travel: kept inside the robe's
	# silhouette (a sole behind the hem reads as a stray boot), the lost stance becomes flight
	var ff := lerpf(0.52, 0.56, _g_run)
	_g_td = minf(_g_W * ff, _robe_reach(_g_dir.y))
	_g_lo = minf(_g_W * (1.0 - ff), _robe_reach(-_g_dir.y))
	_g_D = clampf((_g_td + _g_lo) / maxf(2.0 * L, 0.05), 0.2, 0.66)
	var plant := on_floor and slide < 0.05 and _legs_free()
	_plant_k = move_toward(_plant_k, 1.0 if plant else 0.0, dt * (9.0 if plant else 14.0))
	if not plant:
		_g_air = true
		return
	if _g_air:
		_g_air = false
		_land_feet(xf, by, speed)
	if _g_mode == 1:
		_g_stop_t = _g_stop_t + dt if speed < 0.35 else 0.0
		if _g_stop_t > 0.06:
			_enter_settle()
		else:
			_cycle(speed, xf, by, dt)
	if _g_mode == 0:
		if speed > 0.6:
			_enter_cycle(xf)
			_cycle(speed, xf, by, dt)
		else:
			_settle(xf, by, dt)
	_phase = _cyc * TAU + PI * 0.5


## Touching down from the air: both feet planted where the air pose put them, the leading one
## first if the landing runs on.
func _land_feet(xf: Transform3D, by: float, speed: float) -> void:
	for i in 2:
		_plant(i, _ground((_foot[i] as Node3D).global_position, xf.origin.y), by)
	if speed <= 0.6:
		_g_mode = 0
		return
	_g_mode = 1
	_g_stop_t = 0.0
	var along := xf.basis * Vector3(_g_dir.x, 0.0, _g_dir.y)
	var lead := 0 if ((_f_pos[0] as Vector3) - (_f_pos[1] as Vector3)).dot(along) > 0.0 else 1
	_cyc = fposmod(0.02 - 0.5 * float(lead), 1.0)
	var other := 1 - lead
	var co := fposmod(_cyc + 0.5 * float(other), 1.0)
	if co >= _g_D:
		_lift(other, co)


func _enter_cycle(xf: Transform3D) -> void:
	_g_mode = 1
	_g_stop_t = 0.0
	var along := xf.basis * Vector3(_g_dir.x, 0.0, _g_dir.y)
	# the foot further back swings first; the other carries the body through its stance
	var sw := 0 if ((_f_out[0] as Vector3) - (_f_out[1] as Vector3)).dot(along) < 0.0 else 1
	if _f_sw[0] != _f_sw[1]:
		sw = 0 if _f_sw[0] else 1
	var st := 1 - sw
	if _f_sw[st]:
		_plant(st, _ground(_f_out[st], xf.origin.y), _f_out_yaw[st])
	_cyc = fposmod(_g_D * 0.35 - 0.5 * float(st), 1.0)
	var csw := fposmod(_cyc + 0.5 * float(sw), 1.0)
	_lift(sw, csw)


func _enter_settle() -> void:
	_g_mode = 0
	for i in 2:
		if _f_sw[i]:
			_f_from[i] = _f_out[i]
			_f_from_yaw[i] = _f_out_yaw[i]
			_f_st[i] = 0.0
			_f_dur[i] = 0.16


func _cycle(speed: float, xf: Transform3D, by: float, dt: float) -> void:
	var prev := _cyc
	_cyc = fposmod(_cyc + speed * dt / maxf(2.0 * _g_L, 0.1), 1.0)
	var along := Vector3(_g_dir.x, 0.0, _g_dir.y)
	var lift := lerpf(0.07, 0.15, _g_run) + 0.06 * _g_spr     # (a high heel kick shows the leg through the robe)
	var flying := true
	for i in 2:
		var c0 := fposmod(prev + 0.5 * float(i), 1.0)
		var c := fposmod(_cyc + 0.5 * float(i), 1.0)
		var td := xf * (Vector3((-1.0 if i == 0 else 1.0) * _foot_w(), 0.0, 0.0) + along * _g_td)
		if _f_sw[i]:
			if c < c0:
				_plant(i, _ground(td, xf.origin.y), by)        # touchdown
				_footstep(speed)
			else:
				var u := clampf((c - (_f_u0[i] as float)) / maxf(1.0 - (_f_u0[i] as float), 0.02), 0.0, 1.0)
				_swing_foot(i, _ground(td, xf.origin.y), by, u, lift)
		if not _f_sw[i]:
			if c >= _g_D and c < 0.98:
				_lift(i, c)
				_f_out_pitch[i] = -(0.3 + 0.45 * _g_run)
			else:
				flying = false
				var su := clampf(c / maxf(_g_D, 0.05), 0.0, 1.0) if c < 0.98 else 0.0
				_stance(i, su)
	_flight = lerpf(_flight, 1.0 if flying else 0.0, 1.0 - exp(-30.0 * dt))


func _stance(i: int, su: float) -> void:
	_f_su[i] = su
	_f_out[i] = _f_pos[i]
	_f_out_yaw[i] = _f_yaw[i]
	_f_out_n[i] = _f_n[i]
	var heel := smoothstep(0.55, 1.0, su) * (0.3 + 0.45 * _g_run) * (1.0 if _g_mode == 1 else 0.0)
	var strike := (1.0 - smoothstep(0.0, 0.2, su)) * 0.14 * (1.0 - _g_run) * (1.0 if _g_mode == 1 else 0.0)
	_f_out_pitch[i] = strike - heel


func _swing_foot(i: int, g: Array, by: float, u: float, lift: float) -> void:
	var dest: Vector3 = g[0]
	var from: Vector3 = _f_from[i]
	# out of the back quickly (a heel kicked up behind the hem reads as a stray boot), eased in
	var e := 0.5 * u * u * (3.0 - 2.0 * u) + 0.5 * (1.0 - (1.0 - u) * (1.0 - u))
	var p := from.lerp(dest, e)
	p.y = lerpf(from.y, dest.y, smoothstep(0.0, 0.7, u)) + lift * pow(sin(PI * pow(u, 0.75)), 0.9)
	_f_out[i] = p
	_f_out_yaw[i] = lerp_angle(_f_from_yaw[i], by + (-TOE_OUT if i == 0 else TOE_OUT), e)
	_f_out_pitch[i] = lerpf(-0.3 - 0.45 * _g_run, 0.16 * (1.0 - _g_run) + 0.04, smoothstep(0.05, 0.85, u))
	_f_out_n[i] = Vector3.UP.slerp((g[1] as Vector3).normalized(), e)


## Standing: planted feet stay put (they pivot with the body); when the body has turned or drifted
## too far off one, it steps back under the hip, one foot at a time.
func _settle(xf: Transform3D, by: float, dt: float) -> void:
	var want := -1
	var worst := 1.0
	var inv := xf.affine_inverse()
	for i in 2:
		var spot := Vector3((-1.0 if i == 0 else 1.0) * lerpf(0.12, 0.04, beam), 0.0, -0.035 if i == 0 else 0.035)
		if _f_sw[i]:
			_f_st[i] += dt
			var u := clampf((_f_st[i] as float) / (_f_dur[i] as float), 0.0, 1.0)
			var g := _ground(xf * spot, xf.origin.y)
			var e := smoothstep(0.0, 1.0, u)
			var from: Vector3 = _f_from[i]
			var p := from.lerp(g[0], e)
			p.y = lerpf(from.y, (g[0] as Vector3).y, e) + 0.05 * sin(PI * u)
			_f_out[i] = p
			_f_out_yaw[i] = lerp_angle(_f_from_yaw[i], by + (-TOE_OUT if i == 0 else TOE_OUT), e)
			_f_out_pitch[i] = 0.12 * sin(PI * u)
			_f_out_n[i] = Vector3.UP
			if u >= 1.0:
				_plant(i, g, by)
				_scuff()
		else:
			_stance(i, 0.4)
			var l := inv * (_f_pos[i] as Vector3)
			var err := Vector2(l.x - spot.x, l.z - spot.z).length()
			var yerr := absf(angle_difference(_f_yaw[i] as float, by))
			var score := maxf(err / 0.14, yerr / 0.6)
			if score > worst:
				worst = score
				want = i
	if want >= 0 and not _f_sw[0] and not _f_sw[1]:
		_f_sw[want] = true
		_f_from[want] = _f_pos[want]
		_f_from_yaw[want] = _f_yaw[want]
		_f_st[want] = 0.0
		_f_dur[want] = clampf(0.26 - absf(_turn) * 0.025, 0.16, 0.26)
		_f_su[want] = -1.0


## A quiet step when a foot resettles on the spot.
func _scuff() -> void:
	if _steps == null or not is_inside_tree():
		return
	_steps.volume_db = -17.0
	_steps.pitch_scale = 0.94
	_steps.play()


## Gait body: pelvis height (stance compression at a run, a rise at a walk, a little lift in the
## flight phase), hips turned toward a side-step, a sprinter's forward pitch, landings.
func _gait_body(_speed: float, on_floor: bool, idle: float, breathe: float, dt: float) -> void:
	_pelvis.rotation.x = 0.0
	_pelvis.position.z = 0.0
	_chest.rotation = Vector3.ZERO
	var bob := 0.0
	if _g_mode == 1 and on_floor:
		for i in 2:
			if (_f_su[i] as float) >= 0.0:
				bob += lerpf(0.016, -0.045, _g_run) * sin(PI * clampf(_f_su[i] as float, 0.0, 1.0))
	bob += _flight * 0.024 * _g_run
	_land_hard = move_toward(_land_hard, 0.0, dt * 1.5)
	var hard := sin(clampf(_land_hard, 0.0, 1.0) * PI * 0.5)
	_pelvis.position.y = _g_hip + 0.19 + bob * _plant_k - _land * 0.15 - hard * 0.26 + _air * 0.04 + breathe * 0.004 * idle
	# side-steps: the hips turn toward the step, the chest stays on the aim
	var ang := atan2(-_g_dir.x, -_g_dir.y)
	var hy := ang * 0.5 if absf(ang) <= PI * 0.5 else (ang - signf(ang) * PI) * 0.4
	hy *= clampf(_stride * 1.6, 0.0, 1.0)
	_hip_yaw = lerp_angle(_hip_yaw, hy, 1.0 - exp(-8.0 * dt))
	_pelvis.rotation.y += _hip_yaw
	_torso.rotation.y -= _hip_yaw * 0.85
	# sprint: pitched from the hips, head up to see where it's going
	_pelvis.rotation.x -= 0.07 * _g_spr * _stride
	_torso.rotation.x -= 0.1 * _g_spr
	_head.rotation.x += 0.1 * _g_spr
	if lock:
		_pelvis.position.y -= 0.03


func _align_up(b: Basis, n: Vector3) -> Basis:
	var nn := n.normalized()
	if nn.y > 0.9995:
		return b
	var axis := Vector3.UP.cross(nn).normalized()
	var ang := minf(acos(clampf(nn.y, -1.0, 1.0)), 0.5)
	return Basis(axis, ang) * b


## Legs onto the feet: the pelvis comes down when a planted foot would be out of reach, then a
## two-bone solve per leg with the knee toward the toe, the sole on the ground.
func _gait_legs(dt: float) -> void:
	if _plant_k <= 0.001:
		_pel_drop = lerpf(_pel_drop, 0.0, 1.0 - exp(-10.0 * dt))
		return
	var xf := global_transform.orthonormalized()
	var inv := xf.affine_inverse()
	var by := _rig_yaw(xf)
	var reach := 2.0 * H_LEG * 0.995
	var tgt := [Vector3.ZERO, Vector3.ZERO]
	var fb := [Basis.IDENTITY, Basis.IDENTITY]
	var yb := [Basis.IDENTITY, Basis.IDENTITY]
	for i in 2:
		var y := Basis(Vector3.UP, wrapf((_f_out_yaw[i] as float) - by, -PI, PI))
		var p: float = _f_out_pitch[i]
		var sole: Vector3 = inv * (_f_out[i] as Vector3)
		if p < 0.0:
			sole += y * Vector3(0.0, -BALL * sin(p), -BALL + BALL * cos(p))
		tgt[i] = sole
		yb[i] = y
		fb[i] = _align_up(y, inv.basis * (_f_out_n[i] as Vector3)) * Basis(Vector3.RIGHT, p)
	var need := 0.0
	for i in 2:
		var hip_l: Vector3 = _pelvis.transform * (_hip[i] as Node3D).position
		var d: Vector3 = (tgt[i] as Vector3) - hip_l
		var h := Vector2(d.x, d.z).length()
		var allowed := sqrt(maxf(reach * reach - h * h, 0.0))
		need = maxf(need, -d.y - allowed)
	need = clampf(need, 0.0, 0.3) * _plant_k
	_pel_drop = lerpf(_pel_drop, need, 1.0 - exp(-(40.0 if need > _pel_drop else 10.0) * dt))
	_pelvis.position.y -= _pel_drop
	for i in 2:
		_leg_ik(i, tgt[i], fb[i], yb[i], _plant_k)


func _leg_ik(i: int, ank: Vector3, foot_b: Basis, yaw_b: Basis, w: float) -> void:
	var hip := _hip[i] as Node3D
	var knee := _knee[i] as Node3D
	var foot := _foot[i] as Node3D
	var P := _pelvis.transform
	var d := P.affine_inverse() * ank - hip.position
	var dl := d.length()
	var dist := clampf(dl, 0.12, 2.0 * H_LEG - 0.002)
	var dn := d / dl if dl > 0.001 else Vector3.DOWN
	var a := acos(clampf(dist / (2.0 * H_LEG), -1.0, 1.0))
	var pole := P.basis.inverse() * (yaw_b * Vector3.FORWARD)
	pole -= dn * dn.dot(pole)
	pole = pole.normalized() if pole.length_squared() > 1e-6 else Vector3.FORWARD
	var u := dn * cos(a) + pole * sin(a)
	var zb := -(pole - u * u.dot(pole)).normalized()
	var ybv := -u
	var hb := Basis(ybv.cross(zb), ybv, zb).orthonormalized()
	hip.quaternion = hip.quaternion.slerp(hb.get_rotation_quaternion(), w)
	knee.rotation = Vector3(lerpf(knee.rotation.x, -2.0 * a, w), 0.0, 0.0)
	var chain := P.basis * hip.basis * knee.basis
	var fl := (chain.inverse() * foot_b).orthonormalized()
	foot.quaternion = foot.quaternion.slerp(fl.get_rotation_quaternion(), w)


# --- traversal, dodge, idle life (forward kinematics, layered last) ---------------------------------

func _moves_pose(speed: float, on_floor: bool, dt: float) -> void:
	_staff_frame = Basis.IDENTITY
	var sf_yaw := twist * 0.8
	# aim twist: the chest turns toward the aim while the hips keep to the run
	_torso.rotation.y += twist * 0.5
	_chest.rotation.y += twist * 0.3
	if lock:
		_staff_off.x -= 0.12
		_sh[1].rotation.x += 0.18
		_sh[0].rotation.x += 0.15
		_el[0].rotation.x += 0.2
	# in the air: rising, the leading knee drives up; falling, the legs reach down and the arms open
	if not on_floor and hang < 0.05 and _mv_t < 0.0 and slide < 0.05:
		var rise := clampf(_vy / 5.0, 0.0, 1.0) * _air
		var fall := clampf(-_vy / 9.0, 0.0, 1.0) * _air
		_hip[0].rotation.x += 0.35 * rise
		_knee[0].rotation.x -= 0.4 * rise
		_hip[1].rotation.x -= 0.5 * rise
		_knee[1].rotation.x += 0.35 * rise
		for i in 2:
			_knee[i].rotation.x += 0.55 * fall
			_hip[i].rotation.x -= 0.2 * fall
		_sh[0].rotation.z -= 0.45 * fall
		_sh[0].rotation.x += 0.35 * fall
		_sh[1].rotation.z += 0.25 * fall
		_torso.rotation.x += 0.08 * fall
		_head.rotation.x -= 0.12 * fall
	if _land_hard > 0.0:
		# a hard landing: down on one knee's worth, the free hand to the ground, then up
		var k := sin(clampf(_land_hard, 0.0, 1.0) * PI * 0.5)
		_torso.rotation.x -= 0.5 * k
		_head.rotation.x += 0.35 * k
		_sh[0].rotation.x += 0.75 * k
		_sh[0].rotation.z -= 0.2 * k
		_el[0].rotation.x -= 0.2 * k
		_staff_off.x -= 0.25 * k
		_sh[1].rotation.z += 0.35 * k
	if ride > 0.001:
		_pose_ride(ride)
	if hang > 0.001:
		_pose_hang(hang)
		_staff_frame = _staff_frame.slerp(Basis(Vector3.BACK, -PI * 0.5) * Basis(Vector3.RIGHT, 0.12), hang)
	if steep > 0.001:
		_pose_steep(steep)
	if beam > 0.001:
		var k := beam
		var sway := sin(_t * 2.3) * 0.06 + sin(_t * 3.7 + 1.0) * 0.03
		_sh[0].rotation.z -= 1.15 * k + sway * 2.0 * k
		_sh[0].rotation.x += 0.1 * k
		_el[0].rotation.x -= 0.15 * k
		_sh[1].rotation.z += 0.75 * k - sway * 1.5 * k
		_sh[1].rotation.x += 0.35 * k
		_torso.rotation.z += sway * k
		_head.rotation.z -= sway * 0.6 * k
		_head.rotation.x -= 0.18 * k                  # watching the footing
		_staff_frame = _staff_frame.slerp(Basis(Vector3.BACK, -PI * 0.5), k * 0.85)
	_combat_pose()
	if _mv_t >= 0.0:
		_mv_t += dt
		var u := _mv_t / _mv_len
		if u >= 1.0:
			_mv_t = -1.0
		else:
			match _mv:
				&"roll":
					_pose_roll(u)
				&"hop":
					var k := sin(PI * u)
					_torso.rotation.x -= 0.3 * k
					_pelvis.position.y -= 0.06 * k
					_sh[0].rotation.x += 0.5 * k
					_sh[1].rotation.x += 0.3 * k
					_staff_off.x -= 0.3 * k
					for i in 2:
						_hip[i].rotation.x += 0.5 * k
						_knee[i].rotation.x -= 0.8 * k
				&"vault":
					_pose_vault(u)
				&"climb":
					_pose_climb(u)
				&"mantle":
					_pose_climb(0.35 + 0.65 * u)         # the same, from hands already on the top
				&"wallkick":
					_pose_wallkick(u)
	_staff_frame = Basis(Vector3.UP, sf_yaw) * _staff_frame
	_idle_acts(speed, on_floor, dt)
	_hood_tick(dt)


## Tucked forward roll about the body's middle: the whole skeleton turns once, the staff with it.
func _pose_roll(u: float) -> void:
	var k := smoothstep(0.0, 0.14, u) * (1.0 - smoothstep(0.78, 1.0, u))
	var spin := -TAU * smoothstep(0.06, 0.86, u)
	var centre := Vector3(0.0, lerpf(_pelvis.position.y, 0.5, k), 0.0)
	_pelvis.position = centre + Basis(Vector3.RIGHT, spin) * Vector3(0.0, -0.12 * k, 0.0)
	_pelvis.rotation.x += spin
	for i in 2:
		_hip[i].rotation.x = lerpf(_hip[i].rotation.x, 1.75 - 0.15 * float(i), k)
		_knee[i].rotation.x = lerpf(_knee[i].rotation.x, -2.3, k)
		_foot[i].rotation.x = lerpf(_foot[i].rotation.x, -0.4, k)
	_torso.rotation.x = lerpf(_torso.rotation.x, -0.75, k)
	_head.rotation.x = lerpf(_head.rotation.x, -0.55, k)
	_sh[0].rotation.x = lerpf(_sh[0].rotation.x, 0.9, k)
	_sh[0].rotation.z = lerpf(_sh[0].rotation.z, -0.1, k)
	_el[0].rotation.x = lerpf(_el[0].rotation.x, 1.4, k)
	_sh[1].rotation.x = lerpf(_sh[1].rotation.x, 0.7, k)
	_el[1].rotation.x = lerpf(_el[1].rotation.x, 1.1, k)
	_staff_off.x = lerpf(_staff_off.x, 1.2, k)        # the staff tucked along the body
	_staff_frame = Basis(Vector3.RIGHT, spin) * _staff_frame


## Hanging by the hands: arms overhead, the body long against the wall, toes finding it; the staff
## laid along the ledge in the right fist. Shimmying swings the legs and walks the hands.
## r36 astride a horse: thighs forward and spread round the barrel, knees bent, heels down, the
## back upright, both hands low in front on the reins (the staff rides on the back: its own offset).
func _pose_ride(k: float) -> void:
	var bob := sin(_t * 9.0) * 0.012
	_pelvis.position.y = lerpf(_pelvis.position.y, H_PELVIS + bob, k)
	_torso.rotation.x = lerpf(_torso.rotation.x, 0.06, k)
	_torso.rotation.y = lerpf(_torso.rotation.y, 0.0, k)
	_head.rotation.x = lerpf(_head.rotation.x, -0.05, k)
	_sh[0].rotation = _sh[0].rotation.lerp(Vector3(0.55, 0.0, -0.18), k)
	_sh[1].rotation = _sh[1].rotation.lerp(Vector3(0.55, 0.0, 0.18), k)
	_el[0].rotation.x = lerpf(_el[0].rotation.x, 0.9, k)
	_el[1].rotation.x = lerpf(_el[1].rotation.x, 0.9, k)
	for i in 2:
		var sd := 1.0 if i == 0 else -1.0
		_hip[i].rotation.x = lerpf(_hip[i].rotation.x, 1.15, k)
		_hip[i].rotation.z = lerpf(_hip[i].rotation.z, 0.42 * sd, k)
		_knee[i].rotation.x = lerpf(_knee[i].rotation.x, -1.25, k)
		_foot[i].rotation.x = lerpf(_foot[i].rotation.x, 0.2, k)


func _pose_hang(k: float) -> void:
	var sh := hang_shimmy
	var walk := sin(_t * 9.0) * absf(sh)
	_pelvis.position.y = lerpf(_pelvis.position.y, H_PELVIS + 0.02, k)
	_pelvis.rotation.z += -sh * 0.12 * k
	_torso.rotation.x = lerpf(_torso.rotation.x, 0.08, k)
	_torso.rotation.y = lerpf(_torso.rotation.y, 0.0, k)
	_torso.rotation.z += walk * 0.05 * k
	_head.rotation.x = lerpf(_head.rotation.x, 0.3, k)
	_head.rotation.y = lerpf(_head.rotation.y, sh * 0.5, k)
	_sh[0].rotation = _sh[0].rotation.lerp(Vector3(2.9 + walk * 0.12, 0.0, -0.2 - maxf(-sh, 0.0) * 0.25), k)
	_sh[1].rotation = _sh[1].rotation.lerp(Vector3(2.9 - walk * 0.12, 0.0, 0.2 + maxf(sh, 0.0) * 0.25), k)
	_el[0].rotation.x = lerpf(_el[0].rotation.x, 0.25, k)
	_el[1].rotation.x = lerpf(_el[1].rotation.x, 0.25, k)
	_staff_off = _staff_off.lerp(Vector3(0.12, 0.0, -0.06), k)
	for i in 2:
		var sw := (walk if i == 0 else -walk) * 0.25
		_hip[i].rotation.x = lerpf(_hip[i].rotation.x, 0.28 + sw, k)
		_hip[i].rotation.z = lerpf(_hip[i].rotation.z, sh * 0.15, k)
		_knee[i].rotation.x = lerpf(_knee[i].rotation.x, -0.45 - absf(sw), k)
		_foot[i].rotation.x = lerpf(_foot[i].rotation.x, 0.35, k)


## Hands on the ledge, pull, a knee up onto the top, stand. u 0..1 (the Player moves the body).
func _pose_climb(u: float) -> void:
	var pull := 1.0 - smoothstep(0.0, 0.45, u)          # 1 at the hang, 0 once the chest is over
	var knee_up := smoothstep(0.3, 0.55, u) * (1.0 - smoothstep(0.75, 1.0, u))
	var press := smoothstep(0.25, 0.5, u) * (1.0 - smoothstep(0.7, 0.95, u))
	var k := 1.0 - smoothstep(0.85, 1.0, u)
	# arms: overhead -> elbows bent pulling -> pressing down beside the hips
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var ax := lerpf(0.4, 2.9, pull) - 0.9 * (1.0 - pull) * (1.0 - press) * 0.0
		_sh[i].rotation = _sh[i].rotation.lerp(Vector3(ax - 0.5 * press, 0.0, s * (0.2 + 0.25 * press)), k)
		_el[i].rotation.x = lerpf(_el[i].rotation.x, 0.25 + 1.3 * sin(pull * PI) * (1.0 - press) + 0.2 * press, k)
	_torso.rotation.x = lerpf(_torso.rotation.x, -0.15 - 0.55 * press - 0.2 * knee_up, k)
	_head.rotation.x = lerpf(_head.rotation.x, 0.3 * pull + 0.15 * press, k)
	_hip[1].rotation.x = lerpf(_hip[1].rotation.x, 0.3 + 1.6 * knee_up, k)
	_knee[1].rotation.x = lerpf(_knee[1].rotation.x, -0.5 - 1.7 * knee_up, k)
	_hip[0].rotation.x = lerpf(_hip[0].rotation.x, 0.2 - 0.25 * knee_up, k)
	_knee[0].rotation.x = lerpf(_knee[0].rotation.x, -0.4 - 0.4 * knee_up, k)
	_staff_off.x = lerpf(_staff_off.x, 0.12 + 0.5 * press, k)
	_staff_frame = Basis(Vector3.BACK, -PI * 0.5 * pull) * _staff_frame


## Speed vault: the free hand plants on the top, the legs swing through to the right, the staff
## held high and wide for balance.
func _pose_vault(u: float) -> void:
	var k := smoothstep(0.0, 0.2, u) * (1.0 - smoothstep(0.7, 1.0, u))
	var plant := smoothstep(0.05, 0.3, u) * (1.0 - smoothstep(0.55, 0.8, u))
	_pelvis.rotation.z += 0.45 * k * _mv_side
	_pelvis.position.y -= 0.05 * k
	_torso.rotation.x -= 0.35 * k
	_torso.rotation.z -= 0.25 * k * _mv_side
	_sh[0].rotation.x = lerpf(_sh[0].rotation.x, 0.75, plant)
	_sh[0].rotation.z = lerpf(_sh[0].rotation.z, 0.05, plant)
	_el[0].rotation.x = lerpf(_el[0].rotation.x, 0.1, plant)
	_sh[1].rotation.z += 0.6 * k
	_sh[1].rotation.x += 0.4 * k
	_staff_off.x += 0.35 * k
	for i in 2:
		_hip[i].rotation.x = lerpf(_hip[i].rotation.x, 1.25 - 0.3 * float(i), k)
		_hip[i].rotation.z += 0.35 * k * _mv_side
		_knee[i].rotation.x = lerpf(_knee[i].rotation.x, -1.5 + 0.4 * float(i), k)


## Kicking off a wall: the push leg straight back into it, the other tucked, arms thrown up.
func _pose_wallkick(u: float) -> void:
	var k := smoothstep(0.0, 0.1, u) * (1.0 - smoothstep(0.45, 1.0, u))
	_hip[0].rotation.x = lerpf(_hip[0].rotation.x, -0.7, k)
	_knee[0].rotation.x = lerpf(_knee[0].rotation.x, -0.15, k)
	_foot[0].rotation.x = lerpf(_foot[0].rotation.x, -0.5, k)
	_hip[1].rotation.x = lerpf(_hip[1].rotation.x, 1.15, k)
	_knee[1].rotation.x = lerpf(_knee[1].rotation.x, -1.6, k)
	_torso.rotation.x += 0.18 * k
	_head.rotation.x += 0.25 * k
	_sh[0].rotation.x += 1.4 * k
	_sh[0].rotation.z -= 0.55 * k
	_sh[1].rotation.z += 0.45 * k
	_staff_off.x += 0.4 * k


## Down a slope too steep to stand on: a low surfing crouch, the free hand trailing on the stone.
func _pose_steep(k: float) -> void:
	_pelvis.position.y = lerpf(_pelvis.position.y, 0.62, k)
	_torso.rotation.x = lerpf(_torso.rotation.x, 0.1, k)
	_torso.rotation.y += 0.35 * k
	_head.rotation.y -= 0.3 * k
	for i in 2:
		_hip[i].rotation.x = lerpf(_hip[i].rotation.x, 0.85 + 0.25 * float(i), k)
		_knee[i].rotation.x = lerpf(_knee[i].rotation.x, -1.25, k)
		_foot[i].rotation.x = lerpf(_foot[i].rotation.x, 0.3, k)
	_sh[0].rotation = _sh[0].rotation.lerp(Vector3(-0.5, 0.0, -0.95), k)
	_el[0].rotation.x = lerpf(_el[0].rotation.x, 0.15, k)
	_sh[1].rotation.z += 0.5 * k
	_staff_off.x += 0.3 * k


## Standing a while, the wanderer does something: looks about, lifts the lantern to peer into the
## dark, leans on the staff, glances back over a shoulder. Any movement or cast ends it at once.
func _idle_acts(speed: float, on_floor: bool, dt: float) -> void:
	var still := on_floor and speed < 0.2 and _cast_t < 0.0 and charge <= 0.0 and hang < 0.01 \
		and _mv_t < 0.0 and not lock and slide < 0.01 and _hit <= 0.0
	_still = _still + dt if still else 0.0
	if _ia < 0:
		if _still > _ia_next:
			_ia = _rng.randi_range(0, 3)
			if _ia == _ia_last:
				_ia = (_ia + 1) % 4
			_ia_last = _ia
			_ia_t = 0.0
			_ia_len = [3.8, 3.4, 4.4, 2.6][_ia]
		else:
			return
	_ia_t += dt
	var u := _ia_t / _ia_len
	var env := smoothstep(0.0, 0.2, u) * (1.0 - smoothstep(0.75, 1.0, u))
	_ia_k = minf(env, _ia_k + dt * 6.0) if still else move_toward(_ia_k, 0.0, dt * 5.0)
	if u >= 1.0 or (not still and _ia_k <= 0.0):
		_ia = -1
		_ia_k = 0.0
		_ia_next = _still + _rng.randf_range(5.0, 10.0)
		return
	var k := _ia_k
	match _ia:
		0:  # look about: left, then right
			var s := sin(u * TAU)
			_head.rotation.y += s * 0.7 * k
			_torso.rotation.y += s * 0.16 * k
			_head.rotation.x += 0.06 * k
		1:  # the lantern lifted to peer into the dark ahead
			_sh[0].rotation.x += 1.2 * k
			_sh[0].rotation.z += 0.3 * k
			_el[0].rotation.x += 0.35 * k
			_head.rotation.x -= 0.08 * k
			_head.rotation.y += 0.18 * k
			_torso.rotation.x -= 0.08 * k
			_torso.rotation.y += 0.1 * k
		2:  # weight onto the staff, a slow breath
			_staff_off.x -= 0.1 * k
			_sh[1].rotation.x += 0.28 * k
			_el[1].rotation.x += 0.25 * k
			_torso.rotation.z -= 0.07 * k
			_torso.rotation.x -= 0.07 * k
			_pelvis.position.x += 0.03 * k
			_head.rotation.x -= 0.14 * k * (0.7 + 0.3 * sin(_t * 1.2))
		3:  # a glance back over the right shoulder
			var b := smoothstep(0.08, 0.35, u) * (1.0 - smoothstep(0.62, 0.9, u))
			_head.rotation.y -= 1.0 * b * k
			_torso.rotation.y -= 0.32 * b * k
			_sh[0].rotation.x += 0.12 * b * k


## The hood's peak as a damped spring on the head's real acceleration: it flops back on a start,
## forward on a stop, sideways in a turn, lifts in a fall.
func _hood_tick(dt: float) -> void:
	if dt <= 0.0 or _head == null:
		return
	var hp := _head.global_position
	if _hood_pp == Vector3.INF:
		_hood_pp = hp
	var hv := (hp - _hood_pp) / dt
	var ha := (hv - _hood_pv) / dt
	_hood_pp = hp
	_hood_pv = hv
	if ha.length() > 90.0:
		ha = Vector3.ZERO
	var la := global_basis.orthonormalized().inverse() * ha
	var target := Vector2(clampf(la.z * 0.012 + la.y * 0.006, -0.35, 0.35), clampf(-la.x * 0.012, -0.3, 0.3))
	_hood_v += (target - _hood_s) * 110.0 * dt
	_hood_v *= exp(-6.5 * dt)
	_hood_s = (_hood_s + _hood_v * dt).clamp(Vector2(-0.4, -0.35), Vector2(0.4, 0.35))


## r31: the held staff-art poses (guard, a heavy drawn back, the glide) and the current strike's
## staff swing, layered after the traversal poses. All blends are fed by the Player.
func _combat_pose() -> void:
	if _strike_k > 0.001:
		_staff_frame = _staff_frame.slerp(_strike_frame, clampf(_strike_k, 0.0, 1.0))
	if guard > 0.001:
		# the staff held crosswise before the chest in both hands, the head tucked behind it
		var k := guard
		_sh[1].rotation.x += 1.15 * k
		_sh[1].rotation.z += 0.25 * k
		_el[1].rotation.x -= 0.9 * k
		_sh[0].rotation.x += 1.25 * k
		_sh[0].rotation.z -= 0.35 * k
		_el[0].rotation.x -= 1.0 * k
		_torso.rotation.x -= 0.08 * k
		_head.rotation.x -= 0.1 * k
		_pelvis.position.y -= 0.05 * k
		for i in 2:
			_knee[i].rotation.x -= 0.15 * k
		_staff_frame = _staff_frame.slerp(Basis(Vector3.BACK, -PI * 0.5) * Basis(Vector3.RIGHT, -0.15), k)
	if wind > 0.001:
		# a heavy strike drawn back: the staff high over the shoulder, weight on the back foot, trembling
		var k := smoothstep(0.0, 0.4, wind)
		var shake := sin(_t * 37.0) * 0.015 * wind
		_sh[1].rotation.x += 2.4 * k
		_sh[0].rotation.x += 2.1 * k
		_el[1].rotation.x -= 0.3 * k
		_el[0].rotation.x -= 0.5 * k
		_torso.rotation.x += 0.16 * k + shake
		_torso.rotation.y += 0.2 * k
		_pelvis.position.y -= 0.06 * k
		_hip[0].rotation.x -= 0.2 * k
		_knee[1].rotation.x -= 0.3 * k
		_staff_frame = _staff_frame.slerp(Basis(Vector3.RIGHT, 0.7), k)
	if glide > 0.001:
		# the cloak-glide: arms flung wide to spread the robe, the staff along the right arm, the body
		# pitched into the wind with the legs trailing
		var k := glide
		var flutter := sin(_t * 11.0) * 0.03
		_sh[0].rotation.z = lerpf(_sh[0].rotation.z, -1.35 + flutter, k)
		_sh[1].rotation.z = lerpf(_sh[1].rotation.z, 1.3 - flutter, k)
		_sh[0].rotation.x = lerpf(_sh[0].rotation.x, 0.35, k)
		_sh[1].rotation.x = lerpf(_sh[1].rotation.x, 0.35, k)
		_el[0].rotation.x = lerpf(_el[0].rotation.x, -0.15, k)
		_el[1].rotation.x = lerpf(_el[1].rotation.x, -0.15, k)
		_torso.rotation.x = lerpf(_torso.rotation.x, -0.45, k)
		_head.rotation.x = lerpf(_head.rotation.x, 0.35, k)
		for i in 2:
			_hip[i].rotation.x = lerpf(_hip[i].rotation.x, -0.35 + 0.08 * float(i), k)
			_knee[i].rotation.x = lerpf(_knee[i].rotation.x, -0.25, k)
		_staff_frame = _staff_frame.slerp(Basis(Vector3.BACK, -PI * 0.5) * Basis(Vector3.UP, -0.2), k)
