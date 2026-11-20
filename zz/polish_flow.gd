extends Node
## The polish pass's flow capture (docs/r39/polish.md): what a player meets first, in order, at full size (1600 x 1000, windowed),
## through the real night's grade. Never writes the save (Travel._busy, UMBRAL_SAVE_DIR).
##   godot --path . res://zz/polish_flow.tscn -- --out=<dir> [--only=title,load,open,fight,death,travel,night] [--open-secs=48]
## Frames land in <out>/<step>_<n>.png:
##   title      the title screen after 2 s and after 5 s
##   load       the loading screen every second from the first frame of the night until the world is ready
##   open       the new game's opening shot (core/story/opening_shot.gd) every 3 s, then the first minute's HUD
##   fight      the first fight in the green: a wretch walks in, strikes (hurt wash), is struck (hit read), dies (the kill)
##   death      the wanderer is hollowed: the fade, the return to the fire, the fade in (every 0.3 s for 7 s)
##   travel     a flight along the Ember Road from the Sanctuary to the meadow fire (every 0.3 s for 7 s)
##   night      the night's summary page and the credits
const TitleScreen := preload("res://ui/title_screen.gd")
const FireRoad := preload("res://core/world/fire_road.gd")
const WIN := Vector2i(1600, 1000)

var out := "/tmp/polish_flow"
var only: Array = []
var main: Node
var p: Player
var n := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--only="):
			only = Array(a.trim_prefix("--only=").split(",", false))
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = WIN
	_run.call_deferred()


func _want(k: String) -> bool:
	return only.is_empty() or k in only


func _secs(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	n += 1


func _fail(why: String) -> void:
	print("POLISHFLOW FAIL ", why)


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	if _want("title"):
		var t := TitleScreen.new()
		add_child(t)
		await _secs(2.0)
		await _shot("title_0")
		await _secs(3.0)
		await _shot("title_1")
		t.queue_free()
		await _secs(0.4)
	Travel.story = {}
	Travel.items = {}
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child(main)
	var i := 0
	while is_instance_valid(main) and not main.has_meta("realm_done") and Time.get_ticks_msec() - t0 < 150000:
		if _want("load"):
			await _shot("load_%02d" % i)
		i += 1
		await _secs(1.0)
	p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	if p == null:
		_fail("no player")
		get_tree().quit(1)
		return
	print("POLISHFLOW world ready after %.1f s, %d load frames" % [(Time.get_ticks_msec() - t0) * 0.001, i])
	if _want("open"):
		var secs := 48.0
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--open-secs="):
				secs = float(a.trim_prefix("--open-secs="))
		var k := 0
		var t1 := Time.get_ticks_msec()
		while (Time.get_ticks_msec() - t1) * 0.001 < secs:
			await _shot("open_%02d" % k)
			k += 1
			await _secs(3.0)
		await _secs(6.0)
		await _shot("open_hud_a")
		await _secs(8.0)
		await _shot("open_hud_b")
	else:
		await _secs(6.0)
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		(e as Node).queue_free()
	if _want("fight"):
		await _fight()
	if _want("death"):
		await _death()
	if _want("travel"):
		await _travel()
	if _want("night"):
		await _night()
	print("POLISHFLOW done, %d frames, %.1f s" % [n, (Time.get_ticks_msec() - t0) * 0.001])
	get_tree().quit()


func _fight() -> void:
	var fwd := -p.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var e := (load("res://core/enemy/wretch.gd") as GDScript).new() as Enemy
	main.add_child(e)
	e.global_position = p.global_position + fwd * 9.0 + Vector3.UP * 0.2
	e.home = e.global_position
	e.wake()
	if e.has_method("on_engaged"):
		e.call("on_engaged", p)
	for k in 7:
		await _secs(0.5)
		await _shot("fight_walk_%d" % k)
	e.global_position = p.global_position + fwd * 1.6
	await _secs(0.2)
	p.vitals.take_wound(16.0, e.global_position)
	for k in 5:
		await _shot("fight_hurt_%d" % k)
		await _secs(0.12)
	if is_instance_valid(e):
		e.take_hit(9.0, p)
	for k in 5:
		await _shot("fight_hit_%d" % k)
		await _secs(0.1)
	if is_instance_valid(e):
		e.take_hit(99999.0, p)
	for k in 8:
		await _secs(0.35)
		await _shot("fight_kill_%d" % k)


func _death() -> void:
	p.vitals.hollow()
	for k in 24:
		await _shot("death_%02d" % k)
		await _secs(0.3)


func _travel() -> void:
	var a: Brazier = null
	var b: Brazier = null
	for br in get_tree().get_nodes_in_group(Groups.BRAZIER):
		if br.name == "Sanctuary":
			a = br as Brazier
		elif br.name == "StairFoot":
			b = br as Brazier
	if a == null or b == null:
		_fail("no fires to travel between")
		return
	if not b.lit:
		b._set_lit(true, false)
	var f: Node = FireRoad.travel(a, b)
	if f == null:
		_fail("the flight did not start")
		return
	for k in 26:
		await _shot("travel_%02d" % k)
		await _secs(0.3)


func _night() -> void:
	var np := NightPanel.panel(get_tree())
	if np == null:
		_fail("no night panel")
		return
	np.show_summary()
	await _secs(2.5)
	await _shot("night_summary")
	np.close()
	await _secs(1.0)
	np.show_credits()
	await _secs(4.0)
	await _shot("night_credits_0")
	await _secs(6.0)
	await _shot("night_credits_1")
