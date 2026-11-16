extends Node
## Spawn audit: every place the night puts a hostile, per region, with ground checks (SpawnRules.assess:
## water, slope, a ledge's lip, inside a collider or a prop, on a way, in a safe place) and the design
## numbers (tier, the level a pawn shows, metres from the hub, from the nearest fire and town).
##   godot --headless --path . res://zz/spawn_audit.tscn -- [--out=<dir>] [--no-map] [--tides=12] [--crops] [--crop=name:x0:z0:x1:z1]
## Lists: camps (each planted pawn and each patrol stop), the mixed members, rares (haunt and route), elites,
## guardians (and their escort ring), ambush sites (the trigger on the way, and the five spots the hollowed
## would rise on for a walker), Gloom tide hunters (sampled: --tides points per region, each wave's candidates
## through the director's own spot_ok), surge sites, roaming events, the watch posts' assaults; then the navigation
## mesh: camp centres and guardian sites on it, patrol and rare rounds walkable on it.
## Writes <out>/spawn_audit.txt (every point, then per region, then the problems) and <out>/spawn_map.png (1 px =
## 0.5 m: hillshade, water, ways, safe rings, fires; camps by tier, patrols, rares, elites, guardians, ambushes;
## a red cross on every point that breaks a rule). Exit code = the number of problems (capped 100).
const SpawnRules := preload("res://core/life/encounters/spawn_rules.gd")
const Tiers := preload("res://core/life/encounters/tiers.gd")
const RealmLand := preload("res://core/world/realm/realm_land.gd")
const AmbushSites := preload("res://core/life/encounters/ambush_sites.gd")
const PX := 0.5                                 ## metres per pixel on the map
const CAMP_APART := 15.0                        ## two camps' centres at least this far apart

var main: Node
var out_dir := "user://"
var map := true
var tide_n := 10
var space: PhysicsDirectSpaceState3D
var enc: Node
var sp: EnemySpawner
var fires: Array[Vector2] = []
var outposts: Array[Vector2] = []
var walks: Array[Vector2] = []                  ## the village's walk nodes outside the towns (outposts, travellers)
var rows: Array[Dictionary] = []                ## {kind, id, region, at, a (assess), note}
var report := PackedStringArray()
var problems := PackedStringArray()


