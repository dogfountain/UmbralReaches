extends RefCounted
## THE HERMIT CACHES (the world pass: reasons to leave the road): sixteen small places, 45-130 m off every way, each marked
## by a pole 7 m tall with a lit lantern at its head (a warm star over the heath that nobody put on a map) and
## holding a chest. Three kinds, rotated round the Realm:
##   - the lean-to camp: a plank shelter against a stone, a bedroll, a cold hearth ring with a small fire, a chest
##   - the cell: a four-walled stone cell with a door and a slit window lit from within, an altar slab, a chest
##   - the stone ring: five menhirs round a fire with a capstone table, a chest under it
## Chests are iron tier (they roll gear) and hold ash, iron and now and then a relic fragment: worth the walk.
## Each place is its own kit (it culls on its own; its meshes fade out at 200 m), reserves its ground and is a
## discovery (world_poi). Found by sampling open, flat, dry ground that touches no way, town or site (WK.taken).

const WK := preload("res://core/world/realm/wonders/r39/wonder_kit.gd")
const Dress := preload("res://core/world/realm/wonders/r39/wonder_dress.gd")
const COUNT := 16
const SELF := "res://core/world/realm/wonders/r39/hermit_caches.gd"

static var _ids: Array = []


static func build(root: Node) -> void:
	var w := new()
	w._run(root)


func _run(root: Node) -> void:
	var cands := WK.grid(9100, 24.0, 20.0)
	var t := {}
	var placed := 0
	var tried := 0
	for c: Vector2 in cands:
		if placed >= COUNT:
			break
		tried += 1
		if not _ok(c, t):
			continue
		var sp := WK.span(c, Vector2(7.0, 7.0), 0.0)
		if sp.x == INF:
			WK.rej(t, "span")
			continue
		WorldLanes.register_terrace("wonder_hermit_%d" % placed, c, 8.0, (sp.x + sp.y) * 0.5)
		_cache(root, placed, c, (sp.x + sp.y) * 0.5)
		_placed_pts.append(c)
		placed += 1
	print("WONDER hermit_caches: %d of %d placed (%d of %d candidates tried); rejected: %s" % [placed, COUNT, tried, cands.size(), WK.rejected(t)])


## Cheap clearance: in the Realm, 40 m or more from the nearest way, 60 m from another cache, clear of every site.
func _ok(c: Vector2, t: Dictionary) -> bool:
	if WK.in_town(c, 20.0):
		return WK.rej(t, "town")
	if RealmLayout.path_dist(c) < 40.0:
		return WK.rej(t, "way")
	for q: Vector2 in _placed_pts:
		if q.distance_to(c) < 60.0:
			return WK.rej(t, "spacing")
	if WK.region_at(c) in ["hearth", "summit", "rift", "ossuary", "henge"]:
		return WK.rej(t, "region")
	if WK.site_hit(Rect2(c - Vector2(9.0, 9.0), Vector2(18.0, 18.0)), 2.0):
		return WK.rej(t, "site")
	return true


var _placed_pts: Array[Vector2] = []


