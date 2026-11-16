extends Node
## World-walk perf for the living Realm (docs/living_realm.md), windowed, vsync off, no frame cap:
##   godot --path . --disable-vsync res://zz/life_walk_perf.tscn [-- --no-life-reaches --no-wayfarers]
## The wanderer jogs (4.5 m/s) a fixed route along the ways through the Far Reaches and the Marches, the game's own
## camera behind her; every frame's time is kept. Prints "WALKPERF frames n mean ms p50 p95 p99 worst, life us,
## wayfarers us, people near" and "WALKPERF done". Run with and without the life (the flags) in alternation.
const ROUTE := [Vector2(-152, 296), Vector2(-196, 298), Vector2(-236, 302), Vector2(-266, 306), Vector2(-292, 304), Vector2(-316, 296),
	Vector2(-318, 272), Vector2(-320, 232), Vector2(-318, 190), Vector2(-320, 150), Vector2(-318, 110), Vector2(-326, 80), Vector2(-330, 52),
	Vector2(-300, 56.4), Vector2(-255, 62), Vector2(-232, 64), Vector2(-205, 66), Vector2(-180, 66), Vector2(-150, 67)]
const SPEED := 4.5
var p: Player
var main: Node
var t := 0
var leg := 0
var along := 0.0
var frames := PackedFloat32Array()
var life_us := 0.0
var way_us := 0.0
var near_people := 0
var n := 0
var started := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	Engine.max_fps = 0
	get_window().size = Vector2i(1600, 1000)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	t += 1
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if not main.has_meta("realm_done") or t < 900:
		return
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		(e as Node).queue_free()
	if not started:
		started = true
		_place(ROUTE[0], ROUTE[1])
		return
	if leg >= ROUTE.size() - 1:
		_report()
		return
	var a: Vector2 = ROUTE[leg]
	var b: Vector2 = ROUTE[leg + 1]
	along += SPEED * minf(d, 0.05)
	if along >= a.distance_to(b):
		along -= a.distance_to(b)
		leg += 1
		if leg >= ROUTE.size() - 1:
			return
		a = ROUTE[leg]
		b = ROUTE[leg + 1]
	_place(a.lerp(b, along / a.distance_to(b)), b)
	frames.append(d * 1000.0)
	var w := main.get_node_or_null("Wildlife")
	if w != null:
		life_us += float(w.get("perf_us"))
	var wf := main.get_node_or_null("Wayfarers")
	if wf != null:
		way_us += float(wf.get("perf_us"))
		for party: Dictionary in wf.get("parties"):
			if bool(party.near):
				near_people += (party.people as Array).size()
	n += 1


func _place(q: Vector2, toward: Vector2) -> void:
	var y := RealmLayout.ground(p.get_world_3d().direct_space_state, q.x, q.y)
	p.global_position = Vector3(q.x, y + 0.1, q.y)
	p.velocity = Vector3.ZERO
	var dir := (toward - q).normalized()
	p.rotation.y = atan2(-dir.x, -dir.y)


func _report() -> void:
	set_process(false)
	var s := frames.duplicate()
	s.sort()
	var k := s.size()
	var mean := 0.0
	for f in frames:
		mean += f
	mean /= maxf(float(k), 1.0)
	print("WALKPERF frames %d mean %.2f ms p50 %.2f p95 %.2f p99 %.2f worst %.1f | life %.0f us, wayfarers %.0f us, people near %.1f (args %s)" % [k, mean, s[k / 2], s[int(k * 0.95)], s[int(k * 0.99)], s[k - 1], life_us / maxf(n, 1), way_us / maxf(n, 1), float(near_people) / maxf(n, 1), " ".join(OS.get_cmdline_user_args())])
	print("WALKPERF done")
	get_tree().quit()