func _ready() -> void:
	Travel._busy = true
	Travel.bosses_slain.clear()
	Travel.seals_broken.clear()
	Travel.systems.clear()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
		elif a == "--no-map":
			map = false
		elif a == "--crops":
			crops = CROPS.duplicate()
		elif a.begins_with("--crop="):
			var g := a.trim_prefix("--crop=").split(":")
			crops[g[0]] = Rect2(float(g[1]), float(g[2]), float(g[3]) - float(g[1]), float(g[4]) - float(g[2]))
		elif a.begins_with("--tides="):
			tide_n = int(a.trim_prefix("--tides="))
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	_run.call_deferred()


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 300000:
		await get_tree().process_frame
		var s := main.get_node_or_null("EnemySpawner") as EnemySpawner
		var e := main.get_node_or_null("Encounters")
		if main.has_meta("realm_done") and s != null and s.settled and e != null and bool(e.get("ready_done")) and main.get_node_or_null("Rares") != null:
			break
	for i in 10:
		await get_tree().physics_frame
	sp = main.get_node_or_null("EnemySpawner") as EnemySpawner
	enc = main.get_node_or_null("Encounters")
	if sp == null or enc == null:
		print("AUDIT FAIL the world never came up")
		get_tree().quit(1)
		return
	space = (main as Node3D).get_world_3d().direct_space_state
	enc.call("step", 0.25)                       # the guardians gather their sites
	enc.process_mode = Node.PROCESS_MODE_DISABLED
	sp.process_mode = Node.PROCESS_MODE_DISABLED
	(main.get_node("Rares") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	_gather_fires()
	_camps()
	_rares()
	_elites()
	_guardians()
	_ambushes()
	_tides()
	_surges()
	_watch()
	await _nav()
	_write()
	if map:
		_map()
	print("AUDIT done: %d points, %d problems (%s)" % [rows.size(), problems.size(), ProjectSettings.globalize_path(out_dir)])
	_finish()


## The audit's verdict (zz/spawns_test overrides this with its own checks).
func _finish() -> void:
	get_tree().quit(mini(problems.size(), 100))


# --- gathering ----------------------------------------------------------------------------------

func _gather_fires() -> void:
	for b in get_tree().get_nodes_in_group(Groups.BRAZIER):
		fires.append(Vector2((b as Node3D).global_position.x, (b as Node3D).global_position.z))
	for rid: String in RealmLayout.SLOTS:
		for s: Dictionary in RealmLayout.SLOTS[rid]:
			if String(s.kind) == "fire":
				fires.append(s.at)
	var v := main.get_node_or_null("Village")
	if v != null:
		for id: String in (v.get("outpost_at") as Dictionary):
			var f: Vector3 = (v.get("outpost_at") as Dictionary)[id]
			outposts.append(Vector2(f.x, f.z))
		var vnav: Variant = v.get("nav")
		if vnav is Object and (vnav as Object).get("nodes") is Dictionary:
			for q: Variant in ((vnav as Object).get("nodes") as Dictionary).values():
				if q is Vector3 and SpawnRules.safe_at(Vector2((q as Vector3).x, (q as Vector3).z)) == "":
					walks.append(Vector2((q as Vector3).x, (q as Vector3).z))


func _add(kind: String, id: String, at: Vector3, opts := {}, note := "") -> Dictionary:
	var a := SpawnRules.assess(space, at, opts)
	var q := Vector2(at.x, at.z)
	var fd := INF
	for f in fires:
		fd = minf(fd, f.distance_to(q))
	var od := INF
	for o in outposts:
		od = minf(od, o.distance_to(q))
	var gap: Array = SpawnRules.safe_gap(q)
	var row := {"kind": kind, "id": id, "region": Tiers.region_id(at), "at": at, "a": a, "note": note, "fire": fd, "outpost": od,
		"town": float(gap[0]), "town_id": String(gap[1]), "town_margin": float(gap[2]), "hub": q.distance_to(SpawnRules.HUB), "tier": Tiers.tier_at(at)}
	rows.append(row)
	if not bool(a.ok):
		problems.append("%-9s %-28s %-12s %s: %s" % [kind, id, row.region, _v(at), a.why])
	return row


func _v(p: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [p.x, p.y, p.z]


func _camps() -> void:
	var by := {}
	for slot: Dictionary in sp.slots():
		var ck := String(slot.key).get_slice("#", 0)
		if not by.has(ck):
			by[ck] = []
		(by[ck] as Array).append(slot)
	var n := 0
	for cp: Dictionary in EnemySpawner.REALM_CAMPS:
		n += 1
		var ck := str(cp.at)
		var q := Vector2(cp.at.x, cp.at.z)
		var id := ("camp%02d %s" % [n, String(cp.get("name", ""))]).strip_edges()
		var seal := String(cp.get("seal", ""))
		var opts := {"ways": seal == ""}
		if not by.has(ck):
			problems.append("camp      %-28s %-12s %s: NOT PLANTED" % [id, Tiers.region_id(Vector3(q.x, 0, q.y)), q])
			rows.append({"kind": "skipped", "id": id, "region": Tiers.region_id(Vector3(q.x, 0, q.y)), "at": Vector3(q.x, 0, q.y), "a": {"ok": false, "why": "not planted"},
				"note": "", "fire": INF, "outpost": INF, "town": 0.0, "town_id": "", "hub": q.distance_to(SpawnRules.HUB), "tier": 0})
			continue
		var kinds := PackedStringArray()
		for k: Variant in cp.kinds:
			kinds.append(String(k))
		var first := true
		for slot: Dictionary in by[ck]:
			var r := _add("camp" if seal == "" else "seal", id, slot.at, opts, ",".join(kinds) if first else "")
			r["camp"] = cp
			r["lead"] = first
			first = false
			# a camp centre must also keep its distances (fires, towns, ways), measured from where it was set down
			if r.lead and seal == "" and slot.has("center"):
				var c: Vector3 = slot.center
				var cq := Vector2(c.x, c.z)
				var gap: Array = SpawnRules.safe_gap(cq)
				r["town"] = float(gap[0])
				r["town_id"] = String(gap[1])
				r["town_margin"] = float(gap[2])
				var fd := INF
				for f in fires:
					fd = minf(fd, f.distance_to(cq))
				r["fire"] = fd
			if r.lead and seal == "":
				if float(r.fire) < 13.0:
					problems.append("camp      %-28s %-12s %s: %.1f m from a fire" % [id, r.region, _v(slot.at), float(r.fire)])
				if float(r.town) < float(r.town_margin):
					problems.append("camp      %-28s %-12s %s: %.1f m outside %s's ring (want %.0f)" % [id, r.region, _v(slot.at), float(r.town), r.town_id, float(r.town_margin)])
				if float(r.outpost) < 15.0:
					problems.append("camp      %-28s %-12s %s: %.1f m from a village outpost" % [id, r.region, _v(slot.at), float(r.outpost)])
				var wd := INF
				for w in walks:
					wd = minf(wd, w.distance_to(Vector2(slot.center.x, slot.center.z)))
				if wd < 10.0:
					problems.append("camp      %-28s %-12s %s: %.1f m from where people walk (a village walk node)" % [id, r.region, _v(slot.at), wd])
		var lead: Dictionary = by[ck][0]
		if lead.has("patrol"):
			var k := 0
			for g: Vector3 in lead.patrol:
				var pr := _add("patrol", "%s stop %d" % [id, k], g, opts)
				pr["camp"] = cp
				if float(pr.town) < SpawnRules.PATROL_MARGIN:
					problems.append("patrol    %-28s %-12s %s: %.1f m outside %s's ring" % [id, pr.region, _v(g), float(pr.town), pr.town_id])
				k += 1
	for slot: Dictionary in sp.slots():
		if String(slot.key).begins_with("enc_mix"):
			_add("mix", String(slot.key).get_slice("#", 0), slot.at)
	# two camps this near are one fight, not two places (seal guards stand in their files by design)
	var cs: Array = []
	for slot: Dictionary in sp.slots():
		if slot.has("center") and String(slot.key).ends_with("#0") and String(slot.get("seal", "")) == "":
			cs.append([String(slot.key).get_slice("#", 0), slot.center])
	for i in cs.size():
		for j in range(i + 1, cs.size()):
			var d := Vector2((cs[i][1] as Vector3).x - (cs[j][1] as Vector3).x, (cs[i][1] as Vector3).z - (cs[j][1] as Vector3).z).length()
			if d < CAMP_APART:
				problems.append("camp      %s and %s: %.1f m apart (one fight; want %.0f m)" % [cs[i][0], cs[j][0], d, CAMP_APART])


func _rares() -> void:
	var rr := main.get_node("Rares")
	var haunts: Dictionary = rr.get("haunts")
	var defs: Dictionary = (rr.get_script() as GDScript).get_script_constant_map().get("RARES", {})
	for id: String in defs:
		if not haunts.has(id):
			problems.append("rare      %-28s: no haunt" % id)
			continue
		_add("rare", id, haunts[id], {"ways": false, "safe": false}, String(defs[id].kind))
		if (defs[id] as Dictionary).has("route"):
			var k := 0
			for g: Vector3 in rr.call("route", id):
				if k > 0:
					_add("route", "%s stop %d" % [id, k], g, {"ways": false, "safe": false})
				k += 1


func _elites() -> void:
	var h: Dictionary = enc.get("haunts")
	for id: String in h:
		_add("elite", id, h[id], {"ways": false})


func _guardians() -> void:
	var g := enc.get("guardians") as Node
	if g == null:
		return
	g.call("refresh_sites")
	for s: Dictionary in g.get("sites"):
		_add("guardian", "%s (%s)" % [String(s.id), String(s.key)], s.at, {"ways": false}, String(s.get("from", "")))


## A walker on each ambush's way: the five spots trigger_ambush would try, through the director's spot_ok.
func _ambushes() -> void:
	for s: Dictionary in enc.get("ambushes"):
		var at: Vector3 = s.at
		var r := _add("ambush", String(s.path), at, {"ways": false})
		var used := 0
		for spot: Vector3 in AmbushSites.rise_spots(at, s.dir, Callable(enc, "_ground_at"), Callable(enc, "spot_ok")):
			used += 1
			_add("rise", "%s near %s" % [String(s.path), _v(at)], spot)
		r["note"] = "%s (%.1f): %d of %d spots usable" % [String(s.get("why", "")), float(s.get("score", 0.0)), used, AmbushSites.RISE.size()]
		if used < 2:
			problems.append("ambush    %-28s %-12s %s: only %d spots to rise on" % [String(s.path), r.region, _v(at), used])


## Tide hunters: sample walkers over every region; each takes a wave's candidates through spot_ok.
func _tides() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var by := {}
	for i in 6000:
		var q := Vector2(rng.randf_range(RealmLayout.BOUNDS.position.x + 8, RealmLayout.BOUNDS.end.x - 8), rng.randf_range(RealmLayout.BOUNDS.position.y + 8, RealmLayout.BOUNDS.end.y - 8))
		var rid := String(RealmLayout.region_at(q.x, q.y).get("id", "-"))
		if int(by.get(rid, 0)) >= tide_n:
			continue
		var g: Vector3 = enc.call("_ground_at", Vector3(q.x, 0, q.y), 90.0)
		if g == Vector3.INF or bool(enc.call("_in_haven", g)) or SpawnRules.safe_at(q) != "" or LightGrid.is_lit(g):
			continue
		by[rid] = int(by.get(rid, 0)) + 1
		var base := rng.randf() * TAU
		for k in 8:
			var a := base + rng.randf_range(-0.9, 0.9) + float(k % 2) * PI
			var d := rng.randf_range(19.0, 28.0)
			var spot: Vector3 = enc.call("_ground_at", g + Vector3(cos(a) * d, 0.0, sin(a) * d), g.y + 30.0)
			if spot == Vector3.INF or not bool(enc.call("spot_ok", spot)):
				continue
			_add("tide", "near %s" % _v(g), spot)


## Surges: each site's ring (9-15 m), the spots a wave would take (WorldEvents._spawn_wave's own test).
func _surges() -> void:
	var we := main.get_node_or_null("WorldEvents")
	if we == null:
		return
	for s: Dictionary in we.call("sites"):
		var at: Vector3 = s.at
		var got := 0
		for i in 18:
			var a := TAU * float(i) / 18.0
			var d := 9.0 + 6.0 * float(i % 3) / 2.0
			var q := at + Vector3(cos(a) * d, 0.0, sin(a) * d)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(q + Vector3.UP * 25.0, q + Vector3.DOWN * 25.0, Layers.WORLD))
			if hit.is_empty() or (hit.normal as Vector3).y < 0.75:
				continue
			var spot: Vector3 = hit.position
			if not bool(enc.call("spot_ok", spot, true)) and (i < 12 or not SpawnRules.ok(space, spot, {"ways": false})):
				continue
			got += 1
			_add("surge", String(s.id), spot, {"ways": false})
		if got < 2:
			problems.append("surge     %-28s %s: only %d spots to rise on" % [String(s.id), _v(at), got])


func _watch() -> void:
	for w in get_tree().get_nodes_in_group(&"watch_post"):
		var n := w as Node3D
		var face: Vector3 = n.get("face") if n.get("face") is Vector3 else Vector3.FORWARD
		for a: float in [-1.0, 0.0, 1.0]:
			var q := n.global_position + face.rotated(Vector3.UP, a) * 15.0
			var g: Vector3 = Callable(n, "_come_from").call(q)
			_add("watch", String(n.name), g, {"ways": false})


## The navigation mesh (RealmNav; enemies steer straight and ask it when walled): every camp's centre and every
## guardian site on it, every patrol's and every rare round's legs walkable on it, not three times round.
func _nav() -> void:
	var t0 := Time.get_ticks_msec()
	while not NavAssist.ready() and Time.get_ticks_msec() - t0 < 90000:
		await get_tree().process_frame
	# NavAssist answers for its last tile only: wait until every tile has joined the map (a probe on each of the
	# middle bands and both Reaches answers on its own spot)
	var probes: Array[Vector3] = []
	for q: Vector2 in [Vector2(4, 40), Vector2(-60, 160), Vector2(60, 300), Vector2(-200, 20), Vector2(200, 20), Vector2(-320, 60), Vector2(320, 60)]:
		probes.append(Vector3(q.x, RealmLayout.ground(space, q.x, q.y), q.y))
	var joined := false
	while not joined and Time.get_ticks_msec() - t0 < 150000:
		joined = NavAssist.ready()
		for pr in probes:
			var c := NavigationServer3D.map_get_closest_point(NavAssist.map, pr)
			joined = joined and Vector2(c.x - pr.x, c.z - pr.z).length() < 6.0
		if not joined:
			await get_tree().process_frame
	if not joined:
		problems.append("nav       the navigation mesh never joined all its tiles (150 s)")
		return
	for i in 10:
		await get_tree().physics_frame
	var legs := 0
	var centres := {}
	for slot: Dictionary in sp.slots():
		var ck := String(slot.key).get_slice("#", 0)
		if slot.has("center") and not centres.has(ck):
			centres[ck] = slot.center
			_on_mesh("camp", ck, slot.center)
		if slot.has("patrol") and String(slot.key).ends_with("#0"):
			var pts: Array = [slot.at] + Array(slot.patrol)
			for k in pts.size():
				legs += 1
				_leg("patrol", ck, pts[k], pts[(k + 1) % pts.size()])
	var g := enc.get("guardians") as Node
	if g:
		for st: Dictionary in g.get("sites"):
			_on_mesh("guardian", String(st.key), st.at)
	var rr := main.get_node("Rares")
	for id: String in (rr.get("haunts") as Dictionary):
		var route: Array = rr.call("route", id)
		for k in route.size():
			if route.size() > 1:
				legs += 1
				_leg("rare", id, route[k], route[(k + 1) % route.size()])
	report.append("nav: %d camps and guardian sites on the mesh, %d legs walked (%d ms)" % [centres.size(), legs, Time.get_ticks_msec() - t0])


func _on_mesh(kind: String, id: String, at: Vector3) -> void:
	var c := NavigationServer3D.map_get_closest_point(NavAssist.map, at)
	if Vector2(c.x - at.x, c.z - at.z).length() > 2.5 or absf(c.y - at.y) > 2.0:
		problems.append("nav       %-9s %-28s %s: off the mesh (nearest %s)" % [kind, id.left(28), _v(at), _v(c)])


func _leg(kind: String, id: String, a: Vector3, b: Vector3) -> void:
	var path := NavAssist.path(a, b)
	var straight := Vector2(a.x - b.x, a.z - b.z).length()
	if straight < 1.0:
		return
	if path.is_empty() or Vector2(path[path.size() - 1].x - b.x, path[path.size() - 1].z - b.z).length() > 3.0:
		problems.append("nav       %-9s %-28s %s -> %s: no way there" % [kind, id.left(28), _v(a), _v(b)])
		return
	var ln := 0.0
	for k in path.size() - 1:
		ln += path[k].distance_to(path[k + 1])
	if ln > straight * 3.0 + 8.0:
		problems.append("nav       %-9s %-28s %s -> %s: %.0f m round for %.0f m" % [kind, id.left(28), _v(a), _v(b), ln, straight])


# --- the report ---------------------------------------------------------------------------------

func _write() -> void:
	report.append("SPAWN AUDIT  %s" % Time.get_datetime_string_from_system())
	report.append("rules: way berth %.1f m (%.1f m within %.0f m of the hub), slope n.y >= %.2f, lip drop <= %.1f m, water <= %.2f m, camps %.0f m past a safe ring, patrols %.0f m" % [
		SpawnRules.WAY_BERTH, SpawnRules.HUB_BERTH, SpawnRules.HUB_ROADS_R, SpawnRules.MAX_SLOPE, SpawnRules.LIP_DROP, SpawnRules.WADE, SpawnRules.CAMP_MARGIN, SpawnRules.PATROL_MARGIN])
	report.append("")
	report.append("== per region (hub = Hearthward; tier = REGION_BASE; level = what a plain pawn shows at night depth 0)")
	var regs := {}
	for r: Dictionary in RealmLayout.REGIONS:
		regs[String(r.id)] = {"camps": 0, "foes": 0, "rare": 0, "elite": 0, "guardian": 0, "ambush": 0, "tide": 0, "bad": 0, "kinds": {}, "hub": INF}
	for row: Dictionary in rows:
		var rid := String(row.region)
		if not regs.has(rid):
			regs[rid] = {"camps": 0, "foes": 0, "rare": 0, "elite": 0, "guardian": 0, "ambush": 0, "tide": 0, "bad": 0, "kinds": {}, "hub": INF}
		var d: Dictionary = regs[rid]
		match String(row.kind):
			"camp", "seal", "mix":
				d.foes += 1
				if row.get("lead", false):
					d.camps += 1
					for k: Variant in row.camp.kinds:
						d.kinds[String(k).get_slice("@", 0)] = true
			"rare", "elite", "guardian", "ambush", "tide":
				d[String(row.kind)] += 1
		if not bool(row.a.ok):
			d.bad += 1
		d.hub = minf(float(d.hub), float(row.hub))
	var ids := regs.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return _reg_hub(a) < _reg_hub(b))
	report.append("%-13s %4s %5s %5s %5s %4s %4s %4s %5s %5s %4s  %s" % ["region", "tier", "lvl", "hub m", "camps", "foes", "rare", "elit", "guard", "amb", "bad", "roster"])
	for rid: String in ids:
		var d: Dictionary = regs[rid]
		var tier := Tiers.region_base(rid)
		report.append("%-13s %4d %5s %5.0f %5d %4d %4d %4d %5d %5d %4d  %s" % [rid, tier, _lvl(rid), _reg_hub(rid), d.camps, d.foes, d.rare, d.elite, d.guardian, d.ambush, d.bad, ", ".join(PackedStringArray((d.kinds as Dictionary).keys()))])
	report.append("")
	report.append("== problems (%d)" % problems.size())
	report.append_array(problems)
	report.append("")
	report.append("== every point")
	for row: Dictionary in rows:
		report.append("%-8s %-34s %-12s t%d %s hub %4.0f fire %5.1f town %5.1f%s way %5.1f ny %.2f drop %4.1f water %.2f %s %s" % [row.kind, String(row.id).left(34), row.region, int(row.tier), _v(row.at),
			float(row.hub), float(row.fire), float(row.town), (" " + String(row.town_id).left(4)) if float(row.town) < 40.0 else "     ",
			float(row.a.get("way", INF)), float(row.a.get("ny", 1.0)), float(row.a.get("drop", 0.0)), float(row.a.get("water", 0.0)),
			"OK " if bool(row.a.ok) else "BAD", String(row.a.why) + ((" | " + String(row.note)) if String(row.note) != "" else "")])
	var f := FileAccess.open(out_dir.path_join("spawn_audit.txt"), FileAccess.WRITE)
	if f:
		f.store_string("\n".join(report))
	for i in mini(report.size(), 70):
		print("AUDIT ", report[i])