func _cache(root: Node, i: int, p: Vector2, level: float) -> void:
	var k := WK.new()
	k.setup(root, "HermitCache%d" % i, 9100 + i)
	var reg := WK.region_at(p)
	k.poi("hermit_cache_%d" % i, "A Hermit's Place", "a lantern on a pole, a long way from any road", reg if reg != "" else "road")
	var g := level
	var lo := level - 1.0
	var yaw := float((i * 2654435761) % 628) / 100.0
	var b := Basis(Vector3.UP, yaw)
	var c := Vector3(p.x, g, p.y)
	var kind := i % 3
	if not k.cached(WK.fp(SELF, [c, i, level, WK.tsig(p, 7.0)])):
		# the footing: a stone pad under everything
		k.kit.box("stone", Vector3(c.x, (lo - 0.8 + g + 0.12) * 0.5, c.z), Vector3(9.0, g + 0.12 - (lo - 0.8), 9.0), b, true, 0.86)
		var rx := b * Vector3(1.0, 0.0, 0.0)
		var rz := b * Vector3(0.0, 0.0, 1.0)
		# the pole and its lantern: the hook
		var pole := c + rx * 3.4 - rz * 3.2
		k.tube("wood_big", pole, pole + Vector3.UP * 7.2, 0.2, 0.14, 6, true, 0.7)
		k.beam("wood_big", pole + Vector3.UP * 6.9, pole + Vector3.UP * 6.9 + rx * -1.1, 0.12, 0.12, false, 0.7)
		k.kit.box("iron", pole + rx * -1.1 + Vector3.UP * 6.7, Vector3(0.04, 0.3, 0.04), Basis.IDENTITY, false, 0.6)
		k.kit.box("glow", pole + rx * -1.1 + Vector3.UP * 6.35, Vector3(0.36, 0.5, 0.36), b, false, 1.0)
		k.lamp(pole + rx * -1.1 + Vector3.UP * 6.3, Color(1.0, 0.68, 0.38), 1.6, 12.0)
		var loot := {"grave_ash": 10 + i, "grave_iron": 1 + (i % 2)}
		if i % 4 == 3:
			loot["relic_fragment"] = 1
		match kind:
			0:
				# lean-to: a pitched shed of planks against the back, a bedroll, a hearth ring with a fire
				k.kit.box("wood_big", c + rz * -2.4 + Vector3.UP * 1.0, Vector3(5.0, 2.2, 0.25), b, true, 0.92)
				for s: float in [-1.0, 1.0]:
					k.kit.box("wood_big", c + rz * -1.2 + rx * (s * 2.4) + Vector3.UP * 0.9, Vector3(0.25, 1.8, 2.4), b, true, 0.92)
				k.kit.box("wood_big", c + rz * -1.2 + Vector3.UP * 2.1, Vector3(5.4, 0.2, 3.2), Basis(rx, 0.28) * b, true, 0.86)
				k.kit.box("wood_big", c + rz * -1.0 + rx * -0.9 + Vector3.UP * 0.2, Vector3(1.4, 0.2, 2.4), b, false, 0.78)
				for q in 8:
					var a := TAU * float(q) / 8.0
					k.kit.box("stone", c + rz * 1.6 + Vector3(cos(a) * 0.9, 0.12, sin(a) * 0.9), Vector3(0.4, 0.3, 0.34), Basis(Vector3.UP, a), false, 0.82)
				k.fire(c + rz * 1.6 + Vector3.UP * 0.2, 0.7, 1.6)
				k.chest("hermit_%d" % i, "iron", c + rz * -1.6 + rx * 1.4 + Vector3.UP * 0.12, yaw, loot)
			1:
				# the cell: four walls (the south one with a door gap), a roof slab, a lit slit, an altar, a chest
				k.kit.box("brick_big", c + rz * -2.2 + Vector3.UP * 1.5, Vector3(4.6, 3.0, 0.5), b, true, 0.96)
				for s: float in [-1.0, 1.0]:
					k.kit.box("brick_big", c + rx * (s * 2.05) + Vector3.UP * 1.5, Vector3(0.5, 3.0, 4.4), b, true, 0.96)
					k.kit.box("brick_big", c + rz * 2.2 + rx * (s * 1.5) + Vector3.UP * 1.5, Vector3(1.6, 3.0, 0.5), b, true, 0.96)
				k.kit.box("brick_big", c + rz * 2.2 + Vector3.UP * 2.7, Vector3(1.6, 0.7, 0.5), b, true, 0.94)
				k.kit.box("stone_big", c + Vector3.UP * 3.2, Vector3(5.2, 0.5, 5.0), b, true, 0.9)
				k.window(c + rz * -1.94 + Vector3.UP * 1.3, rx, rz, 0.5, 1.2)
				k.kit.box("stone_big", c + rz * -1.2 + Vector3.UP * 0.45, Vector3(1.8, 0.9, 0.9), b, true, 0.94)
				k.lamp(c + Vector3.UP * 1.8, Color(1.0, 0.66, 0.36), 1.2, 7.0)
				k.kit.candle_cluster(c + rz * -1.2 + Vector3.UP * 0.9, 4, 0.2, k.rng)
				k.chest("hermit_%d" % i, "iron", c + rx * 1.2 + rz * -0.6 + Vector3.UP * 0.12, yaw + PI * 0.5, loot)
			_:
				# the ring: five menhirs, a fire, a capstone table, a chest beneath
				for q in 5:
					var a := TAU * float(q) / 5.0 + 0.3
					var mp := c + Vector3(cos(a) * 3.0, 0.0, sin(a) * 3.0)
					k.kit.box("stone_big", mp + Vector3.UP * 2.0, Vector3(1.0, 4.0 + 0.5 * float(q % 3), 0.8), Basis(Vector3.UP, a + PI * 0.5) * Basis(Vector3.RIGHT, 0.05 * float(q - 2)), true, 0.92)
				k.kit.box("stone_big", c + rx * 0.0 + Vector3.UP * 0.45, Vector3(2.6, 0.9, 2.6), b, true, 0.9)
				k.fire(c + Vector3.UP * 1.0, 0.9, 1.8)
				k.chest("hermit_%d" % i, "iron", c + rx * 4.5 + Vector3.UP * 0.12, yaw, loot)
		# secondary forms: stores, rope, rubble, a bedroll or cairn, strands on the pole
		Dress.rubble(k, c + rx * -3.2 + rz * 2.8, 2.4, 9, "stone")
		Dress.barrel(k, c + rx * -3.4 + rz * -2.6, yaw, 0.95)
		Dress.crate(k, c + rx * 3.0 + rz * 3.0, yaw + 0.5, 0.75)
		Dress.rope(k, pole + Vector3.UP * 5.0, c + rx * 0.5 + rz * -2.4 + Vector3.UP * 2.2, 0.7, 0.05)
		Dress.strands(k, pole + Vector3.UP * 6.8, pole + Vector3.UP * 6.8 + rx * -1.1, 3, 1.2)
		if kind != 0:
			Dress.camp(k, c + rx * 2.2 + rz * 4.2, yaw, false)
	k.commit(150.0)
