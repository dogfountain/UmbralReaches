extends Node
## --camps / --towns (zz/perf_tour.gd): the camps-and-villages run (r39 camps and villages perf pass, 21 Nov).
##   camps   for each camp in CAMPS: stand 120 m out on its far side from Hearthward, then cross it at a sprint (or a
##           gallop, "ride") straight through its centre and 60 m past; the foes are left awake (as in play), so
##           they rise, wake, call and fight as the wanderer passes. Guardians, elites and rares are among them.
##   towns   for each town in TOWNS: on a horse 150 m out, gallop to its centre, stop and turn the camera round once
##           (4 s), then gallop 60 m out the far side.
## A window starts after a 1.5 s settle at each start (the teleport's own frames are not play). Prints per window:
##   "CAMPS <name> <part> frames <n> fps <f> 1%low <l> worst <ms> over16 <n> nudges <n>" and, for every frame over 16 ms,
##   "CAMPS slow <name> <ms> at <m> from the centre, scripts <ms> draws <n>"; with --hitches=16 --probe the tour adds
##   what each slow frame did. "CAMPS summary" / "TOWNS summary" close the run. The wanderer cannot die (the tour clears
##   Gloom and Wounds every frame). A run stuck on a rock or a wall is carried 5 m on (a "nudge": counted).
## --camps=a,b / --towns=a,b: only those.

const HorseScript := preload("res://core/world/mount/horse.gd")
const SLOW_MS := 16.0
const SETTLE := 1.5
const HUB := Vector2(4.0, 36.0)

## [name, centre xz, how: "foot" | "ride"]. Spread over the Realm's regions and kinds: war bands, nests, patrols,
## risen graves (pilgrims), guardians' places (their escorts), two elites' haunts, the Far Reaches.
const CAMPS := [
	["thornwood_warband", Vector2(-152, -38), "foot"],
	["east_way", Vector2(43, -6), "foot"],
	["barrow_field", Vector2(99, -34), "foot"],
	["quarry_benches", Vector2(-120, -102), "foot"],       # the benches and the Stonewright's floor
	["founders_pits", Vector2(135, -94), "foot"],          # the furnace mouth and the Bell-Founder
	["orchard_nest", Vector2(-80, 142), "foot"],
	["waiting_graves", Vector2(-8, 141), "foot"],          # the pilgrims' graves and the Vigil-Keeper
	["mere_east", Vector2(133, 110), "foot"],              # the bank and the Drowned Deacon
	["siege_lines", Vector2(-240, 168), "foot"],
	["white_pans", Vector2(246, 118), "foot"],
	["keeps_gate", Vector2(-310, -78), "foot"],            # the keep's gate, the fell watch and the Castellan
	["stone_row", Vector2(-310, 142), "foot"],             # the stone row's pilgrims and the Barrow-King
	["elite_hobb", Vector2(48, 73), "foot"],
	["elite_old_sunk", Vector2(86, 26), "foot"],
	["downs_patrol", Vector2(-120, 214), "ride"],
	["arches_valley", Vector2(30, 368), "ride"],
	["moor_north", Vector2(141, -51), "ride"],
	["ford_road", Vector2(-212, 314), "ride"],
]
## [name, centre xz, approach from (unit xz: the side the road comes in)]
const TOWNS := [
	["hearthward", Vector2(2, 36), Vector2(1, 0.25)],
	["weirford", Vector2(-203, 66), Vector2(1, 0)],
	["saltmarket", Vector2(213, 95), Vector2(-1, 0)],
	["lastlight", Vector2(326, 46), Vector2(-1, 0.3)],
	["fallowmere", Vector2(-158, 300), Vector2(1, -0.4)],
	["reedholm", Vector2(-324, 298), Vector2(1, 0)],
]

var tour: Node
var p: Player
var main: Node
var name_now := ""
var _ft := PackedFloat32Array()
var _rec := false
var _horse: Node3D
var _nudges := 0
var _centre := Vector3.ZERO
var _all: Array = []                    ## [name, part, worst, over16] per window
var _towns_all: Array = []


