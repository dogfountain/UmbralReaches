extends Node
## THE WALK TO THE PILGRIMS' CHAPEL, driven by the real Player (its test drive: 0.3 m capsule, gravity, step-up): from the
## third tower's deck (with `-- --full`: from the Hearthward rim over the crossing) down the Pilgrims' Stair (rift/tower_stair.gd) and the quay,
## through the doorway to the kneeling stone. Waypoints are xz only (the Player keeps to the floor). Every waypoint
## must be reached within the time, the player's height at the end must be the chapel floor's, and the log shows the
## height at each. Never writes the save (Travel._busy).
## Ends: THRESHOLD WALK TEST PASS / FAIL (and prints "WALK reached <name> at <pos>")
const TowerStair := preload("res://core/world/realm/rift/tower_stair.gd")
const Chapel := preload("res://core/world/realm/rift/chapel.gd")

var main: Node
var player: Player
var fails := 0
var names: Array[String] = []
var reached := {}
var t := 0.0
var started := false
var _log_t := 0.0
var _diag_t := 0.0
var _markers: Array[Marker3D] = []
var _wp := 0
var _done := false
var _diag_done := false


func _ready() -> void:
	Travel._busy = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(delta: float) -> void:
	if main == null or not main.has_meta("realm_done"):
		return
	t += delta
	if not started:
		if t < 3.0:
			return
		started = true
		player = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		if player == null:
			print("THRESHOLD WALK TEST FAIL (no player)")
			get_tree().quit(1)
			return
		# the runner's 300 s holds the part below the third tower; `-- --full` walks the whole way from the rim (about 4 min)
		var full := "--full" in OS.get_cmdline_user_args()
		var pts: Array = []
		if full:
			pts = [["rim", Vector2(0, -4)], ["forecourt", Vector2(0, -9)], ["forecourt_top", Vector2(0, -13.5)], ["t1", Vector2(0, -21)]]
			pts.append(["viaduct_mid", Vector2(-6.5, -25.5)])
			pts.append(["t2", Vector2(-13, -30)])
			pts.append(["column_mid", Vector2(-7.4, -35.0)])
		pts.append(["t3", Vector2(-1.8, -40)])
		var sp := Vector2(-1.8, -40.0)
		pts.append(["t3_east", sp + Vector2(cos(deg_to_rad(-35.0)), sin(deg_to_rad(-35.0))) * 3.0])
		for i in range(0, TowerStair.N + 1, 2):
			var p := TowerStair.at(i)
			pts.append(["stair_%d" % i, Vector2(p.x, p.z)])
		pts.append(["foot", Vector2(-7.6, -40.0)])
		pts.append(["quay", Vector2(-10.5, -40.0)])
		pts.append(["forecourt", Vector2(-13.1, -40.0)])
		pts.append(["forecourt_door", Vector2(-13.1, -36.85)])
		pts.append(["door", Vector2(-14.9, -36.85)])
		pts.append(["stone", Vector2(-18.4, -36.85)])
		var markers: Array[Marker3D] = []
		for e: Array in pts:
			var m := Marker3D.new()
			m.name = e[0]
			m.set_meta("sprint", true)
			main.add_child(m)
			m.global_position = Vector3(e[1].x, 0.0, e[1].y)
			markers.append(m)
			names.append(e[0])
		var space := (main as Node3D).get_world_3d().direct_space_state
		var from := Vector3(0.0, 12.0, -3.0) if full else Vector3(-1.8, 12.0, -40.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3(0.0, -40.0, 0.0), Layers.WORLD))
		player.teleport((hit.position as Vector3) + Vector3.UP * 0.3 if not hit.is_empty() else from - Vector3(0.0, 10.0, 0.0))
		player._debug_drive = true            # the Player's own test drive (real step-up, gravity, capsule); autopilot skips step-up
		_markers = markers
		print("WALK start at ", player.global_position)
		return
	_diag_t += delta
	if _diag_t > 12.0 and not _diag_done:
		_diag_done = true
		var sp2 := (main as Node3D).get_world_3d().direct_space_state
		for dy in [0.02, 0.1, 0.2, 0.3, 0.4, 0.5, 0.7, 1.0]:
			var o := player.global_position + Vector3(0, dy, 0)
			var h := sp2.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + Vector3(0, 0, -3.0), Layers.WORLD))
			print("WALK diag y+%.2f -> %s" % [dy, "none" if h.is_empty() else "%s %s" % [(h.position as Vector3).snapped(Vector3.ONE * 0.05), (h.collider as Node).get_path()]])
	_log_t += delta
	if _log_t > 3.0:
		_log_t = 0.0
		print("WALK pos %s" % player.global_position.snapped(Vector3.ONE * 0.05))
	if not _done and _wp < _markers.size():
		var m := _markers[_wp]
		var to := m.global_position - player.global_position
		to.y = 0.0
		if to.length() < 0.7:
			reached[String(m.name)] = player.global_position
			print("WALK reached %s at %s" % [m.name, player.global_position.snapped(Vector3.ONE * 0.05)])
			_wp += 1
		else:
			player._debug_wish = to.normalized()
			player._debug_sprint = true
			player._yaw = atan2(-to.x, -to.z)
	if _wp >= _markers.size():
		player._debug_wish = Vector3.ZERO
		_done = true
	if t > 900.0 or _done:
		var last := names[names.size() - 1]
		for n in names:
			if not reached.has(n):
				print("WALK NOT reached ", n, " (player at ", player.global_position.snapped(Vector3.ONE * 0.05), ")")
				fails += 1
				break
		if reached.has(last):
			var y: float = (reached[last] as Vector3).y
			if absf(y - (-11.97 + 0.0)) > 1.0:
				print("WALK end height wrong ", y)
				fails += 1
		print("THRESHOLD WALK TEST ", "PASS" if fails == 0 else "FAIL %d" % fails)
		get_tree().quit(fails)
