class_name PlayerCasting
extends Node
## Bolts and aim assist, charge effects, the aim ring, nova effects and the animation hand-off.
## Part of Player (core/player/player.gd): Player owns this node and keeps its public surface;
## the state lives on Player unless declared here.

var player: Player

const BOLT := preload("res://core/player/magic_bolt.tscn")
const StaffSfx := preload("res://core/vfx/staff_sfx.gd")

var _charge_was_full := false
var _over_pulsed := false               ## the overcharge peak has rung once
const OVER_PEAK := 0.15                 ## seconds past full when the auto-fire peak shows
var _charge_c := 0.0                    ## the SkillBook's charge (physics tick); drawn per frame


func _init(p: Player) -> void:
	player = p


# --- Animation ---------------------------------------------------------------

func _animate(delta: float, horiz: Vector3) -> void:
	# casting / locked on: square up or twist the chest toward the aim; otherwise face the run
	# (quick to turn from a walk, a wider sweep at a sprint; the body leans into it, see the rig)
	if player._roll_t < 0.0 and player._vault_t < 0.0 and not player._hang and player._climb_t < 0.0:
		player.targeting._facing(delta, horiz if player._steep_k < 0.5 else Vector3(player._steep_n.x, 0.0, player._steep_n.z), player._sprint_held)
	if player._crawl:
		player._slide_blend = move_toward(player._slide_blend, 1.0, delta * 6.0)    # crawling out from under: the low pose
	elif not player._sliding:
		player._slide_blend = move_toward(player._slide_blend, 0.0, delta * 6.0)
	player._visual.slide = player._slide_blend
	if player._sliding:
		player._visual.rotation.y = lerp_angle(player._visual.rotation.y, atan2(-player._slide_dir.x, -player._slide_dir.z), 1.0 - exp(-12.0 * delta))
	player._look_t -= delta
	if player._look_t <= 0.0:
		player._look_t = 0.2
		player._look_foe = player.targeting._nearest_foe()
	if is_instance_valid(player._lock):
		player._visual.look_at_point = player._lock.global_position + Vector3.UP * (player._lock.hp_bar_y * 0.6)
	elif player._look_foe and is_instance_valid(player._look_foe) and player._look_foe.is_alive():
		player._visual.look_at_point = player._look_foe.global_position + Vector3.UP * (player._look_foe.hp_bar_y * 0.6)
	elif player._cam:
		player._visual.look_at_point = player._cam.global_position - player._cam.global_basis.z * 30.0
	player._visual.animate(player.velocity, player._grounded, delta)
	player._last_pos = player.global_position


func _on_skill_cast(id: StringName) -> void:
	player._visual.cast_pose(id)


## Spawn one staff bolt toward the crosshair. cfg keys (all optional): heavy, dmg, blast, speed,
## marks (Umbral Marks per hit), pierce. Skills call this; it owns aim, pooling and the gesture.

func fire_bolt(cfg: Dictionary) -> MagicBolt:
	if player._hollowing or player._visual == null:
		return null
	var host := player.get_tree().current_scene
	if host == null:
		return null
	# the staff's own voice: a lash for the empowered 3rd bolt; the Lance plays its throw below;
	# cfg.sound overrides (a staff core's own cast sound)
	var lash_voice := bool(cfg.get("empower", false)) and not bool(cfg.get("heavy", false)) and not cfg.has("sound")
	var voice := "" if bool(cfg.get("heavy", false)) or lash_voice else "bolt"
	player._visual.cast(String(cfg.get("sound", voice)))
	if lash_voice:
		StaffSfx.play("lash", player._visual.muzzle(), -1.0)      # the third bolt is its own attack before it lands
	var pool := player.get_tree().get_first_node_in_group("bolt_pool") as BoltPool
	var bolt: MagicBolt
	if pool:
		bolt = pool.take()
		if bolt == null:
			return null                               # the pool is at its live cap
	else:
		bolt = BOLT.instantiate() as MagicBolt
		host.add_child(bolt)
	var muzzle := player._visual.muzzle()
	var aim := _combat_aim(muzzle)
	if cfg.has("dir"):
		aim = (cfg.dir as Vector3).normalized()      # r36: a fanned throw (the Slag Heart's Scatter)
	var up := Vector3.UP
	if absf(aim.dot(up)) > 0.95:
		up = Vector3.RIGHT
	bolt.transform = Transform3D(Basis.looking_at(aim, up), muzzle + aim * 0.28)
	bolt.direction = aim
	bolt.arm_with(cfg)
	bolt.add_collision_exception_with(player)
	var heavy := bool(cfg.get("heavy", false))
	# r33 combat: a Lance spends Resonance (SkillBook.cast_power) and scars; a Rift Bolt builds it
	if heavy:
		bolt.hit_dmg *= player._book.cast_power
		bolt.scar = 2 if player._book.cast_spent >= 3 else 1
	else:
		bolt.resonant = 2 if bool(cfg.get("empower", false)) else 1
	var col := Player.EMBER if heavy else Player.VIOLET
	Vfx.burst(muzzle + aim * 0.2, col, {"count": 16 if heavy else 8, "life": 0.22, "speed": Vector2(1.5, 4.0), "size": 0.05, "dir": aim, "spread": 35.0, "gravity": 0.0, "trail": 0.05})
	Vfx.light(muzzle, Color(col.r, col.g, col.b) * 0.5, 2.5 if heavy else 1.6, 4.5, 0.12)
	# the orb flashes as the shot leaves it: a quick bright pulse and a ring along the aim
	SpellFx.shell(muzzle, 0.05, 0.4, Color(col.r, col.g, col.b) * (0.45 if heavy else 0.8), 0.1)
	Vfx.ring(muzzle + aim * 0.25, 0.55 if heavy else 0.32, col, 0.16, 0.08, aim)
	if heavy:
		StaffSfx.play("lance_fire", muzzle, -1.0)
		StaffSfx.play("swish", muzzle, -6.0)
	return bolt


