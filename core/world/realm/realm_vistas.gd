extends RefCounted
## Vistas and night spectacle the wider Realm earns (docs/far_reaches.md):
##   moon shafts   where an old wood opens to the sky (the Lanternwood, the Southwood, the Sorrow's alders, the
##                 Grandmother Oak's grove), soft shafts along the moon's own direction and a slow drift of motes,
##                 found at build time from the flora's canopy (a clearing ringed by trees), at most a few per wood.
##                 Additive cards, no lights; they fade with distance. The Thornwood's shafts stay the secret's reward.
##   lookouts      three cairns on the downs' south scarp and the Kings' ridge, each with a stone seat (and a glide
##                 perch where the ground falls away), set where the Long Arches, the Reedmere and the far woods all show at once.
##   places        the March beacons, the scarp's cliffs, sightlines and valley mist (vistas/vista_places.gd).
## Built by realm_pois.gd (REACH_POIS): reserve() before the stamp and the flora, build() after the flora.

const Flora := preload("res://core/world/realm/realm_flora.gd")
const P := preload("res://core/world/realm/realm_pois.gd")
const Kit := preload("res://core/life/secrets/kit.gd")
const PropModels := preload("res://core/world/realm/prop_models.gd")
const Places := preload("res://core/world/realm/vistas/vista_places.gd")

## Woods that get moon shafts where their canopy opens: region id -> how many clearings at most (the Sorrow's alders
## open by themselves; the Lanternwood and the Southwood close overhead, so CLEARINGS opens a few glades in them).
const SHAFT_WOODS := {"sorrow": 3, "oak": 2}
const CLEARINGS := [Vector2(-354.0, -36.0), Vector2(-318.0, 32.0), Vector2(-296.0, -14.0), Vector2(-350.0, 2.0),
	Vector2(112.0, 272.0), Vector2(188.0, 282.0), Vector2(250.0, 334.0), Vector2(178.0, 380.0), Vector2(116.0, 384.0)]
const CLEARING_R := 8.5
const FIRE_SKY := 3.0               ## no crown within this (plus 0.6 of its spread) of a campfire slot
const SHAFT_SIZE := Vector2(4.2, 20.0)
## Lookouts: [xz, the way it looks (xz)]
const LOOKOUTS := [[Vector2(12.0, 248.0), Vector2(0.0, 342.0)], [Vector2(112.0, 244.0), Vector2(150.0, 330.0)], [Vector2(-330.0, 206.0), Vector2(-300.0, 330.0)]]

static var shafts_at: Array[Vector2] = []        ## last build (tests, stills)
static var lookouts_at: Array[Vector3] = []


static func reserve(_root: Node) -> void:
	Places.reserve(_root)
	for lk: Array in LOOKOUTS:
		var q: Vector2 = lk[0]
		var f: Vector2 = ((lk[1] as Vector2) - q).normalized()
		Flora.tree_clear.append([q, 7.0])
		for k in 4:                                  # a corridor cut toward the view
			Flora.tree_clear.append([q + f * (9.0 + 8.0 * float(k)), 5.0 + 1.5 * float(k)])
	for c: Vector2 in CLEARINGS:
		Flora.tree_clear.append([c, CLEARING_R])
	# open sky over every campfire: a fire's smoke and sparks go up into the night, not into a crown (map audit, 18 Nov:
	# willows hung over the foundry fire, Reedholm's landing and Stillwater's shore; trunks were already kept off, crowns not)
	for slots: Dictionary in [RealmLayout.SLOTS, RealmReaches.SLOTS]:
		for id: String in slots:
			for s: Dictionary in slots[id]:
				if String(s.kind) == "fire":
					Flora.tree_clear.append([s.at as Vector2, FIRE_SKY])
	# and over every raid floor (its trunks were kept off; pines leaned over the Anchoress's terrace and the summit deck)
	for r: Dictionary in RealmLayout.RAIDS:
		Flora.tree_clear.append([r.c as Vector2, float(r.r) - 1.0])
		if r.has("rx"):
			for sgn: float in [-1.0, 1.0]:
				Flora.tree_clear.append([(r.c as Vector2) + Vector2(sgn * (float(r.rx) - float(r.r) * 0.7), 0.0), float(r.r) * 0.7 - 1.0])


static func build(holder: Node) -> void:
	var host := Node3D.new()
	host.name = "Vistas"
	host.set_meta("site", "realm_vistas")
	holder.add_child(host)
	var root := holder.get_parent() if holder.get_parent() != null else holder
	_shafts(root, host)
	_lookouts(root, host)
	Places.build(holder as Node3D)
	print("REALM_VISTAS %d moon shafts %s, %d lookouts %s" % [shafts_at.size(), shafts_at, lookouts_at.size(), lookouts_at])


# --- moon shafts ---------------------------------------------------------------------------------------

static func _moon_dir(root: Node) -> Vector3:
	for l in root.find_children("*", "DirectionalLight3D", true, false):
		if l.has_meta(&"no_shadow"):
			continue                                   # the night's fill (atmosphere.gd), not the moon
		return -(l as DirectionalLight3D).global_basis.z
	return Vector3(0.35, -0.85, 0.4).normalized()


