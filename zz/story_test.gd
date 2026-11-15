extends Node
## Story + NPC tests, headless, no world:  godot --headless --path . res://zz/story_test.tscn
##   quests     objective transitions from a fresh save to the end (QuestDB)
##   dialogue   data integrity (every target, condition, fallback), start nodes by progress
##   flow       the director + dialogue box: the keep's first meeting through choices, pausing,
##              the ending conversation and its flags; patrons' conversations
##   persist    Travel.story survives save/load; an older save without [story] loads as {}
##   rigs       dwarf builds, IK reach, the keep's lane clears counter and shelves, the bar regular
##              clears the counter, seated patrons clear the table edge and the chair backs,
##              every animation beat poses without NaNs
## Never writes the real save: Travel._busy is held for the whole run (save_game is a no-op) and the
## persistence check round-trips the [story] section through a ConfigFile in memory. As a belt and
## braces the save files are read first and written back only if their bytes changed.
## Ends: STORY TEST PASS  /  STORY TEST FAIL n

const QuestDB := preload("res://core/story/quest_db.gd")
const DialogueDB := preload("res://core/story/dialogue_db.gd")
const StoryScript := preload("res://core/story/story.gd")
const Book := preload("res://core/story/quest_book.gd")
const Chains := preload("res://core/story/quest_chains.gd")

var fails := 0
var _bak := {}
var _travel := {}


func ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		fails += 1
		print("  FAIL ", what)


