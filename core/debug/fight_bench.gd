extends Node
## A heavy fight, measured (the night's harness starts it: core/debug/main_harness.gd, so packed builds run it too).
##   <game> -- --fight-bench --fps-log [--boss=thornwarden|bone_abbot|anchoress|warden|none] [--n=10] [--secs=20] [--no-cast]
##       [--slow=11] [--quit]   (--quit: leave after the report; the frame cap is lifted for the measured fight)
## The night is built, the wanderer stands on open ground, a boss and N grunts are spawned round him and come at
## him, and every spell slot is pressed over and over (cooldowns reset). He cannot die (his wounds are cleared).
## At the end "FIGHT" prints the frame times and the engine monitors averaged over the fight; --ab-enemies then
## measures the foes' thinking (far, near), the spells, drawing the foes and the HUD by switching each off for a
## few seconds; --hud-ab measures the HUD in alternating windows and each of its widgets taken away in turn;
## --hud-draws counts which HUD canvas items redraw during the fight.
const Tiers := preload("res://core/life/encounters/tiers.gd")
const HudPrefs := preload("res://ui/hud_prefs.gd")
const SPOT := Vector2(62.0, 60.0)
const BOSSES := {"thornwarden": "res://core/enemy/thornwarden.gd", "bone_abbot": "res://core/enemy/bone_abbot.gd",
	"anchoress": "res://core/enemy/anchoress.gd", "warden": "res://core/enemy/ascended_warden.gd"}
const KINDS := ["wretch", "husk", "spitter", "ossuant", "leaper", "crawler"]

var main: Node
var p: Player
var t := 0
var started := false
var boss := "thornwarden"
var n := 10
var secs := 20.0
var cast := true
var immortal := "--immortal" in OS.get_cmdline_user_args()    ## the foes are healed as they are hit: the fight stays the same size (for A/B windows)
var micro := "--micro" in OS.get_cmdline_user_args()          ## 5 s in: each effect call timed on its own (us a call)
var _press := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]   ## per slot: usec in press(), presses
var cap := 0                   ## --cap=120: the frame cap during the measured fight (0 = none)
var slow_ms := 22.0            ## --slow=11: frames over this are listed with what happened before them
var _frames_ms := PackedFloat32Array()
var _mon := {}
var _book: SkillBook
var _ev: Array = []            ## [usec, text]: what happened in the fight, to set beside the slow frames
var _slow: Array = []          ## [usec, ms]
var _fight_t0 := 0


## Brackets every node's _process / _physics_process in a frame (first and last in line), as PerfWatch does, but
## kept per frame: where each frame's time went, so the slow frames can be set beside the ordinary ones.
class Mark extends Node:
	var cb: Callable
	var phys := false
	func _process(_d: float) -> void:
		if not phys:
			cb.call()
	func _physics_process(_d: float) -> void:
		if phys:
			cb.call()


var _seg := PackedFloat32Array()      ## per frame, SEG_N values (ms): see SEG
const SEG := ["frame", "idle scripts", "physics scripts", "ticks", "step+nav", "to pre-draw", "draw", "rest", "cast call", "nodes added", "nodes freed", "tweens",
	"deferred", "xf+free+timers", "tweens run", "sync"]
const SEG_N := 16
## the time before the draw, cut at three more marks: a deferred call queued by the last script (it runs after every
## deferred call of the frame), the bench's own first tween (after the transform flush, the delete queue and the
## timers), and a deferred call queued from that tween (after the tweens and what they deferred)
var _m_def := 0
var _m_tw := 0
var _m_def2 := 0
var _f_cast := 0.0                    ## usec in the bench's own press() this frame (it runs from a timer: after the scripts)
var _f_added := 0
var _f_freed := 0
var _m_i0 := 0                        ## first idle script
var _m_i1 := 0                        ## last idle script
var _m_p0 := 0
var _m_pre := 0
var _m_post := 0                      ## the last frame's post-draw
var _f_phys := 0.0
var _f_ticks := 0
var _f_step := 0.0
var _m_pe := 0
var _drawn0 := 0


