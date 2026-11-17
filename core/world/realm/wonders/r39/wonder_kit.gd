extends RefCounted
## The shared hand of the world-pass landmarks (the world-pass landmarks doc). Every big set piece of the world pass (the
## Sleeper, the Hollow King, the Salt Ship, the Wardens' Line, the Chain Span, the Titan Gates, the Hermit Caches)
## builds through one of these: an OssKit (one mesh per material, collision from the same faces, occluders) plus the
## things a landmark needs that the kit does not give: a free-ground finder, tubes and beams at any angle, fire (a
## flame card, a halo and one small unshadowed light with a distance fade), lit window glass, a chest and the
## discovery banner. Everything is built once, at Realm build time (the wonders stage runs before the terrain stamp,
## the flora, the dress and the nav bake, so the flora keeps off every site reserved here, the ground settles to the
## floors and the nav meshes include them). Nothing runs per frame. No class_name: load by path.
##   const WK := preload(wonder_kit.gd, in core/world/realm/wonders/ and its world-pass folder)

const Chest := preload("res://core/world/realm/loot_chest.gd")
const Land := preload("res://core/world/realm/realm_land.gd")
const Wayfinding := preload("res://core/world/realm/realm_wayfinding.gd")

const FIRE_COL := Color(1.0, 0.6, 0.28)

var kit := OssKit.new()
var host: Node3D
var rng := RandomNumberGenerator.new()
var lights := 0
var fires := 0
var chests := 0
var _fire_mesh: QuadMesh
var _fl: Array[Transform3D] = []        ## flame cards of this kit (one MultiMesh at commit: a fire costs no node and no draw of its own)
var _hl := {}                           ## halo size (x10) -> Array[Transform3D]
var _lrec: Array = []                   ## recorded lights [pos, colour, energy, range, attenuation, fade begin, fade length]: made at commit
var _crec: Array = []                   ## recorded chests [id, tier, at, yaw, loot]
var _wrec: Array = []                   ## recorded water planes [centre, yaw, size, visibility]
var _key := ""                          ## the GenCache key of this kit's geometry (cached())
var _loaded := false
static var light_used := 0              ## every light the wonders add counts here; past LIGHT_CAP only the glow cards and glass remain (the light budget)
const LIGHT_CAP := 72


func setup(root: Node, nm: String, seed_n: int) -> void:
	rng.seed = seed_n
	kit.keep_lanes = false
	kit.candle_lights = false
	kit.relief = false                    # ashlar relief and wall-foot debris cost build time (GDScript boxes): off unless a builder asks
	host = Node3D.new()
	host.name = nm
	host.set_meta("wonder", nm)
	root.add_child(host)


# --- ground and free ground -----------------------------------------------------------------------------

static func h(x: float, z: float) -> float:
	return Land.height_at(x, z)


static func wet(x: float, z: float) -> bool:
	return Land.height_at(x, z) < Land.water_y_at(x, z) + 0.45


## Lowest and highest ground under a centred, yawed rectangle (`half` = half extents), sampled every ~5 m; INF when a
## sample is wet or outside the Realm.
static func span(c: Vector2, half: Vector2, yaw: float) -> Vector2:
	var lo := INF
	var hi := -INF
	var ex := Vector2(cos(yaw), sin(yaw))
	var ez := Vector2(-sin(yaw), cos(yaw))
	var nx := maxi(1, int(ceilf(half.x / 2.5)))
	var nz := maxi(1, int(ceilf(half.y / 2.5)))
	for i in range(-nx, nx + 1):
		for j in range(-nz, nz + 1):
			var p := c + ex * (half.x * float(i) / float(nx)) + ez * (half.y * float(j) / float(nz))
			if not RealmLayout.BOUNDS.grow(-14.0).has_point(p) or wet(p.x, p.y):
				return Vector2(INF, INF)
			var y := h(p.x, p.y)
			lo = minf(lo, y)
			hi = maxf(hi, y)
	return Vector2(lo, hi)


