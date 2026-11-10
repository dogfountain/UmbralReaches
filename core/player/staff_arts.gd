extends Node
## Staff arts (r31): the wanderer's close-quarters kit, so a foe in your face is a fight and not a
## camera problem. Child of Player, named "StaffArts". Load by path (no class_name):
##   const StaffArts := preload("res://core/player/staff_arts.gd")
##
## LIGHT CHAIN  sweep, backhand, overhead slam. The slam is the finisher: a wider blow that takes
##              the foe's Umbral Marks for extra damage (RIFT CUDGEL). Every strike leaves a Mark, so
##              bolts at range and the staff up close feed the same Nova.
##              - the primary trigger (Rift Bolt) turns into the staff by itself when a foe stands
##                within CLOSE_R in front of you (or the lock target is within CLOSE_R + 0.8);
##              - the staff key (G / mouse 4) always strikes; hold it for a HEAVY.
##              Each strike steps you in to the target (LUNGE_MAX) and squares you up to it.
## HEAVY        hold the staff key: drawn back overhead, released into a ground-shaking slam that
##              staggers anything not a boss at full draw.
## GUARD        hold guard (X / mouse 5; pad: B while locked on, stick idle). The first PARRY_WIN
##              seconds of a guard PARRY: the blow is turned, the attacker reels (riposted) and is
##              Marked, Breath comes back, and the next strike or bolt is a riposte. After that the
##              guard BLOCKS what comes from the front: BLOCK_KEEP of the Gloom gets through and the
##              rest is paid in Breath; run dry and the guard breaks.
## A strike that lands holds the whole world still for a few frames (Player.hitstop).

const Combo := preload("res://core/skills/combo.gd")
const StaffSfx := preload("res://core/vfx/staff_sfx.gd")
const Stamina := preload("res://core/player/stamina.gd")
const Hints := preload("res://ui/hints.gd")

const CLOSE_R := 2.7             ## a foe this close in front makes the primary trigger a staff strike
const CLOSE_COS := 0.34          ## ...within ~70 degrees of where you look
const PICK_R := 3.6              ## the staff key looks this far for something to step into
const LUNGE_MAX := 1.7           ## a strike carries you at most this far toward its target
const STAND_OFF := 1.15          ## and stops this far short of it
const BUFFER := 0.32             ## a press this long before a strike ends queues the next
const CHAIN_GAP := 0.42          ## after a strike, this long to continue the chain
const HEAVY_HOLD := 0.36         ## hold the staff key past this to draw a heavy
const HEAVY_FULL := 0.85         ## seconds of draw for a full heavy
const PARRY_WIN := 0.2
const PARRY_RELOCK := 0.55       ## a guard pressed again this soon has no parry window (no mashing)
const BLOCK_KEEP := 0.25
const BLOCK_COST := 2.0          ## Breath per point of Gloom turned by a block
const GUARD_COS := 0.17          ## blocks blows from within ~80 degrees of the front
const BROKEN_TIME := 0.9
const RIPOSTE_MULT := 2.5
const CUDGEL_PER_MARK := 0.7

## [pose, damage, length (s), hit time (s), reach (m), radius (m), arc cos, marks, Breath]
const CHAIN := [
	[&"strike_a", 1.2, 0.36, 0.13, 1.25, 1.35, 0.26, 1, Stamina.STRIKE],
	[&"strike_b", 1.2, 0.36, 0.13, 1.25, 1.35, 0.26, 1, Stamina.STRIKE],
	[&"strike_c", 2.3, 0.54, 0.21, 1.1, 2.0, -0.2, 1, Stamina.FINISHER],
]

var player: Player
var stamina: Node
var _phase := -1                 ## the strike playing (index into CHAIN; 3 = heavy), -1 none
var _t := 0.0
var _len := 0.0
var _hit_at := 0.0
var _hit_done := false
var _queued := false
var _next := 0                   ## the chain step a new strike starts on
var _gap := 0.0                  ## time left to continue the chain
var _target: Node3D
var _lunge := Vector3.ZERO       ## m/s carried toward the target until the hit
var _riposte := false
var _heavy_c := 0.0
var _hold := -1.0                ## the staff key held this long (-1 not held)
var _drawing := false            ## a heavy is being drawn
var _guard_t := -1.0             ## guard held this long (-1 not held)
var _guard_k := 0.0
var _parry_clock := -1.0         ## runs from the moment the staff is across the body (guard_k > 0.65)
var _last_guard := -10.0
var _parry_ok := false
var _broken := 0.0
var _close_frame := -1
var _close: Node3D
var strikes_landed := 0          ## tests and the build sheet
var parries := 0
var blocks := 0


