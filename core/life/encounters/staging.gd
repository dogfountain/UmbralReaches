extends Node
## Foes built ahead of the wanderer (camps and villages perf pass, 21 Nov). The guardians and their escorts, the named
## elites and the rares were each built the moment the wanderer came near them (55, 72 and 95 m): a whole creature in one
## frame (1.4-7 ms warm) on top of the frame's own work. Now each is built a little ahead, in play, one at a time and only
## on a frame with room to spare (`claim`), and waits unseen until the moment the old rule built it:
##   builder   the nearest missing guardian, escort, elite or rare within BUILD_R, outside its owner's rise radius, one a
##             claimed frame. The camps' next pawns (EnemySpawner) and an ambush's risers (ambush_prep.gd) claim the same
##             frames, so two builds never share one.
##   waiting   meta `staged`: built, asleep, hidden, no collision, out of Groups.ENEMY: nothing draws, casts, scans or hits
##             it. It rises (shown) where the old rule built it, as the old rule showed it.
##   out of reach   an untouched group (full health, at rest, no Marks, not enraged) goes back to waiting where it stands
##             (the old rule freed it and built it afresh: the same foe); a hurt, enraged or broken group is freed as before
##             and the builder makes it again later.
## Nothing is built under the loading cover (the load is as before). Owners: director.gd (elites), guardians.gd
## (guardians, escorts; it adds this node), core/enemy/rares.gd (rares). `-- --no-staging`: nothing built ahead (A/B).
## Load by path (no class_name).

const BUILD_R := 170.0                 ## the builder looks this far for what to build
const ROOM_MS := 10.0                  ## a build goes on a frame whose last frame took less than this
const GAP := 4                         ## and at least this many frames after the last build
const STAGED := &"staged"
const HIDDEN := &"stage_hide"          ## a child shown only while its foe has risen (a rare's shimmer and motes)
const LAYER := &"stage_layer"          ## the collision layer a waiting foe had (it has none while it waits)
const TickPhase := preload("res://core/util/tick_phase.gd")
const AudioPrefetch := preload("res://core/vfx/audio_prefetch.gd")

## `-- --no-staging` (A/B): nothing is built ahead; each is built where the old rule built it.
static var OFF := "--no-staging" in OS.get_cmdline_user_args()
static var _built_at := -1000          ## the frame the last build was claimed (every builder shares it)

var guardians: Variant                 ## guardians.gd (sites, nodes, spawn, escort_next)
var director: Variant                  ## director.gd (haunts, elite_nodes, slain, spawn_elite, spawner, root)
var built := 0
var _near := {}                        ## owner -> its rise radius (read from its script once)
var _todo: Array = []                  ## [distance, kind, key]: what the last look found missing, nearest first
var _look_t := 0.0


func _ready() -> void:
	name = "Staging"
	_look_t = TickPhase.first(self, 0.5)
	AudioPrefetch.start(get_parent())          # their voices too: every take loaded ahead, off the main thread


## A frame with room for one build (the last frame was quick, none was built in the last GAP frames): true claims it.
static func claim(n: Node) -> bool:
	if OFF:
		return false
	var f := Engine.get_process_frames()
	if f - _built_at < GAP or n.get_process_delta_time() * 1000.0 > ROOM_MS:
		return false
	_built_at = f
	return true


## Waiting: asleep, hidden, no collision, out of the foes' group.
static func stage(e: Enemy) -> void:
	if e == null or not is_instance_valid(e):
		return
	if not e.has_meta(STAGED):
		e.set_meta(STAGED, true)
		e.set_meta(LAYER, e.collision_layer)
	e.sleep()
	e.visible = false
	e.collision_layer = 0
	_extras(e, false)
	if e.is_in_group(Groups.ENEMY):
		e.remove_from_group(Groups.ENEMY)


static func waiting(e: Enemy) -> bool:
	return e != null and is_instance_valid(e) and e.has_meta(STAGED)


## Risen: what the old rule built at this moment, shown as it showed it. Its owner wakes it (or not) by its own rule.
static func rise(e: Enemy) -> void:
	if not waiting(e):
		return
	e.collision_layer = int(e.get_meta(LAYER, e.collision_layer))
	e.remove_meta(STAGED)
	e.remove_meta(LAYER)
	e.visible = true
	_extras(e, true)
	if e.is_alive() and not e.is_in_group(Groups.ENEMY):
		e.add_to_group(Groups.ENEMY)


## True while `e` waits; false once it has risen (`rise_now`: the owner's old build rule holds). Not waiting: false.
static func waits(e: Enemy, rise_now: bool) -> bool:
	if not waiting(e):
		return false
	if rise_now:
		rise(e)
		return false
	if e.process_mode != Node.PROCESS_MODE_DISABLED:
		e.sleep()                            # woken by a neighbour's call: back to rest, unseen
	return true


## A guardian and its escort wait and rise together. True while they wait.
static func waits_group(group: Array, rise_now: bool) -> bool:
	if group.is_empty() or not waiting(group[0] as Enemy):
		return false
	if rise_now:
		for m: Variant in group:
			if is_instance_valid(m):
				rise(m as Enemy)
				if m != group[0] and (m as Enemy).is_alive():
					(m as Enemy).wake()     # an escort was always awake while it stood (the guardian wakes by its range)
		return false
	for m: Variant in group:
		if is_instance_valid(m):
			waits(m as Enemy, false)
	return true


