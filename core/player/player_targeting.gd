class_name PlayerTargeting
extends Node
## Lock-on, target cycling, the lock mark, and where the body faces.
## Part of Player (core/player/player.gd): Player owns this node and keeps its public surface;
## the state lives on Player unless declared here.

var player: Player

var _lock_lost := 0.0
var _lock_los_t := 0.0
var _lock_mark: MeshInstance3D
var _twist := 0.0


func _init(p: Player) -> void:
	player = p


## The closest living enemy within 14 m that isn't behind the wanderer (for the head's look-at).

func _nearest_foe() -> Enemy:
	var best: Enemy = null
	var bd := 14.0 * 14.0
	var fwd := -player._visual.global_basis.z
	for node in player.get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		var to := e.global_position - player.global_position
		var d := to.length_squared()
		if d < bd and Vector2(to.x, to.z).normalized().dot(Vector2(fwd.x, fwd.z).normalized()) > -0.3:
			bd = d
			best = e
	return best


## r33: the current (remembered) target, null if none.

func current_target() -> Node3D:
	var cs := player.combat()
	return cs.call("get_target") as Node3D if cs != null else null


## Screen-center hit (the HUD crosshair). Parallel-to-camera from the staff orb
## misses around the edges up close — OTS offset. Converge on this point instead.

