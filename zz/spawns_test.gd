extends "res://zz/spawn_audit.gd"
## Spawn placement test (the enemies pass over the doubled Realm), on the built Realm, through the spawn audit:
##   rules     no spawn point breaks SpawnRules: every camp planted and each pawn, patrol stop, rare haunt and
##             round, elite haunt, guardian site, ambush rise spot, sampled tide hunter, surge spot and watch
##             assault on fair ground (no water, way, lip, slope, rock, town); camps 13 m+ from fires and past
##             the safe rings; ambush sites risen on from 2+ fair spots
##   reaches   every wild Far Reaches region holds 2+ camps with its own roster, a rare whose haunt is in it and a
##             guardian of its own; Lastlight's country holds no guardian; no camp inside a town's ring
##   curve     the base tier climbs outward from the hub (the mean tier of each ring of distance is above the one
##             inside it); RealmReaches' region tiers match Tiers.REGION_BASE; a plain pawn reads level 2 at the
##             hub and 20+ in the far corners; the road beyond the March Wall is not Hearthward's road
##   ambushes  25+ sites where the land suggests them, each with its reason, none on the hub's roads or by a town
## Run: SCRATCH=<dir> JOBS=1 tools/run_tests.sh spawns
const REACH_WILD := ["greyfell", "lanternwood", "kingsbarrows", "reedmere", "fallow", "arches", "southwood", "bellfall", "nave", "cairns"]
const Guardians := preload("res://core/life/encounters/guardians.gd")

var fails := 0


func _ready() -> void:
	map = false
	tide_n = 6
	out_dir = OS.get_environment("HOME") if OS.get_environment("HOME") != "" else "user://"
	super._ready()


func check(name: String, ok: bool, detail := "") -> void:
	print("SPAWNS %s %s %s" % ["PASS" if ok else "FAIL", name, detail])
	if not ok:
		fails += 1


func _finish() -> void:
	for pr in problems:
		print("SPAWNS   ", pr)
	check("no spawn point breaks the rules (%d points)" % rows.size(), problems.is_empty(), "%d problems" % problems.size())
	_reaches()
	_curve()
	_ambush_sites()
	print("SPAWNS %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(0 if fails == 0 else 1)


func _reaches() -> void:
	var camps := {}
	var kinds := {}
	for cp: Dictionary in EnemySpawner.REALM_CAMPS:
		var rid := Tiers.region_id(cp.at)
		camps[rid] = int(camps.get(rid, 0)) + 1
		if not kinds.has(rid):
			kinds[rid] = {}
		for k: Variant in cp.kinds:
			kinds[rid][String(k).get_slice("@", 0)] = true
		var q := Vector2(cp.at.x, cp.at.z)
		check("camp %s is outside every town" % q, SpawnRules.safe_at(q) == "", SpawnRules.safe_at(q))
	var rare_in := {}
	for row: Dictionary in rows:
		if String(row.kind) == "rare":
			rare_in[String(row.region)] = true
	var g := enc.get("guardians") as Node
	var own := {}
	var guard_in := {}
	for s: Dictionary in g.get("sites"):
		var rid := Tiers.region_id(s.at)
		guard_in[rid] = true
		if rid in (Guardians.GUARDIANS[s.id].regions as Array):
			own[rid] = true
	for rid: String in REACH_WILD:
		var pool: Array = Tiers.REGION_POOL.get(rid, [])
		var shared := 0
		for k: String in (kinds.get(rid, {}) as Dictionary):
			if k in pool:
				shared += 1
		check("%s holds 2+ camps" % rid, int(camps.get(rid, 0)) >= 2, "%d" % int(camps.get(rid, 0)))
		check("%s's camps field its own roster" % rid, shared >= 2, str((kinds.get(rid, {}) as Dictionary).keys()))
		check("%s has a rare of its own" % rid, rare_in.has(rid))
		check("%s has a guardian of its own" % rid, own.has(rid))
	check("no guardian in Lastlight's country", not guard_in.has("lastlight"))


func _curve() -> void:
	for r: Dictionary in RealmReaches.REGIONS:
		check("tier of %s matches the contract (%d)" % [r.id, int(r.tier)], Tiers.region_base(String(r.id)) == int(r.tier))
	# the mean base tier of each ring of distance from the hub, over the land
	var bands := [0.0, 120.0, 200.0, 280.0, 1000.0]
	var sum := [0.0, 0.0, 0.0, 0.0]
	var n := [0, 0, 0, 0]
	var x := RealmLayout.BOUNDS.position.x + 2.0
	while x < RealmLayout.BOUNDS.end.x:
		var z := RealmLayout.BOUNDS.position.y + 2.0
		while z < RealmLayout.BOUNDS.end.y:
			var d := Vector2(x, z).distance_to(SpawnRules.HUB)
			var t := Tiers.base_at(Vector3(x, 0, z))
			for b in 4:
				if d >= bands[b] and d < bands[b + 1] and SpawnRules.safe_at(Vector2(x, z)) == "":
					sum[b] += float(t)
					n[b] += 1
			z += 8.0
		x += 8.0
	var means := []
	for b in 4:
		means.append(sum[b] / float(maxi(n[b], 1)))
	print("SPAWNS   mean base tier by ring from the hub (0-120, 120-200, 200-280, 280+ m): ", means)
	for b in 3:
		check("the curve climbs outward (ring %d -> %d: %.2f -> %.2f)" % [b, b + 1, means[b], means[b + 1]], float(means[b + 1]) > float(means[b]))
	check("a plain pawn at the hub reads level 2", Tiers.level_for(0, Vector3(4, 0, 36), 1) == 2, str(Tiers.level_for(0, Vector3(4, 0, 36), 1)))
	for c: Vector2 in [Vector2(-318, -108), Vector2(318, -100), Vector2(327, 324)]:
		var lv := Tiers.level_for(Tiers.base_at(Vector3(c.x, 0, c.y)), Vector3(c.x, 0, c.y), 1)
		check("a far corner reads level 20+ (%s)" % c, lv >= 20, str(lv))
	check("the road past the March Wall is not Hearthward's road", Tiers.base_at(Vector3(-200, 0, 66)) >= 1 and Tiers.base_at(Vector3(-60, 0, 66)) == 0)


func _ambush_sites() -> void:
	var sites: Array = enc.get("ambushes")
	var whys := {}
	var bad: Array[String] = []
	for s: Dictionary in sites:
		var q := Vector2((s.at as Vector3).x, (s.at as Vector3).z)
		whys[String(s.get("why", "?"))] = int(whys.get(String(s.get("why", "?")), 0)) + 1
		if q.distance_to(SpawnRules.HUB) < SpawnRules.HUB_ROADS_R and String(s.path) != "mere_causeway":
			bad.append("%s on the hub's roads" % q)
		if SpawnRules.safe_at(q, 20.0) != "":
			bad.append("%s by %s" % [q, SpawnRules.safe_at(q, 20.0)])
		if String(s.get("why", "")) == "":
			bad.append("%s has no reason" % q)
	for b in bad:
		print("SPAWNS   ", b)
	check("25+ ambushes where the land suggests them %s" % whys, sites.size() >= 25, "%d" % sites.size())
	check("no ambush on the hub's roads or by a town, each with its reason", bad.is_empty())