func _marks() -> void:
	RenderingServer.frame_pre_draw.connect(func() -> void: _m_pre = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(_frame_done)
	var marks := [
		[-2000000000, true, func() -> void:
			_m_p0 = Time.get_ticks_usec()
			if _m_pe > 0:
				_f_step += _m_p0 - _m_pe],                 # the step between two ticks of one frame
		[2000000000, true, func() -> void:
			_m_pe = Time.get_ticks_usec()
			_f_phys += _m_pe - _m_p0
			_f_ticks += 1],
		[-2000000000, false, func() -> void:
			_m_i0 = Time.get_ticks_usec()
			if _m_pe > 0:
				_f_step += _m_i0 - _m_pe
			_m_pe = 0],
		[2000000000, false, func() -> void:
			_m_i1 = Time.get_ticks_usec()
			_mark_def.call_deferred()]]
	var tw := create_tween()
	tw.tween_method(func(_v: float) -> void:
		_m_tw = Time.get_ticks_usec()
		_mark_def2.call_deferred(), 0.0, 1.0, 1.0e6)
	for m: Array in marks:
		var nd := Mark.new()
		nd.cb = m[2]
		nd.phys = m[1]
		nd.process_mode = Node.PROCESS_MODE_ALWAYS
		if m[1]:
			nd.process_physics_priority = m[0]
		else:
			nd.process_priority = m[0]
		get_tree().root.add_child.call_deferred(nd)


func _mark_def() -> void:
	_m_def = Time.get_ticks_usec()


func _mark_def2() -> void:
	_m_def2 = Time.get_ticks_usec()


func _frame_done() -> void:
	var now := Time.get_ticks_usec()
	if _m_post > 0 and _m_i1 > 0 and _seg.size() < 800000:
		var frame := float(now - _m_post)
		var idle := float(_m_i1 - _m_i0)
		var pre := float(_m_pre - _m_i1)
		var draw := float(now - _m_pre)
		for v: float in [frame, idle, _f_phys, float(_f_ticks) * 1000.0, _f_step, pre, draw, frame - idle - _f_phys - _f_step - pre - draw,
				_f_cast, float(_f_added) * 1000.0, float(_f_freed) * 1000.0, float(get_tree().get_processed_tweens().size()) * 1000.0,
				float(_m_def - _m_i1), float(_m_tw - _m_def), float(_m_def2 - _m_tw), float(_m_pre - _m_def2)]:
			_seg.append(v / 1000.0)
	_m_post = now
	_f_cast = 0.0
	_f_added = 0
	_f_freed = 0
	_f_phys = 0.0
	_f_ticks = 0
	_f_step = 0.0


## The fight's frames in bands by frame time (the quick half, the middle, the slow tenth, the slowest 3%): the mean
## of each part of the frame in each band. What the slow frames have more of is what makes them slow.
func _seg_report() -> void:
	var nf := _seg.size() / SEG_N
	if nf < 40:
		return
	var order: Array = range(nf)
	order.sort_custom(func(a: int, b: int) -> bool: return _seg[a * SEG_N] < _seg[b * SEG_N])
	# busy: the frame's work, first script to after the draw (with a frame cap the rest is the limiter's sleep, and
	# a frame holds the cap's rate when its busy time fits one refresh)
	var busy := PackedFloat32Array()
	for k in nf:
		busy.append(_seg[k * SEG_N] - _seg[k * SEG_N + 7])
	# what the time before the draw goes with: its mean on frames with and without each thing
	for c: Array in [[8, "a cast"], [9, "nodes added"], [10, "nodes freed"], [3, "a physics tick"]]:
		var a := Vector2.ZERO
		var b0 := Vector2.ZERO
		for k in nf:
			if _seg[k * SEG_N + int(c[0])] > 0.0:
				a += Vector2(_seg[k * SEG_N + 5], 1.0)
			else:
				b0 += Vector2(_seg[k * SEG_N + 5], 1.0)
		print("FIGHT PRE-DRAW with %-15s %.2f ms (%d frames), without %.2f ms (%d frames)" % [c[1], a.x / maxf(a.y, 1.0), int(a.y), b0.x / maxf(b0.y, 1.0), int(b0.y)])
	busy.sort()
	var over := 0
	for v in busy:
		if v > 8.33:
			over += 1
	print("FIGHT BUSY median %.2f  p95 %.2f  p99 %.2f  over 8.33 ms %.1f%%  (cap %d)" % [busy[nf / 2], busy[int(nf * 0.95)], busy[int(nf * 0.99)], 100.0 * over / nf, Engine.max_fps])
	var bands := [["quick half", 0.0, 0.5], ["50-90%", 0.5, 0.9], ["90-97%", 0.9, 0.97], ["slowest 3%", 0.97, 1.0], ["all", 0.0, 1.0]]
	print("FIGHT PARTS %d drawn frames of %d process frames (%d drawn by the engine's count)" % [nf, _frames_ms.size(), Engine.get_frames_drawn() - _drawn0])
	print("FIGHT PARTS (ms a frame)    " + "  ".join(SEG.map(func(k: String) -> String: return "%11s" % k.left(11))))
	for b: Array in bands:
		var i0 := int(nf * float(b[1]))
		var i1 := maxi(int(nf * float(b[2])), i0 + 1)
		var sums := PackedFloat32Array()
		sums.resize(SEG_N)
		for k in range(i0, i1):
			for j in SEG_N:
				sums[j] += _seg[int(order[k]) * SEG_N + j]
		var row := PackedStringArray()
		for j in SEG_N:
			row.append("%11.2f" % (sums[j] / float(i1 - i0)))
		print("FIGHT PARTS %-14s " % b[0] + "  ".join(row))


## --script-cost: mid-fight, every processing script node's _process and _physics_process is called COST_REPS times
## in a row and timed; per script (all its nodes together) the cost of one frame and one tick, heaviest first.
## The calls run the real code (the fight moves on a little faster while it measures): cost, not behaviour.
const COST_REPS := 4
var _methods := {}


func _has(sc: Script, m: StringName) -> bool:
	if not _methods.has(sc):
		var names := {}
		for d: Dictionary in sc.get_script_method_list():
			names[StringName(d.name)] = true
		_methods[sc] = names
	return (_methods[sc] as Dictionary).has(m)


func _script_cost(label: String) -> void:
	var rows := {}                    # script file -> [nodes, idle us a frame, physics us a tick]
	for nd in get_tree().root.find_children("*", "", true, false):
		var sc := nd.get_script() as Script
		if nd == self or nd is Mark or sc == null or not nd.can_process():
			continue
		var idle := nd.is_processing() and _has(sc, &"_process")
		var phys := nd.is_physics_processing() and _has(sc, &"_physics_process")
		if not idle and not phys:
			continue
		var key := sc.resource_path.get_file()
		var row: Array = rows.get(key, [0, 0.0, 0.0])
		row[0] += 1
		for pass_i in 2:
			if (pass_i == 0 and not idle) or (pass_i == 1 and not phys):
				continue
			var t0 := Time.get_ticks_usec()
			var done := 0
			for k in COST_REPS:
				if not is_instance_valid(nd) or not nd.is_inside_tree():
					break
				if pass_i == 0:
					nd.call(&"_process", 1.0 / 120.0)
				else:
					nd.call(&"_physics_process", 1.0 / 60.0)
				done += 1
			row[1 + pass_i] += float(Time.get_ticks_usec() - t0) / maxf(float(done), 1.0)
		rows[key] = row
	var keys := rows.keys()
	var ti := 0.0
	var tp := 0.0
	for k: String in keys:
		ti += float(rows[k][1])
		tp += float(rows[k][2])
	print("FIGHT COST %s: scripts' _process %.2f ms a frame, _physics_process %.2f ms a tick, %d scripts" % [label, ti / 1000.0, tp / 1000.0, keys.size()])
	keys.sort_custom(func(a: String, b: String) -> bool: return float(rows[a][1]) + float(rows[a][2]) > float(rows[b][1]) + float(rows[b][2]))
	for k: String in keys.slice(0, 28):
		print("FIGHT COST %-28s %4d nodes  idle %7.1f us  physics %7.1f us" % [k, rows[k][0], rows[k][1], rows[k][2]])


func begin(night: Node) -> void:
	main = night
	process_mode = Node.PROCESS_MODE_ALWAYS
	_marks()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--boss="):
			boss = a.trim_prefix("--boss=")
		elif a.begins_with("--n="):
			n = int(a.trim_prefix("--n="))
		elif a.begins_with("--secs="):
			secs = float(a.trim_prefix("--secs="))
		elif a == "--no-cast":
			cast = false
		elif a.begins_with("--cap="):
			cap = int(a.trim_prefix("--cap="))
		elif a.begins_with("--slow="):
			slow_ms = float(a.trim_prefix("--slow="))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)     # the real cost, not the refresh cap