func _reg_hub(rid: String) -> float:
	for r: Dictionary in RealmLayout.REGIONS:
		if String(r.id) == rid:
			var c: Vector2 = r.c if r.has("c") else (r.rect as Rect2).get_center()
			return c.distance_to(SpawnRules.HUB)
	return 9999.0


func _lvl(rid: String) -> String:
	for r: Dictionary in RealmLayout.REGIONS:
		if String(r.id) == rid:
			var c: Vector2 = r.c if r.has("c") else (r.rect as Rect2).get_center()
			return "%d" % Tiers.level_for(Tiers.region_base(rid), Vector3(c.x, 0, c.y), 1)
	return "-"


# --- the map ------------------------------------------------------------------------------------

## The whole Realm at PX m a pixel, then each --crop (or every Far Reaches region with --crops) at CROP_PX.
const CROP_PX := 0.25
const CROPS := {"greyfell": Rect2(-372, -152, 120, 110), "lanternwood": Rect2(-372, -58, 120, 132), "kingsbarrows": Rect2(-372, 60, 120, 186),
	"reedmere": Rect2(-372, 228, 160, 172), "fallow": Rect2(-228, 232, 144, 168), "arches": Rect2(-100, 232, 200, 168), "southwood": Rect2(84, 232, 186, 168),
	"bellfall": Rect2(252, -152, 120, 120), "lastlight": Rect2(252, -48, 120, 152), "nave": Rect2(252, 88, 120, 154), "cairns": Rect2(252, 226, 120, 174)}
