extends Node
## A heavy fight, measured (the night's harness starts it: core/debug/main_harness.gd, so packed builds run it too).
##   <game> -- --fight-bench --fps-log [--boss=thornwarden|bone_abbot|anchoress|warden|none] [--n=10] [--secs=20] [--no-cast]
## The night is built, the wanderer stands on open ground, a boss and N grunts are spawned round him and come at
## him, and every spell slot is pressed over and over (cooldowns reset). He cannot die (his wounds are cleared).
## At the end "FIGHT" prints the frame times and the engine monitors averaged over the fight; --ab-enemies then
## measures the foes' thinking (far, near), the spells, drawing the foes and the HUD by switching each off for a
## few seconds; --hud-ab measures the HUD in alternating windows and each of its widgets taken away in turn;
## --hud-draws counts which HUD canvas items redraw during the fight.
const Tiers := preload("res://core/life/encounters/tiers.gd")
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
var _frames_ms := PackedFloat32Array()
var _mon := {}
var _book: SkillBook
var _ev: Array = []            ## [usec, text]: what happened in the fight, to set beside the slow frames
var _slow: Array = []          ## [usec, ms]
var _fight_t0 := 0


func begin(night: Node) -> void:
	main = night
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--boss="):
			boss = a.trim_prefix("--boss=")
		elif a.begins_with("--n="):
			n = int(a.trim_prefix("--n="))
		elif a.begins_with("--secs="):
			secs = float(a.trim_prefix("--secs="))
		elif a == "--no-cast":
			cast = false
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
	if t % 240 == 0:                         # topped up now and then (every frame kept the HUD's numbers moving)
		p.wounds = 0.0
		p.gloom = 0.0
	if _frames_ms.size() < 100000:
		_frames_ms.append(delta * 1000.0)
		if _frames_ms.size() > 60 and delta * 1000.0 > 22.0:
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
	get_tree().node_added.connect(func(nd: Node) -> void:
		if nd is GPUParticles3D or nd is Enemy or nd is OmniLight3D or nd is RigidBody3D:
			var par := nd.get_parent()
			_note("added %s %s" % [nd.get_class(), String(par.name) + "/" + (String(par.get_parent().name) if par and par.get_parent() else "")]))
	# --hud-draws: which HUD canvas items redraw during the fight, and how often (a redraw is what a HUD costs)
	var draws := {}
	if "--hud-draws" in OS.get_cmdline_user_args():
		var hud := get_tree().root.find_child("HUD", true, false)
		if hud != null:
			for ci in hud.find_children("*", "CanvasItem", true, false):
				var key := String(hud.get_path_to(ci))
				(ci as CanvasItem).draw.connect(func() -> void: draws[key] = int(draws.get(key, 0)) + 1)
	_frames_ms.clear()
	var t0 := Time.get_ticks_msec()
	var slot := 0
	while Time.get_ticks_msec() - t0 < int(secs * 1000.0):
		if cast and _book:
			_book.reset_cooldowns()
			_book.press(slot % 4)                   # not slot 4 (Rift Step): it blinks the wanderer down the road
			slot += 1
		_sample()
		await get_tree().create_timer(0.12).timeout
	_report()
	if not draws.is_empty():
		var keys := draws.keys()
		keys.sort_custom(func(a: String, b: String) -> bool: return int(draws[a]) > int(draws[b]))
		var total := 0
		for k: String in keys:
			total += int(draws[k])
		print("FIGHT HUD redraws: %d over %d frames (%.1f a frame), %d items drew at all" % [total, _frames_ms.size(), float(total) / maxf(float(_frames_ms.size()), 1.0), keys.size()])
		for k: String in keys.slice(0, 24):
			print("FIGHT HUD redraw %5.2f a frame  %s" % [float(draws[k]) / maxf(float(_frames_ms.size()), 1.0), k])
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
	# each slow frame (> 22 ms) with what happened in the 100 ms before it
	print("FIGHT slow frames: %d" % _slow.size())
	for sl: Array in _slow.slice(0, 25):
		var t: int = sl[0]
		var near: Dictionary = {}
		for ev: Array in _ev:
			if int(ev[0]) > t - 100000 and int(ev[0]) <= t:
				var k := String(ev[1]).left(60)
				near[k] = int(near.get(k, 0)) + 1
		print("FIGHT slow %6.2f s  %5.1f ms  %s" % [float(t - _fight_t0) / 1.0e6, sl[1], str(near)])
	var f := Array(_frames_ms)
	f.sort()
	var avg := 0.0
	for x: float in f:
		avg += x
	avg /= maxf(float(f.size()), 1.0)
	var p95: float = f[int(f.size() * 0.95)] if f.size() > 0 else 0.0
	var p99: float = f[int(f.size() * 0.99)] if f.size() > 0 else 0.0
	print("FIGHT frames %d  avg %.2f ms (%.0f fps)  p95 %.2f  p99 %.2f  worst %.2f" % [f.size(), avg, 1000.0 / maxf(avg, 0.01), p95, p99, f.back() if f.size() > 0 else 0.0])
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