func _process(delta: float) -> void:
	t += 1
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if not started:
		if main != null and main.has_meta("realm_done") and t > 300:
			started = true
			_run()
		return
	if immortal and t % 6 == 0:
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			var en := e as Enemy
			if en != null and en.is_alive() and en.global_position.distance_squared_to(p.global_position) < 3600.0:
				en.hp = float(en.max_hp)
	if t % 240 == 0:                         # topped up now and then (every frame kept the HUD's numbers moving)
		p.wounds = 0.0
		p.gloom = 0.0
	if _frames_ms.size() < 100000:
		_frames_ms.append(delta * 1000.0)
		if _frames_ms.size() > 60 and delta * 1000.0 > slow_ms:
			_slow.append([Time.get_ticks_usec(), delta * 1000.0])


func _run() -> void:
	var space := (main as Node3D).get_world_3d().direct_space_state
	var gy := RealmLayout.ground(space, SPOT.x, SPOT.y)
	var base := Vector3(SPOT.x, gy, SPOT.y)
	p.teleport(base + Vector3(0, 0.3, 0))
	p.set_view(0.0, -0.08)                       # looking down -z, where they come from
	await _wait(2.0)
	if boss != "none":
		var bs := load(BOSSES.get(boss, BOSSES.thornwarden)) as GDScript
		var b := bs.new() as Enemy
		main.add_child(b)
		b.global_position = base + Vector3(0, 0.2, -16.0)
		b.home = b.global_position
		Events.boss_engaged.emit(b, boss.capitalize())        # its frame, as the arena would show it
	for i in n:
		var e := (load(Tiers.KIND_PATHS[KINDS[i % KINDS.size()]]) as GDScript).new() as Enemy
		main.add_child(e)
		var a := -PI * 0.5 + PI * float(i) / maxf(float(n - 1), 1.0)
		e.global_position = base + Vector3(cos(a) * 11.0, 0.3, -absf(sin(a)) * 11.0 - 3.0)
		e.home = e.global_position
	for c in p.find_children("*", "", true, false):
		if c is SkillBook:
			_book = c
			break
	print("FIGHT start: boss %s, %d grunts, casting %s" % [boss, n, cast])
	_fight_t0 = Time.get_ticks_usec()
	Events.enemy_killed.connect(func(e: Node) -> void: _note("killed " + String(e.name)))
	Events.skill_cast.connect(func(id: StringName) -> void: _note("cast " + String(id)))
	Events.enemy_cast_started.connect(func(e: Node, c: String, _t: float, _i: bool) -> void: _note("foe cast " + c))
	Events.status_changed.connect(func(_t: Node, id: StringName, st: int, _l: float) -> void: _note("status %s %d" % [id, st]))
	Events.item_gained.connect(func(id: String, _a: int, _tt: int) -> void: _note("item " + id))
	get_tree().node_added.connect(func(_nd: Node) -> void: _f_added += 1)
	get_tree().node_removed.connect(func(_nd: Node) -> void: _f_freed += 1)
	get_tree().node_added.connect(func(nd: Node) -> void:
		var par := nd.get_parent()
		if par == main or nd is Enemy or nd is OmniLight3D or nd is RigidBody3D:      # what is spawned into the night
			var sc := nd.get_script() as Script
			_note("added %s %s" % [nd.get_class(), sc.resource_path.get_file() if sc else ""]))
	# --hud-draws: which HUD canvas items redraw during the fight, and how often (a redraw is what a HUD costs)
	var draws := {}
	if "--hud-draws" in OS.get_cmdline_user_args():
		var hud := get_tree().root.find_child("HUD", true, false)
		if hud != null:
			for ci in hud.find_children("*", "CanvasItem", true, false):
				var key := String(hud.get_path_to(ci))
				(ci as CanvasItem).draw.connect(func() -> void: draws[key] = int(draws.get(key, 0)) + 1)
	Engine.max_fps = cap                         # 0: the whole spread (a cap at the screen's rate clips every frame under one refresh)
	_frames_ms.clear()
	_slow.clear()
	_seg.clear()
	_drawn0 = Engine.get_frames_drawn()
	var t0 := Time.get_ticks_msec()
	var slot := 0
	var cost_at := [6000, 13000] if "--script-cost" in OS.get_cmdline_user_args() else []
	while Time.get_ticks_msec() - t0 < int(secs * 1000.0):
		if cast and _book:
			var c0 := Time.get_ticks_usec()
			_book.reset_cooldowns()
			_book.press(slot % 4)                   # not slot 4 (Rift Step): it blinks the wanderer down the road
			_press[slot % 4] += Vector2(float(Time.get_ticks_usec() - c0), 1.0)
			slot += 1
			_f_cast += float(Time.get_ticks_usec() - c0)
		_sample()
		if micro and Time.get_ticks_msec() - t0 > 5000:
			micro = false
			_micro()
		if not cost_at.is_empty() and Time.get_ticks_msec() - t0 > int(cost_at[0]):
			_script_cost("%.0f s in" % (float(cost_at.pop_front()) / 1000.0))
		await get_tree().create_timer(0.12).timeout
	_report()
	_seg_report()
	if not draws.is_empty():
		var keys := draws.keys()
		keys.sort_custom(func(a: String, b: String) -> bool: return int(draws[a]) > int(draws[b]))
		var total := 0
		for k: String in keys:
			total += int(draws[k])
		print("FIGHT HUD redraws: %d over %d frames (%.1f a frame), %d items drew at all" % [total, _frames_ms.size(), float(total) / maxf(float(_frames_ms.size()), 1.0), keys.size()])
		for k: String in keys.slice(0, 24):
			print("FIGHT HUD redraw %5.2f a frame  %s" % [float(draws[k]) / maxf(float(_frames_ms.size()), 1.0), k])
	if "--parts-ab" in OS.get_cmdline_user_args():
		await _parts_ab()
		get_tree().quit()
		return
	if "--quit" in OS.get_cmdline_user_args():
		get_tree().quit()
		return
	if "--world-ab" in OS.get_cmdline_user_args():
		await _world_ab()
		get_tree().quit()
		return
	if "--hud-ab" in OS.get_cmdline_user_args():
		await _hud_ab()
		get_tree().quit()
		return
	if "--ab-enemies" in OS.get_cmdline_user_args():
		# the same fight with every foe's logic and physics frozen (still drawn): what the foes' thinking costs
		var fr: float = await _avg_frame(4.0)
		var far := 0
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			if (e as Node3D).global_position.distance_to(p.global_position) > 40.0:
				(e as Node).process_mode = Node.PROCESS_MODE_DISABLED
				far += 1
		var off_far: float = await _avg_frame(4.0)
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			(e as Node).process_mode = Node.PROCESS_MODE_DISABLED
		var off: float = await _avg_frame(4.0)
		print("FIGHT A/B all foes thinking %.2f ms | the %d far ones frozen %.2f ms (far cost %.2f) | all frozen %.2f ms (near cost %.2f)" % [fr, far, off_far, fr - off_far, off, off_far - off])
		# the spells' lights: every light the casting made (bolts, wards, wells) switched off
		var lit := 0
		for l in get_tree().root.find_children("*", "OmniLight3D", true, false):
			if String((l as Node).get_meta(&"light_class", "")) == "player_orb":
				(l as Light3D).visible = false
				lit += 1
		print("FIGHT %d player-orb lights at the moment" % lit)
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			(e as Node).process_mode = Node.PROCESS_MODE_INHERIT
		var none: float = await _avg_frame(3.0)
		cast = false
		var quiet: float = await _avg_frame(4.0)
		print("FIGHT A/B casting %.2f ms, not casting %.2f ms -> spells %.2f ms a frame" % [none, quiet, none - quiet])
		# what drawing them costs: every foe hidden (frozen too), then the HUD hidden as well
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			(e as Node).process_mode = Node.PROCESS_MODE_DISABLED
		var shown: float = await _avg_frame(4.0)
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			(e as Node3D).visible = false
		var hidden: float = await _avg_frame(4.0)
		var near_shown := 0
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			near_shown += 1 if (e as Node3D).global_position.distance_to(p.global_position) < 60.0 else 0
		print("FIGHT A/B foes drawn %.2f ms, hidden %.2f ms -> drawing foes %.2f ms (%d within 60 m)" % [shown, hidden, shown - hidden, near_shown])
		for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
			(c as CanvasLayer).visible = false
		var no_ui: float = await _avg_frame(4.0)
		print("FIGHT A/B HUD shown %.2f ms, hidden %.2f ms -> HUD %.2f ms" % [hidden, no_ui, hidden - no_ui])
		# the HUD's own pieces: each shown alone over the bare frame (the rest of the HUD hidden)
		var hud := get_tree().root.find_child("HUD", true, false) as CanvasLayer
		if hud:
			hud.visible = true
			var top: Node = hud                  # the HUD's widget root: the node with the most children
			for c in hud.find_children("*", "Control", true, false):
				if (c as Node).get_child_count() > top.get_child_count():
					top = c
			for k in hud.get_children():
				if k is CanvasItem:
					(k as CanvasItem).visible = true
			var kids: Array = []
			for k in top.get_children():
				if k is CanvasItem and (k as CanvasItem).visible:
					kids.append(k)
					(k as CanvasItem).visible = false
			var bare: float = await _avg_frame(3.0)
			for k: CanvasItem in kids:
				k.visible = true
				var w: float = await _avg_frame(2.5)
				k.visible = false
				print("FIGHT HUD part %-28s %+.2f ms  (%s, %d nodes)" % [k.name, w - bare, k.get_script().resource_path.get_file() if k.get_script() else k.get_class(), k.find_children("*", "", true, false).size()])