## True when a yawed rectangle touches something that is already there: a town, another region's ground (not the
## regions in `allow`), a registered site, a way. The big places keep to open country between things.
static func taken(c: Vector2, half: Vector2, yaw: float, allow: Array, margin: float) -> bool:
	var r := maxf(half.x, half.y) + margin
	var box := Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
	for t: Vector3 in [Vector3(-311.0, 281.0, 42.0), Vector3(-160.0, 300.0, 46.0), Vector3(324.5, 53.5, 54.0), Vector3(6.0, 38.0, 50.0)]:
		if Vector2(t.x, t.y).distance_to(c) < t.z + r:
			return true
	for reg: Dictionary in RealmLayout.REGIONS:
		if String(reg.id) in allow:
			continue
		if reg.has("c"):
			if (reg.c as Vector2).distance_to(c) < float(reg.r) + r:
				return true
		elif reg.has("rect") and (reg.rect as Rect2).grow(-4.0).intersects(box):
			return true
	if site_hit(box, margin):
		return true
	var ex := Vector2(cos(yaw), sin(yaw))
	var ez := Vector2(-sin(yaw), cos(yaw))
	for i in range(-2, 3):
		for j in range(-2, 3):
			var p := c + ex * (half.x * float(i) / 2.0) + ez * (half.y * float(j) / 2.0)
			if RealmLayout.path_dist(p) < margin * 0.5 + 3.0:
				return true
	return false


static var _sidx := {}                  ## 32 m cell -> the registered sites touching it (built once per change of the site list)
static var _sidx_n := -1


static func _reindex() -> void:
	_sidx.clear()
	for st: Dictionary in WorldLanes.sites:
		var r: Rect2 = st.rect
		for cx in range(floori(r.position.x / 32.0), floori(r.end.x / 32.0) + 1):
			for cz in range(floori(r.position.y / 32.0), floori(r.end.y / 32.0) + 1):
				var key := Vector2i(cx, cz)
				if not _sidx.has(key):
					_sidx[key] = []
				(_sidx[key] as Array).append(st)
	_sidx_n = WorldLanes.sites.size()


## Does any registered site touch `box` (grown by `margin`)? Looks only at the sites near it (the index), not at every site.
static func site_hit(box: Rect2, margin: float) -> bool:
	if _sidx_n != WorldLanes.sites.size():
		_reindex()
	var g := box.grow(margin)
	for cx in range(floori(g.position.x / 32.0), floori(g.end.x / 32.0) + 1):
		for cz in range(floori(g.position.y / 32.0), floori(g.end.y / 32.0) + 1):
			var list: Variant = _sidx.get(Vector2i(cx, cz))
			if list == null:
				continue
			for st: Dictionary in (list as Array):
				if WorldLanes.site_hits_rect(st, box, margin):
					return true
	return false


## BOUNDED placement: the first of at most `cands.size() x yaws.size()` spots (25 height samples each) that is dry, within
## `rel` metres of relief, off the ways and clear of every registered site; else the least bad of them. Never searches, never
## returns empty: {pos: Vector2, yaw: float, lo: float, hi: float, bad: int} (bad = 0 for a clean spot).
static func place(cands: Array, half: Vector2, yaws: Array, rel := 6.0) -> Dictionary:
	var best := {}
	var best_s := INF
	for cv: Variant in cands:
		var c: Vector2 = cv
		for yv: Variant in yaws:
			var yaw := float(yv)
			var ex := Vector2(cos(yaw), sin(yaw))
			var ez := Vector2(-sin(yaw), cos(yaw))
			var lo := INF
			var hi := -INF
			var wetn := 0
			var pathn := 0
			for i in range(-2, 3):
				for j in range(-2, 3):
					var p := c + ex * (half.x * float(i) / 2.0) + ez * (half.y * float(j) / 2.0)
					var y := h(p.x, p.y)
					lo = minf(lo, y)
					hi = maxf(hi, y)
					if wet(p.x, p.y) or not RealmLayout.BOUNDS.grow(-8.0).has_point(p):
						wetn += 1
					if RealmLayout.path_dist(p) < 4.0:
						pathn += 1
			var r := maxf(half.x, half.y)
			var sitebad := 1 if site_hit(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), 2.0) else 0
			var bad := wetn * 4 + pathn * 3 + sitebad * 6 + (1 if hi - lo > rel else 0)
			var sc := float(bad) * 100.0 + (hi - lo)
			if sc < best_s:
				best_s = sc
				best = {"pos": c, "yaw": yaw, "lo": lo, "hi": hi, "bad": bad}
			if bad == 0:
				return best
	return best