var crops: Dictionary = {}
var _tier_grid := PackedByteArray()
var _img: Image
var _rect: Rect2
var _px_m := PX


func _map() -> void:
	_tier_grid.resize(int(RealmLayout.BOUNDS.size.x / 4.0 + 1) * int(RealmLayout.BOUNDS.size.y / 4.0 + 1))
	var gw := int(RealmLayout.BOUNDS.size.x / 4.0 + 1)
	for j in int(RealmLayout.BOUNDS.size.y / 4.0 + 1):
		for i in gw:
			var x := RealmLayout.BOUNDS.position.x + float(i) * 4.0 + 2.0
			var z := RealmLayout.BOUNDS.position.y + float(j) * 4.0 + 2.0
			_tier_grid[j * gw + i] = Tiers.base_at(Vector3(x, 0, z))
	_render(RealmLayout.BOUNDS, PX).save_png(out_dir.path_join("spawn_map.png"))
	for id: String in crops:
		_render(crops[id], CROP_PX).save_png(out_dir.path_join("spawn_%s.png" % id))


func _tier_px(x: float, z: float) -> int:
	var gw := int(RealmLayout.BOUNDS.size.x / 4.0 + 1)
	var i := clampi(int((x - RealmLayout.BOUNDS.position.x) / 4.0), 0, gw - 1)
	var j := clampi(int((z - RealmLayout.BOUNDS.position.y) / 4.0), 0, int(RealmLayout.BOUNDS.size.y / 4.0))
	return _tier_grid[j * gw + i]