func _avg_frame(s: float) -> float:
	var n0 := Engine.get_process_frames()
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < int(s * 1.0e6):
		if cast and _book:
			_book.reset_cooldowns()
			_book.press(randi() % 4)
		await get_tree().create_timer(0.12).timeout
	return float(Time.get_ticks_usec() - t0) / 1000.0 / maxf(float(Engine.get_process_frames() - n0), 1.0)


func _note(t: String) -> void:
	_ev.append([Time.get_ticks_usec(), t])


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _sample() -> void:
	var m := {
		"process ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"prims k": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0,
		"enemies": float(get_tree().get_nodes_in_group(Groups.ENEMY).size()),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"physics active": Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
	}
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	m["render cpu ms"] = RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
	m["gpu ms"] = RenderingServer.viewport_get_measured_render_time_gpu(vp)
	for k: String in m:
		var arr: Array = _mon.get(k, [])
		arr.append(float(m[k]))
		_mon[k] = arr


func _report() -> void:
	# each slow frame (> --slow, 22 ms) with what happened in the 100 ms before it
	print("FIGHT slow frames (over %.1f ms): %d" % [slow_ms, _slow.size()])
	for sl: Array in _slow.slice(0, 25):
		var t: int = sl[0]
		var near: Dictionary = {}
		for ev: Array in _ev:
			if int(ev[0]) > t - 100000 and int(ev[0]) <= t:
				var k := String(ev[1]).left(60)
				near[k] = int(near.get(k, 0)) + 1
		print("FIGHT slow %6.2f s  %5.1f ms  %s" % [float(t - _fight_t0) / 1.0e6, sl[1], str(near)])
	# what the fight was made of: every noted event, counted
	var kinds := {}
	for ev: Array in _ev:
		if int(ev[0]) >= _fight_t0:
			kinds[ev[1]] = int(kinds.get(ev[1], 0)) + 1
	var ks := kinds.keys()
	ks.sort_custom(func(a: String, b: String) -> bool: return int(kinds[a]) > int(kinds[b]))
	for k: String in ks.slice(0, 24):
		print("FIGHT EVENT %5d  %s" % [kinds[k], k])
	for i in 4:
		var pr: Vector2 = _press[i]
		print("FIGHT PRESS slot %d (%s): %.0f us a press, %d presses" % [i, _book.slots[i] if _book and i < _book.slots.size() else "?", pr.x / maxf(pr.y, 1.0), int(pr.y)])
	var f := Array(_frames_ms)
	f.sort()
	var avg := 0.0
	for x: float in f:
		avg += x
	avg /= maxf(float(f.size()), 1.0)
	var p95: float = f[int(f.size() * 0.95)] if f.size() > 0 else 0.0
	var p99: float = f[int(f.size() * 0.99)] if f.size() > 0 else 0.0
	var med: float = f[f.size() / 2] if f.size() > 0 else 0.0
	print("FIGHT frames %d  avg %.2f ms (%.0f fps)  median %.2f  p95 %.2f  p99 %.2f  worst %.2f" % [f.size(), avg, 1000.0 / maxf(avg, 0.01), med, p95, p99, f.back() if f.size() > 0 else 0.0])
	# the spread: with V-Sync a frame that misses one refresh waits for the next, so the fps halves in steps
	if f.size() > 20:
		var qs := PackedStringArray()
		for q: float in [0.05, 0.25, 0.5, 0.75, 0.9]:
			qs.append("p%d %.2f" % [roundi(q * 100.0), f[int(f.size() * q)]])
		var hz := maxf(DisplayServer.screen_get_refresh_rate(DisplayServer.window_get_current_screen()), 30.0)
		var late := 0
		for x: float in f:
			if x > 1500.0 / hz:
				late += 1
		print("FIGHT spread %s | %d%% of frames took over 1.5 refreshes (%.0f Hz, vsync mode %d, max_fps %d)" % [", ".join(qs), roundi(100.0 * float(late) / float(f.size())), hz, DisplayServer.window_get_vsync_mode(), Engine.max_fps])
	for k: String in _mon:
		var arr: Array = _mon[k]
		var s := 0.0
		var mx := 0.0
		for x: float in arr:
			s += x
			mx = maxf(mx, x)
		print("FIGHT %-15s avg %8.2f  max %8.2f" % [k, s / maxf(float(arr.size()), 1.0), mx])