func _ready() -> void:
	player = get_parent() as Player


# --- read-only surface -----------------------------------------------------------------------

## A strike, a heavy or its draw is under way (no spells meanwhile).
func busy() -> bool:
	return _phase >= 0 or _drawing


func guarding() -> bool:
	return _guard_t >= 0.0


## Inside a guard's opening: a blow now is parried (Player.is_evading reads this).
func parrying() -> bool:
	return _parry_clock >= 0.0 and _parry_clock <= PARRY_WIN and _parry_ok


func phase() -> int:
	return _phase


func heavy_charge() -> float:
	return _heavy_c if _drawing else 0.0


## Walk speed while busy: a guard shuffles, a draw creeps, a strike is driven by its lunge.
func move_scale() -> float:
	if _broken > 0.0:
		return 0.35
	if _drawing:
		return 0.4
	if _guard_t >= 0.0:
		return 0.45
	return 1.0


## The primary trigger (Rift Bolt) is the staff's this tick: a foe is close, or a strike is going.
func claims_primary() -> bool:
	if busy():
		return true
	return player != null and player.is_grounded() and close_target() != null


## The foe the staff should go for: the lock target when it is near, else the nearest living foe
## within CLOSE_R in front of the view, in sight. Cached per physics frame.
func close_target(reach := CLOSE_R) -> Node3D:
	var f := Engine.get_physics_frames()
	if f == _close_frame and is_equal_approx(reach, CLOSE_R):
		return _close
	var found := _find_close(reach)
	if is_equal_approx(reach, CLOSE_R):
		_close_frame = f
		_close = found
	return found


func _find_close(reach: float) -> Node3D:
	if player == null or not player.is_inside_tree():
		return null
	var at := player.global_position
	var lk := player.lock_target()
	if lk and lk.is_alive() and reach > CLOSE_R + 0.01:       # the staff key reaches a lock; the trigger asks the cone and sight like any body
		var dl := Vector2(lk.global_position.x - at.x, lk.global_position.z - at.z).length()
		if dl <= reach + 0.8 and absf(lk.global_position.y - at.y) < 2.2:
			return lk
	var fwd := _view_flat()
	var best: Node3D = null
	var best_s := INF
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		var to := e.global_position - at
		if absf(to.y) > 2.0:
			continue
		var flat := Vector2(to.x, to.z)
		var d := flat.length() - _girth(e)
		if d > reach:
			continue
		var dt := 1.0 if flat.length() < 0.5 else flat.normalized().dot(Vector2(fwd.x, fwd.z))
		if dt < CLOSE_COS:
			continue
		var score := d - dt * 1.5 - (1.0 if e == lk else 0.0)
		if score >= best_s:
			continue
		if not _clear(at + Vector3.UP * 1.1, e.global_position + Vector3.UP * minf(e.hp_bar_y * 0.5, 1.2)):
			continue
		best_s = score
		best = e
	return best


## A big body (a boss, the bulwark) is reached at its skin, not its middle.
func _girth(e: Enemy) -> float:
	return clampf(e.hp_bar_y * 0.22, 0.0, 1.4)


func _view_flat() -> Vector3:
	var cam := player.get_viewport().get_camera_3d() if player.is_inside_tree() else null
	var f := -cam.global_basis.z if cam else -player.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD


func _clear(a: Vector3, b: Vector3) -> bool:
	var space := player.get_world_3d().direct_space_state
	if space == null:
		return true
	var q := PhysicsRayQueryParameters3D.create(a, b, Layers.WORLD, [player.get_rid()])
	return space.intersect_ray(q).is_empty()


