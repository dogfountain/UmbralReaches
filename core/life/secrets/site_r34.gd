extends RefCounted
## r34 places (docs/r34/places.md): three hidden things in the doubled Realm's new ground, in the
## r23/r28 manner (a climb-only nook, a puzzle, a lever and a door), each beside a place the player
## already has a reason to visit (realm_pois_r34.gd), so the discovery is "there was more here":
##   cutters_nook   THE CUTTERS' NOOK (Saints' Quarry): a shelter on a bench above the Unfinished
##                  Stair's crane deck. The benches are cut 3 m high (no grab reaches): only the Tether
##                  from the deck (or a long glide) gets you up. The cutters' strongbox and a page.
##   ninth_rank     THE NINTH RANK (Waiting Field): three graves behind the Pilgrims' Ranks, each with
##                  a grave-lamp. The warden's slate says in what order they are to be lit; lit right,
##                  the end tomb's lid slides off its cache. A wrong lamp puts them all out.
##   corvin_sluice  CORVIN'S SLUICE (Corvin's Mere): a lever in the boat-house raises a sunk stone walk
##                  from the jetty's end up onto a high islet where Corvin kept his last lamp.
## State: secrets' own (State: open.sluice, solved.ninth, looted.*, found.*). Texts: pages.gd.

const Kit := preload("res://core/life/secrets/kit.gd")
const State := preload("res://core/life/secrets/state.gd")
const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const WATER := -0.9

## The Ninth Rank: the graves in the row (left to right), and the order the slate gives (indices).
const RANK := ["Old Tam the carter", "a child, no name", "Ilse of the West Gate"]
const RANK_ORDER := [2, 0, 1]               ## who walked furthest, who waited longest, the child

static var _lit: Array[int] = []


static func release() -> void:
	_lit.clear()


static func build(root: Node, host: Node3D) -> void:
	# a fresh build is a cold one: puzzle progress that is not the save does not outlive its night
	_lit.clear()
	var pois := root.get_node_or_null("RealmPois")
	if pois == null:
		print("SECRETS r34: no places built")
		return
	_nook(root, host, pois.get_node_or_null("Poi_quarry_crane") as Node3D)
	_ninth(root, host, pois.get_node_or_null("Poi_necro_ranks") as Node3D)
	_sluice(root, host, pois.get_node_or_null("Poi_mere_landing") as Node3D)


