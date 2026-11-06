class_name Enemy
extends CharacterBody3D
## Melee crawler base. Steering is flat and cheap (straight at the target, local wall-following); only
## when the straight line is walled or it stops making progress does it ask the baked navigation mesh
## for a path (NavAssist, at think rate, at most twice a second) and follow its corners; the same
## fallback walks it home on a leash. A landed blow goes to the wanderer's Wounds
## (Player.take_wound; a guard or a roll can turn it); Gloom is the dark's clock only, never a foe's damage.

enum { IDLE, CHASE, WINDUP, STRIKE, RECOVER, DEAD, LEAP_PREP, AIRBORNE, FEINT, SPECIAL, CALL }
## FEINT    a false start: the rig rears but no red fills -- it settles, then the real tell comes.
##          The rule the player learns: no red on the ground, no hit.
## SPECIAL  a kind's own move (a charge, a slam, a burrow, a cast); the subclass drives it through
##          _special_think() and moves the body with _drive.
## CALL     the first of a pack to see you throws its head back and howls: the rest wake and come.
##
## Readability (the HUD reads this header as its contract):
##   display_name() -> String         "Chanter", "Hobb, Who Knocks Thrice", "Mother Sallow", a boss's title
##   rank() -> String                 "normal" | "elite" | "rare" | "boss"
##   level() -> int                   1.. from the night's danger tier and rank (-1 for a boss: show "??")
##   hp (float) / max_hp (int)        health
##   cast_info() -> Dictionary        {} when not casting, else {"name", "progress" 0..1, "time", "left",
##                                    "interruptible"}; also the plain fields cast_name / cast_time /
##                                    cast_elapsed / cast_interruptible and casting() / cast_progress()
##   debuffs() -> Array[Dictionary]   [{"id", "name", "left" (s, -1 = open-ended), "stacks", "harmful"}]:
##                                    Umbral Marks, broken, burning / chilled / frozen / slowed (core/skills/
##                                    afflict.gd), shrouded and warded (buffs), plus anything another system
##                                    puts in meta "statuses" (an Array of the same dicts)
##   ui_info() -> Dictionary          all of the above in one call
##   is_evading() -> bool             leashed: walking home (it can be struck, which turns it back; no heal)
## Events.enemy_cast_started(enemy, name, time, interruptible) and Events.enemy_cast_ended(enemy, name,
## interrupted) fire as casts begin and end, so a cast bar needs no polling to appear.
## interrupt(by) -> bool: a skill that interrupts calls this (true = a cast was broken). Any blow breaks a
## lesser foe's interruptible cast; a boss's only a heavy blow (a Lance, a charged bolt, >= INTERRUPT_DMG)
## or a burst on its open weak point. A broken caster is locked out of casting for SILENCE seconds.
##
## Threat and aggro: the wanderer is the only foe they have. They wake inside chase_range (not while
## you shelter in fire-light), a blow from anywhere provokes them, and a pull is the whole PACK: everything
## camped within PACK_LINK of the same home comes together (the first to see you may also howl the
## ALARM_R neighbourhood awake). They leash like WoW mobs: drag one past its leash (hunt_leash, or
## HARD_LEASH x it for kinds with their own rules) or outrun its chase and it EVADES -- it walks home
## and drops its Marks and tells; its packmates reset with it. It keeps its damage (no heal at
## home) and a blow on the way turns it back into the fight. A Tollman's bell (Enemy.toll) and a tide's hunters are exempt while they hunt.

const Hints := preload("res://ui/hints.gd")
const HP_BAR_SHADER := "res://core/enemy/health_bar.gdshader"
const HP_BAR_SIZE := Vector2(0.86, 0.1)   ## metres; same value as `size` in the shader
const HP_BAR_TRAIL_HOLD := 0.28           ## seconds the pale "just lost" strip waits before draining
const HP_BAR_TRAIL_RATE := 1.4            ## ratio per second it drains at
const TURN_RATE := 10.0                   ## same turn smoothing the Player uses on its rig
const CAPSULE_R := 0.35
const CAPSULE_H := 1.7
const MARK_MAX := 3
const MARK_LIFE := 5.0
const BAR_RANGE := 28.0          ## the plate and its beads end here (sleep is 46), fading over BAR_FADE
const BAR_FADE := 4.0
const HIT_COL := Color(0.86, 0.8, 1.0)
const HIT_BIG := Color(1.0, 0.55, 0.3)

@export var max_hp := 3
@export var walk_speed := 3.4
@export var chase_range := 11.0
@export var strike_range := 1.35
@export var strike_gloom := 25.0
@export var think_hz := 10.0
@export var sleep_range := 46.0
@export var hunt_leash := 14.0
@export var light_averse := true
@export var gravity := 16.0
@export var hp_bar_y := 2.02
@export var crawler := false
@export var leaper := false
@export_group("Melee")
@export var windup_time := 0.42         ## rear-up telegraph, seconds: the dodge window
@export var strike_arc := 75.0          ## half-angle (deg) of the strike cone in front of it
@export var lunge := 4.5                ## m/s thrown forward on the strike (step back to dodge it)
@export var poise := 2.6                ## damage taken within POISE_WINDOW that staggers it
@export var recover_time := 0.55        ## open after a strike: the punish window
@export_group("")
@export_group("Leap")
@export var leap_min := 4.0             ## metres; closer than this it just walks in
@export var leap_max := 13.0            ## metres of horizontal pounce
@export var leap_apex := 1.9            ## metres above the higher end of the jump
@export var leap_prep := 0.45           ## crouch telegraph, seconds — the player's dodge window
@export var leap_cooldown := 2.6
@export var leap_lead := 0.6            ## 0 = jump at where you are, 1 = where you will be
@export var hop_len := 3.2              ## crawler hop length
@export_group("")
@export_group("Pack")
@export var combo_max := 0              ## extra blows a strike can chain into, each with its own tell
@export var combo_chance := 0.0         ## chance a windup opens a chain
@export var combo_windup := 0.3         ## the shorter tell of a chained blow (still a full cone)
@export var feint_chance := 0.0         ## chance a windup is a feint first
@export var can_call := true            ## first of a pack to see you howls the rest awake
@export var can_flee := true            ## badly hurt with packmates near: falls back once
@export var mass := 1.0                 ## knockback divides by this
@export var role: StringName = &""      ## "flanker" (your sides), "guard" (stands before casters), "support" (keeps behind a guard), "swarm"
@export var turn_rate := TURN_RATE      ## how fast it can turn to face you (a shield-bearer is slow: circle it)
@export_group("")
var home := Vector3.ZERO
var _leap_cd := 0.0
var _hop_cd := 0.0

var hp := 3.0
var _state := IDLE
var _think_cd := 0.0
var _state_t := 0.0
var _knock := Vector3.ZERO
var _flash := 0.0
var _wish := Vector3.ZERO
var _face_dir := Vector3.ZERO
var _visual: Node3D
var _face: Node3D               ## what turns to face travel; subclasses may point it at the rig itself
var _rig: CharacterRig          ## shared stride / cast; same class the Player drives
var _hp_bar: MeshInstance3D
var _hp_trail := 1.0
var _hp_trail_hold := 0.0
var _stuck_t := 0.0
var _p: Player
var _to := Vector3.ZERO
var _dist := INF
var _hitstop := 0
var marks := 0
var _mark_t := 0.0
var _pips: Array[MeshInstance3D] = []
var _ballistic := false
var _air_t := 0.0
var _pounced := false
var _squash := 0.0

var _flesh: Array[MeshInstance3D] = []
var _hit_fx := 0.0
var _glint := 0.0
var _dissolve := 0.0
var _flank := 0.0            ## per-enemy approach angle so packs surround instead of queue
var _sep := Vector3.ZERO     ## separation from packmates, refreshed at think rate
var _lit_t := 0.0            ## seconds the player has been sheltering in light
var _calm_t := 0.0           ## after giving up a chase: no re-aggro until this runs out
var _poise_dmg := 0.0        ## recent damage toward a stagger, drains at 1/POISE_WINDOW
var _stagger_cd := 0.0       ## no stun-lock: one stagger per STAGGER_CD
var _struck := false         ## this STRIKE has resolved
var _danger: MeshInstance3D  ## the telegraph cone while it fills
var _orbit := 1.0            ## which way it circles while waiting for an opening
var _dying := 0.0            ## seconds into the death collapse (rig keeps animating)
var _waiting := false        ## circling for an opening (no token)
var move_serial := 0         ## bumped when its telegraphed moves are cancelled (AttackKit)
var _moves: Array[MeshInstance3D] = []
var _combo_left := 0
var _cur_windup := 0.42      ## this windup's length (a chained blow is shorter)
var _feinted := false
var _flee_t := 0.0           ## falling back, hurt
var _fled := false
var _shaken_t := 0.0         ## a Nova just went off near it: backing off
var _wary_t := 0.0           ## ...and for a while it keeps a wider ring
var _rally_t := 0.0          ## answering a call: a little faster
var _detour := Vector3.ZERO  ## a way round what blocks the straight line to the player (zero: none)
var _detour_side := 0.0      ## the side it last went round (kept, so it does not dither at a post)
var _nav: NavAssist = null          ## the chase fallback (made on first need): path corners round walls
var _nav_home: NavAssist = null     ## the same for the walk home (leash, evade)
var _detour_mem := 0.0       ## seconds the side is still remembered after the way looked clear
var _provoked_ms := -100000  ## when a hit last stirred its pack (once a second at most)
var _ward_t := 0.0           ## a boss between phases: blows mostly turned
var _shroud_t := 0.0         ## a chanter's working on it: half damage
var _hurt_voice_cd := 0.0
var _allies := 0             ## living packmates within 10 m (think rate)
var _ward_ally: Enemy        ## nearest support (a guard stands between it and you)
var _shield_ally: Enemy      ## nearest melee packmate (a support keeps it between you)
var _guarding := false
var _last_from := Vector3.ZERO
var _last_dmg := 0.0
var _drive := Vector3.ZERO   ## SPECIAL: velocity the subclass wants this frame
var token_pool: StringName = &"melee"
var pool_max := MAX_ATTACKERS

## r31 (docs/enshrouded/enemies.md): the poise meter shows on the bar (a gold strip filling under
## the health), a stagger leaves it BROKEN for a beat (every blow lands harder), and a kind may
## carry a WEAK POINT on its body -- a glowing knot a projectile can find (a bolt that bursts on it
## deals WEAK_MULT and twice the poise). Bosses open theirs only during certain moves.
const BROKEN_MULT := 1.3
const BROKEN_MULT_BOSS := 1.2
const BOSS_BROKEN := 2.6              ## a boss whose weak point broke a move stays open this long
const WEAK_MULT := 1.6
const WEAK_COL := Color(1.7, 1.0, 0.32)      ## the knot: ember-gold, under the bloom threshold's worst
var weak_socket := ""                 ## rig socket the weak point rides on ("" = none)
var weak_offset := Vector3.ZERO       ## from that socket, in rig space
var weak_r := 0.16                    ## the knot's radius (rig space)
var weak_open := true                 ## shown and hittable (bosses toggle it during moves)
var _weak: Node3D
var _broken_t := 0.0
var _bar_poise := -1.0
var _bar_broken := -1.0
## r31 pack morale: two packmates fall near it in a few seconds and the survivors pull back together,
## one howls, and they come again as one (once a life). _hunt_t: answering a Tollman's bell (it
## tracks you far past its usual leash for a while).
var _fallen := 0.0
var _regroup_t := 0.0
var _regroup_at := Vector3.ZERO
var _regrouped := false
var _hunt_t := 0.0
static var _weak_mat: StandardMaterial3D
static var _weak_mesh: SphereMesh
static var _alarms: Array = []   ## [Vector3, msec] of recent pack calls
const ALARM_R := 18.0
const AttackKit := preload("res://core/enemy/attack_kit.gd")

## Attack tokens: at most MAX_ATTACKERS ordinary enemies wind up on the player at once; the rest
## circle at WAIT_RING and step in when one finishes. A pack reads as a pack, not a pile.
const MAX_ATTACKERS := 2
const WAIT_RING := 2.9
const POISE_WINDOW := 2.5
const STAGGER_CD := 3.0
const STAGGER_TIME := 1.1
const HunchRig := preload("res://core/enemy/hunch_rig.gd")
const Synth := preload("res://core/vfx/synth.gd")
static var _tokens := {}     # instance id -> true while it holds a token
## Bosses skip tokens and are not counted (their minions still queue among themselves).
var boss := false