# --- input -----------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if player == null:
		return
	_broken = maxf(0.0, _broken - delta)
	_gap = maxf(0.0, _gap - delta)
	if _gap <= 0.0 and _phase < 0:
		_next = 0
	var live := _input_ok() and not player.skills_locked_for_arts()
	if live:
		_read_input(delta)
	else:
		_hold = -1.0
		if _drawing:
			_drawing = false
		_end_guard()
	_tick_strike(delta)
	_tick_guard(delta)
	var rig: Variant = player.get("_visual")
	if rig is Object:
		(rig as Object).set("guard", _guard_k)
		(rig as Object).set("wind", _heavy_c if _drawing else 0.0)


func _input_ok() -> bool:
	var book := player.skills()
	return book == null or book._input_ok()


func _read_input(delta: float) -> void:
	# guard: its own key, or (pad) the slide button while locked on with the stick idle
	var g := _held(&"guard") or (Settings.using_pad and player.lock_target() != null and _held(&"slide") \
			and Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() < 0.2)
	if g and _guard_t < 0.0 and _phase < 0 and not _drawing and _broken <= 0.0 and player.is_grounded():
		_start_guard()
	elif not g and _guard_t >= 0.0:
		_end_guard()
	if _guard_t >= 0.0:
		return
	# the staff key: tap = a light strike, hold = draw a heavy
	if _just(&"staff_strike"):
		_hold = 0.0
	if _hold >= 0.0:
		if _held(&"staff_strike"):
			if player.is_grounded():
				_hold += delta
			else:
				_hold = 0.0                              # time in the air is not a draw
				if _drawing:
					_drawing = false
					_heavy_c = 0.0
			if _hold >= HEAVY_HOLD and not _drawing and _phase < 0 and player.is_grounded() and _broken <= 0.0:
				_drawing = true
				_heavy_c = 0.0
			if _drawing:
				_heavy_c = minf(1.0, _heavy_c + delta / HEAVY_FULL)
		else:
			if _drawing:
				_drawing = false
				heavy(_heavy_c)
			else:
				request_strike(true)
			_hold = -1.0
	# the primary trigger, up close: the staff chain while it is held
	var book := player.skills()
	if book and book.slots.size() > 0 and book.slots[0] != null and book.slots[0].id == &"bolt" \
			and Input.is_action_pressed(book.slots[0].action) and claims_primary():
		request_strike(false)


func _held(action: StringName) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action)


func _just(action: StringName) -> bool:
	return InputMap.has_action(action) and Input.is_action_just_pressed(action)


# --- strikes ---------------------------------------------------------------------------------

## Ask for the next light strike: starts now when free, or is queued in the last BUFFER of the one
## playing. `any` (the staff key) strikes even with nothing near; the trigger needs a close foe.
func request_strike(any: bool) -> bool:
	if _broken > 0.0 or _drawing or _guard_t >= 0.0 or not player.is_grounded():
		return false
	if _phase >= 0:
		if _phase < 3 and _len - _t <= BUFFER:
			_queued = true
		return false
	var tgt := close_target() if not any else close_target(PICK_R)
	if tgt == null and not any:
		return false
	return _begin(_next, tgt)


func _begin(i: int, tgt: Node3D) -> bool:
	var c: Array = CHAIN[i]
	var st := player.stamina()
	if st and not st.spend(float(c[8])):
		HitText.pop(player.global_position + Vector3.UP * 2.2, "no breath", Color(0.75, 0.8, 0.95))
		return false
	_phase = i
	_t = 0.0
	_len = float(c[2])
	_hit_at = float(c[3])
	_hit_done = false
	_queued = false
	_target = tgt
	_riposte = player._riposte_ready                  # armed, not spent: the blow that connects spends it
	_aim_lunge(tgt, _hit_at)
	player.note_combat()
	player.call("_visual_pose", c[0])
	StaffSfx.play("swish", player.global_position + Vector3.UP * 1.2, -4.0 if i < 2 else -1.0, 1.1 if i < 2 else 0.85)
	return true


## A heavy at draw `c` (0..1): the overhead slam.
func heavy(c: float) -> bool:
	var st := player.stamina()
	if st and not st.spend(Stamina.HEAVY):
		HitText.pop(player.global_position + Vector3.UP * 2.2, "no breath", Color(0.75, 0.8, 0.95))
		return false
	_phase = 3
	_t = 0.0
	_len = 0.66
	_hit_at = 0.28
	_hit_done = false
	_queued = false
	_heavy_c = clampf(c, 0.0, 1.0)
	_target = close_target(PICK_R)
	_riposte = player._riposte_ready
	_aim_lunge(_target, _hit_at)
	player.note_combat()
	player.call("_visual_pose", &"heavy")
	StaffSfx.play("swish", player.global_position + Vector3.UP * 1.4, 0.0, 0.7)
	return true


