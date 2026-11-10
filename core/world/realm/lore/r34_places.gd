extends RefCounted
## r34 places (docs/r34/places.md): the written lore of the doubled Realm's new ground, at the r33
## density (the dressed regions held 9-19 inscriptions each; each new region gets its places' own
## stones from realm_pois_r34.gd plus these): graves, waystones, notices, rune stones and pages in
## the Saints' Quarry, the Rooted Holds, the Founder's Pits, the Lanternless Moor, the Cinder Orchard,
## the Waiting Field and Corvin's Mere. And the dressing that makes the places read from the ways: the
## Waiting Field's ranks of graves, the moor's guide-cairns along moor_track, the orchard's row-stones,
## Corvin's lamp-posts standing in the mere. Built by RealmLore (before the stamp and the flora, after
## RealmBosses reserved the r34 places), so every piece registers a site and keeps clear of the
## others. Texts: lore_db.gd (regions quarry, holds, foundry, moor, orchard, necropolis, mere).

const LK := preload("res://core/world/realm/lore/lore_kit.gd")


static func build(parent: Node) -> void:
	var L: RefCounted = LK.begin(parent, "R34Places", 34034)
	# --- the Saints' Quarry ----------------------------------------------------------------------
	_rune(L, "qy_mark", "r34_qy_mark", [Vector2(-112, -96), Vector2(-138, -96), Vector2(-118, -114)], 0.0)
	_grave(L, "qy_grave", "r34_qy_grave", [Vector2(-116, -90), Vector2(-134, -84), Vector2(-122, -92)], true)
	_notice(L, "qy_ban", "r34_qy_ban", [Vector2(-122, -78), Vector2(-128, -78), Vector2(-116, -79)])
	_page_stone(L, "qy_book_3", "r34_qy_book", [Vector2(-140, -104), Vector2(-136, -112), Vector2(-112, -106)])
	# --- the Rooted Holds ------------------------------------------------------------------------
	_rune(L, "rh_stone", "r34_rh_stone", [Vector2(-128, 24), Vector2(-142, 22), Vector2(-127, 6)], 0.0)
	_grave(L, "rh_grave", "r34_rh_grave", [Vector2(-145, 0), Vector2(-146, 20), Vector2(-122, 2)], false, 4)
	_rune(L, "rh_kin", "r34_rh_kin", [Vector2(-128, -8), Vector2(-138, -10), Vector2(-121, -6)], 0.0)
	_way(L, "rh_track", "r34_rh_track", "west_track", [52.0, 60.0, 44.0, 70.0])
	# --- the Founder's Pits ----------------------------------------------------------------------
	_notice(L, "fp_notice", "r34_fp_notice", [Vector2(125, -82), Vector2(118, -78), Vector2(127, -70)])
	_page_stone(L, "fp_book_2", "r34_fp_book", [Vector2(141, -84), Vector2(116, -92), Vector2(146, -90)])
	_rune(L, "fp_heap", "r34_fp_heap", [Vector2(117, -86), Vector2(144, -94), Vector2(139, -78)], 0.0)
	_grave(L, "fp_grave", "r34_fp_grave", [Vector2(113, -96), Vector2(118, -108), Vector2(148, -82)], true)
	# --- the Lanternless Moor --------------------------------------------------------------------
	_page_stone(L, "lm_lost", "r34_lm_lost", [Vector2(144, -6), Vector2(146, -38), Vector2(140, 26)])
	_rune(L, "lm_cairn", "r34_lm_cairn", [Vector2(140, -58), Vector2(146, -60), Vector2(138, -40)], 0.0)
	_way(L, "lm_way", "r34_lm_way", "moor_track", [150.0, 140.0, 160.0, 120.0])
	_grave(L, "lm_grave", "r34_lm_grave", [Vector2(146, 28), Vector2(140, 4), Vector2(148, -10)], false, 4)
	_cairns_along(L, "moor_track", 26.0, 3.2)
	# --- the Cinder Orchard ----------------------------------------------------------------------
	_rune(L, "co_row", "r34_co_row", [Vector2(-118, 112), Vector2(-124, 118), Vector2(-108, 136)], 0.0)
	_grave(L, "co_kindler", "r34_co_kindler", [Vector2(-96, 112), Vector2(-102, 140), Vector2(-92, 136)], true, 1)
	_page_stone(L, "co_child", "r34_co_child", [Vector2(-80, 112), Vector2(-90, 110), Vector2(-74, 128)])
	_gate(L, "co_gate", "r34_co_gate", "orchard_lane", 30.0)
	_row_stones(L, Rect2(-146, 94, 72, 52), 12)
	# --- the Waiting Field -----------------------------------------------------------------------
	_field_gate(L)
	_field_kerb(L)
	_notice(L, "wf_gate", "r34_wf_gate", [Vector2(-5, 104), Vector2(5, 102), Vector2(-8, 100)])
	_grave(L, "wf_ada", "r34_wf_ada", [Vector2(14, 120), Vector2(18, 124), Vector2(10, 118)], true, 2)
	_grave(L, "wf_twins", "r34_wf_twins", [Vector2(-12, 132), Vector2(-16, 128), Vector2(-10, 138)], true, 0)
	_grave(L, "wf_soldier", "r34_wf_soldier", [Vector2(22, 138), Vector2(30, 132), Vector2(16, 142)], true, 1)
	_page_stone(L, "wf_log_3", "r34_wf_log", [Vector2(-34, 132), Vector2(-30, 138), Vector2(34, 122)])
	_field(L)
	# --- Corvin's Mere ---------------------------------------------------------------------------
	_page_stone(L, "cm_log_2", "r34_cm_log", [Vector2(112, 102), Vector2(120, 98), Vector2(90, 100)])
	_lamp_post(L, "cm_post", "r34_cm_post", [Vector2(94, 116), Vector2(110, 132), Vector2(88, 124)])
	_grave(L, "cm_grave", "r34_cm_grave", [Vector2(98, 140), Vector2(128, 138), Vector2(140, 116)], false, 4)
	_notice(L, "cm_fare", "r34_cm_fare", [Vector2(98, 92), Vector2(108, 94), Vector2(96, 88)])
	for q: Vector2 in [Vector2(90, 128), Vector2(76, 104), Vector2(116, 118), Vector2(84, 134)]:
		_lamp_post(L, "", "r34_cm_lamp_%d" % int(q.x + q.y), _cands(q, 4.0))
	L.finish()
	L.note("The new ground (r34)", Vector3(0, 0, 120))


