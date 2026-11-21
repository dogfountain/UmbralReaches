extends Node
## Foes built ahead of the wanderer (camps and villages perf pass, 21 Nov). The guardians and their escorts, the named
## elites and the rares were each built the moment the wanderer came near them (55, 72 and 95 m): a whole creature in one
## frame (3-7 ms warm; the 10-15 ms script frames of every camp the perf tour's path passed) that appeared from nothing
## at that distance. Now each is built once, asleep, behind the loading cover (a few a frame, BUDGET_US), and stands at
## its post like a camp pawn: coming near only wakes it.
##   waiting   meta `staged`: built but "not risen yet". It stays asleep and inert where the old rule had no body at all,
##             and rises when the old rule would have built it, or the moment it is hurt or alerted (a bolt from afar).
##   out of reach   an untouched group (full health, at rest, no Marks, not enraged) simply sleeps again where it stands,
##             waiting (the old rule freed it and built it afresh: the same foe). A hurt, enraged or broken group is freed
##             as before and built again asleep once the wanderer is well past the owner's FAR (PAD), one a tick: never
##             in the middle of the fight it came from.
## Owners: director.gd (elites), guardians.gd (guardians, escorts; it adds this node), core/enemy/rares.gd (rares). The
## zone gets meta `foes_staged` when the first pass is done (the loading screen waits for it).
## Load by path (no class_name).

const HIDE_R := 170.0                  ## a waiting foe further than this is not drawn at all (EnemySpawner.HIDE_R)
const PAD := 15.0                      ## built again asleep once the wanderer is this far past the owner's FAR
const BUDGET_US := 5000                ## the first pass: builds a frame until this much time is spent (at least one)
const STAGED := &"staged"
const HIDDEN := &"stage_hide"          ## a child shown only while its foe has risen (a rare's shimmer and motes)
const AudioPrefetch := preload("res://core/vfx/audio_prefetch.gd")

var guardians: Variant                 ## guardians.gd (sites, nodes, spawn)
var director: Variant                  ## director.gd (haunts, elite_nodes, slain, spawn_elite, spawner, root)
var done := false
var _step := 0                         ## 0 elites, 1 guardians, 2 rares, 3 done
var _keys: Array = []
var _k := 0
var _built := 0
var _esc_key := ""                     ## the guardian whose escort the pass is building
var _t0 := 0


func _ready() -> void:
	name = "Staging"
	_t0 = Time.get_ticks_msec()
	AudioPrefetch.start(get_parent())          # their voices too: every take loaded ahead, off the main thread


## The far side of an owner's reach: a foe missing there is built again asleep.
static func ahead(d: float, far_r: float) -> bool:
	return d > far_r + PAD


## A foe the owner has just built: waiting (asleep, not risen) when `wait`, else left as built.
static func built(e: Enemy, wait: bool, d: float) -> void:
	if e != null and wait:
		stage(e, d)


## Asleep and waiting (built ahead, or stood down out of reach); drawn only inside HIDE_R. Out of Groups.ENEMY while it
## waits: the twenty-odd systems that walk the foes (aim, targeting, the minimap, stamina, the horse, the foe index, the
## encounters' cap) walk what they walked before, when it was not built at all; a bolt still finds its body (take_hit).
static func stage(e: Enemy, d: float) -> void:
	if e == null or not is_instance_valid(e):
		return
	e.set_meta(STAGED, true)
	e.sleep()
	_extras(e, false)
	e.visible = d <= HIDE_R
	if e.is_in_group(Groups.ENEMY):
		e.remove_from_group(Groups.ENEMY)


static func waiting(e: Enemy) -> bool:
	return e != null and is_instance_valid(e) and e.has_meta(STAGED)


## Hurt, alerted or dead: a waiting foe that met the wanderer rises whatever the distance.
static func disturbed(e: Enemy) -> bool:
	return is_instance_valid(e) and (not e.is_alive() or e.hp < float(e.max_hp) - 0.001 or e._state != Enemy.IDLE)


## Risen: what the old rule built at this moment. Its owner wakes it (or not) by its own sleep rule.
static func rise(e: Enemy) -> void:
	if not waiting(e):
		return
	e.remove_meta(STAGED)
	e.visible = true
	_extras(e, true)
	if e.is_alive() and not e.is_in_group(Groups.ENEMY):
		e.add_to_group(Groups.ENEMY)


## True while `e` waits (kept asleep, drawn by distance); false once it has risen: `rise_now` (the owner's old build rule
## holds) or it was disturbed. Not waiting at all: false.
static func waits(e: Enemy, rise_now: bool, d: float) -> bool:
	if not waiting(e):
		return false
	if rise_now or disturbed(e):
		rise(e)
		return false
	if e.process_mode != Node.PROCESS_MODE_DISABLED:
		e.sleep()                            # woken by a neighbour's call but untouched: back to rest
	var show := d <= HIDE_R
	if e.visible != show:
		e.visible = show
	return true


