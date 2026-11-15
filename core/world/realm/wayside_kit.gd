extends RefCounted
## The wayside's kinds of place (realm_wayside.gd plans them, wayside_themes.gd says which go where): each kind first
## lays itself out as data (layout: pieces in the place's own frame, local -z facing the way it is read from), so the
## planner can register the ground each solid piece stands on before the flora grows, and the same pieces are built
## after the flora (build) with the lore kit's walls, carts, graves and stones, the in-house prop models
## (art/models/props) and the site props' clutter. Nothing here lights itself: a camp's fire is cold, a lamp unlit.
## Load by path: const Kit := preload("res://core/world/realm/wayside_kit.gd")

const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const Props := preload("res://core/world/realm/site_props.gd")
const RockKit := preload("res://core/world/realm/rock_kit.gd")
const PropModels := preload("res://core/world/realm/prop_models.gd")
const Chest := preload("res://core/world/realm/loot_chest.gd")

const CLUTTER_RANGE := 70.0          ## the site props' clutter (barrels, sacks, bones) fades out past this
const HEADSTONES := ["lore_headstone_round.glb", "lore_headstone_cross.glb", "lore_headstone_slab.glb", "lore_headstone_broken.glb"]


# --- layout -------------------------------------------------------------------------------------

## The pieces of a place of `kind` (each a Dictionary with "t", its type, and local points), drawn from `rng`.
static func layout(kind: String, rng: RandomNumberGenerator) -> Array:
	match kind:
		"wall": return _l_wall(rng)
		"fold": return _l_fold(rng)
		"cottage": return _l_cottage(rng)
		"shrine": return _l_shrine(rng)
		"stones": return _l_stones(rng)
		"circle": return _l_circle(rng)
		"cairns": return _l_cairns(rng)
		"cart": return _l_cart(rng)
		"camp": return _l_camp(rng)
		"well": return _l_well(rng)
		"graves": return _l_graves(rng)
		"woodpile": return _l_woodpile(rng)
		"statue": return _l_statue(rng)
		"blocks": return _l_blocks(rng)
		"lookout": return _l_lookout(rng)
		"battle": return _l_battle(rng)
		"debris": return _l_debris(rng)
		"barrow": return _l_barrow(rng)
		"charcoal": return _l_charcoal(rng)
		"farm": return _l_farm(rng)
		"milestone": return _l_milestone(rng)
		"jetty": return _l_jetty(rng)
		"bones": return _l_bones(rng)
	return []


static func _v(x: float, z: float) -> Vector2:
	return Vector2(x, z)


static func _l_wall(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var a := _v(rng.randf_range(-6.0, -4.5), rng.randf_range(-1.0, 1.0))
	var m := _v(rng.randf_range(-0.5, 1.5), rng.randf_range(-1.6, 1.6))
	var b := _v(rng.randf_range(4.5, 6.0), rng.randf_range(-1.5, 1.5))
	var h := rng.randf_range(0.75, 1.35)
	var ruin := rng.randf_range(0.35, 0.7)
	var gap := rng.randf_range(0.3, 0.7)
	var g0 := a.lerp(m, gap - 0.12)
	var g1 := a.lerp(m, gap + 0.12)
	out.append({"t": "wall", "a": a, "b": g0, "h": h, "ruin": ruin})
	out.append({"t": "wall", "a": g1, "b": m, "h": h * rng.randf_range(0.8, 1.1), "ruin": ruin})
	out.append({"t": "wall", "a": m, "b": b, "h": h * rng.randf_range(0.6, 1.0), "ruin": minf(ruin + 0.2, 0.9)})
	if rng.randf() < 0.55:
		out.append({"t": "glb", "f": "wall_pier.glb", "p": a + (a - m).normalized() * 0.6, "yaw": rng.randf() * 0.3, "s": h / 1.6, "col": true})
	out.append({"t": "rubble", "p": b + (b - m).normalized() * 0.8, "r": 1.4, "n": 7})
	if rng.randf() < 0.4:
		out.append({"t": "clutter", "k": "flag2", "p": (g0 + g1) * 0.5 + _v(0.0, 0.3), "yaw": rng.randf() * TAU, "s": 1.0})
	return out


static func _l_fold(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var r := rng.randf_range(3.4, 4.3)
	var n := 10
	var gate := rng.randi_range(-1, 1)                 # the gap near the front (local -z, toward the way)
	var h := rng.randf_range(0.85, 1.2)
	for i in n:
		if i == 7 + gate:
			continue
		var a0 := TAU * float(i) / float(n) + 0.12
		var a1 := TAU * float(i + 1) / float(n) + 0.12
		out.append({"t": "wall", "a": _v(cos(a0) * r, sin(a0) * r), "b": _v(cos(a1) * r, sin(a1) * r), "h": h * rng.randf_range(0.75, 1.05), "ruin": rng.randf_range(0.2, 0.55)})
	if rng.randf() < 0.6:
		out.append({"t": "glb", "f": "trough.glb", "p": _v(rng.randf_range(-1.0, 1.0), rng.randf_range(0.5, 1.5)), "yaw": rng.randf() * TAU, "s": 1.0, "col": true})
	if rng.randf() < 0.5:
		out.append({"t": "clutter", "k": "hay", "p": _v(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.0, 1.0)), "yaw": rng.randf() * TAU, "s": 1.2})
	for i in rng.randi_range(0, 3):
		out.append({"t": "clutter", "k": ["bone", "rib", "skull"][rng.randi() % 3], "p": _v(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0)), "yaw": rng.randf() * TAU, "s": 1.0})
	out.append({"t": "spot", "p": _v(rng.randf_range(-1.6, 1.6), 1.8)})
	return out


