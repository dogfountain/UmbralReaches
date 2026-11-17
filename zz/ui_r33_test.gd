extends Node
## r33 HUD (WoW pass): the HUD builds and runs with none of the new data, then with all of it.
##   HOME=<scratch>/home godot --headless --path . res://zz/ui_r33_test.tscn
## A bare scene (no night): the HUD alone; then a stand-in wanderer with health, a level, XP, buffs
## and a cast, a stand-in foe (elite, casting, afflicted, marked) locked on, a stand-in boss, and a
## map_marker of every kind on a minimap given a stand-in ground. Checks the widgets show only when
## their data exists and that every draw runs. Never writes a save (Travel._busy; prefs in memory).
## Ends: UI33 PASS  /  UI33 FAIL n

const HudPrefs := preload("res://ui/hud_prefs.gd")

var fails := 0
var hud: CanvasLayer
var draws := {}


class FakeStamina extends Node:
	var winded := true
	var breath := 40.0
	func ratio() -> float:
		return 0.4
	func in_fight() -> bool:
		return true
	func flash() -> float:
		return 0.0
	func flash_good() -> bool:
		return false


class FakeFoe extends Node3D:
	## the r33 enemy contract (core/enemy/enemy.gd header): methods, not fields
	var hp := 7.0
	var max_hp := 12
	var marks := 2
	var hp_bar_y := 2.0
	func is_alive() -> bool:
		return hp > 0.0
	func display_name() -> String:
		return "Hobb, Who Knocks Thrice"
	func rank() -> String:
		return "elite"
	func level() -> int:
		return 7
	func cast_info() -> Dictionary:
		return {"name": "Third Knock", "progress": 0.6, "interruptible": true}
	func debuffs() -> Array[Dictionary]:
		return [{"id": "umbral_mark", "name": "Umbral Mark", "left": -1.0, "stacks": 2, "harmful": true},
			{"id": "hexed", "name": "Hexed", "left": 4.0, "stacks": 3, "harmful": true},
			{"id": "warded", "name": "Warded", "left": 2.0, "stacks": 1, "harmful": false}]


class FakeBoss extends Node3D:
	var hp := 30.0
	var max_hp := 40
	var phase := 2
	var boss := true
	var hp_bar_y := 3.0
	func is_alive() -> bool:
		return hp > 0.0
	func phase_marks() -> Array[float]:
		return [0.66, 0.33]


class FakePlayer extends Node3D:
	var gloom := 40.0
	var gloom_max := 100.0
	var health := 80.0
	var max_health := 120.0
	var level := 4
	var xp := 340.0
	var xp_next := 900.0
	var velocity := Vector3.ZERO
	var ward_drain_left := 12.0
	var _riposte_ready := true
	var wounds := 30.0                 # r35: the Wounds bar (the frame shows what they leave)
	var wounds_max := 120.0
	var target: Node3D
	var st := FakeStamina.new()
	func _ready() -> void:
		add_child(st)
	func stamina() -> Node:
		return st
	func lock_target() -> Node3D:
		return target
	func is_grounded() -> bool:
		return true
	func is_hanging() -> bool:
		return false
	func buffs() -> Array:
		return [{"name": "Kindled Blood", "glyph": "flame", "color": Color(1.0, 0.6, 0.3), "left": 12.0, "dur": 30.0, "stacks": 2},
			{"name": "Ash Sickness", "glyph": "", "color": Color(0.7, 0.7, 0.7), "left": 70.0, "dur": 90.0, "stacks": 0, "debuff": true}]
	func cast_info() -> Dictionary:
		return {"name": "Kindle", "t": 0.5, "color": Color(1.0, 0.7, 0.3)}


func ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		fails += 1
		print("  FAIL ", what)


