class_name PlayerVitals
extends Node
## Gloom, Wounds, the Shade, hollowing, the ash mound, falls, lava and stuck recovery.
## Part of Player (core/player/player.gd): Player owns this node and keeps its public surface;
## the state lives on Player unless declared here.

var player: Player

const ASH_MOUND := preload("res://core/player/ash_mound.gd")
const Hints := preload("res://ui/hints.gd")
const StaffSfx := preload("res://core/vfx/staff_sfx.gd")
const Stamina := preload("res://core/player/stamina.gd")

var _gloom_zone_t := 0.0
var _in_rift := false
var _in_fight := false
var _ash_mound: Node3D
var _shade_warned := false
var _gloom_emit := 0.0
var _gloom_emit_t := 0.0
var _wounds_emit := 0.0
var _wounds_emit_t := 0.0
var _stuck_from := Vector3.INF


func _init(p: Player) -> void:
	player = p


## Lava: a heavy Gloom burn and a throw back to the last solid ground (see Lava).

func lava_burn(amount: float) -> void:
	if player._burn_cd > 0.0 or player._hollowing:
		return
	player._burn_cd = 1.0
	var from := player.global_position
	add_wounds(amount)                        # r35: lava wounds (it filled the Gloom before the split)
	Events.player_hurt.emit(amount, from)
	player.traversal._end_traverse()
	Vfx.burst(from + Vector3.UP * 0.6, SpellFx.EMBER_HOT, {"count": 50, "life": 0.7, "speed": Vector2(3.0, 8.0), "size": 0.05, "gravity": -8.0, "trail": 0.08, "dir": Vector3.UP, "spread": 50.0})
	player.locomotion._end_slide()
	var to := player._safe_ground if player._safe_ground != Vector3.INF else player.checkpoint
	player.locomotion.teleport(to + Vector3.UP * 0.1)
	SpellFx.rift_in(to)
	player.camera_ctl.kick(0.8)
	Events.toast.emit("The molten dark spits you back out.")


## A strike or pounce passed through you during a Rift Step: slow time, stagger and mark the
## attacker, and arm a free Rift Lash on your next bolt.

func on_evaded(attacker: Node) -> void:
	var now := Time.get_ticks_msec() * 0.001
	var at := player.global_position + Vector3.UP * 2.0
	if player._arts != null and player._arts.parrying() and player._evade_t <= 0.0:
		player._arts.parry(attacker)                   # r31: the staff turned it aside
		_surge(&"parry")
		return
	if player._evade_roll and player._dodge_roll and player._roll_t >= 0.0 and player._roll_t <= Player.PERFECT_T and now >= player._riposte_cd:
		_perfect_dodge(attacker)                # r31: rolled the instant it landed
		_surge(&"dodge")
		return
	if player._evade_roll:
		HitText.pop(at, "evaded", Color(0.6, 0.75, 1.0))    # a plain roll: through it, no riposte
		return
	if now < player._riposte_cd:
		HitText.pop(at, "evaded", Color(0.6, 0.75, 1.0))
		return
	player._riposte_cd = now + 1.5
	player._riposte_ready = true
	_surge(&"riposte")
	HitText.pop(at, "RIPOSTE", Color(1.3, 0.75, 2.6), true)
	Hints.once(&"riposte", "RIPOSTE: stepping through a blow makes your next bolt a Rift Lash.")
	if attacker.has_method("add_mark"):
		attacker.add_mark(2)
	if attacker.has_method("riposted"):
		attacker.riposted()
	Sfx.play("res://art/audio/mark_tick.wav", at, 0.0, 0.7, 0.02)
	SpellFx.shell(player.global_position + Vector3.UP, 0.3, 2.2, Color(1.2, 0.5, 2.8), 0.3)
	player.camera_ctl.kick(0.5)
	TimeSlow.request(player.get_tree(), 0.35, 0.22)


## r33: a parry, a perfect dodge or a riposte lights Rift Surge (CombatState).

func _surge(reason: StringName) -> void:
	var cs := player.combat()
	if cs != null:
		cs.call("proc_surge", reason)


func consume_riposte() -> bool:
	var r := player._riposte_ready
	player._riposte_ready = false
	return r


