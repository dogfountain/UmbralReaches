extends RefCounted
## The shared hand of the the world pass landmarks (docs/the world pass/world_landmarks.md). Every big set piece of the world pass (the
## Sleeper, the Hollow King, the Salt Ship, the Wardens' Line, the Chain Span, the Titan Gates, the Hermit Caches)
## builds through one of these: an OssKit (one mesh per material, collision from the same faces, occluders) plus the
## things a landmark needs that the kit does not give: a free-ground finder, tubes and beams at any angle, fire (a
## flame card, a halo and one small unshadowed light with a distance fade), lit window glass, a chest and the
## discovery banner. Everything is built once, at Realm build time (the wonders stage runs before the terrain stamp,
## the flora, the dress and the nav bake, so the flora keeps off every site reserved here, the ground settles to the
## floors and the nav meshes include them). Nothing runs per frame. No class_name: load by path.
##   const WK := preload("res://core/world/realm/wonders/the world pass/wonder_kit.gd")

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


func setup(root: Node, nm: String, seed_n: int) -> void:
	rng.seed = seed_n
	kit.keep_lanes = false
	kit.candle_lights = false
	kit.relief = true
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
	for st: Dictionary in WorldLanes.sites:
		if WorldLanes.site_hits_rect(st, box, margin):
			return true
	var ex := Vector2(cos(yaw), sin(yaw))
	var ez := Vector2(-sin(yaw), cos(yaw))
	for i in range(-2, 3):
		for j in range(-2, 3):
			var p := c + ex * (half.x * float(i) / 2.0) + ez * (half.y * float(j) / 2.0)
			if RealmLayout.path_dist(p) < margin * 0.5 + 3.0:
				return true
	return false


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
func fire(at: Vector3, s := 1.0, energy := 2.2, light := true) -> Array[Node3D]:
	var made: Array[Node3D] = []
	if _fire_mesh == null:
		_fire_mesh = QuadMesh.new()
		_fire_mesh.size = Vector2(0.075, 0.17)
	for i in 2:
		var mi := MeshInstance3D.new()
		mi.name = "Flame"
		mi.mesh = _fire_mesh
		mi.material_override = OssKit.mat("flame")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		host.add_child(mi)
		made.append(mi)
		mi.position = at + Vector3(0.18 * s * (float(i) - 0.5), 0.5 * s, 0.12 * s * (0.5 - float(i)))
		mi.scale = Vector3(7.0, 6.0 + float(i), 7.0) * s
	var hm := MeshInstance3D.new()
	hm.name = "FireHalo"
	var hq := QuadMesh.new()
	hq.size = Vector2(5.0, 5.0) * s
	hm.mesh = hq
	hm.material_override = OssKit.mat("halo")
	hm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(hm)
	made.append(hm)
	hm.position = at + Vector3.UP * (0.55 * s)
	fires += 1
	if not light:
		return made
	var l := OmniLight3D.new()
	l.name = "FireLight"
	l.light_color = FIRE_COL
	l.light_energy = energy
	l.omni_range = 9.0 + 5.0 * s
	l.omni_attenuation = 1.3
	l.light_specular = 0.3
	l.light_volumetric_fog_energy = 0.0
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 70.0
	l.distance_fade_length = 24.0
	l.set_meta(&"light_class", &"lamp")
	l.set_meta(&"base", {"e": energy, "r": l.omni_range, "a": 1.3})
	host.add_child(l)
	made.append(l)
	l.position = at + Vector3.UP * (1.2 * s)
	lights += 1
	return made


## A small lantern light with no flame card (a lit window's spill, a hung lamp). Fades out past 45 m.
func lamp(at: Vector3, col := Color(1.0, 0.7, 0.4), energy := 1.0, rng_m := 6.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = "LampLight"
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng_m
	l.omni_attenuation = 1.4
	l.light_specular = 0.2
	l.light_volumetric_fog_energy = 0.0
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 38.0
	l.distance_fade_length = 14.0
	l.set_meta(&"light_class", &"lamp")
	l.set_meta(&"base", {"e": energy, "r": rng_m, "a": 1.4})
	host.add_child(l)
	l.position = at
	lights += 1
	return l


## A chest that opens once per save (loot_chest.gd): `id` is its save key, `tier` wood / iron / reliquary.
func chest(id: String, tier: String, at: Vector3, yaw: float, loot: Dictionary) -> Node3D:
	var c: Node3D = Chest.new()
	c.name = "Chest_" + id
	c.set("chest_id", id)
	c.set("tier", tier)
	c.set("loot", loot.duplicate())
	host.add_child(c)
	c.global_transform = Transform3D(Basis(Vector3.UP, yaw), at)
	chests += 1
	return c


## A far beacon over the landmark (the generic system: a pale shaft and a glow; `reach` 0 = the system's own).
func beacon(at: Vector3, col: Color, radius := 1.0, ceiling := 9.0, reach := 0.0) -> Node3D:
	return Wayfinding.beacon(host, at, "", col, 0.0, radius, ceiling, true, reach)


## Commit the kit's meshes under the host. `range_end` > 0 gives every mesh of the host (and its flame cards) a dither-faded
## visibility range of that many metres: the small places (caches, towers) vanish like the wayside's props do; the
## colossal landmarks pass 0 and are never culled by range.
func commit(range_end := 0.0) -> int:
	var n := kit.commit(host, host.name + "Body")
	if range_end > 0.0:
		for ch in host.get_children():
			if ch is MeshInstance3D or ch is MultiMeshInstance3D:
				var gi := ch as GeometryInstance3D
				gi.visibility_range_end = range_end
				gi.visibility_range_end_margin = range_end * 0.1
				gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return n