func _render(rect: Rect2, px: float) -> Image:
	_rect = rect
	_px_m = px
	var w := int(rect.size.x / px)
	var h := int(rect.size.y / px)
	_img = Image.create(w, h, false, Image.FORMAT_RGB8)
	var img := _img
	var tier_tint := [Color(0.55, 0.75, 0.55), Color(0.75, 0.75, 0.45), Color(0.8, 0.55, 0.35), Color(0.75, 0.35, 0.4), Color(0.7, 0.3, 0.75)]
	for j in h:
		for i in w:
			var x := rect.position.x + (float(i) + 0.5) * px
			var z := rect.position.y + (float(j) + 0.5) * px
			var hh := RealmLand.height_at(x, z)
			var dx := RealmLand.height_at(x + 1.0, z) - RealmLand.height_at(x - 1.0, z)
			var dz := RealmLand.height_at(x, z + 1.0) - RealmLand.height_at(x, z - 1.0)
			var shade := clampf(0.62 - 0.22 * dx - 0.14 * dz + hh * 0.006, 0.18, 0.95)
			var col := Color(shade * 0.78, shade * 0.8, shade * 0.7)
			col = col.lerp(tier_tint[clampi(_tier_px(x, z), 0, 4)], 0.16)
			var grade := Vector2(dx, dz).length() * 0.5           # rise per metre
			if grade > 0.62:                                         # steeper than the spawn rules' floor: brick red
				col = col.lerp(Color(0.55, 0.18, 0.12), clampf((grade - 0.62) * 2.0 + 0.35, 0.0, 0.8))
			if px < 0.4 and absf(fposmod(hh, 2.0) - 1.0) > 0.92:   # contours every 2 m on the crops
				col = col.darkened(0.25)
			if RealmLand.in_water(x, z):
				col = Color(0.22, 0.34, 0.52).lerp(Color(0.1, 0.16, 0.3), clampf((RealmLand.water_y_at(x, z) - hh) * 0.6, 0.0, 1.0))
			if RealmLayout.path_dist(Vector2(x, z)) < 0.0:
				col = Color(0.86, 0.8, 0.62)
			img.set_pixel(i, j, col)
	for st: Dictionary in WorldLanes.sites:
		var r: Rect2 = st.rect
		if r.intersects(rect):
			if st.has("circle"):
				_ring(img, Vector2(st.circle.x, st.circle.y), float(st.circle.z), Color(0.3, 0.85, 0.95))
			else:
				_box(img, r, Color(0.3, 0.85, 0.95))
	for s: Dictionary in SpawnRules.SAFE:
		_ring(img, s.c, float(s.r), Color(0.4, 0.95, 0.6))
		_ring(img, s.c, float(s.r) + SpawnRules.CAMP_MARGIN, Color(0.3, 0.6, 0.4))
	_ring(img, SpawnRules.HUB, SpawnRules.HUB_ROADS_R, Color(0.45, 0.7, 0.55))
	for f in fires:
		_dot(img, f, 1.6, Color(1.0, 0.6, 0.15))
		_ring(img, f, 13.0, Color(0.9, 0.55, 0.2))
	for o in outposts:
		_dot(img, o, 1.2, Color(0.3, 1.0, 0.4))
		_ring(img, o, 22.0, Color(0.3, 0.8, 0.4))
	var tier_col := [Color(0.6, 1.0, 0.6), Color(1.0, 0.95, 0.4), Color(1.0, 0.6, 0.2), Color(1.0, 0.25, 0.3), Color(0.9, 0.2, 0.9)]
	var camp_no := 0
	for row: Dictionary in rows:
		var q := Vector2((row.at as Vector3).x, (row.at as Vector3).z)
		match String(row.kind):
			"camp", "seal":
				_dot(img, q, 0.6, tier_col[clampi(int(row.tier), 0, 4)])
				if row.get("lead", false):
					camp_no += 1
					_ring(img, Vector2(row.camp.at.x, row.camp.at.z), 4.5, tier_col[clampi(int(row.tier), 0, 4)])
					_digits(img, Vector2(row.camp.at.x, row.camp.at.z) + Vector2(5.0, -5.0), str(row.get("no", camp_no)), Color(1, 1, 1))
			"patrol":
				_dot(img, q, 0.5, Color(0.95, 0.95, 1.0))
			"mix":
				_dot(img, q, 0.6, Color(0.8, 0.8, 0.8))
			"rare":
				_ring(img, q, 3.0, Color(0.85, 0.92, 1.0))
				_dot(img, q, 1.0, Color(0.85, 0.92, 1.0))
			"route":
				_dot(img, q, 0.5, Color(0.7, 0.8, 0.95))
			"elite":
				_diamond(img, q, 4.0, Color(1.0, 0.8, 0.3))
			"guardian":
				_diamond(img, q, 4.0, Color(0.85, 0.4, 1.0))
			"ambush":
				_diamond(img, q, 2.5, Color(1.0, 0.2, 0.2))
			"rise":
				_dot(img, q, 0.4, Color(1.0, 0.45, 0.45))
			"tide":
				_dot(img, q, 0.35, Color(0.55, 0.4, 0.8))
			"surge":
				_dot(img, q, 0.35, Color(0.8, 0.5, 1.0))
		if not bool(row.a.ok):
			_cross(img, q, 2.0, Color(1.0, 0.0, 0.0))
	return img