func _aim_lunge(tgt: Node3D, over: float) -> void:
	_lunge = Vector3.ZERO
	var fwd := _view_flat()
	if tgt and is_instance_valid(tgt):
		var to := tgt.global_position - player.global_position
		to.y = 0.0
		var d := to.length()
		if d > 0.05:
			fwd = to / d
			var girth := _girth(tgt as Enemy) if tgt is Enemy else 0.0
			var go := clampf(d - girth - STAND_OFF, 0.0, LUNGE_MAX)
			_lunge = fwd * go / maxf(over, 0.05)
	player.call("_face_now", fwd)


## The Player asks this every physics tick while busy: the horizontal velocity of the strike (the
## lunge until the blow, then planted; the stick only nudges).
func drive(wish: Vector3) -> Vector3:
	if _phase < 0:
		return Vector3.ZERO
	if _t < _hit_at:
		return _lunge * smoothstep(0.0, _hit_at * 0.5, _t) + wish * 0.6
	return wish * 0.8 * (1.0 - clampf((_t - _hit_at) / 0.15, 0.0, 1.0))


func _tick_strike(delta: float) -> void:
	if _phase < 0:
		return
	_t += delta
	if not _hit_done and _t >= _hit_at:
		_hit_done = true
		_land_blow()
	if _t >= _len:
		var was := _phase
		_phase = -1
		if was == 3:
			_next = 0
			_gap = 0.0
			return
		_next = (was + 1) % CHAIN.size()
		_gap = CHAIN_GAP if was < 2 else 0.0
		if was == 2:
			_next = 0
		if _queued:
			_queued = false
			var tgt := close_target(PICK_R)
			_begin(_next, tgt)


func cancel() -> void:
	_phase = -1
	_queued = false
	_drawing = false
	_hold = -1.0
	_lunge = Vector3.ZERO
	_end_guard()