func _ready() -> void:
	_backup()
	await get_tree().process_frame
	_quests()
	_dialogue_data()
	await _flow()
	_persist()
	await _rigs()
	_restore()
	print("STORY TEST %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	get_tree().quit(0 if fails == 0 else 1)


# --- sandbox the save ---------------------------------------------------------------------------

func _backup() -> void:
	Travel._busy = true
	for suf: String in ["", ".bak"]:
		var p := Travel.SAVE_PATH + suf
		_bak[suf] = FileAccess.get_file_as_bytes(p) if FileAccess.file_exists(p) else null
	for k: String in ["seals_broken", "bosses_slain", "items", "story", "lit_by_path"]:
		_travel[k] = (Travel.get(k) as Dictionary).duplicate(true)
	Travel.seals_broken = {}
	Travel.bosses_slain = {}
	Travel.items = {}
	Travel.story = {}
	Travel.lit_by_path = {}


func _restore() -> void:
	for k: String in _travel:
		Travel.set(k, _travel[k])
	for suf: String in _bak:
		var p := Travel.SAVE_PATH + suf
		if _bak[suf] == null:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		elif FileAccess.get_file_as_bytes(p) != _bak[suf]:
			var f := FileAccess.open(p, FileAccess.WRITE)
			f.store_buffer(_bak[suf])
			f.close()
			print("  save CHANGED during the test: restored ", suf)
	print("  save untouched")


# --- quests -------------------------------------------------------------------------------------

func _ids(ws: Dictionary) -> Array:
	return QuestDB.active(ws, 9).map(func(o: Dictionary) -> String: return String(o.id))


func _quests() -> void:
	print("quests")
	var ws := {"flags": {}, "kindled": 0, "seals": {}, "bosses": {}, "items": {}}
	ok(_ids(ws) == ["arrive"], "fresh: find the keep  %s" % [_ids(ws)])
	ws.flags["met_keep"] = true
	ok(_ids(ws) == ["doors", "kindle"], "met the keep: the two doors + kindling (sheet 237)  %s" % [_ids(ws)])
	ok(String(QuestDB.active(ws)[1].text).ends_with("(0/4)"), "kindling shows its count")
	ws.kindled = 2
	ok(String(QuestDB.active(ws)[1].text).ends_with("(2/4)"), "kindling 2/4")
	ws.seals["henge"] = true
	ok(_ids(ws) == ["thornwarden", "oss_seal", "kindle"], "thorn seal broken -> the Thornwarden  %s" % [_ids(ws)])
	ws.bosses["thornwarden"] = true
	ok(_ids(ws) == ["oss_seal", "kindle"], "Thornwarden slain  %s" % [_ids(ws)])
	ws.seals["oss_gallery"] = true
	ok(_ids(ws) == ["bone_abbot", "kindle"], "gallery seal -> the Bone Abbot  %s" % [_ids(ws)])
	ws.kindled = 4
	ok(not "kindle" in _ids(ws), "all four braziers: kindling done")
	ws.bosses["bone_abbot"] = true
	ok(_ids(ws) == ["peal"], "both shards -> the Founder's peal (four bells) first  %s" % [_ids(ws)])
	for b: String in Chains.BELLS.slice(0, Chains.BELLS_NEEDED):   # four bells answered, as play records them
		Book.start(b)
		Book.choose(b, "rung")
	ok(_ids(ws) == ["summit_seal"], "four bells -> the summit ward  %s" % [_ids(ws)])
	ws.seals["summit"] = true
	ok(_ids(ws) == ["warden"], "summit ward open  %s" % [_ids(ws)])
	ws.bosses["ascended_warden"] = true
	ok(_ids(ws) == ["return"], "Warden slain -> return to the Keg  %s" % [_ids(ws)])
	for b: String in Chains.BELLS.slice(0, Chains.BELLS_NEEDED):   # the four test bells: not tracked tasks later on
		Book.drop(b)
	ws.flags["ending_told"] = true
	ok(_ids(ws).is_empty(), "ending told: nothing left  %s" % [_ids(ws)])
	# out of order: the Abbot first, before ever meeting the keep
	var ws2 := {"flags": {}, "kindled": 0, "seals": {"oss_gallery": true}, "bosses": {"bone_abbot": true}, "items": {}}
	ok(_ids(ws2) == ["arrive"], "unmet keep hides the rest")
	ws2.flags["met_keep"] = true
	ok(_ids(ws2) == ["thorn_seal", "kindle"], "Abbot already down: only the thorn side left  %s" % [_ids(ws2)])
	ok(QuestDB.test("seal:henge|boss:bone_abbot", ws2) and not QuestDB.test("seal:henge,boss:bone_abbot", ws2), "| and , semantics")
	ok(QuestDB.test("!flag:x", ws2) and QuestDB.test("bosses:1", ws2) and not QuestDB.test("bosses:2", ws2), "! and bosses:n")


# --- dialogue data ----------------------------------------------------------------------------

func _dialogue_data() -> void:
	print("dialogue data")
	var bad := DialogueDB.audit()
	ok(bad.is_empty(), "integrity %s" % [bad])
	var fresh := {"flags": {}, "kindled": 0, "seals": {}, "bosses": {}, "items": {}}
	ok(DialogueDB.start_node("keep", fresh) == "meet_1", "keep opens on the first meeting")
	var met := {"flags": {"met_keep": true}, "kindled": 0, "seals": {}, "bosses": {}, "items": {}}
	ok(DialogueDB.start_node("keep", met) == "hub", "keep opens on the hub after")
	var won := {"flags": {"met_keep": true}, "kindled": 4, "seals": {}, "bosses": {"thornwarden": true, "bone_abbot": true, "ascended_warden": true}, "items": {}}
	ok(DialogueDB.start_node("keep", won) == "end_1", "keep opens on the ending after the Warden")
	won.flags["ending_told"] = true
	ok(DialogueDB.start_node("keep", won) == "hub", "and on the hub once it is told")
	ok(DialogueDB.text_of(DialogueDB.node("keep", "hub"), won).begins_with("The kindled one. Your stool"), "hub greeting knows the story is over")
	won.flags.erase("ending_told")
	won.bosses.erase("ascended_warden")
	ok(DialogueDB.text_of(DialogueDB.node("keep", "hub"), won).begins_with("Heart and crown"), "hub greeting reacts to progress")
	# with heart and crown but no peal yet, the keep sends the wanderer to the bells (the Crossing is gated by four)
	ok(DialogueDB.text_of(DialogueDB.node("keep", "next"), won).begins_with("Not up yet. The door hears bells"), "what now: the bells, before the Crossing")
	var nx: Array = DialogueDB.node("keep", "next").get("say_if", [])
	var crossing := false
	for row: Variant in nx:
		if row is Array and String(row[1]).begins_with("Across the Crossing"):
			crossing = true
	ok(crossing, "what now: the Crossing line is still there for after the peal is told")
	won.bosses["ascended_warden"] = true
	won.flags["ending_told"] = true
	ok(not DialogueDB.text_of(DialogueDB.node("keep", "next"), won).contains("Aurel's at the top"), "what now: nobody is sent up a finished Stair")
	var two := {"flags": {}, "kindled": 2, "seals": {}, "bosses": {}, "items": {}}
	ok(DialogueDB.text_of(DialogueDB.node("keep", "news"), two).begins_with("Two of four"), "news counts the braziers")
	two.kindled = 1
	ok(DialogueDB.text_of(DialogueDB.node("keep", "news"), two).begins_with("1 of four"), "news counts one brazier")
	for cid: String in ["hesk", "harrow", "brannoc"]:
		ok(DialogueDB.start_node(cid, fresh) == "meet", "%s opens on a meeting" % cid)
	ok(DialogueDB.start_node("hesk", {"bosses": {"thornwarden": true}}) == "after", "Hesk reacts to the Thornwarden")
	ok(DialogueDB.start_node("harrow", {"bosses": {"bone_abbot": true}}) == "after", "Harrow reacts to the Abbot")
	ok(DialogueDB.start_node("brannoc", {"bosses": {"ascended_warden": true}}) == "after", "Brannoc reacts to the Warden")


# --- the director and the box -------------------------------------------------------------------

func _flow() -> void:
	print("flow")
	var story: Node = StoryScript.new()
	story.opening_delay = 0.3
	add_child(story)
	await get_tree().process_frame
	await get_tree().process_frame
	var ui: Node = story.ui
	ok(is_instance_valid(ui) and ui.is_inside_tree(), "dialogue box in the tree")
	# the opening narration fires once
	await get_tree().create_timer(0.5).timeout
	ok(story.flag("arrived") and ui.narrating(), "opening narration on first arrival")
	ok(story.objectives().size() == 1 and String(story.objectives()[0].id) == "arrive", "objective: find the keep")
	# talk to the keep
	ok(story.talk("keep", null, null), "talk opens")
	ok(ui.is_open() and get_tree().paused, "box open, world paused")
	ok(ui.typing(), "line types out")
	ui.press()
	ok(not ui.typing(), "press finishes the line")
	ui.press()              # meet_1 -> meet_2
	ui.press()
	ui.press()              # meet_2 -> meet_hub (choices)
	ui.press()
	ok(ui.choice_count() == 4, "first-meeting menu has 4 choices (%d)" % ui.choice_count())
	ui.chosen.emit(1)       # what happened (2nd: start is first now) -> lore_1 -> lore_2 -> hub
	for i in 4:
		ui.press()
	ok(ui.choice_count() == 3, "picked 'once' choice is gone (%d)" % ui.choice_count())
	ui.chosen.emit(0)       # "Where do I start?" (still first among the remaining)
	ui.press()
	ui.press()              # start_1 -> start_2 (sets met_keep; choices)
	ui.press()
	ok(story.flag("met_keep"), "the keep's directions set met_keep")
	ok(ui.choice_count() == 2, "start_2 offers two choices")
	ui.chosen.emit(1)       # "I'll go." -> meet_end
	ui.press()
	ui.press()
	ok(not ui.is_open() and not get_tree().paused, "conversation ends, world unpaused")
	var ids: Array = story.objectives().map(func(o: Dictionary) -> String: return String(o.id))
	ok(ids == ["doors", "kindle"], "objectives after meeting the keep %s" % [ids])
	# Esc closes mid-conversation
	story.talk("hesk")
	ok(ui.is_open(), "Hesk talks")
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await get_tree().process_frame
	await get_tree().process_frame
	ok(not ui.is_open() and not get_tree().paused, "Esc leaves the conversation")
	ok(story.flag("met_hesk"), "meeting Hesk is remembered")
	# the ending
	Travel.bosses_slain = {"thornwarden": true, "bone_abbot": true}
	Travel.seals_broken = {"henge": true, "oss_gallery": true, "summit": true}
	Events.boss_slain.emit("ascended_warden")
	Travel.bosses_slain["ascended_warden"] = true
	ids = story.objectives().map(func(o: Dictionary) -> String: return String(o.id))
	ok(ids == ["return"], "after the Warden: return to the Keg %s" % [ids])
	story.talk("keep")
	ok(ui.is_open(), "the keep's ending conversation opens")
	var guard := 0
	while ui.is_open() and guard < 40:
		guard += 1
		ui.press()
		if not ui.typing() and ui.choice_count() > 0:
			ui.chosen.emit(0)
	ok(story.flag("ending_told") and story.flag("ending_card"), "ending told; title card shown")
	ok(story.objectives().is_empty(), "no objectives left")
	ok(Travel.story.has("flags") and (Travel.story.flags as Dictionary).has("met_keep"), "flags live in Travel.story")
	await get_tree().create_timer(10.2).timeout   # the ending waits out the 9 s sky spin (sheet 240)
	ok(story.flag("ending_seen"), "ending narration fired")
	story.queue_free()
	await get_tree().process_frame


# --- persistence ----------------------------------------------------------------------------------

func _persist() -> void:
	print("persist (in memory)")
	var st := {"flags": {"met_keep": true, "met_harrow": true}, "picked": {"keep/meet_hub/0": true}}
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "version", Travel.SAVE_VERSION)
	cfg.set_value("story", "state", st)          # as Travel.save_game writes it
	var back := ConfigFile.new()
	back.parse(cfg.encode_to_text())
	var got: Variant = back.get_value("story", "state", {})
	ok(got is Dictionary and bool(((got as Dictionary).get("flags", {}) as Dictionary).get("met_harrow", false)), "story flags survive the save's encoding")
	ok(got is Dictionary and ((got as Dictionary).get("picked", {}) as Dictionary).has("keep/meet_hub/0"), "picked choices survive")
	# an older save: no [story] section -> Travel.load_game's default
	back.erase_section("story")
	var old: Variant = back.get_value("story", "state", {})
	ok(old is Dictionary and (old as Dictionary).is_empty(), "older save loads with an empty story")
	ok(not FileAccess.file_exists(Travel.SAVE_PATH) or FileAccess.get_file_as_bytes(Travel.SAVE_PATH) == _bak[""], "the real save was not written")


