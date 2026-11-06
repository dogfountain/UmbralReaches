extends Node
## r34 enemies (docs/r34/layout.md, the doubled Realm), on the built Realm:
##   density   every new region holds camps and foes at the r33 density (camps per 10,000 m², foes per
##             1,000 m², by RealmLayout.region_at), the Rooted Holds only a few (safe-ish), each with
##             its own roster (quarry leapers and stone-bound husks, foundry cinder casters and
##             bulwarks, moor roaming gaunts, orchard burrowers and mites, necropolis pilgrims,
##             ossuants and chanters, mere spitters and drowned husks)
##   camps     every Realm camp planted (none skipped), 10 m+ inside BOUNDS, 13 m+ from every fire,
##             off the raid floors; the new ones 4 m+ off the ways; roaming packs walk their rounds
##   seals     the henge's guards stand on the way to its stair (west_way and the flight), all three
##             camps planted, seal_total matches; the summit's on the Crossing; seal_guards() lists them
##   tiers     tiers.gd REGION_BASE matches the REGIONS' suggested tier for every new region
##   kinds     a Risen Pilgrim lies in its grave and rises when you come near; a Cinder Caster's shot
##             is a "Cinder Hurl" cast; stone-bound / drowned pawns wear their look
##   rares     at least one named rare per new region, its haunt in that region and on the map
##             (map_kind "rare"); it spawns with rare_id / rare_name (the loot hooks), route rares
##             roam; killed, it pays and its marker leaves the map
##   guardians a guardian site in every new region but the Holds (group or fallback), each picking a
##             guardian of its own region; the Mere's causeway has its ambush
## Run: SCRATCH=<dir> JOBS=1 tools/run_tests.sh enemies_r34
const Variants := preload("res://core/life/encounters/variants.gd")
const Tiers := preload("res://core/life/encounters/tiers.gd")
const Guardians := preload("res://core/life/encounters/guardians.gd")

const NEW_REGIONS := ["quarry", "holds", "foundry", "moor", "orchard", "necropolis", "mere"]
const CAMPS_PER_10K := 4.2          ## r33: 21 camps over 50,600 m²
const FOES_PER_1K := 1.1            ## r33: ~55 camp foes over 50,600 m²
## what each region's roster must show (kind keys or "@variant")
const ROSTER := {
	"quarry": ["leaper", "@stonebound"], "foundry": ["cinder", "bulwark"], "moor": ["gaunt"],
	"orchard": ["burrower", "mite"], "necropolis": ["pilgrim", "ossuant", "chanter"], "mere": ["spitter", "@drowned"],
}
const R34_RARES := {"brother_chisel": "quarry", "clapper": "foundry", "hennet": "moor", "old_pippin": "orchard",
	"last_pilgrim": "necropolis", "ferryman": "mere", "old_rook": "holds"}

var main: Node
var p: Player
var fails := 0
var started := false
var space: PhysicsDirectSpaceState3D


func _ready() -> void:
	Travel._busy = true
	Travel.bosses_slain.clear()
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func check(name: String, ok: bool, detail := "") -> void:
	print("ENEMY34 %s %s %s" % ["PASS" if ok else "FAIL", name, detail])
	if not ok:
		fails += 1


