extends Node
## The new player's guide (core/story/guide.gd), headless, no world: the real story director (and its guide, dialogue
## box and task banner) over stand-in places: the keep in the Keg, two valley braziers, the two seals, a villager.
##   - a save without the guide flag (a returning save) has no step, no answer, no pinned tracker;
##   - with it the step follows the story: the Keg's door from the yard, the keep inside; the Stair-foot fire (the
##     nearest cold one); the nearer seal; each change after the first is announced ("Next") in the banner lane;
##   - a villager passed close calls out where the step is (once), turns to point; "Which way?" is answered;
##   - the hand-off at Brannoc ends it (guide_done), and the HUD preference switches it off;
##   - the prompts' painted caps: {action} tokens become caps of the live binding, the lesson lane draws them.
## Never writes the save (Travel._busy).   HOME=<scratch> godot --headless --path . res://zz/guide_test.tscn
## Ends: GUIDE TEST PASS / GUIDE TEST FAIL n

const StoryScript := preload("res://core/story/story.gd")
const Guide := preload("res://core/story/guide.gd")
const HudPrefs := preload("res://ui/hud_prefs.gd")
const KeyCap := preload("res://ui/key_cap.gd")
const TextDirector := preload("res://ui/text_director.gd")
const QuestDB := preload("res://core/story/quest_db.gd")

var fails := 0
var _travel := {}

const LIT_SRC := "extends Node3D\nvar lit := false\n"
const VILLAGER_SRC := "extends Node3D\nvar id := \"hild\"\nvar display_name := \"Hild\"\nvar attend = null\nvar point_at := Vector3.INF\nvar point_t := 0.0\n"
const SEAL_SRC := "extends Node3D\nvar seal_id := \"\"\n"