# --- carriers ----------------------------------------------------------------------------------

## The given candidates, then rings round each (so a busy spot finds the next clear ground).
static func _cands(q: Vector2, step := 3.0) -> Array:
	var out: Array = [q]
	for r: float in [step, step * 2.0, step * 3.0]:
		for i in 8:
			var a := TAU * float(i) / 8.0 + r * 0.3
			out.append(q + Vector2(cos(a), sin(a)) * r)
	return out


static func _all(cands: Array) -> Array:
	var out: Array = []
	for q: Vector2 in cands:
		if _free(q):
			out.append(q)
	for q: Vector2 in cands:
		for c: Vector2 in _cands(q).slice(1):
			if _free(c):
				out.append(c)
	return out


## Off the camps (EnemySpawner.REALM_CAMPS, the enemies pass's ground): a camp inside a site is skipped.
const CAMP_KEEP := 7.0
static func _free(q: Vector2, keep := CAMP_KEEP) -> bool:
	for c: Dictionary in EnemySpawner.REALM_CAMPS:
		var a: Vector3 = c.at
		if Vector2(a.x, a.z).distance_to(q) < keep:
			return false
	return true


## Facing yaw for a carrier at q: its face (local -z) toward the nearest way, so it reads from there.
static func _face(q: Vector2) -> float:
	var best := q + Vector2(0, -1)
	var bd := INF
	for path: Dictionary in RealmLayout.PATHS:
		var pts: Array = path.pts
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var ab := b - a
			var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			var c := a + ab * t
			if c.distance_to(q) < bd:
				bd = c.distance_to(q)
				best = c
	var d := best - q
	return atan2(-d.x, -d.y)


