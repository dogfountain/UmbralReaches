extends Node
var p: Player
var t := 0
var step := 0
var wait := 0
var log_ok := []
func _ready() -> void:
	# start from a fresh progress whatever the save on disk holds (it is shared with other runs);
	# the test still writes the save as it goes, so back it up and restore it around a run
	Travel.seals_broken.clear()
	Travel.bosses_slain.clear()
	Travel.items.clear()
	Travel.relics.clear()
	# r36 Act II: the summit opens to a peal; four of the Founder's bells answered for (rung, so
	# the Warden keeps his whole life for the fight's numbers)
	var qb := preload("res://core/story/quest_book.gd")
	for bid: String in (preload("res://core/story/quest_chains.gd").BELLS as Array).slice(0, 4):
		qb.start(bid)
		qb.choose(bid, "rung")
	
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
## r30: a boss stands shelled through its intro and holds each phase until its signature move has
## been seen twice (BossKit.phase_floor): the test's killing blow lifts both.
func _slay(b: Enemy) -> void:
	b._ward_t = 0.0
	b.set_meta(&"test_no_floor", true)
	b.take_hit(999.0)


func _seal(id: String) -> WardSeal:
	for s in get_tree().get_nodes_in_group(&"ward_seal"):
		if (s as WardSeal).seal_id == id: return s
	return null
func _arena(id: String) -> BossArena:
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		if (a as BossArena).boss_id == id: return a
	return null
func _kill_seal(id: String) -> int:
	var sp_all := get_tree().root.find_children("EnemySpawner", "", true, false)
	var n := 0
	for sp in sp_all:
		for slot in sp._slots:
			if slot.get("seal", "") == id and is_instance_valid(slot.pawn) and slot.pawn is Enemy and (slot.pawn as Enemy).is_alive():
				var e := slot.pawn as Enemy
				e.marks = 3
				e.take_hit(999.0)
				n += 1
	return n
func _tp(at: Vector3) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
func _boss() -> Enemy:
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		if (e as Node).has_meta(&"boss_id"): return e
	return null
## Under --realm the zone is built over many frames: wait for the camps to be planted.
func _realm_ready() -> bool:
	var main := p.owner if p.owner else p.get_parent()
	if not main.has_meta("summit_dressed"):
		return false
	for sp in get_tree().root.find_children("EnemySpawner", "", true, false):
		if sp.get_parent() == main and (sp._slots as Array).size() > 0:
			return true
	return false
## Teleport onto the ground at xz (realm: the ground is not where the old numbers expect it).
func _tp_ground(x: float, z: float) -> void:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 80, z), Vector3(x, -40, z), Layers.WORLD)
	var h := p.get_world_3d().direct_space_state.intersect_ray(q)
	_tp(Vector3(x, ((h.position as Vector3).y if h else 2.0) + 0.6, z))
func check(name: String, ok: bool) -> void:
	print("BOSSTEST ", "PASS " if ok else "FAIL ", name)
