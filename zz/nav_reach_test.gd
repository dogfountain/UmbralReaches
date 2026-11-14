extends Node
## Navigation reach: the one runtime mesh (core/world/realm/realm_nav.gd) connects the road to every place
## the night sends the wanderer or its foes: the boss arenas, the Ossuary's gallery and abbot, the Gloom Surge
## pins, and the way out of the crypt to the Sanctuary.  godot --headless --path . res://zz/nav_reach_test.tscn
## Each path (NavigationServer3D.map_get_path on the shared map) must end within REACH_M of its target.
## Ends: NAVREACH PASS / NAVREACH FAIL n
const REACH_M := 2.5
## [label, from, to]; points are x,z on the ground (y is snapped to the mesh).
const PAIRS: Array = [
	["road to the Thornwarden arena", Vector2(0, 33), Vector2(-86, -24)],
	["road to the Ossuary gallery seal pin", Vector2(0, 33), Vector2(-16.0, 174.0)],
	["road to the Bone Abbot", Vector2(0, 33), Vector2(6.0, 168.0)],
	["road to the gallery door (over the bone bridge)", Vector2(0, 33), Vector3(-21.5, 1.0, 173.0)],
	["road to the pit floor (down the gallery stair)", Vector2(0, 33), Vector3(12.0, -3.2, 167.0)],
	["gallery door to the Sanctuary", Vector3(-21.5, 1.0, 173.0), Vector2(0, 33)],
	["road to the Counting Door", Vector2(0, 33), Vector2(10.0, 179.0)],
	["road to the west Gloom Surge pin", Vector2(0, 33), Vector2(-190, 66)],
	["road to the far north-west landmark", Vector2(0, 33), Vector2(-126, -101)],
	["road to the Thorn seal", Vector2(0, 33), Vector2(-61, -7)],
]
var fails := 0
var main: Node


func ok(c: bool, what: String) -> void:
	print(("NAVREACH PASS " if c else "NAVREACH FAIL ") + what)
	if not c:
		fails += 1


func _ready() -> void:
	Travel._busy = true
	main = (load("res://world/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(main)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 180000:
		await get_tree().process_frame
		if main.has_meta("realm_done") and bool(RealmNav.info.get("ready", false)):
			break
	for i in 40:
		await get_tree().physics_frame
	t0 = Time.get_ticks_msec()
	while not NavAssist.ready() and Time.get_ticks_msec() - t0 < 20000:
		await get_tree().physics_frame
	ok(NavAssist.ready(), "the nav map is up")
	var map := NavAssist.map
	for pr: Array in PAIRS:
		var a := _snap(_pt(pr[1]))
		var b := _pt(pr[2])
		var path := NavAssist.path(a, b)
		var gap := 1e9
		var end := Vector3.ZERO
		if path.size() >= 1:
			end = path[path.size() - 1]
			gap = Vector2(end.x - b.x, end.z - b.z).length()
		print("NAVREACH probe %s: from %s to %s ends %s gap %.1f m, %d points, closest mesh point %s" % [pr[0], a, b, end, gap, path.size(), NavigationServer3D.map_get_closest_point(map, b)])
		ok(gap <= REACH_M, "%s (ends %.1f m short)" % [pr[0], gap])
	print("NAVREACH %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	get_tree().quit(0 if fails == 0 else 1)


func _pt(v: Variant) -> Vector3:
	if v is Vector3:
		return v
	return _ground(v as Vector2)


func _ground(v: Vector2) -> Vector3:
	var space := (main as Node3D).get_world_3d().direct_space_state
	return Vector3(v.x, RealmLayout.ground(space, v.x, v.y), v.y)


func _snap(v: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(NavAssist.map, v)
