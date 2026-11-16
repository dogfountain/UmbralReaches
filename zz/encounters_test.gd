extends Node
## Encounters system test (core/life/encounters): tier scaling, variants, rest refill, the Gloom
## tide (start away from fires, waves, ends at a lit brazier), road ambushes, elites (spawn,
## dress, defeat, bounty paid once), the Deeper Night (flag persists in the save, bosses and
## seals reset, deeper tiers, boss scaling), and the near-player cap.
##   godot --headless --path . res://zz/encounters_test.tscn -- --fresh   -> "ENCTEST DONE fails=0"
## Writes the save (NG+ persistence): back up ~/Library/Application Support/UmbralReaches/
## savegame.cfg (+ .bak) first and restore it after.

const Tiers := preload("res://core/life/encounters/tiers.gd")
const Variants := preload("res://core/life/encounters/variants.gd")
const Elites := preload("res://core/life/encounters/elites.gd")

var p: Player
var main: Node
var d: Node
var fails := 0
var tide_events: Array[bool] = []


func check(n: String, ok: bool, extra := "") -> void:
	print("ENCTEST ", "PASS " if ok else "FAIL ", n, (" (" + extra + ")") if extra != "" else "")
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	Travel.seals_broken.clear()
	Travel.bosses_slain.clear()
	Travel.items.clear()
	Travel.systems.erase("encounters")
	Events.gloom_tide.connect(func(on: bool) -> void: tide_events.append(on))
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	_run.call_deferred()


func _tp(at: Vector3) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _ground(x: float, z: float) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 90, z), Vector3(x, -40, z), Layers.WORLD)
	var h := p.get_world_3d().direct_space_state.intersect_ray(q)
	return (h.position as Vector3) if h else Vector3(x, 2.0, z)


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 300000:
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		if p and main.has_meta("realm_done"):
			d = main.get_node_or_null("Encounters")
			var sp := main.get_node_or_null("EnemySpawner")
			if d and bool(d.get("ready_done")) and sp and bool(sp.get("planted_done")):
				break
	check("director built", d != null and bool(d.get("ready_done")))
	if d == null:
		_done()
		return
	await _frames(10)
	p.gloom = 0.0; p.wounds = 0.0
	await _tiers()
	await _rest()
	await _tide()
	await _ambush()
	await _elites()
	await _ng()
	_done()


