extends Node
## r34 flora checks on the built Realm, in memory only (Travel._busy):
##   density    every new region holds flora (undergrowth, trees, stones and props) per m2 of open
##              ground (off the sites' boxes, the ways and the outpost camps' rounds) within +-20 % of the r33 ground of its biome
##              (RealmLayout.biome_at inside the r33 bounds), measured the same way in the same build
##              (the old ground did not change); the foundry (ash) against crag, the orchard (ash)
##              against the whole r33 world: r33 had no live ash ground, the rift is lava; the Waiting
##              Field (ruin) against heath: r33's ruin (the chapel) has no open ground. Open ground,
##              so the places the other builders raise in a region (camps, POIs, tombs) do not count
##              as missing flora.
##   looks      each new region carries its own plants (LOOKS): fruit rows, cypresses, lilies...
##   clear      nothing grows on a raid floor; nothing but reeds below the water line
##   outposts   no live plant (undergrowth or tree) within 3.5 m of an outpost camp's fire (the camps
##              are built after the flora: village.gd _outposts)
##   build      the flora build stays under its budget (r33: ~1.05 s over half the ground; r34 phase 1:
##              ~2.0-2.8 s; the mesh generation of a cold cache is not counted)
##   cache      the placement the build stored (flora_cache.gd) reads back as the placement it made, and a
##              build that adopted a stored one stays under WARM_MS
## Run: SCRATCH=<dir> JOBS=1 tools/run_tests.sh flora_r34
const Flora := preload("res://core/world/realm/realm_flora.gd")

const REF := {"quarry": "b:crag", "holds": "b:heath", "foundry": "b:crag", "moor": "b:heath", "orchard": "r33", "necropolis": "b:heath", "mere": "b:fen"}
const R33 := Rect2(-110, -150, 220, 230)           ## the r33 BOUNDS
const TOL := 0.2
const MIN_OPEN := 400.0                   ## m2 of open ground below which a region's density is not judged
## signature kinds: [kind, at least] inside the region
const SIGN := {
	"quarry": [["rubble", 40], ["block", 5], ["scaffold", 2]],
	"holds": [["heather", 30]],
	# (foundry deadbush 8: the Crowns-foot link crosses the pits' south edge and keeps its brush off the track)
	"foundry": [["slag", 20], ["deadbush", 8], ["cinders", 4], ["ashdrift", 20]],
	"moor": [["windtree", 6], ["gorse", 20], ["cairn", 2], ["heather", 800]],
	"orchard": [["fruit", 40], ["ashdrift", 200], ["cinders", 5]],
	"necropolis": [["cypress", 6], ["headstone", 1], ["yew", 2], ["tallgrass", 400]],
	"mere": [["lily", 100], ["reeds", 100], ["willow", 10]],
}
# the Realm is twice the ground (520 x 390 m): ~4.2 s measured (ground rays 0.5, field 0.65, trees 0.5, undergrowth 1.4,
# nodes 1.1 s), none of it waste found; the old limit was for 310 x 325 m
const BUDGET_MS := 5000                ## without making meshes (a cold GenCache: a test's fresh HOME)
const WARM_MS := 1000                  ## a build that adopts the stored placement

var main: Node
var t := 0.0
var done := false
var fails := 0


func _ready() -> void:
	Travel._busy = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func check(what: String, ok: bool) -> void:
	print("FLORA34 ", "PASS " if ok else "FAIL ", what)
	if not ok:
		fails += 1


func _process(d: float) -> void:
	t += d
	if done:
		return
	if t > 220.0:
		print("FLORA34 FAIL timeout")
		done = true
		get_tree().quit(1)
		return
	if main == null or not main.has_meta("realm_done") or t < 2.0:
		return
	done = true
	await get_tree().physics_frame
	_check()
	print("FLORA34 %s %d" % ["DONE PASS" if fails == 0 else "DONE FAIL", fails])
	get_tree().quit(0 if fails == 0 else 1)


## The old Realm's region at x, z: the Marches' regions (whose blend reaches 18 m over the old edges) are not asked.
func _reg(x: float, z: float) -> String:
	var best := ""
	var best_s := 0.0
	for r: Dictionary in RealmLayout.REGIONS:
		if String(r.id) in RealmLayout.MARCHES_IDS:
			continue
		var sc := RealmLayout.place_score(r, x, z)
		if sc > best_s:
			best_s = sc
			best = String(r.id)
	return best if best != "" else "-"


