extends Node
## Dev probe for the r34 enemies pass: rates candidate camp spots on the built Realm (region, ground,
## slope, water, ways, sites, fires, bounds) and searches round the ones that fail. Not a test.
## Run: HOME=<scratch>/home godot --headless --path . res://zz/enemies_r34_probe.tscn
const Land := preload("res://core/world/realm/realm_land.gd")

var main: Node
var t := 0.0
var done := false
var space: PhysicsDirectSpaceState3D

## [region, xz]
const CANDS := [
	["*", Vector2(-66, 34)], ["*", Vector2(-62, 28)], ["*", Vector2(-74, 32)], ["*", Vector2(-96, 6)], ["*", Vector2(-70, -40)], ["*", Vector2(-100, -10)],
	["thornwood", Vector2(-108, 0)], ["thornwood", Vector2(-104, 30)], ["thornwood", Vector2(-112, -46)], ["thornwood", Vector2(-96, 36)],
]


func _ready() -> void:
	Travel._busy = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	t += d
	if done:
		return
	if t > 200.0:
		print("PROBE timeout")
		get_tree().quit(1)
		done = true
		return
	if main == null or not main.has_meta("summit_dressed") or t < 4.0:
		return
	var sp := main.get_node_or_null("EnemySpawner")
	if sp == null or not bool(sp.get("planted_done")):
		return
	done = true
	await get_tree().physics_frame
	space = (main as Node3D).get_world_3d().direct_space_state
	_areas()
	for c: Array in CANDS:
		var rid := String(c[0])
		var q: Vector2 = c[1]
		var why := _why(rid, q)
		if why.is_empty():
			print("PROBE ok   %-10s %s y %.1f path %.1f" % [rid, q, _terrain(q.x, q.y), RealmLayout.path_dist(q)])
		else:
			print("PROBE BAD  %-10s %s: %s  -> best %s" % [rid, q, ", ".join(why), _search(rid, q)])
	_henge()
	_sites()
	get_tree().quit(0)


func _fires() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for b in get_tree().get_nodes_in_group(Groups.BRAZIER):
		out.append(Vector2((b as Node3D).global_position.x, (b as Node3D).global_position.z))
	for rid: String in RealmLayout.SLOTS:
		for s: Dictionary in RealmLayout.SLOTS[rid]:
			if String(s.kind) == "fire":
				out.append(s.at)
	return out


func _why(rid: String, q: Vector2) -> PackedStringArray:
	var why := PackedStringArray()
	var reg := String(RealmLayout.region_at(q.x, q.y).get("id", "-"))
	if reg != rid and rid != "*":
		why.append("in " + reg)
	if not RealmLayout.BOUNDS.grow(-10.5).has_point(q):
		why.append("bounds")
	var g := _terrain(q.x, q.y)
	if is_nan(g):
		why.append("no ground")
		return why
	var lo := INF
	var hi := -INF
	for o: Vector2 in [Vector2(2.5, 0), Vector2(-2.5, 0), Vector2(0, 2.5), Vector2(0, -2.5)]:
		var gy := _terrain(q.x + o.x, q.y + o.y)
		lo = minf(lo, gy)
		hi = maxf(hi, gy)
	if hi - lo > 2.0:
		why.append("steep %.1f" % (hi - lo))
	if Land.in_water(q.x, q.y) or Land.in_water(q.x + 2.5, q.y) or Land.in_water(q.x - 2.5, q.y) or Land.in_water(q.x, q.y + 2.5) or Land.in_water(q.x, q.y - 2.5):
		why.append("water")
	if RealmLayout.path_dist(q) < 4.0:
		why.append("way %.1f" % RealmLayout.path_dist(q))
	var s := WorldLanes.site_at(q, 2.5)
	if not s.is_empty():
		why.append("site " + String(s.name))
	for f in _fires():
		if f.distance_to(q) < 14.0:
			why.append("fire %.1f" % f.distance_to(q))
	for r: Dictionary in RealmLayout.RAIDS:
		if q.distance_to(r.c) < float(r.r) + 6.0:
			why.append("raid")
	return why


func _search(rid: String, want: Vector2) -> String:
	for r in range(1, 26):
		for k in 24:
			var q := (want + Vector2(cos(TAU * k / 24.0), sin(TAU * k / 24.0)) * float(r)).round()
			if _why(rid, q).is_empty():
				return "%s (%d m)" % [q, r]
	return "none"


func _areas() -> void:
	var area := {}
	var camps := {}
	var foes := {}
	for x in range(-155, 155, 2):
		for z in range(-150, 175, 2):
			var id := String(RealmLayout.region_at(x + 1.0, z + 1.0).get("id", "-"))
			area[id] = int(area.get(id, 0)) + 4
	for cp: Dictionary in EnemySpawner.REALM_CAMPS:
		var id := String(RealmLayout.region_at(cp.at.x, cp.at.z).get("id", "-"))
		camps[id] = int(camps.get(id, 0)) + 1
		foes[id] = int(foes.get(id, 0)) + (cp.kinds as Array).size()
	for id: String in area:
		print("PROBE area %-10s %6d m2  camps %d foes %d  (camps/10k %.2f)" % [id, area[id], camps.get(id, 0), foes.get(id, 0), float(camps.get(id, 0)) * 10000.0 / float(area[id])])


func _henge() -> void:
	for b in get_tree().get_nodes_in_group(Groups.BRAZIER):
		print("PROBE fire %s %s" % [b.name, (b as Node3D).global_position])
	for cp: Dictionary in EnemySpawner.REALM_CAMPS:
		if String(cp.get("seal", "")) != "henge":
			continue
		var q := Vector2(cp.at.x, cp.at.z)
		print("PROBE henge guard %s: y %.1f, path %.1f, to stair foot %.1f, to henge c %.1f, site '%s'" % [q, _terrain(q.x, q.y), RealmLayout.path_dist(q),
			q.distance_to(RealmLayout.HENGE_STAIR_FOOT), q.distance_to(RealmLayout.HENGE_C), WorldLanes.site_at(q, 1.0).get("name", "")])
	var sp := main.get_node("EnemySpawner")
	for g: Dictionary in sp.call("seal_guards"):
		print("PROBE live guard %s %s" % [g.seal, g.pos])


func _sites() -> void:
	for n in get_tree().get_nodes_in_group(&"guardian_site"):
		var p := (n as Node3D).global_position
		print("PROBE guardian_site %s at %s region %s guardian '%s'" % [n.name, p, RealmLayout.region_at(p.x, p.z).get("id", "-"), n.get_meta("guardian", "")])
	for n in get_tree().get_nodes_in_group(&"world_poi"):
		print("PROBE poi %s %s" % [n.get_meta("poi", n.name), n.get_meta("centre", Vector3.ZERO)])


func _terrain(x: float, z: float) -> float:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x + 0.0037, 140, z + 0.0029), Vector3(x, -80, z), Layers.WORLD))
	var ex: Array[RID] = []
	for i in 8:
		if hit.is_empty():
			return NAN
		if String((hit.collider as Node).name).begins_with("Terrain"):
			return (hit.position as Vector3).y
		ex.append((hit.collider as CollisionObject3D).get_rid())
		var q := PhysicsRayQueryParameters3D.create(Vector3(x + 0.0037, 140, z + 0.0029), Vector3(x, -80, z), Layers.WORLD)
		q.exclude = ex
		hit = space.intersect_ray(q)
	return NAN