func _process(d: float) -> void:
	p.gloom = 0.0
	p.wounds = 0.0
	if not _rec:
		return
	_ft.append(d)
	var ms := d * 1000.0
	if ms > SLOW_MS:
		var flat := Vector2(p.global_position.x - _centre.x, p.global_position.z - _centre.z).length()
		print("CAMPS slow %s %.1f ms at %.0f m from the centre, scripts %.1f ms draws %d" % [name_now, ms, flat,
			float(tour.get("_proc_us")) / 1000.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


static func _want(arg: String) -> PackedStringArray:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(arg + "="):
			return a.trim_prefix(arg + "=").split(",")
	return PackedStringArray()


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var camps_on := "--camps" in args or not _want("--camps").is_empty()
	var towns_on := "--towns" in args or not _want("--towns").is_empty()
	if camps_on:
		var only := _want("--camps")
		for c: Array in CAMPS:
			if only.is_empty() or String(c[0]) in only:
				await _camp(String(c[0]), c[1] as Vector2, String(c[2]) == "ride")
		_summary("CAMPS", _all)
	if towns_on:
		var only_t := _want("--towns")
		for t: Array in TOWNS:
			if only_t.is_empty() or String(t[0]) in only_t:
				await _town(String(t[0]), t[1] as Vector2, (t[2] as Vector2).normalized())
		_summary("TOWNS", _towns_all)
	tour.call("_finish")


func _ground(xz: Vector2) -> Vector3:
	return Vector3(xz.x, RealmLayout.ground(p.get_world_3d().direct_space_state, xz.x, xz.y) + 0.15, xz.y)


func _put(at: Vector3, yaw: float) -> void:
	if _horse != null and is_instance_valid(_horse):
		_horse.call("dismount")
		_horse.queue_free()
		_horse = null
		await _wait(0.3)
	p.debug_drive(Vector3.ZERO)
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	p.set_view(yaw, -0.06)


func _mount() -> void:
	var h: Node3D = HorseScript.new()
	h.set("breed", "palfrey")
	main.add_child(h)
	h.global_position = p.global_position + p.global_basis.x * 1.6
	_horse = h
	await _wait(0.6)
	h.call("mount", p)


## From `from` along `dir` for `length` metres at a sprint (or gallop on a horse), kept on the line; recorded.
func _run(from: Vector3, dir: Vector2, length: float, label: String) -> void:
	var yaw := atan2(-dir.x, -dir.y)
	var t0 := Time.get_ticks_msec()
	var last_s := 0.0
	var last_t := t0
	_rec = true
	while true:
		await get_tree().physics_frame
		var here := Vector2(p.global_position.x - from.x, p.global_position.z - from.z)
		var s := here.dot(dir)
		if s >= length or Time.get_ticks_msec() - t0 > 45000:
			break
		var ahead := Vector2(from.x, from.z) + dir * (s + 8.0)
		var wish := Vector2(ahead.x - p.global_position.x, ahead.y - p.global_position.z).normalized()
		p.debug_drive(Vector3(wish.x, 0.0, wish.y), true)
		p.set_view(yaw, -0.06)
		if Time.get_ticks_msec() - last_t > 1000:
			if s - last_s < 1.5:                     # stuck on a rock, a wall, a bank: carried 5 m on
				var on := _ground(Vector2(from.x, from.z) + dir * (s + 5.0))
				if _horse != null and is_instance_valid(_horse):
					_horse.global_position = on
					_horse.reset_physics_interpolation()
				else:
					p.global_position = on
					p.reset_physics_interpolation()
				_nudges += 1
			last_s = s
			last_t = Time.get_ticks_msec()
	_rec = false
	p.debug_drive(Vector3.ZERO)
	_report(label)


func _report(part: String) -> void:
	var st: Array = tour.call("frame_stats", _ft)
	var over := 0
	for x in _ft:
		if x * 1000.0 > SLOW_MS:
			over += 1
	print("CAMPS %-18s %-5s frames %4d fps %6.1f 1%%low %6.1f worst %5.1f ms over16 %d nudges %d" % [name_now, part, _ft.size(),
		float(st[0]), float(st[1]), float(st[3]), over, _nudges])
	var row := [name_now, part, float(st[3]), over, float(st[0]), float(st[1])]
	if part == "pass":
		_all.append(row)
	else:
		_towns_all.append(row)
	_ft = PackedFloat32Array()
	_nudges = 0


func _camp(n: String, c: Vector2, ride: bool) -> void:
	name_now = n
	var dir := (HUB - c).normalized() if c.distance_to(HUB) > 1.0 else Vector2(1, 0)
	_centre = _ground(c)
	var start := _ground(c + dir * 120.0)
	var yaw := atan2(dir.x, dir.y)                 # facing the camp (back along -dir)
	await _put(start, yaw)
	if ride:
		await _mount()
	await _wait(SETTLE)
	await _run(start, -dir, 180.0, "pass")


func _town(n: String, c: Vector2, side: Vector2) -> void:
	name_now = n
	_centre = _ground(c)
	var start := _ground(c + side * 150.0)
	await _put(start, atan2(side.x, side.y))
	await _mount()
	await _wait(SETTLE)
	await _run(start, -side, 150.0, "in")
	# stopped at the centre: the camera turned round once, as a player looks about
	_rec = true
	var t := 0.0
	var yaw0 := atan2(side.x, side.y)
	while t < 4.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		p.set_view(yaw0 + TAU * clampf(t / 4.0, 0.0, 1.0), -0.08)
	_rec = false
	_report("turn")
	var here := Vector3(p.global_position.x, 0.0, p.global_position.z)
	await _run(here, -side, 60.0, "out")


func _summary(tag: String, rows: Array) -> void:
	var worst := 0.0
	var over := 0
	var at := ""
	for r: Array in rows:
		over += int(r[3])
		if float(r[2]) > worst:
			worst = float(r[2])
			at = "%s %s" % [r[0], r[1]]
	print("%s summary: %d windows, worst frame %.1f ms (%s), frames over 16 ms %d" % [tag, rows.size(), worst, at, over])