## The HUD's cost, alternating (on / off windows, so drift cancels), then each widget taken away from the full
## HUD in turn (on / without it / on ...): what removing it would save in play.
func _hud_ab() -> void:
	var hud := get_tree().root.find_child("HUD", true, false) as CanvasLayer
	if hud == null:
		return
	var on := 0.0
	var off := 0.0
	for i in 3:
		hud.visible = true
		on += await _avg_frame(4.0)
		hud.visible = false
		off += await _avg_frame(4.0)
	hud.visible = true
	print("FIGHT HUDAB whole HUD %.2f ms (on %.2f, off %.2f)" % [(on - off) / 3.0, on / 3.0, off / 3.0])
	var top: Node = hud
	for c in hud.find_children("*", "Control", true, false):
		if (c as Node).get_child_count() > top.get_child_count():
			top = c
	for k in top.get_children():
		if not (k is CanvasItem) or not (k as CanvasItem).visible:
			continue
		var ci := k as CanvasItem
		var with := 0.0
		var without := 0.0
		for i in 2:
			ci.visible = true
			with += await _avg_frame(3.0)
			ci.visible = false
			without += await _avg_frame(3.0)
		ci.visible = true
		print("FIGHT HUDAB %-24s %+.2f ms" % [ci.name, (with - without) / 2.0])