## r33: casts (see the header). A cast "bound" to a state ends when the state does (a Chanter's sigil in
## WINDUP, a Tollman's toll in SPECIAL); a timed one (bound = false: the bosses') ends by its clock and
## then runs its `done` callable. Interrupted casts never run it.
const INTERRUPT_DMG := 2.0
const SILENCE := 4.0
const INTERRUPT_COL := Color(0.75, 0.9, 1.6)
const PACK_LINK := 9.0
const HARD_LEASH := 2.2
const EVADE_PACE := 1.0               ## r35: it walks home (it ran at 1.8, immune)
const EVADE_MAX := 12.0
const EVADE_COL := Color(0.85, 0.85, 0.95)
const AFFLICT_PATH := "res://core/skills/afflict.gd"
signal cast_started(cast: String, time: float, interruptible: bool)
signal cast_ended(cast: String, interrupted: bool)
signal evaded()                 ## got home from a leash (r35: not healed)
var cast_name := ""
var cast_time := 0.0
var cast_elapsed := 0.0
var cast_interruptible := false
var _cast_bound := -1
var _cast_done := Callable()
var _cast_cut := false
var _silence_t := 0.0
var _evading := false
var _evade_t := 0.0
## A rare (or any foe) may walk a beat round its home instead of standing at it: points on the ground.
var patrol: Array[Vector3] = []
## r34: a roaming pack or a rare on a long route: its home walks with it (the leash and the evade are
## from where you pulled it, not from the route's start), and `patrol_speed` (m/s, 0 = the old slow
## beat) keeps a pack's members in step.
var roam := false
var patrol_speed := 0.0
var _patrol_i := 0
var _patrol_wait := 0.0
## Ramps: the Wounds its blows and zones deal are multiplied by this (BossKit reads it; r35: no soft enrage).
var dmg_mult := 1.0
static var _afflict: GDScript
## EnemyBody kind to dress with; empty = the type's own (bosses set theirs before _build).
var body_kind: StringName = &""


func _kind(own: StringName) -> StringName:
	return body_kind if body_kind != &"" else own

const LIGHT_MARGIN := 0.6    ## enemies stop this far outside any lit brazier / ward radius
const SFX_DIE := "res://art/audio/enemy_die.wav"
const SFX_MARK := "res://art/audio/mark_tick.wav"
const SFX_SHRIEK := "res://art/audio/pounce_shriek.wav"

static var _pip_mesh: SphereMesh

static var _hp_bar_mesh: QuadMesh


func _ready() -> void:
	add_to_group(Groups.ENEMY)
	collision_layer = Layers.HURTBOX | Layers.PROPS
	collision_mask = Layers.WORLD
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(46.0)
	hp = float(max_hp)
	_think_cd = randf() / think_hz
	_flank = randf_range(-0.55, 0.55)
	_cur_windup = windup_time
	if not Events.skill_cast.is_connected(_on_skill_cast):
		Events.skill_cast.connect(_on_skill_cast)
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_face = _visual
	_ensure_capsule()
	_build()
	_make_weak()
	_pin_visuals()
	if _hp_bar == null:
		_make_hp_bar()
	call_deferred("_remember_home")


func _ensure_capsule() -> void:
	if get_node_or_null("Collision") != null:
		return
	var col := CollisionShape3D.new()
	col.name = "Collision"
	var cap := CapsuleShape3D.new()
	cap.radius = CAPSULE_R
	cap.height = CAPSULE_H
	col.shape = cap
	col.position = Vector3(0.0, 0.85, 0.0)
	add_child(col)


## Humanoids get HunchRig (the wanderer's skeleton with an enemy's posture, telegraph, strike and
## flinch); the jumpers pass a QuadRig. dress_default off so types paint their own look.
func attach_rig(custom: CharacterRig = null) -> CharacterRig:
	var rig: CharacterRig = custom if custom != null else HunchRig.new() as CharacterRig
	rig.dress_default = false
	rig.rim_light = false
	rig.driven = true
	rig.melee = true
	rig.walk_speed = walk_speed
	_visual.add_child(rig)
	if rig.socket("chest") == null:
		rig._build()
	_face = rig
	_rig = rig
	return rig


## Per-kind stance on a HunchRig: {"hunch", "crouch", "arm_reach", "head_jut", "limp", "sway",
## "twitch", "splay"}. Ignored on other rigs.
func posture(p: Dictionary) -> void:
	if _rig == null or not (_rig.get_script() == HunchRig):
		return
	for k: String in p:
		_rig.set(k, p[k])


## Bare mannequin on the shared sockets. Types pass a skin; they do not walk bone paths.
func dress_dummy(skin: Material) -> void:
	if _rig == null:
		return
	_limb("chest", "Torso", ProcMesh.capsule(0.16, 0.58), Vector3(0.0, 0.02, 0.0), skin)
	_limb("head", "Head", ProcMesh.sphere(0.11, 0.18, 10, 6), Vector3(0.0, 0.04, 0.0), skin)
	_limb("shoulder_l", "ArmL", ProcMesh.cyl(0.045, 0.05, 0.58, 8, 1), Vector3(0.0, -0.28, 0.0), skin)
	_limb("shoulder_r", "ArmR", ProcMesh.cyl(0.045, 0.05, 0.58, 8, 1), Vector3(0.0, -0.28, 0.0), skin)
	_limb("hip_l", "LegL", ProcMesh.cyl(0.055, 0.048, 0.78, 8, 1), Vector3(0.0, -0.40, 0.0), skin)
	_limb("hip_r", "LegR", ProcMesh.cyl(0.055, 0.048, 0.78, 8, 1), Vector3(0.0, -0.40, 0.0), skin)


func _limb(socket_name: String, n_name: String, mesh: Mesh, at: Vector3, skin: Material) -> void:
	var joint := _rig.socket(socket_name)
	if joint == null:
		return
	ProcMesh.mesh(joint, n_name, mesh, skin, at, Vector3.ZERO, false)


## Damage comes from anything with this method (the bolt finds it by walking up from the collider).
## Hit feel: a freeze of 2-6 physics frames scaled by the hit (the body shudders in place), a flinch
## on the rig away from the source, a wet/bone thud, knockback, and poise: enough damage inside
## POISE_WINDOW staggers it (long reel, windup cancelled) -- heavy hits on a windup always do.
func take_hit(dmg: float, from: Node = null) -> void:
	if _state == DEAD:
		return
	if _evading:
		# r35: walking home is not a shield (it was WoW's immune "evade"): the blow lands, and it
		# turns back on you with what it has left
		_end_evade()
		_hunt_t = maxf(_hunt_t, 5.0)
	var weak := _weak_hit(from)
	if weak:
		dmg *= WEAK_MULT
	if _broken_t > 0.0:
		dmg *= BROKEN_MULT_BOSS if boss else BROKEN_MULT
	dmg = _absorb(dmg, from)                     # after: a boss's phase floor still holds
	if dmg <= 0.0:
		return
	if weak:
		_poise_dmg += dmg                        # twice the poise: a weak point is how you break one
		HitText.pop(global_position + Vector3.UP * (hp_bar_y + 0.85), "weak point", WEAK_COL)
		Vfx.burst(_weak.global_position, WEAK_COL, {"count": 18, "life": 0.35, "speed": Vector2(2.0, 5.5), "size": 0.04, "gravity": -6.0, "trail": 0.06})
		Sfx.play_stream(Synth.get_stream("bone"), _weak.global_position, -2.0, 1.4)
		Hints.once(&"weak_point", "Glowing knots are weak points: a bolt that bursts on one hits far harder and breaks its guard.")
		_on_weak_hit(dmg)
	if _ward_t > 0.0:
		dmg *= 0.15
		HitText.pop(global_position + Vector3.UP * (hp_bar_y + 0.6), "warded", Color(0.8, 0.7, 1.0))
	elif _shroud_t > 0.0:
		dmg *= 0.5
		Vfx.ring(global_position + Vector3.UP * (hp_bar_y * 0.55), 0.7, AttackKit.GLOAM, 0.25, 0.06, Vector3.UP, 0.8)
	_last_dmg = dmg
	if from is Node3D:
		var away3 := global_position - (from as Node3D).global_position
		away3.y = 0.0
		_last_from = away3.normalized() if away3.length() > 0.05 else Vector3.ZERO
	hp = maxf(hp - dmg, 0.0)
	_flash = 0.08
	_hit_fx = 1.0
	var at := global_position + Vector3.UP * (hp_bar_y * 0.6)
	# ENS art pass: a flash star + sparks thrown away from the blow (core/vfx/vfx.gd impact)
	Vfx.impact(at, Color(1.6, 0.8, 2.4), _last_from if from is Node3D else Vector3.ZERO, dmg >= 3.0)
	# three presets (the hitstop's tiers), not one per damage value: Vfx pools and caches by preset,
	# and damage carries every multiplier. The count still follows the hit through amount_ratio (r30).
	var tier := 0 if dmg < 1.5 else (1 if dmg < 3.0 else 2)
	var cap: int = [16, 22, 40][tier]
	Vfx.burst(at, _ichor(), {"count": cap, "life": 0.55, "speed": Vector2(1.5, [4.8, 6.05, 7.8][tier]), "size": 0.07, "gravity": -9.5, "additive": false, "ratio": clampf((10.0 + dmg * 4.0) / cap, 0.25, 1.0)})
	var big := dmg >= 3.0
	HitText.pop(global_position + Vector3.UP * (hp_bar_y + 0.35), _dmg_text(dmg), HIT_BIG if big else HIT_COL, big)
	_hitstop = 2 if dmg < 1.5 else (4 if dmg < 3.0 else 6)
	if hp <= 0.001:
		_hitstop = 6
	_refresh_hp(true)
	Sfx.play_stream(Synth.get_stream(_hit_sound()), at, -5.0 + minf(dmg, 4.0), 1.15 - minf(dmg, 4.0) * 0.06)
	if hp > 0.001 and _hurt_voice_cd <= 0.0:
		_hurt_voice_cd = 0.7
		Sfx.play_stream(Synth.voice(voice_family(), "hurt"), at, -9.0, _voice_pitch())
	var p := _player()
	if p:
		p.cast_impulse()
	var side := 0.0
	if from is Node3D:
		var away := global_position - (from as Node3D).global_position
		away.y = 0.0
		if away.length() <= 0.05 and _face:
			away = _face.global_basis.z                 # on top of the source: thrown backwards
			away.y = 0.0
		if away.length() > 0.05:
			_knock = away.normalized() * knockback(dmg) / maxf(mass, 0.2)
			if _face:
				side = clampf((_face.global_basis.inverse() * away.normalized()).x, -1.0, 1.0)
	if _rig and _rig.has_method("flinch"):
		_rig.call("flinch", clampf(0.35 + dmg * 0.22, 0.0, 1.0), side)
	if hp <= 0.001:
		_die()
		return
	if not boss:
		_provoke(from)
	if casting() and cast_interruptible and _interrupts(dmg, from, weak):
		interrupt(from)
	_poise_dmg += dmg
	var winding := _state == WINDUP or _state == LEAP_PREP or _state == FEINT or (_state == SPECIAL and _special_breakable())
	if _stagger_cd <= 0.0 and (_poise_dmg >= poise or (dmg >= 2.0 and winding)):
		stagger()
	elif can_flee and not boss and not _fled and _allies >= 1 and _hp_ratio() < 0.34 and not has_meta(&"enc_hunter"):
		_start_flee()


## Hurt by something it had not noticed (a bolt from beyond its wake range): it turns on the shooter
## and hunts past its usual range a while, and the pack within earshot wakes with it. Before r30 an
## idle enemy took the hit and went on holding its post, and so did everything stood beside it.
func _provoke(from: Node) -> void:
	_rally_t = maxf(_rally_t, 6.0)
	_hunt_t = maxf(_hunt_t, 5.0)                 # r33: it comes for the shooter, it does not just leash home
	_calm_t = 0.0
	if _state == IDLE:
		_set_state(CHASE)
	var now := Time.get_ticks_msec()
	if now - _provoked_ms < 1000:
		return
	_provoked_ms = now
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		if node != self and node is Enemy and (node as Enemy)._state == IDLE and (node as Node3D).global_position.distance_to(global_position) < ALARM_R:
			(node as Enemy).alerted(from)


## Hook: a shield turns the blow (returns what gets through). Default: all of it.
func _absorb(dmg: float, _from: Node) -> float:
	return dmg


## Hook: can a heavy hit break this SPECIAL's tell like a windup? (a charge mid-run cannot)
func _special_breakable() -> bool:
	return true