func _box(img: Image, r: Rect2, c: Color) -> void:
	var a := _px(r.position)
	var b := _px(r.end)
	for x in range(int(a.x), int(b.x) + 1):
		for y: int in [int(a.y), int(b.y)]:
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, c)
	for y in range(int(a.y), int(b.y) + 1):
		for x: int in [int(a.x), int(b.x)]:
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, c)


func _px(q: Vector2) -> Vector2:
	return (q - _rect.position) / _px_m


func _dot(img: Image, q: Vector2, r_m: float, c: Color) -> void:
	var p := _px(q)
	var r := maxf(1.0, r_m / _px_m)
	for y in range(int(p.y - r), int(p.y + r) + 1):
		for x in range(int(p.x - r), int(p.x + r) + 1):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and Vector2(x, y).distance_to(p) <= r:
				img.set_pixel(x, y, c)


func _ring(img: Image, q: Vector2, r_m: float, c: Color) -> void:
	var p := _px(q)
	var r := r_m / _px_m
	var n := int(r * 7.0) + 12
	for k in n:
		var a := TAU * float(k) / float(n)
		var x := int(p.x + cos(a) * r)
		var y := int(p.y + sin(a) * r)
		if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
			img.set_pixel(x, y, c)


func _diamond(img: Image, q: Vector2, r_m: float, c: Color) -> void:
	var p := _px(q)
	var r := int(r_m / _px_m)
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			if absi(x) + absi(y) <= r and absi(x) + absi(y) >= r - 1:
				var px := int(p.x) + x
				var py := int(p.y) + y
				if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
					img.set_pixel(px, py, c)


func _cross(img: Image, q: Vector2, r_m: float, c: Color) -> void:
	var p := _px(q)
	var r := int(r_m / _px_m)
	for k in range(-r, r + 1):
		for t in [0, 1]:
			for pt: Vector2i in [Vector2i(int(p.x) + k, int(p.y) + k + t), Vector2i(int(p.x) + k, int(p.y) - k + t)]:
				if pt.x >= 0 and pt.y >= 0 and pt.x < img.get_width() and pt.y < img.get_height():
					img.set_pixel(pt.x, pt.y, c)


## 3x5 digits, 2 px a cell.
const GLYPH := ["111101101101111", "010110010010111", "111001111100111", "111001111001111", "101101111001001",
	"111100111001111", "111100111101111", "111001010010010", "111101111101111", "111101111001111"]


func _digits(img: Image, q: Vector2, s: String, c: Color) -> void:
	var p := _px(q)
	for ci in s.length():
		var g: String = GLYPH[int(s[ci])]
		for k in 15:
			if g[k] != "1":
				continue
			for yy in 2:
				for xx in 2:
					var x := int(p.x) + ci * 8 + (k % 3) * 2 + xx
					var y := int(p.y) + (k / 3) * 2 + yy
					if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
						img.set_pixel(x, y, c)