## Open ground: not inside a site's box (grown 1 m) and 1 m+ off a way's edge.
var _camps: Array[Vector2] = []           ## outpost candidates and fires: kept bare on purpose


func _open(x: float, z: float) -> bool:
	if RealmLayout.path_dist(Vector2(x, z)) < 1.0 or not RealmLayout.OLD_BOUNDS.has_point(Vector2(x, z)) or RealmMarch.wall_dist(Vector2(x, z)) < 10.0:
		return false                  # (judged on the old Realm's ground, less the March Wall's band: its sites and keep-outs are the wall's)
	for c in _camps:
		if c.distance_to(Vector2(x, z)) < Flora.OUTPOST_CLEAR:
			return false
	return WorldLanes.site_at(Vector2(x, z), 1.0).is_empty()


var _og := PackedByteArray()
var _onx := 0


func _open_at(x: float, z: float) -> bool:
	var b := RealmLayout.BOUNDS
	var i := clampi(int((x - b.position.x) / 2.0), 0, _onx - 1)
	var j := clampi(int((z - b.position.y) / 2.0), 0, int(b.size.y / 2.0))
	var k := j * _onx + i
	return k < _og.size() and _og[k] == 1


func _check() -> void:
	var cast: Dictionary = (load(Flora.OUTPOST_CAST) as GDScript).get_script_constant_map().get("OUTPOSTS", {})
	for id: String in cast:
		for nv: Vector2 in cast[id].near:
			_camps.append(nv)
	var v := main.get_node_or_null("Village")
	if v != null and v.get("outpost_at") is Dictionary:
		for f: Vector3 in (v.get("outpost_at") as Dictionary).values():
			_camps.append(Vector2(f.x, f.z))
	var b := RealmLayout.BOUNDS
	var area := {}
	_onx = int(b.size.x / 2.0) + 1
	_og.resize(_onx * (int(b.size.y / 2.0) + 1))
	_og.fill(0)
	var x := b.position.x + 1.0
	while x < b.end.x:
		var z := b.position.y + 1.0
		while z < b.end.y:
			var op := _open(x, z)
			_og[int((z - b.position.y) / 2.0) * _onx + int((x - b.position.x) / 2.0)] = 1 if op else 0
			if op:
				var id := _reg(x, z)
				area[id] = int(area.get(id, 0)) + 4
				if R33.has_point(Vector2(x, z)):
					area["r33"] = int(area.get("r33", 0)) + 4
					var bk := "b:" + RealmLayout.biome_at(x, z)
					area[bk] = int(area.get(bk, 0)) + 4
			z += 2.0
		x += 2.0
	var count := {}
	var kinds := {}
	var on_raid := 0
	var wet := 0
	for it: Array in Flora.instance_list():
		var p: Vector3 = it[1]
		var id := _reg(p.x, p.z)
		var sp := String(it[0])
		sp = sp.substr(0, sp.rfind("_"))
		if not kinds.has(id):
			kinds[id] = {}
		kinds[id][sp] = int(kinds[id].get(sp, 0)) + 1
		if _open_at(p.x, p.z):
			count[id] = int(count.get(id, 0)) + 1
			if R33.has_point(Vector2(p.x, p.z)):
				count["r33"] = int(count.get("r33", 0)) + 1
				var bk := "b:" + RealmLayout.biome_at(p.x, p.z)
				count[bk] = int(count.get(bk, 0)) + 1
		for rd: Dictionary in RealmLayout.RAIDS:
			if Vector2(p.x, p.z).distance_to(rd.c) < float(rd.r) - 0.5 and sp != "stone":
				on_raid += 1
		if p.y < Flora.WATER_Y - 0.01 and not (sp in ["reeds", "cattail", "stone"]):
			wet += 1
	for bk: String in ["b:crag", "b:heath", "b:ruin", "b:fen", "b:oldforest", "b:meadow", "r33"]:
		print("FLORA34 reference %s %.2f /m2 of open ground (%.0f m2)" % [bk, float(count.get(bk, 0)) / float(area.get(bk, 1)), float(area.get(bk, 0))])
	for id: String in REF:
		var a := float(area.get(id, 1))
		var dn := float(count.get(id, 0)) / a
		var rid: String = REF[id]
		var ref := float(count.get(rid, 0)) / float(area.get(rid, 1))
		if a < MIN_OPEN:
			# the Rooted Holds' clearing is mostly earth-houses and an outpost camp now: what open ground
			# is left is a few verges inside the sites' keep-off bands, too little to judge a density by
			print("FLORA34 skip %s density %.2f /m2 (only %.0f m2 of open ground)" % [id, dn, a])
		else:
			check("%s density %.2f /m2 of open ground (%s %.2f, +-%d %%; %d in %.0f m2)" % [id, dn, rid, ref, int(TOL * 100), count.get(id, 0), a],
				absf(dn - ref) <= ref * TOL)
		var kd: Dictionary = kinds.get(id, {})
		var ks := kd.keys()
		ks.sort_custom(func(a, c) -> bool: return int(kd[a]) > int(kd[c]))
		var line := ""
		for k: String in ks:
			line += "%s %d  " % [k, kd[k]]
		print("FLORA34 %s kinds: %s" % [id, line])
		for s: Array in SIGN[id]:
			check("%s grows %s (%d >= %d)" % [id, s[0], int(kd.get(s[0], 0)), s[1]], int(kd.get(s[0], 0)) >= int(s[1]))
	check("nothing on the raid floors (%d)" % on_raid, on_raid == 0)
	check("nothing but reeds under the water line (%d)" % wet, wet == 0)
	var ground := 0
	for tr: Array in Flora.trees:
		var p: Vector3 = tr[0]
		if p.y < Flora.WATER_Y:
			ground += 1
	check("no tree stands in the water (%d)" % ground, ground == 0)
	_outposts()
	check("flora build %d ms (%d ms of it making meshes) <= %d ms" % [Flora.build_ms, Flora.gen_ms, BUDGET_MS], Flora.build_ms - Flora.gen_ms <= BUDGET_MS)
	_cache()