func _on_enemy_killed(e: Node) -> void:
	if player._hollowing or not (e is Node3D) or not player.is_inside_tree():
		return
	var at := (e as Node3D).global_position + Vector3.UP * 1.0
	if at.distance_to(player.global_position) > 28.0:
		return
	var now := Time.get_ticks_msec() * 0.001
	player._chain = player._chain + 1 if now < player._chain_until else 1
	player._chain_until = now + Player.CHAIN_WINDOW
	mend(minf(Player.KILL_RELIEF + 2.0 * float(player._chain - 1), 14.0))   # r35: a kill mends Wounds
	if player._chain >= 2:
		HitText.pop(player.global_position + Vector3.UP * 2.3, "chain x%d" % player._chain, Color(1.2, 0.6, 2.6), player._chain >= 4)
	Vfx.arc(at, player.global_position + Vector3.UP * 1.2, Color(1.2, 0.55, 2.8), 0.35, 0.18)
	Vfx.burst(player.global_position + Vector3.UP * 1.1, Color(1.3, 0.6, 3.0), {"count": 12, "life": 0.4, "speed": Vector2(0.5, 1.5), "size": 0.04, "gravity": -1.0, "radius": 0.3})


# --- Gloom and the shade -----------------------------------------------------

func _update_gloom(delta: float) -> void:
	if player._hollowing:
		return
	_gloom_zone_t -= delta
	if _gloom_zone_t <= 0.0:
		_gloom_zone_t = 0.25
		_in_fight = player.boss_fight_active(player.get_tree())
		_in_rift = _rift_here()
	# r30: a fire drains at the player's rate; a Lantern Ward at its own (4/s, at most 25 a cast);
	# inside a live boss arena the dark does not gather on its own (the boss is the pressure);
	# the rift rate is the Ashen Rift itself, not everything north of z -40.
	var drain := LightGrid.drain_at(player.global_position)
	var lit := drain != 0.0
	var rate := player.gloom_rate_rift if _in_rift else player.gloom_rate_dark
	if drain < 0.0:
		rate = -player.gloom_drain_lit
	elif drain > 0.0:
		var want := drain * player.gloom_drain_lit / 12.0
		rate = -want if player.ward_drain_left > 0.0 and player.gloom > 0.0 else 0.0
		player.ward_drain_left = maxf(0.0, player.ward_drain_left + rate * delta)
	elif _in_fight:
		rate = 0.0
	elif player._sprint_held and player._run_blend > 0.6 and player._grounded:
		rate *= Player.SPRINT_DARK_MULT
	var prev := player.gloom
	player.gloom = clampf(player.gloom + rate * delta, 0.0, player.gloom_max)
	if not is_equal_approx(prev, player.gloom):
		_gloom_emit_t += delta
		if absf(player.gloom - _gloom_emit) >= 0.5 or _gloom_emit_t >= 0.1:
			Events.gloom_changed.emit(player.gloom, player.gloom_max)
			_gloom_emit = player.gloom
			_gloom_emit_t = 0.0
	else:
		_gloom_emit_t = 0.0
	if player.gloom >= player.gloom_max and not is_instance_valid(player._shade) and player._shade_lock <= 0.0:
		_spawn_shade()
	if lit and is_instance_valid(player._shade):
		player._shade.unmake_by_light()
	# r35: a fire mends Wounds (a Lantern Ward does not: it only holds the dark back)
	if drain < 0.0 and player.wounds > 0.0:
		var before := player.wounds
		player.wounds = maxf(0.0, player.wounds - player.wounds_mend_lit * delta)
		_wounds_emit_t += delta
		if player.wounds <= 0.0 or before - _wounds_emit >= 0.5 or _wounds_emit_t >= 0.1:
			_emit_wounds()


func add_gloom(amount: float) -> void:
	player.gloom = clampf(player.gloom + amount, 0.0, player.gloom_max)
	Events.gloom_changed.emit(player.gloom, player.gloom_max)


func _emit_wounds() -> void:
	_wounds_emit = player.wounds
	_wounds_emit_t = 0.0
	Events.wounds_changed.emit(player.wounds, player.wounds_max)


## Raw Wounds (positive hurts, negative mends) with no hit reaction. At wounds_max you are hollowed.
## Blows from the world go through take_wound (grace window, guard, the reaction); this is for
## mending and for scripted hurts that do their own show (lava, a long fall, a crypt push-back).

func add_wounds(amount: float) -> void:
	if player._hollowing:
		return
	player.wounds = clampf(player.wounds + amount, 0.0, player.wounds_max)
	_emit_wounds()
	if player.wounds >= player.wounds_max - 0.01:
		hollow()


## Kills, spent Resonance, Nova motes and the like: a little of the hurt closes.

func mend(amount: float) -> void:
	if amount > 0.0 and player.wounds > 0.0:
		add_wounds(-amount)


## The Ashen Rift proper: the chasm region and its crossing, not the Ossuary under the fen or the
## summit platform (both used to take the rift rate because they lie north of z -40).

