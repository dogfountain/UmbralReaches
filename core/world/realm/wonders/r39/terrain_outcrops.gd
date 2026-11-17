extends RefCounted
## THE OUTCROPS (the world pass): where the benches (terrain_benches.gd) and the land's own scarps rise steeply, strata
## of stone break the slope: stratified cliff faces (RockKit.cliff: cached, LOD'd, convex collision) 5-9 m wide and
## 3-6 m high, turned to face down the hill, stood along the steep ground of the Far Reaches (outside the old Marches).
## Up to 90, found on a 12 m jittered grid where the slope is 21-50 degrees, dry, 14 m off every way and outside every
## registered site; style by the region's biome (ash, mossy in the woods and fens, granite elsewhere). Each keeps the
## trees off (RealmFlora.tree_clear) and fades out at 170 m. A few sizes only, so the meshes are shared (and cached on disk).

const WK := preload("res://core/world/realm/wonders/r39/wonder_kit.gd")
const RockKit := preload("res://core/world/realm/rock_kit.gd")
const Flora := preload("res://core/world/realm/realm_flora.gd")
const MAX := 90
const SIZES := [Vector3(6.0, 3.6, 2.4), Vector3(7.5, 4.8, 2.8), Vector3(9.0, 6.0, 3.2), Vector3(5.0, 3.0, 2.0)]


static func build(root: Node) -> void:
	var w := new()
	w._run(root)


func _run(root: Node) -> void:
	var host := Node3D.new()
	host.name = "Outcrops"
	root.add_child(host)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var biome := {}
	for reg: Dictionary in RealmLayout.REGIONS:
		biome[String(reg.id)] = String(reg.get("biome", ""))
	var placed := 0
	var mb := RealmReaches.MARCH_BOUNDS
	var gz := -138.0
	while gz < 390.0 and placed < MAX:
		var gx := -360.0
		while gx < 360.0 and placed < MAX:
			gx += 12.0
			var p := Vector2(gx + rng.randf() * 10.0, gz + rng.randf() * 10.0)
			if mb.has_point(p) or not RealmLayout.BOUNDS.grow(-12.0).has_point(p):
				continue
			var h := WK.h(p.x, p.y)
			if WK.wet(p.x, p.y):
				continue
			var gxv := (WK.h(p.x + 4.0, p.y) - WK.h(p.x - 4.0, p.y)) / 8.0
			var gzv := (WK.h(p.x, p.y + 4.0) - WK.h(p.x, p.y - 4.0)) / 8.0
			var sl := sqrt(gxv * gxv + gzv * gzv)
			if sl < 0.38 or sl > 1.2 or rng.randf() > 0.55:
				continue
			if RealmLayout.path_dist(p) < 14.0 or WK.taken(p, Vector2(6.0, 4.0), 0.0, ["x"], 4.0):
				continue
			var down := Vector2(-gxv, -gzv).normalized()
			var reg := WK.region_at(p)
			var bio: String = String(biome.get(reg, ""))
			var style := "ash" if bio == "ash" else ("mossy" if bio in ["oldforest", "fen"] else "granite")
			var sz: Vector3 = SIZES[rng.randi() % SIZES.size()]
			var mesh := RockKit.cliff(rng.randi() % 8, sz, style)
			var xf := Transform3D(Basis(Vector3.UP, atan2(down.x, down.y)), Vector3(p.x, h - 0.5, p.y))
			RockKit.spawn(host, mesh, xf, true, 170.0)
			Flora.tree_clear.append([p, sz.x * 0.55 + 2.0])
			placed += 1
		gz += 12.0
	print("WONDER terrain_outcrops: %d scarp faces" % placed)