## As the old rule built it: at rest, whole, unmarked, not enraged, not leashing home.
static func untouched(e: Variant) -> bool:
	if not is_instance_valid(e) or not (e is Enemy):
		return false
	var en := e as Enemy
	return en.is_alive() and en.hp >= float(en.max_hp) - 0.001 and en._state == Enemy.IDLE and not en.is_evading() \
		and en.marks == 0 and not bool(en.get_meta(&"guardian_enraged", false))


## Out of reach: an untouched group goes back to waiting where it stands (true). Anything else (false) the owner frees.
static func stand_down(group: Array) -> bool:
	if group.is_empty() or OFF:
		return false
	for m: Variant in group:
		if not untouched(m):
			return false
	for m: Variant in group:
		stage(m as Enemy)
	return true


static func _extras(e: Enemy, on: bool) -> void:
	for c in e.get_children():
		if c.has_meta(HIDDEN) and c is Node3D:
			(c as Node3D).visible = on
			if c is GPUParticles3D:
				(c as GPUParticles3D).emitting = on


# --- the builder: one a claimed frame, the nearest first -------------------------------------------------------------

func _process(dt: float) -> void:
	if OFF or director == null or not bool(director.ready_done):
		return
	if get_tree().get_first_node_in_group(&"loading_screen") != null:
		return                                   # nothing under the cover: the load is as it was
	var player := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if player == null:
		return
	var pos := player.global_position
	_look_t -= dt
	if _look_t <= 0.0:
		_look_t = TickPhase.next(_look_t, 0.5)
		_look(pos)
	while not _todo.is_empty():
		var job: Array = _todo[0]
		if not _still_missing(job):
			_todo.pop_front()
			continue
		if not claim(self):
			return
		if _build(job, pos):
			built += 1
		if String(job[1]) != "escort":
			_todo.pop_front()                    # (an escort job stays until the whole escort stands)
		return


## An owner's rise radius, from its script's own constant (no copy of the number here).
func _rise_r(owner: Variant, name_c: String) -> float:
	var sc := (owner as Object).get_script() as Script
	var k := sc.resource_path + ":" + name_c
	if not _near.has(k):
		_near[k] = float(sc.get_script_constant_map().get(name_c, 95.0))
	return float(_near[k])


## What is missing within BUILD_R, outside each owner's rise radius, nearest first.
func _look(pos: Vector3) -> void:
	_todo.clear()
	for id: String in director.haunts:
		var at: Vector3 = director.haunts[id]
		var d := pos.distance_to(at)
		if d < BUILD_R and d > _rise_r(director, "ELITE_NEAR") and not is_instance_valid((director.elite_nodes as Dictionary).get(id)) \
				and not bool(director.slain(id)) and not LightGrid.is_lit(at):
			_todo.append([d, "elite", id])
	guardians.refresh_sites()
	for s: Dictionary in guardians.sites:
		var key := String(s.key)
		var d2 := pos.distance_to(s.at as Vector3)
		if d2 >= BUILD_R or bool(guardians.slain(key)):
			continue
		var g: Variant = (guardians.nodes as Dictionary).get(key)
		if is_instance_valid(g):
			if waiting(g as Enemy) and bool(guardians.escort_missing(key)):
				_todo.append([d2, "escort", key])
		elif d2 > _rise_r(guardians, "NEAR") and not LightGrid.is_lit(s.at as Vector3):
			_todo.append([d2, "guardian", key, s])
	var sp: EnemySpawner = director.spawner
	if sp != null and is_instance_valid(sp) and sp.rares != null and is_instance_valid(sp.rares):
		var rares: Variant = sp.rares
		for id2: String in rares.haunts:
			var at2: Vector3 = rares.haunts[id2]
			var d3 := pos.distance_to(at2)
			if d3 < BUILD_R and d3 > _rise_r(rares, "NEAR") and not is_instance_valid((rares.nodes as Dictionary).get(id2)) \
					and bool(rares.due(id2)) and not LightGrid.is_lit(at2):
				_todo.append([d3, "rare", id2])
	_todo.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))


func _still_missing(job: Array) -> bool:
	match String(job[1]):
		"elite":
			return not is_instance_valid((director.elite_nodes as Dictionary).get(job[2]))
		"guardian":
			return not is_instance_valid((guardians.nodes as Dictionary).get(job[2]))
		"escort":
			return waiting((guardians.nodes as Dictionary).get(job[2]) as Enemy) and bool(guardians.escort_missing(job[2]))
		"rare":
			var sp: EnemySpawner = director.spawner
			return sp != null and is_instance_valid(sp) and sp.rares != null and not is_instance_valid((sp.rares.nodes as Dictionary).get(job[2]))
	return false


func _build(job: Array, _pos: Vector3) -> bool:
	match String(job[1]):
		"elite":
			stage(director.spawn_elite(String(job[2])) as Enemy)
			return true
		"guardian":
			stage(guardians.spawn(job[3] as Dictionary, false, false) as Enemy)
			return true
		"escort":
			return bool(guardians.escort_next(String(job[2])))
		"rare":
			var sp: EnemySpawner = director.spawner
			stage(sp.rares.spawn_rare(String(job[2])) as Enemy)
			return true
	return false