## Clearings in a region: open ground (little canopy over it) with a ring of trees round it (canopy 10-14 m out).
static func _clearings(rid: String, want: int) -> Array[Vector2]:
	var region := {}
	for r: Dictionary in RealmLayout.REGIONS:
		if String(r.id) == rid:
			region = r
	if region.is_empty():
		return []
	var box: Rect2 = (region.rect as Rect2) if region.has("rect") else Rect2(region.c, Vector2.ZERO).grow(float(region.r))
	var out: Array[Vector2] = []
	var z := box.position.y + 6.0
	while z < box.end.y - 6.0 and out.size() < want:
		var x := box.position.x + 6.0
		while x < box.end.x - 6.0 and out.size() < want:
			var q := Vector2(x, z)
			x += 7.0
			if String(RealmLayout.region_at(q.x, q.y).get("id", "")) != rid or Flora.cover_at(q.x, q.y) > 0.08:
				continue
			if RealmLayout.path_dist(q) < 3.0 or not WorldLanes.site_at(q, 2.0).is_empty() or not is_nan(RealmLayout.water_level_at(q.x, q.y)):
				continue
			var ring := 0
			for k in 8:
				var a := TAU * float(k) / 8.0
				if Flora.cover_at(q.x + cos(a) * 11.0, q.y + sin(a) * 11.0) > 0.3:
					ring += 1
			if ring < 6:
				continue
			var spaced := true
			for o in out:
				if o.distance_to(q) < 34.0:
					spaced = false
			if spaced:
				out.append(q)
		z += 7.0
	return out


static func _shafts(root: Node, host: Node3D) -> void:
	shafts_at.clear()
	var sp := Kit.space(root)
	var moon_dir := _moon_dir(root)
	var up := -moon_dir
	if up.y < 0.3:
		up = (up + Vector3.UP).normalized()
	var mesh := QuadMesh.new()
	mesh.size = SHAFT_SIZE
	mesh.center_offset = Vector3(0, SHAFT_SIZE.y * 0.5, 0)
	var mat := Kit.shader_mat("shaft")
	var node := Node3D.new()
	node.name = "MoonShafts"
	host.add_child(node)
	var spots: Array[Vector2] = []
	for c: Vector2 in CLEARINGS:
		if RealmLayout.path_dist(c) > 2.0 and WorldLanes.site_at(c, 2.0).is_empty():
			spots.append(c)
	for rid: String in SHAFT_WOODS:
		spots.append_array(_clearings(rid, int(SHAFT_WOODS[rid])))
	for p: Vector2 in spots:
		var g := Kit.gy(sp, p.x, p.y)
		for k in 3:
			var yaw := float(k) * PI / 3.0
			var side := Vector3(cos(yaw), 0, sin(yaw)).cross(up).normalized()
			var fwd := side.cross(up).normalized()
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = 90.0
			mi.visibility_range_end_margin = 14.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			node.add_child(mi)
			mi.global_transform = Transform3D(Basis(side, up, fwd), Vector3(p.x, g - 0.5, p.y))
			mi.set_instance_shader_parameter(&"strength", 1.15)
		var e := Vfx.emitter(Color(0.5, 0.65, 1.0, 0.6), {"count": 12, "life": 6.0, "speed": Vector2(0.02, 0.12), "size": 0.035, "gravity": 0.01, "radius": 1.6, "turbulence": true, "explosive": 0.0})
		if e:
			e.name = "Motes"
			node.add_child(e)
			e.global_position = Vector3(p.x, g + 2.5, p.y)
			e.visibility_range_end = 40.0
		shafts_at.append(p)


# --- lookouts ------------------------------------------------------------------------------------------

static func _lookouts(root: Node, host: Node3D) -> void:
	lookouts_at.clear()
	var sp := Kit.space(root)
	var pm := PropModels.new()
	for lk: Array in LOOKOUTS:
		var q: Vector2 = lk[0]
		var look: Vector2 = lk[1]
		if not WorldLanes.site_at(q, 2.0).is_empty() or RealmLayout.path_dist(q) < 2.5:
			continue
		var y := Kit.low(sp, q, 1.6)
		var f := (look - q).normalized()
		var yaw := atan2(f.x, f.y)
		var b := Basis(Vector3.UP, yaw)
		pm.add("lore_cairn_stack.glb", Transform3D(b.scaled(Vector3.ONE * 1.6), Vector3(q.x, y - 0.1, q.y)))
		var seat := q - f * 2.6 + Vector2(f.y, -f.x) * 1.4
		pm.add("bench.glb", Transform3D(b, Vector3(seat.x, Kit.low(sp, seat, 0.8) - 0.05, seat.y)))
		var drop := y - RealmLayout.ground(sp, q.x + f.x * 8.0, q.y + f.y * 8.0)
		if drop > 5.5:                                  # a perch only where the ground really falls away below it
			P._perch(host, Vector3(q.x + f.x * 1.2, y + 0.3, q.y + f.y * 1.2), Vector3(f.x, 0.0, f.y), drop)
		lookouts_at.append(Vector3(q.x, y, q.y))
	for mi in pm.commit(host, "Lookouts", true, true):
		mi.visibility_range_end = 160.0
		mi.visibility_range_end_margin = 20.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