## Live flora instances (as drawn: a cleared one has a zeroed basis) within r of p, by species.
func _live_near(p: Vector3, r: float) -> Dictionary:
	var out := {}
	var host := main.get_node_or_null("RealmFlora")
	if host == null:
		return out
	for ch in host.get_children():
		var c3 := (ch as Node3D).position
		if Vector2(c3.x - p.x, c3.z - p.z).length() > r + 34.0:
			continue
		for n in ch.get_children():
			if not (n is MultiMeshInstance3D) or not (n as MultiMeshInstance3D).multimesh.has_meta("cpu_buffer"):
				continue
			var mm := (n as MultiMeshInstance3D).multimesh
			var buf: PackedFloat32Array = mm.get_meta("cpu_buffer")
			for i in mm.instance_count:
				var o := i * 16
				if buf[o] == 0.0 and buf[o + 5] == 0.0 and buf[o + 10] == 0.0:
					continue
				var q := Vector3(buf[o + 3], buf[o + 7], buf[o + 11]) + c3
				if Vector2(q.x - p.x, q.z - p.z).length() < r:
					var sp := String(n.name).trim_prefix("Flora_")
					out[sp] = int(out.get(sp, 0)) + 1
	return out


func _outposts() -> void:
	var v := main.get_node_or_null("Village")
	if v == null or v.get("outpost_at") == null:
		print("FLORA34 no village outposts (skipped)")
		return
	var at: Dictionary = v.get("outpost_at")
	for id: String in at:
		var live := _live_near(at[id], 3.5)
		check("outpost %s at %s is clear of flora %s" % [id, at[id], live], live.is_empty())
	check("outposts built (%d)" % at.size(), at.size() >= 5)


func _cache() -> void:
	print("FLORA34 this build %s the placement (%d ms; laps %s)" % ["adopted" if Flora.cached else "scattered", Flora.build_ms, Flora.laps])
	if Flora.cached:
		check("a build from the stored placement %d ms <= %d ms" % [Flora.build_ms, WARM_MS], Flora.build_ms <= WARM_MS)
	var hit: Dictionary = Flora.Cache.load_hit(Flora.last_fp)
	check("the placement cache holds this build's entry", not hit.is_empty())
	if not hit.is_empty():
		var t0 := Time.get_ticks_usec()
		var same := Flora.placement_digest(hit["items"], hit["stones"]) == Flora.built_digest()
		check("the stored placement reads back as the one placed (%d plants)" % Flora.instance_list().size(), same)
		check("the stored trees and counts read back", (hit["trees"] as Array).size() == Flora.trees.size() and (hit["placed"] as Dictionary).hash() == Flora.placed.hash())
		print("FLORA34 digest check %d ms" % [(Time.get_ticks_usec() - t0) / 1000])