## Badly hurt with its pack about: it backs off for a moment (cowering, a whimper), then returns.
## Once a life. Lone ones fight to the end.
func _start_flee() -> void:
	_fled = true
	_flee_t = 2.4
	_combo_left = 0
	if _state == WINDUP or _state == FEINT or _state == CHASE or _state == CALL:
		_set_state(CHASE)
	Sfx.play_stream(Synth.voice(voice_family(), "flee"), global_position + Vector3.UP, -6.0, _voice_pitch())


## Knockback speed for a hit; bosses shrug most of it off.
func knockback(dmg: float) -> float:
	dmg = minf(dmg, 6.0)                         # a huge blow (a Shatter, a test's 999) throws, not launches
	return (1.6 if boss else 3.4) + dmg * (0.4 if boss else 1.1)


## A long reel: windup cancelled, token given up, open to a free combo. The reward for reading a
## tell (heavy hit on a windup) or for pressure (poise). Not again for STAGGER_CD.
func stagger() -> void:
	if _state == DEAD:
		return
	_poise_dmg = 0.0
	_stagger_cd = STAGGER_CD
	# a boss is broken only by its weak point (its own handlers open the window), not by poise
	_broken_t = STAGGER_TIME + 0.5 if not boss else 0.0
	_ballistic = false
	_combo_left = 0
	_cast_cut = true                             # r33: a state-bound cast (a lesser caster's) breaks with it
	if not boss:
		cancel_moves()                           # a boss's set pieces outlast a stagger (a phase change takes them)
	_hitstop = maxi(_hitstop, 5)              # the reel lands with a longer crunch than a plain hit
	_set_state(RECOVER)
	_state_t = -(STAGGER_TIME - recover_time)
	if _rig and _rig.has_method("stagger"):
		_rig.call("stagger")
	HitText.pop(global_position + Vector3.UP * (hp_bar_y + 0.6), "broken", Color(1.0, 0.8, 0.5))
	Sfx.play_stream(Synth.get_stream("stagger"), global_position + Vector3.UP, -3.0, 1.0 if not boss else 0.7)
	Vfx.ring(global_position + Vector3.UP * 0.1, 1.2 * maxf(hp_bar_y / 2.0, 0.6), Color(1.6, 1.2, 0.5), 0.4, 0.1, Vector3.UP, 1.0)


func _hit_sound() -> String:
	return "flesh"


## Synth voice family (Synth.VOICES): growls, cries and calls.
func voice_family() -> String:
	return "rasp"


## Its telegraphed area moves (AttackKit) are cancelled: staggered, riposted or dead.
func cancel_moves() -> void:
	move_serial += 1
	for mi in _moves:
		if is_instance_valid(mi):
			mi.queue_free()
	_moves.clear()


func track_move(mi: MeshInstance3D) -> void:
	var keep: Array[MeshInstance3D] = []
	for m in _moves:
		if is_instance_valid(m):
			keep.append(m)
	keep.append(mi)
	_moves = keep


## A chanter's working: half damage for `t` seconds, a violet shimmer on the flesh.
func shroud(t: float) -> void:
	if _state == DEAD:
		return
	_shroud_t = maxf(_shroud_t, t)
	SpellFx.shell(global_position + Vector3.UP * (hp_bar_y * 0.5), 0.3, 1.1, AttackKit.GLOAM, 0.5)


## Woken by a packmate's call: come now, a little faster for a while.
func alerted(_by: Node) -> void:
	if _state == DEAD or boss or _evading:
		return
	_calm_t = 0.0
	_rally_t = 4.0
	if _state == IDLE:
		_set_state(CHASE)


## Umbral Nova near it: survivors back off a beat and keep a wider ring for a while (they learn).
func _on_skill_cast(id: StringName) -> void:
	if id != &"nova" or _state == DEAD or boss or not is_inside_tree() or process_mode == Node.PROCESS_MODE_DISABLED:
		return
	_cache_player()
	if _dist > 12.0:
		return
	_wary_t = 6.0
	if _dist < 8.5 and (_state == CHASE or _state == IDLE or _state == CALL):
		_shaken_t = 0.9
		if _state == IDLE:
			_set_state(CHASE)
	_on_nova_near()


## Hook for kinds that answer a Nova differently (a support fires back at once).
func _on_nova_near() -> void:
	pass


## Blood colour for hit/death sprays (non-additive particles).
func _ichor() -> Color:
	return Color(0.35, 0.05, 0.12)


static func _dmg_text(dmg: float) -> String:
	return str(roundi(dmg)) if is_equal_approx(dmg, roundf(dmg)) else "%.1f" % dmg


func station(at: Vector3) -> void:
	home = at
	global_position = at + Vector3(0.0, 0.05, 0.0)


func wake() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT


func sleep() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_DISABLED


func _remember_home() -> void:
	if home == Vector3.ZERO:
		home = global_position


func _pin_visuals() -> void:
	if _hp_bar == null:
		return
	_range_cap(_hp_bar)
	_hp_bar.extra_cull_margin = maxf(_hp_bar.extra_cull_margin, 2.4)
	_hp_bar.ignore_occlusion_culling = true
	for pip in _pips:
		_range_cap(pip)


func _range_cap(g: GeometryInstance3D) -> void:
	g.visibility_range_end = BAR_RANGE
	g.visibility_range_end_margin = BAR_FADE
	g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


func _build() -> void:
	pass


## Body parts from EnemyBody.dress(); their flesh shader reads hit_flash / glint / dissolve.
func set_flesh(parts: Array[MeshInstance3D]) -> void:
	_flesh = parts


func _flesh_param(param: StringName, v: float) -> void:
	for mi in _flesh:
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter(param, v)


# --- health bar ---------------------------------------------------------------------------------
# One quad, one shared mesh + material. Per-enemy state is three instance uniforms (health_bar.gdshader).

func _make_hp_bar() -> void:
	if _hp_bar_mesh == null:
		var mat := ShaderMaterial.new()
		mat.shader = load(HP_BAR_SHADER)
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE            # the shader scales it to HP_BAR_SIZE
		quad.material = mat
		_hp_bar_mesh = quad
	_hp_bar = MeshInstance3D.new()
	_hp_bar.name = "HealthBar"
	_hp_bar.mesh = _hp_bar_mesh
	_hp_bar.position = Vector3(0.0, hp_bar_y, 0.0)
	_hp_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hp_bar.extra_cull_margin = 1.2
	_range_cap(_hp_bar)
	_hp_bar.ignore_occlusion_culling = true
	add_child(_hp_bar)
	_hp_bar.set_instance_shader_parameter(&"segments", hp_segments(max_hp))
	_hp_trail = _hp_ratio()
	_refresh_hp(false)
	_make_pips()


## Notches on the bar: one per hit point for small things; a big pool (an elite, a boss) gets one
## notch per ~10 % instead -- at 90 notches the 0.86 m bar was all frame and no fill.
static func hp_segments(pool: int) -> float:
	if pool <= 12:
		return float(maxi(pool, 1))
	return float(pool) / ceilf(float(pool) / 10.0)


## Umbral Marks: three violet beads over the bar. Shared mesh + material, toggled per stack.
func _make_pips() -> void:
	if _pip_mesh == null:
		_pip_mesh = SphereMesh.new()
		_pip_mesh.radius = 0.045
		_pip_mesh.height = 0.09
		_pip_mesh.radial_segments = 8
		_pip_mesh.rings = 4
		_pip_mesh.material = ProcMesh.glow_mat(Color(1.5, 0.6, 3.2))
	for i in MARK_MAX:
		var pip := MeshInstance3D.new()
		pip.mesh = _pip_mesh
		pip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pip.position = Vector3((float(i) - 1.0) * 0.14, hp_bar_y + 0.16, 0.0)
		pip.visible = false
		_range_cap(pip)
		add_child(pip)
		_pips.append(pip)


func add_mark(n := 1) -> void:
	if _state == DEAD:
		return
	marks = mini(MARK_MAX, marks + n)
	_mark_t = MARK_LIFE
	_refresh_pips()
	if marks >= 3:
		Hints.once(&"nova_marks", "%s  Umbral Nova detonates Marks: each one is another blow. Marks last 5 seconds." % Hints.key("skill_nova", "Q"))
	Sfx.play(SFX_MARK, global_position, -12.0, 0.9 + 0.12 * float(marks))
	Vfx.ring(global_position + Vector3.UP * (hp_bar_y + 0.16), 0.22 + 0.06 * float(marks), Color(1.4, 0.6, 3.0), 0.3, 0.2, Vector3.BACK)


func take_marks() -> int:
	var m := marks
	marks = 0
	_refresh_pips()
	return m


func _refresh_pips() -> void:
	for i in _pips.size():
		_pips[i].visible = i < marks
		_pips[i].transparency = 0.0


## The beads thin with the clock (the set shares one MARK_LIFE) and fade across the last second.
func _fade_pips() -> void:
	var t := 0.45 * (1.0 - _mark_t / MARK_LIFE) + 0.55 * (1.0 - clampf(_mark_t, 0.0, 1.0))
	for i in marks:
		_pips[i].transparency = clampf(t, 0.0, 0.95)


func is_alive() -> bool:
	return _state != DEAD


func shove(v: Vector3) -> void:
	_knock = Vector3(v.x, 0.0, v.z)
	if is_on_floor() and not _ballistic:
		velocity.y = 2.4


## Ballistic jump that lands on `target`. The apex sits `apex` m above the higher end, so up-stair
## and down-stair pounces both arc. Returns the flight time.
func launch_at(target: Vector3, apex: float) -> float:
	var from := global_position
	var dy := target.y - from.y
	var h := maxf(apex, dy + apex * 0.5)
	var vy := sqrt(2.0 * gravity * h)
	var t := vy / gravity + sqrt(2.0 * maxf(h - dy, 0.05) / gravity)
	var flat := Vector3(target.x - from.x, 0.0, target.z - from.z)
	velocity = Vector3(flat.x / t, vy, flat.z / t)
	_ballistic = true
	_air_t = 0.0
	_pounced = false
	_stuck_t = 0.0
	return t


func flight_time(apex: float, dy: float) -> float:
	var h := maxf(apex, dy + apex * 0.5)
	var vy := sqrt(2.0 * gravity * h)
	return vy / gravity + sqrt(2.0 * maxf(h - dy, 0.05) / gravity)


func _hp_ratio() -> float:
	return clampf(hp / maxf(float(max_hp), 0.001), 0.0, 1.0)


## The fill is exact and instant (one third of the bar per hit with 3 HP). The pale trail behind it
## lags, so the size of the chunk you just took stays readable for a moment.
func _refresh_hp(hit: bool) -> void:
	if _hp_bar == null:
		return
	var ratio := _hp_ratio()
	_hp_bar.set_instance_shader_parameter(&"fill", ratio)
	if hit:
		_hp_trail_hold = HP_BAR_TRAIL_HOLD
	else:
		_hp_trail = ratio
	_hp_bar.set_instance_shader_parameter(&"trail", maxf(_hp_trail, ratio))


func _tick_hp_trail(delta: float) -> void:
	var ratio := _hp_ratio()
	if _hp_bar == null or _hp_trail <= ratio:
		return
	if _hp_trail_hold > 0.0:
		_hp_trail_hold -= delta
		return
	_hp_trail = maxf(move_toward(_hp_trail, ratio, delta * HP_BAR_TRAIL_RATE), ratio)
	_hp_bar.set_instance_shader_parameter(&"trail", _hp_trail)


