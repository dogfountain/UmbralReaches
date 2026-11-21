extends Node
## --moments (zz/perf_tour.gd): the play moments a cold shader cache meets once, each its own measured window:
##   map      the world map opened and held, then closed
##   mount    a horse called beside the wanderer, mounted, ridden at a trot and a gallop, got down
##   fight    the first fight: five kinds of foe woken in front of the wanderer, who casts every slotted spell at them
##   spells   every other spell (one of each school), swapped into a slot and cast at the foes
##   travel   the Ember Road: from one lit fire to another (both kindled quietly first), and the landing
## Prints "MOMENT <name> frames <n> worst <ms> over16 <n> PSO <kinds>" per window (the pipeline counters' delta);
## PsoWatch names each compile frame under "moments:<name>". Calls tour._finish() at the end.

const HorseScript := preload("res://core/world/mount/horse.gd")
const FireRoad := preload("res://core/world/fire_road.gd")
const PsoWatch := preload("res://zz/pso_watch.gd")
const WorldMap := preload("res://ui/world_map.gd")
const FIGHT_AT := Vector3(-39.4, NAN, 8.7)              ## the west way into the wood (out of Hearthward's ward)
const FIGHT_YAW := 1.9                                   ## west, along the way
const EXTRA := ["res://core/skills/skill_familiar.gd", "res://core/skills/skill_tether.gd", "res://core/skills/skill_well.gd",
	"res://core/skills/skill_peal.gd", "res://core/skills/skill_sealed.gd", "res://core/skills/skill_lance.gd"]

var tour: Node
var p: Player
var main: Node
var name_now := ""
var _frames := 0
var _worst := 0.0
var _over := 0
var _pso0: PackedInt64Array = []
var _foes: Array[Node] = []
var map_open := false


func _process(d: float) -> void:
	if name_now == "":
		return
	_frames += 1
	_worst = maxf(_worst, d * 1000.0)
	if d * 1000.0 > PsoWatch.SLOW_MS:
		_over += 1
	p.gloom = 0.0
	p.wounds = 0.0


func _begin(n: String) -> void:
	name_now = n
	_frames = 0
	_worst = 0.0
	_over = 0
	_pso0 = PsoWatch._counts()


func _end() -> void:
	var now := PsoWatch._counts()
	var parts := PackedStringArray()
	var sum := 0
	for k in now.size():
		var dk := now[k] - _pso0[k]
		sum += dk
		if dk > 0:
			parts.append("%s+%d" % [PsoWatch.KINDS[k], dk])
	print("MOMENT %-7s frames %d worst %.1f ms over16 %d PSO %s" % [name_now, _frames, _worst, _over, " ".join(parts) if sum > 0 else "none"])
	name_now = ""


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _stand(at: Vector3, yaw: float) -> void:
	if is_nan(at.y):
		at.y = RealmLayout.ground(p.get_world_3d().direct_space_state, at.x, at.z) + 0.15
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	p.set_view(yaw, -0.08)


func run() -> void:
	await _map()
	await _mount()
	await _fight()
	await _spells()
	_clear_foes()
	await _travel()
	tour.call("_finish")


func _map() -> void:
	var wm := get_tree().get_first_node_in_group(&"world_map") as WorldMap
	_begin("map")
	if wm != null:
		var until := Time.get_ticks_msec() + 8000
		while not wm.is_baked() and Time.get_ticks_msec() < until:
			await get_tree().process_frame
		map_open = true
		wm.open()
		await _wait(1.5)
		wm.close()
		map_open = false
	await _wait(1.0)
	_end()


func _mount() -> void:
	_stand(Vector3(26.0, NAN, 40.0), PI * 0.5)
	await _wait(0.5)
	_begin("mount")
	var h: Node3D = HorseScript.new()
	h.set("breed", "palfrey")
	main.add_child(h)
	h.global_position = p.global_position + p.global_basis.x * 1.6
	await _wait(0.6)
	h.call("mount", p)
	await _wait(1.8)
	var fwd := -p.global_basis.z
	fwd.y = 0.0
	p.debug_drive(fwd.normalized() * 0.6)
	await _wait(2.0)
	p.debug_drive(fwd.normalized(), true)
	await _wait(3.0)
	p.debug_drive(Vector3.ZERO)
	await _wait(1.0)
	h.call("dismount")
	await _wait(1.0)
	_end()
	h.queue_free()


func _fight() -> void:
	_stand(FIGHT_AT, FIGHT_YAW)
	await _wait(1.0)
	_begin("fight")
	var fwd := Vector3(-sin(FIGHT_YAW), 0.0, -cos(FIGHT_YAW))
	var right := fwd.cross(Vector3.UP)
	var kinds: Array[GDScript] = [Husk, Spitter, Leaper, Wretch, Crawler]
	for k in kinds.size():
		var e := kinds[k].new() as Node3D
		e.set_meta(&"tour_awake", true)
		main.add_child(e)
		var at := p.global_position + fwd * 9.0 + right * (float(k) - 2.0) * 1.8
		at.y = RealmLayout.ground(p.get_world_3d().direct_space_state, at.x, at.z) + 0.1
		e.global_position = at
		_foes.append(e)
	await _wait(1.5)
	var sb := p.skills()
	for i in sb.slots.size():
		if sb.slots[i] == null:
			continue
		sb.reset_cooldowns()
		sb.press(i)
		await _wait(0.9)
	await _wait(2.5)
	_end()


func _spells() -> void:
	_begin("spells")
	var sb := p.skills()
	var keep: Skill = sb.slots[1] if sb.slots.size() > 1 else null
	for path: String in EXTRA:
		if not ResourceLoader.exists(path):
			continue
		var s := (load(path) as GDScript).new() as Skill
		if s == null:
			continue
		sb.set_slot(1, s)
		sb.reset_cooldowns()
		sb.press(1)
		await _wait(1.2)
	if keep != null:
		sb.set_slot(1, keep)
	await _wait(1.5)
	_end()


func _clear_foes() -> void:
	for e in _foes:
		if is_instance_valid(e):
			e.queue_free()
	_foes.clear()


func _travel() -> void:
	var fires: Array[Brazier] = []
	for n in get_tree().get_nodes_in_group(Groups.BRAZIER):
		if n is Brazier and (n as Brazier).is_inside_tree():
			fires.append(n as Brazier)
	if fires.size() < 2:
		print("MOMENT travel skipped: %d fires" % fires.size())
		return
	var home := Vector3(0.0, 0.0, 30.0)                   # from Hearthward's own fire to the farthest one
	fires.sort_custom(func(a: Brazier, b: Brazier) -> bool: return a.global_position.distance_squared_to(home) < b.global_position.distance_squared_to(home))
	var from := fires[0]
	var to := fires[fires.size() - 1]
	from.kindle_quiet()
	to.kindle_quiet()
	_stand(from.spawn_point(), 0.0)
	await _wait(6.0)                                     # out of the fight's reach and its combat state
	_stand(from.spawn_point(), 0.0)
	_begin("travel")
	var f := FireRoad.travel(from, to)
	if f == null:
		print("MOMENT travel refused (%s)" % FireRoad.blocked_reason(get_tree()))
	else:
		var until := Time.get_ticks_msec() + 20000
		while is_instance_valid(f) and Time.get_ticks_msec() < until:
			await get_tree().process_frame
	await _wait(4.0)
	_end()
