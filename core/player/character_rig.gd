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


func _ready() -> void:
	if _pelvis == null:
		_build()
	set_process(not driven)
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
	if rim_light:
		_add_rim_light()


## Soft violet key from in front/above so the near-black robe keeps a readable silhouette
## and fold detail against the night. No shadows: cheap, and it only needs to lift edges.
func _add_rim_light() -> void:
	var l := OmniLight3D.new()
	l.name = "RimLight"
	l.light_color = Color(0.62, 0.5, 1.0)
	l.light_energy = 1.1
	l.omni_range = 4.5
	l.omni_attenuation = 1.4
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
	for entry in DefaultLoadout.entries():
		equip(entry.socket, entry.piece, entry.key)

	_staff = _equipped.get("weapon_main")
	if _staff:
		_orb = _staff.get_node_or_null("Head/Orb")
		if _orb:
			_orb_light = _orb.get_node_or_null("OrbLight")
			_trail = _orb.get_node_or_null("Trail")
			_burst = _orb.get_node_or_null("Burst")

	_lantern = _equipped.get("lantern")
	if _lantern:
		_lantern_light = _lantern.get_node_or_null("LanternLight")
	# Coat mesh Y is [-1.16, 0.30] under chest — weight must use that local range, not world Y.
	var coat_root: Node = _equipped.get("coat")
	if coat_root:
		_coat_mi = coat_root.find_child("Torso", true, false) as MeshInstance3D
		if _coat_mi == null:
			for node in coat_root.find_children("*", "MeshInstance3D", true, false):
				_coat_mi = node as MeshInstance3D
				break
	_dress_cloth(coat_root, 0.28, 1.42, 1.0, 1.0, 0.0)
	_dress_cloth(_equipped.get("hood"), 0.26, 0.38, 0.0, 0.35, 0.0)
	_dress_cloth(_equipped.get("sleeve_l"), 0.05, 0.36, 0.0, 0.25, 0.0)
	_dress_cloth(_equipped.get("sleeve_r"), 0.05, 0.36, 0.0, 0.25, 0.0)
	_build_face()


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
	_stride = lerpf(_stride, target_stride, 1.0 - exp(-8.0 * delta))
	var step_len := STEP_LEN * (1.0 + clampf((speed - walk_speed) / (sprint_speed - walk_speed), 0.0, 1.0) * 0.55)
	if on_floor:
		_phase += speed * delta / step_len * PI
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

	_legacy_pose(s, c, st, breathe, idle)
	_tuck = move_toward(_tuck, 0.0, delta * 2.2)
	if slide > 0.01 or _tuck > 0.01:
		_pose_overlay()

	var body := global_basis.orthonormalized()
	if _staff and _orb and _orb_light:
		var tilt := -0.12 - s * 0.12 * st - _gesture * 0.75
		_staff.global_basis = body * Basis.from_euler(Vector3(tilt, 0.0, 0.06 + _turn * 0.03))
		_hand[1].rotation.z = 0.35
		_orb.position.y = 0.17 + sin(_t * 2.2) * 0.015
		_orb.rotation.y += delta * 1.5
		_orb_light.light_energy = 1.3 + sin(_t * 3.1) * 0.15 + _gesture * 3.5 + charge * (4.0 + sin(_t * 31.0) * 0.6)
		_orb.scale = Vector3.ONE * (1.0 + charge * 0.7)
		if _trail:
			var run := clampf((speed - walk_speed * 0.85) / maxf(sprint_speed - walk_speed, 0.2), 0.0, 1.0)
			_trail.amount_ratio = lerpf(1.0, 0.16, run)
			_trail.lifetime = lerpf(1.15, 0.38, run)
	if _lantern_light:
		_lantern_light.light_energy = 1.85 + sin(_t * 13.0) * 0.07 + sin(_t * 7.3) * 0.05

	# Body lag is for lantern/hood lean only — NEVER feed walk velocity into cloth_lag
	# (that slid the whole coat behind the body while walking).
	var local_vel := body.inverse() * vel
	var accel := (vel - _prev_vel) / delta
	_prev_vel = vel
	var local_acc := body.inverse() * accel
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
	var cloth_changed := (
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
	_hood_peak.rotation.x = 0.4 + clampf(-_lag.z * 1.5, -0.3, 0.45) + _air * 0.15
	_hood_peak.rotation.z = clampf(_lag.x * 1.5, -0.3, 0.3)


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
	_pelvis.position.y = lerpf(_pelvis.position.y, 0.5, k)
	_torso.rotation.x = lerpf(_torso.rotation.x, 0.42, k) - _tuck * 0.3
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
		mat.set_shader_parameter("rim_color", Vector3(0.28, 0.42, 0.85))
		mat.set_shader_parameter("roughness_amt", 0.82)
		mat.set_shader_parameter("glow_energy", 1.45)
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
	qmat.albedo_color = Color(1, 1, 1, 1)
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


## Raise the staff and release a burst of violet motes (kindling and spellcasting).
func cast() -> void:
	_gesture_t = 0.0
	if _burst:
		_burst.restart()
		_burst.emitting = true
	play_cast_sound()


func play_cast_sound() -> void:
	if _cast_sfx:
		_cast_sfx.play()


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


## Every stride gets a step (the old guard skipped any step that landed while the previous
## sample was still ringing, so sprinting dropped beats). Louder at a run than a walk.
func _footstep(speed := 0.0) -> void:
	if _steps == null:
		return
	var run := clampf((speed - 1.0) / maxf(sprint_speed - 1.0, 0.1), 0.0, 1.0)
	_steps.volume_db = lerpf(-11.0, -4.0, run)
	_steps.pitch_scale = lerpf(0.97, 1.04, run)
	_steps.play()


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


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or driven:
		return
	# Idle-only fallback when no player drives the rig (e.g. a preview scene).
	if get_parent() == null or not get_parent().has_method("hollow"):
		animate(Vector3.ZERO, true, delta)
