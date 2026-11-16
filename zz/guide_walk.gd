extends Node
## A new player's first minutes, captured: the real title screen -> New Game -> slot 1 -> the loading screen ->
## the staged opening -> a walk from the spawn fire to the keep of the Kindled Keg -> his first conversation ->
## out of the door toward the next thing the HUD asks for. Full-size stills (1920 x 1080) of every beat, for
## judging whether the player always knows the next step (core/story/guide.gd).
##   HOME=<scratch>/home UMBRAL_CACHE_DIR=$PWD/.godot/realm_cache_tests \
##     godot --path . res://zz/guide_walk.tscn -- --out=<dir> [--cap=300] [--idle=12]
## The harness scene hands itself to the root (a "GuideWalkDriver" that outlives scene changes) and changes to
## the real first scene (ui/title_boot.tscn), so the night is the current scene as in a real launch.
## Prints "WALK ..." lines (what is on screen at each beat) and quits itself.

const BOOT := "res://ui/title_boot.tscn"
var out := ""
var cap := 300.0
var idle := 12.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--cap="):
			cap = float(a.trim_prefix("--cap="))
		elif a.begins_with("--idle="):
			idle = float(a.trim_prefix("--idle="))
	if out == "":
		out = OS.get_user_data_dir() + "/guide_walk"
	DirAccess.make_dir_recursive_absolute(out)
	if name == "GuideWalkDriver":
		_drive.call_deferred()
		return
	var d: Node = (get_script() as GDScript).new()
	d.name = "GuideWalkDriver"
	d.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(d)
	Travel.forced_title = true
	Settings.fullscreen = false
	Settings.monitor = -1
	get_window().size = Vector2i(1920, 1080)
	get_window().always_on_top = true           # an occluded window stops drawing on macOS: the stills would wait forever
	(func() -> void: get_tree().change_scene_to_file(BOOT)).call_deferred()


var _t0 := 0
var _n := 0


func _now() -> float:
	return float(Time.get_ticks_msec() - _t0) / 1000.0


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	_n += 1
	var path := "%s/%02d_%s.png" % [out, _n, tag]
	img.save_png(path)
	print("WALK shot %s at %.1f s | %s" % [path.get_file(), _now(), _screen()])


## What the HUD says now: the objective lines, the lesson lane, the world prompt, the narration.
func _screen() -> String:
	var bits: PackedStringArray = []
	var obj := get_tree().root.find_child("Objectives", true, false)
	if obj and obj.has_method("lines"):
		bits.append("obj[a=%.2f]=%s" % [(obj as CanvasItem).modulate.a, " / ".join(obj.call("lines") as PackedStringArray)])
	var td := get_tree().get_first_node_in_group(&"text_director")
	if td and td.has_method("lesson_text"):
		bits.append("lesson=%s" % String(td.call("lesson_text")))
	var dlg := get_tree().root.get_node_or_null("Dialogue")
	if dlg:
		var sub := dlg.get("_sub") as Label
		if sub and sub.is_visible_in_tree() and sub.modulate.a > 0.2 and sub.text != "":
			bits.append("narr=%s" % sub.text.left(60))
	var hud := get_tree().get_first_node_in_group(&"hud")
	var pl := _player()
	if pl:
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			if e is Node3D and (e as Node3D).global_position.distance_to(pl.global_position) < 24.0:
				bits.append("foe24=%s@%s" % [e.name, (e as Node3D).global_position.round()])
	if td:
		bits.append("fight=%s" % str(td.call("in_combat")))
	var st := get_tree().root.find_child("Story", true, false)
	var tr: Variant = st.get("trail") if st else null
	if tr is Node:
		var shown := 0
		var cam := get_viewport().get_camera_3d()
		var at: Array[String] = []
		var slots: PackedInt32Array = tr.get("_slot")
		var alphas: PackedFloat32Array = tr.get("_alpha")
		var pos: Array = tr.get("_pos")
		for i in slots.size():
			if slots[i] >= 0 and alphas[i] > 0.05:
				shown += 1
				var w: Vector3 = pos[i]
				var front := cam != null and not cam.is_position_behind(w)
				var dist := cam.global_position.distance_to(w) if cam else -1.0
				at.append("%s %.0fm %s" % [w.round(), dist, "in-view" if front and cam.is_position_in_frustum(w) else "off-view"])
		if not at.is_empty():
			bits.append("marks=%s" % ", ".join(at))
		bits.append("trail=hidden:%s route:%d shown:%d" % [str(tr.get("_hidden")), (tr.get("_rp") as PackedVector2Array).size(), shown])
	else:
		bits.append("trail=none")
	if hud:
		var pr := hud.get("_prompt") as Label
		var row := hud.get("_prompt_row") as Control
		if pr and (row.modulate.a if row else pr.modulate.a) > 0.2 and pr.text != "":
			bits.append("prompt=%s" % pr.text)
		var cmp := hud.get("_compass") as Control
		if cmp:
			bits.append("compass=%s" % cmp.is_visible_in_tree())
	var g := get_tree().get_first_node_in_group(&"guide")
	if g and g.has_method("target_info"):
		bits.append("guide=%s" % str(g.call("target_info")))
		if not (g.get("said") as Array).is_empty():
			bits.append("calls=%s" % str(g.get("said")))
	var ql := get_tree().root.get_node_or_null("QuestLog")
	if ql:
		var bn := ql.get("_banner") as Control
		if bn and bn.modulate.a > 0.2:
			bits.append("banner=%s | %s" % [(ql.get("_b_top") as Label).text, (ql.get("_b_name") as Label).text])
	return "  ".join(bits)