## What the world costs to draw (measurement only; everything is set back): each thing switched off for a few
## seconds, alternating with the normal frame. Half the 3D resolution says how much is pixels (GPU fill).
func _world_ab() -> void:
	var vp := get_viewport()
	var env: Environment = vp.get_camera_3d().get_world_3d().environment if vp.get_camera_3d() and vp.get_camera_3d().get_world_3d() else null
	var sun: DirectionalLight3D = null
	for l in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
		if (l as DirectionalLight3D).visible and (l as DirectionalLight3D).shadow_enabled:
			sun = l
	var tests: Array = [
		["half 3D resolution", func(on: bool) -> void: vp.scaling_3d_scale = (0.5 if on else 1.0) * _scale0],
		["sun shadows off", func(on: bool) -> void: if sun: sun.shadow_enabled = not on],
		["omni/spot lights hidden", func(on: bool) -> void: _toggle_class("Light3D", on, [sun])],
		["particles hidden", func(on: bool) -> void: _toggle_class("GPUParticles3D", on, [])],
		["multimeshes hidden", func(on: bool) -> void: _toggle_class("MultiMeshInstance3D", on, [])],
		["volumetric fog off", func(on: bool) -> void: if env: env.volumetric_fog_enabled = _vf0 and not on],
		["SSAO/SSIL off", func(on: bool) -> void: if env: env.ssao_enabled = _ao0 and not on; env.ssil_enabled = _il0 and not on],
		["glow off", func(on: bool) -> void: if env: env.glow_enabled = _gl0 and not on],
		["foes frozen", func(on: bool) -> void: _freeze(get_tree().get_nodes_in_group(Groups.ENEMY), on)],
		["other bodies frozen", func(on: bool) -> void: _freeze(get_tree().root.find_children("*", "CharacterBody3D", true, false).filter(func(n: Node) -> bool: return not n.is_in_group(Groups.ENEMY) and not n.is_in_group(Groups.PLAYER)), on)],
		["animation players off", func(on: bool) -> void: _freeze(get_tree().root.find_children("*", "AnimationPlayer", true, false) + get_tree().root.find_children("*", "AnimationTree", true, false), on)],
	]
	_scale0 = vp.scaling_3d_scale
	if env:
		_vf0 = env.volumetric_fog_enabled
		_ao0 = env.ssao_enabled
		_il0 = env.ssil_enabled
		_gl0 = env.glow_enabled
	print("FIGHT WORLD env fog %s ssao %s ssil %s glow %s sdfgi %s, 3D scale %.2f, sun shadows %s" % [_vf0, _ao0, _il0, _gl0, env.sdfgi_enabled if env else false, _scale0, sun != null])
	if "--mm-list" in OS.get_cmdline_user_args():
		_mm_list()
		return
	if "--world-cpu" in OS.get_cmdline_user_args():
		tests = tests.slice(8)
	for tst: Array in tests:
		var f: Callable = tst[1]
		var base := 0.0
		var off := 0.0
		for i in 2:
			base += await _avg_frame(3.0)
			f.call(true)
			off += await _avg_frame(3.0)
			f.call(false)
		print("FIGHT WORLD %-24s saves %+.2f ms (%.2f -> %.2f)" % [tst[0], (base - off) / 2.0, base / 2.0, off / 2.0])


