extends Node
## RealmLore headless check: godot --headless --path . res://zz/realm_lore_test.tscn -- --realm --realm-modules=land,lore
## Waits for the module, then checks: inscriptions (count, text, off paths, not buried), lights
## (<= 12, shadows off), every landmark holder has meta "site", every registered site is clear of
## the Realm paths, the tavern, the brazier's 10 m and the boss sites. Ends LORE TEST PASS / FAIL n.
const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const LoreDB := preload("res://core/world/realm/lore_db.gd")
const CodexStore := preload("res://core/world/realm/lore/codex_store.gd")
var t := 0.0
var fails := 0
var done := false


func _ready() -> void:
	# never touch the player's journal: an in-memory store for this run
	CodexStore.persist = false
	CodexStore.use_path("user://codex_test.cfg", false)
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func fail(msg: String) -> void:
	fails += 1
	print("LORE FAIL ", msg)


func _process(d: float) -> void:
	t += d
	if done:
		return
	var rl := get_tree().root.find_child("RealmLore", true, false)
	if rl == null or not rl.has_meta("scraps"):
		if t > 120.0:
			fail("RealmLore never finished")
			_end()
		return
	done = true
	await get_tree().create_timer(1.0).timeout
	var space := (rl as Node3D).get_world_3d().direct_space_state
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--probe="):        # ground map: '~' water, digits = height
			var v := a.trim_prefix("--probe=").split(",")
			var z := float(v[1])
			while z <= float(v[3]):
				var line := "%5d " % int(z)
				var x := float(v[0])
				while x <= float(v[2]):
					var gy := RealmLayout.ground(space, x, z)
					line += "~" if gy < -0.75 else str(clampi(int(gy + 1.0), 0, 9))
					x += 2.0
				print("PROBE ", line)
				z += 2.0
	# inscriptions
	var scraps := rl.find_children("Lore_*", "", true, false)
	print("LORE inscriptions placed: %d (db entries %d)" % [scraps.size(), LoreDB.TEXTS.size()])
	if scraps.size() < 80:
		fail("only %d inscriptions" % scraps.size())
	var placed := {}
	for s in scraps:
		var n := s as Node3D
		var id := String(n.get("lore_id"))
		placed[id] = true
		if String(n.get("body")) == "":
			fail("%s has no text" % id)
		var p := n.global_position
		var gy := RealmLayout.ground(space, p.x, p.z)
		if p.y < gy - 0.3:
			fail("%s buried (%.2f under ground %.2f)" % [id, p.y, gy])
		if p.y > gy + 3.0:
			fail("%s floating %.1f m" % [id, p.y - gy])
	# every inscription reads: into the journal and the reading panel (or one toast without a
	# codex), its toast form wrapped to the HUD's label; the sense point stands in open air
	var codex := get_tree().get_first_node_in_group("codex")
	if codex == null:
		fail("no Codex in the scene")
	var toasts: Array[String] = []
	var cb := func(t: String) -> void: toasts.append(t)
	Events.toast.connect(cb)
	var shown := 0
	for s in scraps:
		var id := String(s.get("lore_id"))
		if s.get_node_or_null("Glint") == null:
			fail("%s has no glint before reading" % id)
		(s as Interactable).interact(null)
		if not CodexStore.has_read(id):
			fail("%s not in the journal after reading" % id)
		if codex and String(codex.call("reading_id")) == id:
			shown += 1
		var p := (s as Node3D).global_position
		# a sphere, not a point: Jolt's point-in-trimesh test counts ray crossings, so a point under
		# any roof reads as "inside"
		var q := PhysicsShapeQueryParameters3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.25
		q.shape = sph
		q.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * 0.9)
		q.collision_mask = Layers.WORLD
		var hits := space.intersect_shape(q, 1)
		if not hits.is_empty():
			fail("%s sense point inside %s at %s" % [s.get("lore_id"), (hits[0].collider as Node).get_path(), p.snapped(Vector3.ONE * 0.1)])
	Events.toast.disconnect(cb)
	if codex and shown != scraps.size():
		fail("reading panel showed %d of %d" % [shown, scraps.size()])
	var longest := 0
	for s in scraps:
		for line in String(s.call("wrapped")).split("\n"):
			longest = maxi(longest, line.length())
	print("LORE read: %d into the journal, %d in the panel, %d toasts, longest toast line %d chars" % [CodexStore.read.size(), shown, toasts.size(), longest])
	if longest > 90:
		fail("toast line of %d chars" % longest)
	for id: String in LoreDB.TEXTS:
		if not placed.has(id):
			print("LORE note: entry %s not placed" % id)
	# lights
	var lights := rl.find_children("*", "OmniLight3D", true, false)
	print("LORE lights: %d" % lights.size())
	if lights.size() > 12:
		fail("%d lights" % lights.size())
	for l in lights:
		if (l as Light3D).shadow_enabled:
			fail("%s casts shadows" % l.name)
	# holders
	for c in rl.get_children():
		if not c.has_meta("site"):
			fail("holder %s has no site meta" % c.name)
	# sites
	var mine: Array[String] = LK.site_names
	print("LORE sites: %d" % mine.size())
	for st in WorldLanes.sites:
		if not String(st.name) in mine:
			continue
		var r: Rect2 = st.rect
		var minp := INF
		var x := r.position.x
		while x <= r.end.x + 0.01:
			var z := r.position.y
			while z <= r.end.y + 0.01:
				minp = minf(minp, RealmLayout.path_dist(Vector2(x, z)))
				z += 0.5
			x += 0.5
		if minp < 0.3:
			fail("site %s on a path (%.2f)" % [st.name, minp])
		if r.intersects(Rect2(9.5, 21.0, 20.0, 14.4)):
			fail("site %s on the tavern" % st.name)
		var cl := Vector2(clampf(0.0, r.position.x, r.end.x), clampf(33.0, r.position.y, r.end.y))
		if cl.distance_to(Vector2(0, 33)) < 10.0:
			fail("site %s inside the brazier's 10 m" % st.name)
		if Vector2(clampf(-72.0, r.position.x, r.end.x), clampf(-18.0, r.position.y, r.end.y)).distance_to(Vector2(-72, -18)) < 18.0:
			fail("site %s on the henge" % st.name)
		if r.intersects(Rect2(-24, -118, 48, 106)):
			fail("site %s in the rift" % st.name)
		if r.intersects(Rect2(RealmLayout.OSSUARY.position.x, RealmLayout.OSSUARY.position.z, RealmLayout.OSSUARY.size.x, RealmLayout.OSSUARY.size.z)):
			fail("site %s on the Ossuary" % st.name)
		for other in WorldLanes.sites:
			if String(other.name) in mine:
				continue
			if (other.rect as Rect2).intersects(r):
				fail("site %s overlaps %s" % [st.name, other.name])
	for lm: Dictionary in LK.landmarks:
		print("LORE landmark %s at %s sites %s" % [lm.name, (lm.at as Vector3).snapped(Vector3.ONE * 0.1), lm.sites])
	_end()


func _end() -> void:
	print("LORE TEST PASS" if fails == 0 else "LORE TEST FAIL %d" % fails)
	get_tree().quit()
