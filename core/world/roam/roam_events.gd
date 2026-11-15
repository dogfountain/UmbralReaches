extends Node
## r36 roaming events (docs/critique/r36_plan.md, step 4): things that happen in the Realm on their
## own, near the wanderer but out of her sight, one at a time. Each has a map pin while it lasts and
## pays when it is seen through. Nothing runs while none is on (a 2 s check); an event lasts minutes.
##   procession  a file of hollowed walking the road toward the summit, singing; put them down
##   incursion   the dark leans on a lit brazier: hollowed gather at the edge of its light
##   tear        a rift opens and lets crawling things through until six are put down
##   pilgrim     a living pilgrim knelt in the dark; reach her and she gets up and goes home
## Built by EnemySpawner with the watch (realm only). State: none (events are of the moment).

const VillagerScript := preload("res://core/life/village/villager.gd")
const ReachState := preload("res://core/world/night/reach_state.gd")
const SpawnRules := preload("res://core/life/encounters/spawn_rules.gd")
const Director := preload("res://core/life/encounters/director.gd")

const FIRST := 150.0             ## seconds before the first event of a night
const EVERY := Vector2(200.0, 360.0)
const NEAR := Vector2(35.0, 70.0)   ## how far from the wanderer an event starts
const LAST := 240.0              ## an event not seen through by then ends of itself
const KINDS := ["procession", "incursion", "tear", "pilgrim"]

var kind := ""
var _wait := FIRST
var _t := 0.0
var _check := 0.0
var _pin: Node3D
var _foes: Array[Node3D] = []
var _need := 0
var _done_n := 0
var _spawn_t := 0.0
var _at := Vector3.ZERO
var _who: Node3D
var _village: Node
var _rng := RandomNumberGenerator.new()
var history: Array[String] = []  ## kinds started (tests)


## The lost pilgrim's two looks (an old woman, a man), prewarmed under the load: a fresh villager mesh
## built in play is a 250 ms stall.
const PILGRIMS := [
	{"seed": 9041, "sex": "f", "age": "old", "garment": "robe", "hood": true, "r": "staff", "cloth": Color(0.4, 0.37, 0.32), "cloth2": Color(0.3, 0.28, 0.25)},
	{"seed": 9057, "sex": "m", "age": "adult", "garment": "robe", "hood": true, "r": "staff", "cloth": Color(0.36, 0.33, 0.3), "cloth2": Color(0.28, 0.26, 0.24)},
]


func _ready() -> void:
	if not Slice.full():                     # the 30-minute slice hides roaming events (--full restores them)
		set_physics_process(false)
		return
	add_to_group(&"roam_events")
	_rng.randomize()
	var Rig: GDScript = load("res://core/life/village/villager_rig.gd")
	for look: Dictionary in PILGRIMS:
		var r: Node = Rig.call("create", look.duplicate())
		r.free()


func _physics_process(delta: float) -> void:
	_check -= delta
	if kind == "":
		if _check > 0.0:
			return
		_check = 2.0
		_wait -= 2.0
		if _wait <= 0.0 and not Player.boss_fight_active(get_tree()):
			var k := String(KINDS[_rng.randi_range(0, KINDS.size() - 1)])
			if ReachState.homecoming() and _rng.randf() < 0.5:
				k = "pilgrim"                 # r36 Act III: the door on the latch; they come home
			start(k)
		return
	_t += delta
	match kind:
		"tear":
			_tick_tear(delta)
		"pilgrim":
			_tick_pilgrim()
		_:
			_tick_foes()
	if kind != "" and _t > LAST - 5.0 and is_instance_valid(_pin):
		_pin.queue_free()                 # it lets go of the map in its last seconds; nothing here is saved
	if kind != "" and _t > LAST:
		_end(false)


## Start event `k` now (the director's pick, or a test's). Returns false when no place was found.
func start(k: String) -> bool:
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if p == null:
		return false
	var at := _place(p, k)
	if at == Vector3.INF:
		_wait = 30.0
		return false
	kind = k
	_at = at
	_t = 0.0
	_done_n = 0
	_foes.clear()
	history.append(k)
	match k:
		"procession":
			_procession(p)
		"incursion":
			_incursion()
		"tear":
			_need = 6
			_spawn_t = 0.5
			Events.toast.emit("Something tears, out in the dark.")
			Vfx.light(_at + Vector3.UP * 1.5, SpellFx.VIOLET, 6.0, 14.0, 1.2, 2)
		"pilgrim":
			_pilgrim()
	_make_pin(k)
	return true


