extends Node
## Renders of the skills UI (B, r28), HUD and grade on, at a lit fire:
##   HOME=<scratch>/home godot --path . res://zz/skill_ui_shot.tscn [-- --tag=after]
##   -> shots/agentB_kindling_<spells|staff|loadout>_<tag>.png, shots/agentB_hud_combo_<tag>.png
## The hud shot casts a Lance on a Marked wretch (KINDLED RIFT) beside an open Well, with a Bound
## Shade out: the hotbar's learned glyphs, working bars, core gem and the combo readout.
## Progress is set in memory only (Travel._busy) and the run quits without saving.

var t := 0.0
var step := 0
var tag := "after"
var p: Player
var g: Node
var k: Node
var main: Node
var foes: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
	get_window().size = Vector2i(1600, 1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	Travel._busy = true
	Travel.story = {"flags": {"arrived": true, "met_keep": true}, "picked": {}}
	Travel.items = {"grave_ash": 64, "relic_fragment": 3, "core_cinder": 1, "core_prism": 1, "charm_hook": 1, "charm_jar": 1}
	Travel.bosses_slain = {"thornwarden": true}
	Travel.systems = {"progression": {"ranks": {"bolt": 2, "lance": 1, "tether": 2, "well": 1, "familiar": 1, "nova": 1},
		"known": ["tether", "well", "familiar"], "loadout": ["lance", "tether", "well", "familiar"], "core": "core_cinder",
		"worn": ["charm_hook", "charm_jar"], "spent": 120}}
	main = (load("res://world/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(main)


func _shot(n: String) -> void:
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/agentB_%s_%s.png" % [n, tag]))
	print("SKILL_UI shot ", n)


func _process(d: float) -> void:
	t += d
	if p == null:
		if main and main.has_meta("realm_done"):
			p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
			g = get_tree().get_first_node_in_group("growth")
			k = get_tree().get_first_node_in_group("progression")
			t = 0.0
		return
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		if not foes.has(e):
			(e as Node).queue_free()
	match step:
		0:
			if t > 2.0:
				var b := _fire()
				b.kindle_quiet()
				p.global_position = b.spawn_point()
				p.set_view(atan2(b.global_position.x - p.global_position.x, b.global_position.z - p.global_position.z) + PI, -0.2)
				step = 1
		1:
			if t > 4.5:
				g.call("open_menu", true, "spells")
				step = 2
		2:
			if t > 5.2:
				var cards: Array = g.get("_cards")
				for i in cards.size():
					if cards[i].kind == "rank" and cards[i].id == "tether" and cards[i].sub == 3:
						g.set("_sel", i)
				g.call("_show")
				step = 3
		3:
			if t > 5.6:
				_shot("kindling_spells")
				g.call("show_tab", 5)
				step = 4
		4:
			if t > 6.0:
				var cards: Array = g.get("_cards")
				for i in cards.size():
					if cards[i].id == "core_lodestar":
						g.set("_sel", i)
				g.call("_show")
				step = 5
		5:
			if t > 6.4:
				_shot("kindling_staff")
				g.call("show_tab", 6)
				step = 6
		6:
			if t > 6.8:
				_shot("kindling_loadout")
				g.call("close_menu")
				_arena()
				step = 7
		7:
			if t > 8.5:
				var book := p.skills()
				book.try_cast(book.slot_of(&"familiar"), 0.0, false)
				step = 8
		8:
			if t > 9.3:
				var book := p.skills()
				for i in book.slots.size():
					book.refund(i, 99.0)
				book.set("_gcd", 0.0)
				book.try_cast(book.slot_of(&"well"), 0.0, false)
				step = 9
		9:
			if t > 9.9:
				var book := p.skills()
				book.set("_gcd", 0.0)
				book.try_cast(book.slot_of(&"lance"), 0.0, false)
				step = 10
		10:
			if t > 10.6:
				_shot("hud_combo")
				get_tree().quit()


func _arena() -> void:
	var fwd := -p.global_basis.z
	var cam := get_viewport().get_camera_3d()
	if cam:
		fwd = -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var at := p.global_position
	for i in 3:
		var w := Wretch.new()
		main.add_child(w)
		var q := at + fwd * (7.0 + float(i)) + fwd.cross(Vector3.UP) * (float(i) - 1.0) * 1.6
		q.y = RealmLayout.ground(p.get_world_3d().direct_space_state, q.x, q.z) + 0.05
		w.global_position = q
		w.max_hp = 40
		w.hp = 40.0
		w.set_physics_process(false)
		w.add_mark(2)
		foes.append(w)
	p.set_view(atan2(-fwd.x, -fwd.z), -0.3)


func _fire() -> Brazier:
	var b: Brazier = null
	for n in get_tree().get_nodes_in_group(Groups.INTERACTABLE):
		if n is Brazier and (b == null or String(n.name) == "Sanctuary"):
			b = n
	return b