static func _bx(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _camp_near(q: Vector2, r: float) -> bool:
	for c: Dictionary in EnemySpawner.REALM_CAMPS:
		var a: Vector3 = c.at
		if Vector2(a.x, a.z).distance_to(q) < r:
			return true
	return false


# --- the Cutters' Nook -------------------------------------------------------------------------

static func _nook(root: Node, host: Node3D, crane: Node3D) -> void:
	if crane == null or not crane.has_meta("route"):
		print("SECRETS cutters' nook: no crane")
		return
	var sp := Kit.space(root)
	var route: Array = crane.get_meta("route")
	var deck: Vector3 = route[route.size() - 1]
	# a free-standing stack of offcuts on the pit floor, 8-14 m off the deck, nothing higher within
	# 4.5 m of it (no bench to jump across from): too tall to jump and grab, so only the Tether
	# from the deck, or a glide off it, reaches the top
	var floor_y := deck.y - 8.1
	var best := Vector3.INF
	var best_d := INF
	var out_dir := Vector2.ZERO
	for i in 36:
		var a := TAU * float(i) / 36.0
		var f := Vector2(cos(a), sin(a))
		var r := 8.0
		while r <= 14.0:
			var q := Vector2(deck.x, deck.z) + f * r
			var y := Kit.gy(sp, q.x, q.y)
			var ok := absf(y - floor_y) < 0.8 and WorldLanes.site_at(q, 3.0).is_empty() and not _camp_near(q, 9.0) and RealmLayout.path_dist(q) > 10.0
			if ok:
				for j in 12:
					var aa := TAU * float(j) / 12.0
					for rr: float in [2.5, 4.5]:
						if Kit.gy(sp, q.x + cos(aa) * rr, q.y + sin(aa) * rr) > y + 1.5:
							ok = false
			if ok and r < best_d:
				best_d = r
				best = Vector3(q.x, y, q.y)
				out_dir = f
			r += 1.0
	if best == Vector3.INF:
		print("SECRETS cutters' nook: no clear pit floor by the crane")
		return
	var top_h := 6.6
	var node := Node3D.new()
	node.name = "CuttersNook"
	node.set_meta("site", "secrets_nook")
	host.add_child(node)
	var to_deck := Vector3(-out_dir.x, 0, -out_dir.y)
	var b := Basis(Vector3.UP, atan2(to_deck.x, to_deck.z))     # local +z faces the crane
	var k := OssKit.new()
	k.keep_lanes = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 34101
	# the stack: four courses of squared offcuts, each a little askew, sheer on every side
	for i in 4:
		var y0 := float(i) * top_h / 4.0
		var hh := top_h / 4.0 + (0.6 if i == 0 else 0.0)
		k.box("stone", best + b * Vector3(rng.randf_range(-0.12, 0.12), y0 + hh * 0.5 - (0.6 if i == 0 else 0.0), rng.randf_range(-0.12, 0.12)), Vector3(3.4, hh, 3.4), b * Basis(Vector3.UP, rng.randf_range(-0.06, 0.06)), true, rng.randf_range(0.8, 0.9))
	var top := best + Vector3.UP * top_h
	var c := top + b * Vector3(0, 0, -0.5)
	# the cutters' lean-to on top: a back wall of slabs, a slab roof on two posts, chisels, a bench
	k.box("stone", c + b * Vector3(0, 0.75, -0.95), Vector3(3.0, 1.5, 0.3), b, true, 0.82)
	for sx: float in [-1.3, 1.3]:
		k.box("wood", c + b * Vector3(sx, 0.85, 0.6), Vector3(0.14, 1.7, 0.14), b, true, 0.7)
	k.box("slate", c + b * Vector3(0, 1.75, -0.15), Vector3(3.1, 0.14, 2.0), b * Basis(Vector3.RIGHT, -0.12), false, 0.85)
	k.box("wood", c + b * Vector3(-0.6, 0.22, -0.45), Vector3(1.3, 0.44, 0.5), b, true, 0.7)
	for i in 3:
		k.box("iron", c + b * Vector3(0.5 + 0.12 * float(i), 0.04, 0.2), Vector3(0.05, 0.05, 0.6), b * Basis(Vector3.UP, 0.2 * float(i)), false, 0.8)
	# a hoist rope hangs from the lean-to down the stack's face, cut short of the ground
	k.box("iron", best + b * Vector3(1.0, top_h - 1.6, 1.72), Vector3(0.04, 3.2, 0.04), b, false, 0.7)
	k.commit(node, "NookBody")
	best = top
	var lip := best + b * Vector3(0, 0.9, 1.55)
	var anchor: Node3D = (load("res://core/player/grapple_anchor.gd") as GDScript).new() if ResourceLoader.exists("res://core/player/grapple_anchor.gd") else Node3D.new()
	anchor.name = "GrappleAnchor"
	anchor.set_meta("reach", 18.0)
	anchor.set_meta("stand", best + b * Vector3(0, 0, 0.5))
	anchor.set_meta("land", best + b * Vector3(0, 0.1, 0.5) - lip)
	node.add_child(anchor)
	anchor.global_position = lip
	anchor.add_to_group("grapple_anchor")
	var box := Kit.mi(node, _bx(Vector3(0.7, 0.42, 0.45)), OssKit.mat("wood"), Transform3D(b, c + b * Vector3(0.7, 0.21, -0.55)), 60.0)
	State.cache(node, "cutters_nook", c + b * Vector3(0.7, 0.5, -0.1), "the cutters' strongbox", func(_a: bool) -> void: box.scale = Vector3(1, 0.4, 1))
	State.reading(node, "sc_nook", c + b * Vector3(-0.6, 0.6, 0.2))
	Kit.site(root, "secrets_nook", Rect2(best.x - 2.2, best.z - 2.2, 4.4, 4.4), best.y - top_h)
	State.register({"id": "cutters_nook", "name": "The Cutters' Nook", "at": best, "r": 1.6, "node": node,
		"deck": deck, "anchor": lip, "stand": best + b * Vector3(0, 0, 0.5), "climb_only": true, "foot": best - Vector3.UP * top_h,
		"sync": func(_animate: bool) -> void: box.scale = Vector3(1, 0.4, 1) if State.has("looted", "cutters_nook") else Vector3.ONE})
	print("SECRETS cutters' nook at %s (%.1f m off the deck, %.1f m up)" % [best.snapped(Vector3.ONE * 0.1), best_d, best.y - deck.y])


# --- the Ninth Rank ----------------------------------------------------------------------------

static func _ninth(root: Node, host: Node3D, ranks: Node3D) -> void:
	if ranks == null:
		print("SECRETS ninth rank: no ranks")
		return
	var sp := Kit.space(root)
	var c0: Vector3 = ranks.get_meta("centre")
	var R34 := load("res://core/world/realm/realm_pois_r34.gd") as GDScript
	var spot: Dictionary = (R34.get("spots") as Dictionary).get("necro_ranks", {})
	var yaw := float(spot.get("yaw", 0.0))
	var b := Basis(Vector3.UP, yaw)
	var want := Vector2(c0.x, c0.z) + Vector2((b * Vector3(0, 0, -11.0)).x, (b * Vector3(0, 0, -11.0)).z)
	var ok := func(q: Vector2) -> bool: return not _camp_near(q, 8.0) and Kit.gy(sp, q.x, q.y) > WATER + 0.3
	var q := LK.search_spot(sp, want, 26.0, Vector2(4.5, 3.0), 1.0, 1.8, [], 2.0, ok)
	if q == Vector2.INF:
		print("SECRETS ninth rank: no clear ground")
		return
	var node := Node3D.new()
	node.name = "NinthRank"
	node.set_meta("site", "secrets_ninth")
	host.add_child(node)
	var gy := Kit.low(sp, q, 3.0)
	var c := Vector3(q.x, gy, q.y)
	Kit.site(root, "secrets_ninth", Rect2(q.x - 4.5, q.y - 3.0, 9.0, 6.0), gy)
	LK.ensure_mats()
	var k := OssKit.new()
	k.keep_lanes = false
	var lamps: Array[MeshInstance3D] = []
	var flame_m := Kit.shader_mat("glint")
	for i in 3:
		var gp := c + b * Vector3(-2.4 + 2.4 * float(i), 0, 0)
		gp.y = Kit.gy(sp, gp.x, gp.z)
		k.box("lore_tstone", gp + b * Vector3(0, 0.55, 0), Vector3(0.7, 1.4, 0.2), b, true, 0.86)
		LK.half_disc(k, "lore_tstone", Transform3D(b, gp + b * Vector3(0, 1.25, 0)), 0.35, 0.0, 0.2, 6, false, 0.9)
		k.box("lore_earth", gp + b * Vector3(0, 0.05, 0.9), Vector3(0.9, 0.14, 1.6), b, false, 0.7)
		# the grave-lamp: an iron cage on a short post at the stone's foot
		var lp := gp + b * Vector3(0.0, 0.0, 0.45)
		k.box("iron", lp + Vector3.UP * 0.3, Vector3(0.06, 0.6, 0.06), b, true, 0.8)
		k.box("iron", lp + Vector3.UP * 0.68, Vector3(0.22, 0.22, 0.22), b, false, 0.7)
		var fl := Kit.mi(node, QuadMesh.new(), flame_m, Transform3D(Basis.IDENTITY, lp + Vector3.UP * 0.7), 50.0, false)
		(fl.mesh as QuadMesh).size = Vector2(0.4, 0.4)
		fl.set_instance_shader_parameter(&"tint", Color(1.0, 0.65, 0.3))
		fl.visible = false
		lamps.append(fl)
		var idx := i
		var t := Kit.touch(node, lp + Vector3.UP * 0.7 + b * Vector3(0, 0, 0.5), "", func(_by: Node) -> void: light(idx, lamps, lp), 2.0)
		t.name = "Lamp_%d" % i
		var label := "Light the lamp on the child's grave" if idx == 1 else "Light the lamp on %s's grave" % RANK[idx]
		t.set("prompt_fn", func() -> String: return "" if State.has("solved", "ninth") else label)
	# the tomb at the row's end: a chest-tomb whose lid slides off when the lamps are lit right
	var tc := c + b * Vector3(4.3, 0, 0.6)
	tc.y = Kit.gy(sp, tc.x, tc.z)
	k.box("lore_tstone", tc + b * Vector3(0, 0.4, 0), Vector3(1.0, 0.8, 1.9), b, true, 0.84)
	k.box("dark", tc + b * Vector3(0, 0.81, 0), Vector3(0.7, 0.02, 1.5), b, false, 0.25)
	k.commit(node, "RankBody")
	var lid := Kit.mi(node, _bx(Vector3(1.15, 0.18, 2.05)), OssKit.mat("lore_tstone"), Transform3D(b, tc + Vector3.UP * 0.9), 70.0)
	var lid_body := Kit.box_body(node, tc + Vector3.UP * 0.9, Vector3(1.15, 0.18, 2.05), b)
	State.cache(node, "ninth_rank", tc + Vector3.UP * 1.1, "what the ninth rank kept", Callable(), func() -> bool: return State.has("solved", "ninth"))
	State.reading(node, "sc_rank_slate", c + b * Vector3(-4.2, 0.9, 0.8))
	k = OssKit.new()
	k.keep_lanes = false
	var sl := c + b * Vector3(-4.2, 0, 0.2)
	sl.y = Kit.gy(sp, sl.x, sl.z)
	k.box("wood", sl + Vector3.UP * 0.5, Vector3(0.12, 1.0, 0.12), b, true, 0.7)
	k.box("slate", sl + Vector3.UP * 1.0 + b * Vector3(0, 0, 0.08), Vector3(0.5, 0.36, 0.04), b, false, 0.9)
	k.commit(node, "SlateBody")
	var sync := func(animate: bool) -> void:
		var done := State.has("solved", "ninth")
		for m in lamps:
			if is_instance_valid(m):
				m.visible = done or (lamps.find(m) in _lit)
		Kit.set_body(lid_body, not done)
		var to := Transform3D(b * Basis(Vector3.FORWARD, 0.3), tc + b * Vector3(1.0, 0.45, 0.2))
		if done and animate:
			Kit.play("grind", tc, -4.0, 1.2)
			lid.create_tween().tween_property(lid, "global_transform", to, 1.4).set_trans(Tween.TRANS_SINE)
		elif done:
			lid.global_transform = to
	State.register({"id": "ninth_rank", "name": "The Ninth Rank", "at": c, "r": 6.0, "node": node, "sync": sync,
		"lamps": lamps, "order": RANK_ORDER, "tomb": tc, "lid": lid_body,
		"route": {"from": Vector3(c.x, 0, c.z) + b * Vector3(0, 0, 8.0), "pts": [c + b * Vector3(0, 0, 2.2)] as Array[Vector3]},
		"goal": c + b * Vector3(0, 0, 2.2)})
	sync.call(false)


## Light grave-lamp `idx`; in the slate's order the tomb opens, out of it they all go dark.
static func light(idx: int, lamps: Array[MeshInstance3D], at: Vector3) -> void:
	if State.has("solved", "ninth") or idx in _lit:
		return
	var want: int = RANK_ORDER[_lit.size()]
	if idx != want:
		_lit.clear()
		for m in lamps:
			if is_instance_valid(m):
				m.visible = false
		Kit.play("thud", at, -4.0)
		State.toast("The lamps gutter and go out together. The field is very quiet.")
		return
	_lit.append(idx)
	if idx < lamps.size() and is_instance_valid(lamps[idx]):
		lamps[idx].visible = true
	Kit.play("chime", at, -8.0, 0.8 + 0.15 * float(_lit.size()))
	if _lit.size() < RANK_ORDER.size():
		return
	_lit.clear()
	State.mark("solved", "ninth")
	State.toast("The three lamps burn steady. At the row's end, stone grinds on stone.")
	State.banner("the ninth rank is lit", "The Ninth Rank")
	State.refresh(true)


# --- Corvin's Sluice ---------------------------------------------------------------------------

static func _sluice(root: Node, host: Node3D, landing: Node3D) -> void:
	if landing == null or not landing.has_meta("lever_at"):
		print("SECRETS corvin's sluice: no landing")
		return
	var sp := Kit.space(root)
	var R34 := load("res://core/world/realm/realm_pois_r34.gd") as GDScript
	var jetty: Array = (R34.get("causeways") as Dictionary).get("mere_landing", [])
	if jetty.size() < 2:
		print("SECRETS corvin's sluice: no jetty")
		return
	var j0: Vector2 = jetty[0]
	var j1: Vector2 = jetty[1]
	var fwd := (j1 - j0).normalized()
	# the islet: off the jetty's end to one side, in open water
	var isle := Vector2.INF
	var deepest := WATER - 0.05
	for side: float in [1.0, -1.0]:
		for d: float in [5.0, 6.5, 8.0, 9.5, 11.0]:
			for f: float in [-1.0, 1.5, 4.0]:
				var q := j1 + Vector2(-fwd.y, fwd.x) * side * d + fwd * f
				var g := Kit.low(sp, q, 1.6)
				if g < deepest and WorldLanes.site_at(q, 2.0).is_empty() and not _camp_near(q, 9.0):
					deepest = g
					isle = q
	if isle == Vector2.INF:
		print("SECRETS corvin's sluice: no open water for the islet")
		return
	var node := Node3D.new()
	node.name = "CorvinSluice"
	node.set_meta("site", "secrets_sluice")
	host.add_child(node)
	var bottom := Kit.low(sp, isle, 2.0)
	var high := bottom
	for i in 12:
		var a2 := TAU * float(i) / 12.0
		for rr: float in [2.4, 3.4]:
			high = maxf(high, Kit.gy(sp, isle.x + cos(a2) * rr, isle.y + sin(a2) * rr))
	var top := maxf(bottom + 2.8, high + 2.6)        # out of reach from the water round it (a grab is 2.25)
	var k := OssKit.new()
	k.keep_lanes = false
	LK.ensure_mats()
	var ic := Vector3(isle.x, top, isle.y)
	k.box("stone", Vector3(isle.x, (top + bottom) * 0.5 - 0.3, isle.y), Vector3(3.2, top - bottom + 0.6, 3.2), Basis(Vector3.UP, 0.3), true, 0.78)
	k.box("stone", ic + Vector3.UP * 0.05, Vector3(3.4, 0.12, 3.4), Basis(Vector3.UP, 0.3), false, 0.9)
	# Corvin's last lamp on an iron post, still burning
	k.box("iron", ic + Vector3(0.9, 0.9, -0.9), Vector3(0.08, 1.8, 0.08), Basis.IDENTITY, true, 0.8)
	k.box("glow", ic + Vector3(0.9, 1.7, -0.9), Vector3(0.18, 0.24, 0.18), Basis.IDENTITY, false, 0.55)
	# the lever in the boat-house: a post, a slot, a long iron handle
	var lv: Vector3 = landing.get_meta("lever_at")
	k.box("wood", lv + Vector3.UP * 0.5, Vector3(0.3, 1.0, 0.3), Basis.IDENTITY, true, 0.75)
	k.commit(node, "SluiceBody")
	Kit.omni(node, ic + Vector3(0.9, 2.1, -0.9), Color(1.0, 0.7, 0.4), 0.8, 7.0)
	var handle := Kit.mi(node, _bx(Vector3(0.08, 1.1, 0.08)), OssKit.mat("iron"), Transform3D(Basis(Vector3.FORWARD, -0.6), lv + Vector3.UP * 1.3), 50.0)
	# the sunk walk: a ramp of stone from the jetty's end to the islet, under the water until raised
	var a := Vector3(j1.x, WATER + 0.3, j1.y)
	var e := ic + Vector3(0, 0.05, 0) + (Vector3(a.x, 0, a.z) - Vector3(ic.x, 0, ic.z)).normalized() * 1.5
	var mid := (a + e) * 0.5
	var run := Vector3(e.x - a.x, e.y - a.y, e.z - a.z)
	var rb := Basis.looking_at(run.normalized(), Vector3.UP)
	var ramp_size := Vector3(1.4, 0.3, run.length() + 0.4)
	var sunk := Vector3.DOWN * (e.y - WATER + 1.2)
	var walk := Kit.mi(node, _bx(ramp_size), OssKit.mat("stone"), Transform3D(rb, mid + sunk), 90.0)
	var walk_body := Kit.box_body(node, mid, ramp_size, rb)
	var lever := Kit.touch(node, lv + Vector3.UP * 1.0, "", func(_by: Node) -> void: pull(lv), 2.0)
	lever.name = "Lever"
	lever.set("prompt_fn", func() -> String: return "" if State.has("open", "sluice") else "Pull the sluice lever")
	State.cache(node, "corvin_sluice", ic + Vector3(-0.5, 0.5, 0.5), "Corvin's lamp-box", Callable())
	State.reading(node, "sc_sluice", ic + Vector3(0.4, 0.6, 0.9))
	State.reading(node, "sc_lever", lv + Vector3(0.6, 1.0, 0.0))
	Kit.site(root, "secrets_sluice", Rect2(isle.x - 2.0, isle.y - 2.0, 4.0, 4.0), top)
	var sync := func(animate: bool) -> void:
		var open := State.has("open", "sluice")
		Kit.set_body(walk_body, open)
		handle.global_transform = Transform3D(Basis(Vector3.FORWARD, 0.6 if open else -0.6), lv + Vector3.UP * 1.3)
		var to := Transform3D(rb, mid if open else mid + sunk)
		if open and animate:
			Kit.play("grind", mid, -2.0, 0.8)
			walk.create_tween().tween_property(walk, "global_transform", to, 2.4).set_trans(Tween.TRANS_SINE)
		else:
			walk.global_transform = to
	State.register({"id": "corvin_sluice", "name": "Corvin's Sluice", "at": ic, "r": 4.0, "node": node, "sync": sync,
		"lever": lv, "walk": [a, e], "door": walk_body,
		"route": {"from": Vector3(j0.x, 0, j0.y), "pts": [Vector3(j1.x, 0, j1.y), e, ic] as Array[Vector3]}, "goal": ic})
	sync.call(false)


static func pull(at: Vector3) -> void:
	if State.has("open", "sluice"):
		return
	State.mark("open", "sluice")
	Kit.play("clank", at, -2.0)
	State.toast("Somewhere under the jetty a chain runs out. Out on the mere, stone comes up through the water.")
	State.refresh(true)