func _player() -> Player:
	return get_tree().get_first_node_in_group(Groups.PLAYER) as Player


func _drive() -> void:
	_t0 = Time.get_ticks_msec()
	get_tree().create_timer(cap, true, false, true).timeout.connect(func() -> void:
		print("WALK cap reached")
		get_tree().quit(1))
	# 1. the title screen
	var title: Node = null
	while title == null:
		await _wait(0.2)
		title = get_tree().root.find_child("TitleScreen", true, false)
	await _wait(2.5)
	await shot("title")
	title.call("_open_slots", "new")
	await _wait(1.0)
	await shot("slots")
	title.call("_slot_pressed", 1)
	# 2. the loading screen
	var p: Player = null
	while p == null:
		await _wait(0.25)
		p = _player()
	var lift := false
	var ls_shot := false
	while not lift:
		await _wait(0.25)
		var ls := get_tree().current_scene.get_node_or_null("LoadingScreen") if get_tree().current_scene else null
		if ls != null and not ls_shot and _now() > 8.0:
			ls_shot = true
			await shot("loading")
		lift = ls == null and get_tree().current_scene != null and get_tree().current_scene.name == "Main"
	var t_lift := _now()
	print("WALK loading lifted at %.1f s" % t_lift)
	# 3. the opening, standing still the way a new player looks around
	for at: float in [0.5, 3.0, 6.0, 9.0, idle]:
		await _wait(maxf(0.0, t_lift + at - _now()))
		await shot("open_%04.1fs" % at)
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		if e is Node3D and (e as Node3D).global_position.distance_to(p.global_position) < 40.0:
			print("WALK foe near the spawn: %s (%s) at %s alive %s" % [e.name, (e as Node).get_script().resource_path.get_file() if (e as Node).get_script() else "?",
				(e as Node3D).global_position, e.call("is_alive") if e.has_method("is_alive") else "?"])
	# 4. the walk to the keep: in at the Keg's door (north side), to the bar
	var route: Array[Vector3] = [Vector3(17.6, 0, 21.5), Vector3(17.6, 0, 27.0), Vector3(15.6, 0, 31.4)]
	await _walk(p, route, "to_keep", 2.5)
	var keep := get_tree().get_first_node_in_group("keep") as Node3D
	if keep and p.global_position.distance_to(keep.global_position) > 2.6:
		# the Keg's tables can catch a scripted walk: a player would step round them; the harness hops to the bar
		print("WALK hop to the bar (stopped %.1f m from the keep at %s)" % [p.global_position.distance_to(keep.global_position), p.global_position])
		p.global_position = Vector3(keep.global_position.x - 0.2, p.global_position.y, keep.global_position.z - 1.7)
		p.set_view(atan2(-(keep.global_position.x - p.global_position.x), -(keep.global_position.z - p.global_position.z)), -0.12)
	await _wait(0.6)
	await shot("at_keep")
	# 5. talk: the interact key, like a player (an action event: the player reads it in _unhandled_input)
	var hud0 := get_tree().get_first_node_in_group(&"hud")
	var said_to := (hud0.get("_prompt") as Label).text if hud0 else ""
	if keep and not said_to.contains("keep"):
		p.global_position = Vector3(keep.global_position.x, p.global_position.y, keep.global_position.z - 1.55)
		p.set_view(0.0, -0.1)
		await _wait(0.8)
		said_to = (hud0.get("_prompt") as Label).text if hud0 else ""
	print("WALK the prompt says '%s'" % said_to)
	if said_to.contains("keep"):
		await shot("prompt_keep")
		await _key("interact")
	await _wait(1.2)
	var dlg := get_tree().root.get_node_or_null("Dialogue")
	if keep and dlg and not bool(dlg.call("is_open")):
		print("WALK the key reached someone else (%s): talking to the keep directly" % (get_tree().get_first_node_in_group(&"hud").get("_prompt") as Label).text)
		get_tree().get_first_node_in_group("story").call("talk", "keep", keep, p)
		await _wait(1.0)
	var steps := 0
	while dlg and bool(dlg.call("is_open")) and steps < 14:
		steps += 1
		if bool(dlg.call("typing")):
			dlg.call("finish_line")
			await _wait(0.4)
		await shot("talk_%d" % steps)
		var n := int(dlg.call("choice_count"))
		if n > 0:
			# "Where do I start?" first, then "I'll go."
			var labels: Array = []
			for c in (dlg.get("_choices") as Node).get_children():
				if c is Button:
					labels.append((c as Button).text)
			var pick := labels.size() - 1                    # the way out, unless there is a better line
			for i in labels.size():
				if String(labels[i]).contains("Where do I start"):
					pick = i
			for i in labels.size():
				if String(labels[i]).contains("I'll go"):
					pick = i
			print("WALK choices %s -> %d" % [labels, pick])
			dlg.call("_pick", pick)
		else:
			dlg.call("press")
		await _wait(0.8)
	# a quest offer screen may follow
	await _wait(1.0)
	await shot("after_talk")
	var offer := get_tree().root.get_node_or_null("QuestOffer")
	if offer and offer.has_method("is_open") and bool(offer.call("is_open")):
		print("WALK an offer screen is open")
		Input.action_press("ui_cancel")
		await _wait(0.1)
		Input.action_release("ui_cancel")
	for at2: float in [2.0, 5.0]:
		await _wait(at2 - (0.0 if at2 == 2.0 else 2.0))
		await shot("after_talk_%ds" % int(at2))
	# 6. out of the door, and to whatever the HUD points at now (a guided save: the meadow fire), and kindle it
	await _walk(p, [Vector3(17.6, 0, 27.5), Vector3(17.6, 0, 24.0), Vector3(17.6, 0, 20.5)], "out", 3.0, false)
	# a Hearthward villager on the way: walking up to one, they call out where the step is and point; then "Which way?"
	var vil: Node3D = null
	for v in get_tree().get_nodes_in_group("villager"):
		var vn := v as Node3D
		if vn and vn.is_visible_in_tree() and vn.global_position.distance_to(p.global_position) < 45.0 and (vil == null or vn.global_position.distance_to(p.global_position) < vil.global_position.distance_to(p.global_position)):
			vil = vn
	if vil:
		print("WALK to the villager %s at %s" % [vil.get("id"), vil.global_position])
		var gd := get_tree().get_first_node_in_group(&"guide")
		if gd:
			gd.set("_bark_t", 0.0)
		await _walk(p, [vil.global_position + (p.global_position - vil.global_position).normalized() * 3.2], "to_villager", 3.0)
		var dv := vil.global_position - p.global_position
		p.set_view(atan2(-dv.x, -dv.z), -0.1)
		var said0: int = (gd.get("said") as Array).size() if gd else 0
		var wv := 0.0
		while gd and (gd.get("said") as Array).size() == said0 and wv < 12.0:
			await _wait(0.3)                              # the subtitle lane may be holding the opening's lines or the Keg's chatter
			wv += 0.3
		await _wait(1.0)
		await shot("villager_calls")
		await _wait(0.4)
		for v2 in get_tree().get_nodes_in_group("villager"):
			if "point_t" in v2 and float(v2.get("point_t")) > 0.0:
				vil = v2                                  # the one who called out
		print("WALK %s state %s act %s point_t %.1f point_at %s" % [vil.get("id"), vil.get("state"), vil.get("act"), float(vil.get("point_t")), vil.get("point_at")])
		# a close side view of the one pointing (the wanderer's camera sits behind her shoulder)
		var side := Camera3D.new()
		get_tree().current_scene.add_child(side)
		var fwd := (p.global_position - vil.global_position)
		fwd.y = 0.0
		fwd = fwd.normalized()
		var right := fwd.cross(Vector3.UP)
		side.global_position = vil.global_position + fwd * 2.6 + right * 1.6 + Vector3.UP * 1.6
		side.look_at(vil.global_position + Vector3.UP * 1.2)
		side.current = true
		await _wait(0.3)
		await shot("villager_points")
		side.current = false
		side.queue_free()
		var dlv := get_tree().root.get_node_or_null("Dialogue")
		while dlv and bool(dlv.call("narrating")):
			await _wait(0.3)
		var hudv := get_tree().get_first_node_in_group(&"hud")
		print("WALK at the villager the prompt says '%s'" % (hudv.get("_prompt") as Label).text)
		vil.call("interact", p)                         # straight to her (the key can find a carved stone at her elbow first)
		await _wait(1.2)
		var asked := false
		var nv := 0
		while dlv and bool(dlv.call("is_open")) and nv < 10:
			nv += 1
			if bool(dlv.call("typing")):
				dlv.call("finish_line")
				await _wait(0.3)
			var labels2: Array = []
			for c in (dlv.get("_choices") as Node).get_children():
				if c is Button:
					labels2.append((c as Button).text)
			if labels2.size() > 0:
				var pk := labels2.size() - 1
				for i in labels2.size():
					if String(labels2[i]).contains("Which way") and not asked:
						pk = i
				if pk != labels2.size() - 1:
					asked = true
				await shot("villager_hub")
				dlv.call("_pick", pk)
				await _wait(1.0)
				if asked and nv < 9:
					if bool(dlv.call("typing")):
						dlv.call("finish_line")
					await _wait(0.4)
					await shot("villager_which_way")
			else:
				dlv.call("press")
			await _wait(0.6)
	var tgt := _guide_target()
	if tgt != Vector3.INF:
		var foot := Vector3(tgt.x, p.global_position.y, tgt.z)
		var dir := foot - p.global_position
		dir.y = 0.0
		await _walk(p, [foot - dir.normalized() * 1.3], "to_next", 3.0)
		await _wait(0.5)
		await shot("at_next")
		var hudn := get_tree().get_first_node_in_group(&"hud")
		var pr_n := (hudn.get("_prompt") as Label).text if hudn else ""
		print("WALK at the fire the prompt says '%s'" % pr_n)
		if pr_n.contains("Kindle"):
			await _key("interact")
		else:
			var fire: Node3D = null
			for b in get_tree().get_nodes_in_group(Groups.BRAZIER):
				if b is Node3D and (fire == null or (b as Node3D).global_position.distance_to(p.global_position) < fire.global_position.distance_to(p.global_position)):
					fire = b
			if fire:
				print("WALK kindling %s directly (%.1f m)" % [fire.name, fire.global_position.distance_to(p.global_position)])
				fire.call("interact", p)
		for at3: float in [1.5, 4.0, 7.0]:
			await _wait(at3 - (0.0 if at3 == 1.5 else (1.5 if at3 == 4.0 else 4.0)))
			await shot("kindled_%0.1fs" % at3)
		# face the next step's way, like a player reading the compass
		var t2 := _guide_target()
		if t2 != Vector3.INF:
			var d2 := t2 - p.global_position
			p.set_view(atan2(-d2.x, -d2.z), -0.12)
			await _wait(1.2)
			await shot("facing_next")
	# 7. the rest of the first act, by state (no fights in a capture): each milestone, the HUD's hand-off to the next
	var story := get_tree().get_first_node_in_group("story")
	for m: Array in [["seal", "henge"], ["boss", "thornwarden"], ["seal", "oss_gallery"], ["boss", "bone_abbot"]]:
		if String(m[0]) == "seal":
			Travel.seals_broken[String(m[1])] = true
		else:
			Travel.bosses_slain[String(m[1])] = true
		if story:
			story.emit_signal("objectives_changed")
		await _wait(1.2)
		var t3 := _guide_target()
		if t3 != Vector3.INF:
			var d3 := t3 - p.global_position
			p.set_view(atan2(-d3.x, -d3.z), -0.1)
		await _wait(1.6)
		await shot("act_%s_%s" % [m[0], m[1]])
	# 8. Brannoc, the end of the guided act: talk to him, and the guide lets go
	var bran: Node3D = null
	for n in get_tree().get_nodes_in_group(Groups.INTERACTABLE):
		if "talk_id" in n and String(n.get("talk_id")) == "brannoc":
			bran = n
	if bran and story:
		p.global_position = bran.global_position + Vector3(0.0, 0.3, -1.6)
		await _wait(1.0)
		await shot("brannoc")
		story.call("talk", "brannoc", bran, p)
		await _wait(1.0)
		await shot("brannoc_talk")
		var dl := get_tree().root.get_node_or_null("Dialogue")
		var n2 := 0
		while dl and bool(dl.call("is_open")) and n2 < 12:
			n2 += 1
			if bool(dl.call("typing")):
				dl.call("finish_line")
				await _wait(0.3)
			var cc := int(dl.call("choice_count"))
			if cc > 0:
				dl.call("_pick", cc - 1)                  # the way out
			else:
				dl.call("press")
			await _wait(0.6)
		await _wait(2.5)
		await shot("guide_done")
		await _wait(4.0)
		await shot("guide_done_4s")
	await shot("end")
	print("WALK done at %.1f s" % _now())
	get_tree().quit()