func _rift_here() -> bool:
	if not player.rift_enabled or player.global_position.z >= player.rift_z + 28.0:
		return false
	var p := player.global_position
	if RealmLayout.OSSUARY.has_point(p):
		return false
	if Vector2(p.x - RealmLayout.SUMMIT.x, p.z - RealmLayout.SUMMIT.z).length() < 26.0:
		return false
	return String(RealmLayout.region_at(p.x, p.z).get("id", "")) == "rift"


func _spawn_shade() -> void:
	var s := Shade.new()
	var host := player.get_tree().current_scene
	if host == null:
		return
	host.add_child(s)
	var behind := Basis(Vector3.UP, player._yaw) * Vector3(0.0, 0.0, 1.0)
	s.target = player
	s.global_position = player.global_position + behind * 16.0 + Vector3.UP * Shade.HOVER
	player._shade = s
	s.tree_exiting.connect(_on_shade_leaving)
	Events.shade_spawned.emit()
	if not _shade_warned:
		_shade_warned = true
		Events.toast.emit("The dark has taken shape. Find light.")


func note_shade_unmade() -> void:
	player._shade_lock = 2.0


## A bolt or spell passed through the Shade. The first time, say what does work.

func note_shade_passed() -> void:
	Hints.once(&"shade_drive", "Bolts pass through the Shade. Run for a fire or a lantern: only light unmakes it.")


## r35: a blow from the world (a foe, a boss, their hazards). It wounds; it no longer fills the Gloom.
## Two strikes inside HURT_GRACE count once; a held guard turns most of a blow from the front.

func take_wound(amount: float, from_pos := Vector3.INF) -> void:
	if player._hollowing:
		return
	if Time.get_ticks_msec() * 0.001 < player._hurt_grace_until:
		return                                   # two strikes landing together count once
	player._hurt_grace_until = Time.get_ticks_msec() * 0.001 + Player.HURT_GRACE
	if player._arts != null:
		amount = player._arts.absorb(amount, from_pos)   # r31: a held guard turns most of a blow from the front
	if player._book != null:
		player._book.on_hurt(amount)                    # r33: a hard blow interrupts a cast, a light one pushes it back
	player.camera_ctl.kick(clampf(amount / 30.0, 0.3, 1.0))
	Sfx.play(Player.SFX_HURT, player.global_position + Vector3.UP, -3.0)
	Events.player_hurt.emit(amount, from_pos)
	player._visual.hurt_react(from_pos, amount)
	if not player.has_meta("heard_strike"):
		player.set_meta("heard_strike", true)
		Events.toast.emit("They wound. A fire closes what they open.")
	add_wounds(amount)                           # last: at wounds_max this hollows


func _on_shade_leaving() -> void:
	player._shade = null


func hollow() -> void:
	if player._hollowing:
		return
	player._hollowing = true
	player.hollow_count += 1
	_drop_ash()
	Travel.saved_hollows = player.hollow_count
	Travel.save_soon()
	_shade_warned = false
	Events.hollowed.emit()
	await player.get_tree().create_timer(0.9).timeout
	if not player.is_inside_tree():
		return
	_respawn_now()
	await player.get_tree().create_timer(0.4).timeout
	if not player.is_inside_tree():
		return
	player._hollowing = false


func _respawn_now() -> void:
	player.locomotion.teleport(player.checkpoint)                      # no interpolation streak across the map, no stale state
	player.targeting._release_lock()
	if player._stam != null:
		player._stam.refill()
	if player._arts != null:
		player._arts.cancel()
	player.gloom = 0.0
	player.wounds = 0.0
	Events.gloom_changed.emit(player.gloom, player.gloom_max)
	_emit_wounds()
	if is_instance_valid(player._shade):
		player._shade.queue_free()
	Events.respawned.emit(player.checkpoint)


## Hollowing costs the ash carried since the last fire: it is left in a mound where you fell.
## Walk back to it to take it up; be hollowed again first and it is gone.

func _drop_ash() -> void:
	if is_instance_valid(_ash_mound):
		_ash_mound.queue_free()               # the old mound is lost
	_ash_mound = null
	var have := Travel.count("grave_ash")
	if player._ash_banked < 0 or player._ash_banked > have:
		player._ash_banked = have
	var carried := have - player._ash_banked
	if carried <= 0:
		return
	var host := player.get_tree().current_scene if player.is_inside_tree() else null
	if host == null:
		return
	Travel.items["grave_ash"] = player._ash_banked
	Travel.save_soon()
	var at := player.global_position if player._grounded or player._safe_ground == Vector3.INF else player._safe_ground
	var m := Node3D.new()
	m.set_script(ASH_MOUND)
	m.set("amount", carried)
	host.add_child(m)
	m.global_position = at
	_ash_mound = m
	Hints.once(&"ash_mound", "Your carried ash lies where you fell. Walk back to it.")