# --- rigs -----------------------------------------------------------------------------------------

func _verts(r: DwarfRig) -> PackedVector3Array:
	return (r.mesh_instance.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]


func _rigs() -> void:
	print("rigs")
	var bz := Tavern.Z1 - Tavern.T
	# the keep: his lane on the duckboard clears the counter's back edge and the shelves
	var keep := DwarfRig.make({"seated": false, "seed": 5150, "apron": true, "hat": "bare", "rag": true})
	add_child(keep)
	var lane_z := bz - Tavern.KEEP_IN
	var front := INF
	var back := -INF
	for v in _verts(keep):
		var wy := v.y + Tavern.DUCK            # floor-relative
		if wy > 0.95 and wy < 1.12 and absf(v.x) < 0.24:
			front = minf(front, v.z)         # belly/apron at counter-top height (arms excluded)
		if wy > 1.25 and wy < 1.4 and absf(v.x) < 0.22:
			back = maxf(back, v.z)           # back at the lower shelf
	ok(lane_z + front > bz - 0.92, "keep clears the counter: front %.3f > %.3f" % [lane_z + front, bz - 0.92])
	ok(lane_z + back < bz - 0.35, "keep clears the shelves: back %.3f < %.3f" % [lane_z + back, bz - 0.35])
	ok(lane_z > bz - 0.92 and lane_z < bz - 0.36, "keep's lane is on the duckboard, behind the counter")
	# the bar regular: faces +z on the foot step, his belly short of the counter's front face
	var bar_z := float(Tavern.PATRONS[8][1])
	var reg := DwarfRig.make({"seated": false, "seed": 911 + 8 * 37, "hat": "hood"})
	add_child(reg)
	var rf := INF
	for v in _verts(reg):
		var wy2 := v.y + Tavern.STEP_Y
		if wy2 > 0.3 and wy2 < 1.0 and absf(v.x) < 0.24:
			rf = minf(rf, v.z)
	ok(bar_z - rf < bz - 1.55, "bar regular clears the counter front: %.3f < %.3f" % [bar_z - rf, bz - 1.55])
	# seated patrons: nothing at table height past the board's edge; chair sitters clear the back
	var worst_edge := -INF
	var worst_back := -INF
	var seat_low := INF
	for i in 8:
		var r := DwarfRig.make({"seated": true, "seed": 911 + i * 37, "hat": String(Tavern.PATRONS[i][4])})
		add_child(r)
		for v in _verts(r):
			if v.y > 0.7 and v.y < 0.8 and absf(v.x) < 0.3:
				worst_edge = maxf(worst_edge, -v.z)
			if v.y > 0.5 and v.y < 1.05 and absf(v.x) < 0.2:
				worst_back = maxf(worst_back, v.z)
			if absf(v.x) < 0.2 and absf(v.z) < 0.12:
				seat_low = minf(seat_low, v.y)
		r.free()
	ok(worst_edge < 0.4 - 0.02, "seated bellies stop short of the table edge (%.3f < 0.38)" % worst_edge)
	ok(worst_back < 0.19 + Tavern.CHAIR_IN, "chair sitters clear the chair back (%.3f < %.3f)" % [worst_back, 0.19 + Tavern.CHAIR_IN])
	ok(seat_low > DwarfRig.SEAT - 0.06 and seat_low < DwarfRig.SEAT + 0.06, "seated pelvis rests on the seat (%.3f vs %.2f)" % [seat_low, DwarfRig.SEAT])
	# IK reaches
	keep.fk_all()
	var tgt := keep.lips() + Vector3(0.1, -0.08, -0.12)
	keep.arm_to("r", tgt)
	ok(keep.gpos(DwarfRig.B_HAND_R).distance_to(tgt) < 0.002, "arm IK reaches its target")
	keep.free()
	reg.free()
	# every beat poses cleanly (patron pair + bar regular + keep)
	var a := DwarfNpc.new()
	var b := DwarfNpc.new()
	a.seed_n = 911
	b.seed_n = 948
	add_child(a)
	add_child(b)
	b.position = Vector3(0, 0, -1.7)
	b.rotation.y = PI
	a.partner = b
	b.partner = a
	a.leader = true
	var nan := false
	for act: String in ["idle", "drink", "toast", "laugh", "talk", "listen", "look"]:
		a.cue(act, 2.0)
		b.cue("listen" if act == "talk" else act, 2.0)
		for f in 45:
			a._act_t = 2.0 * float(f) / 44.0
			a.animate(0.05)
			b.animate(0.05)
			for q in a.rig._q:
				if not q.is_finite():
					nan = true
	ok(not nan, "patron beats pose without NaNs")
	a.cue("drink", 4.0)
	a._act_t = 2.0
	a.animate(0.016)
	a.rig.fk_all()
	var mug_top: Vector3 = a.rig.carry(DwarfRig.B_HAND_R, a.rig.mug_rim)
	ok(mug_top.distance_to(a.rig.lips()) < 0.06, "mid-drink the mug rim is at the lips (%.3f m)" % mug_top.distance_to(a.rig.lips()))
	a.free()
	b.free()
	var k := Bartender.new()
	add_child(k)
	k.global_position = Vector3(15.0, -0.4, 33.62)
	k.bar_y = 0.38
	k.bar_z = 33.33
	k.lane_z = 33.62
	k.keg = Vector3(19.2, -0.22, 33.75)
	var knan := false
	for task: String in ["wipe", "polish", "fill", "serve", "chat"]:
		k._task = task
		k._task_len = 3.0
		for f in 30:
			k._task_t = 3.0 * float(f) / 29.0
			k.animate(0.05, false, false, null)
			for q in k.rig._q:
				if not q.is_finite():
					knan = true
	k._walk = 1.0
	for f in 30:
		k._phase = float(f) * 0.3
		k.animate(0.05, true, false, null)
	ok(not knan, "keep's tasks pose without NaNs")
	ok(Bartender.make_mug() != null, "served tankard mesh builds")
	k.free()
	await get_tree().process_frame