## The best open spot for a yawed rectangle near one of `cands`: searched in rings round each, the flattest wins
## (relief within `max_rel` metres). Returns {pos: Vector2, yaw: float, lo: float, hi: float} or {}.
static func find(cands: Array, half: Vector2, yaws: Array, allow: Array, margin := 8.0, max_rel := 4.0, reach := 70.0) -> Dictionary:
	var best := {}
	var best_s := INF
	for cv: Variant in cands:
		var c0: Vector2 = cv
		var rad := 0.0
		while rad <= reach:
			var n := 1 if rad == 0.0 else 8
			for k in n:
				var a := TAU * float(k) / float(n) + rad * 0.13
				var c := c0 + Vector2(cos(a), sin(a)) * rad
				for yv: Variant in yaws:
					var yaw := float(yv)
					var sp := span(c, half, yaw)
					if sp.x == INF or sp.y - sp.x > max_rel:
						continue
					var s := (sp.y - sp.x) + rad * 0.04
					if s >= best_s or taken(c, half, yaw, allow, margin):
						continue
					best_s = s
					best = {"pos": c, "yaw": yaw, "lo": sp.x, "hi": sp.y}
			rad += 10.0
		if not best.is_empty() and best_s < max_rel * 0.6:
			break
	return best


## find() again with the constraints eased pass by pass (a landmark must stand somewhere): {} only if the whole Far Reaches
## has no room for it.
static func find_any(cands: Array, half: Vector2, yaws: Array, allow: Array, rel := 4.0) -> Dictionary:
	for pass_i in 4:
		var f := find(cands, half, yaws, allow, [8.0, 6.0, 4.0, 2.0][pass_i], rel * [1.0, 1.6, 2.4, 3.4][pass_i], [70.0, 110.0, 150.0, 220.0][pass_i])
		if not f.is_empty():
			return f
	return {}


## Reserve a yawed rectangle: the flora, the wayside and everything planned later keep off it; the ground is not cut.
static func reserve(nm: String, c: Vector2, half: Vector2, yaw: float, lo: float, hi: float) -> void:
	var ex := Vector2(absf(cos(yaw)), absf(sin(yaw)))
	var ext := Vector2(half.x * ex.x + half.y * ex.y, half.x * ex.y + half.y * ex.x) + Vector2(3.0, 3.0)
	WorldLanes.register_site(nm, Rect2(c - ext, ext * 2.0), lo, hi + 40.0)


## The id of the region whose ground holds `p` ("" if none): the discovery banner names it.
static func region_at(p: Vector2) -> String:
	var best := ""
	for reg: Dictionary in RealmLayout.REGIONS:
		if reg.has("rect") and (reg.rect as Rect2).has_point(p):
			best = String(reg.id)
		elif reg.has("c") and not reg.has("rect") and (reg.c as Vector2).distance_to(p) < float(reg.r):
			best = String(reg.id)
	return best


## The discovery banner and the world-event hook: the host becomes a `world_poi`.
func poi(id: String, title: String, line: String, region: String) -> void:
	host.add_to_group("world_poi")
	host.set_meta("reach", true)
	host.set_meta("poi", id)
	host.set_meta("title", title)
	host.set_meta("line", line)
	host.set_meta("region", region)


# --- geometry -------------------------------------------------------------------------------------------

static func frame(dir: Vector3) -> Basis:
	var z := dir.normalized()
	var up := Vector3.UP if absf(z.y) < 0.97 else Vector3.RIGHT
	var x := up.cross(z).normalized()
	return Basis(x, z.cross(x).normalized(), z)