# --- behaviour ----------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _state == DEAD:
		_tick_dying(delta)
		return
	_tick_cast(delta)                            # r33: in hitstop too (a boss's cast keeps time with its zones)
	_silence_t = maxf(0.0, _silence_t - delta)
	if _hitstop > 0:
		# frozen mid-pose, shuddering: the crunch of a hit landing
		_hitstop -= 1
		if _state == WINDUP or _state == LEAP_PREP:
			_state_t += delta                    # the tell's clock keeps time with its red fill
		_shudder()
		return
	_cache_player()
	_poise_dmg = maxf(0.0, _poise_dmg - delta * poise / POISE_WINDOW)
	_stagger_cd = maxf(0.0, _stagger_cd - delta)
	_flee_t = maxf(0.0, _flee_t - delta)
	_shaken_t = maxf(0.0, _shaken_t - delta)
	_wary_t = maxf(0.0, _wary_t - delta)
	_rally_t = maxf(0.0, _rally_t - delta)
	_ward_t = maxf(0.0, _ward_t - delta)
	_broken_t = maxf(0.0, _broken_t - delta)
	_fallen = maxf(0.0, _fallen - delta * 0.12)
	_regroup_t = maxf(0.0, _regroup_t - delta)
	_hunt_t = maxf(0.0, _hunt_t - delta)
	_hurt_voice_cd = maxf(0.0, _hurt_voice_cd - delta)
	if _shroud_t > 0.0:
		_shroud_t = maxf(0.0, _shroud_t - delta)
		_flesh_param(&"glint", 0.35 + 0.25 * sin(_shroud_t * 9.0) if _shroud_t > 0.0 else 0.0)
	if _state == STRIKE and not _struck and _state_t >= 0.06:
		_resolve_strike()
	if is_instance_valid(_danger) and _face:
		_danger.rotation.y = _face.rotation.y
	if home != Vector3.ZERO and global_position.y < home.y - 8.0:
		global_position = home + Vector3(0.0, 0.1, 0.0)
		velocity = Vector3.ZERO
		_ballistic = false
		reset_physics_interpolation()
		_set_state(IDLE)
	_think_cd -= delta
	if _think_cd <= 0.0:
		_think_cd = 1.0 / think_hz
		if _evading:
			_tick_evade(1.0 / think_hz)          # r33: leashed: home, nothing else (no kind's own think)
		else:
			_leash_check()
			if not _evading:
				_think()
	if _state == WINDUP and _state_t >= _cur_windup and _exact_windup() and _dist <= strike_range + 2.0:
		_set_state(STRIKE)                       # on the frame the red fills, not up to a think later
	if _state == CHASE and _chases_directly() and not _waiting and _flee_t <= 0.0 and _shaken_t <= 0.0 and not _guarding and _regroup_t <= 0.0:
		_aim_at_player()
	elif _state == LEAP_PREP and _to.length_squared() > 0.01:
		_face_dir = _to.normalized()
	elif _state == SPECIAL:
		_special_frame(delta)
	_leap_cd = maxf(0.0, _leap_cd - delta)
	_hop_cd = maxf(0.0, _hop_cd - delta)
	if marks > 0:
		_mark_t -= delta
		if _mark_t <= 0.0:
			marks = 0
			_refresh_pips()
		else:
			_fade_pips()
	_move(delta)
	_flash_visual(delta)
	_tick_hp_trail(delta)
	if _hp_bar:
		_hp_bar.visible = _state != IDLE or hp < float(max_hp) - 0.01
		if _hp_bar.visible:
			_tick_bar_poise()
	if _weak:
		_tick_weak()


func _cache_player() -> void:
	if not is_instance_valid(_p):
		_p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	if _p == null:
		_to = Vector3.ZERO
		_dist = INF
		return
	_to = _p.global_position - global_position
	_to.y = 0.0
	_dist = _to.length()
	# r36 the Kindled Watch: an assault on a watch-post goes for its watchmen while the wanderer
	# keeps her distance; she is always the first choice once she comes close
	if focus != null and _dist > FOCUS_DROP:
		if is_instance_valid(focus) and not bool(focus.get_meta(&"down", false)):
			_to = focus.global_position - global_position
			_to.y = 0.0
			_dist = _to.length()
		else:
			focus = null


## r36: the watchman this one fights (core/world/watch/watch.gd), while the wanderer is further than
## FOCUS_DROP. Its blows are counted by the watch, not by the strike (which only hurts the wanderer).
var focus: Node3D = null
const FOCUS_DROP := 7.0


## Packmates push apart within 1.4 m, and -- once they are near the player -- also spread round
## it: anyone whose bearing from the player is within ~55 degrees of ours nudges us sideways, so a
## pack fans out into a ring instead of arriving in a line (`_surround`).
func _update_separation() -> void:
	_sep = Vector3.ZERO
	var near_p := _p != null and _dist < 7.0 and _dist > 0.05
	var me := _to / _dist if near_p else Vector3.ZERO
	_allies = 0
	_ward_ally = null
	_shield_ally = null
	var best_ward := 144.0
	var best_shield := 144.0
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		if node == self:
			continue
		var o := node as Node3D
		var d := global_position - o.global_position
		d.y = 0.0
		var l2 := d.length_squared()
		if l2 < 1.96 and l2 > 0.0001:
			_sep += d / l2 * 0.5
		if l2 < 100.0 and node is Enemy and (node as Enemy).is_alive() and not (node as Enemy).boss:
			var en := node as Enemy
			_allies += 1
			if en.role == &"support" and l2 < best_ward:
				best_ward = l2
				_ward_ally = en
			elif en.role != &"support" and en.role != &"swarm" and l2 < best_shield:
				best_shield = l2
				_shield_ally = en
		if near_p and node is Enemy and (node as Enemy).is_alive():
			var od := _p.global_position - o.global_position
			od.y = 0.0
			var ol := od.length()
			if ol < 7.0 and ol > 0.05:
				var cross := me.cross(od / ol).y           # >0: they are clockwise of us
				var dot := me.dot(od / ol)
				if dot > 0.57:
					var tangent := Vector3(-me.z, 0.0, me.x)
					_sep -= tangent * signf(cross if absf(cross) > 0.01 else float(get_instance_id() % 2) - 0.5) * (dot - 0.57) * 2.4


## Chasing with a wall, fence or rock across the straight line: follow its face round, one way (the
## way the player leans, kept until the line is clear: no dithering at a post).
## Think rate only (10 Hz): a handful of rays per chasing enemy. Before r30 they ran into the wall,
## stalled, and wiggled and hopped (the stuck nudge, still the last resort when boxed in).
func _update_detour() -> void:
	_detour = Vector3.ZERO
	if _state != CHASE or _p == null or crawler or _dist < 3.0 or _dist == INF or not is_on_floor():
		_detour_side = 0.0
		if _nav != null:
			_nav.reset()
		return
	var space := get_world_3d().direct_space_state
	# the baked mesh when the straight line is walled or progress has stopped (NavAssist); else the
	# local wall-following below
	var corner := _nav_point(false, _p.global_position, not _waiting)
	if corner != Vector3.INF:
		var cd := corner - global_position
		cd.y = 0.0
		if cd.length_squared() > 0.01:
			_detour = cd.normalized()
			_detour_side = 0.0
			return
	var to := _to / _dist
	var from := global_position + Vector3.UP * 0.9
	# while going round, the whole line to the player must be clear before it turns back in (a short
	# look clears as soon as it steps off the face, and it turned back into the wall and dithered)
	var hit := _probe(space, from, to, minf(_dist - 1.0, 8.0 if _detour_side != 0.0 else 2.8))
	_detour_mem = maxf(0.0, _detour_mem - 1.0 / think_hz)
	if hit.is_empty():
		if _detour_mem <= 0.0:
			_detour_side = 0.0
		return
	_detour_mem = 2.0
	# follow the wall: along its face (a little off it), one way, kept until the line is clear
	var n: Vector3 = hit.normal
	n.y = 0.0
	n = n.normalized() if n.length() > 0.01 else -to
	var along := Vector3(n.z, 0.0, -n.x)
	if _detour_side == 0.0:
		var lean := along.dot(to)
		_detour_side = signf(lean) if absf(lean) > 0.35 else (1.0 if (get_instance_id() & 1) == 0 else -1.0)
	for sd: float in [_detour_side, -_detour_side]:
		var d := (along * sd + n * 0.3).normalized()
		if _probe(space, from, d, 1.6).is_empty():
			_detour = d
			_detour_side = sd
			return
	# boxed in (a corner): the stuck nudge and its hop take over


## The next path corner to `goal` when flat steering is blocked or stalled, else Vector3.INF. `home_leg`
## picks the walk-home state over the chase one. Think rate only.
func _nav_point(home_leg: bool, goal: Vector3, moving: bool) -> Vector3:
	if not NavAssist.ready():
		return Vector3.INF
	var nav := _nav_home if home_leg else _nav
	if nav == null:
		nav = NavAssist.new()
		if home_leg:
			_nav_home = nav
		else:
			_nav = nav
	var dt := 1.0 / think_hz
	nav.watch(global_position, dt, walk_speed, moving)
	var up := Vector3.UP * 1.2
	var blocked := NavAssist.line_blocked(get_world_3d().direct_space_state, global_position + up, goal + up, get_rid())
	var corner := nav.next_point(global_position, goal, blocked, dt)
	if corner != Vector3.INF:
		# a corner that lies the way the goal does (the mesh's path is cut into short collinear steps) adds
		# nothing to flat steering, and flat steering keeps the local wall-following's side memory. Only a
		# real bend steers: that is where the straight line fails.
		var to_goal := Vector2(goal.x - global_position.x, goal.z - global_position.z)
		var to_corner := Vector2(corner.x - global_position.x, corner.z - global_position.z)
		if to_goal.length_squared() < 0.01 or to_corner.length_squared() < 0.01 or to_goal.normalized().dot(to_corner.normalized()) > 0.94:
			return Vector3.INF
	if corner != Vector3.INF:
		# an inner corner: the first 2 m towards it must be open too (a wall that grew since the bake lies
		# across the mesh's path; stopping short of the corner, which hugs a static wall by the agent radius)
		var d := corner - global_position
		d.y = 0.0
		var reach := minf(d.length() - 0.8, 2.0)
		if reach > 0.3 and NavAssist.line_blocked(get_world_3d().direct_space_state, global_position + up, global_position + up + d.normalized() * reach, get_rid()):
			return Vector3.INF
	return corner


## Walking home (leash, evade): the way back, round walls when the straight line is walled.
func _home_dir() -> Vector3:
	var back := home - global_position
	back.y = 0.0
	if back.length() > 3.0:
		var corner := _nav_point(true, home, true)
		if corner != Vector3.INF:
			back = corner - global_position
			back.y = 0.0
	elif _nav_home != null:
		_nav_home.reset()
	return back.normalized() if back.length_squared() > 0.0001 else Vector3.ZERO


## The first wall within `reach` along `dir` at hip height, or {} (a slope underfoot is not a wall).
func _probe(space: PhysicsDirectSpaceState3D, from: Vector3, dir: Vector3, reach: float) -> Dictionary:
	if reach <= 0.2:
		return {}
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * reach, Layers.WORLD | Layers.PROPS)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty() or absf((hit.normal as Vector3).y) > 0.6:
		return {}
	return hit


## Spitters kite instead of closing in; they override this to keep their own _wish.
func _chases_directly() -> bool:
	return true


## Light makes them slink, it does not freeze them. Sanctuary / river zones used to pin Wretches.
func _aim_at_player() -> void:
	if _p == null or _dist < 0.05:
		_wish = Vector3.ZERO
		return
	_wish = _to / _dist
	if _dist > 2.5:
		_wish = _wish.rotated(Vector3.UP, _flank * clampf((_dist - 2.5) / 6.0, 0.0, 1.0))
		if _detour != Vector3.ZERO:
			_wish = _detour                      # the straight line is walled: round the obstacle
	elif _dist < strike_range * 0.6:
		_wish = -_wish * 0.6                     # too close (they don't collide with the player): give room
	if light_averse and LightGrid.is_lit(global_position):
		_wish *= 0.45


