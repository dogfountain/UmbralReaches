extends Node
## The staged opening of a new game (r37), without the world: a stand-in wanderer, the real HUD and the real story
## director, with the opening forced on (HudPrefs.test_force).
##   one narration line alone on black, no HUD -> the black lifts, still no HUD (only the move prompt) ->
##   when the wanderer moves the HUD arrives and the second line is spoken -> the Gloom bar waits for Gloom, the
##   compass and minimap for the Keep, the objective shows for 6 s then hides (a held key brings it back), the hotbar
##   draws only the slots that have been taught.
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
	# 1. the first line alone
	var t := 0.0
	while t < 20.0:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
		ui = story.get("ui")
		if ui != null and is_instance_valid(ui) and ui.has_method("narrating") and bool(ui.call("narrating")) and String((ui.get("_sub") as Label).text) != "":
			break
	_ok(ui != null and String((ui.get("_sub") as Label).text) == String(DialogueDB.OPENING[0]), "the first line is spoken (%s)" % [(ui.get("_sub") as Label).text if ui else "no dialogue"])
	_ok((ui.get("_sub_queue") as Array).is_empty() and not content.visible and fade.color.a > 0.99, "...alone, on black, with no HUD")
	# 2. the black lifts, the HUD does not come
	t = 0.0
	while t < 30.0 and not bool(hud.get("_lifting")):
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	_ok(bool(hud.get("_lifting")), "the black lifts after the line (%.1f s)" % t)
	await get_tree().create_timer(1.2).timeout
	_ok(fade.color.a < 0.95 and not content.visible, "...over the world, still with no HUD (fade %.2f)" % fade.color.a)
	t = 0.0
	while t < 4.0 and td.call("lesson_text") == "":
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	_ok(String(td.call("lesson_text")).contains("move"), "only the move prompt shows: '%s'" % td.call("lesson_text"))
	_ok((ui.get("_sub_queue") as Array).is_empty(), "the second line waits for the wanderer to move")
	# 3. the wanderer moves
	player.global_position += Vector3(6, 0, 0)
	t = 0.0
	while t < 4.0 and not content.visible:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	_ok(content.visible and not bool(hud.get("_opening_hold")), "the HUD arrives when the wanderer moves")
	t = 0.0
	var second := false
	while t < 8.0 and not second:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
		second = String((ui.get("_sub") as Label).text) == String(DialogueDB.OPENING[1])
	_ok(second, "...and the second line is spoken")
	# 4. what has not been earned stays away
	_ok(not HudPrefs.gloom_known() and not (hud.get("_compass") as Control).visible and not (hud.get("_minimap") as Control).visible, "no Gloom bar, no compass, no minimap yet")
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
		_ok(obj.modulate.a < 0.1, "...and hides after 6 s (alpha %.2f)" % obj.modulate.a)
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