## The blow: everything in the arc in front takes it.
func _land_blow() -> void:
	var heavy_hit := _phase == 3
	var c: Array = CHAIN[mini(_phase, 2)]
	var dmg := float(c[1])
	var reach := float(c[4])
	var radius := float(c[5])
	var arc := float(c[6])
	var marks := int(c[7])
	if heavy_hit:
		dmg = lerpf(3.0, 6.5, _heavy_c)
		reach = 1.2
		radius = lerpf(2.1, 3.0, _heavy_c)
		arc = -0.3
		marks = 2 if _heavy_c >= 0.99 else 1
	if _riposte:
		dmg *= RIPOSTE_MULT
	var fwd := -(player.get("_visual") as Node3D).global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 0.0001 else _view_flat()
	var body := player.global_position
	var centre := body + fwd * reach + Vector3.UP * 0.9
	var hit_any := false
	var finisher := _phase == 2 or heavy_hit
	for e in _foes_in(centre, radius):
		var to := e.global_position - body
		to.y = 0.0
		var d := to.length()
		if d > 0.6 and (to / d).dot(fwd) < arc:
			continue
		if not _clear(body + Vector3.UP * 1.0, e.global_position + Vector3.UP * minf(e.hp_bar_y * 0.5, 1.2)):
			continue
		var hit := dmg
		if finisher and not heavy_hit:
			var mk := e.take_marks()
			if mk > 0:
				hit += CUDGEL_PER_MARK * float(mk)
				if mk >= 2:
					Combo.note("RIFT CUDGEL", e.global_position + Vector3.UP * e.hp_bar_y, Color(1.3, 0.7, 2.6), "+%.1f" % (CUDGEL_PER_MARK * float(mk)))
		if marks > 0:
			e.add_mark(marks)
		var cs: Node = player.call("combat") if player.has_method("combat") else null
		if cs != null:
			cs.call("deal", e, hit, &"physical", player)     # r33: crits, Sundered, the damage feed
		else:
			e.take_hit(hit, player)
		strikes_landed += 1
		hit_any = true
		if (_riposte or (heavy_hit and _heavy_c >= 0.99)) and not e.boss:
			e.stagger()
		var at := e.global_position + Vector3.UP * minf(e.hp_bar_y * 0.6, 1.4)
		Vfx.burst(at, Color(1.5, 0.75, 2.8), {"count": 18 if finisher else 10, "life": 0.3, "speed": Vector2(3.0, 7.0), "size": 0.04, "dir": fwd, "spread": 55.0, "gravity": -6.0, "trail": 0.07})
		StaffSfx.play("bolt_hit", at, -2.0 if finisher else -5.0, 0.7 if finisher else 0.9)
		EnemyAudio.player("thwack", at, -1.0 if finisher else -4.0, 0.85 if heavy_hit else 1.0)      # wood on the body: its material answers from take_hit
	if hit_any and player.has_method("combat") and player.call("combat") != null:
		(player.call("combat") as Node).call("build", 1)  # r33: a landed blow builds one Resonance
	if _riposte and hit_any:
		player.consume_riposte()
		HitText.pop(body + Vector3.UP * 2.3, "RIPOSTE", Color(1.3, 0.75, 2.6), true)
		Combo.note("RIPOSTE STRIKE", Vector3.INF, Color(1.3, 0.75, 2.6))
	if finisher:
		var g := body + fwd * reach
		_front_ring(body, g, fwd, radius, arc)
		Vfx.burst(g + Vector3.UP * 0.1, Color(0.18, 0.15, 0.2, 0.55), {"count": 14, "life": 0.6, "speed": Vector2(0.8, 2.4), "size": 0.25, "gravity": -0.4, "dir": Vector3.UP, "spread": 85.0, "additive": false, "radius": radius * 0.5})
		StaffSfx.play("tap", g, -2.0 if heavy_hit else -6.0, 0.7)
	if hit_any:
		player.hitstop(0.11 if heavy_hit else (0.075 if finisher else 0.045), 0.05)
		player.kick(0.5 if heavy_hit else (0.32 if finisher else 0.16))
	elif heavy_hit:
		player.kick(0.3)