## Soft aim assist: if an enemy's chest is within ~6 degrees of the aim and in clear sight, aim
## at it. Narrow on purpose -- it fixes near misses, it does not pick targets for you.

func _assist(muzzle: Vector3, aim: Vector3) -> Vector3:
	var best := aim
	var best_dot := -1.0
	var space := player.get_world_3d().direct_space_state
	for node in player.get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		var chest := e.global_position + Vector3.UP * (e.hp_bar_y * 0.55)
		var to := chest - muzzle
		var d := to.length()
		if d < 0.3 or d > Player.ASSIST_RANGE:
			continue
		var dir := to / d
		# r31: up close the over-the-shoulder crosshair and the staff disagree by tens of degrees, so
		# the cone widens with nearness (~35 deg at 1 m) and narrows back to ~6 deg by 9 m. The pick is
		# by margin inside each foe's own cone, so a near foe off-centre does not steal from a far one
		# dead on the crosshair.
		var cone := lerpf(Player.CLOSE_ASSIST_COS, Player.ASSIST_COS, clampf((d - 1.0) / 8.0, 0.0, 1.0))
		var dt := dir.dot(aim)
		var flat_aim := Vector2(aim.x, aim.z).normalized()
		if d < 4.0:
			dt = maxf(dt, Vector2(dir.x, dir.z).normalized().dot(flat_aim))   # a squat foe under the crosshair
		if dt - cone <= best_dot or dt < cone:
			continue
		var q := PhysicsRayQueryParameters3D.create(muzzle, chest, Layers.WORLD, [player.get_rid()])
		if space and not space.intersect_ray(q).is_empty():
			continue
		best_dot = dt - cone
		best = dir
	return best


## r31: where a bolt goes. Locked on, straight at the target's chest (in sight); otherwise the
## crosshair, nudged by the assist.

func _combat_aim(muzzle: Vector3) -> Vector3:
	var lk := player.targeting.lock_target()
	if lk and lk.is_alive():
		var chest := lk.global_position + Vector3.UP * (lk.hp_bar_y * 0.55)
		var to := chest - muzzle
		if to.length() > 0.2 and to.length() < Player.LOCK_AIM_RANGE and player.locomotion._ray(muzzle, chest).is_empty():
			return to.normalized()
	return _assist(muzzle, _aim_from(muzzle))


func _aim_from(muzzle: Vector3) -> Vector3:
	var look := player.targeting._look_target()
	var cam_fwd := -player._cam.global_transform.basis.z.normalized()
	var aim := look - muzzle
	if aim.length_squared() < 0.04 or aim.normalized().dot(cam_fwd) < 0.12:
		return cam_fwd
	return aim.normalized()


## Called by the SkillBook on its physics tick. The ember orb, its light, the particles and the
## Lance's landing ring are PLACED every rendered frame (_frame_fx) at the staff head as it is drawn:
## placed here they stepped at 60 Hz against the interpolated staff (r29).

func set_charge_glow(c: float) -> void:
	if player._visual:
		player._visual.charge = c
	_charge_c = c
	if c <= 0.0 and player._aim_ring:
		player._aim_ring.visible = false
	if player._charge_fx == null:
		return
	var on := c > 0.0
	if on != player._charge_fx.emitting:
		if on:
			player._charge_fx.global_position = _muzzle_drawn()
		player._charge_fx.emitting = on
		if on:
			player._charge_sfx.play()
		else:
			player._charge_sfx.stop()
			_charge_was_full = false
			_over_pulsed = false
	if not on:
		_charge_vis(0.0)
	if on:
		player._charge_fx.amount_ratio = 0.35 + 0.65 * c
		player._charge_sfx.pitch_scale = 0.8 + 0.5 * c
		if c >= 1.0 and not _charge_was_full:
			_charge_was_full = true      # full charge: a ring snap tells you it will pierce
			Vfx.ring(player._visual.muzzle(), 0.7, Color(2.6, 1.8, 1.0), 0.25, 0.14, -player._cam.global_basis.z)
			Vfx.burst(player._visual.muzzle(), Color(2.8, 1.6, 0.8), {"count": 18, "life": 0.3, "speed": Vector2(2.0, 4.0), "size": 0.04, "trail": 0.06, "gravity": 0.0})
		elif c >= 1.0 and not _over_pulsed and player._book != null and player._book.overcharge() >= OVER_PEAK:
			_over_pulsed = true          # a held lance is about to throw itself: one more ring, the peak
			Vfx.ring(player._visual.muzzle(), 0.9, Color(3.4, 2.6, 1.6), 0.22, 0.12, -player._cam.global_basis.z)