func _physics_process(_d: float) -> void:
	if started:
		return
	if Engine.get_physics_frames() > 60 * 240:
		print("ENEMY34 FAIL timeout waiting for the world")
		get_tree().quit(1)
		return
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	var sp := main.get_node_or_null("EnemySpawner")
	if not main.has_meta("summit_dressed") or sp == null or not bool(sp.get("planted_done")) or main.find_child("Rares", true, false) == null:
		return
	var enc := main.find_child("Encounters", true, false)
	if enc == null or not bool(enc.get("ready_done")):
		return
	started = true
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	space = (main as Node3D).get_world_3d().direct_space_state
	var enc := main.find_child("Encounters", true, false)
	var sp := main.get_node("EnemySpawner")
	var rares := main.find_child("Rares", true, false)
	# one director step so the guardians gather their sites, then hold everything still
	enc.call("step", 0.25)
	enc.process_mode = Node.PROCESS_MODE_DISABLED
	sp.process_mode = Node.PROCESS_MODE_DISABLED
	rares.process_mode = Node.PROCESS_MODE_DISABLED
	_camps(sp)
	_density(sp)
	_seals(sp)
	_tiers()
	_guardians(enc)
	await _roamers(sp)
	await _pilgrim()
	await _cinder()
	await _rares(rares)
	print("ENEMY34 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(0 if fails == 0 else 1)


func _fires() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for b in get_tree().get_nodes_in_group(Groups.BRAZIER):
		out.append(Vector2((b as Node3D).global_position.x, (b as Node3D).global_position.z))
	for rid: String in RealmLayout.SLOTS:
		for s: Dictionary in RealmLayout.SLOTS[rid]:
			if String(s.kind) == "fire":
				out.append(s.at)
	return out


## camp key (str(at)) -> live slots planted for it
func _planted(sp: Node) -> Dictionary:
	var out := {}
	for slot: Dictionary in sp.call("slots"):
		var ck := String(slot.key).get_slice("#", 0)
		if ck.begins_with("enc"):
			continue
		if not out.has(ck):
			out[ck] = []
		(out[ck] as Array).append(slot)
	return out


func _camps(sp: Node) -> void:
	var planted := _planted(sp)
	var fires := _fires()
	var inner := RealmLayout.BOUNDS.grow(-10.0)
	var bad: Array[String] = []
	for cp: Dictionary in EnemySpawner.REALM_CAMPS:
		var at: Vector3 = cp.at
		var q := Vector2(at.x, at.z)
		var tag := "%s %s" % [q, RealmLayout.region_at(q.x, q.y).get("id", "-")]
		if not planted.has(str(at)):
			bad.append("%s not planted (skipped: see the EnemySpawner warning)" % tag)
		if not inner.has_point(q):
			bad.append("%s within 10 m of the edge" % tag)
		# 13 m+ (light 11 + margin); a strict camp on a built deck (the Crossing's head) only outside the light
		var clear := 11.05 if bool(cp.get("strict", false)) else 13.0
		for f in fires:
			if f.distance_to(q) < clear:
				bad.append("%s %.1f m from a fire at %s" % [tag, f.distance_to(q), f])
		for r: Dictionary in RealmLayout.RAIDS:
			if q.distance_to(r.c) < float(r.r) + 1.0:
				bad.append("%s on the %s raid floor" % [tag, r.id])
		var rid := String(RealmLayout.region_at(q.x, q.y).get("id", "-"))
		if (rid in NEW_REGIONS or absf(q.x) > 110.0 or q.y > 80.0) and String(cp.get("seal", "")) == "" and RealmLayout.path_dist(q) < 4.0:
			bad.append("%s %.1f m off a way" % [tag, RealmLayout.path_dist(q)])
	for b in bad:
		print("ENEMY34   ", b)
	check("every camp planted, inside the bounds, 13 m+ from fires, off raids and ways (%d camps)" % EnemySpawner.REALM_CAMPS.size(), bad.is_empty(), "%d problems" % bad.size())


func _area() -> Dictionary:
	var area := {}
	for x in range(int(RealmLayout.BOUNDS.position.x), int(RealmLayout.BOUNDS.end.x), 2):          # r37: the whole (doubled) world
		for z in range(int(RealmLayout.BOUNDS.position.y), int(RealmLayout.BOUNDS.end.y), 2):
			var id := String(RealmLayout.region_at(x + 1.0, z + 1.0).get("id", "-"))
			area[id] = int(area.get(id, 0)) + 4
	return area


func _density(sp: Node) -> void:
	var area := _area()
	var camps := {}
	var foes := {}
	var has := {}
	for slot: Dictionary in sp.call("slots"):
		var at: Vector3 = slot.at
		var rid := String(RealmLayout.region_at(at.x, at.z).get("id", "-"))
		foes[rid] = int(foes.get(rid, 0)) + 1
		if not has.has(rid):
			has[rid] = {}
		var pawn: Variant = slot.pawn
		if is_instance_valid(pawn):
			var scr := (pawn as Node).get_script() as Script
			for k: String in Tiers.KIND_PATHS:
				if scr and scr.resource_path == Tiers.KIND_PATHS[k]:
					has[rid][k] = true
			if (pawn as Node).has_meta(&"enc_variant"):
				has[rid]["@" + String((pawn as Node).get_meta(&"enc_variant"))] = true
	for cp: Dictionary in EnemySpawner.REALM_CAMPS:
		var rid := String(RealmLayout.region_at(cp.at.x, cp.at.z).get("id", "-"))
		camps[rid] = int(camps.get(rid, 0)) + 1
	for rid: String in NEW_REGIONS:
		var a := float(area.get(rid, 1))
		var c := int(camps.get(rid, 0))
		var f := int(foes.get(rid, 0))
		var want_c := a * CAMPS_PER_10K / 10000.0
		var want_f := a * FOES_PER_1K / 1000.0
		print("ENEMY34   %-10s %6d m2: %d camps (r33 density %.1f), %d foes (%.1f), roster %s" % [rid, int(a), c, want_c, f, want_f, ", ".join((has.get(rid, {}) as Dictionary).keys())])
		if rid == "holds":
			check("the Rooted Holds keep few foes (safe-ish)", c == 0 and f <= 2, "%d camps, %d foes" % [c, f])
			continue
		check("%s at the r33 camp density" % rid, c >= maxi(1, floori(want_c * 0.7)) and float(c) <= ceilf(want_c * 1.7) + 1.0, "%d camps for %.1f" % [c, want_c])
		check("%s at the r33 foe density" % rid, float(f) >= want_f * 0.7 and float(f) <= want_f * 3.2, "%d foes for %.1f" % [f, want_f])
		var miss: Array[String] = []
		for k: String in ROSTER.get(rid, []):
			if not (has.get(rid, {}) as Dictionary).has(k):
				miss.append(k)
		check("%s fields its own roster" % rid, miss.is_empty(), "missing " + ", ".join(miss))
	# the whole world: about twice r33's camps over twice the ground
	check("about 4 camps per 10,000 m² over the doubled world", EnemySpawner.REALM_CAMPS.size() >= 38, "%d camps" % EnemySpawner.REALM_CAMPS.size())


func _seg_dist(a: Vector2, b: Vector2, q: Vector2) -> float:
	var ab := b - a
	var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return q.distance_to(a + ab * t)


func _seals(sp: Node) -> void:
	var planted := _planted(sp)
	var west: Array = []
	for pth: Dictionary in RealmLayout.PATHS:
		if pth.id == "west_way":
			west = pth.pts
	# the flight: from the stair's foot to its head on the raid floor's rim (ThornHenge builds it; the
	# head is where the guard at the top stands, so use the stair site's extent)
	var foot := RealmLayout.HENGE_STAIR_FOOT
	var guards := 0
	var camps := 0
	for cp: Dictionary in EnemySpawner.REALM_CAMPS:
		if String(cp.get("seal", "")) != "henge":
			continue
		camps += 1
		var q := Vector2(cp.at.x, cp.at.z)
		var d_way := INF
		for i in west.size() - 1:
			d_way = minf(d_way, _seg_dist(west[i], west[i + 1], q))
		var d_foot := q.distance_to(foot)
		var d_rim := q.distance_to(RealmLayout.HENGE_C) - 31.0
		var on_route := d_way < 12.0 or (d_foot < 16.0 and d_rim < 12.0)
		check("henge guard camp %s stands on the way to the stair" % q, on_route, "%.1f m off west_way, %.1f m from the stair's foot, %.1f m outside the floor's rim" % [d_way, d_foot, d_rim])
		check("henge guard camp %s planted" % q, planted.has(str(cp.at)))
		guards += (planted.get(str(cp.at), []) as Array).size()
	check("the henge seal has three guard camps", camps == 3)
	check("seal_total(henge) counts every planted guard", EnemySpawner.seal_total("henge") == guards, "%d vs %d" % [EnemySpawner.seal_total("henge"), guards])
	var live := {}
	for g: Dictionary in sp.call("seal_guards"):
		live[g.seal] = int(live.get(g.seal, 0)) + 1
	check("seal_guards() lists the henge's and the summit's guards", int(live.get("henge", 0)) == guards and int(live.get("summit", 0)) >= 2, str(live))
	check("the spawner is in the enemy_spawner group", sp.is_in_group(&"enemy_spawner"))


func _tiers() -> void:
	for r: Dictionary in RealmLayout.REGIONS:
		if String(r.id) in NEW_REGIONS:
			check("tier of %s matches the layout (%d)" % [r.id, int(r.get("tier", -1))], Tiers.REGION_BASE.has(r.id) and int(Tiers.REGION_BASE[r.id]) == int(r.get("tier", -1)))
			check("%s has a mixed-pack pool" % r.id, Tiers.REGION_POOL.has(r.id))


func _guardians(enc: Node) -> void:
	var g := enc.get("guardians") as Node
	if g == null:
		check("guardians up", false)
		return
	g.call("refresh_sites")
	var by := {}
	for s: Dictionary in g.get("sites"):
		var rid := Tiers.region_id(s.at)
		if not by.has(rid):
			by[rid] = []
		(by[rid] as Array).append(String(s.id))
	print("ENEMY34   guardian sites: ", by)
	for rid: String in NEW_REGIONS:
		var ids: Array = by.get(rid, [])
		if rid == "holds":
			check("no guardian in the Rooted Holds", ids.is_empty(), str(ids))
			continue
		var own := false
		for id: String in ids:
			if rid in (Guardians.GUARDIANS[id].regions as Array):
				own = true
		check("%s has a guardian of its own" % rid, own, str(ids))
	var amb := false
	for a: Dictionary in enc.get("ambushes"):
		if String(a.path) == "mere_causeway":
			amb = true
	check("an ambush waits on the mere's causeway", amb)


## The moor's packs walk their rounds, in step, their home with them.
func _roamers(sp: Node) -> void:
	var n := 0
	var moving := 0
	var pawns: Array[Enemy] = []
	for slot: Dictionary in sp.call("slots"):
		if slot.has("patrol") and is_instance_valid(slot.pawn):
			n += 1
			pawns.append(slot.pawn as Enemy)
	check("roaming packs have their rounds", n >= 6, "%d roamers" % n)
	if pawns.is_empty():
		return
	var start: Array[Vector3] = []
	for e in pawns:
		start.append(e.global_position)
		e.wake()
	p.teleport(Vector3(0, 1, 30))                     # far off: nobody chases
	await _frames(60 * 6)
	for i in pawns.size():
		if is_instance_valid(pawns[i]) and pawns[i].global_position.distance_to(start[i]) > 2.5 and pawns[i].roam:
			moving += 1
	check("they walk (6 s later most have moved on)", moving >= int(pawns.size() * 0.6), "%d of %d" % [moving, pawns.size()])
	for e in pawns:
		if is_instance_valid(e):
			e.sleep()


func _put(at: Vector3) -> Vector3:
	return Vector3(at.x, RealmLayout.ground(space, at.x, at.z), at.z)


func _pilgrim() -> void:
	var at := _put(Vector3(-24.0, 0.0, 60.0))
	p.teleport(at + Vector3(12, 0.3, 0))
	var e := (load("res://core/enemy/pilgrim.gd") as GDScript).new() as Enemy
	main.add_child(e)
	e.global_position = at + Vector3.UP * 0.1
	e.home = e.global_position
	e.wake()
	await _frames(30)
	check("a pilgrim lies in its grave", bool(e.get("dormant")) and int(e.get("_state")) == Enemy.IDLE)
	check("it dresses as a wretch (variants)", Variants.kind_of(e) == "wretch")
	p.teleport(at + Vector3(4.5, 0.3, 0))
	await _frames(60 * 2)
	check("you come near: it rises and comes", not bool(e.get("dormant")) and int(e.get("_state")) != Enemy.IDLE, "dormant %s state %d" % [e.get("dormant"), int(e.get("_state"))])
	e.queue_free()
	var f := (load("res://core/enemy/pilgrim.gd") as GDScript).new() as Enemy
	main.add_child(f)
	f.global_position = at + Vector3(0, 0.1, 6)
	f.home = f.global_position
	f.wake()
	await _frames(5)
	f.take_hit(0.5, p)
	await _frames(90)
	check("struck in its grave it rises", not bool(f.get("dormant")))
	f.queue_free()
	p.teleport(Vector3(0, 1, 30))
	await _frames(5)


func _cinder() -> void:
	var at := _put(Vector3(-24.0, 0.0, 60.0))
	p.teleport(at + Vector3(11, 0.3, 0))
	var casts: Array[String] = []
	var on_cast := func(_e: Node, n: String, _t: float, _i: bool) -> void: casts.append(n)
	Events.enemy_cast_started.connect(on_cast)
	var e := (load("res://core/enemy/cinder_caster.gd") as GDScript).new() as Enemy
	main.add_child(e)
	e.global_position = at + Vector3.UP * 0.1
	e.home = e.global_position
	e.wake()
	for i in 60 * 6:
		await get_tree().physics_frame
		if casts.has("Cinder Hurl"):
			break
	check("a cinder caster's shot is a Cinder Hurl cast", casts.has("Cinder Hurl"), str(casts))
	check("it dresses as a spitter (variants)", Variants.kind_of(e) == "spitter")
	Events.enemy_cast_started.disconnect(on_cast)
	e.queue_free()
	# the regional looks on a husk
	for v: String in ["stonebound", "drowned"]:
		var h := (load("res://core/enemy/husk.gd") as GDScript).new() as Enemy
		var hp0 := h.max_hp
		Variants.pre(h, v)
		main.add_child(h)
		Variants.dress(h, v)
		h.global_position = at + Vector3(0, 0.1, 5)
		var parts := h.find_children("Enc_%s_*" % v, "MeshInstance3D", true, false).size()
		check("a %s husk wears its look (%d parts) and keeps its body" % [v, parts], parts >= 3 and h.max_hp > hp0 and String(h.get_meta(&"enc_variant", "")) == v)
		h.queue_free()
	p.teleport(Vector3(0, 1, 30))
	await _frames(5)


func _rares(rares: Node) -> void:
	var haunts: Dictionary = rares.get("haunts")
	for id: String in R34_RARES:
		var want := String(R34_RARES[id])
		if not haunts.has(id):
			check("rare %s found a haunt" % id, false)
			continue
		var at: Vector3 = haunts[id]
		var rid := Tiers.region_id(at)
		check("rare %s haunts %s" % [id, want], rid == want, "in " + rid)
		var m := rares.call("marker", id) as Node3D
		check("rare %s is on the map" % id, m != null and m.is_in_group(&"map_marker") and String(m.get_meta("map_kind", "")) == "rare")
		p.teleport(at + Vector3(40, 2, 0))
		var e := rares.call("spawn_rare", id) as Enemy
		await _frames(5)
		var d: Dictionary = rares.get("RARES")[id]
		var ok := e != null and String(e.get_meta(&"rare_id", "")) == id and String(e.get_meta(&"rare_name", "")) == String(d.title) and e.rank() == "rare"
		check("rare %s spawns named, with the loot hooks" % id, ok)
		if e == null:
			continue
		if d.has("route"):
			check("rare %s walks a long route" % id, e.roam and e.patrol.size() >= 4, "%d points" % e.patrol.size())
		if d.has("variant"):
			check("rare %s wears its region's look" % id, String(e.get_meta(&"enc_variant", "")) == String(d.variant))
		if e.has_method("is_risen"):
			check("rare %s is up and walking" % id, bool(e.call("is_risen")))
		var ash0 := Travel.count("grave_ash")
		e.take_hit(9999.0, null)
		await _frames(3)
		check("rare %s pays and leaves the map" % id, Travel.count("grave_ash") > ash0 and not m.is_in_group(&"map_marker"), "%d -> %d" % [ash0, Travel.count("grave_ash")])