static func _l_cottage(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var w := rng.randf_range(2.1, 2.8)                 # half width (x)
	var d := rng.randf_range(2.8, 3.5)                 # half depth (z); the door is in the front wall (-z)
	var hb := rng.randf_range(1.7, 2.5)
	var door := rng.randf_range(-0.6, 0.6)
	# back wall (the gable that stood), the sides, the front with its door gap
	out.append({"t": "wall", "a": _v(-w, d), "b": _v(w, d), "h": hb, "ruin": rng.randf_range(0.15, 0.4)})
	for sx: float in [-1.0, 1.0]:
		var cut := rng.randf_range(0.25, 0.75)
		out.append({"t": "wall", "a": _v(sx * w, d), "b": _v(sx * w, lerpf(d, -d, cut)), "h": hb * rng.randf_range(0.7, 0.95), "ruin": 0.5})
		out.append({"t": "wall", "a": _v(sx * w, lerpf(d, -d, cut)), "b": _v(sx * w, -d), "h": hb * rng.randf_range(0.3, 0.6), "ruin": 0.75})
	out.append({"t": "wall", "a": _v(-w, -d), "b": _v(door - 0.6, -d), "h": hb * rng.randf_range(0.35, 0.7), "ruin": 0.6})
	out.append({"t": "wall", "a": _v(door + 0.6, -d), "b": _v(w, -d), "h": hb * rng.randf_range(0.3, 0.6), "ruin": 0.7})
	# the chimney stood at one gable end
	var cx := -w + 0.55 if rng.randf() < 0.5 else w - 0.55
	out.append({"t": "chimney", "p": _v(cx, d - 0.45), "h": hb + rng.randf_range(0.6, 1.3)})
	out.append({"t": "clutter", "k": "flag", "p": _v(cx * 0.7, d - 1.3), "yaw": 0.0, "s": 1.0})
	# the roof fell in: a beam or two leaning off the walls, slates and rubble on the floor
	for i in rng.randi_range(1, 2):
		var bx := rng.randf_range(-w * 0.6, w * 0.6)
		out.append({"t": "beam", "a": Vector3(bx, hb * 0.85, d - 0.2), "b": Vector3(bx + rng.randf_range(-0.8, 0.8), 0.1, rng.randf_range(-d * 0.6, d * 0.2))})
	out.append({"t": "rubble", "p": _v(rng.randf_range(-w * 0.5, w * 0.5), rng.randf_range(-d * 0.3, d * 0.5)), "r": 1.3, "n": 8})
	out.append({"t": "rubble", "p": _v(w + 0.8, rng.randf_range(-d, d)), "r": 1.0, "n": 5})
	if rng.randf() < 0.6:
		out.append({"t": "glb", "f": "crate_broken.glb", "p": _v(-cx * 0.6, d - 1.0), "yaw": rng.randf() * TAU, "s": 1.0, "col": true})
	if rng.randf() < 0.5:
		out.append({"t": "glb", "f": "barrel_tipped.glb", "p": _v(rng.randf_range(-w + 0.8, w - 0.8), rng.randf_range(-d + 1.0, 0.0)), "yaw": rng.randf() * TAU, "s": 1.0, "col": true})
	for i in 4:
		out.append({"t": "clutter", "k": "leaf", "p": _v(rng.randf_range(-w + 0.4, w - 0.4), rng.randf_range(-d + 0.4, d - 0.4)), "yaw": rng.randf() * TAU, "s": 1.0})
	out.append({"t": "spot", "p": _v(-cx * 0.55, d - 0.9)})
	out.append({"t": "lore", "c": "page", "p": _v(cx * 0.4, d - 1.4)})
	return out


static func _l_shrine(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var style := rng.randi() % 3
	match style:
		0:
			out.append({"t": "glb", "f": "ruin_marker.glb", "p": _v(0.0, 0.6), "yaw": PI, "s": rng.randf_range(1.0, 1.25), "col": true})
		1:
			out.append({"t": "glb", "f": "market_cross.glb", "p": _v(0.0, 0.6), "yaw": rng.randf() * 0.4, "s": rng.randf_range(0.5, 0.6), "col": true})
		2:
			out.append({"t": "saint", "p": _v(0.0, 0.7), "yaw": 0.0, "v": rng.randi_range(1, 3), "plinth": 0.45, "s": 0.8})
	out.append({"t": "clutter", "k": "flag", "p": _v(0.0, -0.5), "yaw": rng.randf_range(-0.2, 0.2), "s": 1.0})
	if rng.randf() < 0.5:
		out.append({"t": "clutter", "k": "flag2", "p": _v(rng.randf_range(-0.8, 0.8), -1.2), "yaw": rng.randf() * TAU, "s": 1.0})
	out.append({"t": "cairn", "p": _v(rng.randf_range(0.7, 1.1), rng.randf_range(-0.3, 0.3)), "h": rng.randf_range(0.35, 0.55)})
	if rng.randf() < 0.5:
		out.append({"t": "cairn", "p": _v(rng.randf_range(-1.1, -0.7), rng.randf_range(-0.2, 0.4)), "h": rng.randf_range(0.25, 0.4)})
	if rng.randf() < 0.35:
		out.append({"t": "glb", "f": "bench.glb", "p": _v(0.0, -1.8), "yaw": 0.0, "s": 1.0, "col": true})
	out.append({"t": "lore", "c": "rune", "p": _v(-1.9, -1.1)})
	return out


static func _l_stones(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var n: int = [1, 2, 3, 3, 4][rng.randi() % 5]
	var lean := rng.randf_range(-0.25, 0.25)
	for i in n:
		var x := (float(i) - float(n - 1) * 0.5) * rng.randf_range(1.4, 2.1)
		out.append({"t": "slab", "p": _v(x, rng.randf_range(-0.4, 0.4)), "h": rng.randf_range(1.7, 3.1) * (1.15 if i == n / 2 else 1.0),
			"w": rng.randf_range(0.7, 1.05), "yaw": rng.randf_range(-0.3, 0.3), "lean": Vector2(rng.randf_range(-0.1, 0.1), lean + rng.randf_range(-0.06, 0.06))})
	if rng.randf() < 0.4:
		out.append({"t": "lying", "p": _v(rng.randf_range(-2.0, 2.0), rng.randf_range(1.2, 2.2)), "len": rng.randf_range(1.8, 2.6), "yaw": rng.randf() * TAU})
	for i in rng.randi_range(2, 4):
		out.append({"t": "boulder", "p": _v(rng.randf_range(-2.4, 2.4), rng.randf_range(-1.6, 1.6)), "s": Vector3(0.5, 0.35, 0.45) * rng.randf_range(0.7, 1.4)})
	out.append({"t": "lore", "c": "rune", "p": _v(-2.8 if rng.randf() < 0.5 else 2.8, -1.3)})
	return out


static func _l_circle(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var n := rng.randi_range(7, 11)
	var r := rng.randf_range(4.6, 5.8)
	var fallen := [rng.randi() % n, rng.randi() % n]
	for i in n:
		var a := TAU * float(i) / float(n) + rng.randf_range(-0.08, 0.08)
		var q := _v(cos(a) * r, sin(a) * r)
		if i in fallen:
			out.append({"t": "lying", "p": q * 1.12, "len": rng.randf_range(1.6, 2.3), "yaw": -a + rng.randf_range(-0.4, 0.4)})
			continue
		out.append({"t": "slab", "p": q, "h": rng.randf_range(1.3, 2.3) * (1.25 if i % 4 == 0 else 1.0), "w": rng.randf_range(0.6, 0.9),
			"yaw": PI * 0.5 - a, "lean": Vector2(rng.randf_range(-0.08, 0.1), rng.randf_range(-0.07, 0.07))})
	out.append({"t": "altar", "p": _v(0.0, 0.0), "yaw": rng.randf() * TAU})
	out.append({"t": "cairn", "p": _v(0.9, 0.4), "h": 0.4})
	out.append({"t": "spot", "p": _v(0.0, -1.0)})
	out.append({"t": "lore", "c": "rune", "p": _v(-1.2, 0.6)})
	return out


static func _l_cairns(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	out.append({"t": "bigcairn", "p": _v(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.4, 0.6)), "h": rng.randf_range(1.3, 2.0)})
	for i in rng.randi_range(4, 10):
		var a := rng.randf() * TAU
		var d := rng.randf_range(1.6, 4.0)
		if rng.randf() < 0.3:
			out.append({"t": "bigcairn", "p": _v(cos(a) * d, sin(a) * d), "h": rng.randf_range(0.7, 1.1)})
		else:
			out.append({"t": "cairn", "p": _v(cos(a) * d, sin(a) * d), "h": rng.randf_range(0.3, 0.75)})
	out.append({"t": "spot", "p": _v(rng.randf_range(-1.2, 1.2), -1.4)})
	return out


static func _l_cart(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var along := PI * 0.5 + rng.randf_range(-0.5, 0.5)          # the cart lies along the way, run off its edge
	out.append({"t": "cart", "p": _v(0.0, 0.3), "yaw": along, "broken": rng.randf() < 0.75, "load": ["", "hay", "sacks"][rng.randi() % 3]})
	var spill := ["sack.glb", "sack_open.glb", "crate.glb", "crate_broken.glb", "barrel.glb", "barrel_tipped.glb"]
	for i in rng.randi_range(2, 4):
		out.append({"t": "glb", "f": spill[rng.randi() % spill.size()], "p": _v(rng.randf_range(-2.2, 2.2), rng.randf_range(0.8, 2.4)), "yaw": rng.randf() * TAU, "s": 1.0, "col": true})
	if rng.randf() < 0.3:
		out.append({"t": "clutter", "k": "skull", "p": _v(rng.randf_range(-1.6, 1.6), rng.randf_range(-0.8, 0.6)), "yaw": rng.randf() * TAU, "s": 1.0})
	out.append({"t": "spot", "p": _v(rng.randf_range(-1.0, 1.0), 1.6)})
	out.append({"t": "lore", "c": "page", "p": _v(0.0, 0.3)})
	return out


static func _l_camp(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	out.append({"t": "firering", "p": _v(0.0, 0.0)})
	out.append({"t": "clutter", "k": "log", "p": _v(rng.randf_range(-0.3, 0.3), -1.5), "yaw": rng.randf_range(-0.3, 0.3), "s": 1.0})
	out.append({"t": "clutter", "k": "log", "p": _v(1.5, rng.randf_range(-0.3, 0.3)), "yaw": PI * 0.5 + rng.randf_range(-0.3, 0.3), "s": 1.0})
	# a lean-to of poles and planks behind the fire, its back to the weather
	var lx := rng.randf_range(-0.8, 0.8)
	out.append({"t": "leanto", "p": _v(lx, 2.6), "yaw": rng.randf_range(-0.25, 0.25)})
	out.append({"t": "bedroll", "p": _v(lx + rng.randf_range(-0.4, 0.4), 2.2), "yaw": PI * 0.5 + rng.randf_range(-0.2, 0.2)})
	var stores := ["sack.glb", "sack_open.glb", "crate.glb", "barrel.glb", "firewood.glb"]
	for i in rng.randi_range(2, 4):
		var a := rng.randf_range(-2.6, 0.4)
		out.append({"t": "glb", "f": stores[rng.randi() % stores.size()], "p": _v(cos(a) * 2.6, sin(a) * 2.6 + 0.4), "yaw": rng.randf() * TAU, "s": 1.0, "col": true})
	out.append({"t": "clutter", "k": "bucket", "p": _v(-1.2, 0.9), "yaw": 0.0, "s": 1.0})
	out.append({"t": "spot", "p": _v(lx - 1.2, 2.5)})
	out.append({"t": "lore", "c": "page", "p": _v(lx + 1.0, 2.3)})
	return out


static func _l_well(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var f := "works_well.glb" if rng.randf() < 0.6 else "hw_well.glb"
	out.append({"t": "glb", "f": f, "p": _v(0.0, 0.4), "yaw": rng.randf_range(-0.3, 0.3), "s": 0.85 if f == "hw_well.glb" else 1.0, "col": true})
	out.append({"t": "glb", "f": "trough.glb", "p": _v(rng.randf_range(1.6, 2.2), -0.8), "yaw": rng.randf_range(-0.4, 0.4), "s": 1.0, "col": true})
	out.append({"t": "clutter", "k": "bucket", "p": _v(-1.4, -0.6), "yaw": rng.randf() * TAU, "s": 1.0})
	for i in 3:
		out.append({"t": "clutter", "k": "flag2" if i % 2 == 0 else "flag", "p": _v(rng.randf_range(-1.2, 1.2), rng.randf_range(-1.8, -1.1)), "yaw": rng.randf() * TAU, "s": 1.0})
	return out


static func _l_graves(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var n := rng.randi_range(3, 7)
	var rank := rng.randf() < 0.6               # in a rank (the Order's way) or scattered as they fell
	for i in n:
		var q := _v((float(i % 4) - 1.5) * 1.3 + rng.randf_range(-0.15, 0.15), 1.0 - float(i >> 2) * 2.2 + rng.randf_range(-0.2, 0.2)) if rank \
			else _v(rng.randf_range(-3.0, 3.0), rng.randf_range(-2.4, 2.4))
		out.append({"t": "headstone", "p": q, "style": rng.randi() % 5, "h": rng.randf_range(0.75, 1.1),
			"tilt": Vector2(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.1, 0.1)), "mound": rng.randf() < 0.35})
	if rng.randf() < 0.55:
		out.append({"t": "fence", "a": _v(-3.6, -2.8), "b": _v(3.6, -2.8), "gaps": 0.4})
	out.append({"t": "lore", "c": "grave", "p": _v(rng.randf_range(-2.0, 2.0), -1.6)})
	return out


static func _l_woodpile(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for i in rng.randi_range(2, 3):
		out.append({"t": "glb", "f": "firewood.glb", "p": _v(-1.6 + float(i) * 1.25, 1.0 + rng.randf_range(-0.2, 0.2)), "yaw": rng.randf_range(-0.2, 0.2), "s": rng.randf_range(0.95, 1.2), "col": true})
	out.append({"t": "block", "p": _v(rng.randf_range(-0.6, 0.6), -0.8), "s": Vector3(0.6, 0.45, 0.6), "k": "lore_beam", "yaw": rng.randf() * TAU})
	out.append({"t": "axe", "p": _v(0.0, -0.8)})
	for i in rng.randi_range(2, 4):
		out.append({"t": "clutter", "k": "log", "p": _v(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.4, -1.6)), "yaw": rng.randf_range(-0.4, 0.4), "s": 1.0})
	out.append({"t": "clutter", "k": "kindling", "p": _v(rng.randf_range(-0.8, 0.8), -1.4), "yaw": rng.randf() * TAU, "s": 1.0})
	out.append({"t": "sawhorse", "p": _v(rng.randf_range(1.4, 2.0), -0.6), "yaw": rng.randf() * TAU})
	out.append({"t": "spot", "p": _v(-1.9, -0.6)})
	return out


static func _l_statue(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	if rng.randf() < 0.55:
		out.append({"t": "saint", "p": _v(0.0, 0.4), "yaw": 0.0, "v": rng.randi_range(1, 3), "plinth": rng.randf_range(0.6, 0.95), "s": rng.randf_range(0.95, 1.25)})
	else:
		out.append({"t": "block", "p": _v(0.9, 0.6), "s": Vector3(1.0, 0.6, 0.9), "k": "lore_tstone", "yaw": rng.randf_range(-0.3, 0.3)})
		out.append({"t": "fallen", "p": _v(-0.6, -0.2), "yaw": rng.randf() * TAU, "v": rng.randi_range(0, 3)})
	out.append({"t": "rubble", "p": _v(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.4, 1.0)), "r": 1.4, "n": 6})
	out.append({"t": "lore", "c": "tablet", "p": _v(1.8, -0.6)})
	return out


static func _l_blocks(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for i in rng.randi_range(4, 8):
		var q := _v(rng.randf_range(-3.6, 3.6), rng.randf_range(-2.6, 2.6))
		var sz := Vector3(rng.randf_range(0.9, 1.6), rng.randf_range(0.5, 0.85), rng.randf_range(0.6, 1.0))
		out.append({"t": "block", "p": q, "s": sz, "k": "lore_tstone", "yaw": rng.randf_range(-0.25, 0.25) + (PI * 0.5 if rng.randf() < 0.3 else 0.0)})
		if rng.randf() < 0.3:
			out.append({"t": "block", "p": q, "s": sz * Vector3(0.8, 0.9, 0.8), "k": "lore_tstone", "yaw": rng.randf_range(-0.3, 0.3), "on": sz.y})
	for i in rng.randi_range(1, 3):
		out.append({"t": "drum", "p": _v(rng.randf_range(-3.0, 3.0), rng.randf_range(-2.0, 2.0)), "r": rng.randf_range(0.45, 0.6), "h": rng.randf_range(0.5, 0.8), "lie": rng.randf() < 0.5, "yaw": rng.randf() * TAU})
	out.append({"t": "glb", "f": "works_quarry.glb", "p": _v(rng.randf_range(-2.0, 2.0), rng.randf_range(2.6, 3.2)), "yaw": rng.randf() * TAU, "s": 1.0, "col": true})
	out.append({"t": "spot", "p": _v(rng.randf_range(-1.0, 1.0), -2.9)})
	return out


static func _l_lookout(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var h := rng.randf_range(3.2, 4.0)
	out.append({"t": "tower", "p": _v(0.0, 0.6), "h": h, "w": 3.2})
	# a stair of fallen blocks up its front and round to the top (rises under the wanderer's step, 0.45 m)
	var steps: Array = []
	var n := int(ceil(h / 0.36))
	for i in n:
		var t := float(i) / float(n - 1)
		var a := lerpf(-PI * 0.95, -PI * 0.25, t)
		steps.append([Vector2(cos(a) * 2.45, 0.6 + sin(a) * 2.45), (float(i) + 1.0) * h / float(n)])
	out.append({"t": "steps", "list": steps})
	# what fell off it: blocks tumbled down the back and sides
	for i in 3:
		var a2 := rng.randf_range(0.1, PI - 0.1) + float(i) * 0.6
		out.append({"t": "rubble", "p": _v(cos(a2) * 3.0, 0.6 + sin(a2) * 3.0), "r": 1.4, "n": 6, "key": "lore_moss"})
	out.append({"t": "block", "p": _v(rng.randf_range(2.6, 3.4), rng.randf_range(1.4, 2.6)), "s": Vector3(0.9, 0.5, 0.6), "k": "lore_moss", "yaw": rng.randf() * TAU})
	out.append({"t": "spot_top", "p": _v(0.4, 0.9)})
	out.append({"t": "perch", "p": _v(0.0, 0.6)})
	return out


static func _l_battle(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	# a broken line of sharpened stakes across the ground they held, leaning out at the enemy
	var sa := rng.randf() * TAU
	var sd := Vector2(cos(sa), sin(sa))
	var so := Vector2(-sd.y, sd.x) * rng.randf_range(1.5, 2.5)
	for i in rng.randi_range(5, 8):
		if rng.randf() < 0.2:
			continue
		var q := so + sd * (float(i) - 3.5) * 0.75 + Vector2(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12))
		out.append({"t": "stake", "p": q, "yaw": atan2(so.x, so.y) + rng.randf_range(-0.15, 0.15), "tilt": rng.randf_range(0.25, 0.6) * (1.0 if rng.randf() < 0.85 else 2.2), "len": rng.randf_range(1.6, 2.3)})
	out.append({"t": "wheel", "p": _v(rng.randf_range(-3.0, 3.0), rng.randf_range(-2.0, 2.0)), "yaw": rng.randf() * TAU})
	for i in rng.randi_range(1, 3):
		out.append({"t": "helm", "p": _v(rng.randf_range(-3.0, 3.0), rng.randf_range(-2.4, 2.4)), "yaw": rng.randf() * TAU})
	for i in rng.randi_range(5, 9):
		out.append({"t": "spear", "p": _v(rng.randf_range(-4.0, 4.0), rng.randf_range(-3.0, 3.0)), "yaw": rng.randf() * TAU, "tilt": rng.randf_range(0.1, 0.5), "len": rng.randf_range(1.6, 2.4)})
	for i in rng.randi_range(2, 4):
		out.append({"t": "shield", "p": _v(rng.randf_range(-3.5, 3.5), rng.randf_range(-2.6, 2.6)), "yaw": rng.randf() * TAU})
	for i in rng.randi_range(2, 4):
		out.append({"t": "clutter", "k": ["bone", "rib", "skull"][rng.randi() % 3], "p": _v(rng.randf_range(-3.6, 3.6), rng.randf_range(-2.6, 2.6)), "yaw": rng.randf() * TAU, "s": 1.0})
	out.append({"t": "banner", "p": _v(rng.randf_range(-1.0, 1.0), 2.4), "h": rng.randf_range(2.6, 3.4)})
	if rng.randf() < 0.6:
		out.append({"t": "cairn", "p": _v(rng.randf_range(-2.0, 2.0), -2.2), "h": 0.55})
	out.append({"t": "spot", "p": _v(rng.randf_range(-2.4, 2.4), 1.6)})
	out.append({"t": "lore", "c": "grave", "p": _v(1.4, -1.4)})
	return out


static func _l_debris(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for i in rng.randi_range(3, 6):
		out.append({"t": "shard", "p": _v(rng.randf_range(-3.6, 3.6), rng.randf_range(-3.0, 3.0)), "yaw": rng.randf() * TAU, "s": rng.randf_range(0.7, 1.6)})
	for i in rng.randi_range(3, 5):
		out.append({"t": "boulder", "p": _v(rng.randf_range(-4.0, 4.0), rng.randf_range(-3.0, 3.0)), "s": Vector3(0.9, 0.55, 0.8) * rng.randf_range(0.6, 1.5), "style": "ash"})
	out.append({"t": "rubble", "p": _v(0.0, 0.0), "r": 3.0, "n": 10, "key": "lore_char"})
	out.append({"t": "spot", "p": _v(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.0, 1.0))})
	return out


static func _l_barrow(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var r := rng.randf_range(3.0, 3.9)
	out.append({"t": "mound", "p": _v(0.0, 0.2), "s": Vector3(r, rng.randf_range(1.1, 1.7), r * rng.randf_range(0.85, 1.05))})
	var n := 12
	for i in n:
		if rng.randf() < 0.25:
			continue
		var a := TAU * float(i) / float(n)
		out.append({"t": "boulder", "p": _v(cos(a) * (r + 0.4), 0.2 + sin(a) * (r + 0.4)), "s": Vector3(0.5, 0.42, 0.45) * rng.randf_range(0.8, 1.2), "style": "mossy"})
	if rng.randf() < 0.55:
		# its door: two jambs and a lintel at the front, a dark mouth behind
		out.append({"t": "door", "p": _v(0.0, -r + 0.3)})
	else:
		out.append({"t": "slab", "p": _v(0.0, -r - 0.6), "h": rng.randf_range(1.4, 2.0), "w": 0.8, "yaw": 0.0, "lean": Vector2(rng.randf_range(-0.1, 0.1), 0.0)})
	out.append({"t": "spot", "p": _v(1.6, -r - 0.8)})
	out.append({"t": "lore", "c": "rune", "p": _v(-1.4, -r - 0.9)})
	return out


static func _l_charcoal(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	out.append({"t": "clamp", "p": _v(0.0, 0.8), "r": rng.randf_range(1.6, 2.1)})
	for i in rng.randi_range(2, 3):
		out.append({"t": "glb", "f": "firewood.glb", "p": _v(-2.8 + float(i) * 1.3, -1.6), "yaw": rng.randf_range(-0.3, 0.3), "s": 1.1, "col": true})
	out.append({"t": "rake", "p": _v(2.4, -0.4), "yaw": rng.randf() * TAU})
	out.append({"t": "clutter", "k": "kindling", "p": _v(2.0, 1.6), "yaw": rng.randf() * TAU, "s": 1.2})
	out.append({"t": "glb", "f": "sack_open.glb", "p": _v(-2.4, 0.4), "yaw": rng.randf() * TAU, "s": 1.0, "col": true})
	out.append({"t": "spot", "p": _v(1.4, -1.8)})
	return out


static func _l_farm(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	# a field's corner: fence or wall along two sides, a gate gap, the season's last rick and the man who kept the crows off
	var w := rng.randf_range(4.5, 5.8)
	if rng.randf() < 0.5:
		out.append({"t": "fence", "a": _v(-w, -2.6), "b": _v(-0.9, -2.6), "gaps": 0.2})
		out.append({"t": "fence", "a": _v(0.9, -2.6), "b": _v(w, -2.6), "gaps": 0.25})
		out.append({"t": "fence", "a": _v(w, -2.6), "b": _v(w, 3.4), "gaps": 0.3})
	else:
		out.append({"t": "wall", "a": _v(-w, -2.6), "b": _v(-0.9, -2.6), "h": 0.9, "ruin": 0.4})
		out.append({"t": "wall", "a": _v(0.9, -2.6), "b": _v(w, -2.6), "h": 0.9, "ruin": 0.45})
		out.append({"t": "wall", "a": _v(w, -2.6), "b": _v(w, 3.4), "h": 0.8, "ruin": 0.5})
	out.append({"t": "rick", "p": _v(rng.randf_range(-2.4, 0.0), rng.randf_range(0.6, 2.0)), "s": rng.randf_range(0.85, 1.2)})
	if rng.randf() < 0.7:
		out.append({"t": "scarecrow", "p": _v(rng.randf_range(1.0, 3.0), rng.randf_range(0.0, 2.4)), "yaw": rng.randf() * TAU})
	if rng.randf() < 0.5:
		out.append({"t": "glb", "f": "barrel.glb", "p": _v(w - 0.7, -1.9), "yaw": 0.0, "s": 1.0, "col": true})
	out.append({"t": "plough", "p": _v(rng.randf_range(-3.6, -2.4), rng.randf_range(-1.4, 0.0)), "yaw": rng.randf() * TAU})
	return out


static func _l_milestone(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	out.append({"t": "lore", "c": "waystone", "p": _v(0.0, 0.0)})
	if rng.randf() < 0.3:
		out.append({"t": "cairn", "p": _v(0.75, 0.5), "h": 0.3})
	return out


static func _l_jetty(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	# the jetty runs out from the shore (local +z is the land, -z the water)
	var length := rng.randf_range(5.5, 8.0)
	out.append({"t": "jetty", "p": _v(0.0, 1.5), "len": length, "w": rng.randf_range(1.3, 1.7)})
	out.append({"t": "trap", "p": _v(rng.randf_range(1.2, 1.8), 1.5 - length * 0.7), "yaw": rng.randf() * TAU})
	if rng.randf() < 0.6:
		out.append({"t": "trap", "p": _v(rng.randf_range(-1.8, -1.2), 1.5 - length * 0.45), "yaw": rng.randf() * TAU})
	out.append({"t": "boat", "p": _v(rng.randf_range(1.8, 2.6), rng.randf_range(1.4, 2.4)), "yaw": rng.randf_range(-0.6, 0.6) + PI * 0.5})
	out.append({"t": "glb", "f": "crate.glb", "p": _v(-0.9, 2.4), "yaw": rng.randf() * TAU, "s": 0.9, "col": true})
	out.append({"t": "spot", "p": _v(0.0, 1.5 - length + 0.8)})
	return out


static func _l_bones(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	# something very big died here: its ribs stand out of the turf like the frame of a boat
	var n := rng.randi_range(5, 8)
	var yaw := rng.randf() * TAU
	for i in n:
		var t := (float(i) - float(n - 1) * 0.5) * 0.85
		for s: float in [-1.0, 1.0]:
			if rng.randf() < 0.18:
				continue
			out.append({"t": "rib", "p": Vector2(t, 0.0).rotated(yaw) + Vector2(0.0, s * 0.5).rotated(yaw), "side": s, "yaw": yaw, "s": rng.randf_range(3.2, 4.2) * (1.0 - absf(t) * 0.08)})
	out.append({"t": "bigskull", "p": Vector2(float(n) * 0.5, 0.0).rotated(yaw) + Vector2(0.9, 0.0).rotated(yaw), "yaw": yaw + rng.randf_range(-0.5, 0.5)})
	return out


# --- footprint ----------------------------------------------------------------------------------

## The solid pieces' ground as world rects (the sites the planner registers): walls along their run in squares,
## props and stones by their size. `xf` maps the place's local xz (as x, z) to the world.
static func footprints(geo: Array, xf: Transform3D) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for e: Dictionary in geo:
		match String(e.t):
			"wall":
				var a := _w(xf, e.a)
				var b := _w(xf, e.b)
				var n := maxi(1, ceili(a.distance_to(b) / 1.3))
				for i in n:
					var c := a.lerp(b, (float(i) + 0.5) / float(n))
					out.append(Rect2(c - Vector2(0.65, 0.65), Vector2(1.3, 1.3)))
			"glb", "saint", "slab", "altar", "bigcairn", "block", "drum", "chimney", "cart", "leanto", "tower", "mound", "door", "clamp", "rick", "jetty", "fallen", "lying", \
					"headstone", "lore", "firering", "bedroll", "sawhorse", "shard", "rib", "bigskull", "scarecrow", "plough", "boat", "stake":
				if e.t == "lore" and e.c != "waystone":
					continue                     # a writing's carrier claims its ground when one is given (realm_wayside.gd _give_lore)
				var c2 := _w(xf, e.p)
				var r := _foot_r(e)
				out.append(Rect2(c2 - Vector2(r, r), Vector2(r, r) * 2.0))
			"steps":
				for st: Array in e.list:
					var c3 := _w(xf, st[0])
					out.append(Rect2(c3 - Vector2(0.55, 0.55), Vector2(1.1, 1.1)))
	return out


static func _foot_r(e: Dictionary) -> float:
	match String(e.t):
		"glb":
			var sz := PropModels.size_of(String(e.f)) * float(e.s)
			return maxf(sz.x, sz.z) * 0.5 + 0.2
		"saint": return 0.75 * float(e.s)
		"slab": return float(e.w) * 0.6
		"altar": return 1.0
		"bigcairn": return float(e.h) * 0.55
		"block": return maxf((e.s as Vector3).x, (e.s as Vector3).z) * 0.6
		"drum": return float(e.r) * (1.6 if bool(e.lie) else 1.1)
		"chimney": return 0.6
		"cart": return 1.8
		"leanto": return 1.6
		"tower": return float(e.w) * 0.55
		"mound": return (e.s as Vector3).x * 0.9
		"door": return 1.1
		"clamp": return float(e.r) + 0.3
		"rick": return 1.2 * float(e.s)
		"jetty": return 1.2
		"fallen": return 1.1
		"lying": return float(e.len) * 0.5
		"headstone": return 0.45
		"lore": return 0.75
		"firering": return 0.95
		"bedroll": return 0.7
		"sawhorse": return 0.9
		"shard": return 1.1 * float(e.s)
		"rib": return 0.45
		"bigskull": return 0.8
		"scarecrow": return 0.45
		"plough": return 1.0
		"boat": return 1.0
		"stake": return 0.3
	return 0.6


static func _w(xf: Transform3D, q: Vector2) -> Vector2:
	var p := xf * Vector3(q.x, 0.0, q.y)
	return Vector2(p.x, p.z)


# --- build --------------------------------------------------------------------------------------

## Build the planned places `vs` under one holder (a cell of the map: one mesh per material for all of them, their
## small clutter one MultiMesh per kind). Returns the holder. Lookouts stand alone (they read from further off).
static func build(parent: Node3D, name: String, vs: Array, space: PhysicsDirectSpaceState3D, body_range: float) -> Node3D:
	var L: RefCounted = LK.begin(parent, name, int((vs[0] as Dictionary).seed))
	var h: Node3D = L.holder
	var clutter := {}                       # site-props key -> [Transform3D]
	for v: Dictionary in vs:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(v.seed) + 7
		L.rng = rng
		var spots: Array[Vector3] = []          # where a box may stand
		for e: Dictionary in v.geo:
			_piece(L, e, v.xf as Transform3D, rng, clutter, spots, v, space)
		if String(v.get("box", "")) != "" and not spots.is_empty():
			var c: Node3D = Chest.new()
			c.name = "Chest_" + String(v.box)
			c.set("chest_id", String(v.box))
			c.set("tier", String(v.get("box_tier", "wood")))
			c.set("loot", (v.get("loot", {"grave_ash": 6}) as Dictionary).duplicate())
			h.add_child(c)
			c.global_transform = Transform3D(Basis(Vector3.UP, float(v.yaw) + rng.randf_range(-0.4, 0.4)), spots[0])
	_commit_clutter(h, clutter)
	L.finish()
	# every mesh fades out by its own range (a cell's holder is 64 m wide: the size rule would draw it to the horizon)
	for n in h.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if gi.visibility_range_end <= 0.0:
			gi.visibility_range_end = body_range
			gi.visibility_range_end_margin = body_range * 0.1
			gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		gi.add_to_group(Groups.CULL_SKIP)
	return h


## Ground point of local q (world, on the ground).
static func _g(L: RefCounted, xf: Transform3D, q: Vector2) -> Vector3:
	var p := xf * Vector3(q.x, 0.0, q.y)
	return L.gv(p.x, p.z)


static func _piece(L: RefCounted, e: Dictionary, xf: Transform3D, rng: RandomNumberGenerator, clutter: Dictionary, spots: Array[Vector3], v: Dictionary, space: PhysicsDirectSpaceState3D) -> void:
	var k: OssKit = L.k
	var b := xf.basis
	var yaw0 := float(v.yaw)
	match String(e.t):
		"wall":
			L.drystone(_g(L, xf, e.a), _g(L, xf, e.b), float(e.h), float(e.ruin), String(e.get("key", "lore_moss")))
		"glb":
			var at := _g(L, xf, e.p)
			var pxf := Transform3D(Basis(Vector3.UP, yaw0 + float(e.yaw)).scaled(Vector3.ONE * float(e.s)), at)
			L.prop(String(e.f), pxf, false)
			if bool(e.col):
				var sz := PropModels.size_of(String(e.f)) * float(e.s)
				LK.col_box(k, at + Vector3.UP * sz.y * 0.5, sz * Vector3(0.85, 1.0, 0.85), pxf.basis.orthonormalized())
		"clutter":
			var cat := _g(L, xf, e.p)
			var key := String(e.k)
			if not clutter.has(key):
				clutter[key] = []
			(clutter[key] as Array).append(Transform3D(Basis(Vector3.UP, yaw0 + float(e.yaw)).scaled(Vector3.ONE * float(e.s)), cat + Vector3.DOWN * 0.02))
		"rubble":
			L.rubble(k, _g(L, xf, e.p), float(e.r), int(e.n), String(e.get("key", "lore_tstone")))
		"chimney":
			var cb := _g(L, xf, e.p)
			var ch := float(e.h)
			var y := cb.y - 0.3
			var lean := rng.randf_range(-0.04, 0.04)
			while y < cb.y + ch:
				var step := rng.randf_range(0.28, 0.4)
				k.box("lore_moss", Vector3(cb.x, y + step * 0.5, cb.z), Vector3(1.0, step, 0.9), b * Basis(Vector3.BACK, lean) * Basis(Vector3.UP, rng.randf_range(-0.06, 0.06)), true, rng.randf_range(0.75, 0.95))
				y += step
		"beam":
			var a3: Vector3 = e.a
			var b3: Vector3 = e.b
			var wa := xf * Vector3(a3.x, 0.0, a3.z)
			var wb := xf * Vector3(b3.x, 0.0, b3.z)
			wa.y = L.g(wa.x, wa.z) + a3.y
			wb.y = L.g(wb.x, wb.z) + b3.y
			var dd := wb - wa
			k.box("lore_beam", (wa + wb) * 0.5, Vector3(0.18, 0.2, dd.length()), Basis.looking_at(dd.normalized(), Vector3.UP), false, 0.65)
		"saint":
			var sat := _g(L, xf, e.p)
			L.saint(sat, yaw0 + float(e.yaw), int(e.v), float(e.plinth), float(e.s))
		"fallen":
			L.fallen_saint(_g(L, xf, e.p), yaw0 + float(e.yaw), int(e.v), rng.randf() < 0.6)
		"slab":
			_slab(L, _g(L, xf, e.p), yaw0 + float(e.yaw), float(e.h), float(e.w), e.lean as Vector2)
		"lying":
			var lat := _g(L, xf, e.p)
			var m: Mesh = RockKit.slab(rng.randi() % 6, LK.UNIT_SLAB, "mossy", 0.3, true)
			var ln := float(e.len)
			var lb := Basis(Vector3.UP, yaw0 + float(e.yaw)) * Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.UP, rng.randf_range(-0.2, 0.2))
			L.rock(m, Transform3D(lb * Basis.from_scale(Vector3(0.7, ln, 0.4) / LK.UNIT_SLAB), lat + Vector3.UP * 0.05), false)
			LK.col_box(k, lat + Vector3.UP * 0.18, Vector3(0.65, ln, 0.4), lb)
		"altar":
			var aat := _g(L, xf, e.p)
			var ab := Basis(Vector3.UP, float(e.yaw))
			k.box("lore_tstone", aat + Vector3.UP * 0.18, Vector3(1.5, 0.55, 0.9), ab * Basis(Vector3.BACK, rng.randf_range(-0.05, 0.05)), true, 0.8)
			L.panel(aat + Vector3.UP * 0.46, Vector3.UP, 0.9, 0.5, LK.LA.C_RUNES, true, ab * Vector3.FORWARD)
		"boulder":
			L.stone(k, _g(L, xf, e.p), e.s as Vector3, "lore_moss" if String(e.get("style", "")) == "mossy" else ("lore_char" if String(e.get("style", "")) == "ash" else "lore_tstone"), (e.s as Vector3).y > 0.45)
		"cairn":
			L.cairn(L.p, _g(L, xf, e.p), float(e.h))
		"bigcairn":
			var bat := _g(L, xf, e.p)
			var bh := float(e.h)
			var cm: Mesh = RockKit.cairn(rng.randi() % 3, Vector3(0.95, 1.25, 0.9), "granite")
			var cb2 := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * (bh / 1.25))
			L.rock(cm, Transform3D(cb2, bat + Vector3.DOWN * 0.08), false)
			LK.col_box(k, bat + Vector3.UP * bh * 0.4, Vector3(0.7, bh * 0.8, 0.7) * (bh / 1.25), cb2.orthonormalized())
		"block":
			var kat := _g(L, xf, e.p)
			var sz2: Vector3 = e.s
			var on := float(e.get("on", 0.0))
			k.box(String(e.k), kat + Vector3.UP * (on + sz2.y * 0.5 - (0.08 if on == 0.0 else 0.0)), sz2, Basis(Vector3.UP, yaw0 + float(e.yaw)) * Basis(Vector3.BACK, rng.randf_range(-0.04, 0.04)), true, rng.randf_range(0.78, 0.95))
		"drum":
			_drum(L, _g(L, xf, e.p), float(e.r), float(e.h), bool(e.lie), yaw0 + float(e.yaw))
		"cart":
			L.cart(_g(L, xf, e.p), yaw0 + float(e.yaw), bool(e.broken), String(e.load))
			var cat2 := _g(L, xf, e.p)
			LK.col_box(k, cat2 + Vector3.UP * 0.5, Vector3(1.4, 1.0, 2.3), Basis(Vector3.UP, yaw0 + float(e.yaw)))
		"fence":
			L.fence(_g(L, xf, e.a), _g(L, xf, e.b), float(e.gaps))
		"headstone":
			var hat := _g(L, xf, e.p)
			L.headstone(hat, 0.0, int(e.style), float(e.h), e.tilt as Vector2, "lore_tstone", bool(e.mound))
		"firering":
			_fire_ring(L, _g(L, xf, e.p), clutter)
		"leanto":
			_leanto(L, _g(L, xf, e.p), yaw0 + float(e.yaw))
		"bedroll":
			var bdat := _g(L, xf, e.p)
			var bcm := CreatureMesh.new(rng.randi())
			bcm.blob(Vector3.ZERO, Vector3(0.36, 0.09, 0.95), Basis.IDENTITY, Color(0.6, 0.5, 0.42), 0.0, 0.3, 0.0, 5, 9)
			LK.organic(L.p, "lore_cloth", bcm.commit(), Transform3D(Basis(Vector3.UP, yaw0 + float(e.yaw)), bdat + Vector3.UP * 0.04))
		"axe":
			var xat := _g(L, xf, e.p) + Vector3.UP * 0.45
			var xb := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, 0.5)
			L.p.box("lore_beam", xat + xb * Vector3(0, 0.32, 0), Vector3(0.05, 0.7, 0.05), xb, false, 0.7)
			L.p.box("iron", xat + xb * Vector3(0.08, 0.02, 0), Vector3(0.2, 0.1, 0.03), xb, false, 0.6)
		"sawhorse":
			var sat2 := _g(L, xf, e.p)
			var sb := Basis(Vector3.UP, float(e.yaw))
			for sx: float in [-0.55, 0.55]:
				for lean2: float in [-0.35, 0.35]:
					L.p.box("lore_beam", sat2 + sb * Vector3(sx, 0.38, 0.0), Vector3(0.06, 0.82, 0.06), sb * Basis(Vector3.RIGHT, lean2), false, 0.7)
			L.p.box("lore_beam", sat2 + sb * Vector3(0, 0.72, 0), Vector3(1.4, 0.09, 0.09), sb, true, 0.75)
			L.p.box("lore_beam", sat2 + sb * Vector3(0.1, 0.84, 0), Vector3(1.9, 0.16, 0.16), sb * Basis(Vector3.UP, 0.15), false, 0.68)
		"tower":
			_tower(L, _g(L, xf, e.p), float(e.h), float(e.w), yaw0, rng)
		"steps":
			for st: Array in e.list:
				var sq: Vector2 = st[0]
				var top: float = st[1]
				var gat := _g(L, xf, sq)
				var base := _g(L, xf, Vector2(0.0, 0.6)).y
				var ytop := base + top
				var hh := ytop - (gat.y - 0.4)
				k.box("lore_tstone", Vector3(gat.x, ytop - hh * 0.5, gat.z), Vector3(1.05, hh, 1.05), Basis(Vector3.UP, yaw0 + rng.randf_range(-0.2, 0.2)), true, rng.randf_range(0.8, 0.95))
		"perch":
			var top3 := _g(L, xf, e.p)
			var tw := float(v.get("tower_top", 3.5))
			var fac := Vector3(-sin(yaw0), 0.0, -cos(yaw0))
			var m := Node3D.new()                            # a glide perch (realm_pois.gd GROUP_GLIDE): the lip faces away from the way
			m.name = "GlidePerch"
			(L.holder as Node3D).add_child(m)
			m.global_position = top3 + Vector3.UP * (tw + 0.1)
			m.add_to_group("glide_perch")
			m.set_meta("facing", -fac)
			m.set_meta("drop", tw)
		"spear":
			var spat := _g(L, xf, e.p)
			var spb := Basis(Vector3.UP, float(e.yaw)) * Basis(Vector3.RIGHT, float(e.tilt))
			var ln2 := float(e.len)
			L.p.box("lore_beam", spat + spb * Vector3(0, ln2 * 0.5 - 0.35, 0), Vector3(0.065, ln2, 0.065), spb, false, 0.6)
			L.p.box("iron", spat + spb * Vector3(0, ln2 - 0.26, 0), Vector3(0.1, 0.36, 0.03), spb, false, 0.55)
		"stake":
			var stat := _g(L, xf, e.p)
			var stb := Basis(Vector3.UP, yaw0 + float(e.yaw)) * Basis(Vector3.RIGHT, -float(e.tilt))
			var sl := float(e.len)
			k.box("lore_beam", stat + stb * Vector3(0, sl * 0.5 - 0.4, 0), Vector3(0.17, sl, 0.17), stb * Basis(Vector3.UP, rng.randf() * 0.8), true, rng.randf_range(0.55, 0.72))
			k.box("lore_beam", stat + stb * Vector3(0, sl - 0.32, 0), Vector3(0.1, 0.32, 0.1), stb * Basis(Vector3.UP, 0.785), false, 0.62)
		"wheel":
			var wat := _g(L, xf, e.p) + Vector3.UP * 0.06
			L._wheel(wat, Basis(Vector3.UP, float(e.yaw)) * Basis(Vector3.BACK, PI * 0.5 + rng.randf_range(-0.12, 0.12)), 0.55)
		"helm":
			var hat2 := _g(L, xf, e.p)
			var hcm := CreatureMesh.new(rng.randi())
			hcm.blob(Vector3.ZERO, Vector3(0.17, 0.13, 0.19), Basis.IDENTITY, Color(0.55, 0.55, 0.58), 0.0, 0.15, 0.0, 5, 9)
			LK.organic(L.p, "iron", hcm.commit(), Transform3D(Basis(Vector3.UP, float(e.yaw)) * Basis(Vector3.RIGHT, rng.randf_range(-0.5, 0.9)), hat2 + Vector3.UP * 0.06))
		"shield":
			var shat := _g(L, xf, e.p)
			var shb := Basis(Vector3.UP, float(e.yaw)) * Basis(Vector3.RIGHT, -PI * 0.5 + rng.randf_range(-0.35, 0.25))
			LK.half_disc(L.p, "lore_beam", Transform3D(shb, shat + Vector3.UP * 0.12), 0.42, -0.0, 0.05, 6, false, 0.7)
			LK.half_disc(L.p, "lore_beam", Transform3D(shb * Basis(Vector3.BACK, PI), shat + Vector3.UP * 0.12), 0.42, 0.0, 0.05, 6, false, 0.66)
			L.p.box("iron", shat + Vector3.UP * 0.16, Vector3(0.14, 0.06, 0.14), shb, false, 0.6)
		"banner":
			var bnat := _g(L, xf, e.p)
			var bh2 := float(e.h)
			var bnb := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, rng.randf_range(-0.18, 0.18))
			L.p.box("lore_beam", bnat + bnb * Vector3(0, bh2 * 0.5 - 0.3, 0), Vector3(0.08, bh2, 0.08), bnb, true, 0.65)
			L.p.box("lore_beam", bnat + bnb * Vector3(0, bh2 - 0.45, 0), Vector3(0.9, 0.06, 0.06), bnb, false, 0.65)
			var rag := CreatureMesh.new(rng.randi())
			rag.blob(Vector3(0, -0.6, 0), Vector3(0.5, 0.7, 0.03), Basis(Vector3.BACK, 0.06), Color(0.42, 0.24, 0.2), 0.0, 0.5, 0.0, 5, 8)
			LK.organic(L.p, "lore_cloth", rag.commit(), Transform3D(bnb, bnat + bnb * Vector3(0, bh2 - 0.48, 0.05)))
		"shard":
			_shard(L, _g(L, xf, e.p), float(e.yaw), float(e.s))
		"mound":
			var mat := _g(L, xf, e.p)
			var ms: Vector3 = e.s
			var mcm := CreatureMesh.new(rng.randi())
			mcm.blob(Vector3.ZERO, ms, Basis.IDENTITY, Color(1, 1, 1), 0.0, 0.18, 0.0, 9, 16)
			LK.organic(k, "lore_earth", mcm.commit(), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), mat + Vector3.DOWN * ms.y * 0.25), true)
		"door":
			var dat := _g(L, xf, e.p)
			var db := Basis(Vector3.UP, yaw0)
			for sx2: float in [-0.65, 0.65]:
				k.box("lore_tstone", dat + db * Vector3(sx2, 0.55, 0.0), Vector3(0.38, 1.5, 0.5), db * Basis(Vector3.BACK, sx2 * -0.06), true, 0.8)
			k.box("lore_tstone", dat + db * Vector3(0, 1.38, 0.05), Vector3(1.9, 0.38, 0.6), db * Basis(Vector3.BACK, rng.randf_range(-0.05, 0.05)), true, 0.82)
			k.box("dark", dat + db * Vector3(0, 0.5, 0.35), Vector3(0.95, 1.3, 0.1), db, false, 0.2)
		"clamp":
			_clamp(L, _g(L, xf, e.p), float(e.r))
		"rake":
			var rat := _g(L, xf, e.p) + Vector3.UP * 0.04
			var rb := Basis(Vector3.UP, float(e.yaw))
			L.p.box("lore_beam", rat + rb * Vector3(0, 0, 0), Vector3(0.04, 0.04, 1.7), rb, false, 0.7)
			L.p.box("lore_beam", rat + rb * Vector3(0, 0.02, 0.85), Vector3(0.6, 0.05, 0.06), rb, false, 0.65)
		"rick":
			var kat2 := _g(L, xf, e.p)
			var rs := float(e.s)
			var rcm := CreatureMesh.new(rng.randi())
			rcm.blob(Vector3(0, 0.9, 0), Vector3(1.05, 1.0, 1.05) * rs, Basis.IDENTITY, Color(1, 1, 1), 0.0, 0.25, 0.0, 7, 12)
			rcm.blob(Vector3(0, 1.75 * rs, 0), Vector3(0.55, 0.55, 0.55) * rs, Basis.IDENTITY, Color(0.9, 0.9, 0.9), 0.0, 0.3, 0.0, 5, 10)
			LK.organic(k, "lore_thatch", rcm.commit(), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), kat2 + Vector3.DOWN * 0.15))
			LK.col_box(k, kat2 + Vector3.UP * 0.9 * rs, Vector3(1.6, 1.8, 1.6) * rs, Basis.IDENTITY)
		"scarecrow":
			L.scarecrow(_g(L, xf, e.p), float(e.yaw))
		"plough":
			var pat := _g(L, xf, e.p) + Vector3.UP * 0.1
			var pb := Basis(Vector3.UP, float(e.yaw)) * Basis(Vector3.BACK, 0.12)
			L.p.box("lore_beam", pat + pb * Vector3(0, 0.2, 0), Vector3(0.12, 0.12, 2.2), pb * Basis(Vector3.RIGHT, -0.18), true, 0.7)
			L.p.box("lore_beam", pat + pb * Vector3(0, 0.55, 0.95), Vector3(0.6, 0.06, 0.06), pb, false, 0.7)
			L.p.box("iron", pat + pb * Vector3(0, -0.02, -0.9), Vector3(0.1, 0.22, 0.4), pb, false, 0.55)
		"jetty":
			_jetty(L, e, xf, yaw0, rng)
		"trap":
			_trap(L, _g(L, xf, e.p), float(e.yaw))
		"boat":
			var bat2 := _g(L, xf, e.p)
			var bcm2 := CreatureMesh.new(rng.randi())
			bcm2.blob(Vector3.ZERO, Vector3(0.65, 0.32, 1.7), Basis.IDENTITY, Color(0.62, 0.52, 0.42), 0.0, 0.12, 0.0, 7, 12)
			LK.organic(k, "wood", bcm2.commit(), Transform3D(Basis(Vector3.UP, yaw0 + float(e.yaw)) * Basis(Vector3.BACK, PI + 0.15), bat2 + Vector3.UP * 0.18), true)
		"rib":
			var rbat := _g(L, xf, e.p)
			var ryaw := yaw0 + float(e.yaw)
			var side := float(e.side)
			var ribm := OssKit.bone_mesh(1)
			var rxb := Basis(Vector3.UP, ryaw + PI * 0.5) * Basis(Vector3.BACK, side * 0.55) * Basis(Vector3.RIGHT, rng.randf_range(-0.1, 0.1))
			k.append_mesh("bone_cm", ribm, Transform3D(rxb.scaled(Vector3.ONE * float(e.s)), rbat + Vector3.DOWN * 0.15))
			LK.col_box(k, rbat + Vector3.UP * 0.6, Vector3(0.18, 1.2, 0.18), rxb.orthonormalized())
		"bigskull":
			var skat := _g(L, xf, e.p)
			k.skull(skat + Vector3.UP * 0.25, yaw0 + float(e.yaw), 3.2, 0, 0.35)
			LK.col_box(k, skat + Vector3.UP * 0.45, Vector3(0.9, 0.8, 1.0), Basis(Vector3.UP, yaw0 + float(e.yaw)))
		"spot":
			spots.append(_g(L, xf, e.p))
		"spot_top":
			var tq := _g(L, xf, e.p)
			spots.append(Vector3(tq.x, _g(L, xf, Vector2(0.0, 0.6)).y + float(v.get("tower_top", 3.5)), tq.z))
		"lore":
			_lore(L, e, xf, v, rng)


## A carrier for the place's writing (v.lore: a wayside_texts id): its kind from the piece.
static func _lore(L: RefCounted, e: Dictionary, xf: Transform3D, v: Dictionary, rng: RandomNumberGenerator) -> void:
	var id := String(v.get("lore", ""))
	var at := _g(L, xf, e.p)
	var face := float(v.yaw)
	match String(e.c):
		"waystone":
			if id == "":
				L.waystone(at, face)
				return
			var fp: Vector3 = L.waystone(at, face)
			L.scrap(id, fp, fp + Basis(Vector3.UP, face) * Vector3(0, 0, 0.25))
		"rune":
			if id == "":
				return
			var fp2: Vector3 = L.rune_stone(at, face, rng.randf_range(1.1, 1.4))
			L.scrap(id, fp2, fp2 + Vector3.UP * 0.3)
		"grave":
			if id == "":
				return
			var fp3: Vector3 = L.headstone(at, 0.0, rng.randi() % 3, rng.randf_range(0.9, 1.1), Vector2(rng.randf_range(-0.06, 0.08), 0.0))
			L.scrap(id, fp3 + Vector3(0, -0.3, -0.6), fp3)
		"notice":
			if id == "":
				return
			var k: OssKit = L.k
			var b := Basis(Vector3.UP, face)
			for sx: float in [-0.55, 0.55]:
				k.box("lore_beam", at + b * Vector3(sx, 0.95, 0), Vector3(0.14, 1.9, 0.14), b, true, 0.7)
			k.box("lore_beam", at + b * Vector3(0, 1.45, -0.05), Vector3(1.3, 0.75, 0.06), b, true, 0.85)
			k.box("lore_beam", at + b * Vector3(0, 1.88, -0.12), Vector3(1.5, 0.1, 0.3), b, false, 0.7)
			var fpn := at + b * Vector3(0, 1.45, -0.09)
			L.page(fpn, b * Vector3(0, 0, -1), 0.1)
			L.scrap(id, fpn + b * Vector3(0, -0.4, -0.7), fpn)
		"tablet":
			if id == "":
				return
			var tb := Basis(Vector3.UP, face) * Basis(Vector3.RIGHT, rng.randf_range(-0.12, 0.02))
			var files := ["lore_tablet_weathered.glb", "lore_tablet_cracked.glb", "lore_tablet_leaning.glb"]
			var fpt: Vector3 = L.prop(files[rng.randi() % files.size()], Transform3D(tb.scaled(Vector3.ONE * rng.randf_range(1.2, 1.5)), at))
			L.letters(fpt, -tb.z, 0.32, 3)
			L.scrap(id, fpt - tb.z * 0.6 + Vector3.DOWN * 0.2, fpt)
		"page":
			if id == "":
				return
			var k2: OssKit = L.k
			var pb := Basis(Vector3.UP, rng.randf() * TAU)
			k2.box("lore_beam", at + Vector3.UP * 0.22, Vector3(0.62, 0.44, 0.5), pb, true, 0.75)
			var top := at + Vector3.UP * 0.45
			L.page(top, Vector3.UP)
			L.scrap(id, top + Vector3.UP * 0.25, top)


static func _slab(L: RefCounted, at: Vector3, yaw: float, h: float, w: float, lean: Vector2) -> void:
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, lean.x) * Basis(Vector3.BACK, lean.y)
	var m: Mesh = RockKit.slab((L.rng as RandomNumberGenerator).randi() % 6, LK.UNIT_SLAB, "mossy" if (L.rng as RandomNumberGenerator).randf() < 0.5 else "granite", 0.3, true)
	var sz := Vector3(w, h, w * 0.42)
	L.rock(m, Transform3D(b * Basis.from_scale(sz / LK.UNIT_SLAB), at + Vector3.DOWN * 0.3), false)
	LK.col_box(L.k, at + b * Vector3(0, h * 0.5 - 0.3, 0), sz * Vector3(0.85, 1.0, 0.85), b)


static func _drum(L: RefCounted, at: Vector3, r: float, h: float, lie: bool, yaw: float) -> void:
	var k: OssKit = L.k
	var n := 10
	var b := Basis(Vector3.UP, yaw)
	if lie:
		b = b * Basis(Vector3.BACK, PI * 0.5)
	var c := at + (Vector3.UP * r * 0.92 if lie else Vector3.UP * (h * 0.5 - 0.05))
	for i in n:
		var a := TAU * float(i) / float(n)
		var o := b * Vector3(cos(a) * r * 0.93, 0, sin(a) * r * 0.93)
		k.box("lore_tstone", c + o, Vector3(r * 0.62, h, r * 0.2), b * Basis(Vector3.UP, -a + PI * 0.5), false, 0.85)
	k.box("lore_tstone", c, Vector3(r * 1.5, h * 0.98, r * 1.5), b, true, 0.82)


static func _fire_ring(L: RefCounted, at: Vector3, clutter: Dictionary) -> void:
	var rng: RandomNumberGenerator = L.rng
	for i in 9:
		var a := TAU * float(i) / 9.0 + rng.randf_range(-0.1, 0.1)
		L.stone(L.p, at + Vector3(cos(a) * 0.62, 0.0, sin(a) * 0.62), Vector3(0.26, 0.18, 0.22) * rng.randf_range(0.85, 1.2), "lore_tstone", false, 0.3)
	if not clutter.has("kindling"):
		clutter["kindling"] = []
	(clutter["kindling"] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at + Vector3.UP * 0.01))
	var ash := CreatureMesh.new(rng.randi())
	ash.blob(Vector3.ZERO, Vector3(0.42, 0.04, 0.42), Basis.IDENTITY, Color(0.3, 0.3, 0.3), 0.0, 0.3, 0.0, 3, 9)
	LK.organic(L.p, "lore_char", ash.commit(), Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.01))


static func _leanto(L: RefCounted, at: Vector3, yaw: float) -> void:
	var k: OssKit = L.k
	var b := Basis(Vector3.UP, yaw)
	for sx: float in [-1.1, 1.1]:
		k.box("lore_beam", at + b * Vector3(sx, 0.75, -0.6), Vector3(0.1, 1.6, 0.1), b, true, 0.7)
	k.box("lore_beam", at + b * Vector3(0, 1.52, -0.6), Vector3(2.5, 0.1, 0.1), b, false, 0.7)
	var slope := Basis(Vector3.RIGHT, -0.72)
	for i in 6:
		var x := -1.0 + float(i) * 0.4
		k.box("lore_beam", at + b * Vector3(x, 0.82, 0.05), Vector3(0.34, 0.05, 1.9), b * slope * Basis(Vector3.UP, (L.rng as RandomNumberGenerator).randf_range(-0.04, 0.04)), true, (L.rng as RandomNumberGenerator).randf_range(0.62, 0.8))


static func _tower(L: RefCounted, at: Vector3, h: float, w: float, yaw: float, rng: RandomNumberGenerator) -> void:
	var k: OssKit = L.k
	var b := Basis(Vector3.UP, yaw)
	# a squat round stump of a watch-tower: courses of blocks round a solid core, its crown broken
	var r := w * 0.5
	var y := at.y - 0.5
	var course := 0
	while y < at.y + h:
		var ch := rng.randf_range(0.36, 0.48)
		var n := 12
		for i in n:
			var a := TAU * float(i) / float(n) + float(course % 2) * 0.26
			var top_cut := y > at.y + h - 1.0 and sin(a * 2.0 + 1.3) > 0.3
			if top_cut:
				continue
			var o := b * Vector3(cos(a) * r, 0, sin(a) * r)
			k.box("lore_moss", Vector3(at.x, y + ch * 0.5, at.z) + o, Vector3(r * 0.56, ch, 0.5), b * Basis(Vector3.UP, -a + PI * 0.5 + rng.randf_range(-0.04, 0.04)), false, rng.randf_range(0.72, 0.95))
		y += ch
		course += 1
	k.box("lore_tstone", at + Vector3.UP * (h * 0.5 - 0.25), Vector3(w * 0.92, h + 0.5, w * 0.92), b, true, 0.8)
	LK.col_box(k, at + Vector3.UP * (h * 0.5 - 0.25), Vector3(w * 1.12, h + 0.5, w * 1.12), b)      # the courses' outer face, walked against
	k.box("lore_tstone", at + Vector3.UP * (h + 0.02), Vector3(w * 0.88, 0.1, w * 0.88), b * Basis(Vector3.UP, 0.4), false, 0.9)


static func _shard(L: RefCounted, at: Vector3, yaw: float, s: float) -> void:
	# a curved piece of the bell: a few bronze plates bent on an arc, half buried, its lip up
	var k: OssKit = L.k
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, (L.rng as RandomNumberGenerator).randf_range(0.3, 1.0))
	var r := 1.3 * s
	var n := 4
	for i in n:
		var a := lerpf(-0.6, 0.6, float(i) / float(n - 1))
		var o := b * Vector3(sin(a) * r, 0.0, (cos(a) - 1.0) * r)
		k.box("lore_bronze", at + o + Vector3.UP * 0.35 * s, Vector3(0.62 * s, 0.9 * s, 0.09 * s), b * Basis(Vector3.UP, -a), true, (L.rng as RandomNumberGenerator).randf_range(0.6, 0.85))
	k.box("lore_bronze", at + b * Vector3(0, 0.82 * s, -0.12 * s), Vector3(1.9 * s, 0.14 * s, 0.16 * s), b, false, 0.7)


static func _clamp(L: RefCounted, at: Vector3, r: float) -> void:
	# a charcoal clamp: a turfed dome over a stack of billets, its vents black
	var k: OssKit = L.k
	var rng: RandomNumberGenerator = L.rng
	var cm := CreatureMesh.new(rng.randi())
	cm.blob(Vector3.ZERO, Vector3(r, r * 0.62, r), Basis.IDENTITY, Color(1, 1, 1), 0.0, 0.2, 0.0, 8, 14)
	LK.organic(k, "lore_earth", cm.commit(), Transform3D(Basis.IDENTITY, at + Vector3.DOWN * 0.2), true)
	for i in 5:
		var a := TAU * float(i) / 5.0 + rng.randf_range(-0.2, 0.2)
		var o := Vector3(cos(a) * r * 0.62, r * 0.38, sin(a) * r * 0.62)
		k.box("lore_char", at + o, Vector3(0.24, 0.12, 0.24), Basis(Vector3.UP, a), false, 0.4)
	k.box("lore_char", at + Vector3.UP * (r * 0.62 - 0.25), Vector3(0.36, 0.14, 0.36), Basis.IDENTITY, false, 0.35)


static func _jetty(L: RefCounted, e: Dictionary, xf: Transform3D, yaw: float, rng: RandomNumberGenerator) -> void:
	var k: OssKit = L.k
	var b := Basis(Vector3.UP, yaw)
	var start := _g(L, xf, e.p)
	var deck_y := maxf(start.y, -0.9) + 0.45
	var length := float(e.len)
	var w := float(e.w)
	var n := int(length / 0.42)
	for i in n:
		if rng.randf() < 0.07 and i > 2:
			continue                                     # a board gone
		var q := start + b * Vector3(0, 0, -0.21 - float(i) * 0.42)
		k.box("lore_beam", Vector3(q.x, deck_y, q.z), Vector3(w * rng.randf_range(0.92, 1.0), 0.07, 0.38), b * Basis(Vector3.UP, rng.randf_range(-0.04, 0.04)), true, rng.randf_range(0.62, 0.82))
	for i in int(length / 1.8) + 1:
		for sx: float in [-1.0, 1.0]:
			var pq := start + b * Vector3(sx * (w * 0.5 + 0.05), 0, -float(i) * 1.8)
			var gy := minf(L.g(pq.x, pq.z), deck_y - 0.3)
			var top := deck_y + (0.4 if i == int(length / 1.8) else 0.05)
			k.box("lore_beam", Vector3(pq.x, (top + gy - 0.6) * 0.5, pq.z), Vector3(0.14, top - gy + 0.6, 0.14), b * Basis(Vector3.RIGHT, rng.randf_range(-0.05, 0.05)), true, 0.6)
	for sx2: float in [-1.0, 1.0]:
		k.box("lore_beam", start + b * Vector3(sx2 * (w * 0.5 - 0.05), 0, -length * 0.5) + Vector3.UP * (deck_y - start.y - 0.08), Vector3(0.12, 0.1, length), b, false, 0.6)


static func _trap(L: RefCounted, at: Vector3, yaw: float) -> void:
	# an eel trap: a wicker cone on its side, half in the water, staked
	var k: OssKit = L.k
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5)
	var c := Vector3(at.x, maxf(at.y, -0.9) + 0.12, at.z)
	for i in 8:
		var a := TAU * float(i) / 8.0
		var o := b * Vector3(cos(a) * 0.22, 0, sin(a) * 0.22)
		k.box("lore_beam", c + o, Vector3(0.025, 1.1, 0.025), b * Basis(Vector3.BACK, cos(a) * 0.12) * Basis(Vector3.RIGHT, sin(a) * 0.12), false, 0.75)
	for ry: float in [-0.4, 0.0, 0.4]:
		k.box("lore_beam", c + b * Vector3(0, ry, 0), Vector3(0.5 - ry * 0.15, 0.03, 0.5 - ry * 0.15), b, false, 0.7)
	k.box("lore_beam", c + Vector3.UP * 0.5, Vector3(0.05, 1.3, 0.05), Basis(Vector3.BACK, 0.15), false, 0.6)


## One MultiMesh per site-props mesh part for this place's small clutter (no collision: it is ankle-high).
static func _commit_clutter(h: Node3D, clutter: Dictionary) -> void:
	for key: String in clutter:
		var d := Props.get_prop(key)
		if d.is_empty():
			continue
		var xfs: Array = clutter[key]
		var parts: Array = []
		if d.has("variants"):
			parts = (d.variants as Array)[0]
		else:
			parts = [{"mesh": d.mesh, "mat": d.mat}]
		for part: Dictionary in parts:
			var mmi := OssKit.multimesh(part.mesh as Mesh, xfs, part.mat as Material, false)
			mmi.name = "Clutter_" + key
			mmi.visibility_range_end = CLUTTER_RANGE
			mmi.visibility_range_end_margin = 8.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			mmi.set_meta("site_owned", true)
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			h.add_child(mmi)