func _think() -> void:
	_update_separation()
	_update_detour()
	if _p != null and LightGrid.is_lit(_p.global_position, _wardproof()):
		_lit_t += 1.0 / think_hz
	else:
		_lit_t = 0.0
	if _p == null:
		_hold_post(_home_planar())
		return
	var player := _p
	var to := _to
	var dist := _dist
	var from_home := _home_planar()
	match _state:
		IDLE:
			_calm_t = maxf(0.0, _calm_t - 1.0 / think_hz)
			if dist <= chase_range and _calm_t <= 0.0 and _lit_t <= 0.0:
				_aim_at_player()
				_set_state(CALL if _should_call() else CHASE)
			elif role == &"guard" and is_instance_valid(_ward_ally) and _ward_ally._state != IDLE and dist <= chase_range * 2.0 and _calm_t <= 0.0:
				_set_state(CHASE)                 # its caster is fighting: the guard goes to it
			else:
				_hold_post(from_home)
		CALL:
			_wish = Vector3.ZERO
			_face_dir = to / maxf(dist, 0.001)
			if _state_t >= 0.85:
				_set_state(CHASE)
		FEINT:
			_wish = Vector3.ZERO
			_face_dir = to / maxf(dist, 0.001)
			if dist > strike_range + 2.0:
				_set_state(CHASE)
			elif _state_t >= 0.3:
				_begin_windup(false)
		SPECIAL:
			_special_think()
		CHASE:
			_guarding = false
			if _flee_t > 0.0 and dist < chase_range * 1.5:
				_flee_from(to, dist)
			elif _regroup_t > 0.0:
				_regroup_move(to, dist)
			elif _shaken_t > 0.0:
				_wish = -to / maxf(dist, 0.001)
			elif _lit_t > 2.5 and _ward_lit() and dist <= chase_range * 1.2 and from_home <= hunt_leash * 1.5:
				# a planted ward is a siege, not a sanctuary: they wait at its edge for it to fade
				_waiting = true
				_circle(dist)
			elif dist > chase_range * (4.0 if _hunt_t > 0.0 else (2.0 if _ward_engaged() or _rally_t > 0.0 else 1.2)) \
					or from_home > hunt_leash * (3.0 if _hunt_t > 0.0 else (1.5 if _rally_t > 0.0 else 1.0)) or _lit_t > 2.5:
				# out of range, leashed, or the player is sheltering in light: walk home and stay calm
				# a while, instead of re-aggroing next tick and milling at the light's edge
				_calm_t = 3.5 if _lit_t > 2.5 else 0.8
				_set_state(IDLE)
				_hold_post(from_home)
			elif not boss and _try_special(dist):
				_waiting = false
			elif role == &"guard" and _guard():
				_guarding = true
			elif dist <= strike_range and _take_token():
				_waiting = false
				_face_dir = to / maxf(dist, 0.001)
				if feint_chance > 0.0 and not _feinted and randf() < feint_chance:
					_feinted = true
					_set_state(FEINT)
				else:
					_begin_windup(true)
			elif not boss and dist <= _wait_ring() + 1.2 and not _has_token() and _pool_full():
				_waiting = true
				_circle(dist)
			elif leaper and _leap_cd <= 0.0 and is_on_floor() and dist >= leap_min and dist <= leap_max and _lit_t <= 0.0 and _strike_clear(player) and _take_token():
				_face_dir = to / maxf(dist, 0.001)
				_set_state(LEAP_PREP)
			else:
				_waiting = false
				_aim_at_player()
		LEAP_PREP:
			_wish = Vector3.ZERO
			if dist > leap_max + 3.0:
				_set_state(CHASE)
			elif _state_t >= leap_prep:
				_pounce(player)
		AIRBORNE:
			pass
		WINDUP:
			_wish = Vector3.ZERO
			_face_dir = to / maxf(dist, 0.001)
			if dist > strike_range + 2.0:
				_set_state(CHASE)
			elif _state_t >= _cur_windup:
				_set_state(STRIKE)
		STRIKE:
			_wish = Vector3.ZERO
			if _struck and _state_t >= 0.22:
				if _combo_left > 0 and dist <= strike_range + 1.2 and _lit_t <= 0.0:
					# the chain: the next blow gets its own (shorter) rear and its own cone
					_combo_left -= 1
					_cur_windup = combo_windup
					_face_dir = to / maxf(dist, 0.001)
					_set_state(WINDUP)
				else:
					_set_state(RECOVER)
		RECOVER:
			_wish = Vector3.ZERO
			_feinted = false
			if _state_t >= recover_time:
				_set_state(CHASE if dist <= chase_range and from_home <= hunt_leash else IDLE)


func _move(delta: float) -> void:
	_state_t += delta
	if not is_on_floor():
		velocity.y -= gravity * delta
	if _ballistic:
		_move_ballistic(delta)
		return
	var pace := walk_speed * (1.15 if _rally_t > 0.0 else 1.0) * (1.1 if _flee_t > 0.0 else 1.0) * (EVADE_PACE if _evading else 1.0)
	var steer := _wish * pace
	if _state == SPECIAL:
		velocity.x = _drive.x + _knock.x
		velocity.z = _drive.z + _knock.z
		_knock = _knock.move_toward(Vector3.ZERO, delta * 14.0)
		_light_barrier(delta)
		move_and_slide()
		_turn_toward(_drive if _drive.length_squared() > 1.0 else _face_dir, delta)
		if _rig:
			_animate_rig(is_on_floor(), delta)
		return
	if _state == WINDUP or _state == STRIKE or _state == RECOVER or _state == FEINT or _state == CALL:
		steer = Vector3.ZERO
		_stuck_t = 0.0
	elif _state == CHASE and is_on_floor() and _wish.length_squared() > 0.12:
		var flat := Vector3(velocity.x, 0.0, velocity.z)
		var dist := _dist
		if crawler and _hop_cd <= 0.0 and dist > 1.6:
			# Skittering hop that actually covers ground: ballistic, momentum kept in the air.
			var hop := minf(dist - 0.9, hop_len)
			launch_at(LightGrid.outside(global_position + _wish * hop, LIGHT_MARGIN, _wardproof()), 0.55)
			_hop_cd = 0.75
			_move_ballistic(delta)
			return
		elif flat.length() < 0.28:
			_stuck_t += delta
			if _stuck_t > 0.22:
				var side := Vector3(-_wish.z, 0.0, _wish.x)
				if int(_stuck_t * 3.0) % 2 == 1:
					side = -side
				steer = (_wish * 0.4 + side).normalized() * walk_speed
				if is_on_floor():
					velocity.y = 2.2
		else:
			_stuck_t = 0.0
	else:
		_stuck_t = 0.0
	if steer.length_squared() > 0.01:
		steer += _sep * walk_speed
	velocity.x = steer.x + _knock.x
	velocity.z = steer.z + _knock.z
	_knock = _knock.move_toward(Vector3.ZERO, delta * 14.0)
	_light_barrier(delta)
	if _at_rest():
		_rest_frames += 1
	else:
		_rest_frames = 0
	# standing still on the floor: move_and_slide would test the same contact and change nothing
	# (it was ~40% of an awake enemy's cost; most awake ones idle at their posts). Still run every
	# REST_CHECK frames so ground that goes away is noticed.
	if _rest_frames < 2 or _rest_frames % REST_CHECK == 0:
		move_and_slide()
		_rest_pos = global_position
	_turn_toward(_face_dir if _waiting or _wish.length_squared() <= 0.0025 else _wish, delta)
	if _rig:
		_animate_rig(is_on_floor(), delta)


const REST_CHECK := 8
var _rest_frames := 0
var _rest_pos := Vector3.INF          # where the last move_and_slide left it (a teleport breaks the rest)


func _at_rest() -> bool:
	return velocity == Vector3.ZERO and global_position == _rest_pos and is_on_floor() and get_platform_velocity() == Vector3.ZERO \
		and get_real_velocity().length_squared() < 1e-8


## The rig's pose (r30): every tick within `full` metres; further out, to 46 m (sleep range), every
## other tick on the enemy's own phase, with the time it skipped. It used to stop past 16 m, so a
## pack running in from 16-46 m slid along as statues. The joints are plain Node3Ds under physics
## interpolation, so 30 Hz there reads as a slightly coarser stride, never a frozen one.
var _anim_dt := 0.0


func _animate_rig(on_floor: bool, delta: float, full := 16.0) -> void:
	_anim_dt = minf(_anim_dt + delta, 0.1)
	if _dist >= full and (_dist > 46.0 or (Engine.get_physics_frames() + get_instance_id()) % 2 != 0):
		return
	_rig.animate(velocity, on_floor, _anim_dt)
	_anim_dt = 0.0


## Airborne: keep the launch momentum (the old code rewrote x/z to walk speed every frame,
## which is why leaps went up instead of across). A pounce lands one strike in flight.
func _move_ballistic(delta: float) -> void:
	_air_t += delta
	velocity.x += _knock.x * delta * 4.0
	velocity.z += _knock.z * delta * 4.0
	_knock = _knock.move_toward(Vector3.ZERO, delta * 14.0)
	_light_barrier(delta)
	move_and_slide()
	if is_on_wall():
		velocity.x *= 0.25
		velocity.z *= 0.25
	if _state == AIRBORNE and not _pounced and _p != null:
		var reach := _p.global_position - global_position
		if reach.length_squared() < 1.7 * 1.7:
			_pounced = true
			if _p.is_evading():
				_p.on_evaded(self)
			else:
				_p.take_wound(strike_gloom * dmg_mult, global_position)
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	_turn_toward(flat if flat.length_squared() > 0.25 else _face_dir, delta)
	if _rig:
		_animate_rig(false, delta, 24.0)
	if _air_t > 0.12 and is_on_floor():
		_ballistic = false
		velocity.x *= 0.2
		velocity.z *= 0.2
		_squash = 0.28
		if _state == AIRBORNE:
			_set_state(RECOVER)
			_state_t = -0.3        # longer stagger after a pounce: the punish window


func _pounce(player: Player) -> void:
	var dy := player.global_position.y - global_position.y
	var t := flight_time(leap_apex, dy)
	var pv := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var target := player.global_position + pv * t * leap_lead
	var flat := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	if flat.length() > leap_max + 1.5:
		flat = flat.normalized() * (leap_max + 1.5)
	target = Vector3(global_position.x + flat.x, player.global_position.y, global_position.z + flat.z)
	launch_at(LightGrid.outside(target, LIGHT_MARGIN, _wardproof()), leap_apex)
	Sfx.play(SFX_SHRIEK, global_position, -4.0)
	_leap_cd = leap_cooldown
	_set_state(AIRBORNE)


## Lit braziers and wards are hard sanctuaries: strip any velocity that points into a zone and
## push out if already inside (knockback, a ward planted on top of them, a brazier just lit).
## r30: bosses and elites respect fires, not the wanderer's own Lantern Ward (it was 7 s of boss
## immunity in every 24). Lesser foes still siege its edge.
func _wardproof() -> bool:
	return boss or has_meta(&"elite_id") or has_meta(&"guardian_id")


func _light_barrier(delta: float) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var wp := _wardproof()
	var ahead := LightGrid.repel(global_position + flat * delta, LIGHT_MARGIN, wp)
	if ahead == Vector3.ZERO:
		return
	var n := ahead.normalized()
	var inward := flat.dot(-n)
	if inward > 0.0:
		flat += n * inward
	var inside := LightGrid.repel(global_position, LIGHT_MARGIN, wp)
	if inside != Vector3.ZERO:
		flat += inside.normalized() * minf(inside.length() * 10.0, 7.0)
		if _ballistic:
			_ballistic = false            # slammed into the light mid-air: drop out of the pounce
			if _state == AIRBORNE:
				_set_state(RECOVER)
	velocity.x = flat.x
	velocity.z = flat.z


## Smoothed like Player.visual so the rig's turn lean and cloth swing see a real turn rate.
func _turn_toward(dir: Vector3, delta: float) -> void:
	if _face == null or dir.length_squared() < 0.0025:
		return
	_face.rotation.y = lerp_angle(_face.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-turn_rate * delta))


func _set_state(next: int) -> void:
	var was := _state
	_state = next
	_state_t = 0.0
	if casting() and _cast_bound >= 0 and next != _cast_bound:
		_finish_cast(_cast_cut or cast_elapsed < cast_time - 0.12)
	_cast_cut = false
	if not boss and not _evading:
		if next == IDLE and was != IDLE and was != DEAD and _lit_t <= 2.5 and _leashed():
			_begin_evade()                      # r33: out of the fight away from a fire: leash and reset
		elif was == IDLE and (next == CHASE or next == CALL):
			_pull_pack()                        # r33: a pull is the whole camp
	if (next == WINDUP or next == LEAP_PREP) and _dist < 6.0 and _p != null and not Hints.seen(&"break_windup"):
		Hints.once(&"break_windup", "A blow of 2 or more breaks a red tell at once: the Lash, the Lance, the staff's last swing. A lighter blow breaks it only when the foe's poise fills. On a great one the Lash is chipped under that line; the Lance and the last swing still clear it.")
	if next != CHASE:
		_waiting = false
	if not (next == WINDUP or next == STRIKE or next == LEAP_PREP or next == AIRBORNE or next == FEINT or next == SPECIAL):
		_release_token()
	if was == WINDUP and next != STRIKE and is_instance_valid(_danger):
		_danger.queue_free()                    # cancelled (staggered, out of reach): no false tell
	if next == WINDUP and was != STRIKE:
		_cur_windup = windup_time               # only a chained blow (STRIKE -> WINDUP) is shorter
	_on_state(next)


