extends Node
## The r33 HUD in the night (needs a renderer): calm, then a staged fight (a locked-on elite winding
## up a blow with your burn and rime on it, a boss frame, buffs, combat text, map markers of every
## kind round you). -> shots/ui_r33_<W>x<H>_<calm|fight|card>.png
##   HOME=<scratch>/home godot --path . res://zz/ui_r33_shot.tscn -- --size=1280x720 --save-dir=<scratch>/save
## Never writes the save (Travel._busy); quits itself (real-time cap 150 s).

const Tiers := preload("res://core/life/encounters/tiers.gd")
const Afflict := preload("res://core/skills/afflict.gd")

var main: Node
var t := 0.0
var size := Vector2i(1600, 900)
var _phase := 0
var _wait := 0.0
var foe: Node3D
var boss: Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			var v := a.trim_prefix("--size=").split("x")
			size = Vector2i(int(v[0]), int(v[1]))
	get_window().size = size
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _shot(nm: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://shots/ui_r33_%dx%d_%s.png" % [size.x, size.y, nm]))
	print("UI33_SHOT ", nm)


func _process(d: float) -> void:
	Travel._busy = true
	t += d
	if t > 150.0:
		print("UI33_SHOT timeout")
		get_tree().quit(1)
		return
	_wait -= d
	if _wait > 0.0:
		return
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	match _phase:
		0:
			if main.has_meta("realm_done") and t > 9.0 and p != null:
				get_window().size = size
				_phase = 1
				_wait = 6.0          # the card is up a few seconds in
		1:
			_shot("calm")
			_stage(p)
			_phase = 2
			_wait = 0.5
		2:
			if is_instance_valid(foe) and foe.has_method("begin_cast"):
				foe.call("begin_cast", "Third Knock", 2.0, true)
			if is_instance_valid(foe):
				p.set("_lock", foe)
			Events.player_hurt.emit(18.0, Vector3.INF)
			var ct := get_tree().get_first_node_in_group(&"combat_text")
			if ct and is_instance_valid(foe):
				ct.call("pop", foe.global_position + Vector3.UP * 2.6, "PARRY", "parry")
			_phase = 3
			_wait = 0.35
			for e: Node3D in [foe, boss]:
				if is_instance_valid(e):
					e.process_mode = Node.PROCESS_MODE_DISABLED
		3:
			_shot("fight")
			_phase = 4
			_wait = 0.2
		4:
			get_tree().quit(0)


func _stage(p: Player) -> void:
	var fwd := -p.global_basis.z
	var cam := get_viewport().get_camera_3d()
	if cam:
		fwd = -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var at := p.global_position + fwd * 5.0
	foe = (load(Tiers.KIND_PATHS["wretch"]) as GDScript).new()
	foe.set_meta(&"elite_id", "hobb")
	foe.set_meta(&"enc_tier", 1)
	main.add_child(foe)
	foe.global_position = at
	boss = (load(Tiers.KIND_PATHS["husk"]) as GDScript).new()
	main.add_child(boss)
	boss.global_position = p.global_position + fwd * 12.0 + fwd.cross(Vector3.UP) * 4.0
	boss.set("hp", float(boss.get("max_hp")) * 0.62)
	var uf := get_tree().root.find_child("UnitFrames", true, false)
	if uf:
		uf.call("_on_boss_engaged", boss, "The Bone Abbot")
	foe.set("hp", float(foe.get("max_hp")) * 0.7)
	foe.set("marks", 2)
	Afflict.burn(foe, 30.0)
	Afflict.chill(foe, 30.0)
	Afflict.chill(foe, 30.0)
	p.set("_riposte_ready", true)
	p.set("ward_drain_left", 18.0)
	p.set("_chain", 3)
	p.set("_chain_until", Time.get_ticks_msec() * 0.001 + 4.0)
	var kinds := ["quest_available", "quest_turnin", "quest_target", "rare", "travel", "gather", "vendor", "trainer"]
	for i in kinds.size():
		var m := Node3D.new()
		m.add_to_group(&"map_marker")
		m.set_meta(&"map_kind", kinds[i])
		if i == 1:
			m.set_meta(&"map_label", "Grisel")
		main.add_child(m)
		var a := TAU * float(i) / float(kinds.size())
		var r := 300.0 if i == 0 else 14.0 + 4.0 * float(i)
		m.global_position = p.global_position + Vector3(cos(a), 0.0, sin(a)) * r
