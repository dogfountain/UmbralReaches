extends Node
## Opens every big panel once behind the loading screen, so a panel's first open in play pays no
## one-time cost (font glyphs, styleboxes, the paper doll's viewport and its shaders, the map's
## textures). The loading screen runs `run()` as a phase and waits for `done`. Each panel is opened
## through its real entry point for two frames and closed again; the pause, the mouse and the
## interface sounds are put back exactly as found. No class_name: the loading screen loads it by path.

const UiSound := preload("res://ui/ui_sound.gd")
const GearDB := preload("res://core/items/gear_db.gd")
const CharacterScreen := preload("res://ui/character_screen.gd")
const SettingsMenu := preload("res://ui/settings_menu.gd")
const LootWindow := preload("res://ui/loot_window.gd")
const QuestOffer := preload("res://ui/quest_offer.gd")
const WorldMap := preload("res://ui/world_map.gd")
const DialogueBox := preload("res://ui/dialogue.gd")
const ShopPanel := preload("res://ui/shop.gd")
const StoryDirector := preload("res://core/story/story.gd")
const DialogueDB := preload("res://core/story/dialogue_db.gd")
const DwarfRigScript := preload("res://core/npc/dwarf_rig.gd")
const BossTitleScript := preload("res://core/enemy/boss_title.gd")

const PAGES := [["wanderer", "gear"], ["wanderer", "charms"], ["wanderer", "relics"], ["wanderer", "staff"],
	["kindling", "embers"], ["kindling", "spells"], ["kindling", "loadout"], ["kindling", "oaths"],
	["kindling", "paths"], ["kindling", "hearth"], ["pack", ""], ["journal", "journal"], ["journal", "stories"],
	["journal", "writings"], ["journal", "places"], ["journal", "map"], ["journal", "lore"], ["journal", "tasks"]]
const MAP_WAIT := 6.0                   ## seconds the map's baking worker may take before the map is left cold
const FRAMES := 2

var done := false
var zone: Node3D


## A stand-in loot bag: the loot window reads a title and entries from it.
class WarmBag extends Node3D:
	var title := "Warm"
	var entries: Array = []


func run() -> void:
	var mouse := Input.mouse_mode
	var was_paused := get_tree().paused
	UiSound.muted = true
	var t0 := Time.get_ticks_usec()
	await IconArt.warm(get_tree())
	_lap("icons", t0)
	while not UiSound.prewarm_one():           # every interface sound, one a frame (quest_done alone took 0.62 s)
		await get_tree().process_frame
	await _character_screen()
	await _settings()
	await _loot()
	await _offer()
	await _dialogue()
	await _shop()
	await _map()
	await _boss_cards()
	UiSound.muted = false
	get_tree().paused = was_paused
	Input.mouse_mode = mouse
	done = true


## A great one's name card and the bar's labels, made once with every letter (19 Nov, the visual pass: the first pull of the
## night paid 18.6 ms once, the title's 64 px glyphs and the bar's outlined labels rasterised in the pull's frame).
func _boss_cards() -> void:
	var t0 := Time.get_ticks_usec()
	var t := BossTitleScript.new()
	t.layer = 41                                  # (drawn, under the loading cover's layer 120: hidden text is never shaped)
	add_child(t)
	t._build("ABCDEFGHIJKLMNOPQRSTUVWXYZ'", "abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ,'·-", BossTitleScript.GOLD)
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	for sz: int in [22, 16, 21]:
		var l := Label.new()
		l.text = "ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789 ·:,'-"
		l.add_theme_font_size_override("font_size", sz)
		if sz == 21:
			l.add_theme_constant_override("outline_size", 6)
		layer.add_child(l)
	await _frames()
	t.queue_free()
	layer.queue_free()
	_lap("boss cards", t0)


func _frames() -> void:
	for i in FRAMES:
		await get_tree().process_frame


## Log how long an open call (and the frame after it) took, so a heavy first open shows in the run log.
func _lap(what: String, t0: int) -> void:
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	if ms > 4.0:
		print("PANEL_WARM %s %.1f ms" % [what, ms])


