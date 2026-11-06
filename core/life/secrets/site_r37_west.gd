extends RefCounted
## West Marches: the Sorrow's hidden thing, beside the place the player already has a reason to wade
## to (realm_pois_r37_west.gd's drowned shrine), in the manner of site_r34.gd:
##   aldith_walk   ALDITH'S WALK (the Sorrow's Banks): an iron ring set in the shrine's plinth. Pulled, a stone
##                 walk of stepping slabs comes up through the river from the shrine's step to a round islet in
##                 the deeper water upstream, where Saint Aldith kept her last lamp and a box of what the
##                 pilgrims paid her. Out of reach of the water round it (a grab is 2.25), so only the walk
##                 gets you there. The three votive boats of Ennis's task are set on the same altar.
## State: secrets' own (State: open.aldith, looted.aldith_walk, pages). Texts: pages.gd (sc_aldith, sc_aldith_ring).

const Kit := preload("res://core/life/secrets/kit.gd")
const State := preload("res://core/life/secrets/state.gd")
const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const WATER := -0.9


static func release() -> void:
	pass


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


static func build(root: Node, host: Node3D) -> void:
	var pois := root.get_node_or_null("RealmPois")
	if pois == null:
		print("SECRETS r37 west: no places built")
		return
	_walk(root, host, pois.get_node_or_null("Poi_sorrow_shrine") as Node3D)


static func _walk(root: Node, host: Node3D, shrine: Node3D) -> void:
	if shrine == null:
		print("SECRETS aldith's walk: no shrine")
		return
	var sp := Kit.space(root)
	var s0 := Vector2(shrine.global_position.x, shrine.global_position.z)
	# the islet: round, in the deeper water upstream or downstream of the shrine, off the sites and the camps
	var isle := Vector2.INF
	var deepest := WATER - 0.05
	for d: float in [8.0, 10.0, 12.0, 14.0, 16.0]:
		for dz: float in [-1.0, 1.0]:
			for dx: float in [-2.0, 0.0, 2.0]:
				var q := s0 + Vector2(dx, dz * d)
				var g := Kit.low(sp, q, 1.6)
				if g < deepest and WorldLanes.site_at(q, 2.0).is_empty() and not _camp_near(q, 9.0):
					deepest = g
					isle = q
	if isle == Vector2.INF:
		print("SECRETS aldith's walk: no open water for the islet")
		return
	var node := Node3D.new()
	node.name = "AldithWalk"
	node.set_meta("site", "secrets_aldith")
	host.add_child(node)
	var bottom := Kit.low(sp, isle, 2.0)
	var high := bottom
	for i in 12:
		var a2 := TAU * float(i) / 12.0
		for rr: float in [2.4, 3.4]:
			high = maxf(high, Kit.gy(sp, isle.x + cos(a2) * rr, isle.y + sin(a2) * rr))
	var top := maxf(bottom + 2.8, high + 2.6)
	var k := OssKit.new()
	k.keep_lanes = false
	LK.ensure_mats()
	var ic := Vector3(isle.x, top, isle.y)
	k.box("stone", Vector3(isle.x, (top + bottom) * 0.5 - 0.3, isle.y), Vector3(3.4, top - bottom + 0.6, 3.4), Basis(Vector3.UP, 0.2), true, 0.78)
	k.box("stone", ic + Vector3.UP * 0.05, Vector3(3.6, 0.12, 3.6), Basis(Vector3.UP, 0.2), false, 0.9)
	# Aldith's last lamp on an iron post, still burning (a lit pane, no light), and her box
	k.box("iron", ic + Vector3(-0.9, 0.9, -0.9), Vector3(0.08, 1.8, 0.08), Basis.IDENTITY, true, 0.8)
	k.box("glow", ic + Vector3(-0.9, 1.7, -0.9), Vector3(0.18, 0.24, 0.18), Basis.IDENTITY, false, 0.55)
	# the ring: set in the shrine's plinth, a post with an iron ring on a hook
	var lv := Vector3(shrine.global_position.x + 3.3, shrine.global_position.y + 0.9, shrine.global_position.z + 1.6)
	k.box("stone", lv + Vector3.UP * 0.0, Vector3(0.5, 0.5, 0.5), Basis.IDENTITY, true, 0.8)
	k.commit(node, "WalkBody")
	var ring := Kit.mi(node, _bx(Vector3(0.34, 0.34, 0.05)), OssKit.mat("iron"), Transform3D(Basis(Vector3.RIGHT, 0.4), lv + Vector3(0.0, 0.45, 0.0)), 50.0)
	# the sunk walk: a ramp of stone from the shrine's step to the islet, under the water until raised
	var a := Vector3(shrine.global_position.x + 1.0, WATER + 0.3, shrine.global_position.z + (3.4 if isle.y > s0.y else -3.4))
	var e := ic + Vector3(0, 0.05, 0) + (Vector3(a.x, 0, a.z) - Vector3(ic.x, 0, ic.z)).normalized() * 1.6
	var mid := (a + e) * 0.5
	var run := Vector3(e.x - a.x, e.y - a.y, e.z - a.z)
	var rb := Basis.looking_at(run.normalized(), Vector3.UP)
	var ramp_size := Vector3(1.5, 0.3, run.length() + 0.4)
	var sunk := Vector3.DOWN * (e.y - WATER + 1.2)
	var walk := Kit.mi(node, _bx(ramp_size), OssKit.mat("stone"), Transform3D(rb, mid + sunk), 90.0)
	var walk_body := Kit.box_body(node, mid, ramp_size, rb)
	var lever := Kit.touch(node, lv + Vector3.UP * 0.5, "", func(_by: Node) -> void: pull(lv), 2.0)
	lever.name = "Ring"
	lever.set("prompt_fn", func() -> String: return "" if State.has("open", "aldith") else "Pull the iron ring")
	State.cache(node, "aldith_walk", ic + Vector3(0.6, 0.5, 0.6), "Aldith's box", Callable())
	State.reading(node, "sc_aldith", ic + Vector3(-0.5, 0.6, 0.9))
	State.reading(node, "sc_aldith_ring", lv + Vector3(0.6, 0.6, 0.0))
	Kit.site(root, "secrets_aldith", Rect2(isle.x - 2.0, isle.y - 2.0, 4.0, 4.0), top)
	var sync := func(animate: bool) -> void:
		var open := State.has("open", "aldith")
		Kit.set_body(walk_body, open)
		ring.global_transform = Transform3D(Basis(Vector3.RIGHT, -0.9 if open else 0.4), lv + Vector3(0.0, 0.45 if not open else 0.2, 0.0))
		var to := Transform3D(rb, mid if open else mid + sunk)
		if open and animate:
			Kit.play("grind", mid, -2.0, 0.8)
			walk.create_tween().tween_property(walk, "global_transform", to, 2.4).set_trans(Tween.TRANS_SINE)
		else:
			walk.global_transform = to
	State.register({"id": "aldith_walk", "name": "Aldith's Walk", "at": ic, "r": 4.0, "node": node, "sync": sync,
		"lever": lv, "walk": [a, e], "door": walk_body,
		"route": {"from": Vector3(a.x, 0, a.z), "pts": [e, ic] as Array[Vector3]}, "goal": ic})
	sync.call(false)


static func pull(at: Vector3) -> void:
	if State.has("open", "aldith"):
		return
	State.mark("open", "aldith")
	Kit.play("clank", at, -2.0)
	State.toast("Under the shrine a chain runs out. Out in the river, stone comes up through the water.")
	State.refresh(true)