## Press and release an action as a player would: an InputEventAction (pressed, then released) through the input path.
func _key(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await _wait(0.12)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


func _guide_target() -> Vector3:
	var g := get_tree().get_first_node_in_group(&"guide")
	if g and g.has_method("target_pos"):
		return g.call("target_pos")
	return Vector3.INF


## Walk to each point of `route` along the navmesh (straight when the map has no path), at a walk, facing the way;
## a still every `every` seconds.
func _walk(p: Player, route: Array[Vector3], tag: String, every: float, use_nav := true) -> void:
	var since := 0.0
	var k := 0
	var pts: Array[Vector3] = []
	var from := p.global_position
	var nav_map := p.get_world_3d().navigation_map
	for goal: Vector3 in route:
		var g := Vector3(goal.x, from.y, goal.z)
		var path := NavigationServer3D.map_get_path(nav_map, from, g, true) if use_nav else PackedVector3Array()
		if path.size() >= 2:
			for i in range(1, path.size()):
				pts.append(path[i])
		if pts.is_empty() or Vector2(pts.back().x - g.x, pts.back().z - g.z).length() > 1.5:
			pts.append(g)               # the navmesh stops short (the Keg's door is not on it): the rest in a straight line
		from = g
	print("WALK %s: %d points (nav %s)" % [tag, pts.size(), NavigationServer3D.map_get_iteration_id(nav_map)])
	for wp: Vector3 in pts:
		var tries := 0.0
		while tries < 25.0:
			var d := Vector3(wp.x - p.global_position.x, 0.0, wp.z - p.global_position.z)
			if d.length() < 0.7:
				break
			var dir := d.normalized()
			if tries > 1.5 and p.velocity.length() < 0.4:
				dir = (dir + Vector3(-dir.z, 0.0, dir.x) * (1.0 if int(tries) % 4 < 2 else -1.0)).normalized()   # caught on a corner: step round it
			p.set_view(lerp_angle(p._yaw, atan2(-dir.x, -dir.z), 0.25), -0.16)
			p.debug_drive(dir, false)
			await _wait(0.1)
			tries += 0.1
			since += 0.1
			if since >= every:
				since = 0.0
				k += 1
				await shot("%s_%d" % [tag, k])
		if tries >= 25.0:
			print("WALK %s: gave up on %s at %s" % [tag, wp, p.global_position])
	p.debug_drive(Vector3.ZERO)
	print("WALK %s: ended at %s (paused %s)" % [tag, p.global_position, get_tree().paused])