func _physics_process(_d: float) -> void:
	t += 1
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	p.wounds = 0.0                  # r35: blows wound now; this test is the progression, not survival
	if wait > 0:
		wait -= 1
		return
	match step:
		0:
			if t < 60: return
			if not _realm_ready():
				if t % 600 == 0: print("BOSSTEST waiting for the realm (", t, ")")
				return
			print("BOSSTEST realm ready at frame ", t, " henge at ", ThornHenge.C)
			p.set_physics_process(true)
			print("BOSSTEST henge guards killed ", _kill_seal("henge")); step = 1; wait = 30
		1:
			check("henge seal broken", Travel.seals_broken.has("henge"))
			check("thorn gate open", _seal("henge") != null and _seal("henge").is_open())
			_tp(ThornHenge.C + Vector3(2, 0.5, 2)); step = 2; wait = 20
		2:
			var b := _boss()
			check("thornwarden rose", b is Thornwarden)
			check("thorn gate closed behind", _seal("henge") != null and _seal("henge")._body.collision_layer != 0)
			_tp_ground(ThornHenge.C.x + 42.0, ThornHenge.C.z + 42.0)        # (59 m: past the 1.6x room and the 6 m leave margin)
			step = 20; wait = 20      # run away: r35, the fight is held (it used to reset)
		20:
			check("leaving holds the fight (r35) and opens the gate", _held_arena("thornwarden") and _seal("henge")._body.collision_layer == 0)
			_tp(ThornHenge.C + Vector3(2, 0.5, 2)); step = 21; wait = 20
		21:
			var b := _boss()
			check("coming back resumes it (the same Thornwarden)", b is Thornwarden and not _held_arena("thornwarden"))
			if b: _slay(b)
			step = 3; wait = 40
		3:
			check("thornwarden slain saved", Travel.bosses_slain.has("thornwarden"))
			check("thorn heart in satchel", Travel.count("thorn_heart") == 1)
			check("thorn relic attuned to splinter", Travel.relics.get("thorn", &"") == &"splinter")
			var sat := _ui_satchel() as Satchel
			sat.open_menu(true)
			sat.select_id("thorn_heart")
			sat.try_attune()
			check("attune at a fire switches to briar", Travel.relics.get("thorn", &"") == &"briar")
			sat.close_menu()
			check("ash from kills and boss", Travel.count("grave_ash") >= 6 + ItemDB.ASH_PER_BOSS)
			check("thorn gate reopened", _seal("henge").is_open() and _seal("henge")._body.collision_layer == 0)
			_tp(Vector3(22.0, 9.0, -55.0)); step = 4; wait = 240     # stream the Ossuary in
		4:
			print("BOSSTEST gallery guards killed ", _kill_seal("oss_gallery")); step = 5; wait = 30
		5:
			check("portcullis seal broken", Travel.seals_broken.has("oss_gallery"))
			check("portcullis open", _seal("oss_gallery") != null and _seal("oss_gallery").is_open())
			_tp(Ossuary.abbot_pull_at()); step = 6; wait = 20     # r34 crypt: the pit hall, past its inner grille
		6:
			var b := _boss()
			check("bone abbot rose", b is BoneAbbot)
			if b:
				b.marks = 3
				_slay(b)
			step = 7; wait = 60
		7:
			check("abbot slain saved", Travel.bosses_slain.has("bone_abbot"))
			var r := get_tree().root.find_child("BoneReliquary", true, false) as Reliquary
			check("reliquary rose from the mound", r != null)
			if r: r.interact(p)
			step = 8; wait = 60
		8:
			check("relic taken and saved", Travel.relics.has("bone"))
			check("reliquary + crown in satchel", Travel.count("bone_reliquary") == 1 and Travel.count("abbot_crown") == 1)
			check("reliquary left the world", get_tree().root.find_child("BoneReliquary", true, false) == null)
			_tp_ground(RealmLayout.CROSSING_FOOT.x + 4.0, RealmLayout.CROSSING_FOOT.z + 6.0)   # the stair is gone: the Crossing's foot
			step = 9; wait = 30
		9:
			print("BOSSTEST summit guards killed ", _kill_seal("summit")); step = 10; wait = 30
		10:
			check("summit ward open", _seal("summit") != null and _seal("summit").is_open())
			_tp(SummitDress.SUMMIT + Vector3(SummitDress.DAIS_C.x, SummitDress.TOP_DECK_Y + 0.45, SummitDress.DAIS_C.y + 6.0)); step = 11; wait = 20   # onto the dais
		11:
			var b := _boss()
			check("ascended warden rose", b is AscendedWarden)
			if b: _slay(b)
			step = 12; wait = 40
		12:
			check("warden slain saved", Travel.bosses_slain.has("ascended_warden"))
			var cfg := ConfigFile.new()
			check("save file has seals and bosses", cfg.load(Travel.SAVE_PATH) == OK and (cfg.get_value("progress", "bosses", {}) as Dictionary).size() == 3)
			check("save file has the satchel", (cfg.get_value("progress", "items", {}) as Dictionary).get("ascension_seal", 0) == 1)
			var sat := _ui_satchel() as Satchel
			sat.open_menu()
			# r35: the Satchel is the character screen's Pack: trophies and materials (relics are on Wanderer)
			var relic_shown := false
			for s in sat._slots:
				if String(ItemDB.def(String(s.id)).kind) == "relic":
					relic_shown = true
			check("the Pack shows trophies and materials, no relics (%d)" % sat._slots.size(), sat._slots.size() >= 2 and not relic_shown and get_tree().paused)
			sat.close_menu()
			check("satchel closes and unpauses", not sat.is_open() and not get_tree().paused)
			get_tree().quit()



## The inventory screen (a CanvasLayer named Satchel), not the satchel bag on the wanderer's belt.
func _ui_satchel() -> Node:
	for n in get_tree().root.find_children("Satchel", "CanvasLayer", true, false):
		return n
	return null


## r35: the arena for `id` holds a walked-out fight.
func _held_arena(id: String) -> bool:
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		if a is BossArena and (a as BossArena).boss_id == id:
			return (a as BossArena).is_held()
	return false