static func _grave(L: RefCounted, id: String, site: String, cands: Array, mound := false, style := -1) -> void:
	var at: Vector3 = L.spot_any(site, _all(cands), 1.0 if not mound else 1.3, 0.6, 0.9)
	if at == Vector3.INF:
		return
	var rng: RandomNumberGenerator = L.rng
	var yaw := 0.0                                    # graves here face the mountain (north, -z)
	var st := style if style >= 0 else rng.randi() % 3
	var fp: Vector3 = L.headstone(at, yaw, st, rng.randf_range(0.85, 1.1), Vector2(rng.randf_range(-0.08, 0.1), rng.randf_range(-0.06, 0.06)), "lore_tstone", mound)
	var n := Basis(Vector3.UP, yaw) * Vector3(0, 0, -1)
	if st != 4 and st != 1:
		L.letters(fp, n, 0.3, 3)
	L.scrap(id, fp + n * 0.6 + Vector3.DOWN * 0.3, fp)


static func _rune(L: RefCounted, id: String, site: String, cands: Array, _yaw: float) -> void:
	var at: Vector3 = L.spot_any(site, _all(cands), 0.9, 0.6, 0.9)
	if at == Vector3.INF:
		return
	var yaw := _face(Vector2(at.x, at.z))
	var fp: Vector3 = L.rune_stone(at, yaw, (L.rng as RandomNumberGenerator).randf_range(1.2, 1.6))
	L.scrap(id, fp, fp + Vector3.UP * 0.3)


static func _notice(L: RefCounted, id: String, site: String, cands: Array) -> void:
	var at: Vector3 = L.spot_any(site, _all(cands), 1.0, 0.6, 0.8)
	if at == Vector3.INF:
		return
	var k: OssKit = L.k
	var yaw := _face(Vector2(at.x, at.z))
	var b := Basis(Vector3.UP, yaw)
	for sx: float in [-0.55, 0.55]:
		k.box("lore_beam", at + b * Vector3(sx, 0.95, 0), Vector3(0.14, 1.9, 0.14), b, true, 0.7)
	k.box("lore_beam", at + b * Vector3(0, 1.45, -0.05), Vector3(1.3, 0.75, 0.06), b, true, 0.85)
	k.box("lore_beam", at + b * Vector3(0, 1.88, -0.12), Vector3(1.5, 0.1, 0.3), b, false, 0.7)
	var face := at + b * Vector3(0, 1.45, -0.09)
	L.page(face, b * Vector3(0, 0, -1), 0.1)
	L.scrap(id, face + b * Vector3(0, -0.4, -0.7), face)


static func _page_stone(L: RefCounted, id: String, site: String, cands: Array) -> void:
	var at: Vector3 = L.spot_any(site, _all(cands), 0.9, 0.6, 0.8)
	if at == Vector3.INF:
		return
	var k: OssKit = L.k
	var rng: RandomNumberGenerator = L.rng
	var yaw := rng.randf() * TAU
	var b := Basis(Vector3.UP, yaw)
	k.box("lore_moss", at + Vector3.UP * 0.18, Vector3(1.0, 0.6, 0.8), b * Basis(Vector3.BACK, 0.06), true, 0.8)
	var top := at + Vector3.UP * 0.5
	L.page(top, Vector3.UP)
	L.cairn(L.p, at + b * Vector3(0.7, 0, 0.3), 0.3)
	L.scrap(id, top + Vector3.UP * 0.2, top)


