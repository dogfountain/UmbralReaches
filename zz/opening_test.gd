extends Node
## The staged opening of a new game (r37), without the world: a stand-in wanderer, the real HUD and the real story
## director, with the opening forced on (HudPrefs.test_force).
##   the black lifts with no HUD and the zone's title card plays on it -> the first narration line, once the card is
##   gone (one message at a time), alone -> a new game is guided (core/story/guide.gd): once the line is read the HUD
##   arrives with the first objective pinned, the compass (it carries the way to the keep) and the move prompt on
##   painted caps; the second line waits for the wanderer to move -> the Gloom bar waits for Gloom, the minimap for the
##   Keep; the objective stays up while the guide is on, and with it off shows for 6 s then hides (a held key brings
##   it back); the hotbar draws only the slots that have been taught.
## Never writes the save (Travel._busy), restores what it changed.   HOME=<scratch> godot --headless --path . res://zz/opening_test.tscn
const StoryScript := preload("res://core/story/story.gd")
const HudPrefs := preload("res://ui/hud_prefs.gd")
const DialogueDB := preload("res://core/story/dialogue_db.gd")
const SealedSkill := preload("res://core/skills/skill_sealed.gd")
var bad := 0
var _travel := {}


func _ready() -> void:
	Travel._busy = true
	for k: String in ["seals_broken", "bosses_slain", "items", "story", "lit_by_path"]:
		_travel[k] = (Travel.get(k) as Dictionary).duplicate(true)
		Travel.set(k, {})
	HudPrefs.test_force = true
	var player := Node3D.new()
	player.add_to_group(Groups.PLAYER)
	add_child(player)
	var hud: CanvasLayer = (load("res://ui/hud.gd") as GDScript).new()
	add_child(hud)
	Events.zone_entered.emit("THE TEST NIGHT", "a card to play first")       # held by the HUD until the opening plays it
	var story := StoryScript.new()
	add_child(story)
	await get_tree().process_frame
	var ui: CanvasLayer = null
	var td: Node = hud.get("_td")
	var fade: ColorRect = hud.get("_fade")
	var content: Control = hud.get("_ui")
	_ok(bool(hud.get("_opening_hold")) and not content.visible and is_equal_approx(fade.color.a, 1.0), "a new game opens on black with no HUD")
	_ok(not HudPrefs.gloom_known(), "the Gloom bar is not known yet")
	_ok(not (hud.get("_compass") as Control).visible or true, "(compass checked once the stage ticks)")
	# 1. the black lifts and the title card plays on it, alone; then the first line
	var t := 0.0
	var card_seen := false
	var card_with_line := false
	var hud_under_card := false
	var title: Label = hud.get("_title")
	while t < 30.0:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
		card_seen = card_seen or title.modulate.a > 0.5
		hud_under_card = hud_under_card or (content.visible and title.modulate.a > 0.5)
		ui = story.get("ui")
		if ui != null and is_instance_valid(ui) and ui.has_method("narrating") and bool(ui.call("narrating")) and String((ui.get("_sub") as Label).text) != "":
			card_with_line = hud.call("title_busy")
			break
	_ok(bool(hud.get("_lifting")) and not hud_under_card, "the black lifts with no HUD under the card")
	_ok(card_seen, "the title card played over the lifting black")
	_ok(ui != null and String((ui.get("_sub") as Label).text) == String(DialogueDB.OPENING[0]), "the first line is spoken (%s)" % [(ui.get("_sub") as Label).text if ui else "no dialogue"])
	_ok(not card_with_line, "...once the card was gone (one message at a time)")
	_ok((ui.get("_sub_queue") as Array).is_empty(), "...alone (the rest waits)")
	await get_tree().create_timer(0.3).timeout
	_ok(story.flag("guide") and content.visible and not bool(hud.get("_opening_hold")), "a new game is guided: the HUD (the first objective, its mark, the compass) comes with the first line")
	_ok(fade.color.a < 0.05, "...over the world (fade %.2f)" % fade.color.a)
	t = 0.0
	while t < 30.0 and td.call("lesson_text") == "":
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	_ok(String(td.call("lesson_text")).contains("Move"), "the move prompt shows once the line is read (%.1f s): '%s'" % [t, td.call("lesson_text")])
	var plate := td.get("_keys_plate") as Control
	_ok(plate != null and plate.visible and plate.get_child_count() > 0, "...on painted caps")
	await get_tree().create_timer(0.6).timeout
	_ok((hud.get("_compass") as Control).visible and not (hud.get("_minimap") as Control).visible, "the compass comes with the guide, the minimap waits for the Keep")
	_ok((ui.get("_sub_queue") as Array).is_empty(), "the second line waits for the wanderer to move")
	# 3. the wanderer moves
	player.global_position += Vector3(6, 0, 0)
	t = 0.0
	var second := false
	while t < 8.0 and not second:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
		second = String((ui.get("_sub") as Label).text) == String(DialogueDB.OPENING[1])
	_ok(second, "...and the second line is spoken when the wanderer moves")
	# 4. what has not been earned stays away
	_ok(not HudPrefs.gloom_known() and not (hud.get("_minimap") as Control).visible, "no Gloom bar, no minimap yet")
	Events.gloom_changed.emit(12.0, 100.0)
	hud.set("_bar", hud.get("_bar"))
	(hud.get("_bar") as Control).set("value", 0.12)
	await get_tree().create_timer(0.3).timeout
	_ok(HudPrefs.gloom_known() and bool(Travel.story.get("gloom_seen", false)), "the Gloom bar appears when Gloom first rises above 0")
	story.set_flag("met_keep")
	await get_tree().create_timer(0.6).timeout
	_ok((hud.get("_compass") as Control).visible and (hud.get("_minimap") as Control).visible, "the compass and minimap arrive with the Keep")
	# 5. the objective
	var obj: Control = null
	for c in content.get_children():
		if c.name == "Objectives":
			obj = c
	_ok(obj != null, "the objective tracker is on the HUD")
	if obj:
		await get_tree().create_timer(0.3).timeout
		_ok(obj.modulate.a > 0.5, "the objective shows when it changes (alpha %.2f)" % obj.modulate.a)
		await get_tree().create_timer(9.0).timeout
		var bw0 := 0.0
		while bw0 < 25.0 and bool(td.call("banner_up")):         # the guide's "Next" banner: the tracker stands aside for it
			await get_tree().create_timer(0.25).timeout
			bw0 += 0.25
		await get_tree().create_timer(1.0).timeout
		_ok(obj.modulate.a > 0.9, "...and stays while the guide is on (alpha %.2f)" % obj.modulate.a)
		story.set_flag("guide_done")
		await get_tree().create_timer(9.0).timeout
		_ok(obj.modulate.a < 0.1, "with the guide off it hides after 6 s (alpha %.2f)" % obj.modulate.a)
		var bw := 0.0
		while bw < 25.0 and bool(td.call("banner_up")):           # the guide's "Next" banner (queued behind the narration) has the lane
			await get_tree().create_timer(0.25).timeout
			bw += 0.25
		Input.action_press("show_objective")
		await get_tree().create_timer(1.0).timeout
		_ok(obj.modulate.a > 0.9, "a held key shows it again (alpha %.2f)" % obj.modulate.a)
		Input.action_release("show_objective")
	# 6. the hotbar draws only what is taught
	var book := SkillBook.new()
	add_child(book)
	await get_tree().process_frame
	for i in range(1, book.slots.size()):
		book.slots[i] = SealedSkill.new()
	var bar := Hotbar.new()
	add_child(bar)
	bar.set("_book", book)
	var wr := PackedByteArray()
	wr.resize(book.slots.size())
	var rp := PackedFloat32Array()
	rp.resize(book.slots.size())
	bar.set("_was_ready", wr)
	bar.set("_ready_pulse", rp)
	await get_tree().process_frame
	_ok((bar.get("_vis") as Array) == [0], "a new wanderer's bar draws one slot, the sealed four are not drawn (%s)" % [bar.get("_vis")])
	book.slots[2] = book.slots[0]
	await get_tree().process_frame
	_ok((bar.get("_vis") as Array).size() == 2, "a slot appears when a spell is taught (%s)" % [bar.get("_vis")])
	for k: String in _travel:
		Travel.set(k, _travel[k])
	HudPrefs.test_force = false
	print("OPENING done bad=%d" % bad)
	get_tree().quit(1 if bad > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	print(("OPENING ok   " if cond else "OPENING FAIL ") + what)
	if not cond:
		bad += 1