## --parts-ab [--tests=a,b]: each thing switched off in alternating windows (3 pairs of 2.5 s), and what it does to
## each part of the frame (the mean of the parts over the windows with it on and with it off). Use with --immortal
## (the fight keeps its size) or with --boss=none --n=0 --no-cast (the quiet world).
func _parts_ab() -> void:
	var vp := get_viewport()
	var cam := vp.get_camera_3d()
	var env: Environment = cam.get_world_3d().environment
	var sun: DirectionalLight3D = null
	for l in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
		if (l as DirectionalLight3D).visible and (l as DirectionalLight3D).shadow_enabled:
			sun = l
	var hud := get_tree().root.find_child("HUD", true, false) as CanvasLayer
	var grade := main.get_node_or_null("Grade") as CanvasLayer
	_scale0 = vp.scaling_3d_scale
	var mask0 := cam.cull_mask
	var tests: Array = [
		["nothing (noise)", func(_on: bool) -> void: pass],
		["3D world not drawn", func(on: bool) -> void: cam.cull_mask = 0 if on else mask0],
		["half 3D resolution", func(on: bool) -> void: vp.scaling_3d_scale = (0.5 if on else 1.0) * _scale0],
		["sun shadows off", func(on: bool) -> void: sun.shadow_enabled = not on],
		["omni/spot lights hidden", func(on: bool) -> void: _toggle_class("Light3D", on, [sun])],
		["particles hidden", func(on: bool) -> void: _toggle_class("GPUParticles3D", on, [])],
		["multimeshes hidden", func(on: bool) -> void: _toggle_class("MultiMeshInstance3D", on, [])],
		["volumetric fog off", func(on: bool) -> void: env.volumetric_fog_enabled = not on],
		["SSAO off", func(on: bool) -> void: env.ssao_enabled = not on],
		["SSR off", func(on: bool) -> void: env.ssr_enabled = not on],
		["glow off", func(on: bool) -> void: env.glow_enabled = not on],
		["HUD hidden", func(on: bool) -> void: hud.visible = not on],
		["grade hidden", func(on: bool) -> void: grade.visible = not on],
		["motion blur off", func(on: bool) -> void: cam.compositor = null if on else _comp0],
		["foes frozen", func(on: bool) -> void: _freeze(_near_foes(), on)],
		["foes hidden", func(on: bool) -> void:
			for e: Node3D in _near_foes():
				e.visible = not on],
		["foes frozen+hidden", func(on: bool) -> void:
			_freeze(_near_foes(), on)
			for e: Node3D in _near_foes():
				e.visible = not on],
		["no casting", func(on: bool) -> void: cast = not on],
		["bolt streaks frozen", func(on: bool) -> void:
			for b in get_tree().root.find_children("*", "MagicBolt", true, false):
				b.set_process(not on)],
		["foe skins frozen", func(on: bool) -> void:
			for e: Node in _near_foes():
				for sk in e.find_children("GruntSkin", "", true, false):
					sk.set_process(not on)],
		["combat text off", func(on: bool) -> void: HudPrefs.combat_text = not on],
		["hit numbers hidden", func(on: bool) -> void: HitText.hush = on],
		["hotbar hidden", func(on: bool) -> void: (hud.find_child("Hotbar", true, false) as CanvasItem).visible = not on],
		["unit frames hidden", func(on: bool) -> void: (hud.find_child("UnitFrames", true, false) as CanvasItem).visible = not on],
		["minimap hidden", func(on: bool) -> void: (hud.find_child("Minimap", true, false) as CanvasItem).visible = not on],
		["villagers+horses frozen", func(on: bool) -> void: _freeze(get_tree().root.find_children("*", "CharacterBody3D", true, false).filter(func(nd: Node) -> bool: return not nd.is_in_group(Groups.ENEMY) and not nd.is_in_group(Groups.PLAYER)), on)],
	]
	_comp0 = cam.compositor
	var only := PackedStringArray()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tests="):
			only = a.trim_prefix("--tests=").split(",")
	print("FIGHT AB %-26s %s" % ["(ms a frame: off - on)", "  ".join(SEG.slice(0, 8).map(func(k: String) -> String: return "%11s" % k.left(11)))])
	for tst: Array in tests:
		var keep := only.is_empty()
		for o in only:
			if String(tst[0]).contains(o):
				keep = true
		if not keep:
			continue
		var f: Callable = tst[1]
		var on := PackedFloat32Array()
		var off := PackedFloat32Array()
		on.resize(SEG_N)
		off.resize(SEG_N)
		var n_on := 0
		var n_off := 0
		for i in 4:
			n_on += await _parts_window(2.5, on)
			f.call(true)
			await _avg_frame(0.3)
			n_off += await _parts_window(2.5, off)
			f.call(false)
			await _avg_frame(0.3)
		var row := PackedStringArray()
		for j in 8:
			row.append("%+11.2f" % (off[j] / maxf(n_off, 1.0) - on[j] / maxf(n_on, 1.0)))
		print("FIGHT AB %-26s %s   (frame %.2f -> %.2f)" % [tst[0], "  ".join(row), on[0] / maxf(n_on, 1.0), off[0] / maxf(n_off, 1.0)])