func _look_target() -> Vector3:
	var center := player.get_viewport().get_visible_rect().get_center()
	var from := player._cam.project_ray_origin(center)
	var dir := player._cam.project_ray_normal(center)
	var far := from + dir * 96.0
	var space := player.get_world_3d().direct_space_state
	if space == null:
		return far
	var q := PhysicsRayQueryParameters3D.create(from, far)
	q.collision_mask = Layers.WORLD | Layers.PROPS | Layers.HURTBOX
	q.exclude = [player.get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return far
	return hit.position


func lock_target() -> Enemy:
	return player._lock if is_instance_valid(player._lock) else null


# --- target lock -------------------------------------------------------------------------------------

func _toggle_lock() -> void:
	if is_instance_valid(player._lock):
		_release_lock()
		return
	var t := _remembered_target()              # r33: the target you had is the one you lock back onto
	if t == null:
		t = _pick_target(0)
	if t:
		_set_lock(t)
	else:
		player._recentre = true                         # nothing to lock: swing the view behind the wanderer


func _set_lock(t: Enemy) -> void:
	player._lock = t
	var cs := player.combat()
	if cs != null:
		cs.call("set_target", t)               # r33: the lock is the target (remembered after it lets go)
	_lock_lost = 0.0
	player._visual.lock = true
	if _lock_mark == null:
		_lock_mark = _make_lock_mark()
	_lock_mark.visible = true
	Sfx.play("res://art/audio/mark_tick.wav", player.global_position + Vector3.UP, -12.0, 1.2, 0.02)


func _release_lock() -> void:
	player._lock = null
	player._visual.lock = false
	if _lock_mark:
		_lock_mark.visible = false


## A foe that burrowed or sank leaves Groups.ENEMY, loses its collision and hides: it cannot be held.
func _lockable(e: Enemy) -> bool:
	return e.is_in_group(Groups.ENEMY) and e.visible and e.collision_layer != 0


## r33: the remembered target when it is still a fair pick (alive, in range, in sight).

func _remembered_target() -> Enemy:
	var t := current_target() as Enemy
	if t == null or not is_instance_valid(t) or not t.is_alive() or not _lockable(t):
		return null
	if player.global_position.distance_to(t.global_position) > Player.LOCK_RANGE:
		return null
	if not player.locomotion._ray(player.global_position + Vector3.UP * 1.4, t.global_position + Vector3.UP * (t.hp_bar_y * 0.55)).is_empty():
		return null
	return t


## r33 combat, Tab-style: the next foe nearest-first in front of the view (wraps to the nearest); the
## camera locks onto it. Returns the new target or null.

func cycle_target() -> Enemy:
	var cam_xf := player._cam.global_transform
	var fwd := -cam_xf.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 0.0001 else Vector3.FORWARD
	var near: Array = []
	for node in player.get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		var to := e.global_position - player.global_position
		var d := to.length()
		if d > Player.LOCK_RANGE:
			continue
		var flat := Vector3(to.x, 0.0, to.z)
		if d > 2.5 and flat.length_squared() > 0.0001 and flat.normalized().dot(fwd) < 0.0:
			continue                           # behind you: Tab picks what you can see
		near.append([d, e])
	if near.is_empty():
		return null
	near.sort_custom(func(a, b): return a[0] < b[0])
	var cur := current_target()
	var start := 0
	for k in near.size():
		if near[k][1] == cur:
			start = k + 1
			break
	for n in near.size():
		var e: Enemy = near[(start + n) % near.size()][1]
		if e == cur and near.size() > 1:
			continue
		if player.locomotion._ray(player.global_position + Vector3.UP * 1.4, e.global_position + Vector3.UP * (e.hp_bar_y * 0.55)).is_empty():
			_set_lock(e)
			return e
	return null


## The foe nearest the middle of the view (side 0), or the next one left (-1) / right (+1) of the
## current target, in sight and within LOCK_RANGE.

func _pick_target(side: int) -> Enemy:
	var cam_xf := player._cam.global_transform
	var fwd := -cam_xf.basis.z
	var right := cam_xf.basis.x
	var cur_s := 0.0
	if side != 0 and is_instance_valid(player._lock):
		cur_s = (player._lock.global_position - cam_xf.origin).normalized().dot(right)
	var best: Enemy = null
	var best_score := INF
	for node in player.get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e == null or not e.is_alive() or e == player._lock:
			continue
		var chest := e.global_position + Vector3.UP * (e.hp_bar_y * 0.55)
		var to := chest - cam_xf.origin
		var d := to.length()
		if player.global_position.distance_to(e.global_position) > Player.LOCK_RANGE or d < 0.5:
			continue
		var dir := to / d
		var dot := dir.dot(fwd)
		var s := dir.dot(right)
		var score := 0.0
		if side == 0:
			if dot < 0.45:
				continue
			score = (1.0 - dot) * 12.0 + d * 0.04
		else:
			if dot < 0.0 or (s - cur_s) * float(side) <= 0.02:
				continue
			score = absf(s - cur_s) * 6.0 + d * 0.03
		if score >= best_score:
			continue
		if not player.locomotion._ray(player.global_position + Vector3.UP * 1.4, chest).is_empty():
			continue
		best_score = score
		best = e
	return best


## Physics tick: drop the lock when the target dies, goes far, or stays out of sight; a dead
## target hands the lock to the next one in view.

func _lock_tick(delta: float) -> void:
	player._regrab = maxf(0.0, player._regrab - delta)
	player._roll_cd = maxf(0.0, player._roll_cd - delta)
	player._kick_lock = maxf(0.0, player._kick_lock - delta)
	if player._lock == null:
		return
	if not is_instance_valid(player._lock) or not player._lock.is_alive() or not _lockable(player._lock):
		var nxt := _pick_target(0)
		if nxt:
			_set_lock(nxt)
		else:
			_release_lock()
		return
	if player.global_position.distance_to(player._lock.global_position) > Player.LOCK_RANGE + 6.0 or player._hollowing:
		_release_lock()
		return
	_lock_los_t -= delta
	if _lock_los_t <= 0.0:
		_lock_los_t = 0.2
		var seen := player.locomotion._ray(player.global_position + Vector3.UP * 1.4, player._lock.global_position + Vector3.UP * (player._lock.hp_bar_y * 0.55)).is_empty()
		_lock_lost = 0.0 if seen else _lock_lost + 0.2
		if _lock_lost > 1.4:
			_release_lock()


## Render frame: the view swings onto the target (framing the wanderer and the foe), the mark sits
## on it; a hard flick of the mouse or stick moves the lock to the next foe that side.

func _lock_view(delta: float, body: Vector3) -> void:
	player._lock_flick_t = maxf(0.0, player._lock_flick_t - delta)
	player._lock_flick = move_toward(player._lock_flick, 0.0, delta * 360.0)     # only a quick flick adds up
	if absf(player._lock_flick) > 90.0:
		var nxt := _pick_target(int(signf(player._lock_flick)))
		player._lock_flick = 0.0
		player._lock_flick_t = 0.0
		if nxt:
			_set_lock(nxt)
	var tp := player._lock.get_global_transform_interpolated().origin + Vector3.UP * (player._lock.hp_bar_y * 0.55)
	# aim from the camera's own pivot (over the right shoulder), not the body: the target then sits
	# on the crosshair, clear of the wanderer, instead of hiding behind the robe up close (r29)
	var pivot := body + Vector3.UP * 1.3 + Basis(Vector3.UP, player._yaw) * Vector3(player._arm.position.x, 0.0, 0.0)
	var aim := tp
	aim.y = minf(aim.y, player._lock.global_position.y + 3.0)    # a 9 m boss: the view keeps the floor and its red, not his chest
	if player._lock._ballistic:
		aim.y = minf(aim.y, body.y + player._lock.hp_bar_y * 0.55)   # a pounce in the air: the view keeps the ground it lands on
	var to := aim - pivot
	if Vector2(to.x, to.z).length() < 1.2:
		to = tp - (body + Vector3.UP * 1.3)     # right on top of it: the shoulder offset would spin the view
	var flat := Vector2(to.x, to.z).length()
	if flat > 0.4:
		var rate := 7.0 if flat > 3.0 else 4.0
		player._yaw = lerp_angle(player._yaw, atan2(-to.x, -to.z), 1.0 - exp(-rate * delta))
	# close in, the view tips down over the shoulder: the foe's wind-up and the red round your feet both in frame (level, the
	# foe stood behind the robe and its cone lay under the hotbar)
	var close := clampf(1.0 - (flat - 1.5) / 4.5, 0.0, 1.0)
	var want_pitch := clampf(atan2(to.y, maxf(flat, 1.0)) * 0.6 - 0.2 - 0.26 * close, player.pitch_min, 0.45)
	player._pitch = lerpf(player._pitch, want_pitch, 1.0 - exp(-4.0 * delta))
	if _lock_mark:
		_lock_mark.global_position = tp + Vector3.UP * 0.15


func _make_lock_mark() -> MeshInstance3D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5)
			var r := absf(d.x) + absf(d.y)                 # a diamond
			var a := clampf(1.0 - absf(r - 24.0) / 3.5, 0.0, 1.0) + clampf(1.0 - r / 4.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	m.fixed_size = true
	m.disable_fog = true
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.albedo_color = Color(1.4, 0.75, 2.6, 0.9)
	var q := QuadMesh.new()
	q.size = Vector2(0.045, 0.045)
	var mi := MeshInstance3D.new()
	mi.name = "LockMark"
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # placed every rendered frame on the drawn target
	mi.visible = false
	player.add_child(mi)
	return mi


## Where the upper body should look: the lock target, else the camera's aim. Facing and twist:
## locked on (walking) or standing in a fight, the body squares up to the aim and steps round;
## running while casting, the legs keep to the run and the chest turns toward the aim (up to
## ~65 degrees, beyond which the body turns and back-pedals).

func _facing(delta: float, horiz: Vector3, sprint_held: bool) -> void:
	var locked := is_instance_valid(player._lock)
	var aim_yaw := player._yaw
	if locked:
		var to := player._lock.global_position - player.global_position
		aim_yaw = atan2(-to.x, -to.z)
	var spd := horiz.length()
	var want_twist := 0.0
	if player._sliding or player._roll_t >= 0.0 or player._hang or player._climb_t >= 0.0 or player._vault_t >= 0.0:
		_twist = lerpf(_twist, 0.0, 1.0 - exp(-10.0 * delta))
		player._visual.twist = _twist
		return
	if player._arts != null and player._arts.phase() >= 0:
		player._visual.rotation.y = lerp_angle(player._visual.rotation.y, player._face_yaw, 1.0 - exp(-16.0 * delta))   # strike face: firm, not a snap
		_twist = lerpf(_twist, 0.0, 1.0 - exp(-10.0 * delta))
		player._visual.twist = _twist
		return
	if locked or player._combat_t > 0.0:
		var move_yaw := atan2(-horiz.x, -horiz.z)
		var free_run := spd > 2.2 and (not locked or (sprint_held and spd > player.walk_speed * 1.05))
		var diff := angle_difference(move_yaw, aim_yaw)
		if free_run and absf(diff) < 1.9:
			player._visual.rotation.y = lerp_angle(player._visual.rotation.y, move_yaw, 1.0 - exp(-lerpf(15.0, 9.0, player._run_blend) * delta))
			want_twist = clampf(angle_difference(player._visual.rotation.y, aim_yaw), -1.15, 1.15)
		else:
			player._visual.rotation.y = lerp_angle(player._visual.rotation.y, aim_yaw, 1.0 - exp(-14.0 * delta))
	elif spd > 0.2:
		var rate := lerpf(15.0, 9.0, player._run_blend)
		player._visual.rotation.y = lerp_angle(player._visual.rotation.y, atan2(-horiz.x, -horiz.z), 1.0 - exp(-rate * delta))
	_twist = lerpf(_twist, want_twist, 1.0 - exp(-10.0 * delta))
	player._visual.twist = _twist