## A beam from a to b, `w` wide (across), `t` thick (up), as a box.
func beam(key: String, a: Vector3, b: Vector3, w: float, t: float, solid := true, shade := 1.0) -> void:
	kit.box(key, (a + b) * 0.5, Vector3(w, t, a.distance_to(b)), frame(b - a), solid, shade)


## A prism from a to b (`sides` flat faces, radius r0 at a to r1 at b), flat-shaded: chunky bark, shafts, masts, hull
## spars. `gap` = [from, to] angles (radians, round the axis) left open (a doorway); `cap` closes the ends.
func tube(key: String, a: Vector3, b: Vector3, r0: float, r1: float, sides := 10, solid := true, shade := 1.0, gap := Vector2(1.0, -1.0), cap := false, twist := 0.0, inward := false) -> void:
	var ax := (b - a).normalized()
	var u := ax.cross(Vector3.UP if absf(ax.y) < 0.97 else Vector3.RIGHT).normalized()
	var v := ax.cross(u).normalized()
	for k in sides:
		var a0 := TAU * float(k) / float(sides) + twist
		var a1 := TAU * float(k + 1) / float(sides) + twist
		var am := (a0 + a1) * 0.5
		if gap.x < gap.y and fposmod(am - gap.x, TAU) < gap.y - gap.x:
			continue
		var d0 := u * cos(a0) + v * sin(a0)
		var d1 := u * cos(a1) + v * sin(a1)
		var out := u * cos(am) + v * sin(am)
		kit.quad(key, a + d0 * r0, a + d1 * r0, b + d1 * r1, b + d0 * r1, -out if inward else out, solid, shade)
	if cap:
		for end: int in 2:
			var c := a if end == 0 else b
			var r := r0 if end == 0 else r1
			var ring: Array = []
			for k in sides:
				var ang := TAU * float(k) / float(sides) + twist
				ring.append(c + (u * cos(ang) + v * sin(ang)) * r)
			fan(key, c, ring, -ax if end == 0 else ax, solid, shade)


## A convex polygon from its centre: `ring` (an even number of points round it) in quads of centre + 3 neighbours.
func fan(key: String, c: Vector3, ring: Array, n: Vector3, solid := true, shade := 1.0) -> void:
	var cnt := ring.size()
	for i in range(0, cnt, 2):
		kit.quad(key, c, ring[i] as Vector3, ring[(i + 1) % cnt] as Vector3, ring[(i + 2) % cnt] as Vector3, n, solid, shade)


## A flat disc (a floor, a cap) facing up or down.
func disc(key: String, c: Vector3, r: float, sides := 12, up := true, solid := true, shade := 1.0) -> void:
	var ring: Array = []
	for i in sides:
		var a0 := TAU * float(i) / float(sides)
		ring.append(c + Vector3(cos(a0), 0.0, sin(a0)) * r)
	fan(key, c, ring, Vector3.UP if up else Vector3.DOWN, solid, shade)


## A footing: a block from the ground under (x, z) (sunk 0.8 m) up to `top`.
func footing(key: String, x: float, z: float, top: float, w: Vector2, yaw := 0.0, shade := 0.86) -> void:
	var g := h(x, z) - 0.8
	kit.box(key, Vector3(x, (g + top) * 0.5, z), Vector3(w.x, top - g, w.y), Basis(Vector3.UP, yaw), true, shade)


## Lit window glass facing `out` (a quad of the kit's warm "glow" material: emissive, under the bloom threshold).
func window(base: Vector3, along: Vector3, out: Vector3, w: float, ht: float) -> void:
	var a := along.normalized() * (w * 0.5)
	var up := Vector3.UP * ht
	kit.quad("glow", base - a, base + a, base + a + up, base - a + up, out, false, 1.0)
	kit.box("iron", base + up * 0.5 + out.normalized() * 0.03, Vector3(0.07, ht, 0.07), Basis.IDENTITY, false)