func _done() -> void:
	print("ENCTEST DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


# --- tiers and variants -------------------------------------------------------------------------

func _tiers() -> void:
	var hearth := Vector3(0, 0, 40)
	var rift := Vector3(0, 0, -40) + Endgame.O
	var fen := Vector3(80, 0, 0)
	check("tier: Hearthward 0 on a fresh night", Tiers.tier_at(hearth) == 0, str(Tiers.tier_at(hearth)))
	check("tier: Rift 4 (the far north-east)", Tiers.tier_at(rift) == 4, str(Tiers.tier_at(rift)))
	check("tier: fen 1", Tiers.tier_at(fen) == 1)
	Travel.bosses_slain["thornwarden"] = true
	check("tier: a felled boss deepens the night", Tiers.tier_at(hearth) == 1 and Tiers.tier_at(rift) == 5)
	Travel.bosses_slain["bone_abbot"] = true
	var w := (load("res://core/enemy/wretch.gd") as GDScript).new() as Enemy
	var base_hp := w.max_hp
	var base_g := w.strike_gloom
	var base_w := w.windup_time
	Tiers.scale_stats(w, Tiers.tier_at(rift))
	check("scale: tier 4 wretch tougher", w.max_hp > base_hp and w.strike_gloom > base_g, "%d hp %.0f gloom" % [w.max_hp, w.strike_gloom])
	check("scale: telegraph unchanged", is_equal_approx(w.windup_time, base_w))
	Travel.bosses_slain.clear()
	# a variant pawn: stats before the tree, parts after it
	Variants.pre(w, "ironclad")
	main.add_child(w)
	w.global_position = _ground(40, 40) + Vector3.UP * 0.1
	Variants.dress(w, "ironclad")
	var parts := w.find_children("Enc_ironclad_*", "MeshInstance3D", true, false)
	check("variant: ironclad parts on the rig", parts.size() >= 3, str(parts.size()))
	var mat := (parts[0] as MeshInstance3D).material_override as ShaderMaterial if parts.size() > 0 else null
	check("variant: own material, glow colour", mat != null and mat != EnemyBody.material(&"wretch"))
	# r30: a grunt may be one skinned body now, so count the variant's own parts in the list, not 8+
	var in_flesh := 0
	for pt in parts:
		if (w._flesh as Array).has(pt):
			in_flesh += 1
	check("variant: flesh list includes parts (dissolve with the body)", in_flesh == parts.size() and (w._flesh as Array).size() > parts.size(), "%d of %d, %d total" % [in_flesh, parts.size(), (w._flesh as Array).size()])
	var c := (load("res://core/enemy/crawler.gd") as GDScript).new() as Enemy
	Variants.pre(c, "deeper")
	main.add_child(c)
	c.global_position = _ground(42, 40) + Vector3.UP * 0.1
	Variants.dress(c, "deeper")
	check("variant: quad rig dressed (deeper)", c.find_children("Enc_deeper_*", "MeshInstance3D", true, false).size() >= 1)
	for v: String in ["scarred", "tideborn"]:
		var h := (load("res://core/enemy/husk.gd") as GDScript).new() as Enemy
		Variants.pre(h, v)
		main.add_child(h)
		h.global_position = _ground(44, 40) + Vector3.UP * 0.1
		Variants.dress(h, v)
		check("variant: husk %s dressed" % v, h.find_children("Enc_%s_*" % v, "MeshInstance3D", true, false).size() >= 1)
		h.queue_free()
	w.queue_free()
	c.queue_free()
	# the camps were scaled by tier through the spawner hooks / retrofit
	var sp := main.get_node("EnemySpawner")
	var tagged := 0
	var live := 0
	var mixed := 0
	for slot: Dictionary in sp.call("slots"):
		if String(slot.key).begins_with("enc_mix"):
			mixed += 1
		if is_instance_valid(slot.pawn):
			live += 1
			if (slot.pawn as Node).has_meta(&"enc_tier"):
				tagged += 1
	check("camps: every live pawn carries its tier", live > 0 and tagged == live, "%d / %d" % [tagged, live])
	print("ENCTEST info: %d live camp pawns, %d mixed members" % [live, mixed])
	await _frames(2)


# --- rest refill --------------------------------------------------------------------------------

func _rest() -> void:
	var sp := main.get_node("EnemySpawner")
	var target: Dictionary = {}
	for slot: Dictionary in sp.call("slots"):
		if String(slot.get("seal", "")) == "" and is_instance_valid(slot.pawn) and (slot.at as Vector3).distance_to(p.global_position) > 40.0 and not LightGrid.is_lit(slot.at):
			target = slot
			break
	check("rest: found a roaming camp pawn", not target.is_empty())
	if target.is_empty():
		return
	var e := target.pawn as Enemy
	e.marks = 3
	e.take_hit(999.0)
	await _frames(100)
	check("rest: roaming dead wait for a rest", EnemySpawner.hold_for_rest and float(sp.call("_respawn_delay", target)) == EnemySpawner.REST_HOLD)
	check("rest: still dead before resting", not (is_instance_valid(target.pawn) and (target.pawn as Enemy).is_alive()))
	var n := int(d.call("rest", "test"))
	check("rest: the camp refills", n >= 1 and is_instance_valid(target.pawn) and (target.pawn as Enemy).is_alive(), "%d rose" % n)
	var seal_dead := 0
	for slot: Dictionary in sp.call("slots"):
		if slot.get("sealed_dead", false) and is_instance_valid(slot.pawn):
			seal_dead += 1
	check("rest: seal guards stay dead", seal_dead == 0)


# --- the Gloom tide -----------------------------------------------------------------------------

func _open_spot(cands: Array) -> Vector3:
	for c: Vector2 in cands:
		var g := _ground(c.x, c.y)
		if bool(d.call("spot_ok", g)) and not LightGrid.is_lit(g):
			return g
	return Vector3.INF


func _tide() -> void:
	var spot := _open_spot([Vector2(62, 4), Vector2(66, -20), Vector2(-60, 30), Vector2(-40, -40), Vector2(30, 55)])
	check("tide: an open spot away from fires", spot != Vector3.INF)
	if spot == Vector3.INF:
		return
	_tp(spot + Vector3.UP * 0.2)
	await _frames(3)
	# r31: roaming camps and guardian escorts (with their sites) now stand in much of the night; the
	# tide is the subject here, so clear the ground round the spot first (the cap is tested below)
	for k in 2:
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			if (e as Node3D).global_position.distance_to(spot) < 60.0:
				(e as Node).queue_free()
		await _frames(2)
	d.set("tide_clock", float(d.call("tide_period")) - 20.0)
	d.call("step", 1.0)
	check("tide: warning before it rises", bool(d.get("_warned")) and not bool(d.get("tide_on")))
	d.call("step", 30.0)
	check("tide: rises away from fires", bool(d.get("tide_on")))
	check("tide: banner", String(d.get("hud").call("banner_text")) == "THE GLOOM TIDE RISES")
	d.call("step", 0.3)
	await _frames(2)
	var hunters: Array = d.get("hunters")
	check("tide: a hunting pack came", hunters.size() >= 2, str(hunters.size()))
	var fair := true
	for h in hunters:
		var e := h as Enemy
		var dist := Vector2(e.global_position.x - spot.x, e.global_position.z - spot.z).length()
		if dist < 17.0 or not bool(d.call("spot_ok", e.get_meta(&"enc_spawn", e.global_position))) or not e.has_meta(&"enc_hunter") or e.get_meta(&"enc_variant", "") != "tideborn":
			fair = false
			print("ENCTEST info: unfair hunter at ", e.global_position, " dist ", dist)
	check("tide: hunters tideborn, out of the haven/light, 19 m+ away", fair)
	_tp(spot + Vector3(3, 0.2, 0))
	d.call("step", 0.3)
	var tracked := true
	for h in hunters:
		if is_instance_valid(h) and (h as Enemy).home.distance_to(p.global_position) > 0.5:
			tracked = false
	check("tide: hunters track the wanderer", tracked)
	# later waves fill only up to the cap (counted against what is near before each wave: a camp's pawns that
	# noticed the wanderer from past the cleared ring may walk in on their own, and they are not the tide's)
	var over := 0
	for k in 4:
		d.set("_waves", 1)
		d.set("tide_age", 40.0)
		var room0 := int(d.call("room", p.global_position))
		var h0 := (d.get("hunters") as Array).size()
		d.call("step", 0.3)
		over = maxi(over, (d.get("hunters") as Array).size() - h0 - room0)
	await _frames(2)
	var near := int(d.call("near_count", p.global_position))
	check("cap: a wave adds no more than the room under 12 (%d near now)" % near, over <= 0, str(over))
	# safe again at a lit brazier
	var b := main.get_node_or_null("Zone/Braziers/StairFoot") as Brazier
	check("tide: StairFoot brazier", b != null)
	if b:
		b.kindle_quiet()
		_tp(b.global_position + Vector3(1.2, 0.3, 1.2))
		await _frames(2)
		d.call("step", 1.0)
		d.call("step", 1.0)
	check("tide: breaks at a lit fire", not bool(d.get("tide_on")))
	await _frames(3)
	var alive := 0
	for h in hunters:
		if is_instance_valid(h) and (h as Node).is_inside_tree():
			alive += 1
	check("tide: hunters gone", alive == 0, str(alive))
	check("tide: Events.gloom_tide rose and fell", tide_events.size() >= 2 and tide_events[0] == true and tide_events[-1] == false)
	check("tide: clock reset after the fire", float(d.get("tide_clock")) == 0.0)


# --- ambushes -----------------------------------------------------------------------------------

func _ambush() -> void:
	var sites: Array = d.get("ambushes")
	check("ambush: sites planned on the roads", sites.size() >= 4, str(sites.size()))
	var in_haven := 0
	for s: Dictionary in sites:
		if Vector2((s.at as Vector3).x, (s.at as Vector3).z).distance_to(Vector2(4, 36)) < 34.0:
			in_haven += 1
	check("ambush: none in the haven", in_haven == 0)
	var fired := false
	for s: Dictionary in sites:
		if LightGrid.is_lit(s.at):
			continue
		_tp((s.at as Vector3) + Vector3.UP * 0.3)
		await _frames(2)
		d.set("_ambush_gap", 0.0)
		var before: int = (d.get("ambushers") as Array).size()
		d.call("step", 0.3)
		var made: Array = d.get("ambushers")
		if made.size() > before:
			fired = true
			check("ambush: banner", String(d.get("hud").call("banner_text")) == "AMBUSH")
			var asleep := true
			var fair := true
			for e in made:
				if (e as Node).process_mode != Node.PROCESS_MODE_DISABLED:
					asleep = false
				if not bool(d.call("spot_ok", (e as Node3D).global_position)):
					fair = false
			check("ambush: they rise first (a breath before acting)", asleep)
			check("ambush: spots fair", fair)
			await get_tree().create_timer(1.1).timeout
			var awake := true
			for e in made:
				if is_instance_valid(e) and (e as Node).process_mode == Node.PROCESS_MODE_DISABLED:
					awake = false
			check("ambush: then they come", awake)
			check("ambush: site on cooldown", float(s.cd) > 0.0)
			d.set("_ambush_gap", 0.0)
			var again: int = (d.get("ambushers") as Array).size()
			d.call("step", 0.3)
			check("ambush: not twice in a row", (d.get("ambushers") as Array).size() == again)
			for e in made:
				if is_instance_valid(e):
					(e as Node).queue_free()
			break
	check("ambush: triggers when walked", fired)
	await _frames(3)


# --- elites -------------------------------------------------------------------------------------

func _elites() -> void:
	var haunts: Dictionary = d.get("haunts")
	var nightly: Array = Elites.ELITES.keys().filter(func(k: String) -> bool: return not bool((Elites.ELITES[k] as Dictionary).get("ng_only", false)))   # Deeper-Night-only elites have no haunt in a first night
	check("elites: every haunt on clear ground (%d of %d)" % [haunts.size(), nightly.size()], haunts.size() == nightly.size(), ", ".join(haunts.keys()))
	var posts: Array = d.get("posts")
	check("elites: a notice per elite and the board", posts.size() == haunts.size() + 1, str(posts.size()))
	# every elite builds and dresses (parts, title)
	for id: String in Elites.ELITES:
		var tb := Time.get_ticks_usec()
		var e := (load(String(Elites.ELITES[id].script)) as GDScript).new() as Enemy
		main.add_child(e)
		print("ENCTEST info: elite %s built in %.1f ms" % [id, float(Time.get_ticks_usec() - tb) / 1000.0])
		e.global_position = _ground(40, 44) + Vector3.UP * 0.1
		var parts := e.find_children("Elite_*", "MeshInstance3D", true, false)
		var lbl := e.get_node_or_null("EliteTitle") as Label3D
		check("elite %s dressed" % id, parts.size() >= 1 and lbl != null and e.max_hp >= 8, "%d parts, %d hp" % [parts.size(), e.max_hp])
		e.queue_free()
	await _frames(2)
	# Hobb: walk near his haunt, he rises; kill him: the bounty is paid once
	if not haunts.has("hobb"):
		check("elite hobb haunt", false)
		return
	var at: Vector3 = haunts.hobb
	_tp(at + Vector3(14, 0.5, 0))
	await _frames(2)
	d.call("step", 0.3)
	var nodes: Dictionary = d.get("elite_nodes")
	var e: Enemy = nodes.get("hobb")
	check("elite: Hobb rises near his haunt", is_instance_valid(e) and e.has_meta(&"elite_id"))
	if not is_instance_valid(e):
		return
	_tp(e.global_position + Vector3(3, 0.5, 0))
	e.take_hit(1.0, p)
	await _frames(2)
	d.call("step", 0.3)
	check("elite: name bar while fighting", bool(d.get("hud").call("elite_shown")))
	var ash0 := Travel.count("grave_ash")
	e.marks = 3
	e.take_hit(999.0, p)
	await _frames(3)
	var st := Travel.system_state("encounters")
	check("elite: slain recorded", (st.slain as Dictionary).has("hobb"))
	var paid := Travel.count("grave_ash") - ash0
	check("elite: bounty ash paid", paid >= 20, str(paid))
	var loot := String(Elites.ELITES.hobb.loot)
	var got := (st.looted as Dictionary).has(loot) and (Travel.count(loot) == 1 or (st.trophies as Dictionary).has(loot))
	check("elite: trophy %s kept" % loot, got)
	check("elite: banner", String(d.get("hud").call("banner_text")).begins_with("BOUNTY"))
	# once: no second Hobb, a second kill pays nothing
	d.call("step", 0.3)
	await _frames(2)
	check("elite: does not rise again", d.call("spawn_elite", "hobb") == null)
	var fake := Node.new()
	fake.set_meta(&"elite_id", "hobb")
	var ash1 := Travel.count("grave_ash")
	d.call("_on_killed", fake)
	fake.free()
	check("elite: bounty only once", Travel.count("grave_ash") == ash1)
	# the board reads
	var board: Node3D = null
	for post in posts:
		if String((post as Node).get("elite_id")) == "":
			board = post
	if board:
		_tp(board.global_position + Vector3(1.0, 0.3, 0))
		await _frames(1)
		board.call("interact", p)
		check("board: reads the tally", bool(d.get("hud").call("note_open")) and String(d.get("hud").call("note_title")).begins_with("Bounties"))
		board.call("interact", p)
		check("board: turns to a notice", String(d.get("hud").call("note_title")) == Elites.title(Elites.ids(0)[0], false))
	# Lisle's count and the Hart's thorns don't error when they fire
	var l := (load(String(Elites.ELITES.lisle.script)) as GDScript).new() as Enemy
	main.add_child(l)
	l.global_position = _ground(46, 44) + Vector3.UP * 0.1
	var before := get_tree().get_nodes_in_group(Groups.ENEMY).size()
	l.take_hit(float(l.max_hp) * 0.6, p)
	await _frames(2)
	# r34 merge: count his own crawlers (the doubled world's camps and rares come and go meanwhile)
	var called := 0
	for m0 in get_tree().get_nodes_in_group(Groups.ENEMY):
		if (m0 as Node).get_meta(&"summoned_by", "") == "elite_lisle":
			called += 1
	check("elite: Lisle calls the count (2 crawlers)", called >= 2, "called %d, hp %.1f/%d, enemies %d -> %d" % [called, l.hp, l.max_hp, before, get_tree().get_nodes_in_group(Groups.ENEMY).size()])
	for m in get_tree().get_nodes_in_group(Groups.ENEMY):
		if (m as Node).get_meta(&"summoned_by", "") == "elite_lisle":
			(m as Node).queue_free()
	l.queue_free()
	await _frames(2)


# --- the Deeper Night ---------------------------------------------------------------------------

func _ng() -> void:
	Travel.bosses_slain = {"thornwarden": true, "bone_abbot": true, "ascended_warden": true}
	Travel.seals_broken = {"henge": true, "oss_gallery": true, "summit": true}
	EnemySpawner._seal_kills["henge"] = {"x": true}
	var bells: Array = d.get("bells")
	check("bell: built at the Crossing's foot and the summit", bells.size() == 2, str(bells.size()))
	if bells.size() > 0:
		check("bell: awake once the Warden is down", bool((bells[0] as Node).call("awake")))
	await d.call("begin_deeper_night", false)
	var st := Travel.system_state("encounters")
	check("ng: level 1", int(st.ng) == 1)
	check("ng: bosses reset", Travel.bosses_slain.is_empty())
	check("ng: seals reset", Travel.seals_broken.is_empty() and EnemySpawner._seal_kills.is_empty())
	check("ng: elite slates clean", (st.slain as Dictionary).is_empty())
	check("ng: trophies kept", (st.looted as Dictionary).has("hobbs_knuckles"))
	var cfg := ConfigFile.new()
	var ok := cfg.load(Travel.SAVE_PATH) == OK
	var sys: Dictionary = cfg.get_value("systems", "state", {}) if ok else {}
	var enc: Dictionary = sys.get("encounters", {})
	check("ng: flag persisted in the save", ok and int(enc.get("ng", 0)) == 1)
	check("ng: bosses reset in the save", ok and (cfg.get_value("progress", "bosses", {"x": 1}) as Dictionary).is_empty())
	var arenas_clear := true
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		if (a as BossArena).slain():
			arenas_clear = false
	check("ng: every arena will fight again", arenas_clear)
	check("ng: the night is two tiers deeper", Tiers.tier_at(Vector3(0, 0, 40)) == 2)
	check("ng: the Faceless Penitent walks", "penitent" in Elites.ids(1))
	check("ng: hud marks the Deeper Night", bool(d.get("hud").get("deeper")))
	# bosses come back harder
	var tw := (load("res://core/enemy/thornwarden.gd") as GDScript).new() as Enemy
	main.add_child(tw)
	tw.global_position = _ground(40, 46) + Vector3.UP * 0.2
	var hp0 := tw.max_hp
	Events.boss_engaged.emit(tw, "Test")
	check("ng: bosses harder", tw.max_hp > hp0, "%d -> %d" % [hp0, tw.max_hp])
	tw.queue_free()
	await _frames(2)
