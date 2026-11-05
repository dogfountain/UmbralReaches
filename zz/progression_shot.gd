extends Node
## Renders of the Kindling (progression) in game, HUD and grade on:
##   godot --path . res://zz/progression_shot.tscn  -> shots/progression_<n>.png
##   kindling_embers / spells / oaths / relics / charms   each page of the menu at a lit fire
##   kindling_buy      the frame after a purchase (ember burst, card flare)
##   satchel           the Satchel with charms
##   spell_cinder      Ember Lance III: a full charge's Cinder Scar burning under three wretches
##   spell_undertow    Umbral Nova III: the ring dragging wretches in, inside a Bramble Ward
## Progress is set in memory only (Travel saving held off) and the run ends with OS.kill, so the
## real save is never written.
const DB := preload("res://core/life/progression/upgrade_db.gd")
const KindlingS := preload("res://core/life/progression/kindling.gd")
const CinderScarS := preload("res://core/life/progression/fx/cinder_scar.gd")
var t := 0.0
var step := 0
var p: Player
var g: Node
var k: Node
var main: Node
var _wretches: Array[Node3D] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().size = Vector2i(1600, 1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	Travel.set("_busy", true)
	Travel.story = {"flags": {"arrived": true, "met_keep": true}, "picked": {}}
	Travel.items = {"grave_ash": 64, "thorn_heart": 1, "charm_thread": 1, "charm_candle": 1, "charm_clapper": 1, "heart_stone": 1, "cinder_censer": 1}
	Travel.relics = {"thorn": &"briar"}
	Travel.bosses_slain = {"thornwarden": true}
	Travel.systems = {"progression": {"ranks": {"warmth": 2, "will": 1, "bolt": 2, "nova": 1, "step": 1}, "oaths": {"1": "a"}, "worn": ["charm_thread", "charm_candle"], "spent": 70}}
	main = (load("res://world/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(main)


func _shot(n: String) -> void:
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/progression_%s.png" % n))
	print("PROG shot ", n)


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
		if not _wretches.has(e):
			(e as Node).queue_free()
	match step:
		0:
			if t > 2.0:
				var b: Brazier = null
				for n in get_tree().get_nodes_in_group(Groups.INTERACTABLE):
					if n is Brazier and (b == null or String(n.name) == "Sanctuary"):
						b = n
				b.kindle_quiet()
				p.global_position = b.spawn_point()
				p.set_view(atan2(b.global_position.x - p.global_position.x, b.global_position.z - p.global_position.z) + PI, -0.2)
				step = 1
		1:
			if t > 4.5:
				g.call("open_menu", true, "embers")
				step = 2
		2:
			if t > 5.2:
				_shot("kindling_embers")
				g.call("show_tab", 1)
				step = 3
		3:
			if t > 5.6:
				_shot("kindling_spells")
				g.call("show_tab", 2)
				step = 4
		4:
			if t > 6.0:
				_shot("kindling_oaths")
				g.call("show_tab", 3)
				step = 5
		5:
			if t > 6.4:
				_shot("kindling_relics")
				g.call("show_tab", 4)
				step = 6
		6:
			if t > 6.8:
				g.set("_sel", 9)
				g.call("_show")
				var sc := (g.get("_page_box") as Control).get_parent() as ScrollContainer
				sc.scroll_vertical = 400
				await get_tree().process_frame
				_shot("kindling_charms")
				g.call("show_tab", 0)
				var cards: Array = g.get("_cards")
				for i in cards.size():
					if cards[i].id == "will":
						g.set("_sel", i)
				g.call("act")
				step = 7
		7:
			if t > 7.05:
				_shot("kindling_buy")
				step = 8
		8:
			if t > 7.6:
				g.call("close_menu")
				var sat := main.get_node_or_null("Satchel")
				sat.call("open_menu")
				sat.call("select_id", "charm_thread")
				step = 9
		9:
			if t > 8.2:
				_shot("satchel")
				main.get_node("Satchel").call("close_menu")
				_arena()
				step = 10
		10:
			if t > 10.0:
				# a full-charge Ember Lance at the ground among them
				var book := p.skills()
				book.slots[1].call("cast", book, 1.0)
				# where a full charge bursts among them (the real lance flies on past the frame)
				var mid := Vector3.ZERO
				for w in _wretches:
					mid += w.global_position / float(_wretches.size())
				var q := PhysicsRayQueryParameters3D.create(mid + Vector3.UP * 2.0, mid + Vector3.DOWN * 4.0, Layers.WORLD)
				var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
				CinderScarS.light_at(main, hit.position if not hit.is_empty() else mid)
				step = 11
		11:
			if t > 11.6:
				_shot("spell_cinder")
				var book := p.skills()
				book.try_cast(3, 0.0, false)                  # Bramble Ward (Mirror Flame too)
				for i in _wretches.size():
					var w := _wretches[i]
					if is_instance_valid(w):
						w.global_position = p.global_position + Basis(Vector3.UP, _yaw) * Vector3((float(i) - 1.0) * 3.4, 0.4, -6.0 + absf(float(i) - 1.0))
						w.add_mark(2)
						w.set_physics_process(true)
				step = 12
		12:
			if t > 13.4:
				var book := p.skills()
				book.slots[2].call("_detonate", p)
				step = 13
		13:
			if t > 13.62:
				_shot("spell_undertow")
				step = 14
		14:
			if t > 12.6:
				print("PROG done")
				OS.kill(OS.get_process_id())


var _yaw := 0.0


## Ranks for the spell shots, three wretches ahead on open ground, the view on the ground ahead.
func _arena() -> void:
	var st := Travel.system_state("progression")
	st.ranks["lance"] = 3
	st.ranks["nova"] = 3
	st.ranks["ward"] = 3
	st.ranks["bramble"] = 1
	k.call("refresh")
	var space := p.get_world_3d().direct_space_state
	var at := Vector3.INF
	for c: Vector2 in [Vector2(-28.0, 60.0), Vector2(24.0, 52.0), Vector2(-36.0, 30.0), Vector2(36.0, 44.0), Vector2(6.0, 58.0), Vector2(-14.0, 64.0)]:
		var g0 := KindlingS.ground_spot(space, c)
		if g0 == Vector3.INF:
			print("PROG arena ", c, " no ground")
			continue
		var clear := true
		for j in 16:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * float(j) / 16.0)
			var q := PhysicsRayQueryParameters3D.create(g0 + Vector3.UP * 1.2, g0 + Vector3.UP * 1.2 + dir * 8.0, Layers.WORLD | Layers.PROPS)
			if not space.intersect_ray(q).is_empty():
				print("PROG arena ", c, " blocked at ", space.intersect_ray(q).position)
				clear = false
				break
		if clear:
			at = g0
			break
	if at == Vector3.INF:
		at = p.global_position
	print("PROG arena at ", at)
	p.global_position = at + Vector3.UP * 0.2
	_yaw = PI * 0.5
	p.set_view(_yaw, -0.2)
	for i in 3:
		var w := Wretch.new()
		main.add_child(w)
		w.global_position = at + Basis(Vector3.UP, _yaw) * Vector3((float(i) - 1.0) * 1.5, 0.05, -7.0 - float(i % 2))
		w.max_hp = 40
		w.hp = 40.0
		w.set_physics_process(false)           # held still for the frame
		_wretches.append(w)