func _character_screen() -> void:
	var cs := get_tree().get_first_node_in_group(&"character_screen") as CharacterScreen
	if cs == null:
		return
	for pg: Array in PAGES:
		var t0 := Time.get_ticks_usec()
		cs.open_at(String(pg[0]), String(pg[1]))
		_lap("char %s/%s call" % [pg[0], pg[1]], t0)
		await _frames()
		_lap("char %s/%s" % [pg[0], pg[1]], t0)
	cs.close()
	await _frames()


func _settings() -> void:
	var sm := _child_by_script("settings_menu.gd") as SettingsMenu
	if sm == null:
		return
	var t0 := Time.get_ticks_usec()
	sm.open()
	_lap("settings open call", t0)
	for i in 4:
		t0 = Time.get_ticks_usec()
		sm._show_tab(i)
		await _frames()
		_lap("settings tab %d" % i, t0)
	sm.close()
	await _frames()


func _loot() -> void:
	var lw := get_tree().get_first_node_in_group(&"loot_window") as LootWindow
	if lw == null:
		return
	var bag := WarmBag.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	bag.entries = [{"kind": "gear", "piece": GearDB.make(rng, {"rarity": 2, "slot": "focus"})}, {"kind": "item", "id": "grave_ash", "n": 3}]
	add_child(bag)
	var t0 := Time.get_ticks_usec()
	lw.open_bag(bag)
	_lap("loot call", t0)
	await _frames()
	_lap("loot", t0)
	lw.close()
	bag.queue_free()
	await _frames()


func _offer() -> void:
	var qo := get_tree().get_first_node_in_group(&"quest_offer") as QuestOffer
	if qo == null:
		return
	var t0 := Time.get_ticks_usec()
	if qo.open_offer("edda_tongs", "Edda"):
		_lap("offer call", t0)
		await _frames()
		_lap("offer", t0)
		qo.close()
		await _frames()


## The conversation box through its real entry point: the portrait viewport and its lights, a line with
## choices (the buttons' styles and the body font's glyphs), and every speaker's portrait rig made once so
## the generated meshes are cached before a first talk.
func _dialogue() -> void:
	var dlg := get_tree().get_first_node_in_group(&"dialogue") as DialogueBox
	if dlg == null:
		return
	var seen := {}
	var t0 := Time.get_ticks_usec()
	var n := 0
	for id: String in DialogueDB.CONV:
		var opts: Dictionary = (DialogueDB.CONV[id] as Dictionary).get("portrait", {})
		if opts.is_empty() or seen.has(str(opts)):
			continue
		seen[str(opts)] = true
		DwarfRigScript.make(opts).free()
		n += 1
		if n % 4 == 0:
			await get_tree().process_frame
	_lap("portrait rigs %d" % n, t0)
	t0 = Time.get_ticks_usec()
	dlg.open("Warm", {"seated": true, "seed": 911, "hat": "helm"})
	dlg.set_mood(2)
	dlg.line("Warm", "The quick brown fox jumps over the lazy dog, and the night comes on: 0123456789 'x' (no).", ["Ask about the road", "Leave it be"])
	_lap("dialogue call", t0)
	for i in 20:
		await get_tree().process_frame
	_lap("dialogue", t0)
	dlg.close()
	await _frames()


## The shop, built the way the first talk builds it (the story director makes it on demand).
func _shop() -> void:
	var st := get_tree().get_first_node_in_group(&"story") as StoryDirector
	if st == null:
		return
	var t0 := Time.get_ticks_usec()
	if not st.open_shop("grisel"):
		return
	_lap("shop call", t0)
	var sh := st.shop as ShopPanel
	await _frames()
	for t in 3:
		sh.set_tab(t)
		await _frames()
	_lap("shop", t0)
	sh.close()
	await _frames()


func _map() -> void:
	var wm := get_tree().get_first_node_in_group(&"world_map") as WorldMap
	if wm == null:
		return
	var until := Time.get_ticks_msec() + int(MAP_WAIT * 1000.0)
	while not wm.is_baked() and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	if not wm.is_baked():
		return
	var t0 := Time.get_ticks_usec()
	wm.open(true)
	_lap("map call", t0)
	await _frames()
	_lap("map", t0)
	wm.close()
	await _frames()


func _child_by_script(file: String) -> Node:
	if zone == null:
		return null
	for c in zone.get_children():
		var sc := c.get_script() as Script
		if sc != null and sc.resource_path.ends_with(file):
			return c
	return null