func _place(p: Node3D, k: String) -> Vector3:
	if k == "incursion":
		var best: Node3D = null
		var bd := INF
		for b in get_tree().get_nodes_in_group(Groups.BRAZIER):
			var bn := b as Node3D
			if bn == null or not bool(bn.get("lit")):
				continue
			if SpawnRules.safe_at(Vector2(bn.global_position.x, bn.global_position.z), 12.0) != "":
				continue                   # a town's or the hub's own fire: the dark does not come into a safe place

			var d := bn.global_position.distance_to(p.global_position)
			if d > NEAR.x * 0.6 and d < NEAR.y * 1.4 and d < bd:
				bd = d
				best = bn
		return best.global_position if best else Vector3.INF
	var space := p.get_world_3d().direct_space_state
	for i in 32:                      # the floor rules turn many points down in a wood: try more of them
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(NEAR.x, NEAR.y)
		var c := p.global_position + Vector3(cos(a), 0.0, sin(a)) * r
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(c + Vector3.UP * 60.0, c + Vector3.DOWN * 60.0, Layers.WORLD))
		if hit.is_empty():
			continue
		var g: Vector3 = hit.position
		if LightGrid.is_lit(g) or absf(g.y - p.global_position.y) > 12.0:
			continue
		# fair ground (no haven, town, water or lava; off the hub's roads); a procession walks a way, so only its
		# file's head may stand on one, and never near Hearthward; and a floor a body stands on (no lip, slope, rock)
		if not Director.fair_ground(g, k == "procession") or not WorldLanes.site_at(Vector2(g.x, g.z), 0.8).is_empty():
			continue
		if not SpawnRules.ok(space, g, {"ways": k != "procession"}):
			continue
		return g
	return Vector3.INF


func _procession(p: Node3D) -> void:
	# a file of five walking a line through the place, toward the summit (the Crossing's north)
	var to_summit := Vector3(0.0, 0.0, -104.0) - _at
	to_summit.y = 0.0
	var dir := to_summit.normalized() if to_summit.length() > 1.0 else Vector3.FORWARD
	var route: Array[Vector3] = [_at - dir * 10.0, _at + dir * 25.0]
	for i in 5:
		var e: Enemy = _make(Wretch if i % 2 == 0 else Husk)
		e.set_meta(&"roam", kind)
		get_parent().add_child(e)
		e.global_position = _fair(_at - dir * (2.2 * float(i)), 2.5) + Vector3.UP * 0.1
		e.patrol.assign(route)
		e.roam = true
		e.patrol_speed = 1.1
		_foes.append(e)
	_need = 5
	Events.toast.emit("Singing on the road. A procession of the hollowed, walking to the Stair.")
	var _p := p


func _incursion() -> void:
	_need = 5
	for i in 5:
		var a := TAU * float(i) / 5.0 + _rng.randf() * 0.4
		var at := _at + Vector3(cos(a), 0.0, sin(a)) * 11.0
		var e: Enemy = _make(Wretch if i % 2 == 0 else Spitter)
		e.set_meta(&"roam", kind)
		get_parent().add_child(e)
		e.global_position = _fair(at, 5.0) + Vector3.UP * 0.1
		_foes.append(e)
	Events.toast.emit("The dark leans on a fire. Hollowed gather at the edge of its light.")


func _tick_foes() -> void:
	for i in range(_foes.size() - 1, -1, -1):
		if not is_instance_valid(_foes[i]) or not (_foes[i] as Enemy).is_alive():
			_foes.remove_at(i)
			_done_n += 1
	if is_instance_valid(_pin) and not _foes.is_empty():
		# the pin rides the file, not one body: killing the leader leaves it on the rest
		var sum := Vector3.ZERO
		var n := 0
		for f in _foes:
			if is_instance_valid(f):
				sum += (f as Node3D).global_position
				n += 1
		if n > 0:
			_pin.global_position = sum / float(n)
	if _done_n >= _need:
		_end(true)


func _tick_tear(delta: float) -> void:
	_tick_count_dead()
	if _done_n >= _need:
		_end(true)
		return
	_spawn_t -= delta
	if _spawn_t <= 0.0 and _foes.size() < 3 and _done_n + _foes.size() < _need:
		_spawn_t = 3.5
		var e: Enemy = _make(Crawler if _rng.randf() < 0.5 else Leaper)
		e.set_meta(&"roam", kind)
		get_parent().add_child(e)
		e.global_position = _ground(_at + Vector3(_rng.randf_range(-1.5, 1.5), 0.0, _rng.randf_range(-1.5, 1.5))) + Vector3.UP * 0.1
		_foes.append(e)
		Vfx.burst(_at + Vector3.UP * 1.4, Color(1.2, 0.6, 3.0), {"count": 30, "life": 0.6, "speed": Vector2(1.0, 4.0), "size": 0.05, "gravity": 0.0, "trail": 0.08})


