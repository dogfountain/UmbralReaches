extends RefCounted
## REGION SIGNATURES (the world pass: "no two regions look alike"): each Far Reaches region gets its own set of props,
## scattered over its open ground, so a walk from the Greyfell to the Reedmere to the Cairns passes three different worlds.
##   greyfell     ballistae, helmet cairns, shield-banner poles, broken pikes standing in rows
##   lanternwood  tall lantern poles (cold glass), fungus rings of glowing caps, hung lantern strings between poles
##   kingsbarrows grave mounds each with a lantern, carved standing stones, wreath-hung stakes
##   reedmere     fish-drying racks, eel baskets, half-sunk boat hulls, reed fences
##   fallow       haystacks, scarecrows, ploughs, water troughs
##   arches       fallen arch stones, aqueduct pipes, sluice wheels
##   southwood    charcoal clamps, bark racks, snares of rope and stakes, woodcutters' stacks
##   bellfall     cracked bell halves half-buried, scorched posts, shattered bell-metal
##   lastlight    lamp-posts, signal poles, notice boards
##   nave         drowned column stubs, leaning pillars, pew rows, lit glass shards
##   cairns       cairn stacks, wind-flag poles, windbreaks
## Props are small and many, so they are built per 96 m cell: one kit (a handful of meshes) per cell with props, faded at
## 140 m, flame-free (glass and glow cards only, a lantern pole's one lamp counts against the light cap). Placement:
## flat, dry, unclaimed ground (WK.span / WK.taken), 9 m off every way, 4-40 props per region by area. Build-time only.
## No class_name.

const SELF := "res://core/world/realm/wonders/r39/region_dressing.gd"
const WK := preload("res://core/world/realm/wonders/r39/wonder_kit.gd")
const Dress := preload("res://core/world/realm/wonders/r39/wonder_dress.gd")

const KINDS := {
	"greyfell": ["ballista", "helmet_cairn", "shield_pole", "pikes"],
	"lanternwood": ["lantern_pole", "fungus_ring", "lantern_pole", "string_poles"],
	"kingsbarrows": ["grave_mound", "carved_stone", "grave_mound", "wreath_stake"],
	"reedmere": ["fish_rack", "eel_basket", "boat_hull", "reed_fence"],
	"fallow": ["haystack", "scarecrow", "plough", "trough", "haystack"],
	"arches": ["fallen_arch", "pipe", "sluice_wheel"],
	"southwood": ["charcoal_clamp", "bark_rack", "snare", "wood_stack"],
	"bellfall": ["bell_half", "scorch_post", "bell_half"],
	"lastlight": ["lamp_post", "signal_pole", "notice_board"],
	"nave": ["column_stub", "leaning_pillar", "pews", "glass_shards"],
	"cairns": ["cairn_stack", "wind_flag", "windbreak", "cairn_stack"],
}


static func build(root: Node) -> void:
	var w := new()
	w._run(root)


func _run(root: Node) -> void:
	var ids: Array = []
	for reg: Dictionary in RealmLayout.REGIONS:
		ids.append(String(reg.id))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var total := 0
	for reg: Dictionary in RealmLayout.REGIONS:
		var id := String(reg.id)
		if not KINDS.has(id) or not reg.has("rect"):
			continue
		var r: Rect2 = reg.rect
		var want := clampi(int(r.get_area() / 420.0), 8, 44)
		var kinds: Array = KINDS[id]
		var cells := {}
		var placed := 0
		var tries := 0
		while placed < want and tries < want * 5:
			tries += 1
			var c := Vector2(rng.randf_range(r.position.x + 8.0, r.end.x - 8.0), rng.randf_range(r.position.y + 8.0, r.end.y - 8.0))
			if RealmLayout.path_dist(c) < 9.0 or WK.in_town(c, 4.0):
				continue
			var sp := WK.span(c, Vector2(2.5, 2.5), 0.0)
			if sp.x == INF or sp.y - sp.x > 1.0 or WK.site_hit(Rect2(c - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), 1.0):
				continue
			var key := Vector2i(floori(c.x / 96.0), floori(c.y / 96.0))
			if not cells.has(key):
				cells[key] = []
			(cells[key] as Array).append([c, sp.y, String(kinds[rng.randi() % kinds.size()]), rng.randf() * TAU])
			placed += 1
		for key: Vector2i in cells:
			var k := WK.new()
			k.setup(root, "Sig_%s_%d_%d" % [id, key.x, key.y], 5200 + key.x * 31 + key.y)
			if not k.cached(WK.fp(SELF, [id, key, cells[key]])):
				for it: Array in (cells[key] as Array):
					var c: Vector2 = it[0]
					_prop(k, String(it[2]), Vector3(c.x, float(it[1]), c.y), float(it[3]))
			k.commit(140.0)
		total += placed
	print("WONDER region_dressing: %d signature props" % total)