## Hook for subclasses. Default: the windup telegraph -- the rig rears up (or coils), the eyes
## flare, a growl, and the strike cone fills on the ground for exactly the windup -- then the rake.
func _on_state(next: int) -> void:
	if next == CALL:
		_call_pack()
		return
	if next == FEINT:
		# the same rear-up, cut short, and no red: the bait
		if _rig and _rig.has_method("telegraph"):
			_rig.call("telegraph", 0.3)
		_glint = 0.6
		Sfx.play_stream(Synth.voice(voice_family(), "tell"), global_position + Vector3.UP, -4.0, _voice_pitch() * 1.1)
		return
	if next == WINDUP or next == LEAP_PREP:
		var life := _cur_windup if next == WINDUP else leap_prep
		if _rig:
			if _rig.has_method("telegraph"):
				_rig.call("telegraph", life)
			else:
				_rig.cast()
		_glint = 1.0
		Sfx.play_stream(Synth.voice(voice_family(), "tell"), global_position + Vector3.UP, -1.0, _voice_pitch() * clampf(0.5 / maxf(life, 0.2), 0.8, 1.5))
		if next == WINDUP:
			_struck = false
			var reach := strike_range + 0.45
			_danger = SpellFx.danger(Vector3.ZERO, life, {"radius": reach, "half_angle": deg_to_rad(strike_arc), "parent": self, "yaw": _face.rotation.y if _face else 0.0})
		elif _p != null:
			# a pounce: the red fills under YOU (where it will come down if you stay)
			_danger = SpellFx.danger(_p.global_position, life, {"radius": 1.5})
	elif next == STRIKE:
		if _rig and _rig.has_method("strike"):
			_rig.call("strike")
		if _face_dir.length_squared() > 0.01:
			# lunge, but stop short of the player (bodies don't collide with them: a full lunge
			# from close in would carry it straight through and out the other side)
			var room := maxf(0.0, _dist - strike_range * 0.55)
			var go := Vector3(_face_dir.x, 0.0, _face_dir.z).normalized() * minf(lunge, sqrt(2.0 * 14.0 * room))
			if _knock.length() < 1.0:
				_knock = go                         # a blow that just landed keeps its knockback
		_swipe_fx()


## Pitch of this kind's voice (small things higher, bosses lower).
func _voice_pitch() -> float:
	return clampf(1.9 / maxf(hp_bar_y, 0.6), 0.6, 1.8) * (0.6 if boss else 1.0)


## Into a real windup (from the chase or after a feint): full tell, maybe the start of a chain.
func _begin_windup(fresh: bool) -> void:
	_cur_windup = windup_time
	if fresh:
		_combo_left = combo_max if combo_max > 0 and randf() < combo_chance else 0
	_set_state(WINDUP)


## Hook: a kind's own move. Return true if it started one (it sets SPECIAL itself).
func _try_special(_d: float) -> bool:
	return false


## Hook: drives a SPECIAL each think (subclasses).
func _special_think() -> void:
	_set_state(RECOVER)


## Hook: per physics frame while in SPECIAL (contact checks for a charge, a spin).
func _special_frame(_delta: float) -> void:
	pass


func untrack_move(mi: MeshInstance3D) -> void:
	_moves.erase(mi)


func _wait_ring() -> float:
	return WAIT_RING + (1.6 if _wary_t > 0.0 else 0.0)


## A guard whose caster is fighting stays with it even when you are past its own chase range.
func _ward_engaged() -> bool:
	return role == &"guard" and is_instance_valid(_ward_ally) and _ward_ally.is_alive() and _ward_ally._state != IDLE


## Is the player standing in a planted Lantern Ward (temporary light) rather than a fire?
func _ward_lit() -> bool:
	if _p == null:
		return false
	for w in get_tree().get_nodes_in_group(&"lantern_ward"):
		if w is Node3D and (w as Node3D).global_position.distance_to(_p.global_position) < 7.5:
			return true
	return false


## Falling back: away from you, toward the nearest packmate (behind it if it can).
func _flee_from(to: Vector3, dist: float) -> void:
	var away := -to / maxf(dist, 0.001)
	if is_instance_valid(_shield_ally) and _shield_ally != self:
		var behind := _shield_ally.global_position - to.normalized() * 2.5 - global_position
		behind.y = 0.0
		if behind.length() > 0.5:
			away = (away + behind.normalized()).normalized()
	_wish = away
	_face_dir = to / maxf(dist, 0.001)


## A guard with a caster behind it: stand on the line between you and the caster, facing you,
## until you come close (then it fights) or reach the caster.
func _guard() -> bool:
	if not is_instance_valid(_ward_ally) or not _ward_ally.is_alive() or _p == null:
		return false
	var ally := _ward_ally.global_position
	var pp := _p.global_position
	var ally_to_p := pp - ally
	ally_to_p.y = 0.0
	if _dist < 4.5 or ally_to_p.length() < 4.0 or ally_to_p.length() > 16.0:
		return false
	var spot := ally + ally_to_p.normalized() * minf(3.2, ally_to_p.length() * 0.5)
	var go := spot - global_position
	go.y = 0.0
	_wish = go.normalized() * clampf(go.length() / 1.5, 0.0, 1.0) if go.length() > 0.4 else Vector3.ZERO
	_face_dir = _to / maxf(_dist, 0.001)
	_waiting = true
	return true


## The first of a pack to see you calls the rest (if anyone near is still unaware, and no call
## went up near here lately).
func _should_call() -> bool:
	if not can_call or boss or _p == null or has_meta(&"enc_hunter"):
		return false
	var now := Time.get_ticks_msec()
	var keep: Array = []
	for a: Array in _alarms:
		if now - int(a[1]) < 9000:
			keep.append(a)
	_alarms = keep
	for a: Array in _alarms:
		if (a[0] as Vector3).distance_to(global_position) < ALARM_R:
			return false
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		if node != self and node is Enemy and (node as Enemy)._state == IDLE and (node as Enemy).global_position.distance_to(global_position) < ALARM_R:
			return true
	return false


func _call_pack() -> void:
	_alarms.append([global_position, Time.get_ticks_msec()])
	_rally_t = 4.0
	_glint = 1.0
	if _rig and _rig.has_method("howl"):
		_rig.call("howl", 0.8)
	Sfx.play_stream(Synth.voice(voice_family(), "call"), global_position + Vector3.UP * 1.4, 0.0, _voice_pitch())
	Vfx.ring(global_position + Vector3.UP * (hp_bar_y * 0.8), 1.2, Color(1.4, 0.5, 0.3), 0.6, 0.05, Vector3.UP, 0.8)
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		if node != self and node is Enemy and (node as Enemy).global_position.distance_to(global_position) < ALARM_R:
			(node as Enemy).alerted(self)


## The strike lands at the end of the rake's first beat: in reach, inside the cone, in sight.
## A Rift Step through it is a riposte; stepping back out of the cone is a clean dodge.
func _resolve_strike() -> void:
	_struck = true
	if _p == null or not is_instance_valid(_p):
		return
	var to := _p.global_position - global_position
	var dy := to.y
	to.y = 0.0
	var d := to.length()
	var fwd := _face_dir if _face_dir.length_squared() > 0.01 else (to / maxf(d, 0.001))
	var in_cone := d < 0.6 or fwd.normalized().dot(to / maxf(d, 0.001)) >= cos(deg_to_rad(strike_arc))
	if d <= strike_range + 0.45 and in_cone and absf(dy) < 1.8 and _strike_clear(_p):
		if _p.is_evading():
			_p.on_evaded(self)
		else:
			_p.take_wound(strike_gloom * dmg_mult, global_position)
			Vfx.burst(_p.global_position + Vector3.UP * 1.1, Color(0.9, 0.12, 0.1), {"count": 12, "life": 0.3, "speed": Vector2(2.0, 4.0), "size": 0.04, "gravity": -4.0, "trail": 0.06})


## A claw-rake arc in front at the moment of the strike, so a whiff reads as a whiff.
func _swipe_fx() -> void:
	var fwd := _face_dir if _face_dir.length_squared() > 0.01 else -global_basis.z
	fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
	var side := fwd.cross(Vector3.UP)
	var c := global_position + Vector3.UP * (hp_bar_y * 0.5)
	var r := strike_range * 0.85
	var pts := PackedVector3Array()
	for i in 9:
		var a := lerpf(-deg_to_rad(strike_arc) * 0.8, deg_to_rad(strike_arc) * 0.8, float(i) / 8.0)
		pts.append(c + (fwd * cos(a) + side * sin(a)) * r + Vector3.UP * (0.45 - 0.9 * float(i) / 8.0) * (hp_bar_y * 0.25))
	Vfx.ribbon(pts, 0.03, 0.16, Color(1.8, 0.62, 0.18, 0.8), 0.18)


# --- attack tokens ------------------------------------------------------------------------------

func _has_token() -> bool:
	return _tokens.has(get_instance_id())


func _take_token() -> bool:
	if boss or _has_token():
		return true
	if _held(token_pool) >= pool_max:
		return false
	_tokens[get_instance_id()] = token_pool
	return true


## Live holders of a token pool (melee: MAX_ATTACKERS at once; a swarm has its own pool).
func _held(pool: StringName) -> int:
	var held := 0
	for id: int in _tokens.keys():
		var o := instance_from_id(id) as Enemy
		if o == null or not is_instance_valid(o) or not o.is_inside_tree() or o._state == DEAD:
			_tokens.erase(id)
		elif StringName(_tokens[id]) == pool:
			held += 1
	return held


func _pool_full() -> bool:
	return _held(token_pool) >= pool_max


func _release_token() -> void:
	_tokens.erase(get_instance_id())


## Waiting for an opening: circle the player at WAIT_RING, drifting round (and switching
## direction now and then), so the pack surrounds you instead of queueing behind the attacker.
func _circle(dist: float) -> void:
	if _p == null or dist < 0.05:
		_wish = Vector3.ZERO
		return
	var dir := _to / dist
	var ring := _wait_ring()
	var drift := 0.75
	if role == &"flanker":
		# work round to your side (not behind: the camera could not show it), where the screen
		# edge and the growl still tell you it is there
		var fwd := Basis(Vector3.UP, _p._yaw) * Vector3.FORWARD
		var bearing := -dir
		var side := signf(fwd.cross(bearing).y)
		if side == 0.0:
			side = 1.0
		var want := fwd.rotated(Vector3.UP, side * deg_to_rad(80.0))
		var tgt := _p.global_position + want * ring
		var tangent0 := Vector3(-dir.z, 0.0, dir.x)
		_orbit = 1.0 if tangent0.dot(tgt - global_position) >= 0.0 else -1.0
		drift = 0.15 if bearing.dot(want) > 0.93 else 0.9
	elif randf() < 0.02:
		_orbit = -_orbit
	var tangent := Vector3(-dir.z, 0.0, dir.x) * _orbit
	var radial := clampf((dist - ring) * 0.9, -1.0, 1.0)
	_wish = (tangent * drift + dir * radial).normalized() * 0.7
	_face_dir = dir


func _exit_tree() -> void:
	_finish_cast(true, false)                    # r33: a cast bar never outlives its caster
	_release_token()
	cancel_moves()                               # reset, unmade or unloaded: nothing of its lands later


## Base windups end on the physics frame the tell's time is up (the red fill and the blow agree to
## the frame). Kinds whose WINDUP means something else (a spit, a sigil) keep it in their _think.
func _exact_windup() -> bool:
	return true


## Hauled through the air (Rift Tether): whatever it was winding up or running is broken, so it
## cannot land at your feet mid-tell with a red that filled somewhere else. It arrives off balance.
func hauled() -> void:
	if _state == DEAD:
		return
	cancel_moves()
	_combo_left = 0
	_cast_cut = true
	_ballistic = false
	_drive = Vector3.ZERO
	if is_instance_valid(_danger):
		_danger.queue_free()
	if _state != IDLE:
		_set_state(RECOVER)
		_state_t = recover_time - 0.45           # 0.45 s off balance once it lands


