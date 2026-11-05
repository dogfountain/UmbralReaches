extends Node
## Real-mix renders of game moments (critique D, r29). Run under Godot's Movie Maker so the audio is
## the engine's own mix (every bus, its volume, reverb, low-pass, 3D attenuation and panning) at a
## fixed 60 fps, written next to the video:
##   godot --path . --write-movie /abs/out.avi --fixed-fps 60 --resolution 480x270 \
##       res://zz/critD_mix.tscn -- [--only=village,fen,...] [--secs=1.0]
## Then: ffmpeg -i out.avi -vn out.wav  (the marks printed as "MIX mark <name> <start s> <end s>"
## cut it into moments). Moments: village, rest (by the spawn fire), heath, wood, fen, storm (heath,
## a near crack and a far roll), drizzle (wood), fight (two wretches and a husk, bolts, a nova and a
## lance), tavern. Holds Travel._busy; quits by itself (real-time cap).
const RL := preload("res://core/world/realm/realm_land.gd")
const MOMENTS := ["village", "rest", "heath", "wood", "fen", "storm", "drizzle", "fight", "tavern"]
const LEN := {"village": 14.0, "rest": 16.0, "heath": 12.0, "wood": 12.0, "fen": 14.0, "storm": 16.0, "drizzle": 10.0, "fight": 16.0, "tavern": 14.0}

var main: Node
var p: Player
var amb: Node
var wild: Node
var wx: Node
var started := false
var only: Array = []
var k := 1.0
var marks: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = Array(a.trim_prefix("--only=").split(","))
		elif a.begins_with("--secs="):
			k = float(a.trim_prefix("--secs="))
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(_d: float) -> void:
	if Time.get_ticks_msec() > 900000:
		print("MIX TIMEOUT")
		get_tree().quit(1)
		return
	if started:
		# camps keep spawning hollowed things (one killed the wanderer mid-render): only ours stay
		_clear_enemies()
		if p != null and is_instance_valid(p):
			p.set("gloom", 0.0)
		return
	if main == null or not main.has_meta("realm_done") or main.get_node_or_null("Wildlife") == null:
		return
	p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	if p == null:
		return
	started = true
	_run()


func _now() -> float:
	return float(Engine.get_process_frames()) / 60.0


func _secs(s: float) -> void:
	var f := Engine.get_process_frames() + int(s * 60.0)
	while Engine.get_process_frames() < f:
		await get_tree().process_frame


func _put(at: Vector3, yaw := 0.0) -> void:
	var y := RealmLayout.ground(p.get_world_3d().direct_space_state, at.x, at.z)
	p.teleport(Vector3(at.x, maxf(y, at.y) + 0.2, at.z))
	p.velocity = Vector3.ZERO
	p.set_view(yaw, -0.1)
	await get_tree().process_frame


func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		if not (e as Node).has_meta("mix_own") and not (e as Node).is_queued_for_deletion():
			(e as Node).queue_free()


func _run() -> void:
	amb = main.get_node_or_null("Ambience")
	wild = main.get_node_or_null("Wildlife")
	wx = wild.get_meta("weather") if wild != null and wild.has_meta("weather") else null
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if String(c.name) != "Grade":
			(c as CanvasLayer).visible = false
	_clear_enemies()
	if wx != null:
		wx.force("clear", true)
	await _secs(2.0)
	for m: String in MOMENTS:
		if not only.is_empty() and m not in only:
			continue
		_clear_enemies()
		var t0 := _now()
		match m:
			"village": await _m_village()
			"rest": await _m_rest()
			"heath": await _m_heath()
			"wood": await _m_wood()
			"fen": await _m_fen()
			"storm": await _m_storm()
			"drizzle": await _m_drizzle()
			"fight": await _m_fight()
			"tavern": await _m_tavern()
		await _secs(float(LEN[m]) * k)
		var t1 := _now()
		marks.append([m, t0, t1])
		print("MIX mark %s %.2f %.2f scape %s music %s" % [m, t0, t1, amb.get("scape") if amb else "-", (amb.get("music").get("state") if amb and amb.get("music") else "-")])
		if wx != null:
			wx.force("clear", true)
		var mu: Node = amb.get("music") if amb else null
		if mu:
			mu.set("forced", "")
	print("MIX DONE ", marks)
	get_tree().quit(0)


func _m_village() -> void:
	await _put(Vector3(8, 0, 42), 0.6)


func _m_rest() -> void:
	var lit: Node3D = null
	for n in get_tree().get_nodes_in_group(Groups.INTERACTABLE):
		if n is Brazier and (n as Brazier).lit:
			lit = n
			break
	if lit != null:
		await _put(lit.global_position + Vector3(2.5, 0, 1.5))
	var mu: Node = amb.get("music") if amb else null
	if mu:
		mu.set("forced", "rest")
		mu.set("_note_t", 1.5)


func _m_heath() -> void:
	await _put(Vector3(-30, 0, 66), 1.2)


func _m_wood() -> void:
	await _put(Vector3(-62, 0, -40), 0.3)


func _m_fen() -> void:
	await _put(Vector3(75, 0, -20), -1.0)


func _m_storm() -> void:
	await _put(Vector3(-30, 0, 66), 1.2)
	if wx == null:
		return
	wx.force("storm", true)
	wx.set("_thunder_t", 999.0)
	await _secs(1.5)
	wx.strike_near(260.0, 0.4)
	await _secs(7.0)
	wx.strike_near(1100.0, -1.0)


func _m_drizzle() -> void:
	await _put(Vector3(-62, 0, -40), 0.3)
	if wx != null:
		wx.force("drizzle", true)


func _m_fight() -> void:
	await _put(Vector3(8, 0, 48), 0.94)
	var at := p.global_position
	var fwd := Vector3(-sin(0.94), 0.0, -cos(0.94))
	var husk_path := "res://core/enemy/husk.gd"
	var target := (load(husk_path) as GDScript).new() as Node3D
	target.set_meta("mix_own", true)
	main.add_child(target)
	var tp := at + fwd * 10.0
	tp.y = RealmLayout.ground(p.get_world_3d().direct_space_state, tp.x, tp.z) + 0.1
	target.global_position = tp
	target.set("max_hp", 99999)
	target.set("hp", 99999.0)
	target.set_physics_process(false)
	for i in 2:
		var w := (load("res://core/enemy/wretch.gd") as GDScript).new() as Node3D
		w.set_meta("mix_own", true)
		main.add_child(w)
		var q := at + fwd.rotated(Vector3.UP, 0.7 * (1.0 if i == 0 else -1.0)) * 9.0
		q.y = RealmLayout.ground(p.get_world_3d().direct_space_state, q.x, q.z) + 0.1
		w.global_position = q
		w.set("home", q)
		if w.has_method("wake"):
			w.call("wake")
	var book: Node = null
	for c in p.get_children():
		if c is SkillBook:
			book = c
	if book == null:
		return
	book.set("using_pad", true)
	var acts := (book.get("slots") as Array)
	# bolts for 5 s, a nova, more bolts, a lance
	Input.action_press(acts[0].action)
	await _secs(5.0)
	Input.action_release(acts[0].action)
	book.call("try_cast", 2, 0.0, false)
	await _secs(1.5)
	Input.action_press(acts[0].action)
	await _secs(3.0)
	Input.action_release(acts[0].action)
	Input.action_press(acts[1].action)
	await _secs(1.3)
	Input.action_release(acts[1].action)
	p.set("gloom", 0.0)


func _m_tavern() -> void:
	await _put(Vector3(18.0, 0.6, 30.2), 1.6)