static func _way(L: RefCounted, id: String, site: String, path: String, arcs: Array) -> void:
	var cands: Array = []
	for s: float in arcs:
		for side: float in [1.0, -1.0]:
			cands.append(LK.beside_path(path, s, side, 3.2))
	var at: Vector3 = L.spot_any(site, cands, 0.8, 0.5, 0.8)
	if at == Vector3.INF:
		return
	var yaw := _face(Vector2(at.x, at.z))
	var fp: Vector3 = L.waystone(at, yaw)
	L.scrap(id, fp, fp + Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.25))


## The orchard gate: two posts beside the lane, no gate between them.
static func _gate(L: RefCounted, id: String, site: String, path: String, s: float) -> void:
	var k: OssKit = L.k
	var a := LK.along(LK.path_pts(path), s)
	var c: Vector2 = a[0]
	var t: Vector2 = a[1]
	var nrm := Vector2(-t.y, t.x)
	var yaw := atan2(t.x, t.y)
	var placed := 0
	var last := Vector3.INF
	for side: float in [1.0, -1.0]:
		var q := c + nrm * side * 2.6
		if not _free(q):
			continue
		var at: Vector3 = L.gv(q.x, q.y)
		if not L.spot("%s_%d" % [site, int(side)], at, 0.6, 0.3):
			continue
		var b := Basis(Vector3.UP, yaw)
		k.box("lore_tstone", at + Vector3.UP * 0.9, Vector3(0.6, 2.2, 0.6), b, true, 0.86)
		k.box("lore_tstone", at + Vector3.UP * 2.1, Vector3(0.75, 0.2, 0.75), b, false, 0.9)
		k.box("lore_char", at + b * Vector3(0, 1.3, 0), Vector3(0.64, 0.5, 0.64), b, false, 0.55)
		last = at
		placed += 1
	if last != Vector3.INF:
		var face := last + Vector3.UP * 1.3
		var out := Vector3(c.x - last.x, 0, c.y - last.z).normalized()
		L.scrap(id, face + out * 0.9, face)


## The Waiting Field's gate: two tomb-stone posts across necropolis_way where the paving begins, a low
## dry-stone boundary running out from each (broken, the way the field's own walls are), and a lit
## grave-lamp on the road side of each wall. Without them the paved apron read as an empty yard.
static func _field_gate(L: RefCounted) -> void:
	var k: OssKit = L.k
	var a := LK.along(LK.path_pts("necropolis_way"), 44.0)
	var c: Vector2 = a[0]
	var t: Vector2 = a[1]
	var nrm := Vector2(-t.y, t.x)
	var yaw := atan2(t.x, t.y)
	var b := Basis(Vector3.UP, yaw)
	for side: float in [1.0, -1.0]:
		var q := c + nrm * side * 2.9
		var at: Vector3 = L.gv(q.x, q.y)
		if not L.spot("r34_wf_post_%d" % int(side), at, 0.6, 0.3):
			continue
		k.box("lore_tstone", at + Vector3.UP * 1.05, Vector3(0.62, 2.4, 0.62), b, true, 0.86)
		k.box("lore_tstone", at + Vector3.UP * 2.3, Vector3(0.8, 0.2, 0.8), b, false, 0.9)
		k.box("lore_char", at + Vector3.UP * 1.4, Vector3(0.66, 0.45, 0.66), b, false, 0.55)
		# the boundary: out from the post, away from the way
		var w0 := c + nrm * side * 3.6
		var w1 := c + nrm * side * 12.0
		var span := Rect2(minf(w0.x, w1.x), minf(w0.y, w1.y), absf(w1.x - w0.x), absf(w1.y - w0.y)).grow(0.5)
		var wlen := 12.0
		while wlen > 6.0 and not LK.clear_of(span, 0.5, ["r34_wf_post_%d" % int(side)]):
			wlen -= 1.5
			w1 = c + nrm * side * wlen
			span = Rect2(minf(w0.x, w1.x), minf(w0.y, w1.y), absf(w1.x - w0.x), absf(w1.y - w0.y)).grow(0.5)
		if LK.clear_of(span, 0.5, ["r34_wf_post_%d" % int(side)]):
			L.site("r34_wf_wall_%d" % int(side), span, minf(L.g(w0.x, w0.y), L.g(w1.x, w1.y)))
			L.drystone(L.gv(w0.x, w0.y), L.gv(w1.x, w1.y), 0.85, 0.45, "lore_tstone")
		else:
			print("REALM_LORE r34 skip field gate wall %d (%s) at %s" % [int(side), LK.blocker(span, 0.5), str(c)])
		# a lit grave-lamp on the road side, off the wall's line
		var lq := c + nrm * side * 4.6 - t * 1.6
		var lat: Vector3 = L.gv(lq.x, lq.y)
		if L.spot("r34_wf_lamp_%d" % int(side), lat, 0.5, 0.3):
			var lc: Vector3 = L.lamp_post(lat, yaw, true)
			L.light("r34_wf_lamp_light_%d" % int(side), lc + Vector3.UP * 0.1, Color(1.0, 0.62, 0.34), 0.9, 6.5)