func _die() -> void:
	_finish_cast(true, false)
	_evading = false
	_state = DEAD
	_dying = 0.0
	_release_token()
	cancel_moves()
	_shroud_t = 0.0
	if is_instance_valid(_danger):
		_danger.queue_free()
	# the killing blow throws the body: harder for a heavy one (a Lance), up off its feet
	var big := _last_dmg >= 3.0
	if _last_from != Vector3.ZERO:
		_knock = _last_from * (6.5 if big else 3.2) / maxf(mass, 0.4) * (0.35 if boss else 1.0)
		if mass < 0.6:
			_knock = _knock.limit_length(4.5)        # a light body folds where it died, in frame
		if big and not boss:
			velocity.y = 3.2
	Sfx.play_stream(Synth.voice(voice_family(), "die"), global_position + Vector3.UP * hp_bar_y * 0.7, -2.0 if boss else -4.0, _voice_pitch())
	if not boss and _allies >= 1:
		_final_blow_check()
		_tell_fallen()
	if _weak:
		_weak.visible = false
	if _rig and _rig.has_method("collapse"):
		_rig.call("collapse")
	_wish = Vector3.ZERO
	collision_layer = 0
	if _hp_bar:
		_hp_bar.visible = false
	for pip in _pips:
		pip.visible = false
	Events.enemy_killed.emit(self)
	var at := global_position + Vector3.UP * (hp_bar_y * 0.5)
	Sfx.play(SFX_DIE, at, -6.0)
	Vfx.burst(at, Color(0.03, 0.02, 0.05, 0.8), {"count": 26, "life": 1.4, "speed": Vector2(0.3, 1.4), "size": 0.32, "gravity": 0.9, "radius": 0.45, "additive": false, "turbulence": true})
	Vfx.burst(at, Color(1.2, 0.45, 2.4), {"count": 30, "life": 1.1, "speed": Vector2(0.5, 2.2), "size": 0.05, "gravity": 1.4, "radius": 0.5, "turbulence": true})
	Vfx.light(at, Color(0.7, 0.4, 1.0), 2.2, 4.0, 0.6)
	Vfx.burst(at, _ichor(), {"count": 24, "life": 0.8, "speed": Vector2(2.0, 5.0), "size": 0.09, "gravity": -9.5, "additive": false})
	Vfx.scorch(global_position, 0.6 + hp_bar_y * 0.35, Color(0.5, 0.2, 0.9), 4.0)    # the stain it leaves
	# the body folds first (HunchRig/QuadRig collapse), then burns away
	var tw := create_tween()
	tw.tween_interval(0.65)                       # the fold is near done before the burn
	tw.tween_method(_set_dissolve, 0.0, 1.0, 0.95)
	tw.tween_callback(queue_free)


## The last of a pack falls: a short slow beat and a camera punch (not on top of a riposte's).
func _final_blow_check() -> void:
	var p := _player()
	if p == null or global_position.distance_to(p.global_position) > 16.0 or TimeSlow.active():
		return
	for node in get_tree().get_nodes_in_group(Groups.ENEMY) + get_tree().get_nodes_in_group(&"burrowed"):
		if node != self and node is Enemy and (node as Enemy).is_alive() and (node as Enemy)._state != IDLE \
				and (node as Enemy).global_position.distance_to(p.global_position) < 18.0:
			return
	p.kick(0.7)
	Vfx.ring(global_position + Vector3.UP * 0.2, 2.2, Color(1.3, 0.6, 2.6), 0.5, 0.08, Vector3.UP, 1.2)
	HitText.pop(global_position + Vector3.UP * (hp_bar_y + 0.6), "the pack is broken", Color(1.1, 0.7, 2.2), true)
	TimeSlow.request(get_tree(), 0.3, 0.16)


## Dead: keep the rig folding and the body settling to the ground while it dissolves.
## The crunch of a landed hit: a frozen shudder, scaled to the body (capped near 8 cm times its scale).
func _shudder() -> void:
	if _visual == null:
		return
	if _hitstop == 0:
		_visual.position = Vector3.ZERO
		return
	var k := maxf(_rig.scale.x, 1.0) if _rig != null else 1.0
	var v := Vector3(randf_range(-1.0, 1.0), randf_range(-0.4, 0.4), randf_range(-1.0, 1.0)) * 0.035 * float(_hitstop)
	_visual.position = v.limit_length(0.08) * k


func _tick_dying(delta: float) -> void:
	if _hitstop > 0:                             # the killing blow freezes and shudders like any other
		_hitstop -= 1
		_shudder()
		return
	_dying += delta
	if _visual:
		_visual.position = Vector3.ZERO
	if not is_on_floor():
		velocity.y -= gravity * delta
	velocity.x = _knock.x
	velocity.z = _knock.z
	_knock = _knock.move_toward(Vector3.ZERO, delta * 10.0)
	move_and_slide()
	if _rig and _dying < 1.4:
		_rig.animate(Vector3.ZERO, true, delta)


func _set_dissolve(v: float) -> void:
	_dissolve = v
	_flesh_param(&"dissolve", v)


func _strike_clear(player: Player) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return true
	var from := global_position + Vector3.UP * 1.1
	var to := player.global_position + Vector3.UP * 1.1
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = Layers.WORLD
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	return hit.is_empty()


func _flash_visual(delta: float) -> void:
	if _visual == null:
		return
	_flash = maxf(0.0, _flash - delta)
	if _hit_fx > 0.0:
		_hit_fx = maxf(0.0, _hit_fx - delta * 7.0)
		_flesh_param(&"hit_flash", _hit_fx)
	if _glint > 0.0:
		_glint = maxf(0.0, _glint - delta * 1.6)
		_flesh_param(&"glint", _glint)
	var s := 1.0 + _flash * 0.4
	if _state == LEAP_PREP:
		_squash = move_toward(_squash, 0.24, delta * 0.9)    # coil: the tell before a pounce
	else:
		_squash = move_toward(_squash, 0.0, delta * 1.6)
	_visual.scale = Vector3(s * (1.0 + _squash * 0.45), s * (1.0 - _squash), s * (1.0 + _squash * 0.45))


func _hold_post(from_home: float) -> void:
	if not patrol.is_empty() and not _evading and _state == IDLE:
		_walk_patrol()
		return
	if home == Vector3.ZERO or from_home < 0.45:
		_wish = Vector3.ZERO
		return
	_wish = _home_dir()


func _home_planar() -> float:
	if home == Vector3.ZERO:
		return 0.0
	var d := home - global_position
	d.y = 0.0
	return d.length()


func _player() -> Player:
	if not is_instance_valid(_p):
		_p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	return _p


## Riposte: the player Rift-Stepped through this enemy's strike. Long stagger, no follow-up.
func riposted() -> void:
	if _state == DEAD:
		return
	if not boss:
		cancel_moves()
	_combo_left = 0
	_cast_cut = true
	_set_state(RECOVER)
	_state_t = -0.9
	if not boss:
		_broken_t = STAGGER_TIME + 0.5           # r31: a riposte opens the broken window too
	_knock = Vector3.ZERO
	if _rig and _rig.has_method("stagger"):
		_rig.call("stagger")


# --- r31: weak points, the poise meter, pack morale, the bell ---------------------------------------

## The weak point: a small glowing knot on `weak_socket` (a kind sets the socket and offset before
## _build ends). A kind may instead point `_weak` at a part it already has (the Spitter's sac).
func _make_weak() -> void:
	if weak_socket == "" or _rig == null or _weak != null:
		return
	var at := _rig.socket(weak_socket)
	if at == null:
		return
	if _weak_mesh == null:
		_weak_mesh = SphereMesh.new()
		_weak_mesh.radius = 1.0
		_weak_mesh.height = 2.0
		_weak_mesh.radial_segments = 14
		_weak_mesh.rings = 7
		_weak_mat = ProcMesh.glow_mat(WEAK_COL)
	var mi := MeshInstance3D.new()
	mi.name = "WeakPoint"
	mi.mesh = _weak_mesh
	mi.material_override = _weak_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = weak_offset
	mi.scale = Vector3.ONE * weak_r
	mi.visible = weak_open
	at.add_child(mi)
	_weak = mi


## Our own knot breathes (and hides while closed); a borrowed part (a sac) is left to its owner.
func _tick_weak() -> void:
	if not is_instance_valid(_weak) or _weak.name != "WeakPoint":
		return
	_weak.visible = weak_open and _state != DEAD
	if _weak.visible:
		_weak.scale = Vector3.ONE * weak_r * (1.0 + 0.14 * sin(float(Engine.get_physics_frames()) * 0.21 + float(get_instance_id() % 7)))


## Did this blow find the weak point? Projectiles only (a bolt bursting on or beside the knot):
## the Lash and the Step are the wanderer's own body, and the wanderer is not that precise.
func _weak_hit(from: Node) -> bool:
	if not is_instance_valid(_weak) or not weak_open or not _weak.is_visible_in_tree() or not (from is Node3D) or from is Player:
		return false
	var s := _weak.global_basis.get_scale().x if _weak.name == "WeakPoint" else weak_r * (_rig.scale.x if _rig else 1.0)
	return (from as Node3D).global_position.distance_to(_weak.global_position) <= s + 0.45


## Hook: a blow found the weak point (after damage rules). Default: a tell in progress breaks.
func _on_weak_hit(_dmg: float) -> void:
	if boss or _stagger_cd > 0.0:
		return
	if _state == WINDUP or _state == LEAP_PREP or _state == FEINT or (_state == SPECIAL and _special_breakable()):
		stagger()


func is_broken() -> bool:
	return _broken_t > 0.0


func _tick_bar_poise() -> void:
	var pr := clampf(_poise_dmg / maxf(poise, 0.01), 0.0, 1.0) if _stagger_cd <= 0.0 else 0.0
	var br := 1.0 if _broken_t > 0.0 else 0.0
	if absf(pr - _bar_poise) > 0.02 or br != _bar_broken:
		_bar_poise = pr
		_bar_broken = br
		_hp_bar.set_instance_shader_parameter(&"poise", pr)
		_hp_bar.set_instance_shader_parameter(&"broken", br)


## A packmate fell within 14 m: the survivors take note.
func _tell_fallen() -> void:
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		var en := node as Enemy
		if en != null and en != self and en.is_alive() and not en.boss and en.global_position.distance_squared_to(global_position) < 196.0:
			en._ally_fell()


## Two falls in a few seconds (each counts 1, draining at 0.12/s) and it pulls back to the pack's
## middle, on the far side from you, faces you there for REGROUP seconds, then comes again rallied.
## Not the hunters of a tide, the named, the guardians, a swarm or one already hurt into fleeing.
const REGROUP := 2.4


func _ally_fell() -> void:
	_fallen += 1.0
	if _fallen < 1.9 or _regrouped or _state != CHASE or _flee_t > 0.0 or role == &"swarm" or _p == null or _dist > 14.0 \
			or has_meta(&"enc_hunter") or has_meta(&"elite_id") or has_meta(&"guardian_id"):
		return
	var c := Vector3.ZERO
	var n := 0
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		var en := node as Enemy
		if en != null and en.is_alive() and not en.boss and en.global_position.distance_squared_to(global_position) < 196.0:
			c += en.global_position
			n += 1
	if n < 2:
		return                                    # nobody to regroup with: it fights on
	c /= float(n)
	var away := c - _p.global_position
	away.y = 0.0
	_regroup_at = c + (away.normalized() * 3.5 if away.length() > 0.1 else Vector3.ZERO)
	_regrouped = true
	_regroup_t = REGROUP
	_combo_left = 0
	_release_token()
	var now := Time.get_ticks_msec()
	for a: Array in _alarms:
		if now - int(a[1]) < 3000 and (a[0] as Vector3).distance_to(global_position) < ALARM_R:
			return
	_alarms.append([global_position, now])        # one of them howls the regroup
	if _rig and _rig.has_method("howl"):
		_rig.call("howl", 0.7)
	Sfx.play_stream(Synth.voice(voice_family(), "call"), global_position + Vector3.UP * 1.4, -2.0, _voice_pitch() * 0.9)
	HitText.pop(global_position + Vector3.UP * (hp_bar_y + 0.6), "they regroup", Color(1.0, 0.7, 0.45))


func _regroup_move(to: Vector3, dist: float) -> void:
	_waiting = true
	_face_dir = to / maxf(dist, 0.001)
	var go := _regroup_at - global_position
	go.y = 0.0
	_wish = go.normalized() * clampf(go.length() / 1.2, 0.0, 1.1) if go.length() > 0.6 else Vector3.ZERO
	if _regroup_t <= 1.0 / think_hz + 0.01:
		_rally_t = 6.0                            # and again, together, a little faster


func is_regrouping() -> bool:
	return _regroup_t > 0.0


## A Tollman's bell (or anything else that raises the dark): every one of ours within `r` of `at`
## wakes, comes for the wanderer and hunts past its leash for a while. Returns how many answered.
static func toll(tree: SceneTree, at: Vector3, r: float, by: Node = null) -> int:
	var n := 0
	for node in tree.get_nodes_in_group(Groups.ENEMY):
		var en := node as Enemy
		if en == null or en == by or not en.is_alive() or en.boss or en._evading or en.global_position.distance_to(at) > r:
			continue
		en.wake()
		en._calm_t = 0.0
		en._hunt_t = maxf(en._hunt_t, 14.0)
		en._rally_t = maxf(en._rally_t, 6.0)
		if en._state == IDLE:
			en._set_state(CHASE)
		n += 1
	return n


# --- r33: casts, interrupts, leash/evade, pulls, patrols and what the HUD reads --------------------

