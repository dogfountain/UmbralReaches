extends Node
## r33 world captures (windowed): the carved discovery banner (region, then a subzone), an ember-post
## by a lit fire, the Ember Road menu, the flight (mid-arc and the landing), and a gloom surge from
## off-site and broken open. In memory only (saves held, the Journal not written).
##   HOME=<scratch>/home godot --path . res://zz/world_r33_shots.tscn -- --out=<dir>
const CodexStore := preload("res://core/world/realm/lore/codex_store.gd")
const FireRoad := preload("res://core/world/fire_road.gd")

var p: Player
var main: Node
var out := "/tmp"
var started := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	CodexStore.persist = false
	CodexStore.reset()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	get_window().size = Vector2i(1600, 900)
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(_d: float) -> void:
	if started:
		return
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if not main.has_meta("realm_done") or main.get_node_or_null("Discovery") == null:
		return
	started = true
	_run()


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	var path := out.path_join("world_r33_%s.png" % n)
	get_viewport().get_texture().get_image().save_png(path)
	print("R33SHOT ", path)


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true).timeout


func _clear_foes() -> void:
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()


func _stand(at: Vector3, look: Vector3, pitch := -0.12) -> void:
	p.teleport(at)
	var d := look - at
	p.set_view(atan2(-d.x, -d.z), pitch)


func _run() -> void:
	await _wait(9.0)                                  # the loading screen and the night's title card
	var we := main.get_node("WorldEvents")
	we.set("auto", false)
	var disc := main.get_node("Discovery")
	_clear_foes()
	# 1. the chapel, discovered
	var space := p.get_world_3d().direct_space_state
	var ch := Vector3(-60.0, 0.0, 58.0)
	ch.y = RealmLayout.ground(space, ch.x, ch.z) + 0.2
	_stand(ch, Vector3(-72.0, 3.0, 52.0))
	await _wait(1.0)
	disc.call("visit", ch)
	await _wait(2.2)
	await _shot("banner_region")
	await _wait(4.5)
	# 2. a subzone: the Almonry
	var host: Node3D = null
	for h in get_tree().get_nodes_in_group("world_poi"):
		if String(h.get_meta("poi")) == "almonry":
			host = h
	var c: Vector3 = host.get_meta("centre")
	var alm: Vector3 = host.get_meta("approach", c + Vector3(0, 0, 10))
	alm = c + Vector3(alm.x - c.x, 0.0, alm.z - c.z).normalized() * 15.0
	CodexStore.discover("road")                       # only the spot's own banner
	CodexStore.discover("fen")
	disc.set("region", "road")
	alm.y = RealmLayout.ground(space, alm.x, alm.z) + 0.2
	_stand(alm, c + Vector3.UP * 2.0, -0.05)
	await _wait(1.0)
	disc.call("visit", c)
	await _wait(2.4)
	await _shot("banner_subzone")
	await _wait(5.0)
	# 3. a lit fire and its ember-post
	var shrine := main.get_node("Zone/Braziers/Shrine") as Brazier
	var landing := main.get_node("Zone/Braziers/Landing") as Brazier
	shrine.kindle_quiet()
	landing.kindle_quiet()
	_clear_foes()
	var post := shrine.get_node("EmberPost") as Node3D
	var view := shrine.global_position + shrine.global_basis * Vector3(-1.0, 0.0, 4.5)
	view.y = RealmLayout.ground(space, view.x, view.z) + 0.2
	_stand(view, (shrine.global_position + post.global_position) * 0.5 + Vector3.UP * 1.0, -0.1)
	await _wait(2.5)
	await _shot("ember_post")
	# 4. the menu
	_stand(shrine.spawn_point(), shrine.global_position)
	await _wait(0.6)
	FireRoad.open(shrine)
	await _wait(0.4)
	await _shot("road_menu")
	(main.get_node("FireRoad") if main.get_node_or_null("FireRoad") else get_tree().current_scene.get_node("FireRoad")).call("close")
	await _wait(0.3)
	# 5. the flight
	_clear_foes()
	var f := FireRoad.travel(shrine, landing)
	if f:
		var dur := float(f.get("dur"))
		await _wait(dur * 0.18)
		await _shot("flight_rise")
		await _wait(dur * 0.32)
		await _shot("flight_mid")
		await _wait(dur * 0.5 + 1.6)
		await _shot("flight_landed")
	else:
		print("R33SHOT flight refused: ", FireRoad.blocked_reason(get_tree()))
	# 6. a gloom surge at the Belfry, seen from the fen path, then broken open
	we.call("start_event", "belfry")
	var bel := Vector3(64.0, 0.0, -6.0)
	bel.y = RealmLayout.ground(space, bel.x, bel.z) + 0.2
	_stand(bel, Vector3(82.0, 8.0, -18.0), 0.05)
	await _wait(3.0)
	await _shot("surge_far")
	await _wait(3.0)
	var near := Vector3(76.0, 0.0, -4.0)
	near.y = RealmLayout.ground(space, near.x, near.z) + 0.2
	_stand(near, Vector3(82.0, 3.0, -18.0), -0.05)
	we.call("arrive")
	await _wait(2.5)
	await _shot("surge_open")
	we.call("win_now")
	await _wait(1.6)
	await _shot("surge_broken")
	print("R33SHOTS done")
	get_tree().quit()