## Rendered frame: everything that rides the staff head while charging.

func _frame_fx() -> void:
	if _charge_c <= 0.0 or player._visual == null:
		return
	var at := _muzzle_drawn()
	if player._charge_fx:
		player._charge_fx.global_position = at
	_charge_vis(_charge_c, at)
	_update_aim_ring(_charge_c, at)


## Where the staff orb is DRAWN this frame (the rig's bones are blended between ticks).

func _muzzle_drawn() -> Vector3:
	if player._visual.has_method("muzzle_drawn"):
		return player._visual.muzzle_drawn()
	return player._visual.muzzle()


## The ember orb at the staff head: swells with the charge, flickers, and burns white at full.

func _charge_vis(c: float, at := Vector3.INF) -> void:
	if player._charge_orb == null:
		return
	var on := c > 0.0
	player._charge_orb.visible = on
	player._charge_halo.visible = on
	player._charge_light.visible = on
	if not on:
		return
	if at == Vector3.INF:
		at = _muzzle_drawn()
	var t := Time.get_ticks_msec() * 0.001
	var flick := 1.0 + 0.08 * sin(t * 37.0) + 0.05 * sin(t * 23.0 + 1.3)
	var full := c >= 1.0
	var r := lerpf(0.05, 0.2, smoothstep(0.0, 1.0, c)) * flick * (1.15 if full else 1.0)
	player._charge_orb.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * r * 2.0), at)
	player._charge_halo.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * r * 4.2), at)
	(player._charge_orb.material_override as StandardMaterial3D).albedo_color = Color(3.2, 1.3, 0.45).lerp(Color(4.2, 3.4, 2.4), 0.6 if full else 0.0)
	(player._charge_halo.material_override as StandardMaterial3D).albedo_color.a = 0.22 + 0.25 * c
	player._charge_light.global_position = at
	var peak := full and _over_pulsed
	player._charge_light.light_energy = (3.4 if peak else 0.6 + 2.2 * c) * flick
	player._charge_light.omni_range = 2.5 + 2.5 * c


## Lance aim: a round marker where the throw will land, sized to the blast it will have now.

func _update_aim_ring(c: float, muzzle: Vector3) -> void:
	if player._aim_ring == null:
		return
	if c <= 0.0:
		player._aim_ring.visible = false
		return
	var space := player.get_world_3d().direct_space_state
	if space == null:
		return
	var aim := _aim_from(muzzle)
	var q := PhysicsRayQueryParameters3D.create(muzzle, muzzle + aim * (lerpf(18.0, 30.0, c) * MagicBolt.LIFE), Layers.WORLD | Layers.PROPS, [player.get_rid()])
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		player._aim_ring.visible = false
		return
	player._aim_ring.visible = true
	# the circle is the blast the charging skill will really have (Wide Ember, the Cinder Censer...)
	var blast := lerpf(SkillLance.BLAST_MIN, SkillLance.BLAST_MAX, c)
	var si := player._book.charging_slot() if player._book else -1
	if si >= 0 and si < player._book.slots.size() and player._book.slots[si] != null and player._book.slots[si].has_method("blast_at"):
		blast = float(player._book.slots[si].call("blast_at", c))
	SpellFx.place_ring(player._aim_ring, hit.position, hit.normal, blast, c)


func nova_fx(radius: float, detonated: Array) -> void:
	player._visual.cast("")
	StaffSfx.play("nova", player.global_position, 0.0)
	var at := player.global_position + Vector3.UP * 0.9
	SpellFx.nova(player.global_position, radius)     # round disc drawn at exactly the damage radius
	for e in detonated:
		var en := e as Node3D
		if en == null or not is_instance_valid(en):
			continue
		var hit := en.global_position + Vector3.UP * 1.0
		Vfx.arc(at, hit, Color(1.8, 1.0, 3.2), 0.28, 0.35)
		Vfx.burst(hit, Color(2.0, 1.1, 3.4), {"count": 26, "life": 0.4, "speed": Vector2(2.5, 6.0), "size": 0.05, "trail": 0.08, "gravity": -4.0})