func ok(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func _script(src: String) -> GDScript:
	var g := GDScript.new()
	g.source_code = src
	g.reload()
	return g


func _ready() -> void:
	Travel._busy = true
	for k: String in ["seals_broken", "bosses_slain", "items", "story", "lit_by_path"]:
		_travel[k] = (Travel.get(k) as Dictionary).duplicate(true)
		Travel.set(k, {})
	Travel.story = {"flags": {"arrived": true}}          # an arrival already played: the opening stays out of it
	HudPrefs.ensure()
	HudPrefs.guide = true
	# the stand-in places
	var player := Node3D.new()
	player.add_to_group(Groups.PLAYER)
	add_child(player)
	player.global_position = Vector3(0, 0, 33)          # Hearthward's fire
	var keep := Node3D.new()
	keep.add_to_group("keep")
	add_child(keep)
	keep.global_position = Vector3(15.0, -0.7, 33.7)
	var zone := Node3D.new()
	zone.name = "Zone"
	add_child(zone)
	var braz := Node3D.new()
	braz.name = "Braziers"
	zone.add_child(braz)
	var lit_s := _script(LIT_SRC)
	var fires := {}
	for n: Array in [["StairFoot", Vector3(-5, 0, -2)], ["Shrine", Vector3(-31, 0, 4)]]:
		var b := Node3D.new()
		b.set_script(lit_s)
		b.name = String(n[0])
		braz.add_child(b)
		b.global_position = n[1]
		fires[n[0]] = b
	var seal_s := _script(SEAL_SRC)
	for sd: Array in [["henge", Vector3(-70, 5, -20)], ["oss_gallery", Vector3(-60, -7, 150)]]:
		var s := Node3D.new()
		s.set_script(seal_s)
		s.set("seal_id", String(sd[0]))
		s.add_to_group(&"ward_seal")
		add_child(s)
		s.global_position = sd[1]
	var story: Node = StoryScript.new()
	add_child(story)
	await get_tree().process_frame
	await get_tree().process_frame
	var guide := get_tree().get_first_node_in_group("guide") as Guide
	ok(guide != null, "the story director brings a guide")
	# 1. a returning save: no guide
	await _wait(0.6)
	ok(not Guide.on() and guide.step().is_empty() and guide.answer() == "" and guide.target_pos() == Vector3.INF, "a save without the guide flag has no step (a returning save plays as before)")
	# 2. guided: find the keep
	story.call("set_flag", "guide")
	await _wait(0.6)
	var st := guide.step()
	ok(String(st.get("id", "")) == "arrive" and String(st.get("text", "")) == "Find the keep in the Kindled Keg", "guided: the first step is the keep (%s)" % st.get("text", ""))
	ok((st.target as Vector3).distance_to(Guide.KEG_DOOR) < 3.0 and String(st.kind) == "door" and String(st.art) == "quest_available", "...from the yard the mark is on the Keg's door (%s)" % st.target)
	player.global_position = Vector3(17.0, -0.7, 30.0)
	await _wait(0.6)
	st = guide.step()
	ok((st.target as Vector3).distance_to(keep.global_position) < 3.0 and String(st.kind) == "person", "...inside, over the keep (%s %s)" % [st.kind, st.target])
	ok(guide.answer().contains("Kindled Keg"), "'Which way?' is answered (%s)" % guide.answer())
	var log_ui: Node = story.get("log_ui")
	var q0 := (log_ui.get("_bq") as Array).size()
	# 3. the keep spoken to: the first fire (the nearest cold one), announced
	story.call("set_flag", "met_keep")
	player.global_position = Vector3(0, 0, 33)
	await _wait(0.6)
	st = guide.step()
	ok(String(st.get("id", "")) == "first_fire" and (st.target as Vector3).distance_to(Vector3(-5, 2.3, -2)) < 0.5 and String(st.art) == "fire", "met the keep: the Stair-foot fire, the nearest cold brazier (%s %s)" % [st.get("id", ""), st.get("target", "")])
	var bq: Array = log_ui.get("_bq")
	var shown := "%s | %s" % [(log_ui.get("_b_top") as Label).text, (log_ui.get("_b_name") as Label).text]
	ok((bq.size() == q0 + 1 and String((bq.back() as Array)[0]) == "NEXT") or (shown.begins_with("Next") and shown.contains("Stair-foot fire")), "...announced in the banner lane, by its short name: %s" % shown)
	var objs: Array = story.call("objectives")
	ok(not objs.is_empty() and String((objs[0] as Dictionary).id) == "first_fire", "...and it heads the tracker (%s)" % [objs.map(func(o: Dictionary) -> String: return String(o.id))])
	# 4. the fire lit: pick a door, the nearer seal
	(fires["StairFoot"] as Node3D).set("lit", true)
	Events.brazier_kindled.emit(fires["StairFoot"])
	await _wait(0.6)
	st = guide.step()
	ok(String(st.get("id", "")) == "doors" and String(st.kind) == "seal" and (st.target as Vector3).x < -60.0 and (st.target as Vector3).z < 0.0, "a fire lit: pick a door, the mark on the nearer seal (%s)" % st.get("target", ""))
	# 5. a villager passed close calls out, once, and points
	var vs := _script(VILLAGER_SRC)
	var v := Node3D.new()
	v.set_script(vs)
	v.add_to_group("villager")
	add_child(v)
	v.global_position = player.global_position + Vector3(2, 0, 0)
	guide.set("_bark_t", 0.0)                 # past the first seconds' hush
	await _wait(1.5)
	ok(guide.said.size() == 1 and String(guide.said[0]).begins_with("hild:"), "a villager passed close calls out the way (%s)" % [guide.said])
	ok(float(v.get("point_t")) > 0.0 and (v.get("point_at") as Vector3).distance_to(st.target) < 0.5, "...and points at it")
	var ui: Node = story.get("ui")
	ok(ui != null and bool(ui.call("narrating")), "...said as a subtitle with her name")
	await _wait(1.5)
	ok(guide.said.size() == 1, "...once per step")
	# 6. through the act: a seal, its keeper, the other seal, its keeper, then Brannoc
	for m: Array in [["henge", "thornwarden", "thornwarden"], ["", "thornwarden", "oss_seal"], ["oss_gallery", "", "bone_abbot"], ["", "bone_abbot", "peal"]]:
		if String(m[0]) != "":
			Travel.seals_broken[String(m[0])] = true
		if String(m[1]) != "" and String(m[0]) == "":
			Travel.bosses_slain[String(m[1])] = true
		await _wait(0.6)
		ok(String(guide.step().get("id", "")) == String(m[2]), "...then %s (%s)" % [m[2], guide.step().get("id", "")])
	# 7. Brannoc spoken to: the guide lets go
	guide.talked("brannoc")
	await _wait(0.4)
	ok(story.call("flag", "guide_done") and not Guide.on() and guide.step().is_empty(), "Brannoc spoken to: the guide lets go")
	# 8. the preference
	Travel.story.flags.erase("guide_done")
	ok(Guide.on(), "(on again)")
	HudPrefs.guide = false
	ok(not Guide.on() and guide.answer() == "", "Settings > Guidance off: no guide")
	HudPrefs.guide = true
	# 9. painted caps
	var row := KeyCap.line("{jump} Jump   {move} Move", false)
	var caps := row.get_children().filter(func(c: Node) -> bool: return c.get_script() == KeyCap)
	ok(caps.size() == 5 and String(caps[0].get("label")) == InputSetup.live_label("jump", false, "?"), "{jump} {move}: five caps, the first the jump key (%d, %s)" % [caps.size(), caps[0].get("label") if caps.size() > 0 else "-"])
	ok(KeyCap.plain("{skill_bolt} Rift Bolt") == "LMB Rift Bolt" and KeyCap.for_action("skill_bolt")[0][0] == "mouse_l", "a mouse button is a painted mouse (%s)" % KeyCap.plain("{skill_bolt} Rift Bolt"))
	ok(String(KeyCap.for_action("move", true)[0][0]) == "stick" and String(KeyCap.for_action("interact", true)[0][0]) == "button", "with a pad: sticks and face buttons")
	ok(IconArt.art("key", "cap") != null and IconArt.art("key", "mouse_l") != null, "the caps are painted art (ui/icons/key)")
	row.free()
	var td: Node = TextDirector.new()
	add_child(td)
	var root := Control.new()
	add_child(root)
	td.call("build", root, load("res://ui/fonts/Cinzel.ttf"))
	td.call("post_lesson", "{interact} Talk")
	td.call("tick", 0.1)
	var plate := td.get("_keys_plate") as Control
	ok(plate.visible and plate.get_child_count() == 1 and String(td.call("lesson_text")).ends_with("Talk"), "a keyed lesson draws on caps (%s)" % td.call("lesson_text"))
	td.call("post_lesson", "A plain lesson")
	td.call("tick", 9.0)
	td.call("tick", 1.0)
	td.call("tick", 0.1)
	ok(not plate.visible and String(td.call("lesson_text")) == "A plain lesson", "...and a plain one does not")
	for k: String in _travel:
		Travel.set(k, _travel[k])
	print("GUIDE TEST PASS" if fails == 0 else "GUIDE TEST FAIL %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