func _tick_count_dead() -> void:
	for i in range(_foes.size() - 1, -1, -1):
		if not is_instance_valid(_foes[i]) or not (_foes[i] as Enemy).is_alive():
			_foes.remove_at(i)
			_done_n += 1


func _pilgrim() -> void:
	_need = 1
	for v in get_tree().get_nodes_in_group("villager"):
		_village = v.get("village")
		if _village:
			break
	if _village == null:
		return
	var w: Node3D = VillagerScript.new()
	w.call("setup", "lost_pilgrim", {"name": "A lost pilgrim", "camp": "roam", "fearless": true, "speed": 0.9, "routines": {},
		"rig": (PILGRIMS[_rng.randi_range(0, PILGRIMS.size() - 1)] as Dictionary).duplicate()}, _village)
	get_parent().add_child(w)
	w.remove_from_group(Groups.INTERACTABLE)
	w.remove_from_group("villager")          # not Hearthward's: they walk off its floor map
	w.global_position = _at
	w.call("hold", "kneel", _at + Vector3(0.0, 0.0, -104.0 - _at.z).normalized() * 3.0)
	_who = w
	Events.toast.emit("Someone is praying, out in the dark. A living voice.")


func _tick_pilgrim() -> void:
	if not is_instance_valid(_who):
		_end(false)
		return
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if _done_n == 0 and p and p.global_position.distance_to(_who.global_position) < 3.5:
		_done_n = 1
		_who.call("release")
		var home := _who.global_position + (_who.global_position - Vector3(0.0, 0.0, -104.0)).normalized() * 40.0
		home.y = _who.global_position.y
		_who.set("follow", home)
		Events.toast.emit("\"I was going up. I don't know why I was going up.\" The pilgrim turns round and walks home.  (+10 grave ash, +1 relic fragment)")
		Travel.give("grave_ash", 10, false)
		Travel.give("relic_fragment", 1, false)
		_t = LAST - 20.0                 # she walks a while, then the night takes her out of sight
		if is_instance_valid(_pin):
			_pin.queue_free()


func _end(won: bool) -> void:
	if won and kind != "pilgrim":
		var ash := {"procession": 14, "incursion": 12, "tear": 16}.get(kind, 10) as int
		Travel.give("grave_ash", ash, false)
		if kind == "tear":
			Travel.give("ember_shard", 2, false)
		Events.toast.emit({"procession": "The procession is broken. Nobody sings on the road.",
			"incursion": "The fire holds. The dark draws back from it.",
			"tear": "The tear closes like a mouth."}.get(kind, "It is over.") + "  (+%d grave ash)" % ash)
	if is_instance_valid(_pin):
		_pin.queue_free()
	if is_instance_valid(_who):
		_who.queue_free()
	_who = null
	for e in _foes:
		if is_instance_valid(e) and not won:
			(e as Node3D).set_meta(&"roam", "")
	_foes.clear()
	kind = ""
	_wait = _rng.randf_range(EVERY.x, EVERY.y) / ReachState.pressure()      # the dark presses harder act by act
	Travel.save_soon()


func _make_pin(k: String) -> void:
	_pin = Node3D.new()
	_pin.name = "RoamPin"
	_pin.set_meta(&"map_kind", "rare")
	_pin.set_meta(&"map_color", Color(1.0, 0.75, 0.35))
	_pin.set_meta(&"map_label", {"procession": "A procession", "incursion": "A fire under siege", "tear": "A rift tear", "pilgrim": "A living voice"}.get(k, "Something"))
	_pin.add_to_group("map_marker")
	get_parent().add_child(_pin)
	_pin.global_position = _at


## Fair ground near `at` (SpawnRules; the edge of a fire's light is allowed: the incursion stands there), else
## the plain ground under it.
func _fair(at: Vector3, reach: float) -> Vector3:
	var g := SpawnRules.find(get_viewport().world_3d.direct_space_state, Vector2(at.x, at.z), reach, at.y + 20.0, {"ways": false}, at.y, 4.0)
	return g if g != Vector3.INF else _ground(at)


func _ground(at: Vector3) -> Vector3:
	var space := get_viewport().world_3d.direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30.0, at + Vector3.DOWN * 30.0, Layers.WORLD))
	return (hit.position as Vector3) if not hit.is_empty() else at


func info() -> Dictionary:
	return {"kind": kind, "foes": _foes.size(), "done": _done_n, "need": _need, "wait": _wait}


func _make(cls: Variant) -> Enemy:
	return (cls as GDScript).new() as Enemy