## Worn kerb stones along necropolis_way across the paved apron: low, set a little off the way's edge,
## sunk and tilted, so the paving reads as laid for processions and not as a bare yard.
static func _field_kerb(L: RefCounted) -> void:
	var k: OssKit = L.k
	var rng: RandomNumberGenerator = L.rng
	var pts: Array = LK.path_pts("necropolis_way")
	var s := 30.0
	while s < 60.0:
		var a := LK.along(pts, s)
		var c: Vector2 = a[0]
		var t: Vector2 = a[1]
		var nrm := Vector2(-t.y, t.x)
		for side: float in [1.0, -1.0]:
			var q := c + nrm * side * 2.75
			var at: Vector3 = L.gv(q.x, q.y)
			var b := Basis(Vector3.UP, atan2(t.x, t.y) + rng.randf_range(-0.06, 0.06)) * Basis(Vector3.BACK, rng.randf_range(-0.05, 0.05))
			k.box("lore_tstone", at + Vector3.UP * 0.08, Vector3(0.38, 0.3, 0.95), b, false, rng.randf_range(0.7, 0.95))
		s += 1.9
	# the paving's own boundary is the kerb: nothing is registered, the stones stand off the way's edge


## A lamp-post standing knee-deep in the mere: an iron hook on a post, a rag on the hook.
static func _lamp_post(L: RefCounted, id: String, site: String, cands: Array) -> void:
	var at: Vector3 = L.spot_any(site, _all(cands), 0.5, 0.4, 1.4)
	if at == Vector3.INF:
		return
	var k: OssKit = L.k
	var rng: RandomNumberGenerator = L.rng
	var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, rng.randf_range(-0.08, 0.08))
	var foot := at + Vector3.DOWN * 0.6
	k.box("lore_beam", foot + b * Vector3(0, 1.6, 0), Vector3(0.18, 3.2, 0.18), b, true, 0.62)
	k.box("iron", foot + b * Vector3(0.28, 3.05, 0), Vector3(0.5, 0.05, 0.05), b, false, 0.8)
	k.box("iron", foot + b * Vector3(0.5, 2.88, 0), Vector3(0.04, 0.3, 0.04), b, false, 0.8)
	L.p.box("lore_cloth", foot + b * Vector3(0.5, 2.62, 0), Vector3(0.08, 0.3, 0.05), b, false, 0.8)
	if id != "":
		var face := foot + b * Vector3(0, 1.9, 0)
		L.scrap(id, Vector3(face.x, maxf(at.y, -0.9) + 1.0, face.z) + b * Vector3(0, 0, -0.7), face)


## The guide-cairns: a waist-high cairn beside moor_track every `step` metres (the faithful counted
## them in the dark), on alternate sides.
static func _cairns_along(L: RefCounted, path: String, step: float, off: float) -> void:
	var pts := LK.path_pts(path)
	var total := 0.0
	for i in pts.size() - 1:
		total += (pts[i] as Vector2).distance_to(pts[i + 1])
	var s := 20.0
	var side := 1.0
	var n := 0
	while s < total - 10.0:
		var q := LK.beside_path(path, s, side, off)
		var at: Vector3 = L.gv(q.x, q.y)
		if _free(q) and L.spot("r34_guide_cairn_%d" % n, at, 0.6, 0.3):
			L.cairn(L.k, at, 0.9)
			LK.col_box(L.k, at + Vector3.UP * 0.4, Vector3(0.7, 0.8, 0.7), Basis.IDENTITY)
		s += step
		side = -side
		n += 1


