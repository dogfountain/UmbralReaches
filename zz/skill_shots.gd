extends Node
## Combat VFX contact sheet: the wanderer casts every skill at a target in an open spot and six
## frames of each are captured from the player camera (a row per skill).
##   godot --path . res://zz/skill_shots.tscn -- [--tag=before] [--more]  -> shots/skills_<tag>_sheet.png
## --more (r28) adds rows for the learned spells (Tether, Well, Shade at rank III), a ranked Nova
## (echo + undertow) and a Rift Bolt with each staff core; those rows set the progression state
## in memory first. Never writes the save or settings (Travel._busy).
const ROWS := [
	# [label, slot, hold seconds (0 = tap), capture times after the press]
	["bolt", 0, 0.95, [0.05, 0.12, 0.22, 0.4, 0.7, 1.05]],
	["lance", 1, 1.25, [0.3, 0.9, 1.3, 1.36, 1.45, 1.7]],
	["nova", 2, 0.0, [0.03, 0.1, 0.2, 0.32, 0.5, 0.8]],
	["ward", 3, 0.0, [0.05, 0.15, 0.3, 0.6, 1.0, 1.6]],
	["step", 4, 0.0, [0.02, 0.08, 0.15, 0.25, 0.4, 0.6]],
]
## --more: [label, slot, hold, times, progression state to set first]
const MORE := [
	["nova_r3", 2, 0.0, [0.03, 0.12, 0.3, 0.55, 0.7, 0.95], {"ranks": {"nova": 3}}],
	["tether", 1, 0.0, [0.04, 0.1, 0.2, 0.35, 0.55, 0.9], {"ranks": {"tether": 3}, "loadout": ["tether", "well", "familiar", "step"]}],
	["well", 2, 0.0, [0.15, 0.5, 1.2, 2.2, 3.3, 3.6], {"ranks": {"well": 3}, "loadout": ["tether", "well", "familiar", "step"]}],
	["familiar", 3, 0.0, [0.25, 0.7, 1.3, 1.9, 2.5, 3.1], {"ranks": {"familiar": 2}, "loadout": ["tether", "well", "familiar", "step"]}],
	["prism", 0, 0.95, [0.05, 0.12, 0.22, 0.4, 0.7, 1.05], {"core": "core_prism", "loadout": ["lance", "nova", "ward", "step"]}],
	["lodestar", 0, 0.95, [0.05, 0.12, 0.22, 0.4, 0.7, 1.05], {"core": "core_lodestar"}],
	["cinder", 0, 0.95, [0.05, 0.12, 0.22, 0.4, 0.7, 1.05], {"core": "core_cinder"}],
	["rime", 0, 0.95, [0.05, 0.12, 0.22, 0.4, 0.7, 1.05], {"core": "core_rime"}],
]
var rows: Array = ROWS.duplicate()
const SPOT := Vector3(8.0, NAN, 48.0)
const YAW := 0.94
var p: Player
var book: Node
var t := 0.0
var phase := "load"
var row := 0
var shot := 0
var row_t := 0.0
var tag := "now"
var frames: Array = []          # [row][col] Image
var target: Node3D
var main: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	Settings.fullscreen = false
	Settings.monitor = -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		if a == "--more":
			rows.append_array(MORE)
	get_window().size = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	t += d
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	match phase:
		"load":
			if Realm.enabled() and not main.has_meta("realm_done"):
				return
			phase = "settle"
			t = 0.0
		"settle":
			if t < 5.0:
				return
			for n in get_tree().get_nodes_in_group(Groups.ENEMY):
				(n as Node).queue_free()
			var at := SPOT
			at.y = RealmLayout.ground(p.get_world_3d().direct_space_state, at.x, at.z) + 0.3
			p.teleport(at)
			p.set_view(YAW, -0.12)
			for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
				if String(c.name) != "Grade":
					(c as CanvasLayer).visible = false
			book = p.get_node_or_null("SkillBook")
			if book == null:
				for c in p.get_children():
					if c is SkillBook:
						book = c
			book.set("using_pad", true)            # the book takes input only with the mouse captured or a pad
			target = Husk.new()
			main.add_child(target)
			var tp := at + Vector3(-sin(YAW), 0.0, -cos(YAW)) * 10.0
			tp.y = RealmLayout.ground(p.get_world_3d().direct_space_state, tp.x, tp.z) + 0.1
			target.global_position = tp
			target.set("max_hp", 99999)
			target.set("hp", 99999.0)
			target.set_physics_process(false)
			target.set_process(false)
			phase = "wait"
			t = 0.0
		"wait":
			if t > 1.5:
				_start_row()
		"row":
			row_t += d
			var r: Array = rows[row]
			var hold: float = r[2]
			if hold > 0.0 and row_t >= hold and Input.is_action_pressed(_action(r[1])):
				Input.action_release(_action(r[1]))
			var times: Array = r[3]
			if shot < times.size() and row_t >= float(times[shot]):
				frames[row].append(get_viewport().get_texture().get_image())
				shot += 1
			if shot >= times.size():
				phase = "gap"
				t = 0.0
		"gap":
			if t > 1.6:
				row += 1
				if row >= rows.size():
					_sheet()
					get_tree().quit()
					return
				_start_row()


func _action(slot: int) -> StringName:
	return (book.get("slots") as Array)[slot].action


func _start_row() -> void:
	var r: Array = rows[row]
	if r.size() > 4:
		_prep(r[4])
	frames.append([])
	shot = 0
	row_t = 0.0
	phase = "row"
	p.set_view(YAW, -0.12)
	if float(r[2]) > 0.0:
		Input.action_press(_action(r[1]))
	else:
		book.call("try_cast", int(r[1]), 0.0, false)
	print("SKILL_SHOT ", r[0])


## --more rows: put the spells, ranks and core in place (memory only; Travel._busy holds the save).
func _prep(want: Dictionary) -> void:
	var k := get_tree().get_first_node_in_group("progression")
	if k == null:
		return
	var st := Travel.system_state("progression")
	st["known"] = ["tether", "well", "familiar"]
	for id: String in (want.get("ranks", {}) as Dictionary):
		(st.ranks as Dictionary)[id] = int(want.ranks[id])
	if want.has("loadout"):
		st["loadout"] = want.loadout
	if want.has("core"):
		Travel.items[String(want.core)] = 1
		st["core"] = want.core
	k.call("refresh")
	for n in get_tree().get_nodes_in_group(&"bound_shade"):
		(n as Node).queue_free()
	for i in (book.get("slots") as Array).size():
		book.call("refund", i, 99.0)
	if target and target.get("marks") != null:
		target.set("marks", 2)


func _sheet() -> void:
	var tw := 320
	var th := 200
	var sheet := Image.create(tw * 6, th * rows.size(), false, Image.FORMAT_RGB8)
	for ri in frames.size():
		for ci in (frames[ri] as Array).size():
			var full: Image = (frames[ri][ci] as Image)
			full.convert(Image.FORMAT_RGB8)
			if ci == 2 or ci == 3:
				full.save_png(ProjectSettings.globalize_path("res://shots/skills_%s_%s_%d.png" % [tag, rows[ri][0], ci]))
			var img := full.duplicate() as Image
			img.resize(tw, th, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(img, Rect2i(0, 0, tw, th), Vector2i(ci * tw, ri * th))
	var path := ProjectSettings.globalize_path("res://shots/skills_%s_sheet.png" % tag)
	sheet.save_png(path)
	print("SKILL_SHOTS saved ", path)