## A fire: two flame cards, a halo and one small unshadowed light (it fades out past ~90 m so far fires cost nothing
## but the two cards and a halo). `s` scales it (1 = a brazier, 3 = a tower's cresset).
func fire(at: Vector3, s := 1.0, energy := 2.2, light := true, own := false) -> Array[Node3D]:
	var made: Array[Node3D] = []
	if _fire_mesh == null:
		_fire_mesh = QuadMesh.new()
		_fire_mesh.size = Vector2(0.075, 0.17)
	for i in 2:
		var pos := at + Vector3(0.18 * s * (float(i) - 0.5), 0.5 * s, 0.12 * s * (0.5 - float(i)))
		var sc := Vector3(7.0, 6.0 + float(i), 7.0) * s
		if own:
			var mi := MeshInstance3D.new()
			mi.name = "Flame"
			mi.mesh = _fire_mesh
			mi.material_override = OssKit.mat("flame")
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			host.add_child(mi)
			made.append(mi)
			mi.position = pos
			mi.scale = sc
		else:
			_fl.append(Transform3D(Basis.from_scale(sc), pos))
	var hp := at + Vector3.UP * (0.55 * s)
	if own:
		var hm := MeshInstance3D.new()
		hm.name = "FireHalo"
		var hq := QuadMesh.new()
		hq.size = Vector2(5.0, 5.0) * s
		hm.mesh = hq
		hm.material_override = OssKit.mat("halo")
		hm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		host.add_child(hm)
		made.append(hm)
		hm.position = hp
	else:
		var key := roundi(s * 10.0)
		if not _hl.has(key):
			_hl[key] = []
		(_hl[key] as Array).append(Transform3D(Basis.IDENTITY, hp))
	fires += 1
	if not light:
		return made
	var lp := at + Vector3.UP * (1.2 * s)
	if own:
		var l := _light(lp, FIRE_COL, energy, 9.0 + 5.0 * s, 1.3, 70.0, 24.0)
		if l != null:
			made.append(l)
	else:
		_lrec.append([lp, FIRE_COL, energy, 9.0 + 5.0 * s, 1.3, 70.0, 24.0])
	return made


## One unshadowed light under the host, within the wonders' light cap (null past it). Tagged for the light policy.
func _light(pos: Vector3, col: Color, energy: float, rng_m: float, att: float, fade_b: float, fade_l: float) -> OmniLight3D:
	if light_used >= LIGHT_CAP:
		return null
	light_used += 1
	var l := OmniLight3D.new()
	l.name = "WonderLight"
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng_m
	l.omni_attenuation = att
	l.light_specular = 0.25
	l.light_volumetric_fog_energy = 0.0
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = fade_b
	l.distance_fade_length = fade_l
	l.set_meta(&"light_class", &"lamp")
	l.set_meta(&"base", {"e": energy, "r": rng_m, "a": att})
	host.add_child(l)
	l.position = pos
	lights += 1
	return l


## A small lantern light with no flame card (a lit window's spill, a hung lamp). Fades out past 45 m.
func lamp(at: Vector3, col := Color(1.0, 0.7, 0.4), energy := 1.0, rng_m := 6.0, own := false) -> OmniLight3D:
	if own:
		return _light(at, col, energy, rng_m, 1.4, 38.0, 14.0)
	_lrec.append([at, col, energy, rng_m, 1.4, 38.0, 14.0])
	return null


## A chest that opens once per save (loot_chest.gd): `id` is its save key, `tier` wood / iron / reliquary.
func chest(id: String, tier: String, at: Vector3, yaw: float, loot: Dictionary) -> void:
	_crec.append([id, tier, at, yaw, loot])


## A flat translucent water plane (a cistern, a pool): recorded, made at commit.
func water_plane(c: Vector3, yaw: float, size: Vector2, vis := 120.0) -> void:
	_wrec.append([c, yaw, size, vis])


## A far beacon over the landmark (the generic system: a pale shaft and a glow; `reach` 0 = the system's own).
func beacon(at: Vector3, col: Color, radius := 1.0, ceiling := 9.0, reach := 0.0) -> Node3D:
	return Wayfinding.beacon(host, at, "", col, 0.0, radius, ceiling, true, reach)