func _foes_in(centre: Vector3, radius: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	var space := player.get_world_3d().direct_space_state
	if space:
		var sph := SphereShape3D.new()
		sph.radius = radius
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = sph
		q.transform = Transform3D(Basis.IDENTITY, centre)
		q.collision_mask = Layers.HURTBOX
		q.collide_with_areas = true
		q.collide_with_bodies = true
		for hit in space.intersect_shape(q, 24):
			var n := hit.get("collider") as Node
			while n and not (n is Enemy):
				n = n.get_parent()
			if n is Enemy and (n as Enemy).is_alive() and not out.has(n):
				out.append(n as Enemy)
	# a body with no hurtbox in reach (a squat crawler, a foe half in the ground): its centre counts
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e and e.is_alive() and not out.has(e) and (e.global_position + Vector3.UP * 0.6).distance_to(centre) <= radius + _girth(e) * 0.5:
			out.append(e)
	return out


# --- guard -----------------------------------------------------------------------------------

func _start_guard() -> void:
	var now := Time.get_ticks_msec() * 0.001
	_parry_ok = now - _last_guard >= PARRY_RELOCK
	_last_guard = now
	_guard_t = 0.0
	_parry_clock = -1.0
	player.note_combat()
	StaffSfx.play("tap", player.global_position + Vector3.UP * 1.3, -12.0, 1.5)


func _end_guard() -> void:
	_guard_t = -1.0
	_parry_clock = -1.0


func _tick_guard(delta: float) -> void:
	if _guard_t >= 0.0:
		_guard_t += delta
		if _parry_clock >= 0.0:
			_parry_clock += delta
		var st := player.stamina()
		if st:
			st.holding = true
	_guard_k = move_toward(_guard_k, 1.0 if _guard_t >= 0.0 else 0.0, delta * (14.0 if _guard_t >= 0.0 else 6.0))
	if _guard_t >= 0.0 and _parry_clock < 0.0 and _guard_k > 0.65:
		_parry_clock = 0.0                        # the window opens when the staff is across, and lasts PARRY_WIN


## Player.on_evaded during a parry window: the blow is turned aside.
func parry(attacker: Node) -> void:
	parries += 1
	_parry_ok = false
	var st := player.stamina()
	if st:
		st.refund(Stamina.PERFECT_REFUND, true)
	var at := player.global_position + Vector3.UP * 1.4
	HitText.pop(at + Vector3.UP * 0.9, "PARRY", Color(1.5, 1.2, 0.6), true)
	Hints.once(&"parry", "PARRY: guard just as a blow lands. The attacker reels and your next strike or bolt is a riposte.")
	if attacker and is_instance_valid(attacker):
		if attacker.has_method("add_mark"):
			attacker.add_mark(1)
		if attacker.has_method("riposted"):
			attacker.riposted()
	player.set("_riposte_ready", true)
	player.call("_visual_pose", &"parry")
	StaffSfx.play("perfect", at, -3.0)
	StaffSfx.play("tap", at, -2.0, 1.6)
	EnemyAudio.player("parry", at, -1.0)
	Vfx.burst(at + (-(player.get("_visual") as Node3D).global_basis.z) * 0.5, Color(2.2, 1.6, 0.8), {"count": 22, "life": 0.25, "speed": Vector2(3.0, 7.0), "size": 0.035, "gravity": -9.0, "trail": 0.06})
	SpellFx.shell(at, 0.2, 1.4, Color(1.6, 1.2, 0.6), 0.2)
	player.hitstop(0.14, 0.15)
	player.kick(0.4)


## Player.take_wound while guarding: how much of `amount` gets through.
func absorb(amount: float, from_pos: Vector3) -> float:
	if _guard_t < 0.0 or amount <= 0.0:
		return amount
	if from_pos != Vector3.INF:
		var to := from_pos - player.global_position
		to.y = 0.0
		var fwd := -(player.get("_visual") as Node3D).global_basis.z
		fwd.y = 0.0
		if to.length() > 0.3 and fwd.length() > 0.01 and to.normalized().dot(fwd.normalized()) < GUARD_COS:
			return amount                         # from the side or behind: the guard does not cover it
	var st := player.stamina()
	var turned := amount * (1.0 - BLOCK_KEEP)
	if st:
		st.drain(turned * BLOCK_COST)
		if st.winded:
			_broken = BROKEN_TIME
			_end_guard()
			HitText.pop(player.global_position + Vector3.UP * 2.3, "GUARD BROKEN", Color(1.4, 0.45, 0.35), true)
			StaffSfx.play("shatter", player.global_position + Vector3.UP, -4.0, 0.8)
			return amount
	blocks += 1
	HitText.pop(player.global_position + Vector3.UP * 2.2, "blocked, %d got through" % roundi(amount * BLOCK_KEEP), Color(0.85, 0.85, 1.0))
	StaffSfx.play("tap", player.global_position + Vector3.UP * 1.3, -3.0, 0.9)
	EnemyAudio.player("block", player.global_position + Vector3.UP * 1.3, -2.0)
	player.kick(0.25)
	return amount * BLOCK_KEEP


## The finisher's ring: only the front of the circle, cut on the arc the blow itself keeps
## (directions from the body at least `arc` against the facing), out to the same radius.
func _front_ring(body: Vector3, centre: Vector3, fwd: Vector3, radius: float, arc: float) -> void:
	var host := get_tree().current_scene
	if host == null:
		return
	const N := 48
	const W := 0.09
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	var keep: Array[bool] = []
	for i in N + 1:
		var a := TAU * float(i) / float(N)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var p := centre + dir * radius
		var to := p - body
		to.y = 0.0
		var d := to.length()
		keep.append(d <= 0.6 or (to / d).dot(fwd) >= arc)
		verts.append(dir * (1.0 - W))
		verts.append(dir)
	for i in N:
		if keep[i] and keep[i + 1]:
			var o := i * 2
			idx.append_array([o, o + 1, o + 3, o, o + 3, o + 2])
	if idx.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(1.2, 0.55, 2.8, 0.9)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mi)
	mi.global_position = centre + Vector3.UP * 0.12
	mi.scale = Vector3(radius * 0.35, 1.0, radius * 0.35)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 1.0, radius), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tw.chain().tween_callback(mi.queue_free)