## Start a cast the HUD can show. `bound` (default): it lives in the current state and ends with it
## (interrupted if it was cut short); else it is timed and runs `done` when its clock is up.
func begin_cast(n: String, time: float, interruptible := true, bound := true, done := Callable()) -> void:
	if _state == DEAD:
		return
	if casting():
		if _cast_bound < 0 and bound:
			return                               # a boss's timed cast keeps the bar over a passing tell
		_finish_cast(false, false)
	cast_name = n
	cast_time = maxf(time, 0.05)
	cast_elapsed = 0.0
	cast_interruptible = interruptible
	_cast_bound = _state if bound else -1
	_cast_done = done
	_cast_cut = false
	cast_started.emit(n, cast_time, interruptible)
	if Events.has_signal(&"enemy_cast_started"):
		Events.emit_signal(&"enemy_cast_started", self, n, cast_time, interruptible)


func casting() -> bool:
	return cast_name != ""


func cast_progress() -> float:
	return clampf(cast_elapsed / maxf(cast_time, 0.001), 0.0, 1.0) if casting() else 0.0


func cast_info() -> Dictionary:
	if not casting():
		return {}
	return {"name": cast_name, "progress": cast_progress(), "time": cast_time,
		"left": maxf(0.0, cast_time - cast_elapsed), "interruptible": cast_interruptible}


## Can it start a cast now? (No for SILENCE seconds after one was interrupted.)
func can_cast() -> bool:
	return _silence_t <= 0.0 and not _evading


func _finish_cast(interrupted: bool, hooks := true) -> void:
	if not casting():
		return
	var n := cast_name
	var done := _cast_done
	cast_name = ""
	_cast_done = Callable()
	_cast_bound = -1
	cast_ended.emit(n, interrupted)
	if Events.has_signal(&"enemy_cast_ended"):
		Events.emit_signal(&"enemy_cast_ended", self, n, interrupted)
	if not hooks:
		return
	if interrupted:
		_on_cast_interrupted(n)
	elif done.is_valid():
		done.call()


func _tick_cast(delta: float) -> void:
	if not casting():
		return
	cast_elapsed += delta
	if _cast_bound < 0 and cast_elapsed >= cast_time:
		_finish_cast(false)


## Does this blow break the cast? A lesser foe's: any blow. A boss's: a heavy one or its weak point.
func _interrupts(dmg: float, from: Node, weak: bool) -> bool:
	if not boss:
		return true
	return weak or dmg >= INTERRUPT_DMG or (from is MagicBolt and (from as MagicBolt).heavy)


## Break the current cast if it can be broken. Returns true if one was.
func interrupt(_by: Node = null) -> bool:
	if not casting() or not cast_interruptible or _state == DEAD:
		return false
	var bound := _cast_bound >= 0
	var n := cast_name
	_silence_t = SILENCE
	HitText.pop(global_position + Vector3.UP * (hp_bar_y + 0.95), "interrupted", INTERRUPT_COL, true)
	Vfx.ring(global_position + Vector3.UP * (hp_bar_y * 0.6), 0.9 * maxf(hp_bar_y / 2.0, 0.6), INTERRUPT_COL, 0.3, 0.06, Vector3.UP, 1.0)
	Sfx.play_stream(Synth.get_stream("block"), global_position + Vector3.UP * hp_bar_y * 0.6, -2.0, 1.3 if not boss else 0.8)
	if bound:
		cancel_moves()                           # its working's tells fade with it
	var st := _state
	_finish_cast(true)
	if bound and _state == st and _state != DEAD:
		_set_state(RECOVER)
		_state_t = -0.4
	Hints.once(&"interrupt", "A foe's cast can be broken: any blow on a lesser caster; on a great one, the Lance, the knot, or a blow that still counts as 2 after the chip.")
	return n != ""


## Hook: a cast of this kind was interrupted (after the bar is gone).
func _on_cast_interrupted(_n: String) -> void:
	pass


func is_evading() -> bool:
	return _evading


## Dragged off its post (or outrun): walk home (r35: hittable, no heal there). Its pack resets with it.
func _begin_evade() -> void:
	if _evading or boss or home == Vector3.ZERO or _state == DEAD:
		return
	_evading = true
	_evade_t = 0.0
	_calm_t = maxf(_calm_t, 99.0)
	_finish_cast(true, false)
	cancel_moves()
	_release_token()
	_combo_left = 0
	_knock = Vector3.ZERO
	_rally_t = 0.0
	_hunt_t = 0.0
	_flee_t = 0.0
	_shaken_t = 0.0
	_regroup_t = 0.0
	_waiting = false
	marks = 0
	_refresh_pips()
	if is_instance_valid(_danger):
		_danger.queue_free()
	if _hp_ratio() < 0.999 or _home_planar() > 3.0:
		HitText.pop(global_position + Vector3.UP * (hp_bar_y + 0.4), "evade", EVADE_COL)
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		var en := node as Enemy
		if en == null or en == self or en.boss or en._evading or not en.is_alive() or en.home == Vector3.ZERO:
			continue
		# packmates out of the fight with it reset too (one still at your throat fights on)
		if en._state == IDLE or en.home.distance_squared_to(home) >= PACK_LINK * PACK_LINK or not en._leashed() \
				or en._hunt_t > 0.0:
			continue
		# r35: its own _dist is refreshed at think rate (10 Hz), so a leader evading between two of a
		# mate's thinks saw the mate still "near" a wanderer who had long gone, and the mate hunted on
		# alone (zz/enemies_r33 "its packmate resets with it"). Measure now.
		en._cache_player()
		if en._dist > en.chase_range:
			en._set_state(IDLE)                  # its _set_state starts its own evade


func _tick_evade(step: float) -> void:
	_evade_t += step
	var back := home - global_position
	back.y = 0.0
	if back.length() < 0.9 or _evade_t > EVADE_MAX:
		if back.length() >= 0.9:
			# boxed in or kept out by a light: it slips home through the dark
			SpellFx.rift_out(global_position)
			global_position = home + Vector3.UP * 0.05
			velocity = Vector3.ZERO
			reset_physics_interpolation()
			SpellFx.rift_in(home)
		_end_evade()
		return
	_wish = _home_dir()
	_face_dir = _wish


func _end_evade() -> void:
	_evading = false
	_wish = Vector3.ZERO
	_calm_t = 1.0
	_fled = false
	_feinted = false
	_regrouped = false
	_fallen = 0.0
	_poise_dmg = 0.0
	_broken_t = 0.0
	_shroud_t = 0.0
	# r35: no heal at home. A foe you hurt and left stays hurt (the critique's "solo bosses and foes":
	# a solo wanderer who kites is playing the game, not exploiting it)
	evaded.emit()


## The leash for kinds whose own think has none (or a long one): HARD_LEASH x hunt_leash from home.
func _leash_check() -> void:
	if _state == IDLE or _state == DEAD or _state == AIRBORNE or _hunt_t > 0.0 or not _leashed():
		return
	if _home_planar() > maxf(hunt_leash * HARD_LEASH, 24.0):
		_cast_cut = true
		_set_state(IDLE)


## A pull is the whole camp: packmates whose home is within PACK_LINK of ours come too.
func _pull_pack() -> void:
	if not _leashed():
		return
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		var en := node as Enemy
		if en == null or en == self or en.boss or en._evading or en._state != IDLE or en.home == Vector3.ZERO:
			continue
		if en.home.distance_squared_to(home) < PACK_LINK * PACK_LINK and en.process_mode != Node.PROCESS_MODE_DISABLED:
			en._hunt_t = maxf(en._hunt_t, _hunt_t)     # shot from afar: the whole camp hunts the shooter
			en.alerted(self)


## Bound to a home at all? Not bosses, a tide's hunters, or a boss's adds (meta "no_leash").
func _leashed() -> bool:
	return not boss and home != Vector3.ZERO and not has_meta(&"enc_hunter") and not has_meta(&"no_leash")


## A slow beat between its patrol points (rares), with a pause at each.
func _walk_patrol() -> void:
	var tgt := patrol[_patrol_i % patrol.size()]
	var go := tgt - global_position
	go.y = 0.0
	if go.length() < 0.8:
		_wish = Vector3.ZERO
		_patrol_wait += 1.0 / think_hz
		if _patrol_wait >= 2.5:
			_patrol_wait = 0.0
			_patrol_i = (_patrol_i + 1) % patrol.size()
		return
	var pace := 0.45 if patrol_speed <= 0.0 else clampf(patrol_speed / maxf(walk_speed, 0.1), 0.1, 1.0)
	_wish = go.normalized() * pace
	_face_dir = go.normalized()
	if roam:
		home = Vector3(global_position.x, global_position.y, global_position.z)


# --- what the HUD reads ---------------------------------------------------------------------------

func display_name() -> String:
	if has_meta(&"display_name"):
		return String(get_meta(&"display_name"))
	var s := String(name)
	if s.begins_with("@") or s == "":
		var sc := get_script() as Script
		s = sc.resource_path.get_file().get_basename().capitalize() if sc else "Hollowed"
		return s
	s = s.rstrip("0123456789")
	return s.capitalize()


func rank() -> String:
	if boss:
		return "boss"
	if has_meta(&"rare_id"):
		return "rare"
	if has_meta(&"elite_id") or has_meta(&"guardian_id"):
		return "elite"
	return "normal"


## A number to read, not a stat: the night's danger tier where it stands, its weight, its rank.
func level() -> int:
	if boss:
		return -1
	if has_meta(&"level"):
		return int(get_meta(&"level"))
	var lv := 1 + 2 * int(get_meta(&"enc_tier", 0)) + (1 if max_hp >= 4 else 0)
	match rank():
		"elite":
			lv += 2
		"rare":
			lv += 3
	return lv


func debuffs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if marks > 0:
		out.append({"id": "umbral_mark", "name": "Umbral Mark", "left": maxf(_mark_t, 0.0), "stacks": marks, "harmful": true})
	if _broken_t > 0.0:
		out.append({"id": "broken", "name": "Broken", "left": _broken_t, "stacks": 1, "harmful": true})
	var rec := _affliction()
	if not rec.is_empty():
		if float(rec.get("burn", 0.0)) > 0.0:
			out.append({"id": "burning", "name": "Burning", "left": float(rec.burn), "stacks": 1, "harmful": true})
		if float(rec.get("frozen", 0.0)) > 0.0:
			out.append({"id": "frozen", "name": "Frozen", "left": float(rec.frozen), "stacks": 1, "harmful": true})
		elif float(rec.get("chill", 0.0)) > 0.0:
			out.append({"id": "chilled", "name": "Chilled", "left": float(rec.chill), "stacks": maxi(int(rec.get("stacks", 1)), 1), "harmful": true})
		if float(rec.get("slow", 0.0)) > 0.0:
			out.append({"id": "slowed", "name": "Slowed", "left": float(rec.slow), "stacks": 1, "harmful": true})
	if _silence_t > 0.0:
		out.append({"id": "silenced", "name": "Interrupted", "left": _silence_t, "stacks": 1, "harmful": true})
	if _shroud_t > 0.0:
		out.append({"id": "shrouded", "name": "Shrouded", "left": _shroud_t, "stacks": 1, "harmful": false})
	if _ward_t > 0.0:
		out.append({"id": "warded", "name": "Warded", "left": _ward_t, "stacks": 1, "harmful": false})
	if dmg_mult > 1.001:
		out.append({"id": "enraged", "name": "Enraged", "left": -1.0, "stacks": 1, "harmful": false})
	var extra: Variant = get_meta(&"statuses") if has_meta(&"statuses") else null
	if extra is Array:
		for d: Variant in extra:
			if d is Dictionary:
				out.append(d)
	return out


## The record core/skills/afflict.gd keeps for it ({} when none). Read only: never creates one.
func _affliction() -> Dictionary:
	if _afflict == null:
		if not ResourceLoader.exists(AFFLICT_PATH):
			return {}
		_afflict = load(AFFLICT_PATH) as GDScript
	var mgr: Variant = _afflict.get("_inst") if _afflict else null
	if not (mgr is Node) or not is_instance_valid(mgr):
		return {}
	var recs: Variant = (mgr as Node).get("_rec")
	if not (recs is Dictionary):
		return {}
	var r: Variant = (recs as Dictionary).get(get_instance_id(), {})
	return r if r is Dictionary else {}


func ui_info() -> Dictionary:
	var d := {"name": display_name(), "rank": rank(), "level": level(), "hp": hp, "max_hp": float(max_hp),
		"cast": cast_info(), "debuffs": debuffs(), "evading": _evading, "alive": is_alive()}
	return d