## A guardian and its escort wait and rise together (anything disturbed raises them all). True while they wait.
static func waits_group(group: Array, rise_now: bool, d: float) -> bool:
	if group.is_empty() or not waiting(group[0] as Enemy):
		return false
	var up := rise_now
	for m: Variant in group:
		if is_instance_valid(m) and disturbed(m as Enemy):
			up = true
	if up:
		for m: Variant in group:
			if is_instance_valid(m):
				rise(m as Enemy)
				if m != group[0] and (m as Enemy).is_alive():
					(m as Enemy).wake()     # an escort was always awake while it stood (the guardian wakes by its range)
		return false
	for m: Variant in group:
		if is_instance_valid(m):
			waits(m as Enemy, false, d)
	return true


## As the old rule built it: at rest, whole, unmarked, not enraged, not leashing home.
static func untouched(e: Variant) -> bool:
	if not is_instance_valid(e) or not (e is Enemy):
		return false
	var en := e as Enemy
	return en.is_alive() and en.hp >= float(en.max_hp) - 0.001 and en._state == Enemy.IDLE and not en.is_evading() \
		and en.marks == 0 and not bool(en.get_meta(&"guardian_enraged", false))


## Out of reach: an untouched group sleeps where it stands, waiting again (true). Anything else (false) the owner frees.
static func stand_down(group: Array, d: float) -> bool:
	if group.is_empty():
		return false
	for m: Variant in group:
		if not untouched(m):
			return false
	for m: Variant in group:
		stage(m as Enemy, d)
	return true


static func _extras(e: Enemy, on: bool) -> void:
	for c in e.get_children():
		if c.has_meta(HIDDEN) and c is Node3D:
			(c as Node3D).visible = on
			if c is GPUParticles3D:
				(c as GPUParticles3D).emitting = on


# --- the first pass: everything built once, asleep, a few a frame -------------------------------------------------

func _process(_dt: float) -> void:
	if done or director == null or not bool(director.ready_done):
		return
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < BUDGET_US:
		if not _build_one():
			break
	if _step >= 3:
		_finish()


## Builds the next foe of the pass (true), or moves on a step (true) or waits for the world (false).
func _build_one() -> bool:
	var player := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	var pos := player.global_position if player != null else Vector3.INF
	match _step:
		0:
			if _keys.is_empty() and _k == 0:
				_keys = (director.haunts as Dictionary).keys()
			if _k >= _keys.size():
				return _next()
			var id := String(_keys[_k])
			_k += 1
			var at: Vector3 = director.haunts[id]
			var have: Variant = (director.elite_nodes as Dictionary).get(id)
			if (have != null and is_instance_valid(have)) or bool(director.slain(id)) or LightGrid.is_lit(at):
				return true
			stage(director.spawn_elite(id) as Enemy, _d(pos, at))
			_built += 1
			return true
		1:
			if _esc_key != "":                  # the last guardian's escort, one a call (each waits as its guardian does)
				if bool(guardians.escort_next(_esc_key)):
					_built += 1
					return true
				_esc_key = ""
			if _keys.is_empty() and _k == 0:
				guardians.refresh_sites()
				_keys = (guardians.sites as Array).duplicate()
			if _k >= _keys.size():
				return _next()
			var s: Dictionary = _keys[_k]
			_k += 1
			var key := String(s.key)
			if is_instance_valid((guardians.nodes as Dictionary).get(key)) or bool(guardians.slain(key)) or LightGrid.is_lit(s.at as Vector3):
				return true
			stage(guardians.spawn(s, false, false) as Enemy, _d(pos, s.at as Vector3))
			_esc_key = key
			_built += 1
			return true
		2:
			var sp: EnemySpawner = director.spawner
			if sp == null or not is_instance_valid(sp):
				return _next()
			if not sp.settled:
				return false                    # (the rares find their haunts once the camps are settled)
			if sp.rares == null or not is_instance_valid(sp.rares):
				return _next()
			var rares: Variant = sp.rares
			if _keys.is_empty() and _k == 0:
				_keys = (rares.haunts as Dictionary).keys()
			if _k >= _keys.size():
				return _next()
			var id := String(_keys[_k])
			_k += 1
			var at: Vector3 = rares.haunts[id]
			if is_instance_valid((rares.nodes as Dictionary).get(id)) or not bool(rares.due(id)) or LightGrid.is_lit(at):
				return true
			stage(rares.spawn_rare(id) as Enemy, _d(pos, at))
			_built += 1
			return true
	return false


func _next() -> bool:
	_step += 1
	_keys = []
	_k = 0
	return _step < 3


static func _d(pos: Vector3, at: Vector3) -> float:
	return pos.distance_to(at) if pos.is_finite() else 0.0


func _finish() -> void:
	done = true
	set_process(false)
	var root: Variant = director.root
	if root is Node:
		(root as Node).set_meta(&"foes_staged", true)
	print("STAGING %d guardians, escorts, elites and rares built ahead, asleep (%.1f s after the encounters came up)" % [_built, (Time.get_ticks_msec() - _t0) / 1000.0])