## --micro: what one call of each effect costs in script (the nodes it makes are drawn afterwards; that is not in it).
func _micro() -> void:
	var at := p.global_position + Vector3(0.0, 1.0, -6.0)
	var foe: Enemy = null
	for e: Enemy in _near_foes():
		if e.is_alive() and not e.boss:
			foe = e
			break
	var col := Color(1.6, 0.8, 3.4)
	var tests: Array = [
		["Vfx.burst (pooled)", func() -> void: Vfx.burst(at, col, {"count": 26, "life": 0.4, "speed": Vector2(2.5, 6.5), "size": 0.04, "gravity": -6.0, "trail": 0.08, "dir": Vector3.UP, "spread": 75.0})],
		["Vfx.ring", func() -> void: Vfx.ring(at, 1.25, col, 0.28, 0.18, Vector3.UP)],
		["Vfx.light", func() -> void: Vfx.light(at, col, 3.0, 4.0, 0.3, 3)],
		["Vfx.impact", func() -> void: Vfx.impact(at, col, Vector3.BACK, false)],
		["Vfx.impact big", func() -> void: Vfx.impact(at, col, Vector3.BACK, true)],
		["Vfx.scorch", func() -> void: Vfx.scorch(at, 1.2, col)],
		["SpellFx.shell", func() -> void: SpellFx.shell(at, 0.15, 0.85, col, 0.18)],
		["HitText.pop", func() -> void: HitText.pop(at, "12", Color.WHITE)],
		["EnemyAudio.hit", func() -> void: EnemyAudio.hit("flesh", at, 2.0, -2.0)],
		["Sfx.play_stream", func() -> void: Sfx.play_stream(Synth.get_stream("bone"), at, -2.0, 1.4)],
		["StaffSfx.play", func() -> void: StaffSfx.play("burn_hit", at, -4.0)],
	]
	if foe != null:
		tests.append(["Enemy.take_hit 1.0", func() -> void:
			foe.hp = float(foe.max_hp)
			foe.take_hit(1.0, p)])
		tests.append(["Enemy._physics_process", func() -> void: foe._physics_process(1.0 / 60.0)])
		tests.append(["Enemy._think", func() -> void: foe._think()])
	tests.append(["Player._physics_process", func() -> void: p._physics_process(1.0 / 60.0)])
	for tst: Array in tests:
		var f: Callable = tst[1]
		var n := 40
		var t0 := Time.get_ticks_usec()
		for i in n:
			f.call()
		print("FIGHT MICRO %-26s %7.1f us a call" % [tst[0], float(Time.get_ticks_usec() - t0) / float(n)])


const Synth := preload("res://core/vfx/synth.gd")
const StaffSfx := preload("res://core/vfx/staff_sfx.gd")


func _near_foes() -> Array:
	return get_tree().get_nodes_in_group(Groups.ENEMY).filter(func(e: Node) -> bool: return (e as Node3D).global_position.distance_squared_to(p.global_position) < 3600.0)


## Runs the fight for `s` seconds and adds each part's sum over those frames to `into`; returns the frames.
func _parts_window(s: float, into: PackedFloat32Array) -> int:
	var i0 := _seg.size() / SEG_N
	await _avg_frame(s)
	var i1 := _seg.size() / SEG_N
	for k in range(i0, i1):
		for j in SEG_N:
			into[j] += _seg[k * SEG_N + j]
	return i1 - i0


var _comp0: Compositor
var _scale0 := 1.0
var _vf0 := false
var _ao0 := false
var _il0 := false
var _gl0 := false
var _hidden: Array = []


func _freeze(nodes: Array, on: bool) -> void:
	for n in nodes:
		if is_instance_valid(n):
			(n as Node).process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
	if on:
		print("FIGHT WORLD   (%d frozen)" % nodes.size())


func _toggle_class(cls: String, hide: bool, skip: Array) -> void:
	if hide:
		_hidden.clear()
		for n in get_tree().root.find_children("*", cls, true, false):
			if n in skip or not (n as Node3D).visible:
				continue
			(n as Node3D).visible = false
			_hidden.append(n)
	else:
		for n in _hidden:
			if is_instance_valid(n):
				(n as Node3D).visible = true
		_hidden.clear()


## The MultiMeshes the camera can see: instances drawn x triangles of the mesh (LOD 0), heaviest first.
func _mm_list() -> void:
	var cam := get_viewport().get_camera_3d()
	var planes := cam.get_frustum()
	var rows: Array = []
	for n in get_tree().root.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := n as MultiMeshInstance3D
		if not mmi.is_visible_in_tree() or mmi.multimesh == null or mmi.multimesh.mesh == null:
			continue
		var box := mmi.global_transform * mmi.get_aabb()
		var inside := true
		for pl: Plane in planes:
			if pl.distance_to(box.get_center()) > box.size.length() * 0.5:
				inside = false
				break
		var d := cam.global_position.distance_to(box.get_center())
		if not inside or (mmi.visibility_range_end > 0.0 and d > mmi.visibility_range_end + box.size.length() * 0.5):
			continue
		var m := mmi.multimesh.mesh
		var tris := 0
		for si in m.get_surface_count():
			var arr := m.surface_get_arrays(si)
			tris += ((arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() if arr[Mesh.ARRAY_INDEX] != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		var cnt := mmi.multimesh.visible_instance_count if mmi.multimesh.visible_instance_count >= 0 else mmi.multimesh.instance_count
		var path := String(get_tree().root.get_path_to(mmi))
		rows.append([cnt * tris, cnt, tris, path.right(70), mmi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, d, m.get_surface_count()])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	var tot := 0
	for r: Array in rows:
		tot += int(r[0])
	print("FIGHT MM %d multimeshes in view, %dk triangles at LOD 0" % [rows.size(), tot / 1000])
	for r: Array in rows.slice(0, 30):
		print("FIGHT MM %7dk  %6d x %5d tris  %d surf  shadow %s  %4.0f m  %s" % [int(r[0]) / 1000, r[1], r[2], r[6], r[4], r[5], r[3]])