## Commit the kit's meshes under the host. `range_end` > 0 gives every mesh of the host (and its flame cards) a dither-faded
## visibility range of that many metres: the small places (caches, towers) vanish like the wayside's props do; the
## colossal landmarks pass 0 and are never culled by range.
## Beyond `near_end` metres the kit's meshes stop and a ~12-triangle hull of their bounds (FarDetail.hull, tapered towards the
## top by `taper`) carries the silhouette to the horizon: a landmark's whole mass costs a hull's few triangles far away, so
## the near detail (relief, ornament) is free at distance. The flame cards, halos and lit glass stay (a fire is still a fire
## from afar); the lights and beacons are separate nodes. Call after commit().
func far(near_end := 150.0, taper := 0.0, col := Color(0.16, 0.17, 0.2)) -> void:
	var box := AABB()
	var first := true
	for ch in host.get_children():
		var mi := ch as MeshInstance3D
		if mi != null and String(mi.name).begins_with("Mesh_") and String(mi.name) != "Mesh_glow":
			var a := mi.get_aabb()
			box = a if first else box.merge(a)
			first = false
	if first:
		return
	FarDetail.register(host, FarDetail.hull(box, taper, col), Transform3D.IDENTITY, near_end)
	for ch in host.get_children():
		if String(ch.name).begins_with("Flames") or String(ch.name).begins_with("FireHalos") or String(ch.name) == "Mesh_glow" or ch is OmniLight3D:
			var gi := ch as GeometryInstance3D
			if gi != null:
				gi.visibility_range_end = 0.0


func commit(range_end := 0.0) -> int:
	if _key != "" and not _loaded:
		_save()
	var n := kit.commit(host, host.name + "Body")
	# flames and halos: one MultiMesh each (per halo size) for the whole kit
	if not _fl.is_empty():
		if _fire_mesh == null:
			_fire_mesh = QuadMesh.new()
			_fire_mesh.size = Vector2(0.075, 0.17)
		var fm := OssKit.multimesh(_fire_mesh, _fl, OssKit.mat("flame"), false)
		fm.name = "Flames"
		host.add_child(fm)
		n += 1
	for key: int in _hl:
		var hq := QuadMesh.new()
		hq.size = Vector2(5.0, 5.0) * (float(key) / 10.0)
		var hm := OssKit.multimesh(hq, _hl[key], OssKit.mat("halo"), false)
		hm.name = "FireHalos"
		host.add_child(hm)
		n += 1
	for lr: Array in _lrec:
		_light(lr[0] as Vector3, lr[1] as Color, float(lr[2]), float(lr[3]), float(lr[4]), float(lr[5]), float(lr[6]))
	for cr: Array in _crec:
		var c: Node3D = Chest.new()
		c.name = "Chest_" + String(cr[0])
		c.set("chest_id", String(cr[0]))
		c.set("tier", String(cr[1]))
		c.set("loot", (cr[4] as Dictionary).duplicate())
		host.add_child(c)
		c.global_transform = Transform3D(Basis(Vector3.UP, float(cr[3])), cr[2] as Vector3)
		chests += 1
	for wr: Array in _wrec:
		var pm := PlaneMesh.new()
		pm.size = wr[2] as Vector2
		var wi := MeshInstance3D.new()
		wi.name = "Water"
		wi.mesh = pm
		wi.material_override = _water_mat()
		wi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		host.add_child(wi)
		wi.global_transform = Transform3D(Basis(Vector3.UP, float(wr[1])), wr[0] as Vector3)
		wi.visibility_range_end = float(wr[3])
	if host.is_in_group("world_poi") and not host.has_meta("centre"):
		# a discovery: the systems that read `world_poi` (world events, the far light signatures) want a centre and a radius
		var bb := AABB()
		var got := false
		for ch2 in host.get_children():
			var m2 := ch2 as MeshInstance3D
			if m2 != null and String(m2.name).begins_with("Mesh_"):
				bb = m2.get_aabb() if not got else bb.merge(m2.get_aabb())
				got = true
		if got:
			host.set_meta("centre", bb.get_center())
			host.set_meta("radius", clampf(bb.size.length() * 0.35, 8.0, 40.0))
	if range_end > 0.0:
		for ch in host.get_children():
			if ch is MeshInstance3D or ch is MultiMeshInstance3D:
				var gi := ch as GeometryInstance3D
				gi.visibility_range_end = range_end
				gi.visibility_range_end_margin = range_end * 0.1
				gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return n