func _count(n: CanvasItem, key: String) -> void:
	if n == null:
		return
	draws[key] = 0
	n.draw.connect(func() -> void: draws[key] = int(draws[key]) + 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	HudPrefs._loaded = true                       # in-memory prefs: no hud.cfg read or written
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 4, 8)
	cam.current = true
	hud = (load("res://ui/hud.gd") as GDScript).new()
	add_child(hud)
	await _frames(3)
	var uf := hud.find_child("UnitFrames", true, false) as Control
	var ct := hud.find_child("CombatText", true, false) as Control
	var xb := hud.find_child("XpBar", true, false) as Control
	var mm := hud.find_child("Minimap", true, false) as Control
	ok(uf != null and ct != null and xb != null and mm != null, "the HUD builds its frames, combat text, XP strip and minimap")
	ok(ct != null and ct.is_in_group(&"combat_text"), "combat text answers to the combat_text group")
	_count(uf, "uf")
	for layer in uf.get_children():                  # the frames draw on their layers (unit_frames.gd LAYERS)
		if layer is CanvasItem:
			(layer as CanvasItem).draw.connect(func() -> void: draws["uf"] = int(draws["uf"]) + 1)
	_count(xb, "xb")
	_count(mm, "mm")
	_count(hud.find_child("Hotbar", true, false) as CanvasItem, "hotbar")

	# --- without any of the new data: no player at all, nothing shown, nothing breaks
	await _frames(20)
	ok(xb != null and not xb.visible, "no XP anywhere: the XP strip stays hidden")
	ok(uf != null and uf.get("_target") == null, "no player: no target frame")

	# --- with it all
	var p := FakePlayer.new()
	p.add_to_group(Groups.PLAYER)
	add_child(p)
	var foe := FakeFoe.new()
	foe.add_to_group(Groups.ENEMY)
	foe.set_meta(&"enc_tier", 2)
	add_child(foe)
	foe.position = Vector3(0, 0, -6)
	p.target = foe
	var boss := FakeBoss.new()
	boss.add_to_group(Groups.ENEMY)
	add_child(boss)
	boss.position = Vector3(3, 0, -12)
	uf.call("_on_boss_engaged", boss, "The Test Warden")
	# markers of every kind, and a stand-in painted ground so the minimap draws
	var kinds := ["quest_available", "quest_turnin", "quest_target", "rare", "travel", "gather", "vendor", "trainer"]
	for i in kinds.size():
		var m := Node3D.new()
		m.add_to_group(&"map_marker")
		m.set_meta(&"map_kind", kinds[i])
		m.set_meta(&"map_label", "Mark %d" % i)
		add_child(m)
		m.position = Vector3(cos(i) * 20.0, 0, sin(i) * 20.0) if i != 0 else Vector3(400, 0, 0)
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	img.fill(Color(0.3, 0.35, 0.25))
	mm.set("_size_m", Vector2(400, 400))
	mm.set("_origin", Vector2(-200, -200))
	mm.set("_tex", ImageTexture.create_from_image(img))
	Events.player_hurt.emit(14.0, Vector3.INF)
	ct.call("pop", foe.global_position + Vector3.UP * 2.0, "PARRY", "parry")
	ct.call("pop", foe.global_position + Vector3.UP * 2.0, "28", "crit")
	ct.call("pop", foe.global_position + Vector3.UP * 2.0, "x", "no such kind")
	await _frames(40)
	p.gloom = 20.0                                   # a sudden fall: relief on the portrait and at the shoulder
	await _frames(40)
	ok(uf.get("_target") == foe, "the locked-on foe is the target")
	ok(uf.get("_boss") == boss, "the engaged boss has its frame")
	ok(String(uf.call("_rank", foe)) == "elite", "rank read from the foe's own field")
	ok(String(uf.call("_name_of", foe)) == "Hobb, Who Knocks Thrice", "name read from display_name()")
	var sub := String(uf.call("_subline", foe, "elite"))
	ok(sub.begins_with("Lv 7  ") and sub.contains("  ·  Elite") and (sub.contains("Even") or sub.contains("Gentle") or sub.contains("Perilous") or sub.contains("Deadly") or sub.contains("Haven")), "its level, danger word and rank under the name (%s)" % sub)
	var ci: Dictionary = uf.call("_cast_of", foe)
	ok(ci.get("name", "") == "Third Knock" and is_equal_approx(float(ci.get("t", 0.0)), 0.6), "the foe's cast_info (progress) drives its cast bar")
	var deb: Array = uf.call("_debuffs_of", foe)
	ok(deb.size() == 3 and bool(deb[0].debuff) and not bool(deb[2].debuff) and String(deb[0].glyph) == "mark", "its debuffs listed, harmful first, marks as marks")
	ok(String(uf.call("_name_of", boss)) == "The Test Warden", "the boss named by its engage title")
	var buffs: Array = uf.get("_buffs")
	var names := PackedStringArray()
	for b: Dictionary in buffs:
		names.append(String(b.name))
	print("  buffs: ", ", ".join(names))
	ok(names.has("Kindled Blood") and names.has("Lantern Ward") and names.has("Riposte Ready") and names.has("Winded") and not names.has("Hollowing"), "reported and derived buffs and debuffs all listed (r35: no Hollowing count)")
	ok(not bool(buffs[0].get("debuff", false)) and bool(buffs[buffs.size() - 1].get("debuff", false)), "buffs before debuffs")
	ok(xb.visible and (xb.get("_info") as Dictionary).get("next", 0.0) == 900.0, "XP found on the player: the strip shows")
	ok((uf.get("_portrait_pops") as Array).size() >= 1 or int(draws.get("uf", 0)) > 0, "portrait numbers popped")
	var marks: Array = mm.get("_marks")
	var seen := {}
	for m: Dictionary in marks:
		seen[String(m.kind)] = true
	var all := true
	for k: String in kinds:
		all = all and seen.has("m:" + k)
	ok(all, "every map_marker kind collected by the minimap (the far quest one too)")
	HudPrefs.track["gather"] = false
	ok(not HudPrefs.tracks("gather") and HudPrefs.tracks("quest_turnin") and HudPrefs.tracks("seal"), "tracking toggles by kind")
	HudPrefs.track["gather"] = true
	# the card: shown again on request
	var hint := hud
	var lessons: Dictionary = Travel.story.get("lessons", {})
	lessons["tip_move"] = true
	Travel.story["lessons"] = lessons
	HudPrefs.card_request += 1
	await _frames(3)
	ok(not (Travel.story.get("lessons", {}) as Dictionary).has("tip_move"), "the settings menu's request replays the one-line control prompts")
	# frames off: the plain Gloom bar returns
	HudPrefs.unit_frames = false
	await _frames(3)
	ok((hud.get("_bar") as Control).visible, "unit frames off: the plain Gloom bar is back")
	HudPrefs.unit_frames = true
	await _frames(3)
	ok(not (hud.get("_bar") as Control).visible and hint != null, "unit frames on: the plain bar steps aside")
	# the foe dies: the target frame says so, then lets go
	foe.hp = 0.0
	p.target = null
	await get_tree().create_timer(1.8).timeout
	ok(uf.get("_target") == null, "a dead target lets go")
	boss.queue_free()
	await _frames(5)
	ok(uf.get("_boss") == null, "a freed boss drops its frame")
	print("  draws: ", draws)
	ok(int(draws.get("uf", 0)) > 10 and int(draws.get("mm", 0)) > 10 and int(draws.get("xb", 0)) > 5, "frames, minimap and XP strip all drew")
	# and back to nothing: the player leaves
	p.queue_free()
	await _frames(20)
	print("UI33 PASS" if fails == 0 else "UI33 FAIL %d" % fails)
	get_tree().quit(0 if fails == 0 else 1)
