extends Node
## Life captures in the real night (windowed): several frames per view so motion shows, the wanderer held well
## behind the camera (so nothing flees the camera itself) unless --player-at says where she stands.
##   godot --path . res://zz/life_reach_shots.tscn -- --out=<dir> [--tag=x] [--frames=4] [--gap=0.5] [--kindle]
##       --view=name:cx:cy:cz:tx:ty:tz      cy / ty metres over the ground
##       [--player-at=x:z]                  (else 70 m behind the first view's camera, kept there)
##       [--walk=name:ax:az:bx:bz:secs]     the camera walks the way from a to b at eye height, frames spread over it
##       [--party=name:i:dist:up:side]      the camera keeps `dist` m from wayfarer party i's leader (Wayfarers), `up` m
##                                          up, `side` degrees round from behind it, looking at the party
##       [--keep-enemies]                   (else every hollowed thing is removed before each view)
##       [--howl]                           call the howls at the first view (life_signs.gd call_howl)
## Writes <out>/<name>_<tag>_<i>.png; prints LIFESHOT lines and LIFESHOTS done.
const Footing := preload("res://core/world/footing.gd")
var p: Player
var main: Node
var views: Array = []
var vi := -1
var fi := 0
var wait := 0
var out := "/tmp/life_shots"
var tag := "x"
var frames := 4
var gap := 0.5
var kindle := false
var keep_enemies := false
var howl := false
var player_at := Vector2.INF
var t := 0
var cam: Camera3D
var _next := 0.0
var _clock := 0.0
var _walk_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a.begins_with("--frames="):
			frames = int(a.trim_prefix("--frames="))
		elif a.begins_with("--gap="):
			gap = float(a.trim_prefix("--gap="))
		elif a == "--kindle":
			kindle = true
		elif a == "--keep-enemies":
			keep_enemies = true
		elif a == "--howl":
			howl = true
		elif a.begins_with("--player-at="):
			var g := a.trim_prefix("--player-at=").split(":")
			player_at = Vector2(float(g[0]), float(g[1]))
		elif a.begins_with("--view="):
			var f := a.trim_prefix("--view=").split(":")
			views.append({"name": f[0], "a": Vector3(float(f[1]), float(f[2]), float(f[3])), "b": Vector3(float(f[4]), float(f[5]), float(f[6]))})
		elif a.begins_with("--party="):
			var g3 := a.trim_prefix("--party=").split(":")
			views.append({"name": g3[0], "party": int(g3[1]), "dist": float(g3[2]), "up": float(g3[3]), "side": float(g3[4])})
		elif a.begins_with("--walk="):
			var w := a.trim_prefix("--walk=").split(":")
			views.append({"name": w[0], "walk": true, "a": Vector2(float(w[1]), float(w[2])), "b": Vector2(float(w[3]), float(w[4])), "secs": float(w[5])})
	get_window().size = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _ground(x: float, z: float) -> float:
	return Footing.terrain_y((main as Node3D).get_world_3d().direct_space_state, x, z, 0.0)


func _process(d: float) -> void:
	t += 1
	_clock += d
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if not main.has_meta("realm_done") or t < 600:
		return
	(p.get_node("Visual") as Node3D).visible = false
	if not keep_enemies:
		for n in get_tree().get_nodes_in_group(Groups.ENEMY):
			(n as Node).queue_free()
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if String(c.name) != "Grade":
			(c as CanvasLayer).visible = false
	if kindle:
		kindle = false
		for n in get_tree().root.find_children("*", "Brazier", true, false):
			(n as Brazier).kindle_quiet()
	if cam == null:
		cam = Camera3D.new()
		cam.fov = 70.0
		cam.near = 0.08
		add_child(cam)
		cam.make_current()
	if vi < 0:
		_start(0)
		return
	var v: Dictionary = views[vi]
	if v.has("walk"):
		_walk_t += d
		_place_walk(v, minf(_walk_t / float(v.secs), 1.0))
	elif v.has("party"):
		_place_party(v)
	_hold_player(v)
	if wait > 0:
		wait -= 1
		if wait == 0:
			_next = _clock
		return
	if _clock < _next:
		return
	var path := out.path_join("%s_%s_%d.png" % [v.name, tag, fi])
	RenderingServer.force_draw(false)          # (a covered window is not redrawn on its own: the frame would repeat)
	get_viewport().get_texture().get_image().save_png(path)
	print("LIFESHOT ", path)
	fi += 1
	var span := gap
	if v.has("walk"):
		span = float(v.secs) / float(maxi(frames - 1, 1))
	_next = _clock + span
	if fi >= frames:
		if vi + 1 >= views.size():
			print("LIFESHOTS done")
			get_tree().quit()
			return
		_start(vi + 1)


func _start(i: int) -> void:
	vi = i
	fi = 0
	_walk_t = 0.0
	var v: Dictionary = views[vi]
	if v.has("walk"):
		_place_walk(v, 0.0)
	elif v.has("party"):
		_place_party(v)
	else:
		var a: Vector3 = v.a
		var b: Vector3 = v.b
		cam.global_position = Vector3(a.x, _ground(a.x, a.z) + a.y, a.z)
		cam.look_at(Vector3(b.x, _ground(b.x, b.z) + b.y, b.z), Vector3.UP)
	_hold_player(v)
	wait = 90 if i > 0 else 150
	if howl and i == 0:
		var w := main.get_node_or_null("Wildlife")
		if w != null and w.get("signs") != null:
			(w.get("signs") as Node).call("call_howl", cam.global_position)


func _place_walk(v: Dictionary, k: float) -> void:
	var a: Vector2 = v.a
	var b: Vector2 = v.b
	var q := a.lerp(b, k)
	var dir := (b - a).normalized()
	cam.global_position = Vector3(q.x, _ground(q.x, q.y) + 1.7, q.y)
	var ahead := q + dir * 12.0
	cam.look_at(Vector3(ahead.x, _ground(ahead.x, ahead.y) + 1.3, ahead.y), Vector3.UP)


func _place_party(v: Dictionary) -> void:
	var w := main.get_node_or_null("Wayfarers")
	if w == null:
		return
	var ps: Array = w.get("parties")
	if int(v.party) >= ps.size():
		return
	var party: Dictionary = ps[int(v.party)]
	var q: Vector2 = w.call("_lead_xz", party)
	var ahead: Vector2 = w.call("_pos", party, float(party.s) + 6.0)
	var fwd := (ahead - q).normalized() if ahead.distance_to(q) > 0.5 else Vector2(0, -1)
	var back := -fwd.rotated(deg_to_rad(float(v.side)))
	var e := q + back * float(v.dist)
	var target := Vector3(q.x, _ground(q.x, q.y) + 1.1, q.y)
	cam.global_position = Vector3(e.x, _ground(e.x, e.y) + float(v.up), e.y)
	if cam.global_position.distance_to(target) > 0.5:
		cam.look_at(target, Vector3.UP)
	if fi == 0 and wait == 1:
		print("LIFESHOT party %d %s at %s state %d" % [int(v.party), party.name, q, int(party.state)])


func _hold_player(v: Dictionary) -> void:
	var at := player_at
	if v.has("walk"):
		var q: Vector3 = cam.global_position
		at = Vector2(q.x, q.z)              # walking: she is the one walking
	elif at == Vector2.INF:
		var back := cam.global_basis.z
		at = Vector2(cam.global_position.x + back.x * 70.0, cam.global_position.z + back.z * 70.0)
	p.global_position = Vector3(at.x, _ground(at.x, at.y) + 0.5, at.y)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