func _prop(k, kind: String, o: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var rng: RandomNumberGenerator = k.rng
	match kind:
		"ballista":
			k.beam("wood_big", o + b * Vector3(-1.2, 0.0, 0.0), o + b * Vector3(-0.6, 1.4, 0.0), 0.18, 0.18, false, 0.7)
			k.beam("wood_big", o + b * Vector3(1.2, 0.0, 0.0), o + b * Vector3(0.6, 1.4, 0.0), 0.18, 0.18, false, 0.7)
			k.beam("wood_big", o + b * Vector3(0.0, 1.3, -1.6), o + b * Vector3(0.0, 1.5, 1.5), 0.22, 0.22, true, 0.75)
			k.beam("wood_big", o + b * Vector3(-1.6, 1.5, 1.2), o + b * Vector3(1.6, 1.7, 1.2), 0.1, 0.1, false, 0.7)
			Dress.rope(k, o + b * Vector3(-1.6, 1.5, 1.2), o + b * Vector3(1.6, 1.7, 1.2), 0.2, 0.03)
		"helmet_cairn":
			for i in 4:
				k.kit.box("stone_big", o + Vector3.UP * (0.25 + 0.4 * float(i)), Vector3(1.4 - 0.25 * float(i), 0.4, 1.2 - 0.2 * float(i)), Basis(Vector3.UP, yaw + float(i)), true, 0.85)
			for i in 5:
				k.kit.box("iron", o + b * Vector3(rng.randf_range(-1.0, 1.0), 1.7 + 0.1 * float(i % 2), rng.randf_range(-0.7, 0.7)), Vector3(0.34, 0.3, 0.34), Basis(Vector3.UP, rng.randf() * TAU), false, 0.55)
		"shield_pole", "wind_flag":
			k.tube("wood_big", o, o + Vector3.UP * 4.2, 0.1, 0.07, 5, true, 0.7)
			Dress.banner(k, o + Vector3.UP * 4.0, b * Vector3(1.0, 0.0, 0.0), 1.8 if kind == "shield_pole" else 3.2, 1.2 if kind == "shield_pole" else 0.9, b * Vector3(0.0, 0.0, 1.0))
		"pikes":
			for i in 5:
				var p := o + b * Vector3(float(i) * 0.9 - 1.8, 0.0, rng.randf_range(-0.2, 0.2))
				k.tube("wood_big", p, p + Vector3(rng.randf_range(-0.15, 0.15), 3.0 - 0.4 * float(i % 3), 0.0), 0.05, 0.04, 4, false, 0.7)
				k.tube("iron", p + Vector3.UP * 2.6, p + Vector3.UP * 3.0, 0.07, 0.01, 4, false, 0.6)
		"lantern_pole":
			k.tube("wood_big", o, o + Vector3.UP * 5.2, 0.13, 0.1, 5, true, 0.7)
			k.beam("wood_big", o + Vector3.UP * 5.0, o + Vector3.UP * 5.0 + b * Vector3(1.0, 0.0, 0.0), 0.08, 0.08, false, 0.7)
			k.kit.box("glow", o + Vector3.UP * 4.6 + b * Vector3(1.0, 0.0, 0.0), Vector3(0.3, 0.4, 0.3), b, false, 1.0)
			if rng.randf() < 0.3:
				k.lamp(o + Vector3.UP * 4.6 + b * Vector3(1.0, 0.0, 0.0), Color(0.6, 0.82, 1.0), 0.9, 8.0)
		"string_poles":
			var a := o + Vector3.UP * 4.4
			var c2 := o + b * Vector3(7.0, 4.4, 0.0)
			k.tube("wood_big", o, a, 0.1, 0.08, 5, true, 0.7)
			k.tube("wood_big", o + b * Vector3(7.0, 0.0, 0.0), c2, 0.1, 0.08, 5, true, 0.7)
			Dress.rope(k, a, c2, 0.9, 0.03)
			for i in 4:
				var q := a.lerp(c2, (float(i) + 0.5) / 4.0) + Vector3.DOWN * 0.7
				k.kit.box("glow", q, Vector3(0.2, 0.28, 0.2), b, false, 1.0)
		"fungus_ring":
			for i in 9:
				var a2 := TAU * float(i) / 9.0
				var p2 := o + Vector3(cos(a2), 0.0, sin(a2)) * 2.0
				k.tube("chalk", p2, p2 + Vector3.UP * (0.3 + 0.2 * rng.randf()), 0.05, 0.04, 5, false, 0.9)
				k.kit.box("glow", p2 + Vector3.UP * 0.4, Vector3(0.28, 0.1, 0.28), Basis(Vector3.UP, a2), false, 0.85)
		"grave_mound":
			k.kit.box("cave_moss", o + Vector3.UP * 0.25, Vector3(2.8, 0.7, 1.6), b, false, 0.85)
			k.kit.box("stone_big", o + b * Vector3(0.0, 0.8, -0.95), Vector3(0.7, 1.4, 0.2), b * Basis(Vector3.RIGHT, rng.randf_range(-0.1, 0.1)), true, 0.9)
			k.kit.box("glow", o + b * Vector3(0.7, 0.5, -0.95), Vector3(0.14, 0.2, 0.14), b, false, 1.0)
		"carved_stone":
			k.kit.box("stone_big", o + Vector3.UP * 1.6, Vector3(0.9, 3.2, 0.5), b * Basis(Vector3.RIGHT, rng.randf_range(-0.08, 0.08)), true, 0.9)
			Dress.carved_band(k, o + b * Vector3(-0.4, 2.2, -0.27), o + b * Vector3(0.4, 2.2, -0.27), 3, Vector3(0.22, 0.3, 0.1), "ruin_big")
		"wreath_stake":
			k.tube("wood_big", o, o + Vector3.UP * 2.2, 0.06, 0.05, 4, false, 0.7)
			k.tube("cave_moss", o + Vector3.UP * 1.9, o + Vector3.UP * 1.95, 0.4, 0.4, 10, false, 0.9)
		"fish_rack":
			for s: float in [-1.0, 1.0]:
				k.tube("wood_big", o + b * Vector3(s * 1.4, 0.0, 0.0), o + b * Vector3(s * 1.4, 1.8, 0.0), 0.07, 0.07, 4, false, 0.7)
			k.beam("wood_big", o + b * Vector3(-1.4, 1.7, 0.0), o + b * Vector3(1.4, 1.7, 0.0), 0.08, 0.08, false, 0.7)
			Dress.strands(k, o + b * Vector3(-1.2, 1.65, 0.0), o + b * Vector3(1.2, 1.65, 0.0), 7, 0.8, "bone")
		"eel_basket":
			k.tube("wood_big", o, o + Vector3.UP * 0.9, 0.35, 0.18, 7, false, 0.75, Vector2(1.0, -1.0), true)
			Dress.rope(k, o + Vector3.UP * 0.5, o + b * Vector3(1.8, 0.0, 0.0), 0.2, 0.03)
		"boat_hull":
			for i in 5:
				var w := 0.7 - 0.12 * absf(float(i) - 2.0)
				k.kit.box("wood_big", o + b * Vector3(0.0, 0.3 + 0.1 * absf(float(i) - 2.0), float(i) * 0.8 - 1.6), Vector3(w * 2.0, 0.15, 0.75), b, false, 0.7)
				for s: float in [-1.0, 1.0]:
					k.kit.box("wood_big", o + b * Vector3(s * w, 0.55, float(i) * 0.8 - 1.6), Vector3(0.08, 0.55, 0.75), b * Basis(Vector3.FORWARD, s * 0.3), false, 0.65)
		"reed_fence":
			for i in 6:
				var p3 := o + b * Vector3(float(i) * 0.6 - 1.5, 0.0, 0.0)
				k.tube("wood_big", p3, p3 + Vector3.UP * (1.2 + 0.2 * rng.randf()), 0.04, 0.04, 4, false, 0.7)
			k.beam("wood_big", o + b * Vector3(-1.5, 0.5, 0.0), o + b * Vector3(1.5, 0.5, 0.0), 0.05, 0.05, false, 0.7)
			k.beam("wood_big", o + b * Vector3(-1.5, 1.0, 0.0), o + b * Vector3(1.5, 1.0, 0.0), 0.05, 0.05, false, 0.7)
		"haystack":
			k.tube("wood_big", o, o + Vector3.UP * 2.6, 1.6, 0.1, 9, false, 0.95, Vector2(1.0, -1.0), true)
		"scarecrow":
			k.tube("wood_big", o, o + Vector3.UP * 2.4, 0.06, 0.05, 4, true, 0.7)
			k.beam("wood_big", o + b * Vector3(-0.9, 1.8, 0.0), o + b * Vector3(0.9, 1.8, 0.0), 0.06, 0.06, false, 0.7)
			Dress.banner(k, o + b * Vector3(-0.5, 1.75, 0.0), b * Vector3(1.0, 0.0, 0.0), 1.0, 0.9, b * Vector3(0.0, 0.0, 1.0))
			k.kit.box("wood_big", o + Vector3.UP * 2.5, Vector3(0.36, 0.3, 0.36), b, false, 0.6)
			k.kit.box("wood_big", o + Vector3.UP * 2.7, Vector3(0.7, 0.05, 0.7), b, false, 0.55)
		"plough":
			k.beam("wood_big", o + b * Vector3(0.0, 0.5, -1.0), o + b * Vector3(0.0, 0.9, 1.6), 0.12, 0.12, false, 0.7)
			k.beam("iron", o + b * Vector3(0.0, 0.0, -1.0), o + b * Vector3(0.0, 0.5, -0.6), 0.08, 0.08, false, 0.55)
			k.beam("wood_big", o + b * Vector3(-0.1, 0.8, 1.2), o + b * Vector3(-0.5, 1.2, 1.9), 0.06, 0.06, false, 0.7)
		"trough":
			k.kit.box("wood_big", o + Vector3.UP * 0.4, Vector3(2.0, 0.5, 0.7), b, false, 0.75)
			k.kit.box("glow", o + Vector3.UP * 0.62, Vector3(1.7, 0.02, 0.45), b, false, 0.25)
		"fallen_arch":
			for i in 5:
				var a3 := PI * float(i) / 4.0
				k.kit.box("stone_big", o + b * Vector3(cos(a3) * 1.6, 0.3 + sin(a3) * 0.5, float(i % 2) * 0.4), Vector3(0.9, 0.5, 1.0), b * Basis(Vector3.FORWARD, a3 - PI * 0.5), true, 0.85)
		"pipe":
			k.tube("stone_big", o + b * Vector3(-1.6, 0.4, 0.0), o + b * Vector3(1.6, 0.5, 0.0), 0.45, 0.45, 10, true, 0.9)
			k.tube("iron", o + b * Vector3(-1.62, 0.4, 0.0), o + b * Vector3(-1.5, 0.4, 0.0), 0.5, 0.5, 10, false, 0.6)
		"sluice_wheel":
			var wc := o + Vector3.UP * 1.4
			k.tube("wood_big", wc - b * Vector3(0.0, 0.0, 0.15), wc + b * Vector3(0.0, 0.0, 0.15), 1.4, 1.4, 12, false, 0.7, Vector2(1.0, -1.0), true)
			k.kit.box("stone_big", o + Vector3.UP * 0.4, Vector3(0.5, 0.8, 0.5), b, true, 0.85)
		"charcoal_clamp":
			k.kit.box("dark", o + Vector3.UP * 0.5, Vector3(3.0, 1.0, 3.0), b, false, 0.5)
			k.tube("dark", o + Vector3.UP * 0.9, o + Vector3.UP * 1.4, 1.2, 0.6, 8, false, 0.45, Vector2(1.0, -1.0), true)
		"bark_rack":
			for i in 4:
				k.beam("wood_big", o + b * Vector3(-1.2 + 0.8 * float(i), 0.0, 0.0), o + b * Vector3(-1.0 + 0.8 * float(i), 1.9, 0.5), 0.12, 0.06, false, 0.65)
		"snare":
			k.tube("wood_big", o, o + Vector3.UP * 1.4, 0.04, 0.04, 4, false, 0.7)
			Dress.rope(k, o + Vector3.UP * 1.4, o + b * Vector3(1.0, 0.1, 0.0), 0.3, 0.02)
		"wood_stack":
			for i in 3:
				for j in 4 - i:
					k.tube("wood_big", o + b * Vector3(-1.2 + 0.6 * float(j) + 0.3 * float(i), 0.2 + 0.35 * float(i), -0.5), o + b * Vector3(-1.2 + 0.6 * float(j) + 0.3 * float(i), 0.2 + 0.35 * float(i), 0.9), 0.17, 0.17, 6, false, 0.75)
		"bell_half":
			k.tube("iron", o + Vector3.DOWN * 0.3, o + Vector3.UP * 1.3, 1.2, 0.5, 10, false, 0.55, Vector2(0.6, 1.8))
			k.kit.box("iron", o + Vector3(1.4, 0.2, 0.3), Vector3(0.6, 0.4, 0.5), b, false, 0.5)
		"scorch_post":
			k.tube("dark", o, o + Vector3.UP * (1.8 + rng.randf()), 0.14, 0.1, 5, false, 0.4)
		"lamp_post", "signal_pole":
			k.tube("iron", o, o + Vector3.UP * (3.2 if kind == "lamp_post" else 5.0), 0.1, 0.07, 6, true, 0.6)
			k.kit.box("glow", o + Vector3.UP * (3.4 if kind == "lamp_post" else 5.2), Vector3(0.34, 0.42, 0.34), b, false, 1.0)
		"notice_board":
			k.kit.box("wood_big", o + Vector3.UP * 1.5, Vector3(1.6, 1.0, 0.1), b, false, 0.8)
			for s: float in [-1.0, 1.0]:
				k.tube("wood_big", o + b * Vector3(s * 0.7, 0.0, 0.0), o + b * Vector3(s * 0.7, 1.9, 0.0), 0.05, 0.05, 4, false, 0.7)
			k.kit.quad("chalk", o + b * Vector3(-0.5, 1.2, -0.06), o + b * Vector3(-0.1, 1.2, -0.06), o + b * Vector3(-0.1, 1.8, -0.06), o + b * Vector3(-0.5, 1.8, -0.06), b * Vector3(0.0, 0.0, -1.0), false, 0.9)
		"column_stub":
			k.tube("chalk", o + Vector3.DOWN * 0.2, o + Vector3.UP * (1.2 + 1.6 * rng.randf()), 0.6, 0.55, 8, true, 0.9)
			Dress.rubble(k, o + b * Vector3(1.4, 0.0, 0.5), 1.0, 5, "chalk")
		"leaning_pillar":
			k.tube("chalk", o, o + b * Vector3(1.8, 3.6, 0.0), 0.55, 0.5, 8, true, 0.9)
		"pews":
			for i in 4:
				k.kit.box("wood_big", o + b * Vector3(0.0, 0.4, float(i) * 1.0 - 1.5), Vector3(2.6, 0.7, 0.4), b, false, 0.6)
		"glass_shards":
			for i in 6:
				var gp := o + b * Vector3(rng.randf_range(-1.0, 1.0), 0.05, rng.randf_range(-1.0, 1.0))
				k.kit.quad("glow", gp, gp + b * Vector3(0.4, 0.0, 0.1), gp + b * Vector3(0.3, 0.0, 0.5), gp + b * Vector3(0.0, 0.0, 0.3), Vector3.UP, false, 0.5)
		"cairn_stack":
			for i in 5:
				k.kit.box("stone_big", o + Vector3.UP * (0.2 + 0.36 * float(i)), Vector3(1.3 - 0.22 * float(i), 0.36, 1.1 - 0.18 * float(i)), Basis(Vector3.UP, yaw + float(i) * 0.7), true, 0.82 + 0.03 * float(i))
		"windbreak":
			for i in 5:
				k.kit.box("stone_big", o + b * Vector3(float(i) * 0.9 - 1.8, 0.5, 0.2 * sin(float(i))), Vector3(0.9, 1.0 + 0.2 * float(i % 2), 0.5), b * Basis(Vector3.UP, 0.15 * float(i)), true, 0.8)
		_:
			Dress.rubble(k, o, 1.2, 6, "stone_big")