## Off the bottom of the world or falling for ages: not a death. Back to the last solid ground
## stood on (else the checkpoint) with a little Gloom for it; r29: it used to respawn at the
## brazier with the Gloom wiped, a free cleanse for jumping into the chasm.

func _fell_out() -> void:
	player._fall_t = 0.0
	var to := player._safe_ground if player._safe_ground != Vector3.INF else player.checkpoint
	if to.y < -38.0:
		to = player.checkpoint
	player.locomotion.teleport(to + Vector3.UP * 0.1)
	add_gloom(8.0)
	SpellFx.rift_in(to)
	player.camera_ctl.kick(0.5)
	Events.toast.emit("The dark gives you back. It keeps a little.")


## Stuck inside geometry (pushed in by a moving platform, a bad spawn, a seam): after a second of
## pushing the stick without moving while the capsule overlaps the world, lift the body out, or
## put it back on the last safe ground.

func _stuck_tick(delta: float, wish: Vector3) -> void:
	if player._hollowing or player.autopilot or player.traversal._trav_busy() or player._mantle_t >= 0.0 or wish.length_squared() < 0.25:
		player._stuck_t = 0.0
		_stuck_from = player.global_position
		return
	if _stuck_from == Vector3.INF or player.global_position.distance_squared_to(_stuck_from) > 0.0225:
		_stuck_from = player.global_position
		player._stuck_t = 0.0
		return
	player._stuck_t += delta
	if player._stuck_t < 1.0:
		return
	player._stuck_t = 0.0
	if player.locomotion._headroom() or (player._col and (player._col.shape as CapsuleShape3D).height < player._col_h):
		return                                  # just a wall in the way, or crouched under something
	for up: float in [0.3, 0.6, 1.0, 1.5]:
		var at := player.global_position + Vector3.UP * up
		if player.locomotion._headroom(at):
			print("Player: freed from geometry at %s (+%.1f m)" % [player.global_position, up])
			player.locomotion.teleport(at)
			return
	if player._safe_ground != Vector3.INF and player.locomotion._headroom(player._safe_ground):
		print("Player: stuck at %s, back to safe ground %s" % [player.global_position, player._safe_ground])
		player.locomotion.teleport(player._safe_ground + Vector3.UP * 0.05)


## A dodge roll met a blow in its first PERFECT_T seconds: time slows, Breath comes back, the
## attacker is Marked and the next strike or bolt is a riposte.

func _perfect_dodge(attacker: Node) -> void:
	var now := Time.get_ticks_msec() * 0.001
	player._riposte_cd = now + 1.5
	player._riposte_ready = true
	if player._stam != null:
		player._stam.refund(Stamina.PERFECT_REFUND)
	var at := player.global_position + Vector3.UP * 2.0
	HitText.pop(at, "PERFECT DODGE", Color(1.5, 1.2, 0.6), true)
	Hints.once(&"perfect_dodge", "PERFECT DODGE: roll the instant a blow lands. Breath back, and your next strike or bolt is a riposte.")
	if attacker and is_instance_valid(attacker) and attacker.has_method("add_mark"):
		attacker.add_mark(1)
	StaffSfx.play("perfect", at, -4.0)
	SpellFx.shell(player.global_position + Vector3.UP, 0.3, 2.0, Color(1.6, 1.2, 0.6), 0.3)
	player.hitstop(0.2, 0.3)


## Gloom from a hard landing: the jolt lets the dark in. Rolled out, half; never to the cap.

func _fall_hurt(impact: float) -> void:
	var rolled := player._rolled_landing
	player._rolled_landing = false
	player.falls_hurt = 0.0
	if impact <= Player.FALL_HURT_V or player.autopilot or player._hollowing:
		return
	var g := minf((impact - Player.FALL_HURT_V) * Player.FALL_GLOOM, 30.0) * (0.5 if rolled else 1.0)
	g = minf(g, maxf(0.0, player.wounds_max - 1.0 - player.wounds))     # a fall wounds; it never hollows on its own
	if g <= 0.0:
		return
	player.falls_hurt = g
	add_wounds(g)
	HitText.pop(player.global_position + Vector3.UP * 2.2, "jarred +%d" % int(round(g)), Color(0.9, 0.6, 0.55))
	Hints.once(&"fall_hurt", "Long drops jar the dark in. Roll as you land (dodge), or open the robe to glide (jump again in the air).")
	player._visual.hurt_react(Vector3.INF, g)
	player.camera_ctl.kick(clampf(g / 20.0, 0.3, 1.0))