## The orchard's row-stones: a short squared stone at the head of each burned row.
static func _row_stones(L: RefCounted, r: Rect2, n: int) -> void:
	var rng: RandomNumberGenerator = L.rng
	var k: OssKit = L.k
	for i in n:
		var q := Vector2(r.position.x + r.size.x * (float(i % 4) + 0.5) / 4.0 + rng.randf_range(-4.0, 4.0), r.position.y + r.size.y * (float(i / 4) + 0.5) / 3.0 + rng.randf_range(-4.0, 4.0))
		var at: Vector3 = L.gv(q.x, q.y)
		if not _free(q) or not L.spot("r34_row_%d" % i, at, 0.5, 0.4):
			continue
		var b := Basis(Vector3.UP, rng.randf_range(-0.2, 0.2))
		k.box("lore_tstone", at + Vector3.UP * 0.3, Vector3(0.4, 0.9, 0.3), b * Basis(Vector3.RIGHT, rng.randf_range(-0.1, 0.1)), true, 0.88)


## The Waiting Field's graves: blocks of ranks, every stone facing the mountain (north), a little
## crooked, a few turned round to face the road home.
static func _field(L: RefCounted) -> void:
	var rng: RandomNumberGenerator = L.rng
	var blocks := [Rect2(8, 114, 12, 7), Rect2(-22, 126, 12, 7), Rect2(12, 126, 12, 7), Rect2(-40, 106, 10, 7), Rect2(26, 102, 12, 6), Rect2(-8, 138, 6, 5), Rect2(28, 142, 9, 6), Rect2(-36, 136, 8, 6), Rect2(-18, 104, 10, 6),
		Rect2(4, 100, 8, 6), Rect2(14, 136, 10, 6), Rect2(-24, 140, 8, 6), Rect2(32, 120, 8, 8), Rect2(-42, 118, 6, 8), Rect2(16, 148, 10, 5)]
	var bi := 0
	for r: Rect2 in blocks:
		bi += 1
		var name := "r34_field_%d" % bi
		if not _free_rect(r) or not LK.clear_of(r, 0.8):
			r = Rect2(r.position + Vector2(3, -3), r.size)
			if not _free_rect(r) or not LK.clear_of(r, 0.8):
				print("REALM_LORE r34 skip field block %d (%s)" % [bi, LK.blocker(r, 0.8)])
				continue
		var gr: Vector2 = L.g_range(r)
		if gr.y - gr.x > 2.5 or gr.x < -0.6:
			continue
		L.site(name, r, gr.x)
		var x := r.position.x + 1.0
		while x < r.end.x - 0.6:
			var z := r.position.y + 1.2
			while z < r.end.y - 0.4:
				if rng.randf() < 0.85:
					var at: Vector3 = L.gv(x + rng.randf_range(-0.2, 0.2), z + rng.randf_range(-0.2, 0.2))
					var yaw := 0.0 if rng.randf() > 0.08 else PI
					L.headstone(at, yaw + rng.randf_range(-0.08, 0.08), rng.randi() % 4, rng.randf_range(0.7, 1.05), Vector2(rng.randf_range(-0.1, 0.12), rng.randf_range(-0.08, 0.08)), "lore_tstone", rng.randf() < 0.3)
				z += 2.4
			x += 1.6


static func _free_rect(r: Rect2) -> bool:
	for c: Dictionary in EnemySpawner.REALM_CAMPS:
		var a: Vector3 = c.at
		if r.grow(CAMP_KEEP).has_point(Vector2(a.x, a.z)):
			return false
	return true
