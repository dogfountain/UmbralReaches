extends Node
## The HUD on its own, over a still night (no world): the wanderer's frame, compass, XP strip, minimap, with
## a stand-in wanderer whose Gloom you set. Windowed, a few seconds.
##   godot --path . res://zz/hud_shot.tscn -- --out=<dir> [--size=1920x1080] [--bg=<png>] [--gloom=0,30,60,85,100]
## -> <dir>/hud_g<gloom>_<W>x<H>.png. Holds Travel._busy; never writes the save.

const HudPrefs := preload("res://ui/hud_prefs.gd")


class FakePlayer extends Node3D:
	var gloom := 0.0
	var gloom_max := 100.0
	var wounds := 0.0
	var wounds_max := 120.0
	var velocity := Vector3.ZERO
	func is_grounded() -> bool:
		return true
	func is_hanging() -> bool:
		return false
	func buffs() -> Array:
		return []


class FakeHearth extends Node:
	var gain := 0
	func xp_info() -> Dictionary:
		return {"level": 0, "into": 20 + gain, "need": 40, "frac": 0.5, "rested_frac": 0.5, "capped": false, "last_gain": 20, "last_why": "discover"}


class Beacon extends Node3D:
	var anchor := Vector3.ZERO
	var tint := Color(1.0, 0.7, 0.3)


var out := "res://shots"
var size := Vector2i(1920, 1080)
var bg := ""
var levels: Array = [0, 30, 60, 85, 100]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	HudPrefs._loaded = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--size="):
			var v := a.trim_prefix("--size=").split("x")
			size = Vector2i(int(v[0]), int(v[1]))
		elif a.begins_with("--bg="):
			bg = a.trim_prefix("--bg=")
		elif a.begins_with("--gloom="):
			levels = Array(a.trim_prefix("--gloom=").split(","))
	get_window().size = size
	Travel.story["gloom_seen"] = true
	Travel.story["flags"] = {"arrived": true}          # not a new game: no staged opening
	HudPrefs.reset_stage()
	if bg != "":
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(Image.load_from_file(bg))
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(tr)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	var hud: Node = (load("res://ui/hud.gd") as GDScript).new()
	add_child(hud)
	var p := FakePlayer.new()
	p.add_to_group(Groups.PLAYER)
	p.wounds = 30.0
	add_child(p)
	var hh := FakeHearth.new()
	hh.add_to_group(&"hearth")
	add_child(hh)
	for i in 3:
		var b := Beacon.new()
		b.anchor = Vector3(-40.0 + 40.0 * i, 0.0, -90.0 - 80.0 * i)
		b.add_to_group(&"landmark_beacon")
		add_child(b)
	_run.call_deferred(p, hh)


func _run(p: FakePlayer, hh: FakeHearth) -> void:
	var strip := Image.create(520, 200 * levels.size(), false, Image.FORMAT_RGBA8)
	var row := 0
	for lv in levels:
		p.gloom = float(lv)
		for i in 50:
			await get_tree().process_frame
		hh.gain += 1
		for i in 30:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/hud_g%d_%dx%d.png" % [out, int(lv), size.x, size.y])
		img.convert(Image.FORMAT_RGBA8)
		strip.blit_rect(img, Rect2i(0, 0, 520, 200), Vector2i(0, row * 200))
		row += 1
		print("HUDSHOT ", lv)
	strip.save_png("%s/strip_%dx%d.png" % [out, size.x, size.y])
	get_tree().quit()