static var _wmat: StandardMaterial3D


static func _water_mat() -> StandardMaterial3D:
	if _wmat == null:
		_wmat = StandardMaterial3D.new()
		_wmat.albedo_color = Color(0.05, 0.13, 0.17, 0.72)
		_wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_wmat.roughness = 0.04
		_wmat.metallic = 0.2
		_wmat.emission_enabled = true
		_wmat.emission = Color(0.02, 0.06, 0.08)
		_wmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _wmat


# --- the geometry cache ---------------------------------------------------------------------------------
# A landmark's boxes are pure GDScript (about 70 microseconds each) and deterministic for a place and a seed, so the finished
# kit is saved once (GenCache, under the generator's own salt) and restored on every later build: the builder skips its
# geometry (`if not k.cached(key): ...`) and the kit, its recorded flames, lights, chests and water planes come back in
# milliseconds. The key names the builder's own source (so an edit rebuilds), the shared builders' sources and the placement.

const KIT_PATH := "res://core/world/realm/wonders/r39/wonder_kit.gd"
const GenCache := preload("res://core/world/realm/gen_cache.gd")


## A signature of the ground round `c` (49 heights, 5 cm): part of a kit's cache key, so a changed terrain rebuilds it.
static func tsig(c: Vector2, r: float) -> String:
	var a := PackedFloat32Array()
	for i in range(-3, 4):
		for j in range(-3, 4):
			a.append(snappedf(h(c.x + r * float(i) / 3.0, c.y + r * float(j) / 3.0), 0.05))
	return str(a).md5_text()


## The cache key for a builder: its script path, the placement it was given (anything that changes the picture) and the sources.
static func fp(builder: String, params: Variant) -> String:
	var sal := "%d_%d_%d_%d" % [GenCache.salt(builder), GenCache.salt(KIT_PATH), GenCache.salt("res://world/areas/ossuary/oss_kit.gd"), GenCache.salt("res://core/world/realm/wonders/r39/wonder_dress.gd")]
	return "wk|%s|%s|%s" % [builder.get_file().get_basename(), sal, str(params).md5_text()]


## True when the kit's geometry (and its recorded flames, lights, chests, water) came back from the cache: the builder then
## skips building it. When false the kit is saved at commit under `key`.
func cached(key: String) -> bool:
	_key = key
	var v: Variant = GenCache.load_var(key, KIT_PATH)
	if not (v is Dictionary):
		return false
	var d: Dictionary = v
	for k2: String in (d.st as Dictionary):
		var st := SurfaceTool.new()
		st.create_from_arrays((d.st as Dictionary)[k2] as Array, Mesh.PRIMITIVE_TRIANGLES)
		kit._st[k2] = st
	kit.col_faces = d.col
	kit.solids = d.solids
	kit.candles = d.candles
	kit.skulls = d.skulls
	kit.bones = d.bones
	kit.puddles.assign(d.puddles)
	_fl.assign(d.fl)
	_hl = d.hl
	_lrec = d.lrec
	_crec = d.crec
	_wrec = d.wrec
	fires = int(d.fires)
	_loaded = true
	return true


func _save() -> void:
	var st := {}
	for k2: String in kit._st:
		st[k2] = (kit._st[k2] as SurfaceTool).commit_to_arrays()
	GenCache.save_var(_key, KIT_PATH, {"st": st, "col": kit.col_faces, "solids": kit.solids, "candles": kit.candles, "skulls": kit.skulls,
		"bones": kit.bones, "puddles": kit.puddles, "fl": _fl, "hl": _hl, "lrec": _lrec, "crec": _crec, "wrec": _wrec, "fires": fires})
